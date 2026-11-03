package app.personalfinance.finance_android.calendar

import android.content.Context
import android.content.ContentUris
import android.provider.CalendarContract as C
import org.json.JSONArray
import java.util.Calendar

object CalendarData {
    const val ACCOUNT = "minhvu2592005@gmail.com"
    private fun prefs(context: Context) = context.getSharedPreferences("pmv_calendar", Context.MODE_PRIVATE)
    fun calendars(context: Context): List<Map<String, Any?>> {
        val p = arrayOf(C.Calendars._ID, C.Calendars.CALENDAR_DISPLAY_NAME, C.Calendars.CALENDAR_COLOR, C.Calendars.VISIBLE, C.Calendars.SYNC_EVENTS)
        val rows = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(C.Calendars.CONTENT_URI, p,
            "${C.Calendars.ACCOUNT_NAME}=? AND ${C.Calendars.ACCOUNT_TYPE}=?",
            arrayOf(ACCOUNT, "com.google"), "${C.Calendars.CALENDAR_DISPLAY_NAME} ASC")?.use { c ->
            while (c.moveToNext()) rows.add(mapOf("id" to c.getLong(0), "name" to (c.getString(1) ?: ""),
                "color" to c.getInt(2), "visible" to (c.getInt(3)==1 && c.getInt(4)==1),
                "account_name" to ACCOUNT, "account_type" to "com.google"))
        }
        return rows
    }
    fun selected(context: Context): List<Long> {
        val available = calendars(context)
        val allowed = available.map { (it["id"] as Number).toLong() }.toSet()
        val raw = prefs(context).getString("selected", null)
        if (raw == null) return available.filter { it["visible"] == true }.map { (it["id"] as Number).toLong() }
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getLong(it) }.filter { it in allowed }
    }
    fun select(context: Context, ids: List<Long>) {
        val allowed = calendars(context).map { (it["id"] as Number).toLong() }.toSet()
        require(ids.all { it in allowed })
        check(prefs(context).edit().putString("selected", JSONArray(ids.distinct()).toString()).commit())
    }
    fun instances(context: Context, requested: List<Long>, start: Long, end: Long): List<Map<String, Any?>> {
        require(end > start && end-start <= 400L*86400000)
        val allowed = calendars(context).map { (it["id"] as Number).toLong() }.toSet()
        val ids = requested.distinct().filter { it in allowed }
        if (ids.isEmpty()) return emptyList()
        val uri = C.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(uri, start); ContentUris.appendId(uri, end)
        val p = arrayOf(C.Instances.EVENT_ID, C.Instances.TITLE, C.Instances.BEGIN, C.Instances.END, C.Instances.ALL_DAY, C.Instances.CALENDAR_ID, C.Instances.DISPLAY_COLOR)
        val rows = mutableListOf<Map<String, Any?>>()
        val seen = mutableSetOf<String>()
        context.contentResolver.query(uri.build(), p, "${C.Instances.CALENDAR_ID} IN (${ids.joinToString(",") { "?" }})",
            ids.map { it.toString() }.toTypedArray(), "${C.Instances.BEGIN} ASC")?.use { c ->
            while(c.moveToNext()) {
                if (!seen.add("${c.getLong(0)}:${c.getLong(2)}")) continue
                rows.add(mapOf("id" to c.getLong(0), "title" to (c.getString(1) ?: ""), "dtStart" to c.getLong(2),
                    "dtEnd" to c.getLong(3), "allDay" to (c.getInt(4)==1), "calId" to c.getLong(5), "color" to c.getInt(6)))
            }
        }
        return rows
    }
    // All-day timestamps represent UTC calendar dates, not a local-time instant.
    fun occursOn(event: Map<String, Any?>, day: Calendar): Boolean {
        val start = event["dtStart"] as Long
        val end = event["dtEnd"] as Long
        val from = day.clone() as Calendar
        from.set(Calendar.HOUR_OF_DAY,0); from.set(Calendar.MINUTE,0); from.set(Calendar.SECOND,0); from.set(Calendar.MILLISECOND,0)
        if (event["allDay"] == true) {
            val utc = Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
            utc.clear(); utc.set(from.get(Calendar.YEAR),from.get(Calendar.MONTH),from.get(Calendar.DAY_OF_MONTH))
            return start < utc.timeInMillis+86400000 && end > utc.timeInMillis
        }
        val to=from.clone() as Calendar; to.add(Calendar.DAY_OF_MONTH,1)
        return start < to.timeInMillis && (if (end>start) end else start+1) > from.timeInMillis
    }
}
