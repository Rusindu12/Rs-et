package com.ruset.ai

import android.app.Application
import android.content.Context
import android.os.Build
import android.graphics.Bitmap
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.Locale

data class ChatMessage(
    val text: String,
    val isUser: Boolean,
    val imageUrl: String? = null,
    val sources: List<SourceItem>? = null
)

data class PendingAttachment(
    val name: String,
    val kind: String,       // "image" | "file"
    val mime: String,
    val dataB64: String
)

data class StoredSession(val title: String = "", val convo: List<ChatMessage> = emptyList())
data class SessionMeta(val id: String, val title: String)

class ChatViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("rsai_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()
    private var activeCall: okhttp3.Call? = null
    private var tts: TextToSpeech? = null

    // multi-chat sessions
    private var sessionsMap: MutableMap<String, StoredSession> = mutableMapOf()
    var activeSessionId by mutableStateOf("")
        private set
    val sessionList = mutableStateListOf<SessionMeta>()

    // teach panel state
    var teachStatus by mutableStateOf("")
        private set

    var speakOn by mutableStateOf(false)
        private set

    fun toggleSpeak() {
        speakOn = !speakOn
        if (speakOn && tts == null) {
            tts = TextToSpeech(getApplication()) { status ->
                if (status != TextToSpeech.SUCCESS) tts = null
            }
        } else if (!speakOn) {
            tts?.stop()
        }
    }

    private fun speakOut(text: String) {
        if (!speakOn) return
        val t = tts ?: return
        val isSinhala = text.any { it.code in 0x0D80..0x0DFF }
        t.language = if (isSinhala) Locale("si", "LK") else Locale.US
        t.speak(text.take(800), TextToSpeech.QUEUE_FLUSH, null, "rsai_msg")
    }

    fun stopGeneration() {
        activeCall?.cancel()
        tts?.stop()
    }

    private fun persistChat() {
        try {
            if (activeSessionId.isBlank()) return
            val firstUser = messages.firstOrNull { it.isUser }?.text ?: ""
            val title = if (firstUser.isBlank()) "New chat" else firstUser.take(26)
            sessionsMap[activeSessionId] = StoredSession(title, messages.toList().takeLast(40))
            prefs.edit()
                .putString("chat_sessions", gson.toJson(sessionsMap))
                .putString("active_session", activeSessionId)
                .apply()
            refreshSessionList()
        } catch (e: Exception) { /* storage hiccup — non-fatal */ }
    }

    private fun refreshSessionList() {
        sessionList.clear()
        sessionsMap.keys.reversed().forEach { id ->
            sessionList.add(SessionMeta(id, sessionsMap[id]?.title ?: "Chat"))
        }
    }

    fun newChat() {
        if (activeSessionId.isNotBlank()) persistChat()
        activeSessionId = "c" + System.currentTimeMillis()
        messages.clear()
        messages.add(ChatMessage("ආයුබෝවන්! 👋 අලුත් chat එකක් — මම RS AI 🤖", false))
        persistChat()
    }

    fun switchChat(id: String) {
        if (id == activeSessionId) return
        if (activeSessionId.isNotBlank()) persistChat()
        activeSessionId = id
        val convo = sessionsMap[id]?.convo ?: emptyList()
        messages.clear()
        if (convo.isEmpty()) {
            messages.add(ChatMessage("ආයුබෝවන්! 👋", false))
        } else {
            messages.addAll(convo)
        }
        prefs.edit().putString("active_session", activeSessionId).apply()
        refreshSessionList()
    }

    fun deleteSession(id: String) {
        sessionsMap.remove(id)
        prefs.edit().putString("chat_sessions", gson.toJson(sessionsMap)).apply()
        if (id == activeSessionId) {
            activeSessionId = sessionsMap.keys.lastOrNull() ?: ""
            if (activeSessionId.isBlank()) newChat() else {
                val convo = sessionsMap[activeSessionId]?.convo ?: emptyList()
                messages.clear(); messages.addAll(convo)
            }
        }
        refreshSessionList()
    }

    // ---------------- teach ----------------
    fun teachRemember(text: String) {
        if (text.isBlank()) return
        viewModelScope.launch {
            teachStatus = "⏳…"
            teachStatus = try {
                val j = ApiClient.memoryAdd(serverUrl, apiToken, text)
                "✅ Instant memory! ${j.items.size} facts — next chat වල auto use වෙනවා"
            } catch (e: Exception) { "⚠️ " + (e.message ?: "error") }
        }
    }

    fun teachIntoCorpus(text: String) {
        if (text.isBlank()) return
        viewModelScope.launch {
            teachStatus = "⏳…"
            teachStatus = try {
                val j = ApiClient.trainWrite(serverUrl, apiToken, text)
                if (j.ok) "⬆ training data ✔ (${j.corpus_chars} chars) — Fine-tune 🏋️ button එකෙන් brain update"
                else "⚠️ " + (j.error ?: "error")
            } catch (e: Exception) { "⚠️ " + (e.message ?: "error") }
        }
    }

    fun teachFineTune(steps: Int = 120) {
        viewModelScope.launch {
            teachStatus = try {
                val j = ApiClient.trainRun(serverUrl, apiToken, steps)
                if (!j.ok) { "⚠️ " + (j.error ?: "error") } else {
                    "🏋️ fine-tune පටන්ගත්තා…"
                    var done = false; var polls = 0
                    var finalMsg = "✅ done"
                    while (!done && polls < 120) {
                        kotlinx.coroutines.delay(1500)
                        polls++
                        val st = ApiClient.trainStatus(serverUrl)
                        if (st.running) teachStatus = "🏋️ ${st.step}/${st.total} steps · loss ${((st.loss ?: 0.0) * 1000).toInt() / 1000.0}"
                        else if (st.error != null) { done = true; finalMsg = "⚠️ " + st.error }
                        else { done = true; finalMsg = "🎉 fine-tune done! Brain hot-swapped — දැන්ම test!" }
                    }
                    finalMsg
                }
            } catch (e: Exception) { "⚠️ " + (e.message ?: "error") }
        }
    }

    var serverUrl by mutableStateOf(prefs.getString("server_url", DEFAULT_URL) ?: DEFAULT_URL)
        private set
    var apiToken by mutableStateOf(prefs.getString("api_token", "") ?: "")
        private set

    val messages = mutableStateListOf(
        ChatMessage("ආයුබෝවන්! 👋 මම RS AI. උඩ mode එකක් තෝරන්න — chat, thinking, research, image 🎨. Photos/files attach කරන්නත්, 🎙️ voice වලින් අහන්නත් පුළුවන්!", false)
    )

    init {
        // 💾 restore chat sessions (survives app restarts); legacy single history migrates
        activeSessionId = prefs.getString("active_session", "") ?: ""
        val savedMap = prefs.getString("chat_sessions", null)
        if (!savedMap.isNullOrBlank()) {
            try {
                val type = object : com.google.gson.reflect.TypeToken<MutableMap<String, StoredSession>>() {}.type
                val m: MutableMap<String, StoredSession> = gson.fromJson(savedMap, type)
                sessionsMap.putAll(m)
            } catch (e: Exception) { /* corrupted — start fresh */ }
        }
        if (sessionsMap.isEmpty()) {
            val saved = prefs.getString("chat_history", null)
            if (!saved.isNullOrBlank()) {
                try {
                    val arr = gson.fromJson(saved, Array<ChatMessage>::class.java)
                    if (!arr.isNullOrEmpty()) sessionsMap["c0"] = StoredSession("Chat", arr.toList())
                } catch (e: Exception) { /* ignore */ }
            }
        }
        if (activeSessionId.isBlank() || !sessionsMap.containsKey(activeSessionId)) {
            activeSessionId = sessionsMap.keys.lastOrNull() ?: "c" + System.currentTimeMillis()
        }
        val convo = sessionsMap[activeSessionId]?.convo
        if (!convo.isNullOrEmpty()) {
            messages.clear()
            messages.addAll(convo)
        }
        refreshSessionList()
    }
    val attachments = mutableStateListOf<PendingAttachment>()

    fun clearChat() {
        attachments.clear()
        messages.clear()
        tts?.stop()
        persistChat()
        messages.add(
            ChatMessage("ආයුබෝවන්! 👋 අලුතෙන් පටන් ගමු — මම RS AI 🤖", false)
        )
    }
    var selectedMode by mutableStateOf("chat")
    var isTyping by mutableStateOf(false)
        private set

    val modes = listOf(
        "chat" to "💬 Chat",
        "think" to "💡 Thinking",
        "think_harder" to "🧠 Think harder",
        "research" to "🔬 Deep research",
        "image" to "🎨 Image"
    )

    fun updateServerUrl(url: String) {
        val clean = url.trim().trimEnd('/')
        if (clean.isNotEmpty()) {
            serverUrl = clean
            prefs.edit().putString("server_url", clean).apply()
        }
    }

    fun updateApiToken(token: String) {
        apiToken = token.trim()
        prefs.edit().putString("api_token", apiToken).apply()
    }

    fun selectMode(m: String) {
        selectedMode = m
    }

    fun removeAttachment(i: Int) {
        if (i in attachments.indices) attachments.removeAt(i)
    }

    private fun pushAttachment(a: PendingAttachment) {
        when {
            attachments.size >= 3 ->
                messages.add(ChatMessage("⚠️ files 3ක් දක්වායි", false))
            a.dataB64.length > 4_200_000 ->
                messages.add(ChatMessage("⚠️ '${a.name}' ලොකු වැඩියි (max ~3MB)", false))
            else -> attachments.add(a)
        }
    }

    fun addBitmapAttachment(bmp: Bitmap) {
        viewModelScope.launch(Dispatchers.IO) {
            val scaled = scaleDown(bmp, 1280)
            val baos = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 82, baos)
            val b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
            withContext(Dispatchers.Main) {
                pushAttachment(PendingAttachment("camera.jpg", "image", "image/jpeg", b64))
            }
        }
    }

    fun addUriAttachment(uri: Uri) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val cr = getApplication<Application>().contentResolver
                val mime = cr.getType(uri) ?: "application/octet-stream"
                val name = uri.lastPathSegment?.substringAfterLast('/') ?: "file"
                val kind = if (mime.startsWith("image/")) "image" else "file"
                val bytes = cr.openInputStream(uri)?.use { it.readBytes() }
                if (bytes == null || bytes.isEmpty()) throw IllegalStateException("empty file")
                val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                withContext(Dispatchers.Main) {
                    pushAttachment(PendingAttachment(name, kind, mime, b64))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    messages.add(ChatMessage("⚠️ file කියවන්න බැරි වුණා", false))
                }
            }
        }
    }

    fun send(text: String) {
        val msg = text.trim()
        if ((msg.isEmpty() && attachments.isEmpty()) || isTyping) return
        val atts = attachments.toList()
        attachments.clear()
        val mode = selectedMode

        // conversation memory: send the last 10 turns with each request
        val history = messages.takeLast(10)
            .filter { it.text.isNotBlank() }
            .map { HistoryMsg(if (it.isUser) "user" else "assistant", it.text.take(1500)) }

        messages.add(
            ChatMessage(
                if (atts.isEmpty()) msg else msg + "\n📎 ${atts.size} attachment(s)",
                isUser = true
            )
        )
        persistChat()
        isTyping = true
        val botIdx = messages.size
        messages.add(ChatMessage("", false))   // streaming placeholder bubble

        viewModelScope.launch {
            try {
                val call = ApiClient.buildStreamCall(
                    serverUrl,
                    msg.ifEmpty { "(attachment)" },
                    apiToken,
                    mode,
                    atts.map { Attachment(it.name, it.kind, it.mime, it.dataB64) },
                    history
                )
                activeCall = call
                val r = ApiClient.consumeStream(call) { acc ->
                    if (botIdx < messages.size) {
                        messages[botIdx] = ChatMessage(acc, false)
                    }
                }
                if (botIdx < messages.size) {
                    messages[botIdx] = ChatMessage(r.reply, false, r.image_url, r.sources)
                }
                persistChat()
                speakOut(r.reply)
            } catch (e: Exception) {
                val partial = if (botIdx < messages.size) messages[botIdx].text else ""
                val text = if (partial.isNotBlank()) {
                    partial + "\n\n⏹ නවත්තලා"
                } else {
                    "⚠️ Server එකට සම්බන්ධ වෙන්න බැහැ. Settings ⚙️ වලින් URL/token බලන්න.\n" +
                        (e.message ?: serverUrl)
                }
                if (botIdx < messages.size) messages[botIdx] = ChatMessage(text, false)
                persistChat()
            } finally {
                isTyping = false
                activeCall = null
            }
        }
    }

    private fun scaleDown(b: Bitmap, maxDim: Int): Bitmap {
        if (b.width <= maxDim && b.height <= maxDim) return b
        val s = maxDim.toFloat() / maxOf(b.width, b.height)
        return Bitmap.createScaledBitmap(b, (b.width * s).toInt(), (b.height * s).toInt(), true)
    }

    fun testConnection(onResult: (ok: Boolean, detail: String) -> Unit) {
        viewModelScope.launch {
            healthCheckRunning.value = true
            val r = ApiClient.healthCheck(serverUrl)
            healthCheckRunning.value = false
            if (r.isSuccess) {
                val h = r.getOrNull()
                onResult(true, "✅ Connected! Server: " + (h?.active ?: "rs-gpt") +
                        " · modes: " + (h?.modes?.joinToString() ?: "-"))
            } else {
                onResult(false, "❌ Connect fail: " + (r.exceptionOrNull()?.message ?: ""))
            }
        }
    }

    val healthCheckRunning = mutableStateOf(false)

    companion object {
        // emulator 10.0.2.2 works only inside an emulator — real phones get a blank field
        val DEFAULT_URL: String =
            if (Build.FINGERPRINT.contains("generic") || Build.MODEL.contains("Emulator")
                || Build.PRODUCT.contains("sdk_gphone")) "http://10.0.2.2:8000" else ""
    }
}
