package app.quanlytao.user.widget

import android.content.Context
import android.content.SharedPreferences

object WidgetCache {
    private const val PREFS_NAME = "quanlytao_widget_prefs"
    private const val KEY_PENDING_COUNT = "pending_count"
    private const val KEY_IS_LOGGED_IN = "is_logged_in"
    private const val KEY_WIDGET_TOKEN = "widget_token"
    private const val KEY_API_BASE_URL = "api_base_url"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun setPendingCount(context: Context, count: Int) {
        getPrefs(context).edit().putInt(KEY_PENDING_COUNT, count).putBoolean(KEY_IS_LOGGED_IN, true).apply()
    }

    fun getPendingCount(context: Context): Int {
        return getPrefs(context).getInt(KEY_PENDING_COUNT, 0)
    }

    fun isLoggedIn(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_LOGGED_IN, false)
    }

    fun setWidgetCredentials(context: Context, token: String, baseUrl: String) {
        getPrefs(context).edit()
            .putString(KEY_WIDGET_TOKEN, token)
            .putString(KEY_API_BASE_URL, baseUrl)
            .putBoolean(KEY_IS_LOGGED_IN, true)
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
