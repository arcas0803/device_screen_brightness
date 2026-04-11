package com.example.device_screen_brightness;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;
import android.view.WindowManager;

import java.lang.reflect.Field;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Helper class called from Dart via JNIgen.
 *
 * The Context is obtained in Dart with ActivityThread.currentApplication()
 * and passed through the constructor.
 */
public class DeviceScreenBrightnessHelper {
    private final Context context;

    public DeviceScreenBrightnessHelper(Context context) {
        this.context = context;
    }

    // ── Activity resolution (for app-level brightness) ─────────────────────

    /**
     * Returns the currently resumed Activity via reflection on ActivityThread.
     * Returns null when no resumed Activity is found.
     */
    private Activity getCurrentActivity() {
        try {
            Class<?> atClass = Class.forName("android.app.ActivityThread");
            Object currentThread = atClass.getMethod("currentActivityThread").invoke(null);
            Field field = atClass.getDeclaredField("mActivities");
            field.setAccessible(true);
            @SuppressWarnings("unchecked")
            Map<Object, Object> activities = (Map<Object, Object>) field.get(currentThread);
            if (activities == null) return null;
            for (Object record : activities.values()) {
                Class<?> rc = record.getClass();
                Field pausedField = rc.getDeclaredField("paused");
                pausedField.setAccessible(true);
                if (!pausedField.getBoolean(record)) {
                    Field activityField = rc.getDeclaredField("activity");
                    activityField.setAccessible(true);
                    return (Activity) activityField.get(record);
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    // ── System-level brightness (Settings.System) ──────────────────────────

    /**
     * Reads screen brightness from Settings.System (range 0-255)
     * and normalises to 0-100.
     */
    public int getScreenBrightness() {
        try {
            ContentResolver cr = context.getContentResolver();
            int nativeValue = Settings.System.getInt(cr, Settings.System.SCREEN_BRIGHTNESS);
            return Math.round(nativeValue / 255.0f * 100.0f);
        } catch (Settings.SettingNotFoundException e) {
            throw new RuntimeException("SCREEN_BRIGHTNESS setting not found", e);
        }
    }

    /**
     * Writes screen brightness to Settings.System.
     *
     * @param value brightness in 0-100
     * @return the normalised brightness after writing
     * @throws SecurityException if WRITE_SETTINGS permission is not granted
     */
    public int setScreenBrightness(int value) {
        if (!canWrite()) {
            throw new SecurityException("WRITE_SETTINGS permission not granted");
        }
        int nativeValue = Math.round(value / 100.0f * 255.0f);
        ContentResolver cr = context.getContentResolver();
        Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS, nativeValue);
        return getScreenBrightness();
    }

    // ── App-level brightness (WindowManager.LayoutParams) ──────────────────

    /**
     * Reads the current Activity's window brightness (0-100).
     * Falls back to system brightness if no Activity is available or the
     * window brightness is set to the default (-1).
     */
    public int getAppBrightness() {
        Activity activity = getCurrentActivity();
        if (activity == null) return getScreenBrightness();
        WindowManager.LayoutParams params = activity.getWindow().getAttributes();
        float brightness = params.screenBrightness;
        if (brightness < 0) return getScreenBrightness(); // default → system
        return Math.round(brightness * 100.0f);
    }

    /**
     * Sets the current Activity's window brightness.
     * No special permission is required.
     *
     * @param value brightness in 0-100
     * @return the value that was set
     * @throws RuntimeException if no Activity is available
     */
    public int setAppBrightness(int value) {
        Activity activity = getCurrentActivity();
        if (activity == null) {
            throw new RuntimeException("No foreground Activity available");
        }
        float brightness = value / 100.0f;
        CountDownLatch latch = new CountDownLatch(1);
        activity.runOnUiThread(() -> {
            WindowManager.LayoutParams params = activity.getWindow().getAttributes();
            params.screenBrightness = brightness;
            activity.getWindow().setAttributes(params);
            latch.countDown();
        });
        try {
            latch.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return value;
    }

    // ── Permission helpers ─────────────────────────────────────────────────

    /**
     * Whether the app has the WRITE_SETTINGS special permission.
     */
    public boolean canWrite() {
        return Settings.System.canWrite(context);
    }

    /**
     * Opens the system settings screen where the user can grant
     * the WRITE_SETTINGS permission to this app.
     */
    public void requestPermission() {
        Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
        intent.setData(Uri.parse("package:" + context.getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}