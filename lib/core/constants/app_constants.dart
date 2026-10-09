abstract final class AppConstants {
  static const String appName = 'MD Television';
  static const String appTagline = 'MICRO STORIES. BIG DRAMA.';

  // GAM test ad units — Native ads for rich full-screen ad experience
  static const String gamNativeTestUnit = '/21775744923/example/native';
  static const String gamNativeVideoTestUnit =
      '/21775744923/example/native-video';

  // Route different creatives to different slots for variety
  static String adUnitForSlot(String slotId) =>
      slotId == 'ad_2' ? gamNativeVideoTestUnit : gamNativeTestUnit;

  // Ad load timeout — slower than this counts as no-fill
  static const Duration adLoadTimeout = Duration(seconds: 8);

  // Feed composition. E8 sits behind the lock so the forward scroll lock on
  // E7 is observable.
  static const int totalEpisodes = 8;
  static const int adAfterEveryNEpisodes = 3;
  static const int paywallEpisodeId = 7;

  // Ad preload distance — slots within this many pages ahead of the current
  // page start loading. Keeps request volume bounded for long feeds.
  static const int adPreloadAhead = 3;

  // Video preload window — this many episodes either side of the current one
  // keep an initialised player. Everything further away is disposed.
  static const int videoPreloadRadius = 1;

  // Video URLs — 720p lightweight clips
  static const List<String> episodeVideoUrls = [
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_2MB.mp4',
    'https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_2MB.mp4',
    'https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_2MB.mp4',
    'https://media.w3.org/2010/05/sintel/trailer_hd.mp4',
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_5MB.mp4',
  ];

  // Poster frames, where the source publishes one. The paywall blurs the
  // locked episode's poster; null falls back to the episode gradient.
  static const String _bunnyPoster = 'https://media.w3.org/2010/05/bunny/poster.png';
  static const String _sintelPoster = 'https://media.w3.org/2010/05/sintel/poster.png';
  static const List<String?> episodePosterUrls = [
    _bunnyPoster,
    _sintelPoster,
    null,
    _bunnyPoster,
    _sintelPoster,
    null,
    _sintelPoster,
    _bunnyPoster,
  ];

  static const List<String> episodeTitles = [
    'The Beginning',
    'Shadows Fall',
    'Burning Desires',
    'Escape from Reality',
    'Beyond the Horizon',
    'Into the Wild',
    'The Final Chapter',
    'After the Credits',
  ];

  static const List<String> episodeDescriptions = [
    'Where every story begins with a spark that ignites the soul.',
    'When shadows descend, true character is revealed.',
    'Passion burns brighter than reason in the heart of darkness.',
    'Sometimes the only way out is through.',
    'The greatest adventures begin where the map ends.',
    'Nature holds secrets that civilization has forgotten.',
    'All stories must end. But some endings are just new beginnings.',
    'What the story left behind, and who came back for it.',
  ];

  static const Duration heartAnimationDuration = Duration(milliseconds: 1100);
  static const Duration paywallSlideUpDuration = Duration(milliseconds: 700);
  static const Duration shimmerSweepDuration = Duration(seconds: 3);
  static const Duration progressBarExpandDuration = Duration(milliseconds: 250);
  static const Duration videoFadeInDuration = Duration(milliseconds: 400);
  static const Duration infoSlideInDuration = Duration(milliseconds: 500);
}
