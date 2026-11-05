# Decisions

A lightweight decision log. Each entry records what we chose, why, and what would make us revisit it.
Status: **Accepted**, **Proposed** (default unless challenged), or **Superseded by Dnn**.

---

## D01 — Native Swift + SwiftUI
**Status:** Accepted (2026-10-31)

**Context:** The app is personal, iPhone-only, and leans on OS features: scheduled local notifications with action buttons, and later widgets, Shortcuts/Siri and Apple Health.

**Decision:** Write the app in Swift with SwiftUI. No cross-platform framework.

**Alternatives:** Expo/React Native (faster feedback through Expo Go, but widgets, HealthKit and notification actions need native modules); PWA (iOS scheduled notifications too unreliable).

**Consequences:** No Mac means no Xcode, simulator or SwiftUI previews on the dev machine. Every build happens in the cloud (D02). The feedback loop is slow, so UI work should be small and incremental.

---

## D02 — Build on cloud macOS (GitHub Actions)
**Status:** Accepted

**Decision:** Every push builds the app on a GitHub Actions `macos-*` runner with `xcodebuild`. The workflow:
1. Builds and runs unit tests on the iOS Simulator.
2. Produces an **unsigned `.ipa`** as a build artifact (`CODE_SIGNING_ALLOWED=NO`, packaged into `Payload/`).
3. (Optional) Takes simulator screenshots of key screens and uploads them, as a stand-in for previews.

**Repo:** `github.com/EsbenLorenzen/day-tracker`, **public**, so Actions minutes are free. This only works because the repo never holds personal data (D09). That rule is enforced by `.gitignore` and must stay that way.

**Fallback:** Codemagic, which has a free tier of about 500 macOS minutes/month.

---

## D03 — Generate the Xcode project with XcodeGen
**Status:** Accepted

**Context:** `.xcodeproj/project.pbxproj` is a machine-written file that can't realistically be edited by hand without Xcode.

**Decision:** Keep a human-readable `project.yml` (XcodeGen) in the repo. CI runs `xcodegen generate` before building. The `.xcodeproj` is never committed.

**Alternative:** Tuist (more powerful, heavier). Revisit if the targets grow complex.

---

## D04 — Distribution: free Apple ID sideloading now, paid program later
**Status:** Accepted

**Decision:**
- **Now:** Sideload the CI-built unsigned IPA from Windows with **Sideloadly** (or AltStore/SideStore) using a free Apple ID.
- **Later:** Join the Apple Developer Program ($99/yr) and switch CI to signed builds uploaded to **TestFlight** with an App Store Connect API key.

**Free-account limits to live with:** the app expires after 7 days and must be re-signed; at most 3 sideloaded apps; App ID creation is rate-limited. Some entitlements aren't available, and app extensions such as widgets may be fragile under re-signing.

**Revisit (pay) when any of these is true:** the 7-day re-sign is annoying in daily use, *or* we start Phase 5 (widgets, HealthKit, iCloud), *or* re-signing breaks a needed capability.

---

## D05 — Minimum iOS version: 26
**Status:** Accepted (the target iPhone runs iOS 27.0)

**Why:** It's a personal app on one phone, so there's no reason to support old versions. iOS 26 gives us mature SwiftData, interactive widgets, App Intents, Swift Charts and HealthKit's medications API. We don't start at 27 because building for it needs Xcode 27 on the GitHub runner, which may arrive later than the phone update.

**Revisit:** Raise to 27 once the runner image ships Xcode 27 *and* we need a 27-only API.

---

## D06 — Local-only storage with SwiftData; no backend
**Status:** Accepted

**Decision:** All data lives on the device in SwiftData (SQLite underneath). No server and no account. Backup and analysis go through export (D09). iCloud sync can come later (Phase 5).

**Why:** Medication and mood data is sensitive. A backend adds cost, ops work and privacy risk for zero benefit to a single user.

---

## D07 — Generic tracker model (definitions + entries)
**Status:** Accepted

**Decision:** We don't hardcode `Water`, `Coffee` and so on as separate models. Instead:
- `Tracker` defines *what* can be logged (name, kind, unit, scale).
- `Entry` is an append-mostly log row (tracker, value, time, source).

Adding a new thing to track (e.g. "alcohol", "steps outside", "headache") is then a settings change, not a schema migration. It also gives analysis one tidy table. Details are in [ARCHITECTURE.md](ARCHITECTURE.md).

---

## D08 — Local notifications only
**Status:** Accepted

**Decision:** Schedule check-in reminders with `UNUserNotificationCenter` and repeating `UNCalendarNotificationTrigger`s. No remote push (that needs a server and a paid account). Notification categories carry quick actions ("Took it", "Skip", "Snooze 15 min") so common answers don't require opening the app.

---

## D09 — Analysis happens off-device in Python via export
**Status:** Accepted

**Decision:** The app exports CSV (tidy/long format) plus a full JSON backup through the share sheet, to Files or iCloud Drive. Analysis runs on the PC in `analysis/` using the repo's Python venv (pandas, matplotlib, Jupyter). Exported files go in `analysis/data/`, which is gitignored and never committed.

Simple charts in the app (Swift Charts) come later. Serious analysis stays in Python.

---

## D10 — Pure-Swift core package
**Status:** Accepted (2026-11-02)

**Decision:** Domain logic that doesn't depend on SwiftUI or SwiftData lives in the local package `Packages/DayTrackerCore`: day boundaries, aggregation, value formatting and default trackers, later schedules and export. The app depends on it through `project.yml`. Its tests (Swift Testing) run in a `swift` container on an Ubuntu runner, which is fast and needs no Mac.

**Not now:** Installing the Swift toolchain on Windows for local test runs. It's a heavy install (needs Visual Studio build tools), and CI covers it. Revisit if the feedback loop gets painful.

---

## D11 — Medication: taken/skipped only, scheduled and as-needed
**Status:** Accepted (2026-10-31)

**Decision:**
- No dosage tracking. Each medicine is its own tracker (e.g. "Medicine A"), and an entry means *taken* (`value = 1`) or *skipped* (`value = 0`).
- A medicine can have **reminder times** (scheduled), **none** (as-needed), or both: scheduled doses plus extra as-needed intake.
- A scheduled dose entry records which slot it answers (`scheduledFor`), so adherence can be calculated. As-needed entries have `scheduledFor = nil`.
- Medicine reminders are separate from mood check-ins and carry **Taken / Skip / Snooze 15 min** actions.

---

## D12 — State ratings on a 1–10 scale; extensible list
**Status:** Accepted (2026-10-31)

**Decision:** Mood, Energy and **Focus** are rated 1–10. They're just `scale` trackers (D07), so more states (stress, anxiety, pain…) can be added later without code changes.

**Consequences:** Ten choices don't fit as notification buttons, so a check-in notification opens the in-app sheet. There the answer is a 2×5 grid of number buttons, one tap per question. That's faster and more precise than a slider.

---

## D13 — Check-in times: defaults 09:00 / 14:00 / 21:00, user-adjustable
**Status:** Accepted (2026-10-31)

**Decision:** First launch creates three check-in schedules (Morning 09:00, Afternoon 14:00, Evening 21:00, every day), each asking Mood, Energy and Focus. Times, weekdays, questions and on/off can all be changed in Settings, and schedules can be added or removed.

---

## D14 — A "day" runs from 04:00 to 04:00
**Status:** Accepted (2026-11-02)

**Decision:** For grouping (Today screen, History, daily totals), a day starts at **04:00 local time**, not midnight. A coffee at 01:30 or a mood rating before bed at 00:45 counts towards the evening before, which matches how the day was actually lived.

**Notes:** Entries always store the exact `occurredAt` timestamp, so analysis can regroup with any boundary. On DST-change nights a day is 23 or 25 hours long, and `DayBoundary` handles that (tested). The start hour could become a setting later.

---

## D15 — Phase 1 scope details
**Status:** Accepted (2026-11-02)

- Fluid intake counts **glasses** (water) and **cups** (coffee), one per tap.
- Seeded trackers: Water, Coffee, one example "Medicine", Mood, Energy, Focus. Renaming and adding trackers come in Phase 4.
- The stored model class is `LogEntry` (not `Entry`) to avoid confusion with SwiftUI's `@Entry` macro.
- No `VersionedSchema` yet. SwiftData migrates additive changes (new optional fields) automatically. Introduce versioning before the first non-additive change.

---

## D16 — How check-ins and reminders behave
**Status:** Accepted (2026-11-03)

- **One session per occurrence.** A `CheckInSession` is identified by *schedule ID + scheduled time*. Repeating notifications don't carry a date, so the occurrence is worked out as "the latest scheduled time at or before delivery". Answers link to the session through `LogEntry.sessionID`, a plain UUID rather than a SwiftData relationship, which keeps exports simple.
- **Answer window: 3 hours.** A check-in is *due* from its time until 3 h later. After that, an unanswered one becomes *missed*. That's filled in when the app opens, going back up to 14 days but never before the schedule was created or last edited. Missed check-ins can still be answered late. Statuses: pending, answered, partial, skipped (explicit "Skip check-in"), missed.
- **Medicine slots.** Each reminder time is a daily slot. Taken/Skip from the notification records the entry with `scheduledFor = slot`; repeating the action updates the entry instead of duplicating it. **Taken** on the Today screen fills the latest unanswered past slot of the day, or counts as as-needed if there is none.
- **Snooze** (15 min) re-delivers a one-off copy pinned to the original slot, so the answer still counts for, say, 08:00.
- **Rebuild, don't patch.** All repeating requests are removed and re-added from the current settings on launch, on returning to the app, and after every settings change. Snoozes are kept. The total stays under iOS's 64-pending cap, with a little room left for snoozes.
- **Permission** is requested from a banner on Today (and a Settings row), not by a system prompt at first launch.
- Check-in notifications carry only *Snooze*. Ten mood buttons don't fit on a notification (D12), so tapping opens the check-in sheet.

---

## D17 — Export file, backup and import
**Status:** Accepted (2026-11-04)

- **One `.zip` per export**, shared through the iOS share sheet: three tidy CSVs for analysis, `backup.json`, and a README. It's written by our own minimal ZIP writer (stored, uncompressed, about 150 lines in `DayTrackerCore`) rather than a third-party library. The files are small, and Windows, Python's `zipfile` and iOS Files all open it.
- **Times keep their time zone.** CSV timestamps are ISO 8601 in the entry's own time zone with offset, so "hour of day" means what the clock showed then. A precomputed `day` column applies the 04:00 boundary (D14), so Python doesn't need to reimplement it.
- **One format contract, tested on both sides.** Fixture CSVs in the core test target must be reproduced exactly by the Swift exporter (Linux CI) and are loaded by the Python tests (Analysis CI).
- **`backup.json`** is a versioned (`version: 1`) Codable dump of all models. Dates are in ISO 8601 at second precision. Readers reject newer versions.
- **Import merges, it never replaces.** Entries and check-in records are added if their ID is missing. Existing trackers and schedules are kept as they are, so local edits win. To avoid duplicates on a fresh install, an unused default tracker (same name and kind, no entries) or default check-in (same name and time) takes over the backed-up item's ID. Import accepts the export `.zip` or `backup.json`; a re-compressed `.zip` gets a clear "unzip it first" message.
- **Analysis** lives in `analysis/daytracker.py`, with functions returning DataFrames (see below) (`daily`, `by_hour`, `by_weekday`, `last_coffee_vs_evening`, `adherence`, `checkin_summary`) plus `starter.ipynb`. Renamed trackers are grouped by `tracker_id` under their current name.

---

## D18 — Phase 4: own trackers, in-app trends, icon
**Status:** Accepted (2026-11-05)

- **Own trackers.** Settings → Trackers adds counters (unit, plural, amount per tap), 1–10 ratings (adjustable range), numbers (unit) and notes. A tracker's kind is fixed once it's created, because changing it would change what past values mean. As with medicines, trackers with history can only be archived; only unused ones can be deleted. New trackers can immediately be chosen as check-in questions.
- **Today** shows numbers and notes in a "More" section. Tapping one opens a small sheet for entering a value or writing a note. At accessibility text sizes the counter cards switch to one column.
- **Trends tab** (Swift Charts): 7 or 30 days. Counters, numbers and medicines are shown as daily bars, ratings as a line of daily averages, each with a one-line summary. The daily series comes from `Trends.daily` in `DayTrackerCore`, which uses the same 04:00 boundary and aggregation as the rest of the app and is tested on Linux. In-app charts stay simple on purpose; comparisons and correlations stay in Python (D09).
- **App icon** is generated by `tools/make_icon.py` (Pillow) into a single 1024 px asset; iOS derives all sizes. Regenerate after tweaking the script.

---

## D19 — Apple Developer Program: still free sideloading
**Status:** Open, waiting on the user's decision (raised 2026-11-05)

| | Free Apple ID (now) | Developer Program ($99/yr) |
|---|---|---|
| Install | Sideloadly from the PC, USB/Wi-Fi | TestFlight app on the phone, no PC needed |
| Expiry | **7 days**, then re-sign | TestFlight builds last 90 days; new builds arrive automatically |
| CI | Unsigned IPA | Signed build uploaded to TestFlight by GitHub Actions (App Store Connect API key as a repo secret) |
| Capabilities | Basic; widgets/extensions fragile | Widgets, App Groups, HealthKit, iCloud/CloudKit all reliable |
| Effort to switch | — | About an hour: enrol, create app ID and API key, add 3 secrets, switch the workflow to archive + upload |

**Recommendation:** stay free while the re-signing is tolerable. Switch before Phase 5, since widgets, HealthKit and iCloud backup all need capabilities that free sideloading handles badly. Data is kept when switching as long as the bundle ID stays `com.esbenlorenzen.daytracker`. Export a backup first anyway.
