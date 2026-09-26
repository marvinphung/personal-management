package app.personalfinance.finance_android

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import app.personalfinance.finance_android.banknotification.bridge.BankDraftFlutterBridge
import app.personalfinance.finance_android.banknotification.ListenerConnection

class MainActivity : FlutterActivity() {
    private var bankBridge: BankDraftFlutterBridge? = null
    override fun onResume() {
        super.onResume()
        ListenerConnection.ensureBound(this)
        app.personalfinance.finance_android.banknotification.BankInbox.notifyStatus()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bankBridge = BankDraftFlutterBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bankBridge?.onIntent(intent)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bankBridge?.close()
        bankBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
