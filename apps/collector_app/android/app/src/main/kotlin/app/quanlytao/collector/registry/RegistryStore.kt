package app.quanlytao.collector.registry

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class CachedBinding(
    val bindingId: String,
    val bankCode: String,
    val accountNumber: String,
    val bindingVersion: Int,
    val captureEpoch: Long,
)

object RegistryStore {
    private const val PREFS_NAME = "collector_registry_prefs"
    private const val KEY_BINDINGS = "cached_bindings"
    private const val KEY_COLLECTOR_EPOCH = "collector_epoch"
    private const val KEY_INITIALIZED = "is_initialized"

    @Volatile
    private var cachedList: List<CachedBinding>? = null
    @Volatile
    private var collectorEpoch: Long = 1

    fun isInitialized(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_INITIALIZED, false)
    }

    fun getCollectorEpoch(context: Context): Long {
        if (cachedList == null) load(context)
        return collectorEpoch
    }

    fun load(context: Context): List<CachedBinding> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        collectorEpoch = prefs.getLong(KEY_COLLECTOR_EPOCH, 1)
        val raw = prefs.getString(KEY_BINDINGS, null) ?: return emptyList()

        return try {
            val arr = JSONArray(raw)
            val list = mutableListOf<CachedBinding>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                list.add(
                    CachedBinding(
                        bindingId = obj.getString("binding_id"),
                        bankCode = obj.getString("bank_code"),
                        accountNumber = obj.getString("account_number"),
                        bindingVersion = obj.getInt("binding_version"),
                        captureEpoch = obj.getLong("capture_epoch"),
                    )
                )
            }
            cachedList = list
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun save(context: Context, epoch: Long, bindings: List<CachedBinding>) {
        val arr = JSONArray()
        for (b in bindings) {
            val obj = JSONObject().apply {
                put("binding_id", b.bindingId)
                put("bank_code", b.bankCode)
                put("account_number", b.accountNumber)
                put("binding_version", b.bindingVersion)
                put("capture_epoch", b.captureEpoch)
            }
            arr.put(obj)
        }
        collectorEpoch = epoch
        cachedList = bindings
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_COLLECTOR_EPOCH, epoch)
            .putString(KEY_BINDINGS, arr.toString())
            .putBoolean(KEY_INITIALIZED, true)
            .apply()
    }

    fun match(context: Context, bankCode: String, accountNumber: String): CachedBinding? {
        val list = cachedList ?: load(context)
        return list.firstOrNull {
            it.bankCode.equals(bankCode, ignoreCase = true) && it.accountNumber == accountNumber
        }
    }

    fun clear(context: Context) {
        cachedList = null
        collectorEpoch = 1
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
