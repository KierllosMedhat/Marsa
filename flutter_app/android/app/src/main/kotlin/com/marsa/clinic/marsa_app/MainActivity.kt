package com.marsa.clinic.marsa_app

import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native bridge for:
 * 1. Huawei MatePad PaperMatte & Huawei M-Pencil (2nd/3rd Gen) double-tap barrel gesture & stylus buttons.
 * 2. Online Over-The-Air (OTA) Self-Updating Engine:
 *    - In-App Native APK PackageInstaller via FileProvider + REQUEST_INSTALL_PACKAGES.
 *    - Instant Zero-Reinstall Live Cloud OTA WebView Container with M-Pencil hardware gesture forwarding.
 */
class MainActivity : FlutterActivity() {
    private val stylusChannelName = "com.marsa.clinic/stylus"
    private val updaterChannelName = "com.marsa.clinic/updater"

    private var stylusChannel: MethodChannel? = null
    private var updaterChannel: MethodChannel? = null

    private var lastBarrelPressed = false
    private var lastDoubleTapTimestamp = 0L

    // Pending APK path if the user needed to grant ACTION_MANAGE_UNKNOWN_APP_SOURCES first
    private var pendingInstallApkPath: String? = null

    // Live Cloud OTA WebView Overlay (Instant update without APK reinstall)
    private var liveCloudContainer: FrameLayout? = null
    private var liveCloudWebView: WebView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        stylusChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, stylusChannelName)
        updaterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannelName)

        updaterChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersionInfo" -> {
                    result.success(getNativeVersionInfo())
                }
                "canRequestPackageInstalls" -> {
                    result.success(canInstallUnknownPackages())
                }
                "openInstallPermissionSettings" -> {
                    openUnknownSourcesSettings()
                    result.success(true)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "مسار ملف التحديث غير صالح", null)
                    } else {
                        val status = triggerApkInstall(filePath)
                        result.success(status)
                    }
                }
                "launchLiveCloudOta" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "رابط التحديث السحابي غير صالح", null)
                    } else {
                        runOnUiThread {
                            showLiveCloudOtaOverlay(url)
                        }
                        result.success(true)
                    }
                }
                "exitLiveCloudOta" -> {
                    runOnUiThread {
                        hideLiveCloudOtaOverlay()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // If user just returned from granting "Install Unknown Apps" permission, resume APK installation automatically
        val pendingPath = pendingInstallApkPath
        if (pendingPath != null && canInstallUnknownPackages()) {
            pendingInstallApkPath = null
            triggerApkInstall(pendingPath)
        }
    }

    private fun getNativeVersionInfo(): Map<String, Any> {
        return try {
            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode
            }
            mapOf(
                "version" to (pkgInfo.versionName ?: "1.2.0"),
                "buildNumber" to versionCode,
                "packageName" to packageName,
                "canInstallPackages" to canInstallUnknownPackages(),
                "isLiveCloudActive" to (liveCloudContainer != null)
            )
        } catch (e: Exception) {
            mapOf(
                "version" to "1.2.0",
                "buildNumber" to 3,
                "packageName" to packageName,
                "canInstallPackages" to canInstallUnknownPackages(),
                "isLiveCloudActive" to (liveCloudContainer != null)
            )
        }
    }

    private fun canInstallUnknownPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownSourcesSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (e: Exception) {
                val fallback = Intent(Settings.ACTION_SECURITY_SETTINGS)
                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(fallback)
            }
        }
    }

    private fun triggerApkInstall(filePath: String): String {
        val apkFile = File(filePath)
        if (!apkFile.exists() || apkFile.length() < 1024) {
            return "file_not_found"
        }

        if (!canInstallUnknownPackages()) {
            pendingInstallApkPath = filePath
            runOnUiThread {
                Toast.makeText(
                    this,
                    "يرجى السماح بتثبيت التحديثات التلقائية لتطبيق عيادة مرساة",
                    Toast.LENGTH_LONG
                ).show()
            }
            openUnknownSourcesSettings()
            return "permission_requested"
        }

        return try {
            val authority = "$packageName.fileprovider"
            val apkUri: Uri = FileProvider.getUriForFile(this, authority, apkFile)

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                putExtra(Intent.EXTRA_INSTALLER_PACKAGE_NAME, packageName)
            }
            startActivity(installIntent)
            "installer_launched"
        } catch (e: Exception) {
            runOnUiThread {
                Toast.makeText(
                    this,
                    "تعذر فتح مثبت الحزمة: ${e.localizedMessage}",
                    Toast.LENGTH_LONG
                ).show()
            }
            "error: ${e.localizedMessage}"
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun showLiveCloudOtaOverlay(url: String) {
        val rootView = window.decorView.findViewById<ViewGroup>(android.R.id.content) ?: return

        // If already open, simply load the new URL
        if (liveCloudContainer != null && liveCloudWebView != null) {
            liveCloudWebView?.loadUrl(url)
            return
        }

        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#F9FBF7"))
        }

        val progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(4)
            ).apply {
                gravity = Gravity.TOP
            }
            max = 100
            progress = 15
        }

        val webView = WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                loadWithOverviewMode = true
                useWideViewPort = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                }
                userAgentString = "$userAgentString MarsaClinicNativeOTA/1.2.0"
            }

            addJavascriptInterface(object {
                @JavascriptInterface
                fun exitLiveMode() {
                    runOnUiThread { hideLiveCloudOtaOverlay() }
                }
            }, "MarsaNativeUpdater")

            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    progressBar.progress = newProgress
                    progressBar.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
                }
            }

            webViewClient = object : WebViewClient() {
                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: WebResourceError?
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) {
                        // Fallback to cached bundle or return to local native mode if completely offline
                        Toast.makeText(
                            this@MainActivity,
                            "تعذر الاتصال بالسحابة — جاري العودة لوضع التابلت المحلي",
                            Toast.LENGTH_SHORT
                        ).show()
                        hideLiveCloudOtaOverlay()
                    }
                }
            }
        }

        // Sleek floating pill in bottom-left corner to indicate Live Cloud OTA Mode & allow returning to Native Mode
        val pillLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(20).toFloat()
                setColor(Color.parseColor("#DD1B4F72"))
                setStroke(dpToPx(1), Color.parseColor("#B58728"))
            }
            elevation = dpToPx(6).toFloat()
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.START
                setMargins(dpToPx(14), dpToPx(14), dpToPx(14), dpToPx(14))
            }
        }

        val badgeText = TextView(this).apply {
            text = "☁️ النسخة السحابية المحدثة  •  وضع محلي"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
        }

        pillLayout.addView(badgeText)
        pillLayout.setOnClickListener {
            hideLiveCloudOtaOverlay()
            Toast.makeText(this, "تمت العودة إلى وضع التطبيق المحلي", Toast.LENGTH_SHORT).show()
        }

        container.addView(webView)
        container.addView(progressBar)
        container.addView(pillLayout)

        rootView.addView(container)
        liveCloudContainer = container
        liveCloudWebView = webView

        webView.loadUrl(url)
    }

    private fun hideLiveCloudOtaOverlay() {
        val rootView = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        liveCloudWebView?.let { wv ->
            wv.stopLoading()
            wv.destroy()
        }
        liveCloudContainer?.let { container ->
            rootView?.removeView(container)
        }
        liveCloudWebView = null
        liveCloudContainer = null
        updaterChannel?.invokeMethod("onLiveCloudOtaExited", null)
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Huawei M-Pencil double-tap gesture on HarmonyOS / MatePad sends keycode 189 (F19),
        // 190 (F20), or 718 (HarmonyOS internal M-Pencil double-tap keycode).
        if (keyCode == 189 || keyCode == 190 || keyCode == 718) {
            triggerStylusDoubleTap("hardware_key_$keyCode")
            return true
        }
        if (keyCode == KeyEvent.KEYCODE_BACK && liveCloudWebView != null) {
            if (liveCloudWebView?.canGoBack() == true) {
                liveCloudWebView?.goBack()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun dispatchGenericMotionEvent(ev: MotionEvent?): Boolean {
        if (ev != null && ev.isFromSource(InputDevice.SOURCE_STYLUS)) {
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
            // 1. Forward to Native Flutter Engine
            stylusChannel?.invokeMethod(
                "onStylusDoubleTap",
                mapOf("source" to source, "timestamp" to now)
            )
            // 2. Forward to Live Cloud OTA WebView if active
            liveCloudWebView?.evaluateJavascript(
                "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'F19', code: 'F19', keyCode: 189, bubbles: true }));",
                null
            )
        }
    }
}
