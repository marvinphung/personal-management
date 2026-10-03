package app.quanlytao.user.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import app.quanlytao.user.MainActivity
import app.quanlytao.user.R

class BankInboxWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context)
    }

    companion object {
        fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BankInboxWidget::class.java))
            if (ids.isEmpty()) return

            val isLoggedIn = WidgetCache.isLoggedIn(context)
            val count = WidgetCache.getPendingCount(context)

            val views = RemoteViews(context.packageName, R.layout.bank_inbox_widget)
            views.setTextViewText(R.id.inbox_title, "Quản lý Tao")

            if (!isLoggedIn) {
                views.setTextViewText(R.id.inbox_count, "—")
                views.setTextViewText(R.id.inbox_status, "Mở Quản lý Tao để đăng nhập")
                views.setTextViewText(R.id.inbox_review, "Đăng nhập →")
            } else if (count == 0) {
                views.setTextViewText(R.id.inbox_count, "✓")
                views.setTextViewText(R.id.inbox_status, "Không có giao dịch cần phân loại")
                views.setTextViewText(R.id.inbox_review, "Mở ứng dụng →")
            } else {
                views.setTextViewText(R.id.inbox_count, count.toString())
                views.setTextViewText(R.id.inbox_status, "Có $count giao dịch cần phân loại")
                views.setTextViewText(R.id.inbox_review, "Phân loại ngay →")
            }

            // Deep link opens Biến động
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("quanlytao://bank-inbox")).apply {
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                1701,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.inbox_root, pendingIntent)

            manager.updateAppWidget(ids, views)
        }
    }
}
