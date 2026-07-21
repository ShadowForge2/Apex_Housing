package com.apex.apex_admin

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.apexhousing/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isJailbroken" -> result.success(checkJailbroken())
                    "isDebugged" -> result.success(checkDebugger())
                    "isEmulator" -> result.success(checkEmulator())
                    "getAppSignature" -> result.success(getAppSignature())
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkJailbroken(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }

        try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = process.inputStream.bufferedReader()
            if (reader.readLine() != null) return true
        } catch (_: Exception) {}

        return false
    }

    private fun checkDebugger(): Boolean {
        return try {
            val clazz = Class.forName("android.os.Debug")
            val method = clazz.getMethod("isDebuggerConnected")
            method.invoke(null) as Boolean
        } catch (_: Exception) {
            false
        }
    }

    private fun checkEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu"))
    }

    private fun getAppSignature(): String {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNATURES)
            }
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            if (signatures == null || signatures.isEmpty()) return "unknown"
            val md = java.security.MessageDigest.getInstance("SHA-256")
            md.update(signatures[0].toByteArray())
            val bytes = md.digest()
            bytes.joinToString("") { "%02x".format(it) }
        } catch (_: Exception) {
            "unknown"
        }
    }
}
