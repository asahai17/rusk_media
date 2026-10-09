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

/// An ad slot. Which ad unit serves it is the preloader's decision, keyed on
/// this id, so the domain carries nothing SDK-specific.
final class AdFeedItem extends FeedItem {
  final String id;

  const AdFeedItem({required this.id});

  @override
  List<Object?> get props => [id];
}
