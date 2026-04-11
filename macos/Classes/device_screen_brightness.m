// macOS brightness implementation.
//
// Uses the private DisplayServices framework to control the brightness of
// built-in Apple displays (MacBook, iMac, Apple Studio Display, Pro Display XDR).
// Third-party external monitors are NOT supported — any call on such a setup
// returns DSB_BACKEND_NOT_AVAILABLE.

#import "../../src/device_screen_brightness.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

// ── Helpers ─────────────────────────────────────────────────────────────────

static DeviceScreenBrightnessResult dsb_ok(int32_t value) {
  DeviceScreenBrightnessResult r = {value, 0, 100, 0, DSB_OK};
  return r;
}

static DeviceScreenBrightnessResult dsb_error(int32_t code) {
  DeviceScreenBrightnessResult r = {0, 0, 0, 0, code};
  return r;
}

// ── Backend ─────────────────────────────────────────────────────────────────

typedef enum { BK_NONE = 0, BK_DISPLAY_SERVICES } dsb_mac_bk_t;

static dsb_mac_bk_t s_bk     = BK_NONE;
static bool          s_probed = false;

// ── DisplayServices (private framework) ─────────────────────────────────────

typedef int  (*DS_GetBrFn)(CGDirectDisplayID, float *);
typedef int  (*DS_SetBrFn)(CGDirectDisplayID, float);
typedef bool (*DS_CanChFn)(CGDirectDisplayID);

static DS_GetBrFn s_ds_get = NULL;
static DS_SetBrFn s_ds_set = NULL;
static DS_CanChFn s_ds_can = NULL;

// ── Probe (runs once on first API call) ─────────────────────────────────────

static void dsb_probe(void) {
  if (s_probed) return;
  s_probed = true;

  CGDirectDisplayID disp = CGMainDisplayID();

  void *ds = dlopen(
      "/System/Library/PrivateFrameworks/DisplayServices.framework/"
      "DisplayServices",
      RTLD_LAZY);
  if (!ds) return;

  s_ds_get = (DS_GetBrFn)dlsym(ds, "DisplayServicesGetBrightness");
  s_ds_set = (DS_SetBrFn)dlsym(ds, "DisplayServicesSetBrightness");
  s_ds_can = (DS_CanChFn)dlsym(ds, "DisplayServicesCanChangeBrightness");

  if (s_ds_get && s_ds_set && s_ds_can && s_ds_can(disp)) {
    s_bk = BK_DISPLAY_SERVICES;
  }
}

// ── Public API ──────────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  dsb_probe();
  if (s_bk != BK_DISPLAY_SERVICES) return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  float val = 0;
  if (s_ds_get(CGMainDisplayID(), &val) != 0)
    return dsb_error(DSB_NATIVE_FAILURE);
  return dsb_ok((int32_t)(val * 100.0f + 0.5f));
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  if (value < 0 || value > 100) return dsb_error(DSB_INVALID_VALUE);
  dsb_probe();
  if (s_bk != BK_DISPLAY_SERVICES) return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  float scalar = value / 100.0f;
  if (s_ds_set(CGMainDisplayID(), scalar) != 0)
    return dsb_error(DSB_NATIVE_FAILURE);
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
