#include "device_screen_brightness.h"

// This file is compiled by CMake for Android, Linux, and Windows.
// iOS and macOS use separate .m files in their respective Classes/ folders.

// ── Helper ──────────────────────────────────────────────────────────────────

static DeviceScreenBrightnessResult dsb_error(int32_t code) {
  DeviceScreenBrightnessResult r = {0, 0, 0, 0, code};
  return r;
}

// ═══════════════════════════════════════════════════════════════════════════
// ANDROID — stubs (brightness control via JNIgen in Dart, not FFI)
// ═══════════════════════════════════════════════════════════════════════════
#if defined(__ANDROID__)

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  return dsb_error(DSB_UNSUPPORTED_OPERATION);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  return dsb_error(DSB_UNSUPPORTED_OPERATION);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void) {
  return dsb_error(DSB_UNSUPPORTED_OPERATION);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void) {
  return dsb_error(DSB_UNSUPPORTED_OPERATION);
}

// ═══════════════════════════════════════════════════════════════════════════
// LINUX — sysfs backlight
// ═══════════════════════════════════════════════════════════════════════════
#elif defined(__linux__)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>

// Backlight types in preference order: firmware > platform > raw.
static int dsb_type_priority(const char *path) {
  char typepath[512];
  snprintf(typepath, sizeof(typepath), "%s/type", path);
  FILE *f = fopen(typepath, "r");
  if (!f) return 0;
  char buf[32];
  if (!fgets(buf, sizeof(buf), f)) { fclose(f); return 0; }
  fclose(f);
  // Strip trailing newline
  buf[strcspn(buf, "\n")] = '\0';
  if (strcmp(buf, "firmware") == 0) return 3;
  if (strcmp(buf, "platform") == 0) return 2;
  if (strcmp(buf, "raw") == 0) return 1;
  return 0;
}

// Find the best backlight directory. Returns 0 on success, -1 on failure.
static int dsb_find_backlight(char *out, size_t outlen) {
  const char *base = "/sys/class/backlight";
  DIR *dir = opendir(base);
  if (!dir) return -1;

  int best_prio = -1;
  char best[256] = {0};
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL) {
    if (ent->d_name[0] == '.') continue;
    char full[512];
    snprintf(full, sizeof(full), "%s/%s", base, ent->d_name);
    int p = dsb_type_priority(full);
    if (p > best_prio) {
      best_prio = p;
      strncpy(best, ent->d_name, sizeof(best) - 1);
    }
  }
  closedir(dir);

  if (best[0] == '\0') return -1;
  snprintf(out, outlen, "%s/%s", base, best);
  return 0;
}

static int dsb_read_int(const char *path) {
  FILE *f = fopen(path, "r");
  if (!f) return -1;
  int val = 0;
  if (fscanf(f, "%d", &val) != 1) { fclose(f); return -1; }
  fclose(f);
  return val;
}

static int dsb_write_int(const char *path, int val) {
  FILE *f = fopen(path, "w");
  if (!f) {
    if (errno == EACCES) return DSB_PERMISSION_DENIED;
    return DSB_NATIVE_FAILURE;
  }
  if (fprintf(f, "%d", val) < 0) { fclose(f); return DSB_NATIVE_FAILURE; }
  fclose(f);
  return DSB_OK;
}

static DeviceScreenBrightnessResult dsb_linux_query(void) {
  DeviceScreenBrightnessResult r = {0, 0, 100, 0, DSB_OK};
  char bldir[512];
  if (dsb_find_backlight(bldir, sizeof(bldir)) != 0)
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  char path[600];
  snprintf(path, sizeof(path), "%s/max_brightness", bldir);
  int maxb = dsb_read_int(path);
  if (maxb <= 0) return dsb_error(DSB_NATIVE_FAILURE);

  snprintf(path, sizeof(path), "%s/brightness", bldir);
  int cur = dsb_read_int(path);
  if (cur < 0) return dsb_error(DSB_NATIVE_FAILURE);

  r.value = (int32_t)((long)cur * 100 / maxb);
  return r;
}

static DeviceScreenBrightnessResult dsb_linux_set(int32_t value) {
  char bldir[512];
  if (dsb_find_backlight(bldir, sizeof(bldir)) != 0)
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  char path[600];
  snprintf(path, sizeof(path), "%s/max_brightness", bldir);
  int maxb = dsb_read_int(path);
  if (maxb <= 0) return dsb_error(DSB_NATIVE_FAILURE);

  int native_val = (int)((long)value * maxb / 100);
  snprintf(path, sizeof(path), "%s/brightness", bldir);
  int err = dsb_write_int(path, native_val);
  if (err != DSB_OK) return dsb_error(err);

  return dsb_linux_query();
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  return dsb_linux_query();
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  if (value < 0 || value > 100) return dsb_error(DSB_INVALID_VALUE);
  return dsb_linux_set(value);
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value + 5;
  if (next > 100) next = 100;
  return dsb_linux_set(next);
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value - 5;
  if (next < 0) next = 0;
  return dsb_linux_set(next);
}

// ═══════════════════════════════════════════════════════════════════════════
// WINDOWS — Physical Monitor API (dxva2)
// ═══════════════════════════════════════════════════════════════════════════
#elif defined(_WIN32)

#include <windows.h>
#include <physicalmonitorenumerationapi.h>
#include <highlevelmonitorconfigurationapi.h>

static DeviceScreenBrightnessResult dsb_win_query(void) {
  DeviceScreenBrightnessResult r = {0, 0, 100, 0, DSB_OK};

  HMONITOR hMon = MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY);
  if (!hMon) return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  PHYSICAL_MONITOR physMon;
  if (!GetPhysicalMonitorsFromHMONITOR(hMon, 1, &physMon))
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  DWORD dwMin = 0, dwCur = 0, dwMax = 0;
  BOOL ok = GetMonitorBrightness(physMon.hPhysicalMonitor, &dwMin, &dwCur, &dwMax);
  if (!ok || dwMax <= dwMin) {
    DestroyPhysicalMonitor(physMon.hPhysicalMonitor);
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
  }

  r.value = (int32_t)(((long)(dwCur - dwMin) * 100) / (long)(dwMax - dwMin));
  DestroyPhysicalMonitor(physMon.hPhysicalMonitor);
  return r;
}

static DeviceScreenBrightnessResult dsb_win_set(int32_t value) {
  HMONITOR hMon = MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY);
  if (!hMon) return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  PHYSICAL_MONITOR physMon;
  if (!GetPhysicalMonitorsFromHMONITOR(hMon, 1, &physMon))
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);

  DWORD dwMin = 0, dwCur = 0, dwMax = 0;
  BOOL ok = GetMonitorBrightness(physMon.hPhysicalMonitor, &dwMin, &dwCur, &dwMax);
  if (!ok || dwMax <= dwMin) {
    DestroyPhysicalMonitor(physMon.hPhysicalMonitor);
    return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
  }

  DWORD native = (DWORD)((long)value * (long)(dwMax - dwMin) / 100 + dwMin);
  SetMonitorBrightness(physMon.hPhysicalMonitor, native);
  DestroyPhysicalMonitor(physMon.hPhysicalMonitor);

  return dsb_win_query();
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  return dsb_win_query();
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  if (value < 0 || value > 100) return dsb_error(DSB_INVALID_VALUE);
  return dsb_win_set(value);
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value + 5;
  if (next > 100) next = 100;
  return dsb_win_set(next);
}

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void) {
  DeviceScreenBrightnessResult cur = device_screen_brightness_get();
  if (cur.error_code != DSB_OK) return cur;
  int32_t next = cur.value - 5;
  if (next < 0) next = 0;
  return dsb_win_set(next);
}

// ═══════════════════════════════════════════════════════════════════════════
// UNKNOWN PLATFORM
// ═══════════════════════════════════════════════════════════════════════════
#else

FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_get(void) {
  return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_set(int32_t value) {
  return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_increment(void) {
  return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
}
FFI_PLUGIN_EXPORT DeviceScreenBrightnessResult device_screen_brightness_decrement(void) {
  return dsb_error(DSB_BACKEND_NOT_AVAILABLE);
}

#endif

