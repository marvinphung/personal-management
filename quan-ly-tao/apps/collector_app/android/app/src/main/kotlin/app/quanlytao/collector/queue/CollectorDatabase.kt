package app.quanlytao.collector.queue

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class CollectorDatabase(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE queue_items (
                event_id TEXT PRIMARY KEY,
                collector_epoch INTEGER NOT NULL,
                binding_id TEXT NOT NULL,
                binding_version INTEGER NOT NULL,
                capture_epoch INTEGER NOT NULL,
                bank_code TEXT NOT NULL,
                owner_account TEXT NOT NULL,
                direction TEXT NOT NULL,
                amount_vnd INTEGER NOT NULL,
                occurred_at INTEGER NOT NULL,
                time_source TEXT NOT NULL,
                bank_description TEXT NOT NULL,
                bank_reference TEXT,
                source_package TEXT NOT NULL,
                parser_version TEXT NOT NULL,
                source_event_key TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        db.execSQL(
            """
            CREATE TABLE counters (
                name TEXT PRIMARY KEY,
                val INTEGER NOT NULL DEFAULT 0
            );
            """
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Safe schema evolution
    }

    @Synchronized
    fun enqueue(item: QueueItem): Boolean {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("event_id", item.eventId)
            put("collector_epoch", item.collectorEpoch)
            put("binding_id", item.bindingId)
            put("binding_version", item.bindingVersion)
            put("capture_epoch", item.captureEpoch)
            put("bank_code", item.bankCode)
            put("owner_account", item.ownerAccount)
            put("direction", item.direction)
            put("amount_vnd", item.amountVnd)
            put("occurred_at", item.occurredAt)
            put("time_source", item.timeSource)
            put("bank_description", item.bankDescription)
            put("bank_reference", item.bankReference)
            put("source_package", item.sourcePackage)
            put("parser_version", item.parserVersion)
            put("source_event_key", item.sourceEventKey)
            put("created_at", item.createdAt)
            put("retry_count", item.retryCount)
        }
        val res = db.insertWithOnConflict("queue_items", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
        return res != -1L
    }

    @Synchronized
    fun getPendingBatch(limit: Int = 20): List<QueueItem> {
        val list = mutableListOf<QueueItem>()
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT * FROM queue_items ORDER BY created_at ASC LIMIT ?", arrayOf(limit.toString()))
        cursor.use { c ->
            while (c.moveToNext()) {
                list.add(
                    QueueItem(
                        eventId = c.getString(c.getColumnIndexOrThrow("event_id")),
                        collectorEpoch = c.getLong(c.getColumnIndexOrThrow("collector_epoch")),
                        bindingId = c.getString(c.getColumnIndexOrThrow("binding_id")),
                        bindingVersion = c.getInt(c.getColumnIndexOrThrow("binding_version")),
                        captureEpoch = c.getLong(c.getColumnIndexOrThrow("capture_epoch")),
                        bankCode = c.getString(c.getColumnIndexOrThrow("bank_code")),
                        ownerAccount = c.getString(c.getColumnIndexOrThrow("owner_account")),
                        direction = c.getString(c.getColumnIndexOrThrow("direction")),
                        amountVnd = c.getLong(c.getColumnIndexOrThrow("amount_vnd")),
                        occurredAt = c.getLong(c.getColumnIndexOrThrow("occurred_at")),
                        timeSource = c.getString(c.getColumnIndexOrThrow("time_source")),
                        bankDescription = c.getString(c.getColumnIndexOrThrow("bank_description")),
                        bankReference = c.getString(c.getColumnIndexOrThrow("bank_reference")),
                        sourcePackage = c.getString(c.getColumnIndexOrThrow("source_package")),
                        parserVersion = c.getString(c.getColumnIndexOrThrow("parser_version")),
                        sourceEventKey = c.getString(c.getColumnIndexOrThrow("source_event_key")),
                        createdAt = c.getLong(c.getColumnIndexOrThrow("created_at")),
                        retryCount = c.getInt(c.getColumnIndexOrThrow("retry_count")),
                    )
                )
            }
        }
        return list
    }

    @Synchronized
    fun remove(eventId: String): Boolean {
        val db = writableDatabase
        return db.delete("queue_items", "event_id = ?", arrayOf(eventId)) > 0
    }

    @Synchronized
    fun incrementRetry(eventId: String) {
        val db = writableDatabase
        db.execSQL("UPDATE queue_items SET retry_count = retry_count + 1 WHERE event_id = ?", arrayOf(eventId))
    }

    @Synchronized
    fun getQueueSize(): Int {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT COUNT(*) FROM queue_items", null)
        cursor.use {
            if (it.moveToFirst()) return it.getInt(0)
        }
        return 0
    }

    @Synchronized
    fun incrementCounter(name: String) {
        val db = writableDatabase
        db.execSQL(
            """
            INSERT INTO counters (name, val) VALUES (?, 1)
            ON CONFLICT(name) DO UPDATE SET val = val + 1;
            """,
            arrayOf(name)
        )
    }

    @Synchronized
    fun getCounters(): Map<String, Long> {
        val map = mutableMapOf<String, Long>()
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT name, val FROM counters", null)
        cursor.use { c ->
            while (c.moveToNext()) {
                map[c.getString(0)] = c.getLong(1)
            }
        }
        return map
    }

    companion object {
        private const val DATABASE_NAME = "collector_queue.db"
        private const val DATABASE_VERSION = 1

        @Volatile
        private var instance: CollectorDatabase? = null

        fun getInstance(context: Context): CollectorDatabase {
            return instance ?: synchronized(this) {
                instance ?: CollectorDatabase(context.applicationContext).also { instance = it }
            }
        }
    }
}
