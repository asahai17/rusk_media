import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. DI must be ready before anything reads it
  await di.initDependencies();

  // 2. Ads SDK init is non-blocking: queues loads until ready,
  //    splash screen gives it a head start. If it fails, slots timeout (8s).
  unawaited(
    MobileAds.instance.initialize().then<void>(
      (_) {},
      onError: (Object e) => debugPrint('ads sdk init: $e'),
    ),
  );

  // 3. Edge-to-edge + portrait lock (parallel)
  await Future.wait([
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]);

  // 4. Transparent system bars for full-bleed video
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MDTelevisionApp());
}
