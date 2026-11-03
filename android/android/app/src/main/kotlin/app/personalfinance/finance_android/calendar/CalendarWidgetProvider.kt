package app.personalfinance.finance_android.calendar

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.graphics.Color
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import app.personalfinance.finance_android.MainActivity
import app.personalfinance.finance_android.R
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

class CalendarWidgetProvider: AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { runUpdate(context) }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context,intent)
        if (intent.action == ACTION_SELECT_DAY) {
            val id=intent.getIntExtra("widgetId", -1)
            if(id<0) return
            context.getSharedPreferences("pmv_calendar_widget",Context.MODE_PRIVATE).edit()
                .putString("date.$id", intent.getStringExtra("date")).apply()
            runUpdate(context)
        } else if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) runUpdate(context)
    }
    private fun runUpdate(context: Context) {
        val pending=goAsync()
        executor.execute { try { update(context) } finally { pending.finish() } }
    }
    companion object {
        const val ACTION_OPEN_CALENDAR="app.personalfinance.OPEN_CALENDAR"
        const val ACTION_SELECT_DAY="app.personalfinance.SELECT_CALENDAR_DAY"
        private val executor=Executors.newSingleThreadExecutor()
        fun refresh(context: Context) { executor.execute { update(context.applicationContext) } }
        fun update(context: Context) {
            val manager=AppWidgetManager.getInstance(context)
            val ids=manager.getAppWidgetIds(ComponentName(context,CalendarWidgetProvider::class.java))
            for(id in ids) {
                val v=RemoteViews(context.packageName,R.layout.calendar_widget)
                val now=Calendar.getInstance()
                val format=SimpleDateFormat("yyyy-MM-dd",Locale.US).apply { isLenient=false }
                val selected=Calendar.getInstance()
                val stored=context.getSharedPreferences("pmv_calendar_widget",Context.MODE_PRIVATE).getString("date.$id",null)
                try { if(stored!=null) selected.time=format.parse(stored)!! } catch(_: Exception) { /* use today */ }
                val month=now.clone() as Calendar
                month.set(Calendar.DAY_OF_MONTH,1); month.set(Calendar.HOUR_OF_DAY,0);month.set(Calendar.MINUTE,0);month.set(Calendar.SECOND,0);month.set(Calendar.MILLISECOND,0)
                val first=month.clone() as Calendar
                first.add(Calendar.DAY_OF_MONTH,-((first.get(Calendar.DAY_OF_WEEK)+5)%7))
                val end=first.clone() as Calendar;end.add(Calendar.DAY_OF_MONTH,42)
                var events=emptyList<Map<String,Any?>>()
                val granted=ContextCompat.checkSelfPermission(context,Manifest.permission.READ_CALENDAR)==PackageManager.PERMISSION_GRANTED
                var failed=false
                if(granted) try { events=CalendarData.instances(context,CalendarData.selected(context),first.timeInMillis-86400000,end.timeInMillis+86400000) } catch(_:Exception) { failed=true }
                v.setTextViewText(R.id.calendar_widget_month,SimpleDateFormat("'TH'M yyyy",Locale.US).format(month.time))
                for(index in 0 until 42) {
                    val day=first.clone() as Calendar;day.add(Calendar.DAY_OF_MONTH,index)
                    val res=context.resources.getIdentifier("cal_day_$index","id",context.packageName)
                    val inMonth=day.get(Calendar.MONTH)==month.get(Calendar.MONTH)
                    val key=format.format(day.time)
                    val count=events.count { CalendarData.occursOn(it,day) }
                    val today=key==format.format(now.time)
                    v.setTextViewText(res,if(inMonth) day.get(Calendar.DAY_OF_MONTH).toString() else "")
                    v.setTextColor(res,if(day.get(Calendar.DAY_OF_WEEK)==Calendar.SUNDAY) Color.rgb(240,105,105) else Color.WHITE)
                    val bg=when {today->Color.rgb(180,60,75); count>=6->Color.argb(210,25,130,120);count>=3->Color.argb(150,25,130,120);count>0->Color.argb(80,25,130,120);else->Color.TRANSPARENT}
                    v.setInt(res,"setBackgroundColor",if(inMonth) bg else Color.TRANSPARENT)
                    val click=Intent(context,CalendarWidgetProvider::class.java).setAction(ACTION_SELECT_DAY)
                        .setData(Uri.parse("pmv://widget/$id/$key")).putExtra("widgetId",id).putExtra("date",key)
                    v.setOnClickPendingIntent(res,PendingIntent.getBroadcast(context,0,click,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }
                val date=format.format(selected.time)
                v.setTextViewText(R.id.calendar_widget_day_title,SimpleDateFormat("d 'TH'M",Locale.US).format(selected.time))
                val dayEvents=events.filter { CalendarData.occursOn(it,selected) }
                val time=SimpleDateFormat("HH:mm",Locale.US)
                val text=when { !granted -> "Chạm để cấp quyền đọc lịch"; failed -> "Không thể cập nhật. Chạm để thử lại."; dayEvents.isEmpty()->"Không có sự kiện\nMột ngày tốt lành!";else->dayEvents.take(4).joinToString("\n") {
                    val label=if(it["allDay"]==true) "Cả ngày" else time.format(Date(it["dtStart"] as Long))
                    "$label  ${it["title"]}"
                }+(if(dayEvents.size>4) "\n+${dayEvents.size-4}" else "") }
                v.setTextViewText(R.id.calendar_widget_events,text)
                val open=Intent(context,MainActivity::class.java).setAction(ACTION_OPEN_CALENDAR)
                    .setData(Uri.parse("pmv://calendar?date=$date")).putExtra("date",date)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                val pi=PendingIntent.getActivity(context,id,open,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                v.setOnClickPendingIntent(R.id.calendar_widget_day_title,pi);v.setOnClickPendingIntent(R.id.calendar_widget_events,pi);v.setOnClickPendingIntent(R.id.calendar_widget_month,pi)
                manager.updateAppWidget(id,v)
            }
        }
    }
}
