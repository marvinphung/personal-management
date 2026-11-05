package app.quanlytao.collector.queue

import android.content.Context
import app.quanlytao.collector.config.CollectorPreferences
import androidx.work.Constraints
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.CoroutineWorker
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

class UploadWorker(
    private val appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val db = CollectorDatabase.getInstance(appContext)
        val batch = db.getPendingBatch(20)
        if (batch.isEmpty()) {
            return Result.success()
        }

        val baseUrl = CollectorPreferences.getBackendUrl(appContext) ?: return Result.failure()
        val credential = CollectorPreferences.getCredential(appContext) ?: return Result.failure()

        val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
        val endpoint = URL("$cleanBase/collector/events")

        val payload = JSONArray()
        for (item in batch) {
            val obj = JSONObject().apply {
                put("event_id", item.eventId)
                put("collector_epoch", item.collectorEpoch)
                put("binding_id", item.bindingId)
                put("binding_version", item.bindingVersion)
                put("capture_epoch", item.captureEpoch)
                put("bank_code", item.bankCode)
                put("owner_account", item.ownerAccount)
                put("direction", item.direction)
                put("amount_vnd", item.amountVnd.toString())
                put("occurred_at", DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochMilli(item.occurredAt)))
                put("time_source", item.timeSource)
                put("bank_description", item.bankDescription)
                put("bank_reference", item.bankReference)
                put("source_package", item.sourcePackage)
                put("parser_version", item.parserVersion)
                put("source_event_key", item.sourceEventKey)
            }
            payload.put(obj)
        }

        try {
            val conn = endpoint.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $credential")
            conn.doOutput = true
            conn.connectTimeout = 10000
            conn.readTimeout = 10000

            OutputStreamWriter(conn.outputStream).use {
                it.write(payload.toString())
                it.flush()
            }

            val code = conn.responseCode
            if (code in 200..299) {
                val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                val results = JSONArray(responseText)
                for (i in 0 until results.length()) {
                    val res = results.getJSONObject(i)
                    val eventId = res.getString("event_id")
                    val status = res.getString("status")
                    // Terminal outcomes: accepted, duplicate, dropped
                    if (status == "accepted" || status == "duplicate" || status == "dropped") {
                        db.remove(eventId)
                        db.incrementCounter(status)
                    } else {
                        db.incrementRetry(eventId)
                    }
                }
                return Result.success()
            } else if (code == 401 || code == 403) {
                // Collector credential or epoch failure: do not busy loop
                CollectorPreferences.clearCredential(appContext)
                return Result.failure()
            } else {
                // 5xx or server temporary error: retry with backoff
                for (item in batch) {
                    db.incrementRetry(item.eventId)
                }
                return Result.retry()
            }
        } catch (_: Exception) {
            for (item in batch) {
                db.incrementRetry(item.eventId)
            }
            return Result.retry()
        }
    }

    companion object {
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<UploadWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "collector-upload",
                // A retrying worker may be hours into exponential backoff. Every
                // new notification and listener reconnect is a fresh signal that
                // must attempt the complete durable queue immediately.
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
