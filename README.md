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

## macOS — Limitaciones de plataforma

El soporte de macOS usa el framework privado `DisplayServices` de Apple. Esto limita el control de brillo a los siguientes dispositivos:

| Dispositivo | Funciona |
|-------------|:--------:|
| MacBook (pantalla integrada) | ✅ |
| iMac (pantalla integrada) | ✅ |
| Apple Studio Display | ✅ |
| Apple Pro Display XDR | ✅ |
| Monitores externos de terceros (LG, Dell, Samsung…) | ❌ |

Los monitores externos de terceros conectados por HDMI, DisplayPort o USB-C **no están soportados**. Cualquier llamada en ese dispositivo lanza `BackendNotAvailableException`.

> **¿Por qué?** macOS restringe el control de brillo por DDC/CI a apps con entitlements especiales de Apple. La API privada `IOAVService`, usada por herramientas como MonitorControl o m1ddc, requiere privilegios de root o entitlements com.apple.private.* que no están disponibles en aplicaciones de sandbox estándar.

---

## Regenerating bindings

```bash
# FFI bindings (C header → Dart)
dart run ffigen --config ffigen.yaml

# JNI bindings (Java → Dart)
dart run jnigen --config jnigen.yaml
```

---

## License

[MIT](LICENSE)
