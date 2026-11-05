# Architecture (planned)

Nothing here is built yet. This describes the intended shape so the phases in the [roadmap](ROADMAP.md) fit together.

## Repository layout

```
daytracker/
├── project.yml                  # XcodeGen spec → DayTracker.xcodeproj (generated on CI)
├── App/                         # iOS app target (SwiftUI)
│   ├── DayTrackerApp.swift
│   ├── Features/                # Today, QuickLog, CheckIn, History, Settings, Export
│   ├── Persistence/             # SwiftData models + container
│   └── Notifications/           # scheduling, categories, action handling
├── Packages/DayTrackerCore/     # pure Swift logic + tests (D10)
├── .github/workflows/ios.yml    # build, test, unsigned IPA (D02)
├── analysis/                    # Python: loaders, notebooks (D09)
│   ├── requirements.txt
│   └── data/                    # exports — gitignored
└── docs/
```

## Data model (D07)

### Tracker — *what can be logged*
| field | type | notes |
|---|---|---|
| id | UUID | stable; used in exports |
| name | String | "Water", "Coffee", "Medicine A", "Mood" |
| kind | enum | `counter` (tap +1), `dose` (taken/skipped, D11), `scale` (1–10, D12), `number` (free value), `note` |
| unit | String? | "glass", "cup", "mg", "ml" |
| defaultAmount | Double | how much one tap adds (1 cup, 250 ml) |
| scaleMin / scaleMax | Int? | for `scale`; default 1 / 10 |
| reminderTimes | [hour:minute]? | for `dose`; empty = as-needed only (D11) |
| icon, color | String | SF Symbol name, color token |
| sortOrder, archived | Int, Bool | archive instead of delete so history stays intact |

### Entry (`LogEntry` in code) — *something that happened*
| field | type | notes |
|---|---|---|
| id | UUID | |
| tracker | → Tracker | |
| value | Double | count, amount, scale value; dose: 1 = taken, 0 = skipped |
| occurredAt | Date (UTC) | when it happened (editable, for backfilling) |
| loggedAt | Date (UTC) | when it was recorded |
| timeZone | String | IANA id at logging time, so "time of day" analysis is correct when travelling |
| source | enum | `manual`, `notificationAction`, `checkIn`, later `widget`, `shortcut` |
| sessionID | UUID? | `CheckInSession.id` if answered as part of a check-in (D16) |
| scheduledFor | Date? | for `dose`: the reminder slot this answers; nil = as-needed |
| note | String? | |

### CheckInSchedule — *when to ask what*
| field | type | notes |
|---|---|---|
| id, name | | defaults: "Morning" 09:00, "Afternoon" 14:00, "Evening" 21:00 (D13) |
| hour, minute | Int | local time |
| weekdays | Set<Int> | |
| trackers | [Tracker] | the questions in this check-in, in order |
| enabled | Bool | |

### CheckInSession — *one occurrence of a check-in*
`scheduledFor`, `openedAt?`, `completedAt?`, `status` (`answered` / `partial` / `skipped` / `missed`).
This lets analysis measure response rate and latency, and separate "no coffee" from "didn't answer".

## Notifications (D08)

- On launch and whenever schedules change, the app rebuilds all pending requests. There's one repeating calendar trigger per check-in schedule and per medicine reminder time. Keep the total under iOS's 64-pending limit: use one trigger per time when every day is selected, and per weekday only when needed.
- Categories:
  - `DOSE`: **Taken** / **Skip** / **Snooze 15 min**. Handled in the background and written straight to SwiftData with `scheduledFor` set.
  - `CHECKIN`: tapping opens the check-in sheet with that schedule's questions (1–10 grids, D12).
- When a check-in's 3 h answer window passes without an answer, a `missed` session is created the next time the app opens (D16).
- Notification permission is requested from a banner on the Today screen, not at first launch.
- Code: `App/Notifications/` (scheduler, payload, handler); scheduling math in `DayTrackerCore` (`RecurringTime`, `NotificationPlanner`, `CheckInPolicy`).

## Export format (D09, D17)

Settings → Data → Export all data → share sheet with `DayTracker-<yyyy-MM-dd-HHmm>.zip` containing:

- `entries.csv` (long/tidy, one row per entry, oldest first):
  `entry_id, tracker_id, tracker_name, kind, value, unit, occurred_at, logged_at, time_zone, day, source, session_id, scheduled_for, note`
  Timestamps are ISO 8601 in the entry's own time zone with offset (`2026-11-02T09:00:00+01:00`). `day` is `yyyy-MM-dd` using the 04:00 boundary (D14).
- `trackers.csv`: `tracker_id, name, kind, unit, unit_plural, scale_min, scale_max, icon, color, sort_order, archived, reminder_times` (`08:00;20:00`)
- `checkins.csv`: `session_id, schedule_id, schedule_name, scheduled_for, day, status, question_count, answered_count, opened_at, completed_at`
- `backup.json`: full-fidelity `Backup` (version 1), used by Import.
- `README.txt`

The exact format is pinned by `Packages/DayTrackerCore/Tests/DayTrackerCoreTests/Fixtures/*.csv`. The Swift exporter must reproduce those files byte for byte, and `analysis/tests` loads the same files. Change both sides together.

Code: `DayTrackerCore` (`Backup`, `Exporter`, `StoredZip`); app `App/Data/` (model ↔ record mapping, import merge); `analysis/daytracker.py`.

## Screens

1. **Today**: check-ins due, quick logging per kind (counter cards, medicine cards with reminder slots, 1–10 ratings, numbers and notes), notification permission banner.
2. **Check-in sheet**: steps through a check-in's questions. Ratings are a grid of buttons, not sliders, so answers are fast and unambiguous.
3. **History**: entries by day; edit, delete, backfill.
4. **Trends**: 7/30-day chart per tracker (D18).
5. **Settings**: reminders, check-ins, medicines, trackers, data export/import, troubleshooting.
