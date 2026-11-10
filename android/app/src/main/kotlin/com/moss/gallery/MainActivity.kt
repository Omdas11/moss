package com.moss.gallery

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
