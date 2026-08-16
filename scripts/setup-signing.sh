#!/bin/bash
# One-time setup for the automated notarized releases.
#
# Run this ON YOUR MAC from the repo root:
#   ./scripts/setup-signing.sh
#
# It collects your Developer ID certificate and notarization credentials and
# stores them as GitHub Actions secrets. After it succeeds, every
# `git tag vX.Y.Z && git push origin vX.Y.Z` produces a signed, notarized DMG
# on the GitHub Releases page.
#
# Prerequisites:
#   * GitHub CLI:  brew install gh
#   * A "Developer ID Application" certificate in your keychain
#     (Xcode -> Settings -> Accounts -> your team -> Manage Certificates -> +)

set -euo pipefail

REPO="kunalkumarofficial/productive"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required. Install it with:  brew install gh"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  bold "Signing in to GitHub…"
  gh auth login
fi

bold "Step 1/3 — Developer ID certificate"
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)

if [ -z "$IDENTITY" ]; then
  echo "No 'Developer ID Application' certificate found in your keychain."
  echo "Create one first: Xcode -> Settings -> Accounts -> select your team ->"
  echo "Manage Certificates… -> + -> Developer ID Application. Then re-run."
  exit 1
fi

TEAM_ID=$(printf '%s' "$IDENTITY" | sed 's/.*(\([A-Z0-9]*\))$/\1/')
echo "Found certificate: $IDENTITY"
echo "Team ID: $TEAM_ID"
echo
echo "Now export that certificate as a .p12 file:"
echo "  1. Open Keychain Access (login keychain -> My Certificates)."
echo "  2. Right-click \"$IDENTITY\" -> Export…"
echo "  3. Save as .p12 and choose a password."
echo
printf "Drag the exported .p12 file into this window and press Enter: "
read -r P12_PATH
P12_PATH=$(printf '%s' "$P12_PATH" | sed "s/^ *//;s/ *$//;s/^'//;s/'$//")
if [ ! -f "$P12_PATH" ]; then
  echo "File not found: $P12_PATH"
  exit 1
fi
printf "Password you set for the .p12: "
read -rs P12_PASSWORD
echo

bold "Step 2/3 — Notarization credentials"
printf "Your Apple ID email: "
read -r APPLE_ID
echo "Create an app-specific password at https://account.apple.com"
echo "(Sign-In and Security -> App-Specific Passwords)."
printf "App-specific password (xxxx-xxxx-xxxx-xxxx): "
read -rs APP_PASSWORD
echo

bold "Step 3/3 — Storing GitHub secrets for $REPO"
base64 -i "$P12_PATH" | gh secret set MACOS_CERTIFICATE -R "$REPO"
gh secret set MACOS_CERTIFICATE_PASSWORD -R "$REPO" -b "$P12_PASSWORD"
gh secret set KEYCHAIN_PASSWORD -R "$REPO" -b "$(uuidgen)"
gh secret set APPLE_TEAM_ID -R "$REPO" -b "$TEAM_ID"
gh secret set NOTARY_APPLE_ID -R "$REPO" -b "$APPLE_ID"
gh secret set NOTARY_PASSWORD -R "$REPO" -b "$APP_PASSWORD"

echo
bold "Done. Ship a release with:"
echo "  git tag v1.0.0 && git push origin v1.0.0"
echo "A notarized Productive.dmg will appear on the GitHub Releases page."
