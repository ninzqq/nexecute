package com.jndevworks.nexecute

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MonthWidgetRenderPolicyTest {
    @Test
    fun `row and cell counts stay within renderer bounds`() {
        assertEquals(5, MonthWidgetRenderPolicy.rowCount(0))
        assertEquals(5, MonthWidgetRenderPolicy.rowCount(5))
        assertEquals(6, MonthWidgetRenderPolicy.rowCount(6))
        assertEquals(6, MonthWidgetRenderPolicy.rowCount(12))
        assertEquals(0, MonthWidgetRenderPolicy.cellCount(-1))
        assertEquals(35, MonthWidgetRenderPolicy.cellCount(35))
        assertEquals(42, MonthWidgetRenderPolicy.cellCount(42))
        assertEquals(42, MonthWidgetRenderPolicy.cellCount(100))
    }

    @Test
    fun `month navigation continues across years without a page limit`() {
        assertEquals("2025-12", MonthWidgetRenderPolicy.shiftedMonth("2026-01", -1))
        assertEquals("2026-02", MonthWidgetRenderPolicy.shiftedMonth("2026-01", 1))
        assertEquals("2036-01", MonthWidgetRenderPolicy.shiftedMonth("2026-01", 120))
        assertEquals(null, MonthWidgetRenderPolicy.shiftedMonth("not-a-month", 1))
    }

    @Test
    fun `height selects compact one-label and two-label modes`() {
        assertEquals(0, MonthWidgetRenderPolicy.eventLabelCapacity(180))
        assertEquals(0, MonthWidgetRenderPolicy.eventLabelCapacity(229))
        assertEquals(1, MonthWidgetRenderPolicy.eventLabelCapacity(230))
        assertEquals(1, MonthWidgetRenderPolicy.eventLabelCapacity(319))
        assertEquals(2, MonthWidgetRenderPolicy.eventLabelCapacity(320))
    }

    @Test
    fun `event labels cap at two and overflow remains visible`() {
        assertEquals(0, MonthWidgetRenderPolicy.displayedEventCount(4, 0))
        assertEquals(1, MonthWidgetRenderPolicy.displayedEventCount(4, 1))
        assertEquals(2, MonthWidgetRenderPolicy.displayedEventCount(4, 2))
        assertEquals(2, MonthWidgetRenderPolicy.displayedEventCount(4, 9))
        assertEquals("• 4", MonthWidgetRenderPolicy.overflowText(4, 0, 0))
        assertEquals("+3", MonthWidgetRenderPolicy.overflowText(4, 1, 1))
        assertEquals("+2", MonthWidgetRenderPolicy.overflowText(4, 2, 2))
        assertEquals("", MonthWidgetRenderPolicy.overflowText(2, 2, 2))
    }

    @Test
    fun `status takes precedence over the empty message`() {
        assertFalse(MonthWidgetRenderPolicy.showStatus(""))
        assertTrue(MonthWidgetRenderPolicy.showStatus("Sign in"))
        assertTrue(MonthWidgetRenderPolicy.showEmpty(0, ""))
        assertFalse(MonthWidgetRenderPolicy.showEmpty(0, "Sign in"))
        assertFalse(MonthWidgetRenderPolicy.showEmpty(1, ""))
    }

    @Test
    fun `today requires a non-empty exact ISO date match`() {
        assertTrue(MonthWidgetRenderPolicy.isToday("2026-08-28", "2026-08-28"))
        assertFalse(MonthWidgetRenderPolicy.isToday("2026-08-27", "2026-08-28"))
        assertFalse(MonthWidgetRenderPolicy.isToday("", ""))
    }

    @Test
    fun `month surfaces are brighter across every theme`() {
        for (themeId in listOf("midnight", "cyberpunk", "cyberpunkMega", "forest", "neutral")) {
            val theme = NexecuteWidgetTheme.fromId(themeId)
            val surfaces = MonthWidgetRenderPolicy.surfaceColors(theme)

            assertTrue(brightness(surfaces.headerBackground) > brightness(theme.headerBackground))
            assertTrue(brightness(surfaces.gridBackground) > brightness(theme.gridBackground))
            assertTrue(brightness(surfaces.cellBackground) > brightness(theme.columnBackground))
            assertTrue(brightness(surfaces.eventBackground) > brightness(theme.gridBackground))
            assertEquals(0xFF, surfaces.headerBackground ushr 24 and 0xFF)
        }
    }

    private fun brightness(color: Int): Int =
        (color ushr 16 and 0xFF) + (color ushr 8 and 0xFF) + (color and 0xFF)
}

class NexecuteWidgetThemeTest {
    @Test
    fun `every preset resolves and unknown ids use midnight`() {
        val midnight = NexecuteWidgetTheme.fromId("midnight")
        val themes = listOf(
            NexecuteWidgetTheme.fromId("cyberpunk"),
            NexecuteWidgetTheme.fromId("cyberpunkMega"),
            NexecuteWidgetTheme.fromId("forest"),
            NexecuteWidgetTheme.fromId("neutral"),
            midnight,
        )

        assertEquals(5, themes.map { it.headerBackground }.distinct().size)
        assertEquals(midnight, NexecuteWidgetTheme.fromId("unknown"))
        for (theme in themes) {
            assertNotEquals(theme.gridBackground, theme.primaryText)
            assertNotEquals(theme.columnBackground, theme.accent)
        }
    }
}
