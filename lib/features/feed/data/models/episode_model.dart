import '../../domain/entities/episode_entity.dart';

class EpisodeModel extends EpisodeEntity {
  const EpisodeModel({
    required super.id,
    required super.title,
    required super.description,
    required super.videoUrl,
    required super.posterGradientColorValues,
    super.posterUrl,
  });

  factory EpisodeModel.fromIndex(
    int index, {
    required String title,
    required String description,
    required String videoUrl,
    required List<int> posterGradientColorValues,
    String? posterUrl,
  }) {
    return EpisodeModel(
      id: index + 1,
      title: title,
      description: description,
      videoUrl: videoUrl,
      posterGradientColorValues: posterGradientColorValues,
      posterUrl: posterUrl,
    );
  }
}
