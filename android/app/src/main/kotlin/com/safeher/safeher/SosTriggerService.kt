package com.safeher.safeher

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.VolumeProviderCompat

/**
 * Foreground service that watches for a rapid hardware volume-key pattern while
 * SafeHer is backgrounded or the phone is locked, and launches the SOS flow when
 * the pattern is seen.
 *
 * Volume keys cannot be observed from a backgrounded Activity, so the service
 * holds an active [MediaSessionCompat] whose volume is "remote" (a
 * [VolumeProviderCompat]). While that session appears to be playing, the system
 * routes hardware volume-key presses to [VolumeProviderCompat.onAdjustVolume]
 * even with the screen off. This is a well-known pattern; it depends on the
 * session staying the active media session, which is OEM-dependent and must be
 * verified on a physical device.
 *
 * The same pattern pressed again while an SOS is active is the hidden cancel
 * gesture — detection itself does not distinguish start from cancel; the Dart
 * side decides based on current SOS state, so nothing about cancelling is ever
 * shown on screen.
 */
class SosTriggerService : Service() {

    companion object {
        const val ACTION_ARM = "com.safeher.safeher.ARM"
        const val ACTION_DISARM = "com.safeher.safeher.DISARM"
        const val EXTRA_KEY = "key"          // "volumeUp" | "volumeDown"
        const val EXTRA_PRESSES = "presses"  // Int, required rapid presses
        const val EXTRA_WINDOW_MS = "windowMs" // Long, pattern window

        private const val CHANNEL_ID = "safeher_sos_arm"
        private const val NOTIFICATION_ID = 7310

        // Guards against the launched Activity relaunching the service in a loop.
        @Volatile
        var armed: Boolean = false
            private set
    }

    private var session: MediaSessionCompat? = null
    private var selectedKey: String = "volumeUp"
    private var requiredPresses: Int = 3
    private var windowMs: Long = 2000L

    private val pressTimes = ArrayDeque<Long>()
    private var lastTriggerAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISARM -> {
                stopArming()
                return START_NOT_STICKY
            }
            else -> {
                selectedKey = intent?.getStringExtra(EXTRA_KEY) ?: "volumeUp"
                requiredPresses = (intent?.getIntExtra(EXTRA_PRESSES, 3) ?: 3).coerceIn(2, 8)
                windowMs = (intent?.getLongExtra(EXTRA_WINDOW_MS, 2000L) ?: 2000L)
                    .coerceIn(800L, 5000L)
                startArming()
            }
        }
        // Keep the service alive so the trigger survives memory pressure.
        return START_STICKY
    }

    private fun startArming() {
        startForegroundSafely()
        if (session == null) {
            session = MediaSessionCompat(this, "SafeHerSos").apply {
                setPlaybackState(
                    PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PLAYING, 0, 0f)
                        .setActions(0)
                        .build()
                )
                setPlaybackToRemote(volumeProvider)
                isActive = true
            }
        }
        pressTimes.clear()
        armed = true
    }

    private fun stopArming() {
        armed = false
        session?.apply {
            isActive = false
            release()
        }
        session = null
        pressTimes.clear()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private val volumeProvider: VolumeProviderCompat =
        object : VolumeProviderCompat(VOLUME_CONTROL_RELATIVE, 100, 50) {
            override fun onAdjustVolume(direction: Int) {
                // +1 up, -1 down, 0 is a release/no-op.
                val wantUp = selectedKey == "volumeUp"
                val matches = (wantUp && direction > 0) || (!wantUp && direction < 0)
                if (!matches) {
                    // A press of the other key breaks the pattern.
                    if (direction != 0) pressTimes.clear()
                    return
                }
                registerPress()
            }
        }

    private fun registerPress() {
        val now = SystemClock.elapsedRealtime()
        // Drop presses outside the rolling window.
        while (pressTimes.isNotEmpty() && now - pressTimes.first() > windowMs) {
            pressTimes.removeFirst()
        }
        pressTimes.addLast(now)
        if (pressTimes.size >= requiredPresses) {
            pressTimes.clear()
            // Debounce so one long salvo does not fire repeatedly.
            if (now - lastTriggerAt < 3000L) return
            lastTriggerAt = now
            fireTrigger()
        }
    }

    private fun fireTrigger() {
        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_SOS_TRIGGER, true)
        }
        startActivity(launch)
    }

    private fun startForegroundSafely() {
        ensureChannel()
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pending = PendingIntent.getActivity(this, 0, tapIntent, flags)
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SafeHer SOS ready")
            .setContentText("Volume-button SOS shortcut is active.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pending)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SOS shortcut",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps the volume-button SOS shortcut ready in the background."
                setShowBadge(false)
            }
            mgr.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        session?.release()
        session = null
        armed = false
        super.onDestroy()
    }
}
