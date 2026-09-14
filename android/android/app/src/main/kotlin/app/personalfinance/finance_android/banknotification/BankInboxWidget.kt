package app.personalfinance.finance_android.banknotification

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import app.personalfinance.finance_android.MainActivity
import app.personalfinance.finance_android.R
import app.personalfinance.finance_android.banknotification.database.BankDraftDatabase

class BankInboxWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        BankInbox.executor.execute { try { update(context) } finally { pending?.finish() } }
    }
    companion object {
        const val OPEN_INBOX = "app.personalfinance.OPEN_BANK_INBOX"
        fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BankInboxWidget::class.java))
            if (ids.isEmpty()) return
            val owner = BankInbox.owner(context)
            val count = owner?.let { BankDraftDatabase.get(context).drafts().count(it) } ?: 0
            val vi = BankInbox.preferences(context).getString("language", "en") == "vi"
            val views = RemoteViews(context.packageName, R.layout.bank_inbox_widget)
            views.setTextViewText(R.id.inbox_title, if (vi) "Hộp thư giao dịch" else "Finance Inbox")
            views.setTextViewText(R.id.inbox_count, if (count == 0) "✓" else count.toString())
            views.setTextViewText(R.id.inbox_status, if (count == 0) { if (vi) "Đã xử lý hết" else "All caught up" } else { if (vi) "Chờ duyệt" else "Pending" })
            views.setTextViewText(R.id.inbox_review, if (vi) "Xem ngay →" else "Review →")
            val intent = Intent(context, MainActivity::class.java).setAction(OPEN_INBOX)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            views.setOnClickPendingIntent(R.id.inbox_root, PendingIntent.getActivity(context, 1701, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(ids, views)
        }
    }
}
