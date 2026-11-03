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
        BankInbox.executor.execute {
            try {
                update(context)
            } finally {
                pending?.finish()
            }
        }
    }

    companion object {
        const val OPEN_INBOX = "app.personalfinance.OPEN_BANK_INBOX"

        fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BankInboxWidget::class.java))
            if (ids.isEmpty()) return

            val owner = BankInbox.owner(context)
            val rawCount = owner?.let { BankDraftDatabase.get(context).drafts().count(it) } ?: 0

            // Check if there is an active unexpired undo slot
            var undoDeduction = 0
            try {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val rawSlot = flutterPrefs.getString("flutter.undo_slot", null)
                if (rawSlot != null && owner != null) {
                    val parts = rawSlot.split("|")
                    if (parts.size == 3 && parts[0] == owner) {
                        val deadline = parts[2].toLongOrNull() ?: 0L
                        if (deadline > 0L) {
                            undoDeduction = 1
                        }
                    }
                }
            } catch (_: Exception) {
                // Best effort
            }

            val count = maxOf(0, rawCount - undoDeduction)

            val views = RemoteViews(context.packageName, R.layout.bank_inbox_widget)
            views.setTextViewText(R.id.inbox_title, "Biến động")
            views.setTextViewText(R.id.inbox_count, if (count == 0) "✓" else count.toString())
            views.setTextViewText(
                R.id.inbox_status,
                if (count == 0) "Đã xử lý hết" else "$count chờ phân loại"
            )
            views.setTextViewText(R.id.inbox_review, "Mở Biến động →")

            val intent = Intent(context, MainActivity::class.java)
                .setAction(OPEN_INBOX)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

            views.setOnClickPendingIntent(
                R.id.inbox_root,
                PendingIntent.getActivity(
                    context,
                    1701,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            manager.updateAppWidget(ids, views)
        }
    }
}
