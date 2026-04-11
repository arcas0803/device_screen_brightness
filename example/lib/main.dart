import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _brightness = 0;
  BrightnessMode _mode = BrightnessMode.system;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = DeviceScreenBrightness.streamBrightness(mode: _mode).listen(
      (value) => setState(() => _brightness = value),
      onError: (Object e) => debugPrint('Stream error: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _setBrightness(double value) {
    try {
      final result = DeviceScreenBrightness.setBrightness(
        value.toInt(),
        mode: _mode,
      );
      setState(() => _brightness = result);
    } on DeviceScreenBrightnessException catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _switchMode(BrightnessMode mode) {
    setState(() => _mode = mode);
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Screen Brightness')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_brightness %',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _brightness.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '$_brightness',
                  onChanged: _setBrightness,
                ),
                const SizedBox(height: 16),
                if (Platform.isAndroid) ...[
                  SegmentedButton<BrightnessMode>(
                    segments: const [
                      ButtonSegment(
                        value: BrightnessMode.app,
                        label: Text('App'),
                        icon: Icon(Icons.phone_android),
                      ),
                      ButtonSegment(
                        value: BrightnessMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.settings),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => _switchMode(s.first),
                  ),
                  const SizedBox(height: 16),
                  if (_mode == BrightnessMode.system)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (!DeviceScreenBrightness.hasPermission()) {
                            DeviceScreenBrightness.requestPermission();
                          }
                        },
                        icon: const Icon(Icons.security),
                        label: const Text('Request WRITE_SETTINGS'),
                      ),
                    ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        try {
                          final v = DeviceScreenBrightness.decrementBrightness(
                            mode: _mode,
                          );
                          setState(() => _brightness = v);
                        } on DeviceScreenBrightnessException catch (e) {
                          debugPrint('Error: $e');
                        }
                      },
                      child: const Text('−'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        try {
                          final v = DeviceScreenBrightness.incrementBrightness(
                            mode: _mode,
                          );
                          setState(() => _brightness = v);
                        } on DeviceScreenBrightnessException catch (e) {
                          debugPrint('Error: $e');
                        }
                      },
                      child: const Text('+'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
