package com.kssoft.dashcam

import android.media.MediaScannerConnection
import android.os.StatFs
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
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
                    "getFreeDiskSpace" -> {
                        try {
                            val path = Environment.getExternalStorageDirectory().path
                            val stat = StatFs(path)
                            // Use getBlockSizeLong and getAvailableBlocksLong which are available since API 18.
                            // Our minSdk is 26, so this is safe.
                            val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
                            result.success(bytesAvailable)
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", "Failed to get storage info", e.message)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
