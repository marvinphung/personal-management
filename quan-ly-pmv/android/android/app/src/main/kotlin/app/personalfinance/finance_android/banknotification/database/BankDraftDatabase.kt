package app.personalfinance.finance_android.banknotification.database

import android.content.Context
import androidx.room.*
import androidx.sqlite.db.SupportSQLiteDatabase

/** Payload holds the versioned parsed model, never arbitrary notification history.
 * Terminal rows keep only id/owner/fingerprint/status/timestamps to prevent recapture. */
@Entity(tableName = "bank_drafts", indices = [Index(value = ["owner", "fingerprint"], unique = true), Index(value = ["owner", "status"])])
data class BankDraftEntity(
    @PrimaryKey val id: String,
    val owner: String,
    val fingerprint: String,
    val payload: String?,
    val status: String = "pending",
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
)

@Dao
interface BankDraftDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE) fun insert(row: BankDraftEntity): Long
    @Query("SELECT * FROM bank_drafts WHERE owner=:owner AND status='pending' ORDER BY createdAtMillis DESC LIMIT :limit OFFSET :offset")
    fun pending(owner: String, limit: Int = 100, offset: Int = 0): List<BankDraftEntity>
    @Query("SELECT count(*) FROM bank_drafts WHERE owner=:owner AND status='pending'") fun count(owner: String): Int
    @Query("SELECT * FROM bank_drafts WHERE owner=:owner AND id=:id") fun get(owner: String, id: String): BankDraftEntity?
    @Query("UPDATE bank_drafts SET status=:status, payload=NULL, updatedAtMillis=:now WHERE owner=:owner AND id=:id AND status='pending'")
    fun finish(owner: String, id: String, status: String, now: Long): Int
    @Query("DELETE FROM bank_drafts") fun clear()
}

@Database(entities = [BankDraftEntity::class], version = 1, exportSchema = true)
abstract class BankDraftDatabase : RoomDatabase() {
    abstract fun drafts(): BankDraftDao
    companion object {
        @Volatile private var instance: BankDraftDatabase? = null
        fun get(context: Context): BankDraftDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(context.applicationContext, BankDraftDatabase::class.java, "bank_inbox.db")
                .addCallback(object : Callback() {
                    override fun onOpen(db: SupportSQLiteDatabase) { db.query("PRAGMA secure_delete=ON").use { it.moveToFirst() } }
                }).build().also { instance = it }
        }
        // Future versions must add explicit migrations; never destructive fallback.
    }
}
