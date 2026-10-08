import 'package:equatable/equatable.dart';

// Pure Dart — no flutter imports in domain layer
class EpisodeEntity extends Equatable {
  final int id;
  final String title;
  final String description;
  final String videoUrl;
  // Stored as ARGB int values — converted to Color in presentation
  final List<int> posterGradientColorValues;

  const EpisodeEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.posterGradientColorValues,
  });

  @override
  List<Object?> get props => [id, videoUrl];
}
