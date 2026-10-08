import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/episode_entity.dart';
import '../bloc/feed_bloc.dart';
import 'episode_info_overlay.dart';
import 'heart_animation_overlay.dart';
import 'paywall_overlay_widget.dart';
import 'progress_bar_widget.dart';
import 'shimmer_skeleton.dart';

class EpisodePlayerWidget extends StatefulWidget {
  final EpisodeEntity episode;
  final bool isActive;
  final bool isPaywallActive;
  final bool isPaywallUnlocked;
  final VoidCallback? onVideoCompleted;

  const EpisodePlayerWidget({
    super.key,
    required this.episode,
    required this.isActive,
    required this.isPaywallActive,
    required this.isPaywallUnlocked,
    this.onVideoCompleted,
  });

  @override
  State<EpisodePlayerWidget> createState() => _EpisodePlayerWidgetState();
}

class _EpisodePlayerWidgetState extends State<EpisodePlayerWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likeCount = 0;
  Offset? _doubleTapPosition;
  bool _isPaused = false;
  bool _hasAutoAdvanced = false;
  late bool _isMuted;

  // Global mute state shared across all episodes — mute on one stays muted on all
  static bool _globalMuted = false; // ignore: prefer_final_fields

  final GlobalKey<HeartAnimationOverlayState> _heartKey = GlobalKey();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _infoSlideController;
  late Animation<Offset> _infoSlideAnimation;
  late Animation<double> _infoFadeAnimation;

  late AnimationController _pauseIconController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _likeCount = 12400 + widget.episode.id * 345;
    _isMuted = _globalMuted;

    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.videoFadeInDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _infoSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _infoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _infoSlideController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    _infoFadeAnimation = CurvedAnimation(
      parent: _infoSlideController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _pauseIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (!widget.isPaywallActive) {
      _initController();
    }
  }

  @override
  void didUpdateWidget(EpisodePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPaywallActive && !widget.isPaywallActive) {
      if (!_isInitialized) {
        _initController();
      } else {
        _controller?.play();
        setState(() => _isPaused = false);
      }
    }

    if (!oldWidget.isActive && widget.isActive) {
      if (_isInitialized && !widget.isPaywallActive) {
        _controller?.play();
        setState(() => _isPaused = false);
      }
    }

    if (oldWidget.isActive && !widget.isActive) {
      _controller?.pause();
    }
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.episode.videoUrl),
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      controller.addListener(_onVideoPositionChanged);
      setState(() => _isInitialized = true);

      _fadeController.forward();
      _infoSlideController.forward();

      if (widget.isActive && !widget.isPaywallActive) {
        await controller.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPositionChanged);
    _controller?.dispose();
    _fadeController.dispose();
    _infoSlideController.dispose();
    _pauseIconController.dispose();
    super.dispose();
  }

  void _onVideoPositionChanged() {
    final controller = _controller;
    if (controller == null || _hasAutoAdvanced) return;
    if (!controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Auto-advance when video reaches the end
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 300)) {
      _hasAutoAdvanced = true;
      widget.onVideoCompleted?.call();
    }
  }

  void _onSingleTap() {
    if (!_isInitialized || widget.isPaywallActive) return;
    final controller = _controller;
    if (controller == null) return;

    HapticFeedback.lightImpact();

    if (controller.value.isPlaying) {
      controller.pause();
      setState(() => _isPaused = true);
    } else {
      controller.play();
      setState(() => _isPaused = false);
    }
    _pauseIconController.forward(from: 0);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    final pos = _doubleTapPosition;
    if (pos == null) return;
    _heartKey.currentState?.addHeart(pos);
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        _likeCount++;
      });
    }
  }

  void _handleSeek(Duration position) {
    _controller?.seekTo(position);
  }

  void _handleUnlock() {
    context.read<FeedBloc>().add(const PaywallUnlockRequested());
  }

  void _showFancySnackbar(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
  ) {
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).size.height * 0.12,
          left: 20,
          right: 20,
        ),
        duration: const Duration(milliseconds: 1800),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFE63946), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'WIP',
                  style: TextStyle(
                    color: Color(0xFFE63946),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Poster gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.episode.posterGradientColorValues
                    .map((v) => Color(v))
                    .toList(),
              ),
            ),
          ),

          // Video or shimmer
          if (!_isInitialized)
            const ShimmerSkeleton()
          else
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildVideoLayer(),
            ),

          // Buffering indicator
          if (_isInitialized && (_controller?.value.isBuffering ?? false))
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: const CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2.5,
                ),
              ),
            ),

          // Gesture layer
          if (!widget.isPaywallActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onSingleTap,
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: _onDoubleTap,
                child: const SizedBox.expand(),
              ),
            ),

          // Cinematic pause/play indicator
          if (_isInitialized && !widget.isPaywallActive)
            _CinematicPauseIndicator(
              controller: _pauseIconController,
              isPaused: _isPaused,
            ),

          // Heart animations
          Positioned.fill(
            child: HeartAnimationOverlay(key: _heartKey),
          ),

          // Episode info + actions
          if (_isInitialized && !widget.isPaywallActive)
            SlideTransition(
              position: _infoSlideAnimation,
              child: FadeTransition(
                opacity: _infoFadeAnimation,
                child: EpisodeInfoOverlay(
                  episode: widget.episode,
                  isLiked: _isLiked,
                  likeCount: _likeCount,
                  isMuted: _isMuted,
                  bottomPadding: bottomPadding,
                  onLikeTap: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                  },
                  onCommentTap: () {
                    HapticFeedback.lightImpact();
                    _showFancySnackbar(
                      context,
                      Icons.mode_comment_rounded,
                      'Comments coming soon',
                      'This feature is under development',
                    );
                  },
                  onShareTap: () {
                    HapticFeedback.lightImpact();
                    _showFancySnackbar(
                      context,
                      Icons.share_rounded,
                      'Share coming soon',
                      'This feature is under development',
                    );
                  },
                  onMuteTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isMuted = !_isMuted;
                      _globalMuted = _isMuted;
                    });
                    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
                  },
                ),
              ),
            ),

          // Progress bar — sits above the system nav bar with breathing room
          if (_isInitialized && !widget.isPaywallActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + 8,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, value, _) {
                  return ProgressBarWidget(
                    position: value.position,
                    duration: value.duration,
                    onSeek: _handleSeek,
                  );
                },
              ),
            ),

          // Paywall overlay
          if (widget.isPaywallActive)
            PaywallOverlayWidget(
              episode: widget.episode,
              onUnlock: _handleUnlock,
            ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    final controller = _controller!;
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
              // Expanding ring
              Opacity(
                opacity: ringOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: ringScale.clamp(0.5, 2.0),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Icon
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
                      isPaused
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
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
