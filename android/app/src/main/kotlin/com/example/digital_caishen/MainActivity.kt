package com.example.digital_caishen

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "app_control"
        const val OVERLAY_REQ_CODE = 1001
    }

    private var pendingStart = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlay" -> {
                    result.success(canDrawOverlay())
                }
                "requestOverlayPermission" -> {
                    if (!canDrawOverlay()) {
                        pendingStart = call.argument<Boolean>("autostart") ?: false
                        requestOverlayPermission()
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "startFloating" -> {
                    if (canDrawOverlay()) {
                        startFloating()
                        result.success(true)
                    } else {
                        pendingStart = true
                        requestOverlayPermission()
                        result.success(false)
                    }
                }
                "stopFloating" -> {
                    stopFloating()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlay(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_REQ_CODE)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_REQ_CODE && canDrawOverlay() && pendingStart) {
            pendingStart = false
            startFloating()
        }
    }

    private fun startFloating() {
        val intent = Intent(this, FloatingWindowService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopFloating() {
        stopService(Intent(this, FloatingWindowService::class.java))
    }
}
