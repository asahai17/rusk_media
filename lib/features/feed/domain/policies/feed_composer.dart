import 'dart:math' as math;

import '../entities/episode_entity.dart';
import '../entities/feed_item.dart';

// Pure Dart policy — no flutter imports. Testable without widget tree.
// Interleaves ad slots into the episode list and decides what to preload
// around the current page.
class FeedComposer {
  const FeedComposer({this.adEvery = 3});
  final int adEvery;

  // Compose feed: E1 E2 E3 [AD] E4 E5 E6 [AD] E7
  // No slot after the last episode.
  List<FeedItem> compose(
    List<EpisodeFeedItem> episodes, {
    Set<String> removed = const {},
  }) {
    final items = <FeedItem>[];
    var slotCounter = 0;

    for (var i = 0; i < episodes.length; i++) {
      items.add(episodes[i]);
      final isLast = i == episodes.length - 1;
      if (adEvery > 0 && (i + 1) % adEvery == 0 && !isLast) {
        slotCounter++;
        final slotId = 'ad_$slotCounter';
        if (!removed.contains(slotId)) {
          items.add(AdFeedItem(id: slotId));
        }
      }
    }

    return List.unmodifiable(items);
  }

  // Returns slot IDs within [current, current + ahead] for preloading
  List<String> slotsToLoad(
    List<FeedItem> items, {
    required int current,
    required int ahead,
  }) {
    final result = <String>[];
    for (var i = current; i <= current + ahead && i < items.length; i++) {
      final item = items[i];
      if (item is AdFeedItem) result.add(item.id);
    }
    return result;
  }

  /// Episodes whose players should be warm while page [current] is on screen:
  /// the episode on that page (or, on an ad page, the episodes either side of
  /// it) plus [radius] episodes in each direction. Ad pages do not count
  /// towards the radius, so the episode after an ad is warm before the ad is
  /// reached. The forward run stops at the first locked episode, which is
  /// never included.
  List<EpisodeEntity> episodesToWarm(
    List<FeedItem> items, {
    required int current,
    required int radius,
    required bool Function(int episodeId) isLocked,
  }) {
    if (current < 0 || current >= items.length) return const [];

    final episodes = <EpisodeEntity>[];
    final pages = <int>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is EpisodeFeedItem) {
        episodes.add(item.episode);
        pages.add(i);
      }
    }

    final int anchor;
    final int first;
    final int last;
    final onEpisode = pages.indexOf(current);
    if (onEpisode >= 0) {
      anchor = onEpisode;
      first = onEpisode - radius;
      last = onEpisode + radius;
    } else {
      var after = episodes.length;
      for (var j = 0; j < pages.length; j++) {
        if (pages[j] > current) {
          after = j;
          break;
        }
      }
      anchor = after;
      first = after - radius;
      last = after + radius - 1;
    }

    final result = <EpisodeEntity>[];
    final end = math.min(last, episodes.length - 1);
    for (var j = math.max(first, 0); j <= end; j++) {
      final episode = episodes[j];
      if (isLocked(episode.id)) {
        if (j >= anchor) break;
        continue;
      }
      result.add(episode);
    }
    return result;
  }
}
