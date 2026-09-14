package app.personalfinance.finance_android.banknotification

import android.content.Context
import android.os.Handler
import android.os.Looper
import app.personalfinance.finance_android.banknotification.database.*
import app.personalfinance.finance_android.banknotification.parser.*
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.Executors

/** One serial executor owns capture/config/logout ordering, independent of Flutter. */
object BankInbox {
    val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    var onChanged: (() -> Unit)? = null
    fun preferences(context: Context) = context.getSharedPreferences("bank_import", Context.MODE_PRIVATE)
    fun owner(context: Context): String? = preferences(context).getString("owner", null)
    fun changed(context: Context) {
        BankInboxWidget.update(context)
        main.post { onChanged?.invoke() }
    }
    fun setOwner(context: Context, user: String?) {
        val prefs = preferences(context)
        if (user != null && owner(context) == user) return
        // Stop capture durably before erasing the previous user's inbox.
        check(prefs.edit().clear().commit())
        BankDraftDatabase.get(context).drafts().clear()
        if (user != null) check(prefs.edit().putString("owner", user).commit())
        changed(context)
    }
    fun capture(context: Context, source: BankSource, notification: ExtractedNotification): Boolean {
        val user = owner(context) ?: return false
        if (!preferences(context).getBoolean("capture", false)) return false
        val parsed = ParserRouter.parse(source.code, notification.packageName, notification.text, notification.postedAt)
        if (!parsed.canCreateDraft) return false
        val now = System.currentTimeMillis()
        val payload = parsed.toMap() + mapOf("sourceAppLabel" to source.name)
        // No raw text is persisted: normalized suggestions are sufficient for review.
        val row = BankDraftEntity(UUID.randomUUID().toString(), user, parsed.fingerprint(notification.notificationKey),
            JSONObject(payload).toString(), createdAtMillis = now, updatedAtMillis = now)
        val inserted = BankDraftDatabase.get(context).drafts().insert(row) != -1L
        val prefs = preferences(context)
        val account = prefs.getString("account.${source.code}", null)
        if (inserted && account != null && parsed.balanceMinor != null) {
            val key = "balance.$account"
            val previous = prefs.getString(key, null)?.let { JSONObject(it).optLong("at") } ?: Long.MIN_VALUE
            if (parsed.occurredAtMillis > previous) {
                val snapshot = JSONObject(mapOf("account" to account, "amount" to parsed.balanceMinor,
                    "currency" to parsed.balanceCurrency, "at" to parsed.occurredAtMillis))
                check(prefs.edit().putString(key, snapshot.toString()).commit())
            }
        }
        if (inserted) changed(context)
        return inserted
    }
}
