import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// "Unlock Episode" CTA button with a continuous shimmer light sweep every 3 seconds.
/// The shimmer sweeps across in the first ~1s then pauses for ~2s to draw attention.
class ShimmerCtaButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const ShimmerCtaButton({
    super.key,
    required this.onTap,
    this.label = 'Unlock Episode',
  });

  @override
  State<ShimmerCtaButton> createState() => _ShimmerCtaButtonState();
}

class _ShimmerCtaButtonState extends State<ShimmerCtaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.shimmerSweepDuration, // 3 seconds
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Shimmer sweeps across in the first 30% of the 3-second cycle
          final sweepProgress = _controller.value <= 0.3
              ? _controller.value / 0.3
              : 1.0;

          final shimmerStart = sweepProgress * 2.5 - 1.5;
          final shimmerEnd = shimmerStart + 0.8;

          return Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [AppColors.primary, const Color(0xFFB5182A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66E63946),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  child!,
                  // Shimmer sweep overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(shimmerStart, -0.5),
                          end: Alignment(shimmerEnd, 0.5),
                          colors: [
                            Colors.transparent,
                            AppColors.shimmerButtonHighlight.withAlpha(100),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
