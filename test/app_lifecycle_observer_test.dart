import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/core/lifecycle/app_lifecycle_observer.dart';

void main() {
  late int pauses;
  late int resumes;
  late AppLifecycleObserver observer;

  setUp(() {
    pauses = 0;
    resumes = 0;
    observer = AppLifecycleObserver(
      onPause: () => pauses++,
      onResume: () => resumes++,
    );
  });

  test('inactive is ignored so the notification shade keeps playback', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(pauses, 0);
    expect(resumes, 0);
  });

  test('hidden then paused reports one pause; resumed reports one resume', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(pauses, 1);

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(resumes, 0, reason: 'inactive on the way back is not a resume');
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumes, 1);
  });

  test('resumed without a prior pause is a no-op', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumes, 0);
  });

  test('detached pauses too', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    expect(pauses, 1);
  });
}
