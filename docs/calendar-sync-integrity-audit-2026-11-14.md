# Calendar sync integrity audit — 2026-11-14

This candidate starts at TimeFinder's exact plugin pin `58a0666f8a98c5388a7debe3eeb1c3cd4d23511d` on `codex/rafael-calendar-sync-audit`.
The parent app investigation is `/Users/lukememet/Developer/timefinder-rafael-calendar-sync/docs/investigations/2026-11-14-rafael-calendar-sync.md`.
No comparison agent's implementation was reviewed.

## Ownership and intended behavior

The app's Calendar ownership architecture, feature specification, recurrence skill, testing policy, and 2026-11-04 plugin dependency qualification were read before interpreting defects.
The app owns imported Appointment persistence, local edits/deletion decisions, account lifecycle, source matching, and export bookkeeping.
This plugin owns faithful native Calendar reads/writes, native event and occurrence identity, recurrence/date serialization, and provider failure signaling.
An authoritative complete empty snapshot may mean events were removed; a failed or incomplete snapshot must not carry that meaning.
The app's import planner uses source-event absence to remove unedited imports, so this distinction crosses the native/Dart boundary and is a data-integrity requirement.
An imported event's lock is an app editing rule, not a request for this plugin to remove its native event.

## Candidate changes

| Boundary | Defect established from source and regression | Current candidate behavior |
| --- | --- | --- |
| Dart event snapshot | Lazy decoding reports a list before malformed entries are evaluated; missing identity/bounds and recurrence parse failure are not reliable call failures | Materializes and validates the complete event list inside the guarded call; invalid/foreign events fail the complete result; genuine `[]` succeeds |
| Android native snapshot | A null Instances cursor is returned as successful `[]`; null or incomplete RRULE metadata changes recurrence semantics | Rejects unknown/incomplete provider snapshots and malformed/unsupported recurrence instead of publishing absence or single events |
| Apple native snapshot | A missing selected Calendar yields successful `[]`; native events without an identifier are silently skipped | Returns an explicit Calendar-not-found/identity-unavailable error before returning a partial result; ID-only retrieval stays scoped to the selected Calendar |
| Android metadata cost | Attendee and alarm metadata is fetched once for every repeated occurrence | Fetches once per event identity per retrieval, retaining every occurrence/date and its metadata |
| Android export write | Recurring writes supply DTEND with null DURATION; removing recurrence leaves the provider RRULE in place | Uses RFC duration for recurring rows; changing to a single event explicitly clears recurrence and exception-date fields |
| Android export acknowledgement | An update that changes zero provider rows reports success, bypassing the app's missing-event recovery; an invalid update ID becomes a new insertion | Reports not found before attendee/alarm mutation; rejects invalid supplied update IDs |
| Android recurrence wire | Scalar compact fields lose multiple month days, independent ordinal weekdays, and precise UNTIL time | Includes the unchanged provider RFC rule and parses it directly in Dart, preserving selectors, cutoff instant and returned occurrence start |

The native Android compact recurrence fields remain available for compatibility.
The new raw rule is additive; valid legacy replies continue through the existing converter.
Apple's existing recurrence and Reminder wire contracts are preserved.

## Verification

- On the exact pinned source, six snapshot-integrity regressions fail while valid empty and repeated-instance controls pass.
- Six real `CalendarDelegate` → `ContentResolver` recording-provider regressions fail on the pin while the genuine empty snapshot control passes.
- The additional raw-RRULE provider and Dart channel regressions fail before the additive wire repair.
- Final candidate: all 88 plugin Dart tests and all 27 native Android tests pass; the Android release AAR compiles.
- Native tests exercise the actual delegate and writer, record provider ContentValues and call results, and verify all 180 occurrence dates and attendee/alarm contents while proving metadata queries fall from 180 each to one each.
- The exact shared Swift sources compile for macOS and iOS Simulator through XcodeBuildMCP using native static-library harnesses and Flutter 3.47.9 frameworks.
- Focused Dart analysis has no errors or warnings and retains one existing Color.value deprecation information finding.
- SwiftLint reports 46 findings versus 47 on the pin, with no introduced findings.

The Android recording provider is an isolated contract oracle, not the OS Calendar Provider database.
The Apple builds establish both conditional-compilation paths, not EventKit permission/account/runtime acceptance.
The plugin example's existing Flutter SPM identity/migration failure is recorded as harness evidence; the successful native compile harness directly consumes the canonical source files instead.

Canonical local logs, baseline failures, native harnesses, XML reports, artifact hashes, and candidate bundle are under `/Users/lukememet/Documents/TimeFinder/Repository Retention/2026-11-14/rafael-calendar-sync/plugin/`.

## Open audit findings and acceptance gates

1. **COUNT and series anchor:** native events expose occurrence start, not a separate original master DTSTART. Reapplying a finite source COUNT from the earliest retrieved occurrence can extend a partially visible series in the app. The plugin must expose authoritative master identity/anchor metadata before an app repair changes that contract; the parent owns a regression that starts retrieval partway through a counted series.
2. **Android delegate lifetime:** Activity attachment/configuration reattachment replaces CalendarDelegate without an explicit owner stopping the prior observer or closing its single-thread dispatcher; engine detach only removes the channel handler. A lifecycle test must prove old callbacks, pending permission results and worker ownership before changing cancellation semantics. This candidate leaves that source-proven ownership gap visible.
3. **Apple long-range retrieval:** four-year query chunks end one second before the next chunk starts and append overlapping multi-day events without explicit occurrence deduplication. A native boundary/spanning-event regression is required; normal 180-day import windows do not take this chunk boundary.
4. **Cross-device identity:** native event IDs remain provider/device identifiers. The app must distinguish native identity changes, selected Calendar remapping and real source deletion. Plugin API identity alone does not establish cross-device ownership.
5. **All-day boundary:** Android Event.fromJson emits inclusive final-day midnight, while Apple retains the native exclusive end. The app mapper's `spanDays > 1` assumption must be audited against two-day Android events; changing plugin dates silently would break the existing API contract.
6. **Unsupported Android recurrence:** frequencies outside the existing DAILY/WEEKLY/MONTHLY/YEARLY native model now return an explicit failed snapshot. This preserves stored imports; supporting additional frequencies requires a source-preserving representation and app recurrence acceptance.
7. **Runtime acceptance:** exercise the app with this exact candidate against real EventKit and Android Calendar Provider fixtures, including source recurrence changes, genuine empty calendars, transient provider failures, and missing export updates. The app's focused integration, persistence acknowledgement and production incident attribution remain owned by the parent investigation.

## Primary contracts

- [Android Calendar Provider](https://developer.android.com/identity/providers/calendar-provider): recurring provider writes require DURATION with RRULE/RDATE.
- [Android Events API](https://developer.android.com/reference/android/provider/CalendarContract.Events): event insert/update fields and provider identity.
- [Android Instances API](https://developer.android.com/reference/android/provider/CalendarContract.Instances): expanded instance retrieval and range cost.
- [Robolectric setup](https://robolectric.org/getting-started/): direct Android API regression harness.
