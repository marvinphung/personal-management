package app.personalfinance.finance_android.banknotification

import android.content.SharedPreferences

data class BankSource(val code: String, val name: String, val packages: Set<String>, val labels: Set<String>)
object BankSourceRegistry {
    // Verified via adb pm list packages --user 0 on the developer's Samsung, 2026-09-14.
    val sources = listOf(
        BankSource("mbbank", "MB Bank", setOf("com.mbmobile"), setOf("MBBANK", "MB BANK")),
        BankSource("vietinbank", "VietinBank iPay", setOf("com.vietinbank.ipay"), setOf("VIETINBANK IPAY")),
        BankSource("bidv", "BIDV", setOf("com.vnpay.bidv"), setOf("BIDV SMARTBANKING", "BIDV")),
    )
    @Suppress("UNUSED_PARAMETER")
    fun identify(packageName: String, label: String?, preferences: SharedPreferences): BankSource? {
        val exact = sources.firstOrNull { packageName in it.packages || preferences.getString("package.${it.code}", null) == packageName }
        // Labels are not authentication: unknown packages require explicit configuration,
        // even if their label mimics a bank. No arbitrary app can opt itself in by renaming.
        return exact?.takeIf { preferences.getBoolean("enabled.${it.code}", true) }
    }
}
