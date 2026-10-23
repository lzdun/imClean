#!/bin/sh
set -eu
cd "$(dirname "$0")"

swift build -c release

APP=build/imClean.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/imClean" "$APP/Contents/MacOS/imClean"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.lzdun.imclean "$APP"

echo "Built $APP"
