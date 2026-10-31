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
**Status:** Proposed

**Idea:** Keep domain logic that doesn't depend on SwiftUI or SwiftData in a local Swift package (`DayTrackerCore`): schedule calculations, export formatting, adherence and streak calculations. It can then be unit-tested on CI cheaply (Linux runner) and possibly on Windows with the Swift for Windows toolchain, without spending macOS minutes.

**Open:** Is installing Swift on Windows worth it for local tests? Decide in Phase 1.

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
