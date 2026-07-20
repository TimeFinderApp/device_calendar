package com.builttoroam.devicecalendar

import com.builttoroam.devicecalendar.common.AndroidDayOfWeekCodec
import com.builttoroam.devicecalendar.common.AndroidCalendarProviderProbeClassifier
import com.builttoroam.devicecalendar.common.AndroidRecurringIdentityNormalizer
import com.builttoroam.devicecalendar.common.DayOfWeek
import org.dmfs.rfc5545.Weekday
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EventRecurrenceTest {
    @Test
    fun `disabled calendar sync explains an empty provider calendar`() {
        assertEquals(
            "calendar_sync_disabled",
            AndroidCalendarProviderProbeClassifier.classify(
                syncEvents = false,
                accountSyncAutomatically = true,
                rawEventCount = 0,
                rawActiveEventCount = 0,
                rawExpansionCandidateCount = 0,
                instanceCountWithoutDeletedFilter = 0,
                invalidRecurrenceCount = 0,
            ),
        )
    }

    @Test
    fun `eligible raw events identify provider expansion failure`() {
        assertEquals(
            "provider_instance_expansion_failed",
            AndroidCalendarProviderProbeClassifier.classify(
                syncEvents = true,
                accountSyncAutomatically = true,
                rawEventCount = 4,
                rawActiveEventCount = 4,
                rawExpansionCandidateCount = 3,
                instanceCountWithoutDeletedFilter = 0,
                invalidRecurrenceCount = 0,
            ),
        )
    }

    @Test
    fun `instances excluded by plugin predicate identify query mismatch`() {
        assertEquals(
            "plugin_deleted_filter_mismatch",
            AndroidCalendarProviderProbeClassifier.classify(
                syncEvents = true,
                accountSyncAutomatically = true,
                rawEventCount = 1,
                rawActiveEventCount = 1,
                rawExpansionCandidateCount = 1,
                instanceCountWithoutDeletedFilter = 1,
                invalidRecurrenceCount = 0,
            ),
        )
    }

    @Test
    fun `missing provider rows are distinct from disabled sync`() {
        assertEquals(
            "calendar_provider_not_materialized",
            AndroidCalendarProviderProbeClassifier.classify(
                syncEvents = true,
                accountSyncAutomatically = true,
                rawEventCount = 0,
                rawActiveEventCount = 0,
                rawExpansionCandidateCount = 0,
                instanceCountWithoutDeletedFilter = 0,
                invalidRecurrenceCount = 0,
            ),
        )
    }

    @Test
    fun `calendar contract Monday round trips as Monday`() {
        val dayOfWeek = AndroidDayOfWeekCodec.fromCalendarContractValue(2)
        assertEquals(DayOfWeek.MONDAY, dayOfWeek)
        assertEquals(2, AndroidDayOfWeekCodec.toCalendarContractValue(dayOfWeek!!))
    }

    @Test
    fun `dmfs Tuesday round trips as Tuesday`() {
        val dayOfWeek = AndroidDayOfWeekCodec.fromDmfsWeekday(Weekday.TU)
        assertEquals(DayOfWeek.TUESDAY, dayOfWeek)
        assertEquals(Weekday.TU, AndroidDayOfWeekCodec.toDmfsWeekday(dayOfWeek!!))
    }

    @Test
    fun `invalid weekday values return null`() {
        assertNull(AndroidDayOfWeekCodec.fromCalendarContractValue(0))
        assertNull(AndroidDayOfWeekCodec.fromCalendarContractValue(8))
    }

    @Test
    fun `recurring identity prefers provider lineage signals`() {
        val identity = AndroidRecurringIdentityNormalizer.normalize(
            eventId = "123",
            hasRecurrence = true,
            originalId = "99",
            originalSyncId = "orig-sync",
            syncId = "segment-sync",
            uid2445 = "ical-uid",
            originalInstanceTime = 1234L,
        )

        assertEquals("segment-sync", identity.recurringSegmentId)
        assertEquals("ical-uid", identity.recurringLineageId)
        assertTrue(identity.isException)
    }

    @Test
    fun `non recurring rows omit normalized ids`() {
        val identity = AndroidRecurringIdentityNormalizer.normalize(
            eventId = "123",
            hasRecurrence = false,
            originalId = null,
            originalSyncId = null,
            syncId = null,
            uid2445 = null,
            originalInstanceTime = null,
        )

        assertNull(identity.recurringSegmentId)
        assertNull(identity.recurringLineageId)
        assertFalse(identity.isException)
    }
}
