package com.ruset.aihub

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature

/**
 * RS AI Hub — all-in-one AI app shell.
 *
 * The whole product lives in `assets/` (HTML/CSS/JS): chat, image generation,
 * tools, vision, voice. This activity is only the native shell that:
 *  - loads the web app,
 *  - allows the web app to call AI APIs without CORS trouble,
 *  - provides the file picker for photo/vision attachments,
 *  - provides the file picker for photo/vision attachments,
 *  - saves generated images to the gallery,
 *  - offers native speech input / speech output via [AndroidBridge].
 */
class MainActivity : AppCompatActivity() {
    lateinit var web: WebView
    private lateinit var bridge: AndroidBridge

    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    private val fileChooserLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val cb = filePathCallback ?: return@registerForActivityResult
            filePathCallback = null
            val data = result.data
            val uris: Array<Uri>? = if (result.resultCode == RESULT_OK && data != null) {
                val clip = data.clipData
                when {
                    clip != null -> Array(clip.itemCount) { i -> clip.getItemAt(i).uri }
                    data.data != null -> arrayOf(data.data!!)
                    else -> null
                }
            } else null
            cb.onReceiveValue(uris)
        }

    private val speechLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val text = if (result.resultCode == RESULT_OK) {
                result.data?.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)
                    ?.firstOrNull() ?: ""
            } else ""
            val payload = org.json.JSONObject.quote(text)
            web.evaluateJavascript("window.onVoiceResult&&window.onVoiceResult($payload)", null)
        }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        web = WebView(this)
        setContentView(web)
        web.setBackgroundColor(ContextCompat.getColor(this, R.color.bg_dark))
        web.setLayerType(View.LAYER_TYPE_HARDWARE, null)

        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            // the web app lives at file:///android_asset/ and calls https APIs with fetch()
            @Suppress("DEPRECATION")
            allowUniversalAccessFromFileURLs = true
            @Suppress("DEPRECATION")
            allowFileAccessFromFileURLs = true
            mediaPlaybackRequiresUserGesture = false
            useWideViewPort = true
            loadWithOverviewMode = true
            cacheMode = WebSettings.LOAD_DEFAULT
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            setSupportZoom(false)
            javaScriptCanOpenWindowsAutomatically = true
            userAgentString = "$userAgentString RsAIHub/${BuildConfig.VERSION_NAME}"
        }
        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
            @Suppress("DEPRECATION")
            WebSettingsCompat.setForceDark(web.settings, WebSettingsCompat.FORCE_DARK_OFF)
        }
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)

        bridge = AndroidBridge(this)
        web.addJavascriptInterface(bridge, "AndroidBridge")

        web.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(m: ConsoleMessage): Boolean {
                android.util.Log.d("RsAIHub-JS", "${m.message()} @${m.lineNumber()}")
                return true
            }

            override fun onShowFileChooser(
                view: WebView?,
                callback: ValueCallback<Array<Uri>>?,
                params: FileChooserParams?
            ): Boolean {
                filePathCallback?.onReceiveValue(null)
                filePathCallback = callback
                val intent = params?.createIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                return try {
                    fileChooserLauncher.launch(intent)
                    true
                } catch (e: Exception) {
                    android.util.Log.e("RsAIHub", "file chooser failed", e)
                    filePathCallback = null
                    false
                }
            }
        }

        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val u = request.url.toString()
                // keep the app itself inside the WebView; open external links in browser
                return if (u.startsWith("file:///android_asset") || u.startsWith("https://appassets.androidplatform.net")) false
                else {
                    try { startActivity(Intent(Intent.ACTION_VIEW, request.url)) } catch (_: Exception) {}
                    true
                }
            }
        }

        // generated images: save straight to the Pictures/RS AI Hub folder
        web.setDownloadListener { url, _, _, _, _ -> bridge.saveImage(url, "") }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (web.canGoBack()) web.goBack() else moveTaskToBack(true)
            }
        })

        if (savedInstanceState == null) web.loadUrl("file:///android_asset/index.html")
        else web.restoreState(savedInstanceState)
    }

    fun startListening(lang: String) {
        try {
            val intent = Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, lang.ifEmpty { "si-LK" })
                putExtra(android.speech.RecognizerIntent.EXTRA_PROMPT, "RS AI Hub")
            }
            speechLauncher.launch(intent)
        } catch (e: Exception) {
            android.util.Log.e("RsAIHub", "speech input unavailable", e)
            web.evaluateJavascript(
                "window.onVoiceResult&&window.onVoiceResult(\"\",\"unsupported\")", null
            )
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        web.saveState(outState)
    }

    override fun onResume() {
        super.onResume()
        web.onResume()
        web.resumeTimers()
    }

    override fun onPause() {
        web.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        bridge.destroy()
        web.destroy()
        super.onDestroy()
    }
}
