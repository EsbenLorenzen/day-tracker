# Roadmap

Each phase ends with something usable on the iPhone. See [DECISIONS.md](DECISIONS.md) for the why and [ARCHITECTURE.md](ARCHITECTURE.md) for the how.

## Phase 0: Prove the toolchain (no features)
The biggest risk is building and installing an iOS app with no Mac. Retire it first.

- [x] Create public repo `EsbenLorenzen/day-tracker` and push
- [x] Minimal `project.yml` (XcodeGen) + "Hello" SwiftUI app
- [x] GitHub Actions workflow `.github/workflows/ios.yml`: `xcodegen generate` → build → unsigned `.ipa` artifact
- [x] First green CI run (2026-11-02)

*Sideloading and the on-device checks below are deferred. They'll be done alongside a later phase; CI keeps verifying that the code compiles.*
- [ ] Install Sideloadly on Windows (+ iTunes/iCloud from apple.com, not the Microsoft Store versions). See [SIDELOADING.md](SIDELOADING.md)
- [ ] Sideload the IPA with a free Apple ID; trust the developer profile on the iPhone; enable Developer Mode
- [x] Button that schedules a local notification 10 s later *(written)*
- [ ] Notification verified on the phone

**Done when:** the app icon is on the phone and a test notification arrives.

## Phase 1: Manual logging (MVP)
- [x] SwiftData models: `Tracker`, `LogEntry` (seeded with Water, Coffee, one example medicine, Mood, Energy, Focus)
- [x] Today screen with one-tap logging and daily totals; medicine "Taken" button for as-needed use; undo last
- [x] Mood, Energy and Focus on a 1–10 scale (2×5 button grid)
- [x] History list grouped by day (04:00 boundary, D14); edit, delete, backfill a time
- [x] CI: `DayTrackerCore` tests on Linux (day boundary incl. DST, aggregation, formatting, default trackers)
- [x] Decide D10 → core package accepted; no Swift-on-Windows for now
- [x] Green CI run for Phase 1 (2026-11-02)
- [x] Try it on the phone (with the deferred Phase 0 sideload), 2026-11-03: everything works

**Done when:** you can log your whole day by hand for a week.

## Phase 2: Scheduled check-ins
- [x] `CheckInSchedule` + `CheckInSession` models; defaults 09:00 / 14:00 / 21:00 asking Mood, Energy, Focus
- [x] Settings UI to change times, weekdays and questions, and add/remove check-ins
- [x] Local notification scheduling (repeating calendar triggers; rebuilt on launch, return and every settings change)
- [x] Check-in sheet opened from a notification tap, or from the Today screen's check-in list
- [x] Medicine reminder times per medicine; notifications with **Taken / Skip / Snooze** actions (no app open needed)
- [x] Missed / partial session tracking (D16)
- [x] Permission asked from a Today banner, not at first launch
- [x] Green CI run for Phase 2 (2026-11-03)
- [ ] On the phone: allow reminders; a check-in notification opens the questions; Taken/Skip from the lock screen; Snooze returns after 15 min
- [x] **Bug:** tapping a notification opened the app briefly, then it crashed (2026-11-03). The delegate ran off the main thread, so UIKit aborted when opening the app; it now runs on the main actor

**Done when:** the phone asks you 2–3 times a day and answering takes under 10 seconds.

## Phase 2.5: Several medicines
Requested 2026-11-03. Pulled forward from Phase 4's general tracker editing because it's needed for real daily use.
- [x] Settings → Medicines: add a medicine (name, icon, colour), rename, reorder, archive/restore (history kept); delete only when it has no history
- [x] Each medicine has its own reminder times, notifications and Today card (the model already supports this, D11)
- [x] Replace the seeded placeholder "Medicine" by renaming it on its page, without losing its history
- [x] Entries reference medicines by tracker ID, so renaming doesn't split the data (export in Phase 3 uses `tracker_id`)
- [ ] Green CI run for Phase 2.5
- [ ] On the phone: add a second medicine with a reminder; both cards on Today; rename "Medicine"; notification-tap crash fix confirmed

**Done when:** each of your medicines has its own card, reminders and adherence.

## Phase 3: Export & analysis
- [ ] Export zip (CSV + JSON backup) via the share sheet
- [ ] Import from JSON backup (protects against data loss when sideloading or reinstalling)
- [ ] `analysis/`: loader module + starter notebook
- [ ] First questions: caffeine timing vs. evening energy; mood by time of day and weekday; medication adherence; water vs. energy

**Done when:** a week of real data turns into charts on the PC.

## Phase 4: Daily-driver polish
- [ ] Add, edit and archive other trackers in the app (no code changes needed): new 1–10 states like stress, new counters (medicines come earlier, Phase 2.5)
- [ ] Simple in-app charts (Swift Charts): 7- and 30-day trends
- [ ] App icon, haptics, dark mode check, accessibility (Dynamic Type)
- [ ] **Decision point:** join the Apple Developer Program → signed CI builds → TestFlight (ends the 7-day expiry)

## Phase 5: Native extras (paid account)
- [ ] Interactive home/lock-screen widget (log water/coffee without opening the app)
- [ ] App Intents: Siri / Shortcuts / Action Button ("log a coffee")
- [ ] Apple Health: write water and caffeine; read/write State of Mind for mood; check what the medications API allows
- [ ] Automatic backup to iCloud Drive, or CloudKit sync

## Later / maybe
- Correlations in the app ("energy is 0.8 lower on days with coffee after 15:00")
- Context tags (sleep quality, exercise, alcohol) and free-text journal
- Apple Watch quick-log complication

---

## Open questions
None right now.

Resolved: iOS 27 phone → D05 · public repo → D02 · medication → D11 · 1–10 scales + Focus → D12 · check-in times → D13 · glasses/cups → D15

## Risks
| Risk | Mitigation |
|---|---|
| Slow loop without a simulator or previews | Keep UI changes small; get CI screenshots from the simulator; put logic in a testable core package |
| Free-account sideload expires every 7 days | Re-sign weekly with Sideloadly or AltStore auto-refresh; JSON backup/import; pay once it hurts |
| Data loss when re-sideloading or reinstalling | Same bundle ID keeps data on re-sign; export/import backup lands in Phase 3, before relying on it |
| Personal data accidentally committed to the public repo | `.gitignore` covers exports; the app never writes into the repo; check `git status` before commits |
| GitHub runner lags behind on Xcode/iOS SDK | Deployment target 26 (D05) builds on older Xcode and runs on iOS 27 |
| iOS throttles or drops notifications | Repeating calendar triggers; reschedule on every app launch |
