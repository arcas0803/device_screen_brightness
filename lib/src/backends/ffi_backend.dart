import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import '../../device_screen_brightness_bindings_generated.dart';
import '../brightness_mode.dart';
import '../exceptions/device_screen_brightness_exception.dart';
import 'device_screen_brightness_backend.dart';

/// FFI backend used on iOS, macOS, Linux, and Windows.
///
/// Loads the native library via [DynamicLibrary] and delegates to the
/// generated [DeviceScreenBrightnessBindings].
class FfiBackend implements DeviceScreenBrightnessBackend {
  late final DeviceScreenBrightnessBindings _bindings;

  FfiBackend() {
    _bindings = DeviceScreenBrightnessBindings(_openLibrary());
  }

  // ── Library loading ──────────────────────────────────────────────────────

  static DynamicLibrary _openLibrary() {
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libdevice_screen_brightness.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('device_screen_brightness.dll');
    }
    throw const BackendNotAvailableException(
      message: 'FFI backend is not available on this platform.',
    );
  }

  // ── Result translation ───────────────────────────────────────────────────

  int _toInt(DeviceScreenBrightnessResult r) {
    _checkError(r);
    return r.value;
  }

  void _checkError(DeviceScreenBrightnessResult r) {
    switch (r.error_code) {
      case DSB_OK:
        return;
      case DSB_UNSUPPORTED_OPERATION:
        throw const UnsupportedOperationException(
          message: 'This operation is not supported on the current platform.',
        );
      case DSB_PERMISSION_DENIED:
        throw const PermissionDeniedException(
          message: 'Permission denied by the operating system.',
        );
      case DSB_NATIVE_FAILURE:
        throw const NativeBackendException(
          message: 'The native brightness backend reported an error.',
        );
      case DSB_INVALID_VALUE:
        throw const InvalidBrightnessValueException(
          message: 'The brightness value is outside the valid range (0–100).',
        );
      case DSB_BACKEND_NOT_AVAILABLE:
        throw const BackendNotAvailableException(
          message: 'No brightness backend available on this system.',
        );
      default:
        throw NativeBackendException(
          message: 'Unknown native error code: ${r.error_code}',
        );
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────

  @override
  int getBrightness({BrightnessMode mode = BrightnessMode.system}) {
    final r = _bindings.device_screen_brightness_get();
    return _toInt(r);
  }

  @override
  int setBrightness(int value, {BrightnessMode mode = BrightnessMode.system}) {
    final r = _bindings.device_screen_brightness_set(value);
    return _toInt(r);
  }

  @override
  int incrementBrightness({BrightnessMode mode = BrightnessMode.system}) {
    final r = _bindings.device_screen_brightness_increment();
    return _toInt(r);
  }

  @override
  int decrementBrightness({BrightnessMode mode = BrightnessMode.system}) {
    final r = _bindings.device_screen_brightness_decrement();
    return _toInt(r);
  }

  @override
  Stream<int> streamBrightness({BrightnessMode mode = BrightnessMode.system}) {
    late StreamController<int> controller;
    Timer? timer;
    int? lastValue;

    controller = StreamController<int>(
      onListen: () {
        lastValue = getBrightness();
        controller.add(lastValue!);

        timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          try {
            final current = getBrightness();
            if (current != lastValue) {
              lastValue = current;
              controller.add(current);
            }
          } on DeviceScreenBrightnessException catch (e) {
            controller.addError(e);
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
