package app.personalfinance.finance_android.banknotification

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService

/** Bounded, user-triggered recovery. Never touches drafts, permissions or capture preference. */
object ListenerRecovery {
    @Volatile var running = false
        private set
    private const val PENDING = "listener_debug_reset_pending"

    fun restoreComponent(context: Context): Boolean {
        val prefs = context.getSharedPreferences("listener_recovery", Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PENDING, false)) return true
        return runCatching {
            context.packageManager.setComponentEnabledSetting(
                ComponentName(context, BankNotificationListenerService::class.java),
                prefs.getInt("listener_debug_component_state", PackageManager.COMPONENT_ENABLED_STATE_DEFAULT),
                PackageManager.DONT_KILL_APP)
            check(prefs.edit().remove(PENDING).commit())
        }.isSuccess
    }

    fun debug(context: Context, expectedOwner: String, complete: (Map<String, Any>) -> Unit) {
        check(Looper.myLooper() == Looper.getMainLooper())
        val app = context.applicationContext
        val prefs = BankInbox.preferences(app)
        val recoveryPrefs = app.getSharedPreferences("listener_recovery", Context.MODE_PRIVATE)
        fun result(status: String) = mapOf("status" to status, "connected" to ListenerConnection.connected)
        if (running) { complete(result("busy")); return }
        if (!restoreComponent(app)) { complete(result("unresolved")); return }
        fun blocked(): String? = when {
            BankInbox.owner(app) != expectedOwner -> "session_changed"
            !ListenerConnection.hasAccess(app) -> "permission_required"
            !prefs.getBoolean("capture", false) -> "capture_disabled"
            else -> null
        }
        blocked()?.let { complete(result(it)); return }
        if (ListenerConnection.connected) { complete(result("connected")); return }
        running = true
        val handler = Handler(Looper.getMainLooper())
        val start = SystemClock.elapsedRealtime()
        var reset = false
        var ended = false
        fun finish(status: String) {
            if (ended) return
            ended = true
            val restored = restoreComponent(app)
            running = false
            if (BankInbox.owner(app) == expectedOwner) prefs.edit().putLong("listener_debug_at", System.currentTimeMillis())
                .putString("listener_debug_result", if (restored) status else "unresolved").apply()
            complete(result(if (restored) status else "unresolved"))
        }
        fun rebind() {
            runCatching { NotificationListenerService.requestRebind(ComponentName(app, BankNotificationListenerService::class.java)) }
        }
        rebind()
        val poll = object: Runnable {
            override fun run() {
                if (ended) return
                blocked()?.let { finish(it); return }
                if (ListenerConnection.connected) { finish("recovered"); return }
                val elapsed = SystemClock.elapsedRealtime() - start
                if (elapsed >= 10_000) { finish("unresolved"); return }
                if (!reset && elapsed >= 3_000) {
                    reset = true
                    runCatching {
                        val component = ComponentName(app, BankNotificationListenerService::class.java)
                        val state = app.packageManager.getComponentEnabledSetting(component)
                        check(recoveryPrefs.edit().putInt("listener_debug_component_state", state).putBoolean(PENDING, true).commit())
                        app.packageManager.setComponentEnabledSetting(component,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    }
                    // Always restore the original state, even if permission/session changes.
                    handler.postDelayed({
                        if (restoreComponent(app) && blocked() == null && !ended) rebind()
                    }, 500)
                }
                handler.postDelayed(this, 250)
            }
        }
        handler.postDelayed(poll, 250)
    }
}
