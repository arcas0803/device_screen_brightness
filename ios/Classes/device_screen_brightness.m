// iOS implementation using UIScreen.mainScreen.brightness.
//
// Apple provides a public API for reading and writing the screen brightness
// on iOS via UIScreen.mainScreen.brightness (0.0–1.0).
//
// The brightness set by the app resets when the user locks the screen or
// adjusts brightness manually from Control Center.

#import "../../src/device_screen_brightness.h"
#import <UIKit/UIKit.h>

// ── Helpers ─────────────────────────────────────────────────────────────────

static DeviceScreenBrightnessResult dsb_error(int32_t code) {
  DeviceScreenBrightnessResult r = {0, 0, 0, 0, code};
  return r;
}

// ── Public API ──────────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  DeviceScreenBrightnessResult r = {0, 0, 100, 0, DSB_OK};

  __block float brightness = 0;
  if ([NSThread isMainThread]) {
    brightness = (float)[UIScreen mainScreen].brightness;
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{
      brightness = (float)[UIScreen mainScreen].brightness;
    });
  }

  r.value = (int32_t)(brightness * 100.0f + 0.5f);
  return r;
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  if (value < 0 || value > 100) return dsb_error(DSB_INVALID_VALUE);

  float scalar = value / 100.0f;
  if ([NSThread isMainThread]) {
    [UIScreen mainScreen].brightness = scalar;
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{
      [UIScreen mainScreen].brightness = scalar;
    });
  }

  // Small yield so the brightness value reflects the change.
  [NSThread sleepForTimeInterval:0.05];
  return device_screen_brightness_get();
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value + 5;
  if (next > 100) next = 100;
  return device_screen_brightness_set(next);
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value - 5;
  if (next < 0) next = 0;
  return device_screen_brightness_set(next);
}
