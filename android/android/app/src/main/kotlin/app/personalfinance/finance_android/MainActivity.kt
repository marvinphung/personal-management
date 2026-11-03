package app.personalfinance.finance_android

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import app.personalfinance.finance_android.banknotification.bridge.BankDraftFlutterBridge
import app.personalfinance.finance_android.banknotification.ListenerConnection
import app.personalfinance.finance_android.banknotification.BankInbox
import app.personalfinance.finance_android.banknotification.BankInboxWidget
import app.personalfinance.finance_android.calendar.CalendarBridge
import app.personalfinance.finance_android.calendar.CalendarWidgetProvider

class MainActivity : FlutterActivity() {
    private var bankBridge: BankDraftFlutterBridge? = null
    private var navigation: io.flutter.plugin.common.MethodChannel? = null
    private var pendingRoute: String? = null
    private fun readCalendarIntent(intent: Intent?) {
        if (intent?.action != CalendarWidgetProvider.ACTION_OPEN_CALENDAR) return
        val date = intent.getStringExtra("date")
        pendingRoute = if(date != null && Regex("\\d{4}-\\d{2}-\\d{2}").matches(date)) "/calendar?date=$date" else "/calendar"
        intent.action = Intent.ACTION_MAIN
        navigation?.invokeMethod("routeAvailable", null)
    }
    private var calendarBridge: CalendarBridge? = null

    override fun onResume() {
        super.onResume()
        ListenerConnection.ensureBound(this)
        BankInbox.notifyStatus()
        BankInbox.executor.execute { BankInboxWidget.update(applicationContext) }
        CalendarWidgetProvider.refresh(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bankBridge = BankDraftFlutterBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        calendarBridge = CalendarBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        navigation = io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "personal_finance/navigation").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if(call.method == "consumeRoute") { val route=pendingRoute; pendingRoute=null; result.success(route) }
                else result.notImplemented()
            }
        }
        readCalendarIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bankBridge?.onIntent(intent)
        readCalendarIntent(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        calendarBridge?.onPermissionResult(requestCode)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bankBridge?.close()
        bankBridge = null
        calendarBridge?.close()
        calendarBridge = null
        navigation?.setMethodCallHandler(null); navigation = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
