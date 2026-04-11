import 'dart:async';

import 'package:jni/jni.dart';

import '../brightness_mode.dart';
import '../exceptions/device_screen_brightness_exception.dart';
import '../jni/device_screen_brightness_helper.dart';
import 'device_screen_brightness_backend.dart';

/// Android backend using JNIgen-generated bindings to Settings.System.
class AndroidBackend implements DeviceScreenBrightnessBackend {
  late final DeviceScreenBrightnessHelper _helper;

  AndroidBackend() {
    // Get application context via ActivityThread.currentApplication().
    final activityThread = JClass.forName(r'android/app/ActivityThread');

    final methodId = activityThread.staticMethodId(
      r'currentApplication',
      r'()Landroid/app/Application;',
    );
    final context = methodId.call<JObject, JObject>(
      activityThread,
      JObject.type,
      [],
    );
    activityThread.release();
    _helper = DeviceScreenBrightnessHelper(context);
  }

  int _query({BrightnessMode mode = BrightnessMode.system}) {
    try {
      return mode == BrightnessMode.app
          ? _helper.getAppBrightness()
          : _helper.getScreenBrightness();
    } on Exception catch (e) {
      throw NativeBackendException(
        message: 'Settings.System error: $e',
        details: {'platform': 'android'},
      );
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────

  @override
  int getBrightness({BrightnessMode mode = BrightnessMode.system}) {
    return _query(mode: mode);
  }

  /// Whether the app has the WRITE_SETTINGS permission.
  bool hasPermission() {
    return _helper.canWrite();
  }

  /// Opens the system settings screen to grant WRITE_SETTINGS permission.
  void requestPermission() {
    _helper.requestPermission();
  }

  @override
  int setBrightness(int value, {BrightnessMode mode = BrightnessMode.system}) {
    try {
      return mode == BrightnessMode.app
          ? _helper.setAppBrightness(value)
          : _helper.setScreenBrightness(value);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('permission') || msg.contains('WRITE_SETTINGS')) {
        throw PermissionDeniedException(
          message: 'WRITE_SETTINGS permission not granted: $e',
          details: {'platform': 'android'},
        );
      }
      throw NativeBackendException(
        message: 'Settings.System error: $e',
        details: {'platform': 'android'},
      );
    }
  }

  @override
  int incrementBrightness({BrightnessMode mode = BrightnessMode.system}) {
    final current = _query(mode: mode);
    int next = current + 5;
    if (next > 100) next = 100;
    return setBrightness(next, mode: mode);
  }

  @override
  int decrementBrightness({BrightnessMode mode = BrightnessMode.system}) {
    final current = _query(mode: mode);
    int next = current - 5;
    if (next < 0) next = 0;
    return setBrightness(next, mode: mode);
  }

  @override
  Stream<int> streamBrightness({BrightnessMode mode = BrightnessMode.system}) {
    late StreamController<int> controller;
    Timer? timer;
    int? lastValue;

    controller = StreamController<int>(
      onListen: () {
        lastValue = _query(mode: mode);
        controller.add(lastValue!);

        timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          try {
            final current = _query(mode: mode);
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
