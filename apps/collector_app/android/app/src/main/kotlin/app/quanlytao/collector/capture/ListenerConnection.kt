package app.quanlytao.collector.capture

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService

object ListenerConnection {
    @Volatile
    var connected: Boolean = false
        private set

    fun setConnected(context: Context, isConnected: Boolean) {
        connected = isConnected
        val prefs = context.getSharedPreferences("collector_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("listener_connected", isConnected).apply()
    }

    fun isPermissionGranted(context: Context): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val myComponent = ComponentName(context, BankNotificationListenerService::class.java).flattenToString()
        return enabledListeners.split(":").any { it.equals(myComponent, ignoreCase = true) }
    }

    fun ensureBound(context: Context) {
        if (!isPermissionGranted(context)) return
        if (!connected) {
            try {
                NotificationListenerService.requestRebind(
                    ComponentName(context, BankNotificationListenerService::class.java)
                )
            } catch (e: Exception) {
                // Best effort rebind
            }
        }
    }
}
