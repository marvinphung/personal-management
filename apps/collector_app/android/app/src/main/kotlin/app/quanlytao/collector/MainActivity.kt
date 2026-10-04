package app.quanlytao.collector

import android.content.Intent
import android.provider.Settings
import app.quanlytao.collector.capture.ListenerConnection
import app.quanlytao.collector.config.CollectorPreferences
import app.quanlytao.collector.queue.CollectorDatabase
import app.quanlytao.collector.queue.UploadWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.quanlytao.collector/status",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureBackend" -> {
                    try {
                        val url = call.argument<String>("url")
                            ?: throw IllegalArgumentException("Missing backend URL")
                        CollectorPreferences.setBackendUrl(this, url)
                        result.success(null)
                    } catch (error: IllegalArgumentException) {
                        result.error("INVALID_BACKEND_URL", error.message, null)
                    }
                }
                "getCollectorHealth" -> result.success(
                    mapOf(
                        "permission_granted" to ListenerConnection.isPermissionGranted(this),
                        "listener_connected" to ListenerConnection.connected,
                        "queue_size" to CollectorDatabase.getInstance(this).getQueueSize(),
                        "backend_configured" to (CollectorPreferences.getBackendUrl(this) != null),
                        "credential_configured" to CollectorPreferences.hasCredential(this),
                    ),
                )
                "reconnectListener" -> {
                    ListenerConnection.ensureBound(this)
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "drainQueue" -> {
                    UploadWorker.schedule(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
