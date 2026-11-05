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
    fun testSetPendingCountDoesNotResurrectLoggedInState() {
        // R3: Updating count while logged out should not mark logged in
        WidgetCache.setPendingCount(context, 5)
        assertFalse(WidgetCache.isLoggedIn(context))
        assertEquals(5, WidgetCache.getPendingCount(context))
    }

    @Test
    fun testSetWidgetCredentialsStoresTokenAndMarksLoggedIn() {
        WidgetCache.setWidgetCredentials(
            context,
            "scoped_widget_token_123",
            "https://api.quanlytao.app/v1",
            owner = "user_1",
            generation = 1,
        )
        assertTrue(WidgetCache.isLoggedIn(context))
        assertEquals("scoped_widget_token_123", WidgetCache.getWidgetToken(context))
        assertEquals("https://api.quanlytao.app/v1", WidgetCache.getApiBaseUrl(context))
        assertEquals(1, WidgetCache.getGeneration(context))
    }

    @Test
    fun testOldGenerationUpdatesAreDropped() {
        // Set credentials with generation 2
        WidgetCache.setWidgetCredentials(
            context,
            "token_gen2",
            "https://api.quanlytao.app/v1",
            owner = "user_2",
            generation = 2,
        )
        WidgetCache.setPendingCount(context, 10, generation = 2)
        assertEquals(10, WidgetCache.getPendingCount(context))

        // An async update from generation 1 arrives late -> MUST be dropped
        WidgetCache.setPendingCount(context, 999, generation = 1)
        assertEquals(10, WidgetCache.getPendingCount(context))
        assertEquals(2, WidgetCache.getGeneration(context))
    }

    @Test
    fun testAcceptedCountUpdatePersistsItsGeneration() {
        WidgetCache.setPendingCount(context, 3, owner = "user_3", generation = 3)

        assertEquals(3, WidgetCache.getGeneration(context))
    }

    @Test
    fun testClearWipesCredentialsAndResetsState() {
        WidgetCache.setWidgetCredentials(
            context,
            "token_123",
            "https://api.quanlytao.app/v1",
            owner = "user_1",
            generation = 1,
        )
        WidgetCache.setPendingCount(context, 7, generation = 1)
        assertTrue(WidgetCache.isLoggedIn(context))

        WidgetCache.clear(context)

        assertFalse(WidgetCache.isLoggedIn(context))
        assertEquals(0, WidgetCache.getPendingCount(context))
        assertNull(WidgetCache.getWidgetToken(context))
    }
}
