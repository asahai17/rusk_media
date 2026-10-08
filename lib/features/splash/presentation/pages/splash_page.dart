import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Cinematic in-app splash screen.
/// Staggered animation sequence:
///   0.0-0.3s  → Screen fades in, scan lines appear
///   0.3-0.8s  → Play icon scales in with glow pulse
///   0.6-1.2s  → "MD" slides up + fades in
///   0.8-1.4s  → "Television" slides up + fades in (staggered)
///   1.2-1.8s  → Tagline fades in
///   1.8-2.0s  → Red line expands under tagline
///   2.5-3.0s  → Everything fades out, navigate to feed
class SplashPage extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashPage({super.key, required this.onComplete});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Animation helpers (all values 0.0-1.0 safe) ---

  double _remap(double t, double start, double end) {
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // Phase timings (normalized 0-1 over 3.2s)
          final screenFade = Curves.easeIn.transform(_remap(t, 0.0, 0.1));
          final playIconT = _remap(t, 0.1, 0.35);
          final glowT = _remap(t, 0.1, 0.5);
          final mdT = _remap(t, 0.2, 0.45);
          final tvT = _remap(t, 0.3, 0.55);
          final taglineT = _remap(t, 0.4, 0.6);
          final lineT = _remap(t, 0.55, 0.7);
          final exitT = _remap(t, 0.82, 1.0);

          final exitOpacity = 1.0 - Curves.easeIn.transform(exitT);

          return Opacity(
            opacity: (screenFade * exitOpacity).clamp(0.0, 1.0),
            child: Stack(
              children: [
                // Scan lines
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ScanLinePainter(),
                    ),
                  ),
                ),

                // Cinematic vignette
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withAlpha(60),
                            Colors.black.withAlpha(150),
                          ],
                          stops: const [0.0, 0.4, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Center content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play icon with glow
                      _buildPlayIcon(playIconT, glowT),
                      const SizedBox(height: 32),
                      // Brand text
                      _buildBrandText(mdT, tvT),
                      const SizedBox(height: 12),
                      // Tagline
                      _buildTagline(taglineT),
                      const SizedBox(height: 10),
                      // Accent line
                      _buildAccentLine(lineT),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayIcon(double iconT, double glowT) {
    final scale = iconT < 1.0
        ? Curves.easeOutCubic.transform(iconT)
        : 1.0;
    final glowOpacity = (0.5 * math.sin(glowT * math.pi)).clamp(0.0, 1.0);

    return Transform.scale(
      scale: (0.5 + 0.5 * scale).clamp(0.0, 1.5),
      child: Opacity(
        opacity: scale.clamp(0.0, 1.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient glow
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(
                      (40 + 30 * glowOpacity).toInt(),
                    ),
                    blurRadius: 40 + 20 * glowOpacity,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            // Icon container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withAlpha(30),
                border: Border.all(
                  color: AppColors.primary.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandText(double mdT, double tvT) {
    final mdSlide = 20.0 * (1.0 - Curves.easeOutCubic.transform(mdT));
    final mdOpacity = Curves.easeIn.transform(mdT);
    final tvSlide = 20.0 * (1.0 - Curves.easeOutCubic.transform(tvT));
    final tvOpacity = Curves.easeIn.transform(tvT);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Transform.translate(
          offset: Offset(0, mdSlide),
          child: Opacity(
            opacity: mdOpacity.clamp(0.0, 1.0),
            child: const Text(
              'MD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                shadows: [
                  Shadow(color: Color(0xCC000000), blurRadius: 16),
                  Shadow(color: Color(0x44E63946), blurRadius: 30),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.translate(
          offset: Offset(0, tvSlide),
          child: Opacity(
            opacity: tvOpacity.clamp(0.0, 1.0),
            child: Text(
              'Television',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 20,
                  ),
                  const Shadow(color: Color(0xCC000000), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline(double t) {
    final opacity = Curves.easeIn.transform(t);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(
        'MICRO STORIES. BIG DRAMA.',
        style: TextStyle(
          color: Colors.white.withAlpha(120),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildAccentLine(double t) {
    final width = 120.0 * Curves.easeOutCubic.transform(t);
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(0),
            AppColors.primary.withAlpha(180),
            AppColors.primary.withAlpha(0),
          ],
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(3)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
