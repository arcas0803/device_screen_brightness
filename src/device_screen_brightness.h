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
  int32_t value;       // Brightness normalized 0–100
  int32_t min;         // Always 0
  int32_t max;         // Always 100
  int32_t reserved;    // Reserved (0)
  int32_t error_code;  // DSB_OK or error code
} DeviceScreenBrightnessResult;

// ── Public API ──────────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void);

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void);

#endif // DEVICE_SCREEN_BRIGHTNESS_H
