package app.quanlytao.user.widget

import android.appwidget.AppWidgetManager
import android.widget.TextView
import app.quanlytao.user.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetTest {
    @Test
    fun testWidgetCountAndDeepLink() {
        val context = RuntimeEnvironment.getApplication()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(context))
        val id = manager.createWidget(BankInboxWidget::class.java, R.layout.bank_inbox_widget)

        // 1. Not logged in
        WidgetCache.clear(context)
        BankInboxWidget.update(context)
        val viewNotLoggedIn = manager.getViewFor(id)
        assertEquals("—", viewNotLoggedIn.findViewById<TextView>(R.id.inbox_count).text.toString())
        assertEquals("Mở Quản lý Tao để đăng nhập", viewNotLoggedIn.findViewById<TextView>(R.id.inbox_status).text.toString())

        // 2. Logged in, 0 pending
        WidgetCache.setPendingCount(context, 0)
        BankInboxWidget.update(context)
        val viewZero = manager.getViewFor(id)
        assertEquals("✓", viewZero.findViewById<TextView>(R.id.inbox_count).text.toString())
        assertEquals("Không có giao dịch cần phân loại", viewZero.findViewById<TextView>(R.id.inbox_status).text.toString())

        // 3. Logged in, 5 pending
        WidgetCache.setPendingCount(context, 5)
        BankInboxWidget.update(context)
        val viewFive = manager.getViewFor(id)
        assertEquals("5", viewFive.findViewById<TextView>(R.id.inbox_count).text.toString())
        assertEquals("Có 5 giao dịch cần phân loại", viewFive.findViewById<TextView>(R.id.inbox_status).text.toString())

        // 4. Tap root opens deep link quanlytao://bank-inbox
        viewFive.findViewById<android.view.View>(R.id.inbox_root).performClick()
        val nextIntent = Shadows.shadowOf(context).nextStartedActivity
        assertEquals("quanlytao://bank-inbox", nextIntent.dataString)
    }
}
