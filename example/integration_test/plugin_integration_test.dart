import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceScreenBrightness integration', () {
    test('getBrightness returns value in [0, 100]', () {
      final value = DeviceScreenBrightness.getBrightness();
      expect(value, inInclusiveRange(0, 100));
    });

    test('setBrightness and read back', () {
      final original = DeviceScreenBrightness.getBrightness();
      final target = original < 50 ? original + 10 : original - 10;
      DeviceScreenBrightness.setBrightness(target.clamp(0, 100));
      final newValue = DeviceScreenBrightness.getBrightness();
      // Allow ±5 tolerance for platform rounding
      expect(newValue, closeTo(target.clamp(0, 100), 5));
      // Restore
      DeviceScreenBrightness.setBrightness(original);
    });

    test('setBrightness throws InvalidBrightnessValueException for -1', () {
      expect(
        () => DeviceScreenBrightness.setBrightness(-1),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });

    test('setBrightness throws InvalidBrightnessValueException for 101', () {
      expect(
        () => DeviceScreenBrightness.setBrightness(101),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });

    test('incrementBrightness does not exceed 100', () {
      DeviceScreenBrightness.setBrightness(95);
      DeviceScreenBrightness.incrementBrightness();
      expect(DeviceScreenBrightness.getBrightness(), lessThanOrEqualTo(100));
    });

    test('decrementBrightness does not go below 0', () {
      DeviceScreenBrightness.setBrightness(5);
      DeviceScreenBrightness.decrementBrightness();
      expect(DeviceScreenBrightness.getBrightness(), greaterThanOrEqualTo(0));
    });

    test('streamBrightness emits values', () {
      expect(DeviceScreenBrightness.streamBrightness(), isA<Stream<int>>());
    });
  });
}
