package app.personalfinance.finance_android.banknotification

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class BankNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        ListenerConnection.setConnected(this, true)
        val prefs = BankInbox.preferences(this)
        if (!prefs.getBoolean("capture", false) || BankInbox.owner(this) == null) return
        // Only currently visible notifications can be recovered; no history scraping.
        // Reuse the exact source filter and fingerprint-based deduplication.
        runCatching {
            val enabledAt = prefs.getLong("capture_enabled_at", 0L)
            activeNotifications?.filter { it.postTime >= enabledAt }?.forEach(::onNotificationPosted)
        }
    }
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        ListenerConnection.setConnected(this, false)
        ListenerConnection.ensureBound(this)
    }
    override fun onDestroy() {
        ListenerConnection.setConnected(this, false)
        super.onDestroy()
    }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val prefs = BankInbox.preferences(this)
            if (!prefs.getBoolean("capture", false) || BankInbox.owner(this) == null) return
            val source = BankSourceRegistry.identify(sbn.packageName, null, prefs) ?: return
            // Source filtering happens BEFORE touching notification extras.
            val expectedOwner = BankInbox.owner(this)
            val extracted = NotificationExtractor.extract(sbn, source.name)
            BankInbox.executor.execute {
                runCatching {
                    if (BankInbox.owner(applicationContext) == expectedOwner && BankSourceRegistry.identify(extracted.packageName, null, BankInbox.preferences(applicationContext)) != null)
                        BankInbox.capture(applicationContext, source, extracted)
                }.onFailure {
                    if (BankInbox.owner(applicationContext) == expectedOwner)
                        BankInbox.recordOutcome(applicationContext, "error")
                }
                // No notification payload or exception text is logged.
            }
        } catch (_: Exception) { /* Malformed extras must not crash the listener. */ }
    }
}
