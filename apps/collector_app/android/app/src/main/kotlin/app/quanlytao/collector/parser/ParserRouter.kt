package app.quanlytao.collector.parser

object ParserRouter {
    private val REJECT_PATTERNS = listOf(
        Regex("ma otp", RegexOption.IGNORE_CASE),
        Regex("xac thuc", RegexOption.IGNORE_CASE),
        Regex("khuyen mai", RegexOption.IGNORE_CASE),
        Regex("uu dai", RegexOption.IGNORE_CASE),
        Regex("that bai", RegexOption.IGNORE_CASE),
        Regex("khong thanh cong", RegexOption.IGNORE_CASE),
    )

    fun parse(packageName: String, text: String, postTime: Long, allowGatedReference: Boolean = false): ParsedEvent? {
        // 1. Exclude MB Bank permanently
        if (packageName == "com.mbmobile" || packageName.contains("mbmobile")) {
            return null
        }

        // 2. Reject OTP, advertisements, failed transactions
        if (REJECT_PATTERNS.any { it.containsMatchIn(text) }) {
            return null
        }

        // 3. Reject masked accounts
        if (text.contains("***")) {
            return null
        }

        // 4. Route by package name
        return when (packageName) {
            "com.vnpay.bidv" -> BidvParser.parse(text, postTime)
            "com.vietinbank.ipay" -> VietinParser.parse(text, postTime)
            "com.VCB", "com.vnpay.vcb" -> {
                if (VcbParser.isLiveEnabled || allowGatedReference) {
                    VcbParser.parse(text, postTime)
                } else {
                    null // Gated until verified on live device
                }
            }
            "vn.com.techcombank.bb.app" -> {
                if (TechcomParser.isLiveEnabled || allowGatedReference) {
                    TechcomParser.parse(text, postTime)
                } else {
                    null // Gated until verified on live device
                }
            }
            else -> null
        }
    }
}
