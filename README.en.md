# UUFlow

UUFlow is a macOS display companion for UU Remote. It identifies the active controller, creates exactly one device-specific virtual display, and restores windows, the main display, and physical display modes when the session ends.

> UUFlow is not official UU Remote software. There is currently no public UUFlow binary release; build and install it from source.

[中文](README.md) · [日本語](README.ja.md) · [Development](docs/development.md) · [How it works](docs/how-it-works.md)

## Current capabilities

Phase 1 is complete and frozen:

- OnePlus 12 (`一加 12 全网通版`) routes only to its landscape display.
- iPad Air M1 (`iPad Air 5`) routes only to its iPad display.
- ThinkPad E16 (`THINKPAD-E16`) routes only to a `1280×720` computer display.
- MacBook Neo (`MacBook-Neo`) routes only to a `1408×881` computer display and temporarily becomes the main display during that session.
- Legion Y9000P (`LEGION-Y9000P`) explicitly bypasses UUFlow.
- Unknown, unbound, conflicting, disabled, or missing routes fail closed with no virtual display.
- Phone and tablet displays retain touch behavior and the App Library; computer displays behave like ordinary desktops.
- Session teardown restores the original physical main display before removing the Neo display and preserves physical resolution, HiDPI, and refresh rate.

Keyboard mode, LOCAL / REMOTE, Alt+Tab routing, and trackpad work are not implemented yet.

## Install from source

Requirements: macOS 14 or later, Xcode/Swift 6, and a working UU Remote installation.

```bash
git clone https://github.com/YuukiAS/UUFlow.git
cd UUFlow
scripts/uuflow check
scripts/uuflow install
```

The app is installed at `/Applications/UUFlow.app`. macOS Accessibility permission is required to read the current UU Remote controller, move windows, and translate touch input.

## Development commands

```text
scripts/uuflow check             Full build and test gate
scripts/uuflow app               Build build/UUFlow.app
scripts/uuflow install           Safely install and open /Applications/UUFlow.app
scripts/uuflow dist              Build a locally signed and notarized UUFlow DMG
scripts/uuflow remote-check uu   Run the UU Remote compatibility check
```

Internal Swift targets remain `Snug`, `SnugCore`, and `SnugSystem`. The bundle ID remains `com.zephyr4123.snug`, and compatible data is still read from `~/Library/Application Support/Snug`. These internal names preserve existing permissions, display identities, and user data; they are not the product brand.

UUFlow has no runtime updater. Launching the app does not contact an upstream update feed or download a replacement app.

## Upstream and license

UUFlow is based on [Snug](https://github.com/zephyr4123/snug) and the earlier [UUyc-companion](https://github.com/aoyamashou/UUyc-companion). It remains MIT-licensed; see [LICENSE](LICENSE) for copyright and attribution details.
