package com.builttoroam.devicecalendar.common

import org.dmfs.rfc5545.Weekday

object AndroidDayOfWeekCodec {
    fun fromCalendarContractValue(value: Int): DayOfWeek? = when (value) {
        1 -> DayOfWeek.SUNDAY
        2 -> DayOfWeek.MONDAY
        3 -> DayOfWeek.TUESDAY
        4 -> DayOfWeek.WEDNESDAY
        5 -> DayOfWeek.THURSDAY
        6 -> DayOfWeek.FRIDAY
        7 -> DayOfWeek.SATURDAY
        else -> null
    }

    fun toCalendarContractValue(dayOfWeek: DayOfWeek): Int = when (dayOfWeek) {
        DayOfWeek.SUNDAY -> 1
        DayOfWeek.MONDAY -> 2
        DayOfWeek.TUESDAY -> 3
        DayOfWeek.WEDNESDAY -> 4
        DayOfWeek.THURSDAY -> 5
        DayOfWeek.FRIDAY -> 6
        DayOfWeek.SATURDAY -> 7
    }

    fun fromDmfsWeekday(weekday: Weekday): DayOfWeek? = when (weekday) {
        Weekday.SU -> DayOfWeek.SUNDAY
        Weekday.MO -> DayOfWeek.MONDAY
        Weekday.TU -> DayOfWeek.TUESDAY
        Weekday.WE -> DayOfWeek.WEDNESDAY
        Weekday.TH -> DayOfWeek.THURSDAY
        Weekday.FR -> DayOfWeek.FRIDAY
        Weekday.SA -> DayOfWeek.SATURDAY
    }

    fun toDmfsWeekday(dayOfWeek: DayOfWeek): Weekday = when (dayOfWeek) {
        DayOfWeek.SUNDAY -> Weekday.SU
        DayOfWeek.MONDAY -> Weekday.MO
        DayOfWeek.TUESDAY -> Weekday.TU
        DayOfWeek.WEDNESDAY -> Weekday.WE
        DayOfWeek.THURSDAY -> Weekday.TH
        DayOfWeek.FRIDAY -> Weekday.FR
        DayOfWeek.SATURDAY -> Weekday.SA
    }
}
