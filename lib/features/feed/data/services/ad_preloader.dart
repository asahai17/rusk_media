import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Contract the feed depends on for ad preloading.
///
/// Keeping the BLoC behind an interface (instead of the concrete
/// [AdPreloadManager]) lets unit tests drive success/failure without the
/// Google Mobile Ads SDK.
abstract interface class AdPreloader {
  /// Emits a slot id each time its ad finishes loading.
  Stream<String> get successes;

  /// Emits a slot id each time its ad fails, returns no fill, or times out.
  Stream<String> get failures;

  /// Starts loading the given slots. Slots already loading or loaded are
  /// skipped, so calling this repeatedly with overlapping windows is cheap.
  void load(Iterable<String> slotIds);

  /// The loaded ad for a slot, or null if it is not (yet) loaded.
  NativeAd? getLoadedAd(String slotId);

  /// Releases every ad and timer. The preloader is unusable afterwards.
  void dispose();
}
