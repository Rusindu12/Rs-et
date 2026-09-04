package com.ruset.ai

import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST
import java.util.concurrent.TimeUnit

data class ChatRequest(
    val message: String,
    val max_tokens: Int = 200,
    val temperature: Double = 0.8
)

data class ChatResponse(
    val reply: String,
    val latency_ms: Int = 0
)

interface RsAiApi {
    @POST("chat")
    suspend fun chat(@Body body: ChatRequest): ChatResponse
}

object ApiClient {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(180, TimeUnit.SECONDS)   // CPU inference can be slow
        .writeTimeout(30, TimeUnit.SECONDS)
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

    suspend fun chat(base: String, message: String): String =
        api(base).chat(ChatRequest(message)).reply
}
