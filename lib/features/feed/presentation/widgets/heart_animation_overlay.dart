import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class HeartAnimationOverlay extends StatefulWidget {
  const HeartAnimationOverlay({super.key});

  @override
  State<HeartAnimationOverlay> createState() => HeartAnimationOverlayState();
}

class HeartAnimationOverlayState extends State<HeartAnimationOverlay> {
  final List<_HeartEntry> _hearts = [];
  int _idCounter = 0;

  void addHeart(Offset position) {
    HapticFeedback.lightImpact();
    final id = _idCounter++;
    setState(() {
      _hearts.add(_HeartEntry(id: id, position: position));
    });
  }

  void _removeHeart(int id) {
    if (mounted) {
      setState(() => _hearts.removeWhere((e) => e.id == id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: _hearts
          .map(
            (entry) => _HeartBurst(
              key: ValueKey(entry.id),
              position: entry.position,
              onComplete: () => _removeHeart(entry.id),
            ),
          )
          .toList(),
    );
  }
}

class _HeartEntry {
  final int id;
  final Offset position;
  _HeartEntry({required this.id, required this.position});
}

class _HeartBurst extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _HeartBurst({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with TickerProviderStateMixin {
  /// Timeline for rise, fade, rotation and the satellites.
  late AnimationController _controller;

  /// Scale pop: an unbounded controller driven by a real spring, so the
  /// overshoot and settle come from physics rather than a hand-drawn curve.
  late AnimationController _scaleController;
  late List<_SatelliteData> _satellites;

  final _rng = math.Random();
  late final double _rotDir;

  // Under-damped (ratio ≈ 0.45): overshoots to ~1.2 then settles at 1.
  static const SpringDescription _popSpring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 12,
  );

  @override
  void initState() {
    super.initState();
    _rotDir = _rng.nextBool() ? 1.0 : -1.0;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleController = AnimationController.unbounded(vsync: this)
      ..animateWith(SpringSimulation(_popSpring, 0.0, 1.0, 18.0));

    // Generate 3 satellite mini-hearts
    _satellites = List.generate(3, (_) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final distance = 40.0 + _rng.nextDouble() * 35;
      return _SatelliteData(
        dx: math.cos(angle) * distance,
        dy: math.sin(angle) * distance - 30,
        rotation: (_rng.nextDouble() - 0.5) * 0.8,
        size: 18.0 + _rng.nextDouble() * 10,
        delay: _rng.nextDouble() * 0.15,
      );
    });

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Opacity is clamped before it reaches the Opacity widget, which is the
  // only place an overshooting value would throw.

  /// Spring value, eased down by a quarter while the heart rises and fades.
  double _mainScale(double t) {
    final settle = t < 0.5 ? 1.0 : 1.0 - 0.25 * ((t - 0.5) / 0.5);
    return _scaleController.value * settle;
  }

  double _mainOpacity(double t) {
    if (t < 0.1) return t / 0.1;
    if (t < 0.6) return 1.0;
    return 1.0 - ((t - 0.6) / 0.4);
  }

  double _mainRise(double t) {
    if (t < 0.15) return 0;
    return -100.0 * Curves.easeOutCubic.transform((t - 0.15) / 0.85);
  }

  double _mainRotation(double t) {
    if (t < 0.25) return _rotDir * 0.15 * (t / 0.25);
    if (t < 0.5) return _rotDir * (0.15 - 0.2 * ((t - 0.25) / 0.25));
    return _rotDir * -0.05 * (1.0 - ((t - 0.5) / 0.5));
  }

  double _glowOpacity(double t) {
    if (t < 0.2) return 0.7 * (t / 0.2);
    return 0.7 * (1.0 - ((t - 0.2) / 0.8));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _scaleController]),
      builder: (context, _) {
        final t = _controller.value.clamp(0.0, 1.0);
        final rise = _mainRise(t);
        final opacity = _mainOpacity(t).clamp(0.0, 1.0);
        final scale = _mainScale(t).clamp(0.0, 2.0);
        final rotation = _mainRotation(t);
        final glow = _glowOpacity(t).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Glow
            Positioned(
              left: widget.position.dx - 40,
              top: widget.position.dy - 40 + rise,
              child: Opacity(
                opacity: glow,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66FF3B5C),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main heart
            Positioned(
              left: widget.position.dx - 30,
              top: widget.position.dy - 30 + rise,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Transform.rotate(
                    angle: rotation,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.heartRed,
                      size: 60,
                      shadows: [
                        Shadow(
                          color: Color(0x88FF3B5C),
                          blurRadius: 24,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Satellites
            for (final sat in _satellites) _buildSatellite(sat, t, rise),
          ],
        );
      },
    );
  }

  Widget _buildSatellite(_SatelliteData sat, double t, double mainRise) {
    final effectiveT = ((t - sat.delay) / (1.0 - sat.delay)).clamp(0.0, 1.0);
    if (effectiveT <= 0) return const SizedBox.shrink();

    final curve = Curves.easeOutCubic.transform(effectiveT);
    final fadeCurve = effectiveT < 0.5 ? 1.0 : 1.0 - ((effectiveT - 0.5) / 0.5);
    final scale = effectiveT < 0.2
        ? effectiveT / 0.2
        : 1.0 - ((effectiveT - 0.2) / 0.8) * 0.4;

    return Positioned(
      left: widget.position.dx - sat.size / 2 + sat.dx * curve,
      top: widget.position.dy - sat.size / 2 + sat.dy * curve + mainRise * 0.5,
      child: Opacity(
        opacity: fadeCurve.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale.clamp(0.0, 2.0),
          child: Transform.rotate(
            angle: sat.rotation * curve,
            child: Icon(
              Icons.favorite_rounded,
              color: AppColors.heartRed,
              size: sat.size,
              shadows: const [Shadow(color: Color(0x44FF3B5C), blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }
}

class _SatelliteData {
  final double dx;
  final double dy;
  final double rotation;
  final double size;
  final double delay;

  const _SatelliteData({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.size,
    required this.delay,
  });
}
