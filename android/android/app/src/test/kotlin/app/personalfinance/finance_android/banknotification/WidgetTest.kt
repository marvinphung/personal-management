package app.personalfinance.finance_android.banknotification

import android.appwidget.AppWidgetManager
import android.widget.TextView
import app.personalfinance.finance_android.R
import app.personalfinance.finance_android.banknotification.database.BankDraftDatabase
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class WidgetTest {
    private fun <T> native(block: () -> T): T = BankInbox.executor.submit<T> { block() }.get(10, TimeUnit.SECONDS)
    @Test fun widgetCountUpdatesAndTapUsesInboxIntentWithoutFlutter() {
        val context = RuntimeEnvironment.getApplication()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(context))
        native { BankInbox.setOwner(context, "widget-user"); BankInbox.preferences(context).edit().putBoolean("capture", true).commit() }
        val id = manager.createWidget(BankInboxWidget::class.java, R.layout.bank_inbox_widget)
        try {
            native { BankInboxWidget.update(context) }
            assertEquals("✓", manager.getViewFor(id).findViewById<TextView>(R.id.inbox_count).text.toString())
            native {
                BankInbox.capture(context, BankSourceRegistry.sources.first(), ExtractedNotification("com.mbmobile", "MB Bank", "key", 1, null,
                    "GD: +40,000VND 13/09/26 20:56\nSD: 3,288,066VND", 1790000000000))
            }
            assertEquals("1", manager.getViewFor(id).findViewById<TextView>(R.id.inbox_count).text.toString())
            manager.getViewFor(id).findViewById<android.view.View>(R.id.inbox_root).performClick()
            assertEquals(BankInboxWidget.OPEN_INBOX, Shadows.shadowOf(context).nextStartedActivity.action)
            native {
                val dao = BankDraftDatabase.get(context).drafts()
                dao.finish("widget-user", dao.pending("widget-user").single().id, "confirmed", 2)
                BankInbox.changed(context)
            }
            assertEquals("✓", manager.getViewFor(id).findViewById<TextView>(R.id.inbox_count).text.toString())
        } finally { native { BankInbox.setOwner(context, null) } }
    }
}
