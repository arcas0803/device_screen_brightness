import 'dart:io' show Platform;

import 'src/backends/android_backend.dart';
import 'src/backends/backend_selector.dart';
import 'src/brightness_mode.dart';
import 'src/compute/device_screen_brightness_compute.dart' as compute;
import 'src/exceptions/device_screen_brightness_exception.dart';

export 'src/brightness_mode.dart';
export 'src/exceptions/device_screen_brightness_exception.dart';

/// Flutter plugin for reading and controlling the device screen brightness.
///
/// All brightness values are normalised to the **0–100** integer range
/// regardless of each platform's native scale.
///
/// On Android, a [BrightnessMode] parameter lets you choose between
/// **app-level** brightness (no permission required) and **system-level**
/// brightness (requires `WRITE_SETTINGS`). The parameter is ignored on all
/// other platforms.
abstract final class DeviceScreenBrightness {
  // ── Synchronous ──────────────────────────────────────────────────────────

  /// Returns the current screen brightness (0–100).
  ///
  /// On Android, [mode] selects app-level or system-level brightness.
  /// Ignored on other platforms.
  static int getBrightness({BrightnessMode mode = BrightnessMode.system}) {
    return backendForCurrentPlatform().getBrightness(mode: mode);
  }

  /// Sets the screen brightness to [value] (0–100) and returns the
  /// resulting brightness.
  ///
  /// On Android with [BrightnessMode.system], requires `WRITE_SETTINGS`.
  /// With [BrightnessMode.app], no permission is needed.
  ///
  /// Throws [InvalidBrightnessValueException] if [value] is outside 0–100.
  static int setBrightness(
    int value, {
    BrightnessMode mode = BrightnessMode.system,
  }) {
    if (value < 0 || value > 100) {
      throw InvalidBrightnessValueException(
        message: 'Brightness value must be between 0 and 100, got $value.',
      );
    }
    return backendForCurrentPlatform().setBrightness(value, mode: mode);
  }

  /// Increments the brightness by one platform step and returns the
  /// resulting brightness (0–100).
  static int incrementBrightness({
    BrightnessMode mode = BrightnessMode.system,
  }) {
    return backendForCurrentPlatform().incrementBrightness(mode: mode);
  }

  /// Decrements the brightness by one platform step and returns the
  /// resulting brightness (0–100).
  static int decrementBrightness({
    BrightnessMode mode = BrightnessMode.system,
  }) {
    return backendForCurrentPlatform().decrementBrightness(mode: mode);
  }

  // ── Compute (background isolate) ─────────────────────────────────────────

  /// [getBrightness] executed on a background isolate via `compute`.
  static Future<int> getBrightnessCompute({
    BrightnessMode mode = BrightnessMode.system,
  }) => compute.getBrightnessCompute(mode: mode);

  /// [setBrightness] executed on a background isolate via `compute`.
  ///
  /// Throws [InvalidBrightnessValueException] if [value] is outside 0–100.
  static Future<int> setBrightnessCompute(
    int value, {
    BrightnessMode mode = BrightnessMode.system,
  }) {
    if (value < 0 || value > 100) {
      throw InvalidBrightnessValueException(
        message: 'Brightness value must be between 0 and 100, got $value.',
      );
    }
    return compute.setBrightnessCompute(value, mode: mode);
  }

  /// [incrementBrightness] executed on a background isolate via `compute`.
  static Future<int> incrementBrightnessCompute({
    BrightnessMode mode = BrightnessMode.system,
  }) => compute.incrementBrightnessCompute(mode: mode);

  /// [decrementBrightness] executed on a background isolate via `compute`.
  static Future<int> decrementBrightnessCompute({
    BrightnessMode mode = BrightnessMode.system,
  }) => compute.decrementBrightnessCompute(mode: mode);

  // ── Android permission ────────────────────────────────────────────────────

  /// Whether the app has the `WRITE_SETTINGS` permission.
  ///
  /// Always returns `true` on non-Android platforms (no permission needed).
  static bool hasPermission() {
    if (!Platform.isAndroid) return true;
    final backend = backendForCurrentPlatform();
    return (backend as AndroidBackend).hasPermission();
  }

  /// Opens the Android system settings screen where the user can grant the
  /// `WRITE_SETTINGS` permission to this app.
  ///
  /// Does nothing on non-Android platforms.
  static void requestPermission() {
    if (!Platform.isAndroid) return;
    final backend = backendForCurrentPlatform();
    (backend as AndroidBackend).requestPermission();
  }

  // ── Stream ───────────────────────────────────────────────────────────────

  /// Emits the current brightness (0–100) immediately and then whenever
  /// the value changes.  Uses 250 ms polling.
  ///
  /// On Android, [mode] selects app-level or system-level brightness.
  /// Ignored on other platforms.
  static Stream<int> streamBrightness({
    BrightnessMode mode = BrightnessMode.system,
  }) {
    return backendForCurrentPlatform().streamBrightness(mode: mode);
  }
}
