package com.builttoroam.devicecalendar

import android.provider.CalendarContract
import android.text.format.DateUtils
import android.text.format.Time
import android.provider.CalendarContract.Events
import android.content.ContentValues

/**
 * Converts between Android's native recurrence format and RFC format.
 */
class RecurrenceRuleConverter {
    companion object {
        // Android frequency constants
        private const val FREQ_DAILY = 0
        private const val FREQ_WEEKLY = 1
        private const val FREQ_MONTHLY = 2
        private const val FREQ_YEARLY = 3

        /**
         * Converts Android format recurrence rule to RFC format.
         * @param androidRule The Android format recurrence rule
         * @return RFC format string or null if conversion fails
         */
        @JvmStatic
        fun toRfc(androidRule: Map<String, Any?>): String? {
            if (!androidRule.containsKey("recurrenceFrequency")) {
                return null
            }

            val frequency = when (androidRule["recurrenceFrequency"] as Int) {
                FREQ_DAILY -> "DAILY"
                FREQ_WEEKLY -> "WEEKLY"
                FREQ_MONTHLY -> "MONTHLY"
                FREQ_YEARLY -> "YEARLY"
                else -> return null
            }

            val parts = mutableListOf("FREQ=$frequency")

            // Add interval if present
            androidRule["interval"]?.let { interval ->
                if (interval is Int && interval > 1) {
                    parts.add("INTERVAL=$interval")
                }
            }

            // Add BYDAY for weekly recurrence
            if (frequency == "WEEKLY") {
                @Suppress("UNCHECKED_CAST")
                val daysOfWeek = androidRule["daysOfWeek"] as? List<Int>
                if (!daysOfWeek.isNullOrEmpty()) {
                    val byDay = daysOfWeek.map { day ->
                        when (day) {
                            1 -> "SU"
                            2 -> "MO"
                            3 -> "TU"
                            4 -> "WE"
                            5 -> "TH"
                            6 -> "FR"
                            7 -> "SA"
                            else -> null
                        }
                    }.filterNotNull()
                    if (byDay.isNotEmpty()) {
                        parts.add("BYDAY=${byDay.joinToString(",")}")
                    }
                }
            }

            // Add BYMONTHDAY and BYMONTH for monthly/yearly recurrence
            if (frequency == "MONTHLY" || frequency == "YEARLY") {
                androidRule["dayOfMonth"]?.let { dayOfMonth ->
                    if (dayOfMonth is Int) {
                        parts.add("BYMONTHDAY=$dayOfMonth")
                    }
                }

                if (frequency == "YEARLY") {
                    androidRule["monthOfYear"]?.let { monthOfYear ->
                        if (monthOfYear is Int) {
                            parts.add("BYMONTH=$monthOfYear")
                        }
                    }
                }

                // Handle nth weekday of month
                androidRule["weekOfMonth"]?.let { weekOfMonth ->
                    if (weekOfMonth is Int) {
                        @Suppress("UNCHECKED_CAST")
                        val daysOfWeek = androidRule["daysOfWeek"] as? List<Int>
                        if (!daysOfWeek.isNullOrEmpty()) {
                            val byDay = daysOfWeek.map { day ->
                                val weekday = when (day) {
                                    1 -> "SU"
                                    2 -> "MO"
                                    3 -> "TU"
                                    4 -> "WE"
                                    5 -> "TH"
                                    6 -> "FR"
                                    7 -> "SA"
                                    else -> null
                                }
                                if (weekday != null) "${weekOfMonth}$weekday" else null
                            }.filterNotNull()
                            if (byDay.isNotEmpty()) {
                                parts.add("BYDAY=${byDay.joinToString(",")}")
                            }
                        }
                    }
                }
            }

            return parts.joinToString(";")
        }
    }
} 