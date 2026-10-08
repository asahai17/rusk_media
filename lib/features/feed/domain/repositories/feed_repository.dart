import '../entities/feed_item.dart';

abstract interface class FeedRepository {
  List<FeedItem> getFeedItems();
}
