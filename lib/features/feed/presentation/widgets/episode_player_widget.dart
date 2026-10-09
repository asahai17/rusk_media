import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/services/episode_player_pool.dart';
import '../../domain/entities/episode_entity.dart';
import '../bloc/feed_bloc.dart';
import 'episode_gesture_layer.dart';
import 'episode_info_overlay.dart';
import 'episode_video_surface.dart';
import 'paywall_overlay_widget.dart';
import 'progress_bar_widget.dart';
import 'wip_snackbar.dart';

/// One full-screen episode page: composes the video surface, the gesture
/// layer, the info overlay, the seek bar and the paywall.
///
/// Owns no player. It renders whatever controller the [EpisodePlayerPool]
/// holds for its episode and reports gestures to the bloc; the bloc decides
/// what plays, so this widget never calls play or pause.
class EpisodePlayerWidget extends StatefulWidget {
  final EpisodeEntity episode;
  final bool isActive;
  final bool isLocked;
  final EpisodePlayerPool pool;

  const EpisodePlayerWidget({
    super.key,
    required this.episode,
    required this.isActive,
    required this.isLocked,
    required this.pool,
  });

  @override
  State<EpisodePlayerWidget> createState() => _EpisodePlayerWidgetState();
}

class _EpisodePlayerWidgetState extends State<EpisodePlayerWidget>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  EpisodePlayerStatus? _status;
  bool _revealed = false;
  bool _isLiked = false;
  late int _likeCount = 12400 + widget.episode.id * 345;

  late final _fade = AnimationController(
    vsync: this,
    duration: AppConstants.videoFadeInDuration,
  );
  late final _infoSlide = AnimationController(
    vsync: this,
    duration: AppConstants.infoSlideInDuration,
  );
  late final _infoOffset = Tween(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _infoSlide,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    ),
  );
  late final _infoOpacity = CurvedAnimation(
    parent: _infoSlide,
    curve: const Interval(0, 0.5, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    widget.pool.addListener(_onPoolChanged);
    _syncFromPool();
  }

  @override
  void dispose() {
    widget.pool.removeListener(_onPoolChanged);
    _fade.dispose();
    _infoSlide.dispose();
    super.dispose();
  }

  void _onPoolChanged() {
    if (mounted && _syncFromPool()) setState(() {});
  }

  /// Mirrors the pool's controller and status for this episode. Returns true
  /// when something changed.
  bool _syncFromPool() {
    final controller = widget.pool.controllerFor(widget.episode.id);
    final status = widget.pool.statusFor(widget.episode.id);
    if (identical(controller, _controller) && status == _status) return false;

    if (!identical(controller, _controller)) {
      // A new controller (retry, or re-entering the window) reveals afresh.
      _revealed = false;
      _fade.value = 0;
      _infoSlide.value = 0;
    }
    _controller = controller;
    _status = status;

    if (status == EpisodePlayerStatus.ready && !_revealed) {
      _revealed = true;
      _fade.forward();
      _infoSlide.forward();
    }
    return true;
  }

  void _toggleLike({bool onlyLike = false}) {
    if (onlyLike && _isLiked) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FeedBloc>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final controller = _controller;
    final showControls =
        _status == EpisodePlayerStatus.ready &&
        controller != null &&
        !widget.isLocked;
    final isPaused =
        widget.isActive &&
        context.select((FeedBloc bloc) => bloc.state.isUserPaused);
    final isMuted = context.select((FeedBloc bloc) => bloc.state.isMuted);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EpisodeVideoSurface(
            controller: controller,
            status: _status,
            fadeAnimation: _fade,
            posterGradientColorValues: widget.episode.posterGradientColorValues,
            showBuffering: showControls && !isPaused,
            onRetry: () => widget.pool.retry(widget.episode.id),
          ),
          if (showControls) ...[
            EpisodeGestureLayer(
              isPaused: isPaused,
              canTogglePlayback: widget.isActive,
              onTogglePlayback: () => bloc.add(const PlaybackToggled()),
              onLike: () => _toggleLike(onlyLike: true),
            ),
            SlideTransition(
              position: _infoOffset,
              child: FadeTransition(
                opacity: _infoOpacity,
                child: EpisodeInfoOverlay(
                  episode: widget.episode,
                  isLiked: _isLiked,
                  likeCount: _likeCount,
                  isMuted: isMuted,
                  bottomPadding: bottomPadding,
                  onLikeTap: _toggleLike,
                  onCommentTap: () => showWipSnackbar(
                    context,
                    icon: Icons.mode_comment_rounded,
                    title: 'Comments coming soon',
                  ),
                  onShareTap: () => showWipSnackbar(
                    context,
                    icon: Icons.share_rounded,
                    title: 'Share coming soon',
                  ),
                  onMuteTap: () {
                    HapticFeedback.lightImpact();
                    bloc.add(const MuteToggled());
                  },
                ),
              ),
            ),
            EpisodeSeekBar(controller: controller, bottomPadding: bottomPadding),
          ],
          // Tied to the episode's lock state, not to the scroll position, so
          // it never flickers mid-swipe.
          if (widget.isLocked)
            PaywallOverlayWidget(
              episode: widget.episode,
              isActive: widget.isActive,
              onUnlock: () => bloc.add(const PaywallUnlockRequested()),
            ),
        ],
      ),
    );
  }
}
