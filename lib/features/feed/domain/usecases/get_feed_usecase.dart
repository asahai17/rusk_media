import '../entities/feed_item.dart';
import '../repositories/feed_repository.dart';

class GetFeedUseCase {
  final FeedRepository _repository;

  const GetFeedUseCase(this._repository);

  List<FeedItem> call() => _repository.getFeedItems();
}
