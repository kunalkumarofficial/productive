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

The `Release` workflow (`.github/workflows/release.yml`) builds, signs,
notarizes, and staples a DMG, then attaches it to a GitHub Release. One-time
setup:

1. **Create a Developer ID Application certificate.** In Xcode:
   Settings → Accounts → your Apple ID → your team → *Manage Certificates…* →
   **+** → *Developer ID Application*.
2. **Export it as a .p12.** Open *Keychain Access*, find
   "Developer ID Application: …", right-click → *Export…*, choose `.p12` and
   set a password. Then base64 it:

   ```sh
   base64 -i DeveloperID.p12 | pbcopy
   ```
3. **Create an app-specific password** for notarization at
   [account.apple.com](https://account.apple.com) → Sign-In and Security →
   App-Specific Passwords.
4. **Add repository secrets** (GitHub repo → Settings → Secrets and variables →
   Actions):

   | Secret | Value |
   | --- | --- |
   | `MACOS_CERTIFICATE` | the base64 .p12 from step 2 |
   | `MACOS_CERTIFICATE_PASSWORD` | the .p12 password |
   | `KEYCHAIN_PASSWORD` | any random string |
   | `APPLE_TEAM_ID` | your 10-character Team ID (Membership page) |
   | `NOTARY_APPLE_ID` | your Apple ID email |
   | `NOTARY_PASSWORD` | the app-specific password from step 3 |

5. **Ship:** `git tag v1.0.0 && git push origin v1.0.0`. A few minutes later
   the Release page has a `Productive.dmg` anyone can download, open, and drag
   to Applications — Gatekeeper-clean.

### Path B — Mac App Store

The app already satisfies the App Store's technical requirements: App Sandbox
on, hardened runtime on, app category set, icon included. From Xcode:

1. Set your **Team** under *Signing & Capabilities* (and keep the bundle ID,
   or change it to one registered to your team).
2. Create the app record in [App Store Connect](https://appstoreconnect.apple.com)
   with the same bundle ID.
3. *Product → Archive*, then in the Organizer choose *Distribute App →
   App Store Connect*. Xcode handles signing and upload.
4. In App Store Connect fill in metadata. For the privacy questionnaire the
   honest answer is the best possible one: **Data Not Collected** — the app has
   no network access at all. Provide 1–3 screenshots (1280×800 or 2880×1800),
   a description, keywords, and a support URL (this repo works), then submit
   for review.

## Where your data lives

Inside the app's sandbox container:
`~/Library/Containers/com.kunalkumar.Productive/Data/Library/Application Support/Productive/`

- `productive-data.json` — all tasks, projects, habits, notes, and focus sessions
- `Backups/` — automatic timestamped backups

Use **Settings → Data** to reveal this folder, export a backup anywhere, or
import one.
