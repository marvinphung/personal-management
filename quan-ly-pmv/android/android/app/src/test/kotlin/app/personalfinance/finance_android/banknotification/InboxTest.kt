package app.personalfinance.finance_android.banknotification

import androidx.room.Room
import app.personalfinance.finance_android.banknotification.database.*
import app.personalfinance.finance_android.banknotification.parser.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class InboxTest {
    @Test fun roomUniqueConstraintTerminalErasureAndOwnerIsolation() {
        val context = RuntimeEnvironment.getApplication()
        val db = Room.inMemoryDatabaseBuilder(context, BankDraftDatabase::class.java).allowMainThreadQueries().build()
        try {
            val dao = db.drafts()
            val a = ParserRouter.parse("mbbank", "com.mbmobile", "GD: -50,000 VND 13/09/26 10:00", 1)
            val b = ParserRouter.parse("mbbank", "com.mbmobile", "GD: -50,000 VND 13/09/26 14:00", 1)
            val row = BankDraftEntity("1", "A", a.fingerprint("key"), "private suggestion", createdAtMillis=1, updatedAtMillis=1)
            assertTrue(dao.insert(row) != -1L)
            assertEquals(-1L, dao.insert(row.copy(id="repeat")))
            assertEquals(1, dao.count("A"))
            dao.insert(row.copy(id="2", fingerprint=b.fingerprint("key")))
            assertEquals(2, dao.count("A"))
            assertEquals(0, dao.count("B"))
            assertEquals(0, dao.finish("B", "1", "confirmed", 2))
            dao.finish("A", "1", "confirmed", 2)
            assertNull(dao.get("A", "1")!!.payload)
            assertEquals(1, dao.count("A"))
            assertEquals(-1L, dao.insert(row.copy(id="again")))
            dao.finish("A", "2", "ignored", 2)
            assertEquals(0, dao.count("A"))
            dao.clear()
            assertNull(dao.get("A", "1"))
        } finally { db.close() }
    }
    @Test fun sourceRegistryRejectsUnrelatedAndDisabledApps() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("registry_test", 0)
        prefs.edit().clear().commit()
        assertNull(BankSourceRegistry.identify("com.chat.app", "MB Bank", prefs))
        assertEquals("mbbank", BankSourceRegistry.identify("com.mbmobile", null, prefs)?.code)
        prefs.edit().putBoolean("enabled.mbbank", false).commit()
        assertNull(BankSourceRegistry.identify("com.mbmobile", null, prefs))
    }
}
