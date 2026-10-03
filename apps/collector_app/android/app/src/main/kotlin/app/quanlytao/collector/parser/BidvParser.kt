package app.quanlytao.collector.parser

import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.regex.Pattern

object BidvParser {
    const val VERSION = "bidv-v2"
    private val ZONE_VN = ZoneId.of("Asia/Ho_Chi_Minh")

    private val ACCOUNT_REGEX = Pattern.compile("Tài khoản thanh toán:\\s*([0-9A-Za-z]+)", Pattern.CASE_INSENSITIVE)
    private val AMOUNT_REGEX = Pattern.compile("Số tiền GD:\\s*([+\\-])\\s*([0-9.,]+)\\s*(?:VND|đ)", Pattern.CASE_INSENSITIVE)
    private val TIME_REGEX = Pattern.compile("Thời gian giao dịch:\\s*([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)\\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})", Pattern.CASE_INSENSITIVE)
    private val CONTENT_REGEX = Pattern.compile("Nội dung:\\s*(.+?)(?:\\.\\s*Số dư:|$)", Pattern.CASE_INSENSITIVE)

    fun parse(text: String, postTime: Long): ParsedEvent? {
        if (text.contains("***")) return null // Reject masked accounts

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
            val timePart = timeMatcher.group(1) ?: ""
            val datePart = timeMatcher.group(2) ?: ""
            try {
                val fullPattern = if (timePart.count { it == ':' } == 2) "HH:mm:ss dd/MM/yyyy" else "HH:mm dd/MM/yyyy"
                val formatter = DateTimeFormatter.ofPattern(fullPattern)
                val ldt = LocalDateTime.parse("$timePart $datePart", formatter)
                occurredAt = ldt.atZone(ZONE_VN).toInstant().toEpochMilli()
                timeSource = "bank_text"
            } catch (_: Exception) {
                // fallback to postTime
            }
        }

        val contentMatcher = CONTENT_REGEX.matcher(text)
        val description = if (contentMatcher.find()) {
            contentMatcher.group(1)?.trim() ?: "Giao dịch BIDV"
        } else {
            "Giao dịch BIDV"
        }

        return ParsedEvent(
            bankCode = "bidv",
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
