package com.moss.gallery

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val NOTIFICATION_PERMISSION_CODE = 1001
        private const val CHANNEL_ID = "moss_updates"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Moss is fully offline: this channel only reads local disk stats.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moss.storage",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getFreeSpace") {
                try {
                    val stat = StatFs(Environment.getExternalStorageDirectory().path)
                    result.success(stat.availableBytes)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not read free space", null)
                }
            } else {
                result.notImplemented()
            }
        }
        // Local notifications only: completion/failure events, no server.
        // Framework APIs only (NotificationManager) — no extra dependency.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moss.notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Moss"
                    val body = call.argument<String>("body") ?: ""
                    showNotification(id, title, body)
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showNotification(id: Int, title: String, body: String) {
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Moss updates",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description =
                    "Finished exports and scans, and photo library problems."
            }
            manager.createNotificationChannel(channel)
        }
        val intent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()
        manager.notify(id, notification)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Android 12 and older: notifications are on by default.
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        // Ask once; the answer comes back in onRequestPermissionsResult.
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
