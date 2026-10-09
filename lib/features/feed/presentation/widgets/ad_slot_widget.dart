import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_colors.dart';
import 'shimmer_skeleton.dart';

/// Dark native template matching the app theme. Lives with the ad page so
/// the data layer never imports Material or AppColors.
final NativeTemplateStyle nativeAdTemplateStyle = NativeTemplateStyle(
  templateType: TemplateType.medium,
  mainBackgroundColor: const Color(0xFF141420),
  cornerRadius: 16,
  callToActionTextStyle: NativeTemplateTextStyle(
    textColor: Colors.white,
    backgroundColor: AppColors.primary,
    style: NativeTemplateFontStyle.bold,
    size: 15,
  ),
  primaryTextStyle: NativeTemplateTextStyle(
    textColor: Colors.white,
    style: NativeTemplateFontStyle.bold,
    size: 15,
  ),
  secondaryTextStyle: NativeTemplateTextStyle(
    textColor: const Color(0xAAFFFFFF),
    size: 13,
  ),
  tertiaryTextStyle: NativeTemplateTextStyle(
    textColor: const Color(0x88FFFFFF),
    size: 12,
  ),
);

// Full-screen native ad page in the PageView.
// Uses NativeAd with NativeTemplateStyle for rich styled ad content.
// Never places AdWidget under Opacity or Transform (Android native view rule).
//
// Failure is not handled here: a failed slot is removed from the feed by the
// bloc, so this widget only ever sees "still loading" (null) or a loaded ad.
class AdSlotWidget extends StatefulWidget {
  final NativeAd? ad;

  const AdSlotWidget({super.key, required this.ad});

  @override
  State<AdSlotWidget> createState() => _AdSlotWidgetState();
}

class _AdSlotWidgetState extends State<AdSlotWidget>
    with AutomaticKeepAliveClientMixin {
  // A NativeAd is bound to one AdWidget; keeping the page alive avoids
  // re-mounting the platform view every time it scrolls into view.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ad = widget.ad;
    if (ad == null) return const ShimmerSkeleton();
    return _LoadedAdPage(ad: ad);
  }
}

class _LoadedAdPage extends StatelessWidget {
  final NativeAd ad;

  const _LoadedAdPage({required this.ad});

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
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
