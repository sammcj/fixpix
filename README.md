# FixPix

A lightweight command-line tool to fix text scaling and resolution of iOS/iPadOS apps running on Apple Silicon Macs.

By default, iOS/iPadOS apps run at 77% scaling on macOS which can result in small, blurry text. FixPix lets you run these apps at native resolution for pixel-perfect graphics and improved text clarity.

## Usage

```bash
./fixpix.sh <command> [args]

Commands:
  list                     List all iOS/iPadOS apps
  search <search_string>   Search for apps with matching bundle IDs or names
  check <bundle_id>       Check current scaling settings
  enable <bundle_id>      Enable native scaling for an app
  disable <bundle_id>     Disable native scaling for an app
```

### Examples

List all iOS/iPadOS apps installed:
```bash
./fixpix.sh list
```

Search for an app:
```bash
./fixpix.sh search "twitter"
```

Check current scaling settings:
```bash
./fixpix.sh check com.example.myapp
```

Enable native scaling:
```bash
./fixpix.sh enable com.example.myapp
```

## Requirements

- Apple Silicon Mac (M1/M2/M3)
- iOS/iPadOS apps installed
- macOS 11.0 or later

## Notes

- Changes take effect after restarting the app
- Works with both App Store and sideloaded iOS/iPadOS apps
- No administrator privileges or system modifications required
- This script only modifies user preferences files in your home directory

## How it Works

FixPix modifies the app's scaling preferences by setting `iOSMacScaleFactor` to 1.0 for native resolution, similar to how the official Pixel Perfect app works but without requiring full disk access.
