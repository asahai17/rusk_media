import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_constants.dart';
import 'ad_preloader.dart';

// Sealed state machine for each ad slot: idle → loading → loaded | failed
sealed class AdSlotState {
  const AdSlotState();
}

final class AdSlotIdle extends AdSlotState {
  const AdSlotIdle();
}

final class AdSlotLoading extends AdSlotState {
  const AdSlotLoading();
}

final class AdSlotLoaded extends AdSlotState {
  const AdSlotLoaded(this.ad);
  final NativeAd ad;
}

final class AdSlotFailed extends AdSlotState {
  const AdSlotFailed(this.reason);
  final String reason;
}

// NativeAd preloader with timeout and proper lifecycle.
// Uses NativeAd.fromAdManagerRequest with the injected NativeTemplateStyle so
// this layer knows nothing about the app's colours or Material.
//
// Owned by the FeedBloc (registered as a factory in DI), so its lifetime is
// exactly the lifetime of one feed session.
class AdPreloadManager implements AdPreloader {
  AdPreloadManager({required this._templateStyle});

  final NativeTemplateStyle _templateStyle;
  final Map<String, AdSlotState> _states = {};
  final Map<String, NativeAd> _pending = {};
  final Map<String, Timer> _timeouts = {};
  final StreamController<String> _failures = StreamController.broadcast();
  final StreamController<String> _successes = StreamController.broadcast();
  bool _disposed = false;

  @override
  Stream<String> get failures => _failures.stream;

  @override
  Stream<String> get successes => _successes.stream;

  @override
  void load(Iterable<String> slotIds) {
    if (_disposed) return;
    for (final id in slotIds) {
      _load(id);
    }
  }

  @override
  NativeAd? getLoadedAd(String slotId) {
    final state = _states[slotId];
    if (state is AdSlotLoaded) return state.ad;
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    for (final ad in _pending.values) {
      ad.dispose();
    }
    _pending.clear();
    for (final state in _states.values) {
      if (state is AdSlotLoaded) state.ad.dispose();
    }
    _states.clear();
    unawaited(_failures.close());
    unawaited(_successes.close());
  }

  void _load(String slotId) {
    final current = _states[slotId] ?? const AdSlotIdle();
    if (current is! AdSlotIdle) return; // already loading, loaded or failed
    _states[slotId] = const AdSlotLoading();

    late final NativeAd ad;
    ad = NativeAd.fromAdManagerRequest(
      adUnitId: AppConstants.adUnitForSlot(slotId),
      adManagerRequest: const AdManagerAdRequest(),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(startMuted: true),
      ),
      nativeTemplateStyle: _templateStyle,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (_disposed || !identical(_pending[slotId], ad)) return;
          _pending.remove(slotId);
          _timeouts.remove(slotId)?.cancel();
          _states[slotId] = AdSlotLoaded(ad);
          _successes.add(slotId);
        },
        onAdFailedToLoad: (_, error) {
          if (_disposed || !identical(_pending[slotId], ad)) return;
          _fail(slotId, 'code ${error.code}: ${error.message}');
        },
      ),
    );

    _pending[slotId] = ad;
    _timeouts[slotId] = Timer(
      AppConstants.adLoadTimeout,
      () => _fail(slotId, 'timeout'),
    );
    ad.load();
  }

  void _fail(String slotId, String reason) {
    if (_disposed) return;
    _timeouts.remove(slotId)?.cancel();
    _pending.remove(slotId)?.dispose();
    _states[slotId] = AdSlotFailed(reason);
    debugPrint('ad slot $slotId failed: $reason');
    _failures.add(slotId);
  }
}
