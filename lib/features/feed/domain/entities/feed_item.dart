import 'package:equatable/equatable.dart';
import 'episode_entity.dart';

sealed class FeedItem extends Equatable {
  const FeedItem();
}

final class EpisodeFeedItem extends FeedItem {
  final EpisodeEntity episode;

  const EpisodeFeedItem({required this.episode});

  @override
  List<Object?> get props => [episode];
}

final class AdFeedItem extends FeedItem {
  final String id;
  final String adUnitId;

  const AdFeedItem({required this.id, required this.adUnitId});

  @override
  List<Object?> get props => [id, adUnitId];
}
