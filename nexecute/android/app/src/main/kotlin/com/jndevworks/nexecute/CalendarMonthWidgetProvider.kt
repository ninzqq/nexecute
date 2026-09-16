package com.jndevworks.nexecute

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarMonthWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val theme = NexecuteWidgetTheme.fromId(
                widgetData.getString("widget_theme", "midnight"),
            )
            val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val visibleEventLabels = eventLabelCapacity(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250),
            )

            applyFrame(views, theme, widgetData)
            applyLaunchAction(context, views, widgetId)

            val rowCount = widgetData
                .getInt("widget_month_row_count", 6)
                .coerceIn(5, 6)
            val cellCount = widgetData
                .getInt("widget_month_cell_count", rowCount * DAYS_PER_WEEK)
                .coerceIn(0, MAX_CELL_COUNT)
            val todayDate = widgetData
                .getString("widget_month_today_date", "")
                .orEmpty()
            var totalEvents = 0

            views.removeAllViews(R.id.month_widget_grid)
            for (rowIndex in 0 until rowCount) {
                val row = RemoteViews(context.packageName, R.layout.widget_month_week_row)
                for (columnIndex in 0 until DAYS_PER_WEEK) {
                    val cellIndex = rowIndex * DAYS_PER_WEEK + columnIndex
                    val cell = createDayCell(
                        context = context,
                        widgetData = widgetData,
                        theme = theme,
                        cellIndex = cellIndex,
                        cellCount = cellCount,
                        todayDate = todayDate,
                        visibleEventLabels = visibleEventLabels,
                    )
                    totalEvents += cell.eventCount
                    row.addView(R.id.month_week_row, cell.views)
                }
                views.addView(R.id.month_widget_grid, row)
            }

            val status = widgetData.getString("widget_status", "").orEmpty()
            views.setTextViewText(R.id.month_widget_status, status)
            views.setViewVisibility(
                R.id.month_widget_status,
                if (status.isEmpty()) View.GONE else View.VISIBLE,
            )
            views.setTextViewText(
                R.id.month_widget_empty_hint,
                widgetData.getString(
                    "widget_month_empty_text",
                    "No events this month",
                ),
            )
            views.setViewVisibility(
                R.id.month_widget_empty_hint,
                if (totalEvents == 0 && status.isEmpty()) View.VISIBLE else View.GONE,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        super.onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private fun applyFrame(
        views: RemoteViews,
        theme: NexecuteWidgetTheme,
        widgetData: SharedPreferences,
    ) {
        views.setInt(R.id.month_widget_root, "setBackgroundColor", theme.headerBackground)
        views.setInt(R.id.month_widget_header, "setBackgroundColor", theme.headerBackground)
        views.setInt(R.id.month_widget_status, "setBackgroundColor", theme.gridBackground)
        views.setInt(R.id.month_widget_empty_hint, "setBackgroundColor", theme.gridBackground)
        views.setInt(R.id.month_widget_weekday_header, "setBackgroundColor", theme.gridBackground)
        views.setInt(R.id.month_widget_grid, "setBackgroundColor", theme.gridBackground)

        views.setTextViewText(
            R.id.month_widget_title,
            widgetData.getString("widget_title", "Nexecute"),
        )
        views.setTextViewText(
            R.id.month_widget_month_label,
            widgetData.getString("widget_month_label", ""),
        )
        views.setTextColor(R.id.month_widget_title, theme.primaryText)
        views.setTextColor(R.id.month_widget_month_label, theme.secondaryText)
        views.setTextColor(R.id.month_widget_status, theme.secondaryText)
        views.setTextColor(R.id.month_widget_empty_hint, theme.mutedText)

        val weekdayIds = intArrayOf(
            R.id.month_weekday_mon,
            R.id.month_weekday_tue,
            R.id.month_weekday_wed,
            R.id.month_weekday_thu,
            R.id.month_weekday_fri,
            R.id.month_weekday_sat,
            R.id.month_weekday_sun,
        )
        for (weekdayId in weekdayIds) {
            views.setTextColor(weekdayId, theme.mutedText)
        }
    }

    private fun applyLaunchAction(context: Context, views: RemoteViews, widgetId: Int) {
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { intent ->
            val launchIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.month_widget_root, launchIntent)
        }
    }

    private fun createDayCell(
        context: Context,
        widgetData: SharedPreferences,
        theme: NexecuteWidgetTheme,
        cellIndex: Int,
        cellCount: Int,
        todayDate: String,
        visibleEventLabels: Int,
    ): RenderedDayCell {
        val views = RemoteViews(context.packageName, R.layout.widget_month_day)
        val key = "widget_month_cell_$cellIndex"
        val date = widgetData.getString("${key}_date", "").orEmpty()
        val day = widgetData.getInt("${key}_day", 0)
        if (cellIndex >= cellCount || date.isEmpty() || day <= 0) {
            views.setViewVisibility(R.id.month_day_cell, View.INVISIBLE)
            return RenderedDayCell(views, 0)
        }

        val isInMonth = widgetData.getBoolean("${key}_in_month", false)
        val isToday = date == todayDate
        val dayTextColor = when {
            isToday -> theme.headerBackground
            isInMonth -> theme.primaryText
            else -> theme.mutedText
        }
        views.setViewVisibility(R.id.month_day_cell, View.VISIBLE)
        views.setInt(R.id.month_day_cell, "setBackgroundColor", theme.columnBackground)
        views.setTextViewText(R.id.month_day_number, day.toString())
        views.setTextColor(R.id.month_day_number, dayTextColor)
        if (isToday) {
            views.setInt(R.id.month_day_number, "setBackgroundColor", theme.accent)
        }

        val eventCount = widgetData.getInt("${key}_event_count", 0).coerceAtLeast(0)
        val displayedCount = minOf(eventCount, visibleEventLabels, MAX_EVENT_LABELS)
        views.removeAllViews(R.id.month_day_events)
        for (eventIndex in 0 until displayedCount) {
            val label = widgetData
                .getString("${key}_event_$eventIndex", "")
                .orEmpty()
            if (label.isEmpty()) continue

            val event = RemoteViews(context.packageName, R.layout.widget_month_event_item)
            event.setTextViewText(R.id.month_event_text, label)
            event.setTextColor(
                R.id.month_event_text,
                if (isInMonth) theme.primaryText else theme.mutedText,
            )
            event.setInt(
                R.id.month_event_text,
                "setBackgroundColor",
                theme.gridBackground,
            )
            views.addView(R.id.month_day_events, event)
        }

        val hiddenCount = eventCount - displayedCount
        val overflowText = when {
            eventCount == 0 -> ""
            visibleEventLabels == 0 -> "• $eventCount"
            hiddenCount > 0 -> "+$hiddenCount"
            else -> ""
        }
        views.setTextViewText(R.id.month_day_overflow, overflowText)
        views.setTextColor(
            R.id.month_day_overflow,
            if (isInMonth) theme.accent else theme.mutedText,
        )
        views.setViewVisibility(
            R.id.month_day_overflow,
            if (overflowText.isEmpty()) View.GONE else View.VISIBLE,
        )

        return RenderedDayCell(views, eventCount)
    }

    private fun eventLabelCapacity(heightDp: Int): Int = when {
        heightDp >= TWO_LABEL_HEIGHT_DP -> 2
        heightDp >= ONE_LABEL_HEIGHT_DP -> 1
        else -> 0
    }

    private data class RenderedDayCell(
        val views: RemoteViews,
        val eventCount: Int,
    )

    private companion object {
        const val DAYS_PER_WEEK = 7
        const val MAX_CELL_COUNT = 42
        const val MAX_EVENT_LABELS = 2
        const val ONE_LABEL_HEIGHT_DP = 230
        const val TWO_LABEL_HEIGHT_DP = 320
    }
}
