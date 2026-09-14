package app.personalfinance.finance_android.banknotification.parser

import java.security.MessageDigest
import java.text.Normalizer
import java.util.Locale

enum class Direction { income, expense, unknown }
enum class Status { success, failed, unknown }

fun normalize(text: String): String = Normalizer.normalize(text, Normalizer.Form.NFD)
    .replace(Regex("\\p{M}+"), "").replace('đ', 'd').replace('Đ', 'D')
    .replace('−', '-').replace('＋', '+').uppercase(Locale.ROOT)
    .replace(Regex("\\s+"), " ").trim()

data class ParsedBankTransaction(
    val bankCode: String, val sourcePackage: String,
    val amountMinor: Long? = null, val currency: String? = null, val currencyScale: Int = 0,
    val direction: Direction = Direction.unknown,
    val occurredAtMillis: Long, val occurredAtSource: String = "notification_post_time",
    val descriptionCandidate: String? = null, val accountHint: String? = null,
    val cardHint: String? = null, val referenceId: String? = null,
    val status: Status = Status.unknown, val parserId: String, val parserVersion: Int = 1,
    val confidence: Double = 0.0,
    val balanceMinor: Long? = null, val balanceCurrency: String? = null,
) {
    val canCreateDraft: Boolean get() = status == Status.success && amountMinor != null && amountMinor > 0
    fun fingerprint(notificationKey: String): String {
        val time = if (occurredAtSource == "notification_text") occurredAtMillis else occurredAtMillis / 60000
        val identity = if (referenceId != null) listOf(bankCode, accountHint, cardHint, normalize(referenceId), amountMinor, currency, direction)
            else listOf(bankCode, accountHint, cardHint, amountMinor, currency, direction, time,
                normalize(descriptionCandidate.orEmpty()), if (occurredAtSource == "notification_post_time") notificationKey else "")
        return MessageDigest.getInstance("SHA-256").digest(identity.joinToString("\u001f").toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
    fun toMap(): Map<String, Any?> = mapOf(
        "bankCode" to bankCode, "sourcePackage" to sourcePackage, "amountMinor" to amountMinor,
        "balanceMinor" to balanceMinor, "balanceCurrency" to balanceCurrency,
        "currency" to currency, "currencyScale" to currencyScale, "direction" to direction.name,
        "occurredAtMillis" to occurredAtMillis, "occurredAtSource" to occurredAtSource,
        "descriptionCandidate" to descriptionCandidate, "accountHint" to accountHint, "cardHint" to cardHint,
        "referenceId" to referenceId, "status" to status.name, "parserId" to parserId,
        "parserVersion" to parserVersion, "confidence" to confidence, "canCreateDraft" to canCreateDraft)
}
