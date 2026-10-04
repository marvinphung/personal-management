package app.quanlytao.collector.config

import android.content.Context
import android.net.Uri

object CollectorPreferences {
    private const val PREFS_NAME = "collector_prefs"
    private const val KEY_BACKEND_URL = "backend_url"
    private const val KEY_COLLECTOR_TOKEN = "collector_token"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun setBackendUrl(context: Context, value: String) {
        val normalized = value.trim().trimEnd('/')
        val uri = Uri.parse(normalized)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank()) {
            "Collector backend URL must use HTTPS and include a host"
        }
        preferences(context).edit().putString(KEY_BACKEND_URL, normalized).commit()
    }

    fun getBackendUrl(context: Context): String? =
        preferences(context).getString(KEY_BACKEND_URL, null)?.takeIf { it.isNotBlank() }

    fun getCredential(context: Context): String? =
        preferences(context).getString(KEY_COLLECTOR_TOKEN, null)?.takeIf { it.isNotBlank() }

    fun hasCredential(context: Context): Boolean = getCredential(context) != null

    fun clear(context: Context) {
        preferences(context).edit().clear().commit()
    }
}
