package com.example.flutter_application_1

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/storage"
    private val PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestStoragePermission" -> handleRequestStoragePermission(result)
                "getExternalDownloads" -> handleGetExternalDownloads(result)
                "insertMediaStore" -> handleInsertMediaStore(call.arguments as Map<*, *>, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleRequestStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
            // Android 10+ 使用 MediaStore，不需要此权限
            result.success(true)
            return
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            PERMISSION_REQUEST_CODE
        )

        // 通过 onRequestPermissionsResult 回调需要额外逻辑，这里先返回 true 让调用方尝试写入
        result.success(true)
    }

    private fun handleGetExternalDownloads(result: MethodChannel.Result) {
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        result.success(dir.absolutePath)
    }

    private fun handleInsertMediaStore(args: Map<*, *>, result: MethodChannel.Result) {
        val fileName = args["fileName"] as? String ?: run {
            result.error("INVALID_ARGS", "fileName is required", null)
            return
        }
        val mimeType = args["mimeType"] as? String ?: "application/octet-stream"
        val isMedia = args["isMedia"] as? Boolean ?: false
        val tempFilePath = args["tempFilePath"] as? String ?: run {
            result.error("INVALID_ARGS", "tempFilePath is required", null)
            return
        }

        val tempFile = File(tempFilePath)
        if (!tempFile.exists()) {
            result.error("FILE_NOT_FOUND", "Temp file not found: $tempFilePath", null)
            return
        }

        try {
            val resolver = contentResolver
            val collection: Uri
            val relativePath: String

            if (isMedia) {
                if (mimeType.startsWith("video/")) {
                    collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }
                relativePath = Environment.DIRECTORY_MOVIES + "/Z-Files"
            } else {
                collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                relativePath = Environment.DIRECTORY_DOWNLOADS + "/Z-Files"
            }

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }

            val uri = resolver.insert(collection, values)
            if (uri != null) {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    tempFile.inputStream().use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                result.success(uri.toString())
            } else {
                result.error("INSERT_FAILED", "Failed to insert into MediaStore", null)
            }
        } catch (e: Exception) {
            result.error("MEDIASTORE_ERROR", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 简单处理，不做额外回调
    }
}
