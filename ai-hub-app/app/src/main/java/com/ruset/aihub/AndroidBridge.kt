package com.ruset.aihub

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.speech.tts.TextToSpeech
import android.webkit.JavascriptInterface
import android.widget.Toast
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * `window.AndroidBridge` — the native API the HTML app calls.
 *
 * Everything here is optional: the web app feature-detects and falls back to
 * pure-web behaviour (browser download, web speech, in-page TTS) so the same
 * assets also run as a plain website.
 */
class AndroidBridge(private val activity: MainActivity) {
    private val ctx: Context = activity.applicationContext
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    init {
        tts = TextToSpeech(ctx) { st ->
            ttsReady = st == TextToSpeech.SUCCESS
            if (ttsReady) tts?.language = Locale.US
        }
    }

    fun destroy() {
        tts?.shutdown()
        tts = null
    }

    // ---------- generic ----------
    @JavascriptInterface fun isAndroid(): Boolean = true
    @JavascriptInterface fun version(): String = BuildConfig.VERSION_NAME

    @JavascriptInterface
    fun vibrate(ms: Int) {
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                val vm = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator.vibrate(VibrationEffect.createOneShot(ms.toLong().coerceAtMost(400), 80))
            } else {
                @Suppress("DEPRECATION")
                val v = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                v.vibrate(VibrationEffect.createOneShot(ms.toLong().coerceAtMost(400), 80))
            }
        } catch (_: Exception) {}
    }

    @JavascriptInterface
    fun toast(msg: String) {
        activity.runOnUiThread { Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show() }
    }

    // ---------- speech out (TTS) ----------
    @JavascriptInterface
    fun speak(text: String, lang: String) {
        activity.runOnUiThread {
            try {
                val t = tts ?: return@runOnUiThread
                if (lang.isNotEmpty()) t.language = Locale.forLanguageTag(lang)
                t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "rs-ai-hub")
            } catch (_: Exception) {}
        }
    }

    @JavascriptInterface
    fun stopSpeak() {
        activity.runOnUiThread { tts?.stop() }
    }

    // ---------- speech in (STT) ----------
    @JavascriptInterface
    fun listen(lang: String) {
        activity.startListening(lang.ifEmpty { "si-LK" })
    }

    // ---------- share ----------
    @JavascriptInterface
    fun shareText(title: String, text: String) {
        try {
            val i = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            activity.startActivity(Intent.createChooser(i, title.ifEmpty { "Share" }))
        } catch (_: Exception) {}
    }

    // ---------- save image to gallery ----------
    /** Accepts https URLs and data: URLs. Returns "ok" or an error string. */
    @JavascriptInterface
    fun saveImage(url: String, name: String): String {
        Thread {
            var status = "ok"
            try {
                val bytes = fetchBytes(url)
                val fileName = name.ifEmpty { "RSAIHub_${System.currentTimeMillis()}.png" }
                saveToPictures(bytes, fileName)
                activity.runOnUiThread {
                    Toast.makeText(ctx, "Image saved to Pictures ✓", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                status = e.message ?: "error"
                activity.runOnUiThread {
                    Toast.makeText(ctx, "Save failed: $status", Toast.LENGTH_SHORT).show()
                }
            }
        }.start()
        return "started"
    }

    private fun fetchBytes(url: String): ByteArray {
        if (url.startsWith("data:")) {
            val b64 = url.substringAfter("base64,", "")
            if (b64.isEmpty()) throw IllegalArgumentException("bad data url")
            return android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
        }
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 20000
        conn.readTimeout = 60000
        conn.instanceFollowRedirects = true
        try {
            if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode}")
            val out = ByteArrayOutputStream()
            conn.inputStream.use { input ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                }
            }
            return out.toByteArray()
        } finally {
            conn.disconnect()
        }
    }

    private fun saveToPictures(bytes: ByteArray, fileName: String) {
        val resolver = ctx.contentResolver
        val mime = if (fileName.endsWith(".jpg", true) || fileName.endsWith(".jpeg", true))
            "image/jpeg" else "image/png"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= 29) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/RS AI Hub")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri: Uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore insert failed")
        resolver.openOutputStream(uri).use { out ->
            if (out == null) throw IllegalStateException("no output stream")
            out.write(bytes)
        }
        if (Build.VERSION.SDK_INT >= 29) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }
}
