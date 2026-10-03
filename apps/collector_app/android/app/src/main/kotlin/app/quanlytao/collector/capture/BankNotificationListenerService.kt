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
    }

    override fun onListenerDisconnected() {
        ListenerConnection.setConnected(this, false)
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val bank = BankSourceRegistry.identify(sbn.packageName) ?: return
        val extracted = NotificationExtractor.extract(sbn) ?: return
        if (extracted.isGroupSummary) return

        val parsed = ParserRouter.parse(
            packageName = extracted.packageName,
            text = extracted.text,
            postTime = extracted.postTime,
        ) ?: return

        val db = CollectorDatabase.getInstance(this)

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
            UploadWorker.schedule(this)
        }
    }
}
