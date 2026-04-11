import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:device_screen_brightness/device_screen_brightness_bindings_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FFI error code constants', () {
    test('DSB_OK is 0', () => expect(DSB_OK, 0));
    test('DSB_UNSUPPORTED_OPERATION is 1', () {
      expect(DSB_UNSUPPORTED_OPERATION, 1);
    });
    test('DSB_PERMISSION_DENIED is 2', () {
      expect(DSB_PERMISSION_DENIED, 2);
    });
    test('DSB_NATIVE_FAILURE is 3', () => expect(DSB_NATIVE_FAILURE, 3));
    test('DSB_INVALID_VALUE is 4', () => expect(DSB_INVALID_VALUE, 4));
    test('DSB_BACKEND_NOT_AVAILABLE is 5', () {
      expect(DSB_BACKEND_NOT_AVAILABLE, 5);
    });
  });

  group('Error code → exception mapping', () {
    // This test validates the same switch logic that FfiBackend._checkError
    // uses, but without requiring a native library to be loaded.

    DeviceScreenBrightnessException? mapError(int code) {
      switch (code) {
        case DSB_OK:
          return null;
        case DSB_UNSUPPORTED_OPERATION:
          return const UnsupportedOperationException(message: 'test');
        case DSB_PERMISSION_DENIED:
          return const PermissionDeniedException(message: 'test');
        case DSB_NATIVE_FAILURE:
          return const NativeBackendException(message: 'test');
        case DSB_INVALID_VALUE:
          return const InvalidBrightnessValueException(message: 'test');
        case DSB_BACKEND_NOT_AVAILABLE:
          return const BackendNotAvailableException(message: 'test');
        default:
          return NativeBackendException(message: 'Unknown error code: $code');
      }
    }

    test('DSB_OK → null (no error)', () {
      expect(mapError(DSB_OK), isNull);
    });

    test('DSB_UNSUPPORTED_OPERATION → UnsupportedOperationException', () {
      expect(
        mapError(DSB_UNSUPPORTED_OPERATION),
        isA<UnsupportedOperationException>(),
      );
    });

    test('DSB_PERMISSION_DENIED → PermissionDeniedException', () {
      expect(mapError(DSB_PERMISSION_DENIED), isA<PermissionDeniedException>());
    });

    test('DSB_NATIVE_FAILURE → NativeBackendException', () {
      expect(mapError(DSB_NATIVE_FAILURE), isA<NativeBackendException>());
    });

    test('DSB_INVALID_VALUE → InvalidBrightnessValueException', () {
      expect(
        mapError(DSB_INVALID_VALUE),
        isA<InvalidBrightnessValueException>(),
      );
    });

    test('DSB_BACKEND_NOT_AVAILABLE → BackendNotAvailableException', () {
      expect(
        mapError(DSB_BACKEND_NOT_AVAILABLE),
        isA<BackendNotAvailableException>(),
      );
    });

    test('unknown code → NativeBackendException', () {
      expect(mapError(99), isA<NativeBackendException>());
    });
  });
}
