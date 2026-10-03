package app.quanlytao.user.widget

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetCacheTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        WidgetCache.clear(context)
    }

  @Test
    fun testInitialStateIsLoggedOut() {
        assertFalse(WidgetCache.isLoggedIn(context))
        assertEquals(0, WidgetCache.getPendingCount(context))
        assertNull(WidgetCache.getWidgetToken(context))
    }

  @Test
    fun testSetPendingCountUpdatesCountAndMarksLoggedIn() {
        WidgetCache.setPendingCount(context, 5)
        assertTrue(WidgetCache.isLoggedIn(context))
        assertEquals(5, WidgetCache.getPendingCount(context))
    }

  @Test
    fun testSetWidgetCredentialsStoresTokenAndBaseUrl() {
        WidgetCache.setWidgetCredentials(context, "token_123", "https://api.quanlytao.app/v1")
        assertTrue(WidgetCache.isLoggedIn(context))
        assertEquals("token_123", WidgetCache.getWidgetToken(context))
        assertEquals("https://api.quanlytao.app/v1", WidgetCache.getApiBaseUrl(context))
    }

  @Test
    fun testClearWipesCredentialsAndResetsState() {
        WidgetCache.setWidgetCredentials(context, "token_123", "https://api.quanlytao.app/v1")
        WidgetCache.setPendingCount(context, 7)
        assertTrue(WidgetCache.isLoggedIn(context))

        WidgetCache.clear(context)

        assertFalse(WidgetCache.isLoggedIn(context))
        assertEquals(0, WidgetCache.getPendingCount(context))
        assertNull(WidgetCache.getWidgetToken(context))
    }
}
