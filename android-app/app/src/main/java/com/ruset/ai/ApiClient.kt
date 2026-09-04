package com.ruset.ai

import com.google.gson.Gson
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
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

data class HealthResponse(
    val status: String = "",
    val active: String = "",
    val modes: List<String>? = null,
)

interface RsAiApi {
    @POST("chat")
    suspend fun chat(
        @Body body: ChatRequest,
        @Header("Authorization") authorization: String? = null
    ): ChatResponse

    @GET("health")
    suspend fun health(): HealthResponse
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

    /** Quick server reachability check (used by Settings "Test connection"). */
    suspend fun healthCheck(base: String): Result<HealthResponse> =
        try {
            val h = api(base).health()
            Result.success(h)
        } catch (e: Exception) {
            Result.failure(e)
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

    // ------------------------------------------------------------------ //
    // SSE streaming (RS format): data: {"delta": ...} then {"done": ...,  //
    // provider, image_url?, sources?} — callbacks marshaled to Main.      //
    // ------------------------------------------------------------------ //

    private val gson = Gson()

    /** Build the streaming call (caller keeps it => can call Call.cancel()). */
    fun buildStreamCall(
        base: String,
        message: String,
        token: String = "",
        mode: String = "chat",
        attachments: List<Attachment>? = null,
        history: List<HistoryMsg>? = null,
    ): okhttp3.Call {
        val payload = mapOf(
            "message" to message,
            "mode" to mode,
            "stream" to true,
            "attachments" to attachments,
            "history" to history,
        )
        val body = gson.toJson(payload)
            .toRequestBody("application/json; charset=utf-8".toMediaType())
        val reqBuilder = Request.Builder()
            .url(base.trim().trimEnd('/') + "/chat")
            .post(body)
        if (token.isNotBlank()) reqBuilder.header("Authorization", "Bearer $token")
        return client.newCall(reqBuilder.build())
    }

    /** Execute a streaming call; onDelta gets the accumulated text on Main. */
    suspend fun consumeStream(
        call: okhttp3.Call,
        onDelta: (String) -> Unit,
    ): ChatResponse = withContext(Dispatchers.IO) {
        call.execute().use { resp ->
            if (resp.code == 401) throw IllegalStateException("401: API token වැරදියි")
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            val acc = StringBuilder()
            var provider = ""
            var imageUrl: String? = null
            var sources: List<SourceItem>? = null
            val body = resp.body ?: throw IllegalStateException("empty response body")
            val source = body.source()
            while (!source.exhausted()) {
                val line = source.readUtf8Line() ?: break
                if (!line.startsWith("data:")) continue
                val payloadStr = line.substring(5).trim()
                if (payloadStr.isEmpty()) continue
                val j = try {
                    JsonParser.parseString(payloadStr).asJsonObject
                } catch (e: Exception) {
                    continue
                }
                if (j.has("delta")) {
                    acc.append(j.get("delta").asString)
                    withContext(Dispatchers.Main) { onDelta(acc.toString()) }
                } else if (j.has("done") && j.get("done").asBoolean) {
                    provider = if (j.has("provider")) j.get("provider").asString else ""
                    imageUrl = if (j.has("image_url")) j.get("image_url").asString else null
                    sources = if (j.has("sources")) {
                        try {
                            gson.fromJson(j.get("sources"), Array<SourceItem>::class.java).toList()
                        } catch (e: Exception) { null }
                    } else null
                }
            }
            ChatResponse(
                reply = acc.toString(),
                provider = provider,
                image_url = imageUrl,
                sources = sources,
            )
        }
    }
}
