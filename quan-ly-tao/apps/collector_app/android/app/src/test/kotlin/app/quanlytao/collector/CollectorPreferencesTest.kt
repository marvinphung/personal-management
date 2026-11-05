package app.quanlytao.collector

import app.quanlytao.collector.config.CollectorPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CollectorPreferencesTest {
    @Test
    fun backendUrlMustBeExplicitHttpsConfiguration() {
        val context = RuntimeEnvironment.getApplication()
        CollectorPreferences.clear(context)

        assertNull(CollectorPreferences.getBackendUrl(context))
        assertThrows(IllegalArgumentException::class.java) {
            CollectorPreferences.setBackendUrl(context, "http://10.0.2.2:8000/v1")
        }

        val publicUrl = "https://api.xn--qun-l-tao-49a0064f.id.vn/v1"
        CollectorPreferences.setBackendUrl(context, publicUrl)
        assertEquals(publicUrl, CollectorPreferences.getBackendUrl(context))
        assertFalse(CollectorPreferences.hasCredential(context))
    }
}
