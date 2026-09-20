package com.cryptoai.pro

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/** Foreground service: keeps the process (and the WebView JS timers) alive while the bot is running. */
class BotService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra("text") ?: "Trading bot running"
        createChannels(this)
        startForeground(NOTIF_ID, buildNotification(this, text))
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "cryptoai:bot").also { it.acquire() }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        const val CH_SERVICE = "bot_service"
        const val CH_SIGNAL = "signals"
        const val NOTIF_ID = 1001

        fun createChannels(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CH_SERVICE, "Bot service", NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel(CH_SIGNAL, "Trade signals", NotificationManager.IMPORTANCE_HIGH))
        }

        fun buildNotification(ctx: Context, text: String): Notification {
            val pi = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            return NotificationCompat.Builder(ctx, CH_SERVICE)
                .setSmallIcon(R.drawable.ic_notif)
                .setContentTitle("CryptoAI PRO")
                .setContentText(text)
                .setOngoing(true).setOnlyAlertOnce(true)
                .setContentIntent(pi).build()
        }

        fun start(ctx: Context, text: String) {
            val i = Intent(ctx, BotService::class.java).putExtra("text", text)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }
        fun stop(ctx: Context) = ctx.stopService(Intent(ctx, BotService::class.java))

        fun update(ctx: Context, text: String) {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.notify(NOTIF_ID, buildNotification(ctx, text))
        }
    }
}
