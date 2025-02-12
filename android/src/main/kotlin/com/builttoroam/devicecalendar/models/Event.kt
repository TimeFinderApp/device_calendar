package com.builttoroam.devicecalendar.models

import com.builttoroam.devicecalendar.RecurrenceRuleConverter
import com.google.gson.annotations.SerializedName
import java.util.*

data class Event(
    @SerializedName("eventId") var eventId: String? = null,
    @SerializedName("calendarId") var calendarId: String? = null,
    @SerializedName("title") var title: String? = null,
    @SerializedName("description") var description: String? = null,
    @SerializedName("start") var start: Date? = null,
    @SerializedName("end") var end: Date? = null,
    @SerializedName("allDay") var allDay: Boolean? = null,
    @SerializedName("location") var location: String? = null,
    @SerializedName("attendees") var attendees: List<Attendee>? = null,
    @SerializedName("reminders") var reminders: List<Reminder>? = null,
    @SerializedName("recurrenceRule") var recurrenceRule: String? = null,
    @SerializedName("availability") var availability: Int? = null,
    @SerializedName("status") var status: Int? = null,
    @SerializedName("customAppUri") var customAppUri: String? = null,
    @SerializedName("eventIsDetached") var eventIsDetached: Boolean? = null
) {
    companion object {
        @JvmStatic
        fun fromJson(json: Map<String, Any?>): Event {
            val event = Event()
            event.eventId = json["eventId"] as? String
            event.calendarId = json["calendarId"] as? String
            event.title = json["title"] as? String
            event.description = json["description"] as? String
            event.start = (json["start"] as? Double)?.let { Date(it.toLong()) }
            event.end = (json["end"] as? Double)?.let { Date(it.toLong()) }
            event.allDay = json["allDay"] as? Boolean
            event.location = json["location"] as? String
            event.attendees = (json["attendees"] as? List<Map<String, Any?>>)?.map { Attendee.fromJson(it) }
            event.reminders = (json["reminders"] as? List<Map<String, Any?>>)?.map { Reminder.fromJson(it) }
            event.availability = json["availability"] as? Int
            event.status = json["status"] as? Int
            event.customAppUri = json["customAppUri"] as? String
            event.eventIsDetached = json["eventIsDetached"] as? Boolean

            // Handle recurrence rule
            val recurrenceRuleJson = json["recurrenceRule"] as? Map<String, Any?>
            if (recurrenceRuleJson != null) {
                // Check if it's in Android format (has recurrenceFrequency)
                if (recurrenceRuleJson.containsKey("recurrenceFrequency")) {
                    // Convert Android format to RFC format
                    event.recurrenceRule = RecurrenceRuleConverter.toRfc(recurrenceRuleJson)
                } else if (recurrenceRuleJson["freq"] != null) {
                    // Already in RFC format
                    event.recurrenceRule = recurrenceRuleJson["freq"] as? String
                }
            }

            return event
        }
    }

    fun toJson(): Map<String, Any?> {
        val json = mutableMapOf<String, Any?>()
        json["eventId"] = eventId
        json["calendarId"] = calendarId
        json["title"] = title
        json["description"] = description
        json["start"] = start?.time
        json["end"] = end?.time
        json["allDay"] = allDay
        json["location"] = location
        json["attendees"] = attendees?.map { it.toJson() }
        json["reminders"] = reminders?.map { it.toJson() }
        json["recurrenceRule"] = recurrenceRule
        json["availability"] = availability
        json["status"] = status
        json["customAppUri"] = customAppUri
        json["eventIsDetached"] = eventIsDetached
        return json
    }
}