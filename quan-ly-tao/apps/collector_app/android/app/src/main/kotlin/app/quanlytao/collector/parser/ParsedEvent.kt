package app.quanlytao.collector.parser

data class ParsedEvent(
    val bankCode: String,
    val ownerAccount: String,
    val direction: String, // "income" or "expense"
    val amountVnd: Long,
    val occurredAt: Long, // Epoch millis in UTC
    val timeSource: String, // "bank_text" or "notification"
    val bankDescription: String,
    val bankReference: String? = null,
    val parserVersion: String,
)
