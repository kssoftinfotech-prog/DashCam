package com.kssoft.dashcam

import android.media.MediaScannerConnection
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        arrayOf("video/mp4"),
                        { path, uri ->
                            // Optional: log or handle scan completion
                        }
                    )
                    result.success(null)
                }
            }
    }
}