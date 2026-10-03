package app.quanlytao.user

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import app.quanlytao.user.widget.BankInboxWidget
import app.quanlytao.user.widget.WidgetCache
import app.quanlytao.user.widget.WidgetWorker

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.quanlytao.user/widget")
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetCount" -> {
                    val count = call.argument<Int>("count") ?: 0
                    WidgetCache.setPendingCount(this, count)
                    BankInboxWidget.update(this)
                    result.success(true)
                }
                "setWidgetCredentials" -> {
                    val token = call.argument<String>("token") ?: ""
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    WidgetCache.setWidgetCredentials(this, token, baseUrl)
                    WidgetWorker.schedulePeriodic(this)
                    BankInboxWidget.update(this)
                    result.success(true)
                }
                "clearWidget" -> {
                    WidgetCache.clear(this)
                    BankInboxWidget.update(this)
                    result.success(true)
                }
                "getInitialRoute" -> {
                    val uri = intent?.data
                    if (uri != null && uri.scheme == "quanlytao" && uri.host == "bank-inbox") {
                        result.success("/pending")
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data
        if (uri != null && uri.scheme == "quanlytao" && uri.host == "bank-inbox") {
            widgetChannel?.invokeMethod("onDeepLink", "/pending")
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
