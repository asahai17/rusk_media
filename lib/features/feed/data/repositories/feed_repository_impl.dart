import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/feed_item.dart';
import '../../domain/repositories/feed_repository.dart';
import '../models/episode_model.dart';

class FeedRepositoryImpl implements FeedRepository {
  const FeedRepositoryImpl();

  @override
  List<FeedItem> getFeedItems() {
    // Returns episode items only — FeedComposer policy handles ad interleaving
    return List.generate(AppConstants.totalEpisodes, (i) {
      return EpisodeFeedItem(
        episode: EpisodeModel.fromIndex(
          i,
          title: AppConstants.episodeTitles[i],
          description: AppConstants.episodeDescriptions[i],
          videoUrl: AppConstants.episodeVideoUrls[i],
          posterGradientColorValues: AppColors.episodePosterGradientValues[i],
        ),
      );
    });
  }
}
