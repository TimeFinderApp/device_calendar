package com.builttoroam.devicecalendar.common

data class AndroidRecurringIdentity(
    val recurringSegmentId: String?,
    val recurringLineageId: String?,
    val isException: Boolean,
)

object AndroidRecurringIdentityNormalizer {
    fun normalize(
        eventId: String,
        hasRecurrence: Boolean,
        originalId: String?,
        originalSyncId: String?,
        syncId: String?,
        uid2445: String?,
        originalInstanceTime: Long?,
    ): AndroidRecurringIdentity {
        val isException = originalId != null || originalSyncId != null || originalInstanceTime != null
        if (!hasRecurrence && !isException) {
            return AndroidRecurringIdentity(
                recurringSegmentId = null,
                recurringLineageId = null,
                isException = false,
            )
        }

        return AndroidRecurringIdentity(
            recurringSegmentId = syncId ?: eventId,
            recurringLineageId = uid2445 ?: originalSyncId ?: syncId ?: originalId ?: eventId,
            isException = isException,
        )
    }
}
