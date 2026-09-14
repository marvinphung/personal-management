package app.personalfinance.finance_android.banknotification

import android.app.Notification
import android.service.notification.StatusBarNotification

data class ExtractedNotification(val packageName: String, val appLabel: String?, val notificationKey: String,
    val notificationId: Int, val title: String?, val text: String, val postedAt: Long)
object NotificationExtractor {
    fun extract(sbn: StatusBarNotification, label: String?): ExtractedNotification {
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES) ?: emptyArray()
        require(lines.size <= 20) { "Unsupported notification size" }
        val parts = listOfNotNull(title,
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()) +
            lines.map { it.toString() }
        // Never truncate: that could remove a trailing failure/OTP marker.
        require(parts.all { it.length <= 8192 }) { "Unsupported notification size" }
        val unique = parts.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        val combined = unique.filter { a -> unique.none { b -> a != b && b.contains(a) } }.joinToString("\n")
        require(combined.length <= 16384) { "Unsupported notification size" }
        return ExtractedNotification(sbn.packageName, label, sbn.key, sbn.id, title, combined, sbn.postTime)
    }
}
