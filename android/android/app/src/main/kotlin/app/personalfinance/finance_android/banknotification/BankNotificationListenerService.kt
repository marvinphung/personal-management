package app.personalfinance.finance_android.banknotification

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class BankNotificationListenerService : NotificationListenerService() {
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
                }
                // No notification payload or exception text is logged.
            }
        } catch (_: Exception) { /* Malformed extras must not crash the listener. */ }
    }
}
