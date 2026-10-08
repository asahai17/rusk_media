import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/services/ad_preload_manager.dart';
import '../bloc/feed_bloc.dart';
import 'shimmer_skeleton.dart';

// Full-screen native ad page in the PageView.
// Uses NativeAd with NativeTemplateStyle for rich styled ad content.
// Never places AdWidget under Opacity or Transform (Android native view rule).
class AdSlotWidget extends StatefulWidget {
  final String adId;
  final String adUnitId;
  final AdLoadStatus adLoadStatus;
  final PageController pageController;
  final int pageIndex;

  const AdSlotWidget({
    super.key,
    required this.adId,
    required this.adUnitId,
    required this.adLoadStatus,
    required this.pageController,
    required this.pageIndex,
  });

  @override
  State<AdSlotWidget> createState() => _AdSlotWidgetState();
}

class _AdSlotWidgetState extends State<AdSlotWidget>
    with AutomaticKeepAliveClientMixin {
  bool _hasAutoSkipped = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(AdSlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adLoadStatus == AdLoadStatus.failed && !_hasAutoSkipped) {
      _hasAutoSkipped = true;
      _autoSkip();
    }
  }

  void _autoSkip() {
    Future.delayed(AppConstants.adAutoSkipDelay, () {
      if (!mounted) return;
      final nextPage = widget.pageIndex + 1;
      if (widget.pageController.hasClients) {
        widget.pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return switch (widget.adLoadStatus) {
      AdLoadStatus.loading => const ShimmerSkeleton(),
      AdLoadStatus.failed => _buildFailedPage(),
      AdLoadStatus.loaded => _buildLoadedPage(),
    };
  }

  Widget _buildFailedPage() {
    if (!_hasAutoSkipped) {
      _hasAutoSkipped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSkip());
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0x44E63946),
              strokeWidth: 2,
            ),
            SizedBox(height: 12),
            Text(
              'Continuing...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedPage() {
    final ad = sl<AdPreloadManager>().getLoadedAd(widget.adId);
    if (ad == null) return Container(color: Colors.black);

    // Ad sits underneath, loading cover fades off.
    // AdWidget is NEVER placed under Opacity or Transform (Android rule).
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            // Native ad — fills available space inside SafeArea
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              bottom: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AdWidget(ad: ad),
              ),
            ),

            // "Sponsored" pill at top center
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(8)),
                  ),
                  child: const Text(
                    'Sponsored',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            // Swipe hint at bottom
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withAlpha(70),
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Swipe up to continue',
                    style: TextStyle(
                      color: Colors.white.withAlpha(70),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
