import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:md_television/core/constants/app_constants.dart';
import 'package:md_television/features/feed/data/services/ad_preloader.dart';
import 'package:md_television/features/feed/domain/entities/episode_entity.dart';
import 'package:md_television/features/feed/domain/entities/feed_item.dart';
import 'package:md_television/features/feed/domain/repositories/feed_repository.dart';

String urlOf(int episodeId) => 'https://example.com/$episodeId.mp4';

EpisodeEntity episode(int id) => EpisodeEntity(
  id: id,
  title: 'E$id',
  description: '',
  videoUrl: urlOf(id),
  posterGradientColorValues: const [0xFF000000, 0xFF000000],
);

/// 'E1 E2 E3 AD E4 ...' for readable feed assertions.
String describeFeed(List<FeedItem> items) => items
    .map(
      (item) => switch (item) {
        EpisodeFeedItem(:final episode) => 'E${episode.id}',
        AdFeedItem() => 'AD',
      },
    )
    .join(' ');

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({this.episodeCount = AppConstants.totalEpisodes});

  final int episodeCount;

  @override
  List<FeedItem> getFeedItems() => List.generate(
    episodeCount,
    (i) => EpisodeFeedItem(episode: episode(i + 1)),
  );
}

/// Drives ad success and failure by hand; never touches the Ads SDK.
class FakeAdPreloader implements AdPreloader {
  final _successes = StreamController<String>.broadcast();
  final _failures = StreamController<String>.broadcast();
  final List<String> requested = [];
  final Map<String, NativeAd> _loaded = {};
  bool disposed = false;

  @override
  Stream<String> get successes => _successes.stream;
  @override
  Stream<String> get failures => _failures.stream;

  @override
  void load(Iterable<String> slotIds) => requested.addAll(slotIds);

  @override
  NativeAd? getLoadedAd(String slotId) => _loaded[slotId];

  @override
  void dispose() {
    disposed = true;
    _successes.close();
    _failures.close();
  }

  /// Marks the slot loaded with an unloaded NativeAd stand-in (constructing
  /// one never touches the SDK; only load() does).
  void succeed(String id) {
    _loaded[id] = NativeAd(
      adUnitId: 'fake/$id',
      factoryId: 'fake',
      listener: NativeAdListener(),
      request: const AdRequest(),
    );
    _successes.add(id);
  }

  void fail(String id) => _failures.add(id);
}
