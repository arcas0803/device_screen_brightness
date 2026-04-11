import 'package:flutter/foundation.dart';

import '../backends/backend_selector.dart';
import '../brightness_mode.dart';

/// Runs [DeviceScreenBrightnessBackend.getBrightness] on a background isolate
/// via [compute].
Future<int> getBrightnessCompute({
  BrightnessMode mode = BrightnessMode.system,
}) {
  return compute(_getBrightness, mode);
}

/// Runs [DeviceScreenBrightnessBackend.setBrightness] on a background isolate
/// via [compute].
Future<int> setBrightnessCompute(
  int value, {
  BrightnessMode mode = BrightnessMode.system,
}) {
  return compute(_setBrightness, (value, mode));
}

/// Runs [DeviceScreenBrightnessBackend.incrementBrightness] on a background
/// isolate via [compute].
Future<int> incrementBrightnessCompute({
  BrightnessMode mode = BrightnessMode.system,
}) {
  return compute(_adjustBrightness, (true, mode));
}

/// Runs [DeviceScreenBrightnessBackend.decrementBrightness] on a background
/// isolate via [compute].
Future<int> decrementBrightnessCompute({
  BrightnessMode mode = BrightnessMode.system,
}) {
  return compute(_adjustBrightness, (false, mode));
}

// ── Top-level functions required by compute() ───────────────────────────────

int _getBrightness(BrightnessMode mode) {
  return backendForCurrentPlatform().getBrightness(mode: mode);
}

int _setBrightness((int, BrightnessMode) args) {
  final (value, mode) = args;
  return backendForCurrentPlatform().setBrightness(value, mode: mode);
}

int _adjustBrightness((bool, BrightnessMode) args) {
  final (increment, mode) = args;
  final backend = backendForCurrentPlatform();
  if (increment) {
    return backend.incrementBrightness(mode: mode);
  }
  return backend.decrementBrightness(mode: mode);
}
