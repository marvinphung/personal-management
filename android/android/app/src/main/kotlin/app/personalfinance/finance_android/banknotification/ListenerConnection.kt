package app.personalfinance.finance_android.banknotification

import android.content.ComponentName
import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService

/** Permission and live binding are different. Never persist a 'connected' flag:
 * a process killed by Android cannot clear it. No notification content is stored. */
object ListenerConnection {
    @Volatile var connected = false
        private set
    private var lastRequest: Long? = null
    fun hasAccess(context: Context): Boolean {
        val component = ComponentName(context, BankNotificationListenerService::class.java)
        return Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            ?.split(':')?.any { ComponentName.unflattenFromString(it) == component } == true
    }
    fun setConnected(context: Context, value: Boolean) {
        connected = value
        if (value) lastRequest = null
        BankInbox.notifyStatus()
    }
    @Synchronized fun ensureBound(context: Context, force: Boolean = false) {
        val prefs = BankInbox.preferences(context)
        if (connected || BankInbox.owner(context) == null || !prefs.getBoolean("capture", false) || !hasAccess(context)) return
        val now = SystemClock.elapsedRealtime()
        if (!force && lastRequest?.let { now - it < 30_000 } == true) return
        lastRequest = now
        runCatching { NotificationListenerService.requestRebind(ComponentName(context, BankNotificationListenerService::class.java)) }
    }
}
