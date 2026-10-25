package com.marsa.clinic.marsa_app

import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for Huawei MatePad PaperMatte & Huawei M-Pencil (2nd/3rd Gen).
 *
 * Captures:
 * 1. M-Pencil double-tap barrel gesture (mapped by HarmonyOS/EMUI to KEYCODE_F19 / KEYCODE_F20
 *    or stylus button keycodes).
 * 2. High-precision stylus hover & barrel button state changes via MotionEvent.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.marsa.clinic/stylus"
    private var stylusChannel: MethodChannel? = null
    private var lastBarrelPressed = false
    private var lastDoubleTapTimestamp = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        stylusChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Huawei M-Pencil double-tap gesture on HarmonyOS / MatePad sends keycode 189 (F19),
        // 190 (F20), or 718 (HarmonyOS internal M-Pencil double-tap keycode).
        if (keyCode == 189 ||
            keyCode == 190 ||
            keyCode == 718
        ) {
            triggerStylusDoubleTap("hardware_key_$keyCode")
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun dispatchGenericMotionEvent(ev: MotionEvent?): Boolean {
        if (ev != null && ev.isFromSource( android.view.InputDevice.SOURCE_STYLUS )) {
            val isBarrelPressed = (ev.buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0 ||
                    (ev.buttonState and MotionEvent.BUTTON_STYLUS_SECONDARY) != 0
            if (isBarrelPressed && !lastBarrelPressed) {
                triggerStylusDoubleTap("stylus_barrel_button")
            }
            lastBarrelPressed = isBarrelPressed
        }
        return super.dispatchGenericMotionEvent(ev)
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev != null && ev.pointerCount > 0) {
            val toolType = ev.getToolType(0)
            if (toolType == MotionEvent.TOOL_TYPE_STYLUS || toolType == MotionEvent.TOOL_TYPE_ERASER) {
                val isBarrelPressed = (ev.buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0 ||
                        (ev.buttonState and MotionEvent.BUTTON_STYLUS_SECONDARY) != 0
                if (isBarrelPressed && !lastBarrelPressed) {
                    triggerStylusDoubleTap("stylus_touch_button")
                }
                lastBarrelPressed = isBarrelPressed
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    private fun triggerStylusDoubleTap(source: String) {
        val now = System.currentTimeMillis()
        if (now - lastDoubleTapTimestamp < 250) return
        lastDoubleTapTimestamp = now
        runOnUiThread {
            stylusChannel?.invokeMethod(
                "onStylusDoubleTap",
                mapOf("source" to source, "timestamp" to now)
            )
        }
    }
}
