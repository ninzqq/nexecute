package com.jndevworks.nexecute

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            val theme = NexecuteWidgetTheme.fromId(
                widgetData.getString("widget_theme", "midnight"),
            )

            views.setInt(R.id.widget_root, "setBackgroundColor", theme.headerBackground)
            views.setInt(R.id.widget_header, "setBackgroundColor", theme.headerBackground)
            views.setInt(R.id.widget_grid, "setBackgroundColor", theme.gridBackground)
            views.setInt(R.id.widget_status, "setBackgroundColor", theme.gridBackground)
            views.setInt(R.id.widget_empty_hint, "setBackgroundColor", theme.gridBackground)
            views.setTextColor(R.id.widget_title, theme.primaryText)
            views.setTextColor(R.id.widget_week_number, theme.secondaryText)
            views.setTextColor(R.id.widget_empty_hint, theme.secondaryText)

            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("widget_title", "Nexecute"),
            )
            views.setTextViewText(
                R.id.widget_week_number,
                widgetData.getString("widget_week_number", ""),
            )

            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { intent ->
                val launchIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            val status = widgetData.getString("widget_status", "").orEmpty()
            views.setTextViewText(R.id.widget_status, status)
            views.setViewVisibility(
                R.id.widget_status,
                if (status.isEmpty()) View.GONE else View.VISIBLE,
            )

            val showWeekends = widgetData.getBoolean("show_weekends", true)
            val orderedDays = listOf("mon", "tue", "wed", "thu", "fri", "sat", "sun")
            val visibleDays = if (showWeekends) orderedDays else orderedDays.take(5)
            val fallbackLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
            val columnIds = intArrayOf(
                R.id.day_column_mon,
                R.id.day_column_tue,
                R.id.day_column_wed,
                R.id.day_column_thu,
                R.id.day_column_fri,
                R.id.day_column_sat,
                R.id.day_column_sun,
            )
            val dateIds = intArrayOf(
                R.id.widget_mon_date,
                R.id.widget_tue_date,
                R.id.widget_wed_date,
                R.id.widget_thu_date,
                R.id.widget_fri_date,
                R.id.widget_sat_date,
                R.id.widget_sun_date,
            )
            val eventContainerIds = intArrayOf(
                R.id.events_container_mon,
                R.id.events_container_tue,
                R.id.events_container_wed,
                R.id.events_container_thu,
                R.id.events_container_fri,
                R.id.events_container_sat,
                R.id.events_container_sun,
            )
            val todayKey = widgetData.getString("widget_today_key", "").orEmpty()
            var totalEvents = 0

            for (index in orderedDays.indices) {
                val columnId = columnIds[index]
                if (index >= visibleDays.size) {
                    views.setViewVisibility(columnId, View.GONE)
                    continue
                }

                val dayKey = visibleDays[index]
                views.setViewVisibility(columnId, View.VISIBLE)
                views.setInt(columnId, "setBackgroundColor", theme.columnBackground)

                val label = widgetData
                    .getString("widget_${dayKey}_label", fallbackLabels[index])
                    .orEmpty()
                val date = widgetData.getString("widget_${dayKey}_date", "").orEmpty()
                val header = "$label $date".trim()
                if (dayKey == todayKey) {
                    val highlightedHeader = SpannableString(header).apply {
                        setSpan(
                            StyleSpan(Typeface.BOLD),
                            0,
                            length,
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                        )
                    }
                    views.setTextViewText(dateIds[index], highlightedHeader)
                    views.setTextColor(dateIds[index], theme.accent)
                } else {
                    views.setTextViewText(dateIds[index], header)
                    views.setTextColor(dateIds[index], theme.primaryText)
                }

                val containerId = eventContainerIds[index]
                views.removeAllViews(containerId)
                val eventCount = widgetData.getInt("event_${dayKey}_count", 0)
                totalEvents += eventCount
                for (eventIndex in 0 until eventCount) {
                    val eventText = widgetData
                        .getString("event_${dayKey}_$eventIndex", "")
                        .orEmpty()
                    if (eventText.isEmpty()) continue

                    val eventView = RemoteViews(context.packageName, R.layout.widget_event_item)
                    eventView.setTextViewText(R.id.event_text, eventText)
                    eventView.setTextColor(R.id.event_text, theme.primaryText)
                    eventView.setInt(
                        R.id.event_chip,
                        "setBackgroundResource",
                        R.drawable.widget_chip_dark,
                    )
                    eventView.setInt(
                        R.id.event_color_stripe,
                        "setBackgroundColor",
                        theme.accent,
                    )
                    eventView.setViewVisibility(R.id.event_color_stripe, View.VISIBLE)
                    views.addView(containerId, eventView)
                }
            }

            views.setTextViewText(
                R.id.widget_empty_hint,
                widgetData.getString("widget_empty_text", "No events this week"),
            )
            views.setViewVisibility(
                R.id.widget_empty_hint,
                if (totalEvents == 0 && status.isEmpty()) View.VISIBLE else View.GONE,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
