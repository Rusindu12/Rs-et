package com.ruset.ai

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch

data class ChatMessage(val text: String, val isUser: Boolean)

class ChatViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("rsai_prefs", Context.MODE_PRIVATE)

    var serverUrl by mutableStateOf(prefs.getString("server_url", DEFAULT_URL) ?: DEFAULT_URL)
        private set

    var apiToken by mutableStateOf(prefs.getString("api_token", "") ?: "")
        private set

    val messages = mutableStateListOf(
        ChatMessage("ආයුබෝවන්! 👋 මම RS AI — සිංහල සහ ඉංග්‍රීසි කතා කරන AI සහායකයෙක්. ප්‍රශ්නයක් අහන්න!", false)
    )

    var isTyping by mutableStateOf(false)
        private set

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

    fun send(text: String) {
        val msg = text.trim()
        if (msg.isEmpty() || isTyping) return
        messages.add(ChatMessage(msg, isUser = true))
        isTyping = true

        viewModelScope.launch {
            try {
                val reply = ApiClient.chat(serverUrl, msg, apiToken)
                messages.add(ChatMessage(reply, isUser = false))
            } catch (e: Exception) {
                messages.add(
                    ChatMessage(
                        "⚠️ Server එකට සම්බන්ධ වෙන්න බැහැ.\nSettings ⚙️ වලින් URL එක බලන්න.\n(${serverUrl})",
                        isUser = false
                    )
                )
            } finally {
                isTyping = false
            }
        }
    }

    companion object {
        // Android emulator -> host machine localhost. Real device: use your PC's
        // LAN IP (e.g. http://192.168.1.5:8000) or a public server URL.
        const val DEFAULT_URL = "http://10.0.2.2:8000"
    }
}
