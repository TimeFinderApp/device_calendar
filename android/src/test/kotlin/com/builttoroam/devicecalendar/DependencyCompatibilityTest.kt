package com.builttoroam.devicecalendar

import com.builttoroam.devicecalendar.common.DayOfWeek
import com.builttoroam.devicecalendar.common.RecurrenceFrequency
import com.builttoroam.devicecalendar.models.Availability
import com.builttoroam.devicecalendar.models.Event
import com.builttoroam.devicecalendar.models.EventStatus
import com.builttoroam.devicecalendar.models.RecurrenceRule
import com.google.gson.GsonBuilder
import com.google.gson.JsonParser
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.dmfs.rfc5545.DateTime
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class DependencyCompatibilityTest {
    @Test
    fun `native event JSON preserves custom identity URL and recurrence wire values`() {
        val gson = GsonBuilder()
            .registerTypeAdapter(RecurrenceFrequency::class.java, RecurrenceFrequencySerializer())
            .registerTypeAdapter(DayOfWeek::class.java, DayOfWeekSerializer())
            .registerTypeAdapter(Availability::class.java, AvailabilitySerializer())
            .registerTypeAdapter(EventStatus::class.java, EventStatusSerializer())
            .create()
        val event = Event().apply {
            eventTitle = "Planning 🗓 café"
            eventId = "exception-42"
            eventURL = "https://timefinder.app/予定?id=42&source=calendar"
            eventAllDay = true
            eventStartDate = 1793491200000L
            recurringSegmentId = "segment-17"
            recurringLineageId = "series-9"
            androidOriginalId = "provider-8"
            androidOriginalInstanceTime = 1793491200000L
            androidIsException = true
            availability = Availability.FREE
            eventStatus = EventStatus.CONFIRMED
            recurrenceRule = RecurrenceRule(RecurrenceFrequency.WEEKLY).apply {
                daysOfWeek = mutableListOf(DayOfWeek.MONDAY, DayOfWeek.FRIDAY)
                totalOccurrences = 4
            }
        }
        val json = JsonParser.parseString(gson.toJson(event)).asJsonObject
        assertEquals(event.eventTitle, json["eventTitle"].asString)
        assertEquals(event.eventURL, json["eventURL"].asString)
        assertTrue(json["eventAllDay"].asBoolean)
        assertEquals("segment-17", json["recurringSegmentId"].asString)
        assertEquals("series-9", json["recurringLineageId"].asString)
        assertEquals("provider-8", json["androidOriginalId"].asString)
        assertEquals(event.androidOriginalInstanceTime, json["androidOriginalInstanceTime"].asLong)
        assertTrue(json["androidIsException"].asBoolean)
        assertEquals("FREE", json["availability"].asString)
        assertEquals("CONFIRMED", json["eventStatus"].asString)
        val recurrence = json["recurrenceRule"].asJsonObject
        assertEquals(1, recurrence["recurrenceFrequency"].asInt)
        assertEquals(listOf(2, 6), recurrence["daysOfWeek"].asJsonArray.map { it.asInt })
        assertEquals(4, recurrence["totalOccurrences"].asInt)
        assertFalse(json.has("eventDescription"))
    }

    @Test
    fun `native recurrence iterator retains weekly count and weekday semantics`() {
        assertEquals(
            listOf("20261102T090000Z", "20261106T090000Z", "20261109T090000Z", "20261113T090000Z"),
            instances("FREQ=WEEKLY;BYDAY=MO,FR;COUNT=4", "20261102T090000Z")
        )
    }

    @Test
    fun `native recurrence iterator retains negative ordinal month and until semantics`() {
        assertEquals(
            listOf("20261127T090000Z", "20261225T090000Z", "20270129T090000Z"),
            instances("FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20270131T235959Z", "20261101T090000Z")
        )
    }

    @Test
    fun `native recurrence iterator preserves all day leap year occurrences`() {
        assertEquals(
            listOf("20240229", "20280229", "20320229"),
            instances("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29;COUNT=3", "20240229")
        )
    }

    @Test
    fun `owned dispatcher cancellation completes child cleanup before close`() = runBlocking {
        Executors.newSingleThreadExecutor().asCoroutineDispatcher().use { dispatcher ->
            val scope = CoroutineScope(SupervisorJob() + dispatcher)
            val started = CompletableDeferred<Unit>()
            val finalized = AtomicInteger()
            val child = scope.launch {
                try {
                    started.complete(Unit)
                    awaitCancellation()
                } finally {
                    finalized.incrementAndGet()
                }
            }
            started.await()
            scope.cancel()
            child.join()
            assertTrue(child.isCancelled)
            assertEquals(1, finalized.get())
        }
    }

    private fun instances(rule: String, start: String): List<String> {
        val iterator = org.dmfs.rfc5545.recur.RecurrenceRule(rule).iterator(DateTime.parse(start))
        val result = mutableListOf<String>()
        while (iterator.hasNext() && result.size < 20) {
            result.add(iterator.nextDateTime().toString())
        }
        assertFalse(iterator.hasNext(), "fixture must terminate within its explicit recurrence bound")
        return result
    }
}
