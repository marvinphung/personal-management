package app.quanlytao.collector.queue

data class QueueItem(
    val eventId: String,
    val collectorEpoch: Long,
    val bindingId: String,
    val bindingVersion: Int,
    val captureEpoch: Long,
    val bankCode: String,
    val ownerAccount: String,
    val direction: String,
    val amountVnd: Long,
    val occurredAt: Long,
    val timeSource: String,
    val bankDescription: String,
    val bankReference: String?,
    val sourcePackage: String,
    val parserVersion: String,
    val sourceEventKey: String,
    val createdAt: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
)
