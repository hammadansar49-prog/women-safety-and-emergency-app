package com.safeher.safeher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.app.KeyguardManager
import android.content.Context

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_SOS_TRIGGER = "safeher.SOS_TRIGGER"
    }

    private var channel: MethodChannel? = null
    private var mode = "off"
    private var selected = "volumeUp"
    private var downAt = 0L
    private var lastUp = 0L
    private var resumed = false

    // A trigger that arrived (via the background service) before Flutter was
    // ready to receive it. Flutter drains this with `consumePendingTrigger`.
    private var pendingTrigger = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, SosMediaService::class.java).apply {
                            action = SosMediaService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        startService(
                            Intent(this, SosMediaService::class.java).apply {
                                action = SosMediaService.ACTION_STOP
                            },
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/shortcut")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val key = call.argument<String>("key")
                    val requestedMode = call.argument<String>("mode")
                    if (key !in listOf("volumeUp", "volumeDown") ||
                        requestedMode !in listOf("off", "test", "armed")
                    ) {
                        result.error("invalid", "Invalid shortcut", null)
                    } else {
                        selected = key!!
                        mode = requestedMode!!
                        downAt = 0L
                        lastUp = 0L
                        result.success(null)
                    }
                }
                "startBackgroundArm" -> {
                    val key = call.argument<String>("key") ?: "volumeUp"
                    val presses = call.argument<Int>("presses") ?: 3
                    val windowMs = (call.argument<Int>("windowMs") ?: 2000).toLong()
                    if (key !in listOf("volumeUp", "volumeDown")) {
                        result.error("invalid", "Invalid key", null)
                    } else {
                        val intent = Intent(this, SosTriggerService::class.java).apply {
                            action = SosTriggerService.ACTION_ARM
                            putExtra(SosTriggerService.EXTRA_KEY, key)
                            putExtra(SosTriggerService.EXTRA_PRESSES, presses)
                            putExtra(SosTriggerService.EXTRA_WINDOW_MS, windowMs)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                }
                "stopBackgroundArm" -> {
                    val intent = Intent(this, SosTriggerService::class.java).apply {
                        action = SosTriggerService.ACTION_DISARM
                    }
                    startService(intent)
                    result.success(null)
                }
                "consumePendingTrigger" -> {
                    val had = pendingTrigger
                    pendingTrigger = false
                    result.success(had)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleTriggerIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        handleTriggerIntent(intent)
    }

    override fun onPause() {
        resumed = false
        downAt = 0L
        lastUp = 0L
        super.onPause()
    }

    private fun handleTriggerIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_SOS_TRIGGER, false) != true) return
        // Consume so a configuration change or revisit does not refire it.
        intent.removeExtra(EXTRA_SOS_TRIGGER)
        val ch = channel
        if (ch != null && resumed) {
            ch.invokeMethod("backgroundSos", null)
        } else {
            pendingTrigger = true
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val locked = (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
        val key = if (selected == "volumeUp") KeyEvent.KEYCODE_VOLUME_UP else KeyEvent.KEYCODE_VOLUME_DOWN
        if (mode == "off" || !resumed || !hasWindowFocus() || locked || event.keyCode != key) {
            lastUp = 0L
            return super.dispatchKeyEvent(event)
        }
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) downAt = event.eventTime
        if (event.action == KeyEvent.ACTION_UP) {
            if (downAt != 0L && event.eventTime - downAt < 400 && !event.isCanceled) {
                if (lastUp != 0L && event.eventTime - lastUp <= 600) {
                    lastUp = 0L
                    if (mode == "test") mode = "off"
                    channel?.invokeMethod("doublePress", selected)
                } else lastUp = event.eventTime
            } else lastUp = 0L
            downAt = 0L
        }
        return true
    }
}
