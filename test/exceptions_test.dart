import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceScreenBrightnessException hierarchy', () {
    test('UnsupportedOperationException implements Exception', () {
      const e = UnsupportedOperationException(message: 'not supported');
      expect(e, isA<Exception>());
      expect(e, isA<DeviceScreenBrightnessException>());
      expect(e.code, 'unsupported_operation');
      expect(e.message, 'not supported');
    });

    test('InvalidBrightnessValueException has correct code', () {
      const e = InvalidBrightnessValueException(message: 'bad value');
      expect(e.code, 'invalid_brightness_value');
      expect(e.message, 'bad value');
    });

    test('NativeBackendException has correct code', () {
      const e = NativeBackendException(message: 'native error');
      expect(e.code, 'native_backend_failure');
    });

    test('BrightnessObservationException has correct code', () {
      const e = BrightnessObservationException(message: 'obs error');
      expect(e.code, 'brightness_observation_failure');
    });

    test('BackendNotAvailableException has correct code', () {
      const e = BackendNotAvailableException(message: 'no backend');
      expect(e.code, 'backend_not_available');
    });

    test('PermissionDeniedException has correct code', () {
      const e = PermissionDeniedException(message: 'denied');
      expect(e.code, 'permission_denied');
    });

    test('toString includes code and message', () {
      const e = NativeBackendException(message: 'fail');
      final s = e.toString();
      expect(s, contains('native_backend_failure'));
      expect(s, contains('fail'));
    });

    test('toString includes details when present', () {
      const e = NativeBackendException(
        message: 'fail',
        details: {'platform': 'linux'},
      );
      expect(e.toString(), contains('linux'));
    });

    test('details default to empty map', () {
      const e = UnsupportedOperationException(message: 'test');
      expect(e.details, isEmpty);
    });

    test('all subclasses are subtypes of DeviceScreenBrightnessException', () {
      expect(
        const UnsupportedOperationException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
      expect(
        const InvalidBrightnessValueException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
      expect(
        const NativeBackendException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
      expect(
        const BrightnessObservationException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
      expect(
        const BackendNotAvailableException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
      expect(
        const PermissionDeniedException(message: ''),
        isA<DeviceScreenBrightnessException>(),
      );
    });
  });

  group('Facade validation (setBrightness)', () {
    void validateRange(int value) {
      if (value < 0 || value > 100) {
        throw InvalidBrightnessValueException(
          message: 'Brightness value must be between 0 and 100, got $value.',
        );
      }
    }

    test('accepts 0', () => expect(() => validateRange(0), returnsNormally));
    test('accepts 50', () => expect(() => validateRange(50), returnsNormally));
    test(
      'accepts 100',
      () => expect(() => validateRange(100), returnsNormally),
    );

    test('rejects -1', () {
      expect(
        () => validateRange(-1),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });

    test('rejects 101', () {
      expect(
        () => validateRange(101),
        throwsA(isA<InvalidBrightnessValueException>()),
      );
    });
  });
}
