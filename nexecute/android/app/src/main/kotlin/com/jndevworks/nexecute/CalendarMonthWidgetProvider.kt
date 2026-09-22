package com.jndevworks.nexecute

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarMonthWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val instancePrefix = "widget_month_instance_$widgetId"
            val monthPrefix = if (
                widgetData.getString("${instancePrefix}_anchor", "").isNullOrEmpty()
            ) {
                "widget_month"
            } else {
                instancePrefix
            }
            val monthAnchor = widgetData.getString("${monthPrefix}_anchor", "").orEmpty()
            val theme = NexecuteWidgetTheme.fromId(
                widgetData.getString("widget_theme", "midnight"),
            )
            val surfaceColors = MonthWidgetRenderPolicy.surfaceColors(theme)
            val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val visibleEventLabels = MonthWidgetRenderPolicy.eventLabelCapacity(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250),
            )

            applyFrame(
                views,
                theme,
                surfaceColors,
                widgetData,
                monthPrefix,
                monthAnchor,
            )
            applyLaunchAction(context, views, widgetId)
            applyMonthNavigation(context, views, widgetId, monthAnchor)

            val rowCount = MonthWidgetRenderPolicy.rowCount(
                widgetData.getInt("${monthPrefix}_row_count", 6),
            )
            val cellCount = MonthWidgetRenderPolicy.cellCount(
                widgetData.getInt(
                    "${monthPrefix}_cell_count",
                    rowCount * MonthWidgetRenderPolicy.DAYS_PER_WEEK,
                ),
            )
            val todayDate = widgetData
                .getString("widget_month_today_date", "")
                .orEmpty()
            var totalEvents = 0

            views.removeAllViews(R.id.month_widget_grid)
            for (rowIndex in 0 until rowCount) {
                val row = RemoteViews(context.packageName, R.layout.widget_month_week_row)
                for (columnIndex in 0 until MonthWidgetRenderPolicy.DAYS_PER_WEEK) {
                    val cellIndex =
                        rowIndex * MonthWidgetRenderPolicy.DAYS_PER_WEEK + columnIndex
                    val cell = createDayCell(
                        context = context,
                        widgetData = widgetData,
                        monthPrefix = monthPrefix,
                        theme = theme,
                        surfaceColors = surfaceColors,
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

            val status = widgetData.getString("${instancePrefix}_status", null)
                ?: widgetData.getString("widget_status", "").orEmpty()
            views.setTextViewText(R.id.month_widget_status, status)
            views.setViewVisibility(
                R.id.month_widget_status,
                if (MonthWidgetRenderPolicy.showStatus(status)) View.VISIBLE else View.GONE,
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
                if (MonthWidgetRenderPolicy.showEmpty(totalEvents, status)) {
                    View.VISIBLE
                } else {
                    View.GONE
                },
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

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val widgetData = context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE)
        val editor = widgetData.edit()
        val keys = widgetData.all.keys
        for (widgetId in appWidgetIds) {
            val prefix = "widget_month_instance_$widgetId"
            for (key in keys) {
                if (key.startsWith(prefix)) editor.remove(key)
            }
        }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
    }

    private fun applyFrame(
        views: RemoteViews,
        theme: NexecuteWidgetTheme,
        surfaceColors: MonthWidgetSurfaceColors,
        widgetData: SharedPreferences,
        monthPrefix: String,
        monthAnchor: String,
    ) {
        views.setInt(R.id.month_widget_root, "setBackgroundColor", surfaceColors.headerBackground)
        views.setInt(R.id.month_widget_header, "setBackgroundColor", surfaceColors.headerBackground)
        views.setInt(R.id.month_widget_status, "setBackgroundColor", surfaceColors.gridBackground)
        views.setInt(R.id.month_widget_empty_hint, "setBackgroundColor", surfaceColors.gridBackground)
        views.setInt(
            R.id.month_widget_weekday_header,
            "setBackgroundColor",
            surfaceColors.gridBackground,
        )
        views.setInt(R.id.month_widget_grid, "setBackgroundColor", surfaceColors.gridBackground)

        views.setTextViewText(
            R.id.month_widget_title,
            widgetData.getString("widget_title", "Nexecute"),
        )
        views.setTextViewText(
            R.id.month_widget_month_label,
            widgetData.getString("${monthPrefix}_label", ""),
        )
        views.setTextColor(R.id.month_widget_title, theme.primaryText)
        views.setTextColor(R.id.month_widget_month_label, theme.secondaryText)
        views.setTextColor(R.id.month_widget_previous, theme.primaryText)
        views.setTextColor(R.id.month_widget_next, theme.primaryText)
        val navigationVisibility =
            if (MonthWidgetRenderPolicy.shiftedMonth(monthAnchor, 1) != null) {
                View.VISIBLE
            } else {
                View.INVISIBLE
            }
        views.setViewVisibility(
            R.id.month_widget_previous,
            navigationVisibility,
        )
        views.setViewVisibility(
            R.id.month_widget_next,
            navigationVisibility,
        )
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
            // Some launchers let a click handler on the root consume taps from
            // interactive descendants. Keep launch actions on sibling content
            // so the month navigation buttons always receive their broadcasts.
            views.setOnClickPendingIntent(R.id.month_widget_title, launchIntent)
            views.setOnClickPendingIntent(R.id.month_widget_grid, launchIntent)
        }
    }

    private fun applyMonthNavigation(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        monthAnchor: String,
    ) {
        MonthWidgetRenderPolicy.shiftedMonth(monthAnchor, -1)?.let { target ->
            views.setOnClickPendingIntent(
                R.id.month_widget_previous,
                navigationIntent(context, widgetId, target),
            )
        }
        MonthWidgetRenderPolicy.shiftedMonth(monthAnchor, 1)?.let { target ->
            views.setOnClickPendingIntent(
                R.id.month_widget_next,
                navigationIntent(context, widgetId, target),
            )
        }
    }

    private fun navigationIntent(
        context: Context,
        widgetId: Int,
        target: String,
    ): PendingIntent {
        val yearMonth = target.split('-')
        val uri = Uri.Builder()
            .scheme("nexecute")
            .authority("month-widget")
            .appendQueryParameter("widgetId", widgetId.toString())
            .appendQueryParameter("year", yearMonth[0])
            .appendQueryParameter("month", yearMonth[1])
            .build()
        return HomeWidgetBackgroundIntent.getBroadcast(context, uri)
    }

    private fun createDayCell(
        context: Context,
        widgetData: SharedPreferences,
        monthPrefix: String,
        theme: NexecuteWidgetTheme,
        surfaceColors: MonthWidgetSurfaceColors,
        cellIndex: Int,
        cellCount: Int,
        todayDate: String,
        visibleEventLabels: Int,
    ): RenderedDayCell {
        val views = RemoteViews(context.packageName, R.layout.widget_month_day)
        val key = "${monthPrefix}_cell_$cellIndex"
        val date = widgetData.getString("${key}_date", "").orEmpty()
        val day = widgetData.getInt("${key}_day", 0)
        if (cellIndex >= cellCount || date.isEmpty() || day <= 0) {
            views.setViewVisibility(R.id.month_day_cell, View.INVISIBLE)
            return RenderedDayCell(views, 0)
        }

        val isInMonth = widgetData.getBoolean("${key}_in_month", false)
        val isToday = MonthWidgetRenderPolicy.isToday(date, todayDate)
        val dayTextColor = when {
            isToday -> theme.headerBackground
            isInMonth -> theme.primaryText
            else -> theme.mutedText
        }
        views.setViewVisibility(R.id.month_day_cell, View.VISIBLE)
        views.setInt(R.id.month_day_cell, "setBackgroundColor", surfaceColors.cellBackground)
        views.setTextViewText(R.id.month_day_number, day.toString())
        views.setTextColor(R.id.month_day_number, dayTextColor)
        if (isToday) {
            views.setInt(R.id.month_day_number, "setBackgroundColor", theme.accent)
        }

        val eventCount = widgetData.getInt("${key}_event_count", 0).coerceAtLeast(0)
        val displayedCount = MonthWidgetRenderPolicy.displayedEventCount(
            eventCount,
            visibleEventLabels,
        )
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
                surfaceColors.eventBackground,
            )
            views.addView(R.id.month_day_events, event)
        }

        val overflowText = MonthWidgetRenderPolicy.overflowText(
            eventCount,
            displayedCount,
            visibleEventLabels,
        )
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

    private data class RenderedDayCell(
        val views: RemoteViews,
        val eventCount: Int,
    )

    private companion object {
        const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"
    }
}
