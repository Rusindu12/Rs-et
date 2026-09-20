package com.cryptoai.pro

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.net.URLEncoder
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Base for Binance / Bybit signed-request helpers. Keys are stored in app-private SharedPreferences. */
abstract class Exchange(ctx: Context, val name: String) {
    protected val prefs: SharedPreferences = ctx.getSharedPreferences("keys_$name", Context.MODE_PRIVATE)
    @Volatile var timeOffset: Long = 0L

    val apiKey: String get() = prefs.getString("key", "") ?: ""
    val apiSecret: String get() = prefs.getString("secret", "") ?: ""
    val testnet: Boolean get() = prefs.getBoolean("testnet", false)
    val hasKeys: Boolean get() = apiKey.isNotBlank() && apiSecret.isNotBlank()

    fun saveKeys(key: String, secret: String, testnet: Boolean) {
        prefs.edit().putString("key", key.trim()).putString("secret", secret.trim()).putBoolean("testnet", testnet).apply()
    }
    fun clearKeys() = prefs.edit().clear().apply()

    fun status(): String = JSONObject()
        .put("hasKeys", hasKeys).put("testnet", testnet)
        .put("keyPreview", if (apiKey.length > 8) apiKey.take(4) + "…" + apiKey.takeLast(4) else "")
        .put("timeOffset", timeOffset).put("base", baseUrl()).toString()

    protected fun hmacSha256(data: String, secret: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(data.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    protected fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")

    /** paramsJson -> "a=1&b=2" (sorted keys off, insertion order kept). Accepts JSON object or already-encoded query string. */
    protected fun toQuery(paramsJson: String?): String {
        if (paramsJson.isNullOrBlank() || paramsJson == "null") return ""
        val t = paramsJson.trim()
        if (!t.startsWith("{")) return t.removePrefix("?")
        val o = JSONObject(t)
        val parts = ArrayList<String>()
        o.keys().forEach { k ->
            val v = o.get(k)
            if (v != JSONObject.NULL) parts.add("${enc(k)}=${enc(v.toString())}")
        }
        return parts.joinToString("&")
    }

    protected fun now(): Long = System.currentTimeMillis() + timeOffset

    abstract fun baseUrl(): String
    abstract fun syncTime(): Long
    abstract fun public(path: String, paramsJson: String?): String
    abstract fun signed(method: String, path: String, paramsJson: String?): String
}

class Binance(ctx: Context) : Exchange(ctx, "binance") {
    // Futures (USDT-M) by default; spot paths (/api/v3/...) are auto-routed.
    override fun baseUrl(): String = if (testnet) "https://testnet.binancefuture.com" else "https://fapi.binance.com"
    private fun spotBase(): String = if (testnet) "https://testnet.binance.vision" else "https://api.binance.com"
    private fun hostFor(path: String): String = if (path.startsWith("/api/")) spotBase() else baseUrl()

    override fun syncTime(): Long {
        return try {
            val t0 = System.currentTimeMillis()
            val body = Net.get(baseUrl() + "/fapi/v1/time")
            val server = JSONObject(body).getLong("serverTime")
            val t1 = System.currentTimeMillis()
            timeOffset = server - (t0 + (t1 - t0) / 2)
            timeOffset
        } catch (e: Exception) { timeOffset }
    }

    override fun public(path: String, paramsJson: String?): String {
        val url = if (path.startsWith("http")) path else hostFor(path) + path
        val q = toQuery(paramsJson)
        return Net.get(if (q.isEmpty()) url else "$url?$q")
    }

    override fun signed(method: String, path: String, paramsJson: String?): String {
        if (!hasKeys) return JSONObject().put("error", true).put("code", -1).put("msg", "API keys not set").toString()
        var q = toQuery(paramsJson)
        q += (if (q.isEmpty()) "" else "&") + "recvWindow=10000&timestamp=${now()}"
        q += "&signature=" + hmacSha256(q, apiSecret)
        val headers = mapOf("X-MBX-APIKEY" to apiKey, "Content-Type" to "application/x-www-form-urlencoded")
        val url = hostFor(path) + path
        val m = method.uppercase()
        return if (m == "GET" || m == "DELETE") Net.request(m, "$url?$q", null, headers)
        else Net.request(m, url, q, headers, form = true)
    }
}

class Bybit(ctx: Context) : Exchange(ctx, "bybit") {
    override fun baseUrl(): String = if (testnet) "https://api-testnet.bybit.com" else "https://api.bybit.com"

    override fun syncTime(): Long {
        return try {
            val t0 = System.currentTimeMillis()
            val body = Net.get(baseUrl() + "/v5/market/time")
            val server = JSONObject(body).getJSONObject("result").getString("timeNano").toLong() / 1_000_000
            val t1 = System.currentTimeMillis()
            timeOffset = server - (t0 + (t1 - t0) / 2)
            timeOffset
        } catch (e: Exception) { timeOffset }
    }

    override fun public(path: String, paramsJson: String?): String {
        val url = if (path.startsWith("http")) path else baseUrl() + path
        val q = toQuery(paramsJson)
        return Net.get(if (q.isEmpty()) url else "$url?$q")
    }

    override fun signed(method: String, path: String, paramsJson: String?): String {
        if (!hasKeys) return JSONObject().put("retCode", -1).put("retMsg", "API keys not set").toString()
        val ts = now().toString()
        val recv = "10000"
        val m = method.uppercase()
        val payload: String = if (m == "GET") toQuery(paramsJson)
            else if (paramsJson.isNullOrBlank() || paramsJson == "null") "{}" else paramsJson
        val sign = hmacSha256(ts + apiKey + recv + payload, apiSecret)
        val headers = mapOf(
            "X-BAPI-API-KEY" to apiKey, "X-BAPI-SIGN" to sign, "X-BAPI-SIGN-TYPE" to "2",
            "X-BAPI-TIMESTAMP" to ts, "X-BAPI-RECV-WINDOW" to recv, "Content-Type" to "application/json"
        )
        val url = baseUrl() + path
        return if (m == "GET") Net.request("GET", if (payload.isEmpty()) url else "$url?$payload", null, headers)
        else Net.request(m, url, payload, headers)
    }
}
