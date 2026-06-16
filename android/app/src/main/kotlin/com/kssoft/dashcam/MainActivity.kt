package com.kssoft.dashcam

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "media_scanner"

    // Android 15 (SDK 35) makes apps edge-to-edge by default.
    // The previous compilation errors were due to library dependency issues.
    // In FlutterActivity, you don't typically need to manually call enableEdgeToEdge()
    // because the Flutter engine handles the window configuration. 
    // We revert to a clean MainActivity to ensure the build succeeds.

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null,
                            { _, _ -> }
                        )
                    }
                    result.success(null)
                }
            }
    }
}
