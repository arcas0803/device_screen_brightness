/// Internal contract that every platform backend must implement.
///
/// All brightness values are normalized to a **0–100** integer scale regardless
/// of the platform's native range. Backends are not exposed publicly; the
/// [DeviceScreenBrightness] façade delegates to the backend selected by
/// [backendForCurrentPlatform].
///
/// The [BrightnessMode] parameter is only meaningful on Android:
/// * [BrightnessMode.app] — adjusts the current Activity window brightness.
/// * [BrightnessMode.system] — adjusts the global system brightness.
///
/// Non-Android backends **ignore** the [mode] parameter.
library;

import '../brightness_mode.dart';

abstract class DeviceScreenBrightnessBackend {
  /// Returns the current brightness (0–100).
  int getBrightness({BrightnessMode mode = BrightnessMode.system});

  /// Sets the brightness to [value] (0–100) and returns the resulting
  /// brightness.
  int setBrightness(int value, {BrightnessMode mode = BrightnessMode.system});

  /// Increases brightness by one platform step and returns the resulting
  /// brightness (0–100).
  int incrementBrightness({BrightnessMode mode = BrightnessMode.system});

  /// Decreases brightness by one platform step and returns the resulting
  /// brightness (0–100).
  int decrementBrightness({BrightnessMode mode = BrightnessMode.system});

  /// Emits the current brightness (0–100) followed by subsequent changes.
  ///
  /// Implementations must emit the current value immediately upon
  /// subscription and then only emit when the brightness actually changes.
  Stream<int> streamBrightness({BrightnessMode mode = BrightnessMode.system});
}
