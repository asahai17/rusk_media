import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';

const _kOnboardingSeenKey = 'md_tv_onboarding_seen';

// Shows once on first launch. Holds video playback while visible.
// Persists via SharedPreferences so it never shows again.
class OnboardingSheet extends StatefulWidget {
  final VoidCallback onDismiss;

  const OnboardingSheet({super.key, required this.onDismiss});

  // Returns true if onboarding should be shown
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kOnboardingSeenKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeenKey, true);
  }

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _overlayFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _overlayFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    HapticFeedback.mediumImpact();
    await OnboardingSheet.markSeen();
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Dark overlay
        Positioned.fill(
          child: FadeTransition(
            opacity: _overlayFade,
            child: GestureDetector(
              onTap: _dismiss,
              child: ColoredBox(color: Colors.black.withAlpha(140)),
            ),
          ),
        ),

        // Bottom sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPadding + 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF151520),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Walkthrough MD Television',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tips
                    _TipRow(number: 1, text: 'Swipe up to binge the next episode'),
                    const SizedBox(height: 18),
                    _TipRow(number: 2, text: 'Double tap to show some love'),
                    const SizedBox(height: 18),
                    _TipRow(number: 3, text: 'One tap to pause, one tap to play'),
                    const SizedBox(height: 18),
                    _TipRow(number: 4, text: 'Slide the seekbar to jump in time'),
                    const SizedBox(height: 18),
                    _TipRow(number: 5, text: 'Hit the speaker to go silent'),
                    const SizedBox(height: 18),
                    _TipRow(number: 6, text: 'Unlock Episode 7 to finish the story'),
                    const SizedBox(height: 30),

                    // CTA
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(27),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(80),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Start watching',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final int number;
  final String text;

  const _TipRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xDDFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
