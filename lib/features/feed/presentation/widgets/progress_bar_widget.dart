import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';

/// The seek bar bound to a controller, sitting above the system nav bar.
/// Only this subtree rebuilds on position ticks.
class EpisodeSeekBar extends StatelessWidget {
  final VideoPlayerController controller;
  final double bottomPadding;

  const EpisodeSeekBar({
    super.key,
    required this.controller,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding + 8,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (_, value, _) => ProgressBarWidget(
          position: value.position,
          duration: value.duration,
          onSeek: controller.seekTo,
        ),
      ),
    );
  }
}

class ProgressBarWidget extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const ProgressBarWidget({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget>
    with TickerProviderStateMixin {
  // ValueNotifiers instead of setState — only repaints the CustomPaint, not the widget tree
  final ValueNotifier<double> _dragProgress = ValueNotifier(0);
  final ValueNotifier<double> _dragLocalX = ValueNotifier(0);
  final ValueNotifier<bool> _isDragging = ValueNotifier(false);

  late AnimationController _expandController;
  late Animation<double> _heightAnimation;
  late Animation<double> _thumbAnimation;

  late AnimationController _tooltipController;
  late Animation<double> _tooltipOpacity;

  static const double _horizontalPadding = 12.0;
  static const double _collapsedHeight = 3.5;
  static const double _expandedHeight = 6.0;
  static const double _collapsedThumb = 4.0;
  static const double _expandedThumb = 8.0;
  static const double _hitTargetHeight = 44.0;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _heightAnimation = Tween<double>(
      begin: _collapsedHeight,
      end: _expandedHeight,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));
    _thumbAnimation = Tween<double>(
      begin: _collapsedThumb,
      end: _expandedThumb,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));

    _tooltipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tooltipOpacity = CurvedAnimation(
      parent: _tooltipController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _tooltipController.dispose();
    _dragProgress.dispose();
    _dragLocalX.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  double get _currentProgress {
    if (_isDragging.value) return _dragProgress.value;
    if (widget.duration.inMilliseconds == 0) return 0;
    return widget.position.inMilliseconds / widget.duration.inMilliseconds;
  }

  Duration get _previewPosition {
    if (widget.duration.inMilliseconds == 0) return Duration.zero;
    return Duration(
      milliseconds:
          (_dragProgress.value * widget.duration.inMilliseconds).round(),
    );
  }

  RenderBox? get _renderBox {
    final obj = context.findRenderObject();
    return obj is RenderBox ? obj : null;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    final box = _renderBox;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final trackWidth = box.size.width - _horizontalPadding * 2;
    final trackX = localPos.dx - _horizontalPadding;

    HapticFeedback.selectionClick();

    _isDragging.value = true;
    _dragProgress.value = (trackX / trackWidth).clamp(0.0, 1.0);
    _dragLocalX.value = localPos.dx.clamp(0, box.size.width);
    _expandController.forward();
    _tooltipController.forward();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final box = _renderBox;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final trackWidth = box.size.width - _horizontalPadding * 2;
    final trackX = localPos.dx - _horizontalPadding;

    // Only update ValueNotifiers — no setState, no widget rebuild
    _dragProgress.value = (trackX / trackWidth).clamp(0.0, 1.0);
    _dragLocalX.value = localPos.dx.clamp(0, box.size.width);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    HapticFeedback.lightImpact();

    widget.onSeek(Duration(
      milliseconds:
          (_dragProgress.value * widget.duration.inMilliseconds).round(),
    ));
    _isDragging.value = false;
    _expandController.reverse();
    _tooltipController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: SizedBox(
          height: _hitTargetHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Progress track — repaints via Listenable.merge, never rebuilds widget
              AnimatedBuilder(
                animation: Listenable.merge([
                  _expandController,
                  _dragProgress,
                  _isDragging,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(double.infinity, _heightAnimation.value),
                    painter: _ProgressTrackPainter(
                      progress: _currentProgress.clamp(0.0, 1.0),
                      barHeight: _heightAnimation.value,
                      thumbRadius: _thumbAnimation.value,
                      isDragging: _isDragging.value,
                    ),
                  );
                },
              ),
              // Time preview tooltip
              ValueListenableBuilder<bool>(
                valueListenable: _isDragging,
                builder: (context, dragging, _) {
                  if (!dragging) return const SizedBox.shrink();
                  return Positioned(
                    bottom: _hitTargetHeight - 4,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _tooltipOpacity,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _dragLocalX,
                        builder: (context, localX, child) {
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Transform.translate(
                              offset: Offset(
                                (localX -
                                        _horizontalPadding -
                                        (screenWidth -
                                                _horizontalPadding * 2) /
                                            2)
                                    .clamp(
                                  -(screenWidth / 2 - 60),
                                  screenWidth / 2 - 60,
                                ),
                                0,
                              ),
                              child: _TimePreviewBubble(
                                position: _previewPosition,
                                total: widget.duration,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTrackPainter extends CustomPainter {
  final double progress;
  final double barHeight;
  final double thumbRadius;
  final bool isDragging;

  const _ProgressTrackPainter({
    required this.progress,
    required this.barHeight,
    required this.thumbRadius,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final trackRadius = barHeight / 2;

    final trackPaint = Paint()
      ..color = AppColors.progressTrack
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - trackRadius, size.width, barHeight),
        Radius.circular(trackRadius),
      ),
      trackPaint,
    );

    if (progress <= 0) return;

    final progressWidth = size.width * progress;

    final progressPaint = Paint()
      ..color = AppColors.progressFill
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - trackRadius, progressWidth, barHeight),
        Radius.circular(trackRadius),
      ),
      progressPaint,
    );

    if (isDragging) {
      final glowPaint = Paint()
        ..color = AppColors.primary.withAlpha(60)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        Offset(progressWidth, y),
        thumbRadius + 4,
        glowPaint,
      );
    }

    final thumbPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(progressWidth, y),
      thumbRadius,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.isDragging != isDragging;
  }
}

class _TimePreviewBubble extends StatelessWidget {
  final Duration position;
  final Duration total;

  const _TimePreviewBubble({
    required this.position,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
      ),
      child: Text(
        '${DurationFormatter.format(position)} / ${DurationFormatter.format(total)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
