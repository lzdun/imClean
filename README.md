# imClean

A small macOS utility that temporarily locks your keyboard, mouse and trackpad so you can safely wipe down your MacBook (or any Mac) without triggering random input.

## How it works

- Click **Lock** and imClean installs a HID-level event tap that swallows all keyboard, mouse, trackpad, scroll, gesture and media-key events. Overlays are shown while locked.
- **Unlock** by holding `Esc` for 2 seconds.
- As a safety net, input is automatically unlocked after 5 minutes.

## Requirements

- macOS 13 or later
- Swift 6 toolchain (Xcode 16+ or matching command line tools)
- **Accessibility permission** — required to create the event tap. Enable imClean in *System Settings → Privacy & Security → Accessibility*, then relaunch the app if prompted.

## Build

```sh
./build.sh
```

This builds a release binary with SwiftPM, assembles `build/imClean.app` using `Resources/Info.plist`, and ad-hoc code signs it (identifier `com.lzdun.imclean`).

Run it with:

```sh
open build/imClean.app
```

For development you can also use `swift build` / `swift run`, but Accessibility permission is tied to the app bundle, so the `.app` build is recommended.
