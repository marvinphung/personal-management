package app.quanlytao.user.widget

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class WidgetWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    override suspend fun doWork(): Result {
        val token = WidgetCache.getWidgetToken(applicationContext) ?: return Result.success()
        val baseUrl = WidgetCache.getApiBaseUrl(applicationContext)
        val url = if (baseUrl.endsWith("/")) "${baseUrl}widget/summary" else "$baseUrl/widget/summary"

        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $token")
            .addHeader("Accept", "application/json")
            .get()
            .build()

        return try {
            httpClient.newCall(request).execute().use { response ->
                when (response.code) {
                    200 -> {
                        val body = response.body?.string() ?: return Result.retry()
                        val json = JSONObject(body)
                        val count = if (json.has("count")) json.getInt("count") else json.optInt("pending_count", 0)
                        WidgetCache.setPendingCount(applicationContext, count)
                        BankInboxWidget.update(applicationContext)
                        Result.success()
                    }
                    401, 403 -> {
                        // Credential revoked
                        WidgetCache.clear(applicationContext)
                        BankInboxWidget.update(applicationContext)
                        Result.failure()
                    }
                    else -> Result.retry()
                }
            }
        } catch (_: Exception) {
            Result.retry()
        }
    }

    companion object {
        private const val UNIQUE_WORK_NAME = "quanlytao_widget_summary_sync"

        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<WidgetWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest,
            )
        }
    }
}
