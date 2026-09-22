package com.jndevworks.nexecute

import java.time.YearMonth

internal object MonthWidgetRenderPolicy {
    const val DAYS_PER_WEEK = 7
    const val MAX_CELL_COUNT = 42
    const val MAX_EVENT_LABELS = 2

    private const val ONE_LABEL_HEIGHT_DP = 230
    private const val TWO_LABEL_HEIGHT_DP = 320

    fun surfaceColors(theme: NexecuteWidgetTheme): MonthWidgetSurfaceColors =
        MonthWidgetSurfaceColors(
            headerBackground = lift(theme.headerBackground, 12),
            gridBackground = lift(theme.gridBackground, 16),
            cellBackground = lift(theme.columnBackground, 20),
            eventBackground = lift(theme.gridBackground, 24),
        )

    fun rowCount(value: Int): Int = value.coerceIn(5, 6)

    fun cellCount(value: Int): Int = value.coerceIn(0, MAX_CELL_COUNT)

    fun shiftedMonth(anchor: String, delta: Long): String? = try {
        YearMonth.parse(anchor).plusMonths(delta).toString()
    } catch (_: RuntimeException) {
        null
    }

    fun eventLabelCapacity(heightDp: Int): Int = when {
        heightDp >= TWO_LABEL_HEIGHT_DP -> 2
        heightDp >= ONE_LABEL_HEIGHT_DP -> 1
        else -> 0
    }

    fun displayedEventCount(eventCount: Int, labelCapacity: Int): Int = minOf(
        eventCount.coerceAtLeast(0),
        labelCapacity.coerceIn(0, MAX_EVENT_LABELS),
        MAX_EVENT_LABELS,
    )

    fun overflowText(eventCount: Int, displayedCount: Int, labelCapacity: Int): String {
        val safeEventCount = eventCount.coerceAtLeast(0)
        if (safeEventCount == 0) return ""
        if (labelCapacity <= 0) return "• $safeEventCount"

        val hiddenCount = (safeEventCount - displayedCount).coerceAtLeast(0)
        return if (hiddenCount > 0) "+$hiddenCount" else ""
    }

    fun showStatus(status: String): Boolean = status.isNotEmpty()

    fun showEmpty(totalEvents: Int, status: String): Boolean =
        totalEvents <= 0 && !showStatus(status)

    fun isToday(date: String, todayDate: String): Boolean =
        date.isNotEmpty() && date == todayDate

    private fun lift(color: Int, amount: Int): Int {
        val alpha = color ushr 24 and 0xFF
        val red = ((color ushr 16 and 0xFF) + amount).coerceAtMost(0xFF)
        val green = ((color ushr 8 and 0xFF) + amount).coerceAtMost(0xFF)
        val blue = ((color and 0xFF) + amount).coerceAtMost(0xFF)
        return (alpha shl 24) or (red shl 16) or (green shl 8) or blue
    }
}

internal data class MonthWidgetSurfaceColors(
    val headerBackground: Int,
    val gridBackground: Int,
    val cellBackground: Int,
    val eventBackground: Int,
)
