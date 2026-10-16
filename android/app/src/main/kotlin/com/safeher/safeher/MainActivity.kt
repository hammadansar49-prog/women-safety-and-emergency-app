package com.safeher.safeher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import android.app.KeyguardManager
import android.content.Context

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var mode = "off"
    private var selected = "volumeUp"
    private var downAt = 0L
    private var lastUp = 0L
    private var resumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/shortcut")
        channel.setMethodCallHandler { call, result ->
            if (call.method != "configure") {
                result.notImplemented()
            } else {
                val key = call.argument<String>("key")
                val requestedMode = call.argument<String>("mode")
                if (key !in listOf("volumeUp", "volumeDown") || requestedMode !in listOf("off", "test", "armed")) {
                    result.error("invalid", "Invalid shortcut", null)
                } else {
                    selected = key!!
                    mode = requestedMode!!
                    downAt = 0L
                    lastUp = 0L
                    result.success(null)
                }
            }
        }
    }
    override fun onResume() { super.onResume(); resumed = true }
    override fun onPause() {
        resumed = false
        downAt = 0L
        lastUp = 0L
        super.onPause()
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
                    channel.invokeMethod("doublePress", selected)
                } else lastUp = event.eventTime
            } else lastUp = 0L
            downAt = 0L
        }
        return true
    }
}
