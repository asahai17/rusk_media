import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/episode_entity.dart';
import 'shimmer_cta_button.dart';

/// Full-screen paywall overlay for Episode 7.
/// Clean, minimal card design with blurred background.
class PaywallOverlayWidget extends StatefulWidget {
  final EpisodeEntity episode;
  final VoidCallback onUnlock;

  const PaywallOverlayWidget({
    super.key,
    required this.episode,
    required this.onUnlock,
  });

  @override
  State<PaywallOverlayWidget> createState() => _PaywallOverlayWidgetState();
}

class _PaywallOverlayWidgetState extends State<PaywallOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: AppConstants.paywallSlideUpDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    await _slideController.reverse();
    widget.onUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: AppColors.paywallOverlay,
              ),
            ),
          ),
        ),

        // Top branding (visible through blur)
        Positioned(
          top: topPadding + 10,
          left: 16,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'MD',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: const [
                      Shadow(color: Color(0xCC000000), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Television',
                  style: TextStyle(
                    color: AppColors.primary.withAlpha(180),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Episode counter top-right
        Positioned(
          top: topPadding + 12,
          right: 16,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              '${widget.episode.id.toString().padLeft(2, '0')} / ${AppConstants.totalEpisodes.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0x88FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        // Paywall card — clean, minimal design
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: _PaywallCard(
              episode: widget.episode,
              onUnlock: _handleUnlock,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaywallCard extends StatelessWidget {
  final EpisodeEntity episode;
  final VoidCallback onUnlock;

  const _PaywallCard({
    required this.episode,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.fromLTRB(28, 32, 28, bottomPadding + 24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha(15),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Lock icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),

          // Episode label
          Text(
            'E P I S O D E  ${episode.id.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: AppColors.primary.withAlpha(200),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),

          // Headline
          const Text(
            "The story isn't over.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Subtitle
          const Text(
            'Unlock the final chapters and see\nwhat happens next.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // CTA with shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ShimmerCtaButton(
              onTap: onUnlock,
              label: 'Unlock Episode',
            ),
          ),
          const SizedBox(height: 12),

          // Helper text
          const Text(
            'Demo unlock · No payment required',
            style: TextStyle(
              color: AppColors.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Navigation hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withAlpha(60),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Swipe down to revisit earlier chapters',
                style: TextStyle(
                  color: Colors.white.withAlpha(60),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
