# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This project uses XcodeGen to generate the Xcode project from `project.yml`.

```bash
# Generate Xcode project (required before building)
xcodegen generate

# Build Debug
xcodebuild -project "WiFi Boost.xcodeproj" -scheme "WiFi Boost" -configuration Debug build

# Build Release
xcodebuild -project "WiFi Boost.xcodeproj" -scheme "WiFi Boost" -configuration Release build

# Clean build
xcodebuild -project "WiFi Boost.xcodeproj" -scheme "WiFi Boost" clean build
```

The built app is located at `~/Library/Developer/Xcode/DerivedData/WiFi_Boost-*/Build/Products/{Debug,Release}/WiFi Boost.app`

## Architecture

**Menu bar app** (no dock icon, no main window) that toggles macOS AWDL interface to reduce Wi-Fi latency.

### Key Components

- **WiFiBoostApp.swift** - App entry point using `@NSApplicationDelegateAdaptor` pattern. The `AppDelegate` manages:
  - `NSStatusItem` for menu bar icon (left-click toggles, right-click shows menu)
  - 2-second polling timer to sync icon with actual AWDL state
  - "Keep Boosted" auto-restore feature
  - Launch at login via `SMAppService`

- **AWDLController.swift** - Singleton that interfaces with the system:
  - `isEnabled()` - Checks if awdl0 interface has "RUNNING" flag via `/sbin/ifconfig`
  - `setEnabled(_:)` - Runs `sudo /sbin/ifconfig awdl0 up/down`

### System Requirements

The app requires **passwordless sudo** for ifconfig commands. Users must configure `/etc/sudoers.d/awdl`:
```
USERNAME ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down
USERNAME ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 up
```

### Project Configuration

- `LSUIElement: true` - Hides app from Dock (menu bar only)
- `ENABLE_APP_SANDBOX: NO` - Required to execute system commands
- Deployment target: macOS 14.0+
