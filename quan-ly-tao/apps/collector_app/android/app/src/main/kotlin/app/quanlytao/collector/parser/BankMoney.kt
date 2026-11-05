package app.quanlytao.collector.parser

object BankMoney {
    private val DIGITS_CLEANER = Regex("[^0-9]")

    fun parseVnd(raw: String): Long? {
        val trimmed = raw.trim()
        val digitsOnly = DIGITS_CLEANER.replace(trimmed, "")
        if (digitsOnly.isEmpty()) return null
        return try {
            val amount = digitsOnly.toLong()
            if (amount in 1..9_000_000_000_000_000L) amount else null
        } catch (e: NumberFormatException) {
            null
        }
    }
}
