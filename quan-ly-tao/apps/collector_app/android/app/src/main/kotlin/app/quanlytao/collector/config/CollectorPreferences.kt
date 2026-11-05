package app.quanlytao.collector.config

import android.content.Context
import android.net.Uri

object CollectorPreferences {
    private const val PREFS_NAME = "collector_prefs"
    private const val KEY_BACKEND_URL = "backend_url"

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

    fun getCredential(context: Context): String? = CollectorCredentialStore.get(context)

    fun hasCredential(context: Context): Boolean = CollectorCredentialStore.has(context)

    fun clearCredential(context: Context) = CollectorCredentialStore.clear(context)

    fun clear(context: Context) {
        preferences(context).edit().clear().commit()
        CollectorCredentialStore.clear(context)
    }
}
