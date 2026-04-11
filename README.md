# device_screen_brightness

[![pub.dev](https://img.shields.io/pub/v/device_screen_brightness.svg)](https://pub.dev/packages/device_screen_brightness)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Flutter FFI plugin for reading and controlling screen brightness on Android, iOS, macOS, Windows, and Linux.

All brightness values are normalised to an **integer 0–100** regardless of each platform's native range.

---

## Platform support

| Platform | getBrightness | setBrightness | increment / decrement | streamBrightness | Notes |
|----------|:---:|:---:|:---:|:---:|-------|
| Android  | ✅ | ✅ | ✅ | ✅ | App-level & system-level modes (see below) |
| iOS      | ✅ | ✅ | ✅ | ✅ | UIScreen.brightness |
| macOS    | ✅ | ✅ | ✅ | ✅ | DisplayServices (built-in Apple displays only — see below) |
| Linux    | ✅ | ✅ | ✅ | ✅ | sysfs backlight (group `video`) |
| Windows  | ✅ | ✅ | ✅ | ✅ | Physical Monitor API (dxva2) |

---

## Installation

```yaml
dependencies:
  device_screen_brightness: ^0.2.0
```

---

## Android — BrightnessMode

On Android, every brightness operation accepts an optional `BrightnessMode`
parameter that controls **what** brightness is modified:

| Mode | Behaviour | Permission |
|------|-----------|------------|
| `BrightnessMode.app` | Changes `WindowManager.LayoutParams.screenBrightness` on the current Activity. Only affects this app; resets when the Activity is destroyed. | **None** |
| `BrightnessMode.system` *(default)* | Writes `Settings.System.SCREEN_BRIGHTNESS`. Affects the entire device and persists after the app is closed. | `WRITE_SETTINGS` |

> On **iOS, macOS, Linux and Windows** the `mode` parameter is ignored — the
> system brightness is always used.

### System-level brightness — AndroidManifest.xml

If you plan to use `BrightnessMode.system` (the default), add the following
permission to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    ...
</manifest>
```

`WRITE_SETTINGS` is a *special permission* — it is **not** granted
automatically at install time. Before calling `setBrightness` with
`BrightnessMode.system`, check and request the permission:

```dart
// Check whether the permission has already been granted
if (!DeviceScreenBrightness.hasPermission()) {
  // Opens the system settings screen where the user can grant the permission
  DeviceScreenBrightness.requestPermission();
}
```

### App-level brightness — no permission needed

With `BrightnessMode.app` no permission is required. The brightness is
applied only to the current Activity window and resets when the app is
closed:

```dart
// Set app-level brightness (no permission needed)
DeviceScreenBrightness.setBrightness(75, mode: BrightnessMode.app);

// Read app-level brightness (falls back to system if not set)
int level = DeviceScreenBrightness.getBrightness(mode: BrightnessMode.app);
```

---

## Usage

```dart
import 'package:device_screen_brightness/device_screen_brightness.dart';

// Read brightness (0–100)
int level = DeviceScreenBrightness.getBrightness();

// Set brightness (0–100)
DeviceScreenBrightness.setBrightness(75);

// Increment / decrement by one platform step (5)
DeviceScreenBrightness.incrementBrightness();
DeviceScreenBrightness.decrementBrightness();

// Stream — emits current value immediately, then on every change (250 ms polling)
DeviceScreenBrightness.streamBrightness().listen((value) {
  print('Brightness: $value');
});
```

### BrightnessMode on Android

```dart
// App-level brightness (no permission needed, resets on Activity destroy)
DeviceScreenBrightness.setBrightness(80, mode: BrightnessMode.app);
int appLevel = DeviceScreenBrightness.getBrightness(mode: BrightnessMode.app);

// System-level brightness (requires WRITE_SETTINGS, persists)
DeviceScreenBrightness.setBrightness(80, mode: BrightnessMode.system);
int sysLevel = DeviceScreenBrightness.getBrightness(mode: BrightnessMode.system);

// Stream with a specific mode
DeviceScreenBrightness.streamBrightness(mode: BrightnessMode.app).listen((v) {
  print('App brightness: $v');
});
```

### Permission helpers (Android only)

```dart
// Returns true on non-Android platforms
bool granted = DeviceScreenBrightness.hasPermission();

// Opens system settings to grant WRITE_SETTINGS; no-op on non-Android
DeviceScreenBrightness.requestPermission();
```

### Compute variants

Every one-shot operation has a `*Compute` counterpart that runs on a background isolate:

```dart
int level = await DeviceScreenBrightness.getBrightnessCompute();
await DeviceScreenBrightness.setBrightnessCompute(80);
await DeviceScreenBrightness.incrementBrightnessCompute();
await DeviceScreenBrightness.decrementBrightnessCompute();

// Compute variants also accept mode:
await DeviceScreenBrightness.setBrightnessCompute(80, mode: BrightnessMode.app);
```

---

## Error handling

All failures throw a subclass of `DeviceScreenBrightnessException`:

| Exception | When |
|-----------|------|
| `UnsupportedOperationException` | Operation not supported on the current platform |
| `InvalidBrightnessValueException` | Value outside 0–100 |
| `NativeBackendException` | Native OS / driver error |
| `PermissionDeniedException` | Missing required permission (e.g. `WRITE_SETTINGS`) |
| `BackendNotAvailableException` | No brightness backend found (headless, VM, etc.) |
| `BrightnessObservationException` | Error while observing brightness changes |

---

## macOS — Platform limitations

macOS support uses Apple's private `DisplayServices` framework. This limits brightness control to the following devices:

| Device | Supported |
|--------|:---------:|
| MacBook (built-in display) | ✅ |
| iMac (built-in display) | ✅ |
| Apple Studio Display | ✅ |
| Apple Pro Display XDR | ✅ |
| Third-party external monitors (LG, Dell, Samsung…) | ❌ |

Third-party external monitors connected via HDMI, DisplayPort, or USB-C are **not supported**. Any call on such a setup throws `BackendNotAvailableException`.

> **Why?** macOS restricts DDC/CI brightness control to apps with special Apple entitlements. The private `IOAVService` API used by tools like MonitorControl and m1ddc requires root privileges or `com.apple.private.*` entitlements that are unavailable in standard sandboxed applications.

---

## Linux — Requirements

The sysfs backlight interface (`/sys/class/backlight`) requires write permission. On most distributions the current user must belong to the `video` group:

```bash
sudo usermod -aG video $USER
# Log out and back in for the change to take effect
```

If the user lacks write permission, `setBrightness` throws `PermissionDeniedException`.

---

## License

[MIT](LICENSE)
