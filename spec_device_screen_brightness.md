# device_screen_brightness spec

## Resumen

`device_screen_brightness` sera un paquete Flutter para pub.dev que expone control del brillo de pantalla del dispositivo mediante una API Dart uniforme y una implementacion nativa por plataforma. La solucion combina FFI + FFIgen (iOS, macOS, Linux, Windows) y JNIgen (Android).

Todos los valores de brillo se normalizan a un **entero 0–100** independientemente del rango nativo de cada plataforma. El paquete ofrece operaciones sincronas para lectura y escritura de brillo, mas homologos `*Compute` que ejecutan las operaciones en un isolate auxiliar mediante `Flutter.compute`.

**Cuenta GitHub:** `arcas0803`
**Licencia:** MIT

## Referencia de implementacion

Este plugin replica la arquitectura exacta de [`device_volume`](https://github.com/arcas0803/device_volume), que ya fue implementado y publicado con exito. La estructura de proyecto, contrato FFI, jerarquia de excepciones, patron de backend, CI/CD y flujo de publicacion son identicos. Solo cambian las APIs nativas consumidas en cada plataforma.

## Objetivos

- Exponer una API publica simple con `setBrightness`, `incrementBrightness`, `decrementBrightness`, `getBrightness` y `streamBrightness`.
- Normalizar todos los valores de brillo a un entero 0–100 en todas las plataformas.
- Mantener una interfaz Dart estable aunque el backend cambie por plataforma.
- Usar `JNIgen` exclusivamente en Android para integrarse con `Settings.System` y `WindowManager`.
- Usar `FFIgen` en iOS, macOS, Windows y Linux para generar bindings de las funciones C.
- Publicar en pub.dev con metadatos completos, ejemplo funcional, documentacion y pipeline CI/CD automatizado.

## No objetivos

- No se gestionara brillo por aplicacion individual (solo brillo del sistema/pantalla).
- No se garantizara paridad total entre plataformas cuando el sistema operativo no ofrezca API publica equivalente.
- No se soportaran operaciones largas mediante `compute` para flujos continuos; los streams tendran un backend dedicado con polling.
- No se gestionara el modo de brillo automatico (auto-brightness). Se puede leer si esta activo, pero no se activara/desactivara.

## API publica

### Tipos exportados

```dart
/// No hay enum equivalente a VolumeChannel — el brillo es un unico
/// recurso global del display principal.  Si en el futuro se necesita
/// soporte multi-display, se podra añadir un parametro `display`.
```

> La API publica devuelve `int` (0–100). No se exporta ningun modelo intermedio.

### Fachada principal

```dart
abstract final class DeviceScreenBrightness {
  // ── Sincrono ────────────────────────────────────────────────────────────

  /// Devuelve el brillo actual de la pantalla (0–100).
  static int getBrightness();

  /// Fija el brillo a [value] (0–100) y devuelve el brillo resultante.
  ///
  /// Lanza [InvalidBrightnessValueException] si [value] no esta en 0–100.
  static int setBrightness(int value);

  /// Incrementa el brillo en un paso de plataforma y devuelve el brillo
  /// resultante (0–100).
  static int incrementBrightness();

  /// Decrementa el brillo en un paso de plataforma y devuelve el brillo
  /// resultante (0–100).
  static int decrementBrightness();

  // ── Compute (background isolate) ───────────────────────────────────────

  static Future<int> getBrightnessCompute();
  static Future<int> setBrightnessCompute(int value);
  static Future<int> incrementBrightnessCompute();
  static Future<int> decrementBrightnessCompute();

  // ── Stream ─────────────────────────────────────────────────────────────

  /// Emite el brillo actual (0–100) inmediatamente y luego cada vez
  /// que cambia.  Polling cada 250 ms.
  static Stream<int> streamBrightness();
}
```

### Decision tecnica: Compute vs Stream

Igual que en `device_volume`: `compute` solo aplica a operaciones one-shot. `streamBrightness` **no** tiene variante Compute. El stream se implementa con polling cada 250 ms usando `Timer.periodic` sobre el backend nativo.

## Arquitectura

### Capa publica Dart

| Archivo | Proposito |
| --- | --- |
| `lib/device_screen_brightness.dart` | Fachada publica, validacion 0–100, exports |
| `lib/src/backends/device_screen_brightness_backend.dart` | Contrato interno (abstract class) |
| `lib/src/backends/backend_selector.dart` | Seleccion de backend por `Platform.*` |
| `lib/src/backends/ffi_backend.dart` | Backend FFI (iOS, macOS, Linux, Windows) |
| `lib/src/backends/android_backend.dart` | Backend JNIgen (Android) |
| `lib/src/compute/device_screen_brightness_compute.dart` | Wrappers `Flutter.compute` |
| `lib/src/exceptions/device_screen_brightness_exception.dart` | Jerarquia completa de excepciones |
| `lib/device_screen_brightness_bindings_generated.dart` | Bindings generados por FFIgen |

### Contrato del backend (abstract class)

```dart
abstract class DeviceScreenBrightnessBackend {
  int getBrightness();

  int setBrightness(int value);

  int incrementBrightness();

  int decrementBrightness();

  Stream<int> streamBrightness();
}
```

> Nota: a diferencia de `device_volume`, no hay parametro `channel` ni `showSystemUi` porque el brillo es un recurso unico del display.

### Backends por plataforma

#### Android — JNIgen + Settings.System

- Backend implementado en `lib/src/backends/android_backend.dart`.
- Obtiene el contexto de aplicacion via `ActivityThread.currentApplication()` por JNI (mismo patron que `device_volume`).
- **Lectura:** `Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS)` devuelve un valor en el rango **0–255**.
- **Escritura:** `Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, value)`.
- **Normalizacion:** lectura = `(nativeValue / 255.0 * 100).round()`; escritura = `(value / 100.0 * 255).round()`.
- **Permiso requerido:** `android.permission.WRITE_SETTINGS`. Es un permiso especial que el usuario debe conceder manualmente en Ajustes del sistema. La app debe abrir `Settings.ACTION_MANAGE_WRITE_SETTINGS` si no lo tiene.
  - Si la app no tiene permiso de escritura, `setBrightness` lanzara `PermissionDeniedException`.
  - `getBrightness` no requiere permiso especial.
- `increment`/`decrement` usan paso de `(255 * 5 / 100)` ≈ 13 unidades nativas (equivalente a 5 en escala 0–100).
- `streamBrightness` usa polling cada 250 ms con `Timer.periodic`.
- **Alternativa considerada:** `WindowManager.LayoutParams.screenBrightness` controla solo la ventana actual (0.0–1.0). Se descarta para mantener paridad con las demas plataformas que controlan el brillo del sistema.

#### iOS — FFI + UIScreen.main.brightness

- Implementacion nativa en `ios/Classes/device_screen_brightness.m` (Objective-C).
- **Lectura:** `[UIScreen mainScreen].brightness` devuelve `CGFloat` en **0.0–1.0**.
- **Escritura:** `[UIScreen mainScreen].brightness = scalar`. Apple **si** proporciona API publica para escribir el brillo (a diferencia del volumen).
- **Normalizacion:** C: `brightness * 100` (lectura), `value / 100.0` (escritura).
- `increment`/`decrement` usan paso de 5 (sobre escala 0–100).
- La escritura debe ejecutarse en el **main thread** — usar `dispatch_sync(dispatch_get_main_queue(), ...)` cuando se llame desde otro hilo.
- **Framework:** `UIKit` (ya incluido por defecto en plugins iOS).
- **Nota:** El brillo cambiado desde la app se resetea cuando el usuario bloquea la pantalla o ajusta el brillo manualmente desde el Control Center.

#### macOS — FFI + IOKit (IODisplayGetFloatParameter)

- Implementacion nativa en `macos/Classes/device_screen_brightness.m` (Objective-C).
- Usa `IOKit.framework` para acceder al display principal.
- **Lectura:**
  1. Obtener el display principal: `CGMainDisplayID()`.
  2. Obtener el servicio IOKit: `IOServicePortFromCGDisplayID(displayID)` o iterar sobre `IOServiceGetMatchingServices` con `IODisplayConnect`.
  3. `IODisplayGetFloatParameter(service, kNilOptions, kIODisplayBrightnessKey, &brightness)` — devuelve `float` en **0.0–1.0**.
- **Escritura:**
  1. `IODisplaySetFloatParameter(service, kNilOptions, kIODisplayBrightnessKey, scalar)`.
- **Normalizacion:** C: `brightness * 100` (lectura), `value / 100.0` (escritura).
- `increment`/`decrement` usan paso de 5.
- **Frameworks del podspec:** `IOKit`, `CoreGraphics`.
- **Limitacion:** Solo funciona con displays integrados (MacBooks) o monitores que soporten DDC/CI. Para displays externos sin DDC, devuelve `DV_BACKEND_NOT_AVAILABLE`.
- **Compatibilidad:** `IODisplayGetFloatParameter` esta disponible desde macOS 10.9. En macOS 12+ puede requerir privilegios adicionales para escritura.

#### Linux — FFI + sysfs backlight

- Implementacion nativa en `src/device_screen_brightness.c` (seccion `#elif defined(__linux__)`).
- Usa el subsistema **sysfs backlight** del kernel Linux.
- **Lectura:**
  1. Buscar directorio en `/sys/class/backlight/` (primer directorio encontrado, o el preferido tipo `firmware` > `platform` > `raw`).
  2. Leer `/sys/class/backlight/<name>/brightness` (valor entero actual).
  3. Leer `/sys/class/backlight/<name>/max_brightness` (valor maximo).
  4. Normalizar: `(current * 100) / max_brightness`.
- **Escritura:**
  1. Escribir el valor desnormalizado `(value * max_brightness / 100)` a `/sys/class/backlight/<name>/brightness`.
  2. Requiere permisos de escritura en el fichero. Opciones:
     - El usuario pertenece al grupo `video` (configuracion habitual).
     - Regla udev en `/etc/udev/rules.d/` que conceda permisos al grupo `video`.
     - Ejecutar con privilegios elevados.
  3. Si no tiene permisos, devuelve `DSB_PERMISSION_DENIED`.
- `increment`/`decrement` usan paso de 5.
- Si `/sys/class/backlight/` esta vacio o no existe (ej. servidor headless, VM), devuelve `DSB_BACKEND_NOT_AVAILABLE`.
- **Sin dependencias externas de compilacion** (solo syscalls POSIX estandar).
- **Alternativa considerada:** DBus con `org.freedesktop.login1.Session.SetBrightness`. Se descarta para no depender de `libdbus` y mantener el plugin sin dependencias runtime.

#### Windows — FFI + Physical Monitor API (dxva2)

- Implementacion nativa en `src/device_screen_brightness.c` (seccion `#elif defined(_WIN32)`).
- Usa la **Physical Monitor API** de Windows.
- **Lectura:**
  1. `MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY)` para obtener el monitor principal.
  2. `GetPhysicalMonitorsFromHMONITOR(hMonitor, 1, &physMon)`.
  3. `GetMonitorBrightness(physMon.hPhysicalMonitor, &min, &current, &max)`.
  4. Normalizar: `((current - min) * 100) / (max - min)`.
- **Escritura:**
  1. Desnormalizar: `(value * (max - min) / 100) + min`.
  2. `SetMonitorBrightness(physMon.hPhysicalMonitor, nativeValue)`.
  3. `DestroyPhysicalMonitor(physMon.hPhysicalMonitor)` al finalizar.
- `increment`/`decrement` usan paso de 5.
- **Dependencia de compilacion:** `dxva2.lib` (en CMakeLists.txt `target_link_libraries(... PRIVATE dxva2)`).
- **Limitacion:** La Physical Monitor API requiere que el monitor soporte DDC/CI. En monitores que no lo soporten, caer a **WMI** como fallback:
  1. WMI: `WmiMonitorBrightness` (get) / `WmiMonitorBrightnessMethods.WmiSetBrightness` (set).
  2. WMI solo funciona para pantallas de laptop integradas.
  3. Si ambos fallan, devuelve `DSB_BACKEND_NOT_AVAILABLE`.
- **Headers:** `<physicalmonitorenumerationapi.h>`, `<highlevelmonitorconfigurationapi.h>`.
- Los GUIDs necesarios (si los hay) se definiran con macro `DSB_DEFINE_GUID` y prefijo `DSB_` igual que en `device_volume`.

### Matriz tecnologica

| Plataforma | Tecnologia | Framework/API nativo | Rango nativo | Normalizacion |
| --- | --- | --- | --- | --- |
| Android | JNIgen | Settings.System.SCREEN_BRIGHTNESS | 0–255 | Dart: `(value / 255 * 100).round()` |
| iOS | FFI + FFIgen | UIScreen.mainScreen.brightness | 0.0–1.0 | C: `brightness * 100` |
| macOS | FFI + FFIgen | IOKit (IODisplayGetFloatParameter) | 0.0–1.0 | C: `brightness * 100` |
| Linux | FFI + FFIgen | sysfs `/sys/class/backlight/` | 0–max_brightness | C: `(current * 100) / max` |
| Windows | FFI + FFIgen | Physical Monitor API (dxva2) / WMI | min–max (tipicamente 0–100) | C: `((cur-min)*100)/(max-min)` |

### Contrato FFI

Mismo patron que `device_volume` con prefijo `DSB_`:

```c
#ifndef DEVICE_SCREEN_BRIGHTNESS_H
#define DEVICE_SCREEN_BRIGHTNESS_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

// ── Error codes ─────────────────────────────────────────────────────────────

#define DSB_OK                     0
#define DSB_UNSUPPORTED_OPERATION  1
#define DSB_PERMISSION_DENIED      2
#define DSB_NATIVE_FAILURE         3
#define DSB_INVALID_VALUE          4
#define DSB_BACKEND_NOT_AVAILABLE  5

// ── Result struct ───────────────────────────────────────────────────────────

typedef struct {
  int32_t value;       // Brillo normalizado 0–100
  int32_t min;         // Siempre 0
  int32_t max;         // Siempre 100
  int32_t reserved;    // Reservado (0). En device_volume era is_muted.
  int32_t error_code;  // DSB_OK o codigo de error
} DeviceScreenBrightnessResult;

// ── Public API ──────────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void);

#endif // DEVICE_SCREEN_BRIGHTNESS_H
```

> **Diferencias con el contrato de `device_volume`:**
> - No hay parametro `channel` (el brillo es un recurso unico).
> - No hay parametro `show_system_ui` (no aplica para brillo).
> - El campo `is_muted` se renombra a `reserved` (no hay concepto de mute en brillo).
> - Las funciones `_get`, `_increment`, `_decrement` no reciben parametros.

### Implementacion nativa C por plataforma

El archivo `src/device_screen_brightness.c` contiene las implementaciones para Android (stubs), Linux y Windows separadas por `#if defined(...)`. iOS y macOS se implementan en archivos `.m` dentro de `ios/Classes/` y `macos/Classes/` respectivamente, ya que necesitan frameworks de Objective-C.

```c
// Patron identico a device_volume:
#if defined(__ANDROID__)
  // Stubs que devuelven DSB_UNSUPPORTED_OPERATION
  // El control real se hace via JNIgen en Dart
#elif defined(__linux__)
  // sysfs backlight: read/write /sys/class/backlight/*/brightness
#elif defined(_WIN32)
  // Physical Monitor API: dxva2 GetMonitorBrightness/SetMonitorBrightness
#endif
```

### Generacion de codigo

- **FFIgen:** genera `lib/device_screen_brightness_bindings_generated.dart` desde `src/device_screen_brightness.h`. Configurado en `ffigen.yaml`.
- **JNIgen:** genera wrappers Dart internos para `Settings.System`, `ContentResolver` y clases auxiliares Android.
- Los artefactos generados se versionan en el repositorio.

### Build nativo (CMakeLists.txt)

`src/CMakeLists.txt` compila `device_screen_brightness.c` como biblioteca compartida:

- **Android:** flag `-Wl,-z,max-page-size=16384` para soporte de paginas de 16 KB (Android 15).
- **Windows:** enlaza `dxva2` (Physical Monitor API).
- **Linux:** sin dependencias externas (solo syscalls POSIX para leer/escribir sysfs).
- **iOS/macOS:** gestionados por CocoaPods con los `.m` de `Classes/`.

```cmake
cmake_minimum_required(VERSION 3.10)
project(device_screen_brightness_library VERSION 0.0.1 LANGUAGES C)

add_library(device_screen_brightness SHARED "device_screen_brightness.c")

set_target_properties(device_screen_brightness PROPERTIES
  PUBLIC_HEADER device_screen_brightness.h
  OUTPUT_NAME "device_screen_brightness"
)

target_compile_definitions(device_screen_brightness PUBLIC DART_SHARED_LIB)

if (ANDROID)
  target_link_options(device_screen_brightness PRIVATE "-Wl,-z,max-page-size=16384")
elseif(WIN32)
  target_link_libraries(device_screen_brightness PRIVATE dxva2)
  # No se enlaza uuid — los GUIDs se definen explicitamente con DSB_DEFINE_GUID
endif()
# Linux: no necesita dependencias externas (sysfs es POSIX puro)
```

## Comportamiento funcional

### Reglas generales

- Todos los valores se normalizan a 0–100 en la capa nativa (C/Obj-C) o en el backend Dart (Android).
- `setBrightness`/`setBrightnessCompute` validan que `value` este en 0–100 y lanzan `InvalidBrightnessValueException` fuera de rango.
- `increment`/`decrement` usan un paso de 5 unidades (sobre escala 0–100) en todas las plataformas.
- `streamBrightness` emite el valor actual inmediatamente al suscribirse y luego emite solo cuando el valor cambia (polling cada 250 ms con `Timer.periodic`).
- Si una plataforma no soporta una operacion, la API falla con una excepcion especifica.

### Soporte por plataforma

| Plataforma | getBrightness | setBrightness | increment/decrement | streamBrightness | Notas |
| --- | --- | --- | --- | --- | --- |
| Android | ✅ | ✅ | ✅ | ✅ | Requiere permiso `WRITE_SETTINGS` para escritura |
| iOS | ✅ | ✅ | ✅ | ✅ | UIScreen.brightness (lectura y escritura publicas) |
| macOS | ✅ | ✅ | ✅ | ✅ | IOKit (solo displays integrados o con DDC/CI) |
| Linux | ✅ | ✅ | ✅ | ✅ | sysfs backlight (requiere permisos grupo `video`) |
| Windows | ✅ | ✅ | ✅ | ✅ | Physical Monitor API / WMI fallback |

### Limitaciones conocidas por plataforma

| Plataforma | Limitacion |
| --- | --- |
| Android | `WRITE_SETTINGS` es un permiso especial que el usuario concede manualmente. La app debe abrir la pantalla de ajustes si no lo tiene. |
| iOS | El brillo configurado por la app se resetea cuando el usuario bloquea la pantalla o lo ajusta manualmente. |
| macOS | No funciona con monitores externos que no soporten DDC/CI. Solo displays integrados (MacBooks) o monitores DDC/CI. |
| Linux | Requiere que el usuario pertenezca al grupo `video` o equivalente. Servidores headless/VMs no tendran backlight. |
| Windows | Physical Monitor API requiere DDC/CI. El fallback WMI solo funciona en laptops con pantalla integrada. |

## Manejo de errores

### Jerarquia de excepciones

Identica en estructura a `device_volume`, con nombres adaptados:

```dart
abstract class DeviceScreenBrightnessException implements Exception {
  final String code;
  final String message;
  final Map<String, Object?> details;
  const DeviceScreenBrightnessException(this.code, this.message, [this.details = const {}]);

  @override
  String toString() {
    final buffer = StringBuffer('DeviceScreenBrightnessException($code): $message');
    if (details.isNotEmpty) {
      buffer.write(' | details: $details');
    }
    return buffer.toString();
  }
}

final class UnsupportedOperationException extends DeviceScreenBrightnessException {
  const UnsupportedOperationException({required String message, Map<String, Object?> details = const {}})
      : super('unsupported_operation', message, details);
}

final class InvalidBrightnessValueException extends DeviceScreenBrightnessException {
  const InvalidBrightnessValueException({required String message, Map<String, Object?> details = const {}})
      : super('invalid_brightness_value', message, details);
}

final class NativeBackendException extends DeviceScreenBrightnessException {
  const NativeBackendException({required String message, Map<String, Object?> details = const {}})
      : super('native_backend_failure', message, details);
}

final class BrightnessObservationException extends DeviceScreenBrightnessException {
  const BrightnessObservationException({required String message, Map<String, Object?> details = const {}})
      : super('brightness_observation_failure', message, details);
}

final class BackendNotAvailableException extends DeviceScreenBrightnessException {
  const BackendNotAvailableException({required String message, Map<String, Object?> details = const {}})
      : super('backend_not_available', message, details);
}

final class PermissionDeniedException extends DeviceScreenBrightnessException {
  const PermissionDeniedException({required String message, Map<String, Object?> details = const {}})
      : super('permission_denied', message, details);
}
```

### Mapeo de codigos nativos C → excepciones Dart

| `error_code` C | Excepcion Dart |
| --- | --- |
| `DSB_OK` (0) | — (exito) |
| `DSB_UNSUPPORTED_OPERATION` (1) | `UnsupportedOperationException` |
| `DSB_PERMISSION_DENIED` (2) | `PermissionDeniedException` |
| `DSB_NATIVE_FAILURE` (3) | `NativeBackendException` |
| `DSB_INVALID_VALUE` (4) | `InvalidBrightnessValueException` |
| `DSB_BACKEND_NOT_AVAILABLE` (5) | `BackendNotAvailableException` |

La validacion de rango 0–100 se realiza en dos niveles: en la fachada Dart (`DeviceScreenBrightness.setBrightness`) **y** en la capa nativa C.

## Tests

Seguir el mismo patron de 3 archivos de test de `device_volume`:

| Archivo | Cobertura |
| --- | --- |
| `test/exceptions_test.dart` | Todas las excepciones: codigos, toString, details, validacion de fachada (rechaza <0 y >100) |
| `test/ffi_backend_error_test.dart` | Mapeo de codigo de error C → tipo de excepcion Dart, constantes del header |

> Nota: no se necesita `volume_state_test.dart` porque no hay modelo intermedio. Si se necesita algun test adicional de normalizacion del backend Android, crear `test/android_normalization_test.dart`.

## Preparacion para pub.dev

### Metadatos (`pubspec.yaml`)

```yaml
name: device_screen_brightness
description: >-
  Control the screen brightness from Flutter. Provides getBrightness,
  setBrightness, incrementBrightness, decrementBrightness and
  streamBrightness with synchronous and compute-based async variants.
  Uses JNIgen on Android and FFI + FFIgen on iOS, macOS, Linux and Windows.
version: 0.1.0
homepage: https://github.com/arcas0803/device_screen_brightness
repository: https://github.com/arcas0803/device_screen_brightness
issue_tracker: https://github.com/arcas0803/device_screen_brightness/issues
topics:
  - brightness
  - screen
  - ffi
  - platform

environment:
  sdk: ^3.11.3
  flutter: ">=3.3.0"

dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.1.8
  jni: ^1.0.0

dev_dependencies:
  ffi: ^2.2.0
  ffigen: ^20.1.1
  jnigen: ^0.16.0
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      android:
        ffiPlugin: true
      ios:
        ffiPlugin: true
      macos:
        ffiPlugin: true
      windows:
        ffiPlugin: true
      linux:
        ffiPlugin: true
```

### Podspecs

#### iOS (`ios/device_screen_brightness.podspec`)

```ruby
Pod::Spec.new do |s|
  s.name             = 'device_screen_brightness'
  s.version          = '0.0.1'
  s.summary          = 'Control screen brightness from Flutter via FFI.'
  s.description      = <<-DESC
Flutter FFI plugin for reading and writing the screen brightness on iOS
using UIScreen.mainScreen.brightness.
                       DESC
  s.homepage         = 'https://github.com/arcas0803/device_screen_brightness'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ArcasHH' => 'alvaroarcasgarcia@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'UIKit'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
```

#### macOS (`macos/device_screen_brightness.podspec`)

```ruby
Pod::Spec.new do |s|
  s.name             = 'device_screen_brightness'
  s.version          = '0.0.1'
  s.summary          = 'Control screen brightness from Flutter via FFI.'
  s.description      = <<-DESC
Flutter FFI plugin for reading and writing the screen brightness on macOS
using IOKit (IODisplayGetFloatParameter).
                       DESC
  s.homepage         = 'https://github.com/arcas0803/device_screen_brightness'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ArcasHH' => 'alvaroarcasgarcia@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.11'
  s.frameworks       = 'IOKit', 'CoreGraphics'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
```

### ffigen.yaml

```yaml
name: DeviceScreenBrightnessBindings
description: Bindings for device_screen_brightness native library.
output: 'lib/device_screen_brightness_bindings_generated.dart'
headers:
  entry-points:
    - 'src/device_screen_brightness.h'
```

### Android — permisos (AndroidManifest.xml)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.arcas0803.device_screen_brightness">
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
</manifest>
```

## CI/CD

### CI de validacion — `.github/workflows/ci.yml`

Identico a `device_volume`. Se ejecuta en cada `push` y `pull_request` a `main`/`master`. 4 jobs:

```yaml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install dependencies
        run: flutter pub get
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .
      - name: Analyze project source
        run: flutter analyze --fatal-infos

  dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install dependencies
        run: flutter pub get
      - name: Publish dry run
        run: flutter pub publish --dry-run

  build-linux:
    runs-on: ubuntu-latest
    needs: analyze
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install Linux desktop dependencies
        run: |
          sudo apt-get update -y
          sudo apt-get install -y \
            clang cmake ninja-build pkg-config \
            libgtk-3-dev liblzma-dev
      # Nota: NO se necesita libpulse-dev (a diferencia de device_volume)
      # Linux brightness usa sysfs puro, sin dependencias externas.
      - name: Install dependencies
        run: flutter pub get
        working-directory: example
      - name: Build Linux
        run: flutter build linux --release
        working-directory: example

  build-windows:
    runs-on: windows-latest
    needs: analyze
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install dependencies
        run: flutter pub get
        working-directory: example
      - name: Build Windows
        run: flutter build windows --release
        working-directory: example
```

### CD de despliegue — `.github/workflows/publish.yml`

Identico a `device_volume`. Se ejecuta al pushear un tag que coincida con `v[0-9]+.[0-9]+.[0-9]+*`.

```yaml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'

jobs:
  publish:
    permissions:
      id-token: write  # OIDC authentication
    uses: dart-lang/setup-dart/.github/workflows/publish.yml@v1
```

- Usa el **reusable workflow oficial de Dart** (`dart-lang/setup-dart`) con autenticacion OIDC.
- **Trusted Publisher** a configurar en pub.dev para `arcas0803/device_screen_brightness` con patron de tag `v*`.
- **No requiere secretos manuales** — la autenticacion se realiza via token OIDC de GitHub Actions.

### Configuracion de Trusted Publisher en pub.dev

Antes de la primera publicacion automatizada:

1. Publicar la primera version manualmente con `flutter pub publish`.
2. Ir a <https://pub.dev/packages/device_screen_brightness/admin>.
3. En "Automated publishing" → "Add a GitHub Actions publisher":
   - **Repository:** `arcas0803/device_screen_brightness`
   - **Tag pattern:** `v*`
4. Guardar.

### Flujo de release

1. Actualizar `version` en `pubspec.yaml`.
2. Documentar cambios en `CHANGELOG.md`.
3. Commit y push a `main`.
4. Crear tag: `git tag v<version>`.
5. Push del tag: `git push origin v<version>`.
6. GitHub Actions ejecuta `publish.yml` automaticamente → pub.dev.

## Estructura de archivos del proyecto

```
device_screen_brightness/
├── .github/workflows/
│   ├── ci.yml                                           # CI: analyze, dry-run, build-linux, build-windows
│   └── publish.yml                                      # CD: pub.dev via Trusted Publisher OIDC
├── src/
│   ├── device_screen_brightness.h                       # Contrato C: struct + funciones + error codes
│   ├── device_screen_brightness.c                       # Impl nativa: Android stubs, Linux sysfs, Windows dxva2
│   └── CMakeLists.txt                                   # Build nativo: dxva2 (Win)
├── ios/
│   ├── device_screen_brightness.podspec                 # CocoaPods: UIKit
│   └── Classes/
│       ├── device_screen_brightness.c                   # Forwarder (placeholder)
│       └── device_screen_brightness.m                   # Obj-C: UIScreen.brightness
├── macos/
│   ├── device_screen_brightness.podspec                 # CocoaPods: IOKit + CoreGraphics
│   └── Classes/
│       ├── device_screen_brightness.c                   # Forwarder (placeholder)
│       └── device_screen_brightness.m                   # Obj-C: IODisplayGetFloatParameter
├── windows/
│   └── CMakeLists.txt                                   # Incluye src/ como subdirectorio
├── android/
│   ├── build.gradle
│   └── src/main/AndroidManifest.xml                     # WRITE_SETTINGS permission
├── lib/
│   ├── device_screen_brightness.dart                    # Fachada publica (API int 0–100)
│   ├── device_screen_brightness_bindings_generated.dart  # FFIgen bindings
│   └── src/
│       ├── backends/
│       │   ├── device_screen_brightness_backend.dart    # Contrato abstracto
│       │   ├── backend_selector.dart                    # Seleccion por Platform.*
│       │   ├── ffi_backend.dart                         # Backend FFI (iOS/macOS/Linux/Win)
│       │   └── android_backend.dart                     # Backend JNIgen (Android)
│       ├── compute/
│       │   └── device_screen_brightness_compute.dart    # Wrappers Flutter.compute
│       ├── exceptions/
│       │   └── device_screen_brightness_exception.dart  # 6 excepciones tipadas
│       └── jni/                                         # Clases JNIgen generadas
├── test/
│   ├── exceptions_test.dart
│   └── ffi_backend_error_test.dart
├── example/                                             # App de ejemplo con UI: slider de brillo + valor %
│   └── lib/main.dart
├── pubspec.yaml
├── ffigen.yaml
├── CHANGELOG.md
├── README.md
├── LICENSE                                              # MIT
└── analysis_options.yaml
```

## Diferencias respecto a device_volume

| Aspecto | device_volume | device_screen_brightness |
| --- | --- | --- |
| Recurso controlado | Volumen de audio | Brillo de pantalla |
| Parametro `channel` | Si (6 canales: media, ring, alarm...) | No (recurso unico del display) |
| Parametro `showSystemUi` | Si | No |
| Campo `is_muted` en struct C | Si | `reserved` (siempre 0) |
| iOS escritura | MPVolumeView off-screen (UISlider) | `UIScreen.mainScreen.brightness` (API publica) |
| macOS backend | CoreAudio + AudioToolbox | IOKit (IODisplayGetFloatParameter) |
| Linux backend | PulseAudio (`libpulse`) | sysfs backlight (sin dependencias) |
| Linux dependencia build | `libpulse-dev` | Ninguna |
| Windows backend | WASAPI (IAudioEndpointVolume) | Physical Monitor API (dxva2) / WMI |
| Windows dependencia build | `ole32` | `dxva2` |
| Android backend | AudioManager (JNIgen) | Settings.System (JNIgen) |
| Android permiso | Ninguno especial | `WRITE_SETTINGS` (permiso especial) |
| Android rango nativo | Variable (ej. 0–15) | 0–255 |

## Criterios de aceptacion

- [ ] La API publica expone `getBrightness`, `setBrightness`, `incrementBrightness`, `decrementBrightness`, `streamBrightness` y homologos Compute.
- [ ] Todos los valores de brillo normalizados a int 0–100.
- [ ] Android soporta lectura y escritura via JNIgen + Settings.System.
- [ ] iOS soporta lectura y escritura via UIScreen.brightness.
- [ ] macOS soporta la API completa via IOKit.
- [ ] Linux soporta la API completa via sysfs backlight.
- [ ] Windows soporta la API completa via Physical Monitor API / WMI.
- [ ] Las excepciones publicas derivan de `Exception` con mensajes especificos.
- [ ] `flutter pub publish --dry-run` limpio.
- [ ] Publicacion automatizada mediante tag + Trusted Publisher OIDC.
- [ ] CI valida formato, analisis, dry-run y builds nativos (Linux, Windows).
