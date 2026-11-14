package com.builttoroam.devicecalendar

import android.Manifest
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Looper
import android.provider.CalendarContract
import com.builttoroam.devicecalendar.common.Constants
import com.builttoroam.devicecalendar.common.RecurrenceFrequency
import com.builttoroam.devicecalendar.models.Event
import com.builttoroam.devicecalendar.models.RecurrenceRule
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class CalendarDelegateProviderTest {
    private lateinit var provider: CalendarProvider
    private lateinit var delegate: CalendarDelegate

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication() as Context
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR,
        )
        provider = CalendarProvider()
        ShadowContentResolver.registerProviderInternal(CalendarContract.AUTHORITY, provider)
        delegate = CalendarDelegate(null, context, MethodChannel(NoopMessenger(), "calendar-test"))
    }

    @Test
    fun `null instances cursor fails retrieval instead of returning empty events`() {
        provider.nullInstances = true
        val result = retrieve()
        assertNotNull("Unknown provider state must not authorize deletion", result.error)
        assertNull(result.value)
    }

    @Test
    fun `null recurrence cursor fails retrieval instead of changing series to singles`() {
        provider.nullRecurrence = true
        provider.instanceCount = 2
        val result = retrieve()
        assertNotNull("Missing recurrence metadata must fail the complete snapshot", result.error)
        assertNull(result.value)
    }

    @Test
    fun `incomplete recurrence metadata fails retrieval`() {
        provider.instanceCount = 2
        provider.missingRecurrenceRow = true
        assertNotNull(retrieve().error)
    }

    @Test
    fun `malformed recurrence keeps one series identity instead of single events`() {
        provider.instanceCount = 2
        provider.recurrenceRule = "FREQ=INVALID"
        assertUnreadableSeries(retrieve())
    }

    @Test
    fun `unsupported recurrence keeps one series identity without failing the snapshot`() {
        provider.instanceCount = 2
        provider.recurrenceRule = "FREQ=HOURLY"
        assertUnreadableSeries(retrieve())
    }

    @Test
    fun `provider recurrence crosses native wire without losing selectors or cutoff`() {
        provider.instanceCount = 2
        provider.recurrenceRule = "FREQ=MONTHLY;BYMONTHDAY=1,15;UNTIL=20261231T235959Z"
        val result = retrieve()
        assertNull(result.error)
        val event = com.google.gson.JsonParser.parseString(result.value as String).asJsonArray[0].asJsonObject
        assertEquals(provider.recurrenceRule, event["recurrenceRule"].asJsonObject["sourceRruleString"]?.asString)
        assertEquals(1_794_657_600_000L, event["eventStartDate"].asLong)
    }

    @Test
    fun `repeated instances query shared event metadata once`() {
        provider.instanceCount = 180
        val result = retrieve()
        assertNull(result.error)
        assertEquals(1, provider.attendeeQueries)
        assertEquals(1, provider.reminderQueries)
        val events = com.google.gson.JsonParser.parseString(result.value as String).asJsonArray
        assertEquals(180, events.size())
        assertEquals(180, events.map { it.asJsonObject["eventStartDate"].asLong }.distinct().size)
        for (event in events) {
            assertEquals("guest@test.timefinder", event.asJsonObject["attendees"].asJsonArray[0]
                .asJsonObject["emailAddress"].asString)
            assertEquals(15, event.asJsonObject["reminders"].asJsonArray[0].asJsonObject["minutes"].asInt)
        }
    }

    @Test
    fun `empty complete instances snapshot remains successful`() {
        val result = retrieve()
        assertNull(result.error)
        assertEquals("[]", result.value)
    }

    @Test
    fun `recurring creation supplies duration instead of end timestamp`() {
        val event = event().apply {
            recurrenceRule = RecurrenceRule(RecurrenceFrequency.DAILY)
        }
        val result = write(event)
        assertNull(result.error)
        assertEquals("PT3600S", provider.written!!.getAsString(CalendarContract.Events.DURATION))
        assertNull(provider.written!!.get(CalendarContract.Events.DTEND))
    }

    @Test
    fun `all day recurring creation preserves calendar day duration`() {
        val event = event().apply {
            eventAllDay = true
            eventStartDate = 0
            eventEndDate = 172_800_000
            recurrenceRule = RecurrenceRule(RecurrenceFrequency.DAILY)
        }
        val result = write(event)
        assertNull(result.error)
        assertEquals("P2D", provider.written!!.getAsString(CalendarContract.Events.DURATION))
        assertNull(provider.written!!.get(CalendarContract.Events.DTEND))
    }

    @Test
    fun `changing series to single explicitly clears recurrence`() {
        provider.stored.put(CalendarContract.Events.RRULE, "FREQ=DAILY")
        provider.stored.put(CalendarContract.Events.RDATE, "20261115T090000Z")
        provider.stored.put(CalendarContract.Events.EXDATE, "20261116T090000Z")
        val result = write(event().apply { eventId = "42" })
        assertNull(result.error)
        assertNull("Single event must stop producing recurring instances",
            provider.stored.get(CalendarContract.Events.RRULE))
        assertEquals(3_600_000L, provider.stored.getAsLong(CalendarContract.Events.DTEND) -
            provider.stored.getAsLong(CalendarContract.Events.DTSTART))
        assertNull(provider.stored.get(CalendarContract.Events.DURATION))
        assertNull(provider.stored.get(CalendarContract.Events.RDATE))
        assertNull(provider.stored.get(CalendarContract.Events.EXDATE))
    }

    @Test
    fun `missing update target reports not found before metadata changes`() {
        provider.updateCount = 0
        val result = write(event().apply { eventId = "42" })
        assertEquals("404", result.error)
        assertEquals(0, provider.attendeeQueries)
        assertEquals(0, provider.reminderDeletes)
    }

    @Test
    fun `invalid update identity cannot create a new provider event`() {
        val result = write(event().apply { eventId = "invalid" })
        assertEquals("400", result.error)
        assertNull(provider.written)
    }

    private fun event() = Event().apply {
        eventTitle = "Planning"
        eventStartDate = 1_794_657_600_000L
        eventEndDate = eventStartDate!! + 3_600_000L
        eventStartTimeZone = "UTC"
        eventEndTimeZone = "UTC"
    }

    private fun assertUnreadableSeries(result: CapturedResult) {
        assertNull(result.error)
        val events = com.google.gson.JsonParser.parseString(result.value as String).asJsonArray
        assertEquals(2, events.size())
        for (event in events) {
            val json = event.asJsonObject
            assertEquals(true, json["recurrenceRuleUnreadable"].asBoolean)
            assertEquals(false, json.has("recurrenceRule") && !json["recurrenceRule"].isJsonNull)
        }
        assertEquals(1, events.map { it.asJsonObject["recurringSegmentId"].asString }.distinct().size)
    }

    private fun retrieve(): CapturedResult {
        val result = CapturedResult()
        delegate.retrieveEvents("1", 1_794_000_000_000L, 1_810_000_000_000L, emptyList(), result)
        awaitResult(result)
        return result
    }

    private fun write(event: Event): CapturedResult {
        val result = CapturedResult()
        delegate.createOrUpdateEvent("1", event, result)
        awaitResult(result)
        return result
    }

    private fun awaitResult(result: CapturedResult) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (!result.finished.get() && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.yield()
        }
        assertTrue("Native worker must complete its method result", result.finished.get())
    }

    class CapturedResult : MethodChannel.Result {
        val finished = AtomicBoolean(false)
        var value: Any? = null
        var error: String? = null
        override fun success(result: Any?) { value = result; finished.set(true) }
        override fun error(code: String, message: String?, details: Any?) {
            error = code; finished.set(true)
        }
        override fun notImplemented() { error = "notImplemented"; finished.set(true) }
    }

    class NoopMessenger : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            callback?.reply(null)
        }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {}
    }

    class CalendarProvider : ContentProvider() {
        var nullInstances = false
        var nullRecurrence = false
        var missingRecurrenceRow = false
        var recurrenceRule = "FREQ=DAILY"
        var instanceCount = 0
        var attendeeQueries = 0
        var reminderQueries = 0
        var reminderDeletes = 0
        var updateCount = 1
        var written: ContentValues? = null
        val stored = ContentValues()

        override fun onCreate() = true
        override fun getType(uri: Uri): String? = null
        override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
            selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
            val columns = projection!!.map { it }.toTypedArray()
            val cursor = MatrixCursor(columns)
            when (uri.pathSegments.first()) {
                "calendars" -> cursor.addRow(arrayOf<Any?>(1L, "synthetic", "local", "Test", "synthetic",
                    CalendarContract.Calendars.CAL_ACCESS_OWNER, 0, "1", 1, 1))
                "instances" -> {
                    if (nullInstances) return null
                    if (columns.contentEquals(Constants.EVENT_PROJECTION)) {
                        repeat(instanceCount) { occurrence ->
                            val start = 1_794_657_600_000L + occurrence * 86_400_000L
                            cursor.addRow(arrayOf<Any?>(42L, "Planning", null, start, start + 3_600_000L,
                                null, null, 0, null, "UTC", "UTC", 0, 1, null, "series-42", null,
                                "lineage-42", null))
                        }
                    }
                }
                "events" -> {
                    if (nullRecurrence) return null
                    if (columns.contentEquals(arrayOf(CalendarContract.Events._ID, CalendarContract.Events.RRULE)) &&
                        instanceCount > 0 && !missingRecurrenceRow) cursor.addRow(arrayOf<Any?>(42L, recurrenceRule))
                }
                "attendees" -> {
                    attendeeQueries++
                    cursor.addRow(arrayOf<Any?>(1L, 42L, "Guest", "guest@test.timefinder", 1, 1, 1))
                }
                "reminders" -> {
                    reminderQueries++
                    if (columns.contentEquals(Constants.REMINDER_PROJECTION)) cursor.addRow(arrayOf<Any?>(42L, 15))
                }
            }
            return cursor
        }

        override fun insert(uri: Uri, values: ContentValues?): Uri {
            if (uri == CalendarContract.Events.CONTENT_URI) {
                written = ContentValues(values)
                stored.putAll(values)
            }
            return Uri.withAppendedPath(uri, "42")
        }

        override fun update(uri: Uri, values: ContentValues?, selection: String?,
            selectionArgs: Array<out String>?): Int {
            written = ContentValues(values)
            if (updateCount > 0) stored.putAll(values)
            return updateCount
        }

        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
            if (uri.pathSegments.first() == "reminders") reminderDeletes++
            return 1
        }
    }
}
