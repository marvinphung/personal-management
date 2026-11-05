package app.quanlytao.collector.registry

data class BankSource(
    val code: String,
    val name: String,
    val packages: Set<String>,
    val labels: Set<String>
)

object BankSourceRegistry {
    val sources = listOf(
        BankSource("bidv", "BIDV SmartBanking", setOf("com.vnpay.bidv"), setOf("BIDV SMARTBANKING", "BIDV")),
        BankSource("vietinbank", "VietinBank iPay", setOf("com.vietinbank.ipay"), setOf("VIETINBANK IPAY")),
        BankSource("vietcombank", "VCB Digibank", setOf("com.VCB", "com.vnpay.vcb"), setOf("VIETCOMBANK", "VCB")),
        BankSource("techcombank", "Techcombank Mobile", setOf("vn.com.techcombank.bb.app"), setOf("TECHCOMBANK")),
    )

    fun identify(packageName: String): BankSource? {
        return sources.firstOrNull { packageName in it.packages }
    }
}
