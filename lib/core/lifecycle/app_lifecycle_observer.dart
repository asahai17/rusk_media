import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Pauses video on background, resumes on foreground.
// Manages wakelock so screen stays on during playback.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({required this.onPause, required this.onResume});

  final VoidCallback onPause;
  final VoidCallback onResume;
  bool _wasPaused = false;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Notification shade — keep playing (matches TikTok behavior)
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_wasPaused) {
          _wasPaused = true;
          onPause();
        }
      case AppLifecycleState.resumed:
        if (_wasPaused) {
          _wasPaused = false;
          onResume();
        }
    }
  }
}
