package app.personalfinance.finance_android.banknotification.parser

import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.ResolverStyle
import java.time.temporal.ChronoField
import java.util.Locale

interface BankNotificationParser {
    fun parse(bank: String, source: String, raw: String, postedAt: Long, zone: ZoneId): ParsedBankTransaction
}

/** Strict common fields only. Unknown/pending/OTP notifications do not enter the inbox. */
open class GenericVietnamBankParser(private val id: String = "generic-vietnam-v1") : BankNotificationParser {
    private val failure = Regex("\\b(KHONG THANH CONG|THAT BAI|FAILED|DECLINED|TU CHOI)\\b")
    private val unsettled = Regex("\\b(OTP|MA XAC THUC|VERIFICATION CODE|DANG XU LY|PENDING|YEU CAU|DE NGHI)\\b")
    private val explicit = Regex("\\b(?:SO TIEN GD|GD)\\s*:\\s*([+-]?\\s*\\d[\\d.,]*)\\s*(VND|USD)\\b")
    private val amount = Regex("(?<![\\d.,])([+-]\\s*\\d[\\d.,]*)\\s*(VND|USD)\\b")
    private val balance = Regex("\\b(?:SD|SDC|SO DU|BALANCE)\\s*:")
    private val iso = Regex("\\b\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\b")
    private val local = Regex("\\b\\d{2}/\\d{2}/(?:\\d{2}|\\d{4}) \\d{2}:\\d{2}\\b")
    override fun parse(bank: String, source: String, raw: String, postedAt: Long, zone: ZoneId): ParsedBankTransaction {
        if (raw.length > 16384) return ParsedBankTransaction(bank, source, occurredAtMillis = postedAt, parserId = id)
        val text = normalize(raw)
        val failed = failure.containsMatchIn(text) // Must run before success matching.
        var result = ParsedBankTransaction(bank, source, occurredAtMillis = postedAt, parserId = id,
            status = if (failed) Status.failed else Status.unknown)
        // Exclude balance field segments even if they contain a sign.
        val fields = raw.split(Regex("[|\\n\\r]")).map(::normalize)
        val matches = explicit.findAll(text).toList()
        val candidate = if (matches.size == 1) matches.single() else if (matches.isEmpty() &&
            Regex("\\b(MB VISA|MB MASTERCARD|SD THE|GIAO DICH|TRANSACTION)\\b").containsMatchIn(text)) {
            fields.filterNot { balance.containsMatchIn(it) }.flatMap { amount.findAll(it).toList() }.singleOrNull()
        } else null
        if (candidate == null) return result
        // An explicit GD embedded after a balance marker is not an amount field.
        val before = text.substring(0, candidate.range.first.coerceAtMost(text.length))
        if (matches.size == 1 && Regex("(?:SD|SO DU|BALANCE)\\s*:\\s*$").containsMatchIn(before)) return result
        val signed = candidate.groupValues[1].replace(" ", "")
        val currency = candidate.groupValues[2]
        val minor = BankMoney.minor(signed, currency) ?: return result
        val date = parseDate(text, zone)
        result = result.copy(amountMinor = minor, currency = currency, currencyScale = if (currency == "USD") 2 else 0,
            direction = when (signed.first()) { '+' -> Direction.income; '-' -> Direction.expense; else -> Direction.unknown },
            occurredAtMillis = date ?: postedAt, occurredAtSource = if (date != null) "notification_text" else "notification_post_time",
            descriptionCandidate = description(raw),
            accountHint = Regex("\\b(?:TKTT|TK)\\s*:?\\s*([\\dXx*]+)").find(raw)?.groupValues?.get(1)?.takeLast(4),
            cardHint = Regex("\\[([\\d.*]{8,})]").find(raw)?.groupValues?.get(1)?.takeLast(4),
            referenceId = Regex("(?i)(?:Ma GD|Mã GD|transaction reference|reference)\\s*:?\\s*([A-Z0-9_-]+(?:\\s*/\\s*[A-Z0-9_-]+)?)").find(raw)?.groupValues?.get(1)?.replace(Regex("\\s+"), ""),
            status = if (failed) Status.failed else if (unsettled.containsMatchIn(text)) Status.unknown else Status.success,
            confidence = if (date == null) 0.8 else 1.0)
        if (result.status == Status.success) {
            val balances = Regex("\\b(?:SD|SDC|SO DU|BALANCE)\\s*:\\s*([+-]?\\s*\\d[\\d.,]*)\\s*(VND|USD)\\b").findAll(text).toList()
            val b = balances.singleOrNull()
            if (b != null) {
                val value = b.groupValues[1].replace(" ", "")
                val minorBalance = BankMoney.minor(value, b.groupValues[2], allowZero = true)
                result = result.copy(balanceMinor = minorBalance?.let { if (value.startsWith("-")) -it else it },
                    balanceCurrency = if (minorBalance != null) b.groupValues[2] else null)
            }
        }
        return result
    }
    private fun parseDate(text: String, zone: ZoneId): Long? {
        val match = iso.find(text)
        val value = match?.value ?: local.find(text)?.value ?: return null
        val formatter = if (match != null) DateTimeFormatter.ofPattern("uuuu-MM-dd HH:mm:ss", Locale.ROOT)
            else if (value.length == 14) DateTimeFormatterBuilder().appendPattern("dd/MM/").appendValueReduced(ChronoField.YEAR, 2, 2, 2000)
                .appendPattern(" HH:mm").toFormatter(Locale.ROOT)
            else DateTimeFormatter.ofPattern("dd/MM/uuuu HH:mm", Locale.ROOT)
        return runCatching { LocalDateTime.parse(value, formatter.withResolverStyle(ResolverStyle.STRICT)).atZone(zone).toInstant().toEpochMilli() }.getOrNull()
    }
    private fun description(raw: String): String? {
        val field = Regex("(?i)(?:Nội dung GD|Noi dung GD|ND)\\s*:\\s*([^|\\r\\n]+)").find(raw)?.groupValues?.get(1)
        val text = field ?: Regex("(?i)(?:tại|tai)\\s+([^|\\r\\n]+)").find(raw)?.groupValues?.get(1) ?: return null
        return text.replace(Regex("(?i)^Giao dịch chi tiêu tại\\s+"), "")
            .replace(Regex("(?i)\\s*-?\\s*(?:Ma GD|Mã GD).*$"), "").trim().take(500).ifEmpty { null }
    }
}

class MbBankParser : GenericVietnamBankParser("mbbank-v1")
// Deliberately use proven common fields until real samples justify bank-specific formats.
class VietinBankParser : GenericVietnamBankParser("vietinbank-generic-v1")
class TechcombankParser : GenericVietnamBankParser("techcombank-generic-v1")
class BidvParser : GenericVietnamBankParser("bidv-generic-v1")

object ParserRouter {
    fun parse(bank: String, source: String, text: String, postedAt: Long, zone: ZoneId = ZoneId.systemDefault()): ParsedBankTransaction {
        val parser = when (bank) { "techcombank" -> TechcombankParser(); "mbbank" -> MbBankParser(); "vietinbank" -> VietinBankParser(); "bidv" -> BidvParser(); else -> GenericVietnamBankParser() }
        return runCatching { parser.parse(bank, source, text, postedAt, zone) }.getOrElse {
            ParsedBankTransaction(bank, source, occurredAtMillis = postedAt, parserId = "unsupported")
        }
    }
}
