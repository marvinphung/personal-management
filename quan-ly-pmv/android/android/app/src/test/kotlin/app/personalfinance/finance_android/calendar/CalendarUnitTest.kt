package app.personalfinance.finance_android.calendar

import io.flutter.plugin.common.BinaryMessenger
import java.nio.ByteBuffer
import android.app.Activity
import org.robolectric.Robolectric
import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.widget.TextView
import app.personalfinance.finance_android.R
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35])
class CalendarUnitTest {
    private val context get()=RuntimeEnvironment.getApplication()
    @Before fun provider() {
        ShadowContentResolver.registerProviderInternal("com.android.calendar",object:ContentProvider() {
            override fun onCreate()=true
            override fun getType(uri:Uri):String?=null
            override fun insert(uri:Uri,values:ContentValues?):Uri?=null
            override fun delete(uri:Uri,selection:String?,args:Array<out String>?)=0
            override fun update(uri:Uri,values:ContentValues?,selection:String?,args:Array<out String>?)=0
            override fun query(uri:Uri,p:Array<out String>?,selection:String?,args:Array<out String>?,sort:String?):Cursor {
                if(uri.path!!.contains("calendars")) {
                    assertArrayEquals(arrayOf(CalendarData.ACCOUNT,"com.google"),args)
                    return MatrixCursor(p!!).apply {
                        addRow(arrayOf<Any>(1L,"Visible",0xFF356A59,1,1))
                        addRow(arrayOf<Any>(2L,"Hidden",0xFF356A59,0,1))
                    }
                }
                return MatrixCursor(p!!)
            }
        })
        context.getSharedPreferences("pmv_calendar",0).edit().clear().commit()
    }
    @Test fun bridgeStartsWithoutCalendarPermissionAndClosesCleanly() {
        val activity=Robolectric.buildActivity(Activity::class.java).setup().get()
        Shadows.shadowOf(context).denyPermissions(Manifest.permission.READ_CALENDAR)
        val messenger=object: BinaryMessenger {
            override fun send(channel:String, message:ByteBuffer?) {}
            override fun send(channel:String,message:ByteBuffer?,callback:BinaryMessenger.BinaryReply?) {callback?.reply(null)}
            override fun setMessageHandler(channel:String,handler:BinaryMessenger.BinaryMessageHandler?) {}
        }
        val bridge=CalendarBridge(activity,messenger)
        bridge.close()
    }
    @Test fun defaultSelectionUsesVisibleSyncedCalendarsAndPersistsExplicitEmpty() {
        assertEquals(listOf(1L),CalendarData.selected(context))
        CalendarData.select(context,emptyList())
        assertEquals(emptyList<Long>(),CalendarData.selected(context))
        CalendarData.select(context,listOf(2L))
        assertEquals(listOf(2L),CalendarData.selected(context))
        try {CalendarData.select(context,listOf(99L));fail("Foreign calendar accepted")} catch(_:IllegalArgumentException) {}
    }
    @Test fun allDayEndIsExclusiveAndIndependentOfDeviceZone() {
        val utc=Calendar.getInstance(TimeZone.getTimeZone("UTC"));utc.clear();utc.set(2026,10,1)
        val event=mapOf<String,Any?>("dtStart" to utc.timeInMillis,"dtEnd" to utc.timeInMillis+86400000,"allDay" to true)
        val day=Calendar.getInstance(TimeZone.getTimeZone("GMT-08:00"));day.clear();day.set(2026,10,1)
        assertTrue(CalendarData.occursOn(event,day));day.add(Calendar.DAY_OF_MONTH,1)
        assertFalse(CalendarData.occursOn(event,day))
    }
    @Test fun widgetRendersActualMonthDaysAndOpensCalendarWithoutFlutter() {
        Shadows.shadowOf(context).grantPermissions(Manifest.permission.READ_CALENDAR)
        val manager=Shadows.shadowOf(AppWidgetManager.getInstance(context))
        val id=manager.createWidget(CalendarWidgetProvider::class.java,R.layout.calendar_widget)
        CalendarWidgetProvider.update(context)
        val root=manager.getViewFor(id)
        var dayCount=0
        for(i in 0 until 42) {
            val res=context.resources.getIdentifier("cal_day_$i","id",context.packageName)
            if(root.findViewById<TextView>(res).text.isNotEmpty())dayCount++
        }
        assertTrue(dayCount in 28..31)
        assertTrue(root.findViewById<TextView>(R.id.calendar_widget_events).text.contains("Không có sự kiện"))
        root.findViewById<TextView>(R.id.calendar_widget_day_title).performClick()
        val intent=Shadows.shadowOf(context).nextStartedActivity
        assertEquals(CalendarWidgetProvider.ACTION_OPEN_CALENDAR,intent.action)
        assertTrue(intent.getStringExtra("date")!!.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
    }
}
