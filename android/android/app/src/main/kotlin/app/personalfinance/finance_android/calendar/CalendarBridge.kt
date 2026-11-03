package app.personalfinance.finance_android.calendar

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class CalendarBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val TARGET_ACCOUNT_NAME = CalendarData.ACCOUNT
        const val TARGET_ACCOUNT_TYPE = "com.google"
        const val PERMISSION_REQUEST_CODE = 2002
    }
    private val channel = MethodChannel(messenger, "personal_finance/calendar")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null
    private var closed = false
    private var observing = false
    private val changed = Runnable {
        if (!closed) { channel.invokeMethod("onCalendarChanged", null); CalendarWidgetProvider.refresh(activity) }
    }
    private val observer = object: ContentObserver(main) {
        override fun onChange(selfChange: Boolean) { main.removeCallbacks(changed); main.postDelayed(changed, 300) }
    }
    init {
        observeIfPermitted()
        channel.setMethodCallHandler { call, result ->
            if (call.method == "requestPermission") {
                if (hasPermission()) { observeIfPermitted(); result.success(true) }
                else if (pendingPermission != null) result.error("busy", "Permission request in progress", null)
                else { pendingPermission=result; ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.READ_CALENDAR), PERMISSION_REQUEST_CODE) }
            } else worker.execute {
                try {
                    check(hasPermission()) { "Calendar permission required" }
                    val response: Any? = when(call.method) {
                        "getCalendars" -> CalendarData.calendars(activity)
                        "loadSelectedIds" -> CalendarData.selected(activity)
                        "saveSelectedIds" -> {
                            val ids = call.argument<List<Number>>("ids") ?: emptyList()
                            CalendarData.select(activity, ids.map { it.toLong() }); CalendarWidgetProvider.refresh(activity); null
                        }
                        "getInstances" -> CalendarData.instances(activity,
                            (call.argument<List<Number>>("calendarIds") ?: emptyList()).map { it.toLong() },
                            call.argument<Number>("startMs")!!.toLong(), call.argument<Number>("endMs")!!.toLong())
                        else -> throw IllegalArgumentException("Unsupported calendar operation")
                    }
                    main.post { if (!closed) result.success(response) }
                } catch (_: Exception) { main.post { if (!closed) result.error("calendar", "Không thể đọc lịch. Kiểm tra quyền và thử lại.", null) } }
            }
        }
    }
    private fun observeIfPermitted() {
        if (closed || observing || !hasPermission()) return
        try {
            activity.contentResolver.registerContentObserver(CalendarContract.CONTENT_URI, true, observer)
            observing = true
        } catch (_: SecurityException) { observing = false }
    }
    private fun hasPermission() = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CALENDAR)==PackageManager.PERMISSION_GRANTED
    fun onPermissionResult(code: Int) {
        if (code != PERMISSION_REQUEST_CODE) return
        observeIfPermitted()
        pendingPermission?.success(hasPermission()); pendingPermission=null
        CalendarWidgetProvider.refresh(activity)
    }
    fun close() {
        closed=true; pendingPermission?.error("closed", "Activity closed", null); pendingPermission=null
        main.removeCallbacks(changed); if (observing) activity.contentResolver.unregisterContentObserver(observer)
        channel.setMethodCallHandler(null); worker.shutdown()
    }
}
