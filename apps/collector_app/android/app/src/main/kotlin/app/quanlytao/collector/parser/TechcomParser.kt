package app.quanlytao.collector.parser

import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.regex.Pattern

object TechcomParser {
    const val VERSION = "techcombank-reference-v1"
    /**
     * Gated live support: Techcombank live capture is disabled until real Android
     * shared-notification payloads are verified on device.
     */
    const val isLiveEnabled: Boolean = false
    private val ZONE_VN = ZoneId.of("Asia/Ho_Chi_Minh")

    private val ACCOUNT_REGEX = Pattern.compile("TK\\s*([0-9A-Za-z]+):", Pattern.CASE_INSENSITIVE)
    private val AMOUNT_REGEX = Pattern.compile("([+\\-])\\s*([0-9.,]+)\\s*(?:VND|đ)", Pattern.CASE_INSENSITIVE)
    private val TIME_REGEX = Pattern.compile("vao\\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\\s+[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)", Pattern.CASE_INSENSITIVE)
    private val CONTENT_REGEX = Pattern.compile("ND:\\s*(.+)$", Pattern.CASE_INSENSITIVE)

    fun parse(text: String, postTime: Long): ParsedEvent? {
        if (text.contains("***")) return null

        val accMatcher = ACCOUNT_REGEX.matcher(text)
        if (!accMatcher.find()) return null
        val ownerAccount = accMatcher.group(1)?.trim() ?: return null

        val amtMatcher = AMOUNT_REGEX.matcher(text)
        if (!amtMatcher.find()) return null
        val sign = amtMatcher.group(1) ?: return null
        val rawAmount = amtMatcher.group(2) ?: return null
        val amount = BankMoney.parseVnd(rawAmount) ?: return null
        val direction = if (sign == "+") "income" else "expense"

        var occurredAt = postTime
        var timeSource = "notification"

        val timeMatcher = TIME_REGEX.matcher(text)
        if (timeMatcher.find()) {
            val rawTime = timeMatcher.group(1)?.trim()
            if (rawTime != null) {
                try {
                    val fullPattern = if (rawTime.count { it == ':' } == 2) "dd/MM/yyyy HH:mm:ss" else "dd/MM/yyyy HH:mm"
                    val formatter = DateTimeFormatter.ofPattern(fullPattern)
                    val ldt = LocalDateTime.parse(rawTime, formatter)
                    occurredAt = ldt.atZone(ZONE_VN).toInstant().toEpochMilli()
                    timeSource = "bank_text"
                } catch (_: Exception) {
                    // fallback to postTime
                }
            }
        }

        val contentMatcher = CONTENT_REGEX.matcher(text)
        val description = if (contentMatcher.find()) {
            contentMatcher.group(1)?.trim() ?: "Giao dịch Techcombank"
        } else {
            "Giao dịch Techcombank"
        }

        return ParsedEvent(
            bankCode = "techcombank",
            ownerAccount = ownerAccount,
            direction = direction,
            amountVnd = amount,
            occurredAt = occurredAt,
            timeSource = timeSource,
            bankDescription = description,
            parserVersion = VERSION,
        )
    }
}
