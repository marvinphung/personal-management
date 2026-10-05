package app.quanlytao.collector.capture

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import app.quanlytao.collector.parser.ParserRouter
import app.quanlytao.collector.queue.CollectorDatabase
import app.quanlytao.collector.queue.QueueItem
import app.quanlytao.collector.queue.UploadWorker
import app.quanlytao.collector.registry.BankSourceRegistry
import app.quanlytao.collector.registry.RegistryStore
import java.util.UUID

class BankNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        ListenerConnection.setConnected(this, true)

        // Android may keep bank notifications in the shade while this service is
        // disconnected (for example after an APK update or process termination).
        // Replaying the active set closes that gap. Backend/source-event
        // deduplication makes this safe when Android also delivers onPosted.
        activeNotifications?.forEach(::processNotification)

        // Also wake a durable queue left behind by a network outage or process
        // termination, even when Android has no active bank notification left.
        UploadWorker.schedule(this)
    }

    override fun onListenerDisconnected() {
        ListenerConnection.setConnected(this, false)
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        processNotification(sbn)
    }

    private fun processNotification(sbn: StatusBarNotification) {
        val bank = BankSourceRegistry.identify(sbn.packageName) ?: return
        val db = CollectorDatabase.getInstance(this)
        db.incrementCounter("seen_supported")
        val extracted = NotificationExtractor.extract(sbn) ?: run {
            db.incrementCounter("dropped_extract")
            return
        }
        if (extracted.isGroupSummary) {
            db.incrementCounter("dropped_group_summary")
            return
        }

        val parsed = ParserRouter.parse(
            packageName = extracted.packageName,
            text = extracted.text,
            postTime = extracted.postTime,
        ) ?: run {
            db.incrementCounter("dropped_parse")
            return
        }

        // Match against cached registry by exact bank and full owner account
        val binding = RegistryStore.match(this, parsed.bankCode, parsed.ownerAccount)
        if (binding == null) {
            // Drop unmatched without creating a queue entry
            db.incrementCounter("dropped_unmatched")
            return
        }

        val queueItem = QueueItem(
            eventId = UUID.randomUUID().toString(),
            collectorEpoch = RegistryStore.getCollectorEpoch(this),
            bindingId = binding.bindingId,
            bindingVersion = binding.bindingVersion,
            captureEpoch = binding.captureEpoch,
            bankCode = parsed.bankCode,
            ownerAccount = parsed.ownerAccount,
            direction = parsed.direction,
            amountVnd = parsed.amountVnd,
            occurredAt = parsed.occurredAt,
            timeSource = parsed.timeSource,
            bankDescription = parsed.bankDescription,
            bankReference = parsed.bankReference,
            sourcePackage = extracted.packageName,
            parserVersion = parsed.parserVersion,
            sourceEventKey = extracted.key,
        )

        val enqueued = db.enqueue(queueItem)
        if (enqueued) {
            db.incrementCounter("enqueued")
            UploadWorker.schedule(this)
        }
    }
}
