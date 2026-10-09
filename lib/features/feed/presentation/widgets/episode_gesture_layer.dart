import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'heart_animation_overlay.dart';

/// Tap and double-tap handling for an episode page, with the pause glyph and
/// the heart burst that go with them. Reports intent upward; decides nothing
/// about playback itself.
class EpisodeGestureLayer extends StatefulWidget {
  /// Drives the glyph: a pause icon while paused, a play icon otherwise.
  final bool isPaused;

  /// Single taps only act on the page the user is looking at.
  final bool canTogglePlayback;
  final VoidCallback onTogglePlayback;
  final VoidCallback onLike;

  const EpisodeGestureLayer({
    super.key,
    required this.isPaused,
    required this.canTogglePlayback,
    required this.onTogglePlayback,
    required this.onLike,
  });

  @override
  State<EpisodeGestureLayer> createState() => _EpisodeGestureLayerState();
}

class _EpisodeGestureLayerState extends State<EpisodeGestureLayer>
    with SingleTickerProviderStateMixin {
  final GlobalKey<HeartAnimationOverlayState> _heartKey = GlobalKey();
  late final AnimationController _pauseIconController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Offset? _doubleTapPosition;

  @override
  void dispose() {
    _pauseIconController.dispose();
    super.dispose();
  }

  void _onSingleTap() {
    if (!widget.canTogglePlayback) return;
    HapticFeedback.lightImpact();
    widget.onTogglePlayback();
    _pauseIconController.forward(from: 0);
  }

  void _onDoubleTap() {
    final pos = _doubleTapPosition;
    if (pos == null) return;
    _heartKey.currentState?.addHeart(pos);
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onSingleTap,
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: _onDoubleTap,
          child: const SizedBox.expand(),
        ),
        _CinematicPauseIndicator(
          controller: _pauseIconController,
          isPaused: widget.isPaused,
        ),
        HeartAnimationOverlay(key: _heartKey),
      ],
    );
  }
}

/// Cinematic pause/play indicator with ring pulse and icon.
class _CinematicPauseIndicator extends StatelessWidget {
  final AnimationController controller;
  final bool isPaused;

  const _CinematicPauseIndicator({
    required this.controller,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;

          // Icon opacity: quick fade in, hold, fade out
          final double iconOpacity;
          if (t < 0.15) {
            iconOpacity = t / 0.15;
          } else if (t < 0.45) {
            iconOpacity = 1.0;
          } else {
            iconOpacity = 1.0 - ((t - 0.45) / 0.55);
          }

          // Icon scale: pop in then settle
          final double iconScale;
          if (t < 0.2) {
            iconScale = 0.6 + 0.6 * Curves.easeOut.transform(t / 0.2);
          } else if (t < 0.4) {
            iconScale = 1.2 - 0.2 * ((t - 0.2) / 0.2);
          } else {
            iconScale = 1.0;
          }

          // Ring expansion
          final double ringScale = 1.0 + 0.5 * Curves.easeOut.transform(t);
          final double ringOpacity;
          if (t < 0.3) {
            ringOpacity = 0.3;
          } else {
            ringOpacity = 0.3 * (1.0 - ((t - 0.3) / 0.7));
          }

          if (iconOpacity <= 0.01) return const SizedBox.shrink();

          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: ringOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: ringScale.clamp(0.5, 2.0),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: iconOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: iconScale.clamp(0.5, 1.5),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
