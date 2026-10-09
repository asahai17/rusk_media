import 'package:flutter/widgets.dart';

// Reports background/foreground transitions to the owner. It decides nothing
// about playback or the wakelock; the player pool owns both.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({required this.onPause, required this.onResume});

  final VoidCallback onPause;
  final VoidCallback onResume;
  bool _wasPaused = false;

  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Notification shade / app switcher peek — keep playing.
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
