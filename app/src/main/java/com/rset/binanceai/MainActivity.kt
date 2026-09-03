package com.rset.binanceai

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.webkit.WebViewAssetLoader
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Hosts the trading dashboard (assets/www/index.html) inside a WebView and exposes a
 * small native bridge so that:
 *  - API key/secret are stored with EncryptedSharedPreferences (never inside the page)
 *  - Signed Binance requests are HMAC-SHA256 signed natively (secret never reaches JS)
 *  - Public REST calls are proxied natively (no CORS concerns)
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private val executor = Executors.newFixedThreadPool(4)

    private val prefs by lazy {
        val masterKey = MasterKey.Builder(this)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            this,
            "binance_ai_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        webView = WebView(this)
        setContentView(webView)

        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mediaPlaybackRequiresUserGesture = false
            setSupportZoom(false)
            builtInZoomControls = false
            displayZoomControls = false
        }
        webView.setBackgroundColor(0xFF0B0E11.toInt())
        webView.addJavascriptInterface(NativeBridge(), "Native")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? = assetLoader.shouldInterceptRequest(request.url)
        }
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)

        webView.loadUrl("https://appassets.androidplatform.net/assets/www/index.html")

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Let the page handle back (close modals) first.
                webView.evaluateJavascript("window.__onBack ? window.__onBack() : false") { result ->
                    if (result != "true") {
                        isEnabled = false
                        onBackPressedDispatcher.onBackPressed()
                        isEnabled = true
                    }
                }
            }
        })
    }

    override fun onDestroy() {
        executor.shutdownNow()
        webView.destroy()
        super.onDestroy()
    }

    private fun postToJs(callbackId: String, ok: Boolean, status: Int, body: String) {
        val payload = JSONObject()
            .put("ok", ok)
            .put("status", status)
            .put("body", body)
            .toString()
        runOnUiThread {
            webView.evaluateJavascript(
                "window.__nativeCallback && window.__nativeCallback(${JSONObject.quote(callbackId)}, $payload)",
                null
            )
        }
    }

    private fun hmacSha256(secret: String, data: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(data.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    private fun httpRequest(
        method: String,
        url: String,
        headers: Map<String, String>,
        body: String?
    ): Pair<Int, String> {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15000
            readTimeout = 20000
            headers.forEach { (k, v) -> setRequestProperty(k, v) }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
        }
        return try {
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
            status to text
        } finally {
            conn.disconnect()
        }
    }

    inner class NativeBridge {

        @JavascriptInterface
        fun platform(): String = "android"

        @JavascriptInterface
        fun toast(msg: String) {
            runOnUiThread { Toast.makeText(this@MainActivity, msg, Toast.LENGTH_SHORT).show() }
        }

        @JavascriptInterface
        fun vibrate(ms: Int) {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator.vibrate(VibrationEffect.createOneShot(ms.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
        }

        /** Persist credentials securely. Secret never goes back to JS. */
        @JavascriptInterface
        fun saveCredentials(apiKey: String, apiSecret: String, testnet: Boolean) {
            prefs.edit()
                .putString("api_key", apiKey.trim())
                .putString("api_secret", apiSecret.trim())
                .putBoolean("testnet", testnet)
                .apply()
        }

        @JavascriptInterface
        fun clearCredentials() {
            prefs.edit().clear().apply()
        }

        /** Returns JSON: { hasKeys, apiKeyMasked, testnet } */
        @JavascriptInterface
        fun credentialStatus(): String {
            val key = prefs.getString("api_key", "") ?: ""
            val secret = prefs.getString("api_secret", "") ?: ""
            val masked = if (key.length > 8) key.take(4) + "••••" + key.takeLast(4) else ""
            return JSONObject()
                .put("hasKeys", key.isNotEmpty() && secret.isNotEmpty())
                .put("apiKeyMasked", masked)
                .put("testnet", prefs.getBoolean("testnet", true))
                .toString()
        }

        @JavascriptInterface
        fun getPref(key: String): String = prefs.getString("ui_$key", "") ?: ""

        @JavascriptInterface
        fun setPref(key: String, value: String) {
            prefs.edit().putString("ui_$key", value).apply()
        }

        /** Plain GET (public endpoints). */
        @JavascriptInterface
        fun httpGet(url: String, callbackId: String) {
            executor.execute {
                try {
                    val (status, text) = httpRequest("GET", url, emptyMap(), null)
                    postToJs(callbackId, status in 200..299, status, text)
                } catch (e: Exception) {
                    postToJs(callbackId, false, 0, e.message ?: "network error")
                }
            }
        }

        /**
         * Signed request against the configured Binance base URL.
         * @param method GET | POST | DELETE
         * @param path   e.g. /api/v3/account
         * @param query  URL-encoded params WITHOUT timestamp/signature
         */
        @JavascriptInterface
        fun signedRequest(method: String, path: String, query: String, callbackId: String) {
            executor.execute {
                try {
                    val key = prefs.getString("api_key", "") ?: ""
                    val secret = prefs.getString("api_secret", "") ?: ""
                    if (key.isEmpty() || secret.isEmpty()) {
                        postToJs(callbackId, false, 401, """{"code":-1,"msg":"API keys not configured"}""")
                        return@execute
                    }
                    val testnet = prefs.getBoolean("testnet", true)
                    val base = if (testnet) "https://testnet.binance.vision" else "https://api.binance.com"
                    val ts = System.currentTimeMillis()
                    val q = buildString {
                        if (query.isNotBlank()) append(query).append('&')
                        append("recvWindow=10000&timestamp=").append(ts)
                    }
                    val signed = "$q&signature=${hmacSha256(secret, q)}"
                    val headers = mapOf("X-MBX-APIKEY" to key)
                    val (status, text) = when (method.uppercase()) {
                        "POST" -> httpRequest("POST", "$base$path", headers, signed)
                        "DELETE" -> httpRequest("DELETE", "$base$path?$signed", headers, null)
                        else -> httpRequest("GET", "$base$path?$signed", headers, null)
                    }
                    postToJs(callbackId, status in 200..299, status, text)
                } catch (e: Exception) {
                    postToJs(callbackId, false, 0, e.message ?: "network error")
                }
            }
        }
    }
}
