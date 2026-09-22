#!/bin/sh
# Sets CFBundleVersion (CURRENT_PROJECT_VERSION) to the git commit count so
# every upload to App Store Connect has a strictly increasing build number.
# Run from anywhere before Product > Archive / xcodebuild archive.
set -eu
cd "$(dirname "$0")/.."
BUILD=$(git rev-list --count HEAD)
echo "Setting build number to $BUILD"
xcrun agvtool new-version -all "$BUILD"
