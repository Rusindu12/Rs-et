package com.cryptoai.pro

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.widget.Toast
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Locale

/**
 * `window.AndroidBridge` — the native API the HTML app calls.
 * Every method is synchronous and returns a String/primitive; JS gets results directly.
 * Overloads are provided so slightly different call shapes from the HTML still work.
 */
class AndroidBridge(private val activity: MainActivity) {
    private val ctx: Context = activity.applicationContext
    private val binance = Binance(ctx)
    private val bybit = Bybit(ctx)
    private val prefs = ctx.getSharedPreferences("bridge", Context.MODE_PRIVATE)
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var notifSeq = 2000

    init {
        tts = TextToSpeech(ctx) { st ->
            ttsReady = st == TextToSpeech.SUCCESS
            if (ttsReady) tts?.language = Locale.US
        }
    }

    // ---------- generic ----------
    @JavascriptInterface fun apiBase(): String = prefs.getString("apiBase", "") ?: ""
    @JavascriptInterface fun setApiBase(url: String) { prefs.edit().putString("apiBase", url).apply() }
    @JavascriptInterface fun version(): String = BuildConfig.VERSION_NAME
    @JavascriptInterface fun isAndroid(): Boolean = true

    @JavascriptInterface fun getPref(key: String): String = prefs.getString("kv_$key", "") ?: ""
    @JavascriptInterface fun setPref(key: String, value: String) { prefs.edit().putString("kv_$key", value).apply() }

    @JavascriptInterface fun httpGet(url: String): String = Net.get(url)
    @JavascriptInterface fun httpGet(url: String, headersJson: String): String = Net.get(url, Net.parseHeaders(headersJson))
    @JavascriptInterface fun httpPost(url: String, body: String): String = Net.request("POST", url, body)
    @JavascriptInterface fun httpPost(url: String, body: String, headersJson: String): String =
        Net.request("POST", url, body, Net.parseHeaders(headersJson))
    @JavascriptInterface fun httpRequest(method: String, url: String, body: String, headersJson: String): String =
        Net.request(method, url, body.ifEmpty { null }, Net.parseHeaders(headersJson))

    // ---------- Binance ----------
    @JavascriptInterface fun binanceSaveKeys(key: String, secret: String) = binance.saveKeys(key, secret, binance.testnet)
    @JavascriptInterface fun binanceSaveKeys(key: String, secret: String, testnet: Boolean) = binance.saveKeys(key, secret, testnet)
    @JavascriptInterface fun binanceClearKeys() = binance.clearKeys()
    @JavascriptInterface fun binanceStatus(): String = binance.status()
    @JavascriptInterface fun binanceHasKeys(): Boolean = binance.hasKeys
    @JavascriptInterface fun binanceSyncTime(): Long = binance.syncTime()
    @JavascriptInterface fun binancePublic(path: String): String = binance.public(path, null)
    @JavascriptInterface fun binancePublic(path: String, paramsJson: String): String = binance.public(path, paramsJson)
    @JavascriptInterface fun binanceSigned(method: String, path: String): String = binance.signed(method, path, null)
    @JavascriptInterface fun binanceSigned(method: String, path: String, paramsJson: String): String = binance.signed(method, path, paramsJson)

    // ---------- Bybit ----------
    @JavascriptInterface fun bybitSaveKeys(key: String, secret: String) = bybit.saveKeys(key, secret, bybit.testnet)
    @JavascriptInterface fun bybitSaveKeys(key: String, secret: String, testnet: Boolean) = bybit.saveKeys(key, secret, testnet)
    @JavascriptInterface fun bybitClearKeys() = bybit.clearKeys()
    @JavascriptInterface fun bybitStatus(): String = bybit.status()
    @JavascriptInterface fun bybitHasKeys(): Boolean = bybit.hasKeys
    @JavascriptInterface fun bybitSyncTime(): Long = bybit.syncTime()
    @JavascriptInterface fun bybitPublic(path: String): String = bybit.public(path, null)
    @JavascriptInterface fun bybitPublic(path: String, paramsJson: String): String = bybit.public(path, paramsJson)
    @JavascriptInterface fun bybitSigned(method: String, path: String): String = bybit.signed(method, path, null)
    @JavascriptInterface fun bybitSigned(method: String, path: String, paramsJson: String): String = bybit.signed(method, path, paramsJson)

    // ---------- UX ----------
    @JavascriptInterface fun toast(msg: String) {
        activity.runOnUiThread { Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show() }
    }

    @JavascriptInterface fun haptic() = haptic(40)
    @JavascriptInterface fun haptic(ms: Int) {
        try {
            val v: Vibrator = if (Build.VERSION.SDK_INT >= 31)
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            else @Suppress("DEPRECATION") ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createOneShot(ms.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
            else @Suppress("DEPRECATION") v.vibrate(ms.toLong())
        } catch (_: Exception) {}
    }

    @JavascriptInterface fun speak(text: String) {
        if (!ttsReady) return
        tts?.speak(text, TextToSpeech.QUEUE_ADD, null, "cryptoai_${System.nanoTime()}")
    }
    @JavascriptInterface fun stopSpeaking() { tts?.stop() }

    @JavascriptInterface fun notifySignal(text: String) = notifySignal("CryptoAI Signal", text)
    @JavascriptInterface fun notifySignal(title: String, text: String) {
        BotService.createChannels(ctx)
        val n = NotificationCompat.Builder(ctx, BotService.CH_SIGNAL)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(title).setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH).setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL).build()
        try { ctx.getSystemService(NotificationManager::class.java).notify(notifSeq++, n) } catch (_: SecurityException) {}
    }

    @JavascriptInterface fun setKeepScreenOn(on: Boolean) {
        activity.runOnUiThread {
            if (on) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    // ---------- background bot ----------
    @JavascriptInterface fun startBgService() = startBgService("Trading bot running")
    @JavascriptInterface fun startBgService(text: String) {
        prefs.edit().putBoolean("bg", true).apply()
        activity.runOnUiThread { BotService.start(ctx, text) }
    }
    @JavascriptInterface fun stopBgService() {
        prefs.edit().putBoolean("bg", false).apply()
        activity.runOnUiThread { BotService.stop(ctx) }
    }
    @JavascriptInterface fun isBgServiceRunning(): Boolean = prefs.getBoolean("bg", false)

    @JavascriptInterface fun setAutoOn(on: Boolean) {
        prefs.edit().putBoolean("auto", on).apply()
        if (on) startBgService("Auto-trading ON") else stopBgService()
    }
    @JavascriptInterface fun isAutoOn(): Boolean = prefs.getBoolean("auto", false)

    @JavascriptInterface fun setTradingActive(active: Boolean) {
        prefs.edit().putBoolean("trading", active).apply()
        setKeepScreenOn(active)
        if (active) startBgService("Trading active") else if (!isAutoOn()) stopBgService()
    }
    @JavascriptInterface fun isTradingActive(): Boolean = prefs.getBoolean("trading", false)

    @JavascriptInterface fun updateTradeStatus(text: String) {
        if (isBgServiceRunning()) activity.runOnUiThread { BotService.update(ctx, text) }
    }
    @JavascriptInterface fun updateTradeStatus(json: String, extra: String) = updateTradeStatus("$json $extra")

    @JavascriptInterface fun exitApp() { activity.runOnUiThread { activity.finishAffinity() } }

    fun destroy() { tts?.stop(); tts?.shutdown() }
}
