import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/episode_player_pool.dart';
import 'shimmer_skeleton.dart';

/// The picture layer of an episode page: poster gradient, then the shimmer,
/// the retry card or the video, plus the buffering ring. Owns no state.
class EpisodeVideoSurface extends StatelessWidget {
  final VideoPlayerController? controller;
  final EpisodePlayerStatus? status;
  final Animation<double> fadeAnimation;
  final List<int> posterGradientColorValues;

  /// False while the surface is hidden behind the paywall or paused by the
  /// user, so the ring never shows over a still frame.
  final bool showBuffering;
  final VoidCallback onRetry;

  const EpisodeVideoSurface({
    super.key,
    required this.controller,
    required this.status,
    required this.fadeAnimation,
    required this.posterGradientColorValues,
    required this.showBuffering,
    required this.onRetry,
  });

  /// Marks the buffering ring so tests can find it.
  static const Key bufferingKey = Key('episode-buffering');

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final isReady = status == EpisodePlayerStatus.ready && controller != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: posterGradientColorValues.map((v) => Color(v)).toList(),
            ),
          ),
        ),

        if (status == EpisodePlayerStatus.error)
          _LoadErrorState(onRetry: onRetry)
        else if (!isReady)
          const ShimmerSkeleton()
        else
          FadeTransition(
            opacity: fadeAnimation,
            child: _VideoLayer(controller: controller),
          ),

        // Driven by the controller, so it tracks isBuffering instead of
        // waiting for an unrelated rebuild.
        if (isReady && showBuffering)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.isBuffering
                ? const _BufferingPulse(key: bufferingKey)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _VideoLayer extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

/// Shown when the network source cannot be initialised.
class _LoadErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.white.withAlpha(140),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            "Couldn't load this episode",
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRetry();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded buffering indicator: a soft pulsing ring, no Material spinner.
class _BufferingPulse extends StatefulWidget {
  const _BufferingPulse({super.key});

  @override
  State<_BufferingPulse> createState() => _BufferingPulseState();
}

class _BufferingPulseState extends State<_BufferingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Container(
            width: 40 + 24 * t,
            height: 40 + 24 * t,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withAlpha((200 * (1 - t)).round()),
                width: 2,
              ),
            ),
          );
        },
      ),
    );
  }
}
