package com.builttoroam.devicecalendar.common

internal object AndroidCalendarProviderProbeClassifier {
    fun classify(
        syncEvents: Boolean,
        accountSyncAutomatically: Boolean?,
        rawEventCount: Int,
        rawActiveEventCount: Int,
        rawExpansionCandidateCount: Int,
        instanceCountWithoutDeletedFilter: Int,
        invalidRecurrenceCount: Int,
    ): String = when {
        instanceCountWithoutDeletedFilter > 0 -> "plugin_deleted_filter_mismatch"
        !syncEvents -> "calendar_sync_disabled"
        accountSyncAutomatically == false -> "account_calendar_sync_disabled"
        rawEventCount == 0 -> "calendar_provider_not_materialized"
        rawActiveEventCount == 0 -> "no_active_provider_events"
        rawExpansionCandidateCount == 0 -> "no_provider_expansion_candidates"
        invalidRecurrenceCount >= rawExpansionCandidateCount -> "recurrence_rules_rejected"
        else -> "provider_instance_expansion_failed"
    }
}
