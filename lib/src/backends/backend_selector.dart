import 'dart:io' show Platform;

import '../exceptions/device_screen_brightness_exception.dart';
import 'android_backend.dart';
import 'device_screen_brightness_backend.dart';
import 'ffi_backend.dart';

/// Returns the [DeviceScreenBrightnessBackend] for the current platform.
///
/// Android uses the [AndroidBackend] (JNIgen / Settings.System).
/// iOS, macOS, Linux and Windows use the [FfiBackend] (FFIgen / native C).
DeviceScreenBrightnessBackend backendForCurrentPlatform() {
  return _backend ??= _resolve();
}

DeviceScreenBrightnessBackend? _backend;

DeviceScreenBrightnessBackend _resolve() {
  if (Platform.isAndroid) {
    return AndroidBackend();
  }
  if (Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows) {
    return FfiBackend();
  }
  throw BackendNotAvailableException(
    message:
        'No device_screen_brightness backend available for '
        '${Platform.operatingSystem}.',
    details: {
      'platform': Platform.operatingSystem,
      'suggestedAction':
          'This platform is not yet supported by device_screen_brightness.',
    },
  );
}
