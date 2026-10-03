package app.quanlytao.collector

import app.quanlytao.collector.queue.CollectorDatabase
import app.quanlytao.collector.queue.QueueItem
import app.quanlytao.collector.registry.CachedBinding
import app.quanlytao.collector.registry.RegistryStore
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class QueueTest {

    @Test
    fun testQueuePersistenceAndRemoval() {
        val context = RuntimeEnvironment.getApplication()
        val db = CollectorDatabase.getInstance(context)

        val id = UUID.randomUUID().toString()
        val item = QueueItem(
            eventId = id,
            collectorEpoch = 1,
            bindingId = "bnd-1",
            bindingVersion = 1,
            captureEpoch = 1,
            bankCode = "bidv",
            ownerAccount = "00123456789",
            direction = "expense",
            amountVnd = 50000,
            occurredAt = System.currentTimeMillis(),
            timeSource = "bank_text",
            bankDescription = "Test coffee",
            bankReference = null,
            sourcePackage = "com.vnpay.bidv",
            parserVersion = "bidv-v2",
            sourceEventKey = "sbn-key-1",
        )

        // Enqueue
        assertTrue(db.enqueue(item))
        assertEquals(1, db.getQueueSize())

        // Dequeue batch
        val batch = db.getPendingBatch(10)
        assertEquals(1, batch.size)
        assertEquals(id, batch[0].eventId)
        assertEquals("00123456789", batch[0].ownerAccount)

        // Retry increment
        db.incrementRetry(id)
        val updatedBatch = db.getPendingBatch(10)
        assertEquals(1, updatedBatch[0].retryCount)

        // Remove
        assertTrue(db.remove(id))
        assertEquals(0, db.getQueueSize())
    }

    @Test
    fun testRegistryStoreExactMatch() {
        val context = RuntimeEnvironment.getApplication()
        RegistryStore.clear(context)

        val bindings = listOf(
            CachedBinding("b-1", "bidv", "00123456789", 1, 1),
            CachedBinding("b-2", "vietinbank", "1020304050", 1, 1),
        )
        RegistryStore.save(context, 1, bindings)
        assertTrue(RegistryStore.isInitialized(context))

        // Exact match
        val matched = RegistryStore.match(context, "bidv", "00123456789")
        assertNotNull(matched)
        assertEquals("b-1", matched!!.bindingId)

        // Unknown account returns null
        val unknown = RegistryStore.match(context, "bidv", "99999999999")
        assertNull(unknown)

        // Wrong bank returns null
        val wrongBank = RegistryStore.match(context, "techcombank", "00123456789")
        assertNull(wrongBank)
    }
}
