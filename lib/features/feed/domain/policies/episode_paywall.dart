import '../entities/feed_item.dart';

// Pure Dart policy — no flutter imports. Testable without widget tree.
// Determines paywall lock state for episode 7.
class EpisodePaywall {
  const EpisodePaywall({this.lockedEpisode = 7});
  final int lockedEpisode;

  bool isLockedEpisode(int episodeId) => episodeId == lockedEpisode;

  // Returns the page index of the locked episode in the feed, or null
  int? lockedPage(List<FeedItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is EpisodeFeedItem && item.episode.id == lockedEpisode) {
        return i;
      }
    }
    return null;
  }

  // Whether the given page index should show the paywall
  bool shouldShowPaywall(List<FeedItem> items, int pageIndex, {required bool unlocked}) {
    if (unlocked || pageIndex >= items.length) return false;
    final item = items[pageIndex];
    return item is EpisodeFeedItem && item.episode.id == lockedEpisode;
  }
}
