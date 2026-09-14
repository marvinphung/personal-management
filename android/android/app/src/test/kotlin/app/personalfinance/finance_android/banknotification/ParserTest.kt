package app.personalfinance.finance_android.banknotification

import app.personalfinance.finance_android.banknotification.parser.*
import org.junit.Assert.*
import org.junit.Test
import java.time.ZoneId
import java.time.Instant

class ParserTest {
    @Test fun techcombankUsesConservativeCommonFields() {
        assertTrue(BankSourceRegistry.sources.any { it.code == "techcombank" && "vn.com.techcombank.bb.app" in it.packages })
        fun t(text: String) = ParserRouter.parse("techcombank", "vn.com.techcombank.bb.app", text, 1790000000000)
        val p = t("GD: +5,000VND|SD: 100,000VND")
        assertEquals("techcombank-generic-v1", p.parserId)
        assertEquals(5000L, p.amountMinor)
        assertEquals(100000L, p.balanceMinor)
        assertEquals(Direction.income, p.direction)
        assertTrue(p.canCreateDraft)
        assertEquals(1999L, t("Số tiền GD: -19.99 USD").amountMinor)
        assertFalse(t("GD: -5,000VND KHÔNG THÀNH CÔNG").canCreateDraft)
        assertFalse(t("GD: -5,000VND KHONG THANH CONG").canCreateDraft)
        assertFalse(t("Số dư: 100,000VND").canCreateDraft)
    }

    private val zone = ZoneId.of("Asia/Ho_Chi_Minh")
    private fun parse(text: String) = ParserRouter.parse("mbbank", "com.mbmobile", text, 1790000000000, zone)
    @Test fun balanceIsSeparateExactAndOnlyFromSuccessfulNotifications() {
        val p = parse("GD: +40,000VND|SD: 3,288,066VND")
        assertEquals(40000L, p.amountMinor)
        assertEquals(3288066L, p.balanceMinor)
        assertEquals("VND", p.balanceCurrency)
        assertEquals(0L, parse("GD: -50,000VND|Số dư: 0VND").balanceMinor)
        assertEquals(-1999L, parse("GD: -1.00USD|Balance: -19.99 USD").balanceMinor)
        assertNull(parse("GD: -50,000VND|SD: 100VND|KHONG THANH CONG").balanceMinor)
        assertNull(parse("GD: -50,000VND|SD: 100VND|SD: 200VND").balanceMinor)
    }
    @Test fun oversizedTextCannotHideFailureBeyondTruncation() {
        assertFalse(parse("GD: +40,000 VND " + "x".repeat(17000) + " KHONG THANH CONG").canCreateDraft)
    }
    @Test fun explicitAmountWinsOverBalance() {
        val p = parse("TK 03xxx005|GD: +40,000VND 13/09/26 20:56|SD: 3,288,066VND|TU: BUI QUANG THUC - 8850851034|ND: BUI QUANG THUC Chuyen tien- Ma GD ACSP/ q6790622")
        assertEquals(40000L, p.amountMinor)
        assertEquals(Direction.income, p.direction)
        assertEquals(Status.success, p.status)
        assertEquals(Instant.parse("2026-09-13T13:56:00Z").toEpochMilli(), p.occurredAtMillis)
        assertEquals("ACSP/q6790622", p.referenceId)
        assertTrue(p.descriptionCandidate!!.contains("BUI QUANG THUC"))
    }
    @Test fun cardAmountAndDescription() {
        val p = parse("MB MASTERCARD:\nSD THE [530416....2404]\nNgày GD: [2026-09-13 10:04:32]\nSố tiền GD: -527,778 VND\nTKTT: 0386883005\nNội dung GD: Giao dịch chi tiêu tại Google ChatGPT")
        assertEquals(527778L, p.amountMinor)
        assertEquals(Direction.expense, p.direction)
        assertEquals("Google ChatGPT", p.descriptionCandidate)
        assertEquals("notification_text", p.occurredAtSource)
    }
    @Test fun failuresNeverQualifyForDraft() {
        for (failure in listOf("KHÔNG THÀNH CÔNG", "KHONG THANH CONG", "THẤT BẠI", "FAILED", "DECLINED", "GIAO DICH BI TU CHOI")) {
            val p = parse("MB VISA: SD THE [484804....9114] [2026-09-13 15:03:52] [-527,778 VND] tại Google ChatGPT $failure do VƯỢT HẠN MỨC TÍN DỤNG")
            assertEquals(Status.failed, p.status)
            assertFalse(p.canCreateDraft)
        }
        assertEquals(Status.failed, parse("KHONG THANH CONG").status)
    }
    @Test fun usdMinorUnitsAndBalanceExclusion() {
        for ((text, expected) in listOf("Số tiền GD: -19.99 USD" to 1999L, "GD: +1,234.56USD" to 123456L, "GD: -1.234,56 USD" to 123456L, "GD: -19.99 USD\nSD: 3,000,000 VND" to 1999L)) {
            val p = parse(text)
            assertEquals(expected, p.amountMinor)
            assertEquals("USD", p.currency)
            assertEquals(2, p.currencyScale)
            assertTrue(p.canCreateDraft)
        }
    }
    @Test fun vndGroupingAndDirection() {
        for (s in listOf("52,550", "52.550", "52550")) {
            val p = parse("GD: -${s}VND\n13/09/26 10:01\nSD: 3,781,650VND\nND: AP-CASHIN-0386883005-04CI187019hw3-bank2wallet")
            assertEquals(52550L, p.amountMinor)
            assertEquals(Direction.expense, p.direction)
        }
    }
    @Test fun conservativeMalformedAndUnrelated() {
        for (text in listOf("SD: +3,000,000 VND", "Balance: -19.99 USD", "Khuyến mãi nhận +40,000 VND", "GD: -19.999 USD", "GD: -52,55 VND", "GD: 0 VND", "GD: -999999999999999999999 USD", "OTP 123456 cho GD: -20 USD", "GD: -20 USD đang xử lý", "GD: -20 USD\nGD: -30 USD")) {
            assertFalse(text, parse(text).canCreateDraft)
        }
        assertEquals(Direction.unknown, parse("Số tiền GD: 40000 VND").direction)
        assertTrue(parse("Số tiền GD: 40000 VND").canCreateDraft)
    }
    @Test fun timeFallbackAndInvalidDates() {
        assertEquals("notification_post_time", parse("GD: -19.99 USD").occurredAtSource)
        assertEquals("notification_post_time", parse("GD: -19.99 USD 31/02/26 10:00").occurredAtSource)
    }
    @Test fun fingerprintsRepeatButDoNotMergeDifferentTimes() {
        val a = parse("GD: -50,000 VND 13/09/26 10:00")
        val b = parse("GD: -50,000 VND 13/09/26 14:00")
        assertEquals(a.fingerprint("key"), a.fingerprint("key"))
        assertNotEquals(a.fingerprint("key"), b.fingerprint("key"))
    }
}
