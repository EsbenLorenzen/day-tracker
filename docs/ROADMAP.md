# Roadmap

Each phase ends with something usable on the iPhone. See [DECISIONS.md](DECISIONS.md) for the why and [ARCHITECTURE.md](ARCHITECTURE.md) for the how.

## Phase 0: Prove the toolchain (no features)
The biggest risk is building and installing an iOS app with no Mac. Retire it first.

- [ ] Create public repo `EsbenLorenzen/day-tracker` on GitHub and push (the `origin` remote is already set locally)
- [ ] Minimal `project.yml` (XcodeGen) + "Hello" SwiftUI app
- [ ] GitHub Actions workflow: `xcodegen generate` → build → unsigned `.ipa` artifact
- [ ] Install Sideloadly on Windows (+ iTunes/iCloud from apple.com, not the Microsoft Store versions)
- [ ] Sideload the IPA with a free Apple ID; trust the developer profile on the iPhone; enable Developer Mode
- [ ] Add a button that schedules a local notification 10 s later, and check it fires on the phone

**Done when:** the app icon is on the phone and a test notification arrives.

## Phase 1: Manual logging (MVP)
- [ ] SwiftData models: `Tracker`, `Entry` (seeded with Water, Coffee, one example medicine, Mood, Energy, Focus)
- [ ] Today screen with one-tap logging and daily totals; medicine "Taken" button for as-needed use
- [ ] Mood, Energy and Focus on a 1–10 scale (2×5 button grid)
- [ ] History list grouped by day; edit, delete, backfill a time
- [ ] CI: unit tests for the model and day-boundary logic
- [ ] Decide D10 (core package / Swift on Windows)

**Done when:** you can log your whole day by hand for a week.

## Phase 2: Scheduled check-ins
- [ ] `CheckInSchedule` + `CheckInSession` models; defaults 09:00 / 14:00 / 21:00 asking Mood, Energy, Focus
- [ ] Settings UI to change times, weekdays and questions, and add/remove check-ins
- [ ] Local notification scheduling (repeating calendar triggers)
- [ ] Check-in sheet opened from a notification tap
- [ ] Medicine reminder times per medicine; notifications with **Taken / Skip / Snooze** actions (no app open needed)
- [ ] Missed / partial session tracking

**Done when:** the phone asks you 2–3 times a day and answering takes under 10 seconds.

## Phase 3: Export & analysis
- [ ] Export zip (CSV + JSON backup) via the share sheet
- [ ] Import from JSON backup (protects against data loss when sideloading or reinstalling)
- [ ] `analysis/`: loader module + starter notebook
- [ ] First questions: caffeine timing vs. evening energy; mood by time of day and weekday; medication adherence; water vs. energy

**Done when:** a week of real data turns into charts on the PC.

## Phase 4: Daily-driver polish
- [ ] Add, edit and archive trackers in the app (no code changes needed): new medicines, new 1–10 states like stress, new counters
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
1. Count water in glasses or ml? Coffee in cups or mg caffeine? (Default for now: glasses and cups, each tap = 1.)

Resolved on 2026-10-31: iOS 27 phone → D05 · public repo → D02 · medication → D11 · 1–10 scales + Focus → D12 · check-in times → D13

## Risks
| Risk | Mitigation |
|---|---|
| Slow loop without a simulator or previews | Keep UI changes small; get CI screenshots from the simulator; put logic in a testable core package |
| Free-account sideload expires every 7 days | Re-sign weekly with Sideloadly or AltStore auto-refresh; JSON backup/import; pay once it hurts |
| Data loss when re-sideloading or reinstalling | Same bundle ID keeps data on re-sign; export/import backup lands in Phase 3, before relying on it |
| Personal data accidentally committed to the public repo | `.gitignore` covers exports; the app never writes into the repo; check `git status` before commits |
| GitHub runner lags behind on Xcode/iOS SDK | Deployment target 26 (D05) builds on older Xcode and runs on iOS 27 |
| iOS throttles or drops notifications | Repeating calendar triggers; reschedule on every app launch |
