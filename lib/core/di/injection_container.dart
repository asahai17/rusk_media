import 'package:get_it/get_it.dart';

import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/data/services/ad_preload_manager.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/domain/usecases/get_feed_usecase.dart';
import '../../features/feed/presentation/bloc/feed_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Services — feed-scoped ad preloader
  sl.registerLazySingleton<AdPreloadManager>(
    () => AdPreloadManager(),
  );

  // Repository
  sl.registerLazySingleton<FeedRepository>(
    () => const FeedRepositoryImpl(),
  );

  // Use cases
  sl.registerLazySingleton<GetFeedUseCase>(
    () => GetFeedUseCase(sl()),
  );

  // BLoC — factory for fresh state per screen
  sl.registerFactory<FeedBloc>(
    () => FeedBloc(
      getFeedUseCase: sl(),
      adPreloadManager: sl(),
    ),
  );
}
