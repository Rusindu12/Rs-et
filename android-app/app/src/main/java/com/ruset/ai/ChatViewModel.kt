package com.ruset.ai

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

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

class ChatViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("rsai_prefs", Context.MODE_PRIVATE)

    var serverUrl by mutableStateOf(prefs.getString("server_url", DEFAULT_URL) ?: DEFAULT_URL)
        private set
    var apiToken by mutableStateOf(prefs.getString("api_token", "") ?: "")
        private set

    val messages = mutableStateListOf(
        ChatMessage("ආයුබෝවන්! 👋 මම RS AI. උඩ mode එකක් තෝරන්න — chat, thinking, research, image 🎨. Photos/files attach කරන්නත්, 🎙️ voice වලින් අහන්නත් පුළුවන්!", false)
    )
    val attachments = mutableStateListOf<PendingAttachment>()

    fun clearChat() {
        attachments.clear()
        messages.clear()
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

    fun setServerUrl(url: String) {
        val clean = url.trim().trimEnd('/')
        if (clean.isNotEmpty()) {
            serverUrl = clean
            prefs.edit().putString("server_url", clean).apply()
        }
    }

    fun setApiToken(token: String) {
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
        isTyping = true

        viewModelScope.launch {
            try {
                val r = ApiClient.chat(
                    serverUrl,
                    msg.ifEmpty { "(attachment)" },
                    apiToken,
                    mode,
                    atts.map { Attachment(it.name, it.kind, it.mime, it.dataB64) },
                    history
                )
                messages.add(ChatMessage(r.reply, false, r.image_url, r.sources))
            } catch (e: Exception) {
                messages.add(
                    ChatMessage(
                        "⚠️ Server එකට සම්බන්ධ වෙන්න බැහැ. Settings ⚙️ වලින් URL/token බලන්න.\n($serverUrl)",
                        isUser = false
                    )
                )
            } finally {
                isTyping = false
            }
        }
    }

    private fun scaleDown(b: Bitmap, maxDim: Int): Bitmap {
        if (b.width <= maxDim && b.height <= maxDim) return b
        val s = maxDim.toFloat() / maxOf(b.width, b.height)
        return Bitmap.createScaledBitmap(b, (b.width * s).toInt(), (b.height * s).toInt(), true)
    }

    companion object {
        const val DEFAULT_URL = "http://10.0.2.2:8000"
    }
}
