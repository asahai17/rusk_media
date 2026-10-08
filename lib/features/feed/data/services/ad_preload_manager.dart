import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

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

// NativeAd preloader with timeout, retry, and proper lifecycle.
// Uses NativeAd.fromAdManagerRequest with NativeTemplateStyle for rich
// styled ads that fill the screen properly (headline, body, CTA, icon).
class AdPreloadManager {
  final Map<String, ValueNotifier<AdSlotState>> _states = {};
  final Map<String, NativeAd> _pending = {};
  final Map<String, Timer> _timeouts = {};
  final StreamController<String> _failures = StreamController.broadcast();
  final StreamController<String> _successes = StreamController.broadcast();
  bool _disposed = false;

  Stream<String> get failures => _failures.stream;
  Stream<String> get successes => _successes.stream;

  // Widget-facing: get the current state of a slot
  ValueListenable<AdSlotState> stateOf(String slotId) => _notifier(slotId);

  // Load ads for given slot IDs (skips already-loading/loaded)
  void load(Iterable<String> slotIds) {
    if (_disposed) return;
    for (final id in slotIds) {
      _load(id);
    }
  }

  // Get loaded NativeAd for widget display
  NativeAd? getLoadedAd(String slotId) {
    final state = _states[slotId]?.value;
    if (state is AdSlotLoaded) return state.ad;
    return null;
  }

  bool isLoaded(String slotId) => _states[slotId]?.value is AdSlotLoaded;
  bool isFailed(String slotId) => _states[slotId]?.value is AdSlotFailed;

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
    for (final notifier in _states.values) {
      final state = notifier.value;
      if (state is AdSlotLoaded) state.ad.dispose();
      notifier.dispose();
    }
    _states.clear();
    unawaited(_failures.close());
    unawaited(_successes.close());
  }

  ValueNotifier<AdSlotState> _notifier(String slotId) =>
      _states.putIfAbsent(slotId, () => ValueNotifier(const AdSlotIdle()));

  void _load(String slotId) {
    final notifier = _notifier(slotId);
    if (notifier.value is! AdSlotIdle) return; // already loading or done
    notifier.value = const AdSlotLoading();

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
          notifier.value = AdSlotLoaded(ad);
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
    _notifier(slotId).value = AdSlotFailed(reason);
    _failures.add(slotId);
  }

  // Dark native template matching our dark theme
  static final NativeTemplateStyle _templateStyle = NativeTemplateStyle(
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
}
