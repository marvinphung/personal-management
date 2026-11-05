package app.quanlytao.user.widget

import android.content.Context
import android.content.SharedPreferences

object WidgetCache {
    private const val PREFS_NAME = "quanlytao_widget_prefs"
    private const val KEY_PENDING_COUNT = "pending_count"
    private const val KEY_IS_LOGGED_IN = "is_logged_in"
    private const val KEY_WIDGET_TOKEN = "widget_token"
    private const val KEY_API_BASE_URL = "api_base_url"
    private const val KEY_OWNER = "widget_owner"
    private const val KEY_GENERATION = "widget_generation"
    private const val KEY_LAST_UPDATED = "last_updated_epoch_ms"
    private const val KEY_IS_STALE = "is_stale"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun setPendingCount(
        context: Context,
        count: Int,
        owner: String? = null,
        generation: Int = 0,
    ) {
        val prefs = getPrefs(context)
        val currentGen = prefs.getInt(KEY_GENERATION, 0)
        if (generation > 0 && generation < currentGen) {
            // Drop updates from older session generation
            return
        }

        prefs.edit()
            .putInt(KEY_PENDING_COUNT, maxOf(0, count))
            .apply {
                if (owner != null) putString(KEY_OWNER, owner)
                if (generation > 0) putInt(KEY_GENERATION, generation)
            }
            .putBoolean(KEY_IS_STALE, false)
            .putLong(KEY_LAST_UPDATED, System.currentTimeMillis())
            .apply()
    }

    fun getPendingCount(context: Context): Int {
        return getPrefs(context).getInt(KEY_PENDING_COUNT, 0)
    }

    fun isLoggedIn(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_LOGGED_IN, false)
    }

    fun isStale(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_STALE, false)
    }

    fun markStale(context: Context) {
        getPrefs(context).edit().putBoolean(KEY_IS_STALE, true).apply()
    }

    fun getGeneration(context: Context): Int {
        return getPrefs(context).getInt(KEY_GENERATION, 0)
    }

    fun setWidgetCredentials(
        context: Context,
        token: String,
        baseUrl: String,
        owner: String? = null,
        generation: Int = 0,
    ) {
        getPrefs(context).edit()
            .putString(KEY_WIDGET_TOKEN, token)
            .putString(KEY_API_BASE_URL, baseUrl)
            .putString(KEY_OWNER, owner ?: "")
            .putInt(KEY_GENERATION, generation)
            .putBoolean(KEY_IS_LOGGED_IN, true)
            .putBoolean(KEY_IS_STALE, false)
            .putLong(KEY_LAST_UPDATED, System.currentTimeMillis())
            .apply()
    }

    fun getWidgetToken(context: Context): String? {
        return getPrefs(context).getString(KEY_WIDGET_TOKEN, null)
    }

    fun getApiBaseUrl(context: Context): String {
        return getPrefs(context).getString(KEY_API_BASE_URL, "http://10.0.2.2:8000/v1") ?: "http://10.0.2.2:8000/v1"
    }

    fun clear(context: Context) {
        getPrefs(context).edit().clear().apply()
    }
}
