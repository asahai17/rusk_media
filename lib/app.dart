import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'features/feed/presentation/bloc/feed_bloc.dart';
import 'features/feed/presentation/pages/feed_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';

class MDTelevisionApp extends StatelessWidget {
  const MDTelevisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AppShell(),
    );
  }
}

/// Manages the splash → feed transition.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  bool _splashComplete = false;

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _splashComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return SplashPage(onComplete: _onSplashComplete);
    }

    return BlocProvider<FeedBloc>(
      create: (_) => sl<FeedBloc>(),
      child: const FeedPage(),
    );
  }
}
