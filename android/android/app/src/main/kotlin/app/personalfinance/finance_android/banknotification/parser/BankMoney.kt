package app.personalfinance.finance_android.banknotification.parser

import java.math.BigInteger

object BankMoney {
    private val grouped = Regex("(?:\\d+|\\d{1,3}(?:,\\d{3})+|\\d{1,3}(?:\\.\\d{3})+)")
    fun minor(text: String, currency: String, allowZero: Boolean = false): Long? = runCatching {
        val value = text.removePrefix("+").removePrefix("-")
        val digits = when (currency) {
            "VND" -> { require(grouped.matches(value)); value.replace(",", "").replace(".", "") }
            "USD" -> {
                val decimal = Regex("^(.+)[.,](\\d{2})$").matchEntire(value)
                if (decimal != null) {
                    val whole = decimal.groupValues[1]
                    val separator = value[value.length - 3]
                    require(grouped.matches(whole) && !whole.contains(separator))
                    whole.replace(",", "").replace(".", "") + decimal.groupValues[2]
                } else { require(Regex("\\d+").matches(value)); value + "00" }
            }
            else -> error("Unsupported currency")
        }
        val exact = BigInteger(digits)
        require((exact > BigInteger.ZERO || (allowZero && exact == BigInteger.ZERO)) && exact <= BigInteger("9000000000000000"))
        exact.longValueExact()
    }.getOrNull()
}
