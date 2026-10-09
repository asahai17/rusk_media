import 'package:get_it/get_it.dart';

import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/data/services/ad_preload_manager.dart';
import '../../features/feed/data/services/ad_preloader.dart';
import '../../features/feed/data/services/episode_player_pool.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/domain/usecases/get_feed_usecase.dart';
import '../../features/feed/presentation/bloc/feed_bloc.dart';
import '../../features/feed/presentation/widgets/ad_slot_widget.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Repository
  sl.registerLazySingleton<FeedRepository>(() => const FeedRepositoryImpl());

  // Use cases
  sl.registerLazySingleton<GetFeedUseCase>(() => GetFeedUseCase(sl()));

  // Ad preloader — a factory, not a singleton, because FeedBloc.close()
  // disposes it: it owns NativeAd objects whose lifetime is one feed session,
  // and a singleton disposed by one bloc would be dead for the next.
  sl.registerFactory<AdPreloader>(
    () => AdPreloadManager(templateStyle: nativeAdTemplateStyle),
  );

  // Player pool — same rule: it owns VideoPlayerControllers, so one per feed
  // session, disposed by the bloc that owns it.
  sl.registerFactory<EpisodePlayerPool>(() => EpisodePlayerPool());

  // BLoC — factory for fresh state per screen
  sl.registerFactory<FeedBloc>(
    () => FeedBloc(
      getFeedUseCase: sl(),
      adPreloader: sl(),
      playerPool: sl(),
    ),
  );
}
