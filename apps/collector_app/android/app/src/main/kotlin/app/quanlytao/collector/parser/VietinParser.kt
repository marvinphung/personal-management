package app.quanlytao.collector.parser

import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.regex.Pattern

object VietinParser {
    const val VERSION = "vietinbank-v2"
    private val ZONE_VN = ZoneId.of("Asia/Ho_Chi_Minh")

    private val ACCOUNT_REGEX = Pattern.compile("TK:\\s*([0-9A-Za-z]+)", Pattern.CASE_INSENSITIVE)
    private val AMOUNT_TIME_REGEX = Pattern.compile("GD:\\s*([+\\-])\\s*([0-9.,]+)\\s*(?:VND|đ)\\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\\s+[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)", Pattern.CASE_INSENSITIVE)
    private val CONTENT_REGEX = Pattern.compile("ND:\\s*([^|]+)", Pattern.CASE_INSENSITIVE)

    fun parse(text: String, postTime: Long): ParsedEvent? {
        if (text.contains("***")) return null // Reject masked accounts

        val accMatcher = ACCOUNT_REGEX.matcher(text)
        if (!accMatcher.find()) return null
        val ownerAccount = accMatcher.group(1)?.trim() ?: return null

        val amtMatcher = AMOUNT_TIME_REGEX.matcher(text)
        if (!amtMatcher.find()) return null
        val sign = amtMatcher.group(1) ?: return null
        val rawAmount = amtMatcher.group(2) ?: return null
        val amount = BankMoney.parseVnd(rawAmount) ?: return null
        val direction = if (sign == "+") "income" else "expense"

        var occurredAt = postTime
        var timeSource = "notification"

        val rawDateTime = amtMatcher.group(3)
        if (rawDateTime != null) {
            try {
                val fullPattern = if (rawDateTime.count { it == ':' } == 2) "dd/MM/yyyy HH:mm:ss" else "dd/MM/yyyy HH:mm"
                val formatter = DateTimeFormatter.ofPattern(fullPattern)
                val ldt = LocalDateTime.parse(rawDateTime.trim(), formatter)
                occurredAt = ldt.atZone(ZONE_VN).toInstant().toEpochMilli()
                timeSource = "bank_text"
            } catch (_: Exception) {
                // fallback to postTime
            }
        }

        val contentMatcher = CONTENT_REGEX.matcher(text)
        val description = if (contentMatcher.find()) {
            contentMatcher.group(1)?.trim() ?: "Giao dịch VietinBank"
        } else {
            "Giao dịch VietinBank"
        }

        return ParsedEvent(
            bankCode = "vietinbank",
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
