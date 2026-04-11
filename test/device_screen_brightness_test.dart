// Tests for DeviceScreenBrightness that do not require a native runtime.
//
// Full integration tests (requiring a real device) live in
// example/integration_test/plugin_integration_test.dart.

import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceScreenBrightness.setBrightness validation', () {
    test('rejects -1', () {
      expect(
        () => DeviceScreenBrightness.setBrightness(-1),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });

    test('rejects 101', () {
      expect(
        () => DeviceScreenBrightness.setBrightness(101),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });
  });

  group('DeviceScreenBrightness.setBrightnessCompute validation', () {
    test('rejects -1', () {
      expect(
        () => DeviceScreenBrightness.setBrightnessCompute(-1),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });

    test('rejects 101', () {
      expect(
        () => DeviceScreenBrightness.setBrightnessCompute(101),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });
  });
}
