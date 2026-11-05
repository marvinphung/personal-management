package app.quanlytao.collector.capture

import android.app.Notification
import android.service.notification.StatusBarNotification

data class ExtractedNotification(
    val packageName: String,
    val title: String?,
    val text: String,
    val postTime: Long,
    val key: String,
    val isGroupSummary: Boolean,
)

object NotificationExtractor {
    fun extract(sbn: StatusBarNotification): ExtractedNotification? {
        val notification = sbn.notification ?: return null
        val extras = notification.extras ?: return null
        val isGroupSummary = (notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: ""

        if (text.isBlank() && title.isNullOrBlank()) {
            return null
        }

        return ExtractedNotification(
            packageName = sbn.packageName,
            title = title,
            text = text.trim(),
            postTime = sbn.postTime,
            key = sbn.key ?: "${sbn.packageName}:${sbn.postTime}",
            isGroupSummary = isGroupSummary,
        )
    }
}
