package app.quanlytao.collector

import app.quanlytao.collector.parser.BidvParser
import app.quanlytao.collector.parser.ParserRouter
import app.quanlytao.collector.parser.VietinParser
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.InputStreamReader

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ParserTest {
    private fun loadFixture(fileName: String): JSONObject {
        val stream = javaClass.classLoader?.getResourceAsStream("bank_notifications/$fileName")
            ?: throw IllegalArgumentException("Fixture not found: $fileName")
        val content = InputStreamReader(stream).readText()
        return JSONObject(content)
    }

    @Test
    fun testBidvTwoTransactionsEqualPostingTimeRemainDistinct() {
        val fixture1 = loadFixture("bidv_income_1.json")
        val fixture2 = loadFixture("bidv_income_2.json")

        val event1 = ParserRouter.parse(
            fixture1.getString("packageName"),
            fixture1.getString("text"),
            fixture1.getLong("postTime")
        )
        assertNotNull(event1)
        assertEquals("bidv", event1!!.bankCode)
        assertEquals("1234567890", event1.ownerAccount)
        assertEquals("income", event1.direction)
        assertEquals(720000L, event1.amountVnd)

        val event2 = ParserRouter.parse(
            fixture2.getString("packageName"),
            fixture2.getString("text"),
            fixture2.getLong("postTime")
        )
        assertNotNull(event2)
        assertEquals("bidv", event2!!.bankCode)
        assertEquals("1234567890", event2.ownerAccount)
        assertEquals(720000L, event2.amountVnd)

        // Equal notification posting time, but distinct transaction timestamps!
        assertEquals(fixture1.getLong("postTime"), fixture2.getLong("postTime"))
        assertNotEquals(event1.occurredAt, event2.occurredAt)
        assertTrue(event2.occurredAt > event1.occurredAt)
    }

    @Test
    fun testBidvExpense() {
        val fixture = loadFixture("bidv_expense.json")
        val event = ParserRouter.parse(
            fixture.getString("packageName"),
            fixture.getString("text"),
            fixture.getLong("postTime")
        )
        assertNotNull(event)
        assertEquals("expense", event!!.direction)
        assertEquals(150000L, event.amountVnd)
        assertEquals("Thanh toan tien dien", event.bankDescription)
    }

    @Test
    fun testVietinBankBalanceStripped() {
        val fixture = loadFixture("vietinbank_income.json")
        val event = ParserRouter.parse(
            fixture.getString("packageName"),
            fixture.getString("text"),
            fixture.getLong("postTime")
        )
        assertNotNull(event)
        assertEquals("vietinbank", event!!.bankCode)
        assertEquals("102030405060", event.ownerAccount)
        assertEquals("income", event.direction)
        assertEquals(500000L, event.amountVnd)
        assertEquals("Luong thang 9", event.bankDescription)
        assertFalse(event.bankDescription.contains("SDC"))
    }

    @Test
    fun testVcbAndTechcomGatedLiveSupport() {
        val vcbFixture = loadFixture("vcb_reference_fixture.json")
        // In live mode (allowGatedReference = false), returns null because live support is gated
        val liveEvent = ParserRouter.parse(
            vcbFixture.getString("packageName"),
            vcbFixture.getString("text"),
            vcbFixture.getLong("postTime"),
            allowGatedReference = false
        )
        assertNull(liveEvent)

        // In reference mode (allowGatedReference = true), parses properly
        val refEvent = ParserRouter.parse(
            vcbFixture.getString("packageName"),
            vcbFixture.getString("text"),
            vcbFixture.getLong("postTime"),
            allowGatedReference = true
        )
        assertNotNull(refEvent)
        assertEquals("0011000123456", refEvent!!.ownerAccount)
        assertEquals(500000L, refEvent.amountVnd)
    }

    @Test
    fun testRejections() {
        val otpFixture = loadFixture("rejected_otp.json")
        assertNull(ParserRouter.parse(otpFixture.getString("packageName"), otpFixture.getString("text"), 0))

        val mbFixture = loadFixture("rejected_mb.json")
        assertNull(ParserRouter.parse(mbFixture.getString("packageName"), mbFixture.getString("text"), 0))

        val maskedFixture = loadFixture("rejected_masked.json")
        assertNull(ParserRouter.parse(maskedFixture.getString("packageName"), maskedFixture.getString("text"), 0))
    }
}
