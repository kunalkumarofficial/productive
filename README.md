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
- Xcode 16 or later — **only if you build it yourself**; see below for a
  no-Xcode option

## Running without Xcode

Every push builds a ready-to-run, universal (Apple Silicon + Intel) app on CI:

1. Open the repo's **Actions** tab, click the latest green **Build** run, and
   download the **Productive.app** artifact (requires being signed in to
   GitHub). Tagged releases (`v*`) also attach the zip under **Releases**,
   downloadable without signing in.
2. Unzip it and drag `Productive.app` into `/Applications`.
3. The app is ad-hoc signed, not notarized by Apple, so macOS will block the
   first launch of a downloaded copy. Clear the quarantine flag once:

   ```sh
   xattr -cr /Applications/Productive.app
   ```

   Then open it normally. (Alternatively: System Settings → Privacy &
   Security → "Open Anyway" after the first blocked attempt.)

## Building

```sh
git clone https://github.com/kunalkumarofficial/productive.git
open productive/Productive.xcodeproj
```

Press **⌘R** in Xcode. The project is configured to "Sign to Run Locally" out
of the box; select your own team in *Signing & Capabilities* if you prefer.

CI builds the app on every push via GitHub Actions (`.github/workflows/build.yml`).

## Shipping with an Apple Developer account

With a paid Apple Developer account you can distribute Productive so users can
install it with **zero warnings** — no `xattr` step, no "unidentified
developer" dialog. There are two paths; they are not exclusive.

### Path A — Notarized DMG on GitHub Releases (automated)

One-time setup, on your Mac, from the repo root:

1. In Xcode: Settings → Accounts → your team → *Manage Certificates…* →
   **+** → **Developer ID Application** (skip if you already have one).
2. Run the setup script — it finds your certificate, walks you through
   exporting it, asks for your Apple ID + an app-specific password, and stores
   all the GitHub secrets for you:

   ```sh
   ./scripts/setup-signing.sh
   ```

Then, to ship any release:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

A few minutes later the GitHub Releases page has a signed, notarized
`Productive.dmg` anyone can download, open, and drag to Applications —
Gatekeeper-clean, no warnings. The version number is stamped from the tag
automatically.

<details>
<summary>Secrets the script stores (for reference, or to set manually)</summary>

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | the `.p12` password |
| `KEYCHAIN_PASSWORD` | any random string |
| `APPLE_TEAM_ID` | your 10-character Team ID |
| `NOTARY_APPLE_ID` | your Apple ID email |
| `NOTARY_PASSWORD` | an app-specific password from account.apple.com |

</details>

### Path B — Mac App Store

The app already satisfies the App Store's technical requirements: App Sandbox
on, hardened runtime on, app category set, icon included, export-compliance
key embedded (so the "does your app use encryption?" question is pre-answered).

1. Sign in to Xcode with your Apple ID (Settings → Accounts) — once.
2. Create the app record in
   [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** →
   New App: platform macOS, bundle ID `com.kunalkumar.Productive`. If the name
   "Productive" is taken, pick a variant (e.g. "Productive – Local Tasks");
   the store name can differ from the app's on-disk name.
3. Archive and upload with one command:

   ```sh
   ./scripts/release-appstore.sh 1.0.0
   ```

4. In App Store Connect: attach the build, add 1–3 screenshots (1280×800 or
   2880×1800 — ⌘⇧4 then Space, click the app window), a description, and a
   support URL (this repo works). For the privacy questionnaire the honest
   answer is the best possible one: **Data Not Collected** — the app has no
   network access at all. Submit for review.

## Where your data lives

Inside the app's sandbox container:
`~/Library/Containers/com.kunalkumar.Productive/Data/Library/Application Support/Productive/`

- `productive-data.json` — all tasks, projects, habits, notes, and focus sessions
- `Backups/` — automatic timestamped backups

Use **Settings → Data** to reveal this folder, export a backup anywhere, or
import one.
