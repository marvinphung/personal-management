package app.quanlytao.collector

import android.content.Intent
import android.provider.Settings
import app.quanlytao.collector.capture.ListenerConnection
import app.quanlytao.collector.config.CollectorPreferences
import app.quanlytao.collector.config.CollectorCredentialStore
import app.quanlytao.collector.queue.CollectorDatabase
import app.quanlytao.collector.queue.UploadWorker
import app.quanlytao.collector.registry.CachedBinding
import app.quanlytao.collector.registry.RegistryStore
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
                        "binding_count" to RegistryStore.load(this).size,
                    ),
                )
                "activateCollector" -> {
                    try {
                        val token = call.argument<String>("collector_token")
                            ?: throw IllegalArgumentException("Missing collector token")
                        val epoch = call.argument<Number>("collector_epoch")?.toLong()
                            ?: throw IllegalArgumentException("Missing collector epoch")
                        val rawBindings = call.argument<List<Map<String, Any?>>>("bindings")
                            ?: emptyList()
                        val bindings = rawBindings.map { binding ->
                            CachedBinding(
                                bindingId = binding["binding_id"] as String,
                                bankCode = binding["bank_code"] as String,
                                accountNumber = binding["account_number"] as String,
                                bindingVersion = (binding["binding_version"] as Number).toInt(),
                                captureEpoch = (binding["capture_epoch"] as Number).toLong(),
                            )
                        }
                        CollectorCredentialStore.save(this, token)
                        RegistryStore.save(this, epoch, bindings)
                        UploadWorker.schedule(this)
                        result.success(mapOf("binding_count" to bindings.size))
                    } catch (error: Exception) {
                        CollectorCredentialStore.clear(this)
                        result.error("COLLECTOR_ACTIVATION_FAILED", error.message, null)
                    }
                }
                "reconnectListener" -> {
                    ListenerConnection.ensureBound(this)
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
