# Internal dependency audit — November 4, 2026

This maintenance candidate starts from TimeFinder's exact production pin `ec9153d439a9a614ac0b64605e34fce202da639c`, including accepted Reminder intent, field and identity ownership, native lifetime checks, Calendar provider repair/diagnostics, recurrence normalization and EventKit long-range queries.

## Selected dependencies

| Area | Selection |
|---|---|
| Dart | timezone 0.11.2 and rrule 0.2.18 minimums; collection 1.19.1, plugin_platform_interface 2.1.8 and flutter_lints 6.0.0 already current |
| Android serialization | Gson 2.15.0 |
| Android recurrence | lib-recur 0.17.1 |
| Android concurrency | coroutines 1.11.0 |
| Android Kotlin | Kotlin and stdlib 2.4.21 |
| AndroidX | Core 1.19.1 and annotation 1.11.0 |
| Native tests | JUnit BOM 6.1.3; unused Mockito and AndroidX test dependencies removed |
| Build tools | AGP 9.5.0, Gradle 9.8.2 with distribution checksum, Java bytecode target 17 |
| Example | intl 0.20.3, uuid 4.6.0, flutter_timezone 5.1.1, cupertino_icons 2.0.0 and flutter_lints 6.0.0 |

The Android module uses API 24 minimum and compile SDK 37. Flutter 3.38, required by timezone's effective Dart 3.10 minimum, already uses Android API 24; TimeFinder's own app minimum is API 31. Core 1.19.1 requires API 23 and compile SDK 37 and fits those supported clients. AppCompat has no source callers in this plugin; Core directly supplies its ActivityCompat API. The unused AppCompat API dependency and both legacy Support Library declarations are removed. Standalone and example builds disable Jetifier. The empty standalone `:app` module duplicated obsolete dependencies and has no source files; the plugin root owns all native tests.

The standalone project supplies Flutter embedding classes through `compileOnly` solely when it is the root project. A consuming Flutter app supplies its own embedding. The default unit-test task discovers every test class. Flutter and timezone impose an effective Dart minimum of 3.10 while the package retains its established 2.12 language mode; cupertino_icons imposes an effective Dart 3.12 minimum for the example, which also retains its established 2.12 language mode. FVM pins qualification to Flutter 3.47.9 / Dart 3.13.7. Kotlin compatibility flags match the consuming TimeFinder app's AGP 9 configuration.

Apple SPM manifests contain no external package dependencies. All plugin Dart runtime and Apple/Android runtime source files are byte-identical to the baseline. Only the example's removed TextTheme getter and flutter_timezone result shape require Dart API adaptation.

## Qualification

- Baseline: 77 Dart tests and nine native tests pass. The standalone baseline needs a scoped compileOnly embedding injection to compile the plugin's main source; that repair is now explicit in its own Gradle configuration.
- Candidate: 77 Dart tests and 14 native tests pass. Added native controls exercise actual event JSON adapters, custom identity/URL/weekday wire fields, weekly/monthly/leap-year recurrence expansion and owned coroutine cancellation. The same 14 tests pass with baseline dependencies using the scoped baseline harness.
- Candidate Android release AAR and example debug APK compile successfully.
- OSV query of 84 unique selected Maven and hosted Pub package/version pairs reports zero advisories. The captured Android graph includes 33 runtime and 42 test components; Flutter SDK artifacts are outside OSV's version mapping.
- Plugin analysis retains ten baseline information findings. Example analysis has zero errors and 18 existing style/deprecation findings, compared with 21 under its original lint rules; the upgraded rules introduce no findings when its established language mode is preserved. Unrelated automatic Dart fixes and formatting changes are excluded from this maintenance candidate.

Raw metadata, package contracts, release notes, dependency graphs, baseline/candidate logs and the consuming app's subsequent qualification are retained at `/Users/lukememet/Documents/TimeFinder/Repository Retention/2026-11-04/device-calendar-dependencies/`.

Primary references: [Gson 2.15.0](https://github.com/google/gson/releases/tag/gson-parent-2.15.0), [lib-recur releases](https://github.com/dmfs/lib-recur/releases), [coroutines 1.11.0](https://github.com/Kotlin/kotlinx.coroutines/releases/tag/1.11.0), [AndroidX Core](https://developer.android.com/jetpack/androidx/releases/core), [Flutter 3.38 Android defaults](https://github.com/flutter/flutter/blob/3.38.0/packages/flutter_tools/lib/src/android/gradle_utils.dart), [JUnit 6.1.3](https://docs.junit.org/6.1.3/release-notes.html), and [Pub package metadata](https://pub.dev/api/packages/timezone).
