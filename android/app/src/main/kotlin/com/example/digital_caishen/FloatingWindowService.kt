package com.example.digital_caishen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 系统级悬浮窗服务：
 * - 独立 FlutterEngine 渲染桌面宠物（floatingMain 入口）
 * - 通过 WindowManager 叠加到所有应用之上
 * - FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL：窗口不抢焦点（输入法/其他 App 正常），
 *   矩形内点击交给 Flutter（上香），矩形外触摸透传下层应用
 * - 原生处理拖拽，轻点（无位移）通过 MethodChannel 回调 Flutter 的 onClick
 */
class FloatingWindowService : Service() {

    private lateinit var flutterEngine: FlutterEngine
    private lateinit var channel: MethodChannel
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var params: WindowManager.LayoutParams? = null

    private var moveStartX = 0f
    private var moveStartY = 0f
    private var moveParamStartX = 0
    private var moveParamStartY = 0
    private var moved = false

    companion object {
        const val CHANNEL = "floating_window"
        const val NOTIF_ID = 1
        const val NOTIF_CHANNEL = "floating_service"

        // 默认悬浮窗尺寸（dp）
        const val DEFAULT_SIZE_DP = 220
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        flutterEngine = FlutterEngine(this)
        // 悬浮窗复用默认入口 main，但通过初始路由 "/floating" 区分渲染内容，
        // 避免依赖已被精简的 FlutterInjector / 自定义入口点 API。
        flutterEngine.navigationChannel.setInitialRoute("/floating")
        flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hide" -> {
                    removeOverlay()
                    result.success(true)
                }
                "moveTo" -> {
                    val x = (call.argument<Double>("x") ?: 0.0).toInt()
                    val y = (call.argument<Double>("y") ?: 0.0).toInt()
                    params?.let {
                        it.x = x
                        it.y = y
                        windowManager.updateViewLayout(overlayView, it)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())
        addOverlay()
        return START_STICKY
    }

    private fun addOverlay() {
        if (overlayView != null) return

        // 使用 FlutterTextureView 以支持真透明背景。
        val view = FlutterView(this, FlutterTextureView(this))
        view.attachToFlutterEngine(flutterEngine)
        view.setBackgroundColor(Color.TRANSPARENT)

        val sizePx = dp2px(DEFAULT_SIZE_DP)
        params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp2px(16)
            y = dp2px(120)
        }

        view.setOnTouchListener { _, event -> handleTouch(event) }
        overlayView = view
        windowManager.addView(view, params)
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager.removeView(it)
            overlayView = null
        }
    }

    private fun handleTouch(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                moveStartX = event.rawX
                moveStartY = event.rawY
                params?.let {
                    moveParamStartX = it.x
                    moveParamStartY = it.y
                }
                moved = false
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - moveStartX).toInt()
                val dy = (event.rawY - moveStartY).toInt()
                if (kotlin.math.abs(dx) > 5 || kotlin.math.abs(dy) > 5) moved = true
                params?.let {
                    it.x = moveParamStartX + dx
                    it.y = moveParamStartY + dy
                    windowManager.updateViewLayout(overlayView, it)
                }
            }
            MotionEvent.ACTION_UP -> {
                if (!moved) {
                    channel.invokeMethod("onClick", null)
                }
            }
        }
        return true
    }

    private fun dp2px(dp: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun buildNotification(): Notification {
        createChannel()
        return Notification.Builder(this, NOTIF_CHANNEL)
            .setContentTitle("财神驾到")
            .setContentText("悬浮窗运行中")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                NOTIF_CHANNEL,
                "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(chan)
        }
    }

    override fun onDestroy() {
        removeOverlay()
        if (::flutterEngine.isInitialized) flutterEngine.destroy()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
