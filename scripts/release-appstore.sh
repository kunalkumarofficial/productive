#!/bin/bash
# Archive Productive and upload it to App Store Connect.
#
# Run this ON YOUR MAC from the repo root:
#   ./scripts/release-appstore.sh 1.0.0
#
# Prerequisites:
#   * Xcode is signed in to your Apple ID (Xcode -> Settings -> Accounts).
#   * An app record exists in App Store Connect with bundle ID
#     com.kunalkumar.Productive (https://appstoreconnect.apple.com).
#
# If the automatic upload step cannot authenticate, the script leaves the
# archive at build/Productive.xcarchive — open it with Xcode's Organizer
# (Window -> Organizer) and click "Distribute App" instead.

set -euo pipefail

VERSION="${1:?Usage: scripts/release-appstore.sh <version>, e.g. 1.0.0}"
TEAM_ID="${2:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -o '([A-Z0-9]\{10\})' | head -1 | tr -d '()')}"

if [ -z "$TEAM_ID" ]; then
  printf "Could not detect your Team ID. Enter it (10 characters): "
  read -r TEAM_ID
fi

BUILD_NUMBER=$(date +%Y%m%d%H%M)
ARCHIVE_PATH="build/Productive.xcarchive"
EXPORT_OPTIONS="build/ExportOptions.plist"

echo "==> Archiving version $VERSION (build $BUILD_NUMBER) for team $TEAM_ID"
xcodebuild \
  -project Productive.xcodeproj \
  -scheme Productive \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

mkdir -p build
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

echo "==> Uploading to App Store Connect"
if xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates; then
  echo
  echo "Uploaded. Finish in App Store Connect:"
  echo "https://appstoreconnect.apple.com -> your app -> add this build,"
  echo "screenshots, and description -> Submit for Review."
else
  echo
  echo "Automatic upload failed (usually an authentication issue)."
  echo "Open the archive in Xcode instead:  open $ARCHIVE_PATH"
  echo "then Window -> Organizer -> Distribute App -> App Store Connect."
  exit 1
fi
