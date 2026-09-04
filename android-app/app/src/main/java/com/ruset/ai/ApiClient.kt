package com.ruset.ai

import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST
import java.util.concurrent.TimeUnit

data class Attachment(
    val name: String,
    val kind: String = "file",      // "image" | "file"
    val mime: String = "text/plain",
    val data_b64: String
)

data class HistoryMsg(
    val role: String,       // "user" | "assistant"
    val content: String
)

data class ChatRequest(
    val message: String,
    val mode: String = "chat",
    val attachments: List<Attachment>? = null,
    val history: List<HistoryMsg>? = null,   // conversation memory
    val max_tokens: Int = 400,
    val temperature: Double = 0.8
)

data class SourceItem(
    val title: String = "",
    val url: String = ""
)

data class ChatResponse(
    val reply: String,
    val latency_ms: Int = 0,
    val provider: String = "",
    val image_url: String? = null,
    val sources: List<SourceItem>? = null
)

interface RsAiApi {
    @POST("chat")
    suspend fun chat(
        @Body body: ChatRequest,
        @Header("Authorization") authorization: String? = null
    ): ChatResponse
}

object ApiClient {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(300, TimeUnit.SECONDS)   // deep research / think can take a while
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private var cachedBase: String? = null
    private var cachedApi: RsAiApi? = null

    @Synchronized
    private fun api(base: String): RsAiApi {
        val b = base.trim().trimEnd('/') + "/"
        if (b != cachedBase || cachedApi == null) {
            cachedApi = Retrofit.Builder()
                .baseUrl(b)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(RsAiApi::class.java)
            cachedBase = b
        }
        return cachedApi!!
    }

    suspend fun chat(
        base: String,
        message: String,
        token: String = "",
        mode: String = "chat",
        attachments: List<Attachment>? = null,
        history: List<HistoryMsg>? = null
    ): ChatResponse =
        api(base).chat(
            ChatRequest(
                message = message,
                mode = mode,
                attachments = if (attachments.isNullOrEmpty()) null else attachments,
                history = if (history.isNullOrEmpty()) null else history
            ),
            if (token.isBlank()) null else "Bearer $token"
        )
}
