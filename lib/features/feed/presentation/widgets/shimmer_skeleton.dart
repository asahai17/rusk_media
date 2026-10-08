import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Cinematic shimmer loading skeleton — appears while video/ad buffers.
/// Features film-grain texture, diagonal shimmer sweep, ghost placeholders
/// matching the episode player layout, and a pulsing brand icon.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({super.key});

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final shimmerPos = t * 2.5 - 0.75;
        // Pulse for brand icon: slow breathe
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);

        return Container(
          color: AppColors.shimmerBase,
          child: Stack(
            children: [
              // Diagonal shimmer sweep
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(shimmerPos - 1.0, -0.3),
                      end: Alignment(shimmerPos + 0.6, 0.3),
                      colors: const [
                        AppColors.shimmerBase,
                        AppColors.shimmerHighlight,
                        AppColors.shimmerBase,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Cinematic film grain (subtle scan lines)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FilmGrainPainter(seed: (t * 100).toInt()),
                  ),
                ),
              ),

              // Ghost layout — matches episode info position
              Positioned(
                bottom: 100,
                left: 16,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // EP badge ghost
                    _GhostRect(
                      width: 48,
                      height: 20,
                      borderRadius: 4,
                      shimmerPos: shimmerPos,
                    ),
                    const SizedBox(height: 10),
                    // Title ghost
                    _GhostRect(
                      width: double.infinity,
                      height: 18,
                      borderRadius: 6,
                      shimmerPos: shimmerPos,
                    ),
                    const SizedBox(height: 8),
                    // Description ghost lines
                    _GhostRect(
                      width: 220,
                      height: 12,
                      borderRadius: 4,
                      shimmerPos: shimmerPos,
                    ),
                    const SizedBox(height: 6),
                    _GhostRect(
                      width: 160,
                      height: 12,
                      borderRadius: 4,
                      shimmerPos: shimmerPos,
                    ),
                  ],
                ),
              ),

              // Right-side action icons ghost
              Positioned(
                right: 14,
                bottom: 130,
                child: Column(
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        children: [
                          _GhostCircle(size: 28, shimmerPos: shimmerPos),
                          const SizedBox(height: 4),
                          _GhostRect(
                            width: 28,
                            height: 8,
                            borderRadius: 4,
                            shimmerPos: shimmerPos,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Progress bar ghost at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 56,
                child: _GhostRect(
                  width: double.infinity,
                  height: 3.5,
                  borderRadius: 2,
                  shimmerPos: shimmerPos,
                ),
              ),

              // Pulsing brand icon center
              Center(
                child: Opacity(
                  opacity: 0.15 + 0.15 * pulse,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.primary.withAlpha(30),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(50),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.primary.withAlpha(150),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'MD Television',
                        style: TextStyle(
                          color: Colors.white.withAlpha(80),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top bar ghost
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GhostRect(
                      width: 100,
                      height: 16,
                      borderRadius: 4,
                      shimmerPos: shimmerPos,
                    ),
                    _GhostRect(
                      width: 56,
                      height: 22,
                      borderRadius: 12,
                      shimmerPos: shimmerPos,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GhostRect extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final double shimmerPos;

  const _GhostRect({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.shimmerPos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(shimmerPos - 1.0, 0),
          end: Alignment(shimmerPos + 0.5, 0),
          colors: const [
            Color(0xFF1E1E35),
            Color(0xFF2A2A50),
            Color(0xFF1E1E35),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _GhostCircle extends StatelessWidget {
  final double size;
  final double shimmerPos;

  const _GhostCircle({required this.size, required this.shimmerPos});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: const [
            Color(0xFF1E1E35),
            Color(0xFF2A2A50),
            Color(0xFF1E1E35),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(shimmerPos - 1.0, 0),
          end: Alignment(shimmerPos + 0.5, 0),
        ),
      ),
    );
  }
}

/// Subtle film grain scan lines for cinematic feel.
class _FilmGrainPainter extends CustomPainter {
  final int seed;

  const _FilmGrainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(4)
      ..strokeWidth = 0.5;

    // Horizontal scan lines every 3px
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_FilmGrainPainter oldDelegate) => false;
}
