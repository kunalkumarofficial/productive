# Productive

A fast, native macOS productivity app. **Everything is stored locally on your
Mac — no account, no sync, no online database.** The app runs in Apple's App
Sandbox *without the network entitlement*, so it is technically incapable of
sending your data anywhere.

## Features

- **Tasks** — projects with colors, priorities, due dates, flags, and notes.
  Smart views: Today (with overdue), Upcoming (grouped by day), All Tasks,
  Flagged, and a Logbook of completed work.
- **Quick add with natural syntax** — type
  `Ship report @tomorrow !high #Work` and Productive parses the due date,
  priority, and project. Supports `@today`, `@tomorrow`, `@friday` (any
  weekday), `@week`, `!high/!med/!low`, and `#ProjectName`.
- **Focus timer** — Pomodoro-style work/break cycles with configurable
  durations, long breaks, optional auto-start, sound and notifications.
  Completed sessions are logged automatically.
- **Menu bar companion** — the timer countdown lives in your menu bar, with
  quick-add and timer controls one click away, even when the main window is
  closed.
- **Habits** — daily habits with a 7-day toggle strip and streak tracking.
- **Notes** — a lightweight local notepad with search.
- **Dashboard** — daily goals, tasks completed and focus minutes charted over
  the last 14 days, and habit streaks at a glance.
- **Robust local persistence** — a single human-readable JSON file with atomic
  writes, automatic timestamped backups (last 20 kept), quarantine of
  unreadable files instead of data loss, and manual export/import from
  Settings.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | New task (focuses quick add) |
| ⌘1 – ⌘8 | Today / Upcoming / All / Flagged / Dashboard / Focus / Habits / Notes |
| ⇧⌘P | Start / pause the focus timer |
| ⇧⌘K | Skip the current timer phase |
| ⇧⌘0 | Reset the timer |
| ⌘, | Settings |

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later to build

## Building

```sh
git clone https://github.com/kunalkumarofficial/productive.git
open productive/Productive.xcodeproj
```

Press **⌘R** in Xcode. The project is configured to "Sign to Run Locally" out
of the box; select your own team in *Signing & Capabilities* if you prefer.

CI builds the app on every push via GitHub Actions (`.github/workflows/build.yml`).

## Where your data lives

Inside the app's sandbox container:
`~/Library/Containers/com.kunalkumar.Productive/Data/Library/Application Support/Productive/`

- `productive-data.json` — all tasks, projects, habits, notes, and focus sessions
- `Backups/` — automatic timestamped backups

Use **Settings → Data** to reveal this folder, export a backup anywhere, or
import one.
