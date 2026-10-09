import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/domain/entities/episode_entity.dart';
import 'package:md_television/features/feed/domain/entities/feed_item.dart';
import 'package:md_television/features/feed/domain/policies/feed_composer.dart';

List<EpisodeFeedItem> episodes(int count) => List.generate(
  count,
  (i) => EpisodeFeedItem(
    episode: EpisodeEntity(
      id: i + 1,
      title: 'E${i + 1}',
      description: '',
      videoUrl: 'https://example.com/${i + 1}.mp4',
      posterGradientColorValues: const [0xFF000000, 0xFF000000],
    ),
  ),
);

bool lockedE7(int id) => id == 7;
bool none(int id) => false;

String describe(List<FeedItem> items) => items
    .map((i) {
      return switch (i) {
        EpisodeFeedItem(:final episode) => 'E${episode.id}',
        AdFeedItem() => 'AD',
      };
    })
    .join(' ');

void main() {
  const composer = FeedComposer(adEvery: 3);

  group('FeedComposer.compose', () {
    test('interleaves an ad after every 3 episodes, none after the last', () {
      final feed = composer.compose(episodes(7));
      expect(describe(feed), 'E1 E2 E3 AD E4 E5 E6 AD E7');
    });

    test('slot ids are stable', () {
      final ads = composer.compose(episodes(7)).whereType<AdFeedItem>();
      expect(ads.map((a) => a.id), ['ad_1', 'ad_2']);
    });

    test('a removed slot is dropped without renumbering the others', () {
      final feed = composer.compose(episodes(7), removed: const {'ad_1'});
      expect(describe(feed), 'E1 E2 E3 E4 E5 E6 AD E7');
      expect(feed.whereType<AdFeedItem>().single.id, 'ad_2');
    });

    test('does not insert an ad after the final episode', () {
      final feed = composer.compose(episodes(6));
      expect(describe(feed), 'E1 E2 E3 AD E4 E5 E6');
    });
  });

  group('FeedComposer.slotsToLoad', () {
    final feed = composer.compose(episodes(7));

    test('returns slots within the look-ahead window only', () {
      expect(composer.slotsToLoad(feed, current: 0, ahead: 3), ['ad_1']);
      expect(composer.slotsToLoad(feed, current: 0, ahead: 2), isEmpty);
      expect(composer.slotsToLoad(feed, current: 4, ahead: 3), ['ad_2']);
      expect(composer.slotsToLoad(feed, current: 8, ahead: 3), isEmpty);
    });
  });

  group('FeedComposer.episodesToWarm', () {
    // E1 E2 E3 AD E4 E5 E6 AD E7 E8
    final feed = composer.compose(episodes(8));

    List<int> warm(int page, {bool Function(int) isLocked = lockedE7}) =>
        composer
            .episodesToWarm(feed, current: page, radius: 1, isLocked: isLocked)
            .map((e) => e.id)
            .toList();

    test('keeps the current episode and one neighbour each side', () {
      expect(warm(0), [1, 2]);
      expect(warm(1), [1, 2, 3]);
      expect(warm(2), [2, 3, 4], reason: 'the ad page does not count');
    });

    test('on an ad page keeps the episodes either side of it', () {
      expect(warm(3), [3, 4]);
      expect(warm(7), [6]);
    });

    test('stops at the locked episode and never includes it', () {
      expect(warm(7), [6]);
      expect(warm(8), [6]);
      expect(warm(8, isLocked: none), [6, 7, 8]);
      expect(warm(9, isLocked: none), [7, 8]);
    });

    test('is empty for an out-of-range page', () {
      expect(warm(-1), isEmpty);
      expect(warm(feed.length), isEmpty);
    });
  });
}
