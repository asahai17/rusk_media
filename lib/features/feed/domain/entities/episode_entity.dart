import 'package:equatable/equatable.dart';

// Pure Dart — no flutter imports in domain layer
class EpisodeEntity extends Equatable {
  final int id;
  final String title;
  final String description;
  final String videoUrl;

  /// Poster frame, when the source has one. Null means "use the gradient".
  final String? posterUrl;

  // Stored as ARGB int values — converted to Color in presentation
  final List<int> posterGradientColorValues;

  const EpisodeEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.posterGradientColorValues,
    this.posterUrl,
  });

  @override
  List<Object?> get props => [id, videoUrl];
}
