package com.cryptoai.pro

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Shared HTTP helper. All calls are synchronous (bridge methods run on a WebView background thread). */
object Net {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    private val JSON = "application/json; charset=utf-8".toMediaType()
    private val FORM = "application/x-www-form-urlencoded".toMediaType()

    fun parseHeaders(headersJson: String?): Map<String, String> {
        if (headersJson.isNullOrBlank()) return emptyMap()
        return try {
            val o = JSONObject(headersJson)
            val m = HashMap<String, String>()
            o.keys().forEach { k -> m[k] = o.optString(k) }
            m
        } catch (e: Exception) { emptyMap() }
    }

    /** Returns raw response body. On network failure returns a JSON error object so JS never gets null. */
    fun request(method: String, url: String, body: String? = null, headers: Map<String, String> = emptyMap(), form: Boolean = false): String {
        return try {
            val b = Request.Builder().url(url)
            headers.forEach { (k, v) -> b.header(k, v) }
            val m = method.uppercase()
            if (m == "GET") b.get()
            else if (m == "DELETE" && body.isNullOrEmpty()) b.delete()
            else {
                val ct = headers.entries.firstOrNull { it.key.equals("Content-Type", true) }?.value
                val mt = when {
                    ct != null -> ct.toMediaType()
                    form -> FORM
                    else -> JSON
                }
                b.method(m, (body ?: "").toRequestBody(mt))
            }
            client.newCall(b.build()).execute().use { resp ->
                val text = resp.body?.string() ?: ""
                if (text.isEmpty()) JSONObject().put("status", resp.code).put("ok", resp.isSuccessful).toString() else text
            }
        } catch (e: Exception) {
            JSONObject().put("error", true).put("msg", e.message ?: e.toString()).toString()
        }
    }

    fun get(url: String, headers: Map<String, String> = emptyMap()) = request("GET", url, null, headers)
}
