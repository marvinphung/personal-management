package app.personalfinance.finance_android.banknotification.bridge

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import app.personalfinance.finance_android.BuildConfig
import app.personalfinance.finance_android.banknotification.*
import app.personalfinance.finance_android.banknotification.database.BankDraftDatabase
import app.personalfinance.finance_android.banknotification.parser.ParserRouter
import org.json.JSONObject

class BankDraftFlutterBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "personal_finance/bank_inbox")
    private val main = Handler(Looper.getMainLooper())
    private var openPending = activity.intent?.action == BankInboxWidget.OPEN_INBOX
    init {
        BankInbox.onChanged = { channel.invokeMethod("changed", null) }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeOpenPending" -> { result.success(openPending); openPending = false }
                "openSettings" -> {
                    try { activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    catch (_: Exception) { result.error("settings", "Could not open notification access settings", null) }
                }
                else -> BankInbox.executor.execute {
                    try {
                        val prefs = BankInbox.preferences(activity)
                        val dao = BankDraftDatabase.get(activity).drafts()
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        fun owner(): String {
                            val user = BankInbox.owner(activity) ?: error("No user")
                            check(args["owner"] == user)
                            return user
                        }
                        val response: Any? = when (call.method) {
                            "setOwner" -> { BankInbox.setOwner(activity, args["owner"] as? String); ListenerConnection.ensureBound(activity); null }
                            "reconnect" -> { owner(); ListenerConnection.ensureBound(activity, force = true); null }
                            "getSettings" -> {
                                owner()
                                ListenerConnection.ensureBound(activity)
                                mapOf("access" to ListenerConnection.hasAccess(activity), "capture" to prefs.getBoolean("capture", false),
                                    "connected" to ListenerConnection.connected,
                                    "lastBankAt" to prefs.getLong("last_bank_at", 0L),
                                    "lastOutcome" to prefs.getString("last_outcome", null),
                                    "connectedAt" to prefs.getLong("listener_connected_at", 0L),
                                    "disconnectedAt" to prefs.getLong("listener_disconnected_at", 0L),
                                    "rebindAt" to prefs.getLong("listener_rebind_at", 0L),
                                    "rebindResult" to prefs.getString("listener_rebind_result", null),
                                    "sources" to BankSourceRegistry.sources.map { source -> mapOf(
                                        "code" to source.code, "name" to source.name,
                                        "enabled" to prefs.getBoolean("enabled.${source.code}", true),
                                        "package" to (prefs.getString("package.${source.code}", null) ?: source.packages.first()),
                                        "account" to prefs.getString("account.${source.code}", null)) })
                            }
                            "configure" -> {
                                owner()
                                val edit = prefs.edit()
                                (args["capture"] as? Boolean)?.let {
                                    if (it && !prefs.getBoolean("capture", false)) edit.putLong("capture_enabled_at", System.currentTimeMillis())
                                    edit.putBoolean("capture", it)
                                }
                                (args["language"] as? String)?.let { require(it in listOf("en", "vi")); edit.putString("language", it) }
                                (args["bank"] as? String)?.let { bank ->
                                    require(BankSourceRegistry.sources.any { it.code == bank })
                                    (args["enabled"] as? Boolean)?.let { edit.putBoolean("enabled.$bank", it) }
                                    if (args.containsKey("account")) edit.putString("account.$bank", args["account"] as? String)
                                    (args["package"] as? String)?.let { require(Regex("[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)+").matches(it)); edit.putString("package.$bank", it) }
                                }
                                check(edit.commit()); ListenerConnection.ensureBound(activity); BankInbox.changed(activity); null
                            }
                            "pending" -> dao.pending(owner(), offset = ((args["offset"] as? Number)?.toInt() ?: 0).coerceAtLeast(0)).map { row ->
                                jsonMap(JSONObject(row.payload!!)) + mapOf("id" to row.id, "fingerprint" to row.fingerprint, "owner" to row.owner)
                            }
                            "balances" -> {
                                owner()
                                ListenerConnection.ensureBound(activity)
                                prefs.all.filterKeys { it.startsWith("balance.") }.values.map { jsonMap(JSONObject(it as String)) }
                            }
                            "count" -> dao.count(owner())
                            "finish" -> {
                                val status = args["status"] as String
                                require(status in listOf("confirmed", "ignored"))
                                dao.finish(owner(), args["id"] as String, status, System.currentTimeMillis())
                                BankInbox.changed(activity); null
                            }
                            "parse" -> {
                                check(BuildConfig.DEBUG)
                                ParserRouter.parse(args["bank"] as? String ?: "generic", "debug", (args["text"] as String), System.currentTimeMillis()).toMap()
                            }
                            else -> throw IllegalArgumentException("Unsupported operation")
                        }
                        main.post { result.success(response) }
                    } catch (_: Exception) {
                        main.post { result.error("bank_inbox", "Could not access the bank inbox. Please retry.", null) }
                    }
                }
            }
        }
    }
    fun onIntent(intent: Intent) {
        if (intent.action == BankInboxWidget.OPEN_INBOX) {
            openPending = true
            channel.invokeMethod("openPending", null)
        }
    }
    fun close() { BankInbox.onChanged = null; channel.setMethodCallHandler(null) }
    private fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key -> json.get(key).let { if (it == JSONObject.NULL) null else it } }
}
