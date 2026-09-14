package app.personalfinance.finance_android.banknotification

import android.app.Notification
import android.os.Process
import android.service.notification.StatusBarNotification
import app.personalfinance.finance_android.R
import app.personalfinance.finance_android.banknotification.database.BankDraftDatabase
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ListenerTest {
    private fun <T> native(block: () -> T): T = BankInbox.executor.submit<T> { block() }.get(10, TimeUnit.SECONDS)
    @Test fun realListenerPersistsWithoutFlutterAndStopsOnLogout() {
        val context = RuntimeEnvironment.getApplication()
        val service = Robolectric.buildService(BankNotificationListenerService::class.java).create()
        fun notification(text: String, pkg: String = "com.mbmobile"): StatusBarNotification {
            val n = Notification.Builder(context, "test").setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("MB Bank").setContentText(text).build()
            return StatusBarNotification(pkg, pkg, 42, "test", 1000, 0, 0, n, Process.myUserHandle(), 1790000000000)
        }
        try {
            native { BankInbox.setOwner(context, "test-A"); BankInbox.preferences(context).edit().putBoolean("capture", true).putString("account.mbbank", "account-A").commit() }
            service.get().onNotificationPosted(notification("GD: +40,000VND 13/09/26 20:56\nSD: 3,288,066VND"))
            service.get().onNotificationPosted(notification("GD: +40,000VND 13/09/26 20:56\nSD: 3,288,066VND"))
            service.get().onNotificationPosted(notification("Số tiền GD: -527,778 VND\nKHÔNG THÀNH CÔNG"))
            service.get().onNotificationPosted(notification("GD: -19.99 USD", "com.unrelated.chat"))
            assertEquals(1, native { BankDraftDatabase.get(context).drafts().count("test-A") })
            val payload = native { BankDraftDatabase.get(context).drafts().pending("test-A").single().payload!! }
            assertFalse(payload.contains("3,288,066"))
            assertFalse(payload.contains("rawContent"))
            val snapshot = org.json.JSONObject(BankInbox.preferences(context).getString("balance.account-A", null)!!)
            assertEquals(3288066L, snapshot.getLong("amount"))
            service.get().onNotificationPosted(notification("GD: +10VND 12/09/26 20:56|SD: 100VND"))
            native { Unit }
            assertEquals(snapshot.toString(), BankInbox.preferences(context).getString("balance.account-A", null))
            service.get().onNotificationPosted(notification("GD: -19.99 USD 13/09/26 21:00"))
            assertEquals(3, native { BankDraftDatabase.get(context).drafts().count("test-A") })
            native { BankInbox.setOwner(context, null) }
            service.get().onNotificationPosted(notification("GD: -19.99 USD 13/09/26 22:00"))
            assertEquals(0, native { BankDraftDatabase.get(context).drafts().count("test-A") })
            assertNull(BankInbox.preferences(context).getString("balance.account-A", null))
            native { BankInbox.setOwner(context, "test-B") }
            assertFalse(BankInbox.preferences(context).getBoolean("capture", false))
            assertEquals(0, native { BankDraftDatabase.get(context).drafts().count("test-B") })
        } finally {
            native { BankInbox.setOwner(context, null) }
            service.destroy()
        }
    }
    @Test fun extractorDeduplicatesExpandedText() {
        val context = RuntimeEnvironment.getApplication()
        val text = "GD: +40,000VND\nSD: 3,288,066VND"
        val n = Notification.Builder(context, "test").setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text)).build()
        val sbn = StatusBarNotification("com.mbmobile", "com.mbmobile", 1, "test", 1000, 0, 0, n, Process.myUserHandle(), 1)
        assertEquals(text, NotificationExtractor.extract(sbn, "MB Bank").text)
    }
}
