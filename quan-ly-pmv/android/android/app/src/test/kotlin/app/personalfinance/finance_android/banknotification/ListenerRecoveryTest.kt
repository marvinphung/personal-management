package app.personalfinance.finance_android.banknotification

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Looper
import android.provider.Settings
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@LooperMode(LooperMode.Mode.PAUSED)
class ListenerRecoveryTest {
    private fun setup() = RuntimeEnvironment.getApplication().also { context ->
        BankInbox.preferences(context).edit().putString("owner", "u").putBoolean("capture", true).commit()
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners",
            ComponentName(context, BankNotificationListenerService::class.java).flattenToString())
    }
    @Test fun noPermissionOrCaptureMeansNoRecovery() {
        val context = setup()
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
        var result = ""
        ListenerRecovery.debug(context,"u") { result = it["status"] as String }
        assertEquals("permission_required",result)
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners",
            ComponentName(context, BankNotificationListenerService::class.java).flattenToString())
        BankInbox.preferences(context).edit().putBoolean("capture",false).commit()
        ListenerRecovery.debug(context,"u") { result = it["status"] as String }
        assertEquals("capture_disabled",result)
        assertFalse(ListenerRecovery.running)
    }
    @Test fun timeoutDoesNotPretendConnectedAndRestoresComponent() {
        val context=setup()
        var result=""
        ListenerRecovery.debug(context,"u") {result=it["status"] as String}
        assertTrue(ListenerRecovery.running)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(4))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(8))
        assertEquals("unresolved",result)
        assertFalse(ListenerConnection.connected)
        assertFalse(ListenerRecovery.running)
        assertNotEquals(PackageManager.COMPONENT_ENABLED_STATE_DISABLED,context.packageManager.getComponentEnabledSetting(
            ComponentName(context,BankNotificationListenerService::class.java)))
        assertFalse(context.getSharedPreferences("listener_recovery",android.content.Context.MODE_PRIVATE).getBoolean("listener_debug_reset_pending",false))
    }
    @Test fun realConnectedCallbackFinishesRecovery() {
        val context=setup()
        var result=""
        ListenerRecovery.debug(context,"u") {result=it["status"] as String}
        ListenerConnection.setConnected(context,true)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals("recovered",result)
        assertTrue(ListenerConnection.connected)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(12))
        assertFalse(ListenerRecovery.running)
    }
    @Test fun changedOwnerCancelsAndNeverEnablesCapture() {
        val context=setup()
        var result=""
        ListenerRecovery.debug(context,"u") {result=it["status"] as String}
        BankInbox.preferences(context).edit().putString("owner","another").putBoolean("capture",false).commit()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(12))
        assertEquals("session_changed",result)
        assertFalse(BankInbox.preferences(context).getBoolean("capture",false))
    }
    @Test fun interruptedResetMarkerSurvivesOwnerCleanup() {
        val context=setup()
        val component=ComponentName(context,BankNotificationListenerService::class.java)
        val recovery=context.getSharedPreferences("listener_recovery",android.content.Context.MODE_PRIVATE)
        recovery.edit().putInt("listener_debug_component_state",PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
            .putBoolean("listener_debug_reset_pending",true).commit()
        context.packageManager.setComponentEnabledSetting(component,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,PackageManager.DONT_KILL_APP)
        BankInbox.executor.submit { BankInbox.setOwner(context,null) }.get(10,java.util.concurrent.TimeUnit.SECONDS)
        assertTrue(recovery.getBoolean("listener_debug_reset_pending",false))
        ListenerConnection.ensureBound(context)
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,context.packageManager.getComponentEnabledSetting(component))
        assertFalse(recovery.getBoolean("listener_debug_reset_pending",false))
        assertFalse(BankInbox.preferences(context).getBoolean("capture",false))
    }

}
