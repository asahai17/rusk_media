import '../entities/feed_item.dart';

// Pure Dart policy — no flutter imports. Testable without widget tree.
// Interleaves ad slots into the episode list and handles slot removal planning.
class FeedComposer {
  const FeedComposer({this.adEvery = 3});
  final int adEvery;

  // Compose feed: E1 E2 E3 [AD] E4 E5 E6 [AD] E7
  // No slot after the last episode.
  List<FeedItem> compose(
    List<EpisodeFeedItem> episodes, {
    Set<String> removed = const {},
    required String Function(String slotId) adUnitForSlot,
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
          items.add(AdFeedItem(id: slotId, adUnitId: adUnitForSlot(slotId)));
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

  // Find the page index of a given episode ID in the composed feed
  int? pageIndexOfEpisode(List<FeedItem> items, int episodeId) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is EpisodeFeedItem && item.episode.id == episodeId) return i;
    }
    return null;
  }
}
