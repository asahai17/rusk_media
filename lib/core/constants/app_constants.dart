abstract final class AppConstants {
  static const String appName = 'MD Television';
  static const String appTagline = 'MICRO STORIES. BIG DRAMA.';

  // GAM test ad units — Native ads for rich full-screen ad experience
  static const String gamNativeTestUnit = '/21775744923/example/native';
  static const String gamNativeVideoTestUnit = '/21775744923/example/native-video';

  // Route different creatives to different slots for variety
  static String adUnitForSlot(String slotId) =>
      slotId == 'ad_2' ? gamNativeVideoTestUnit : gamNativeTestUnit;

  // Ad load timeout — slower than this counts as no-fill
  static const Duration adLoadTimeout = Duration(seconds: 8);

  // Feed composition
  static const int totalEpisodes = 7;
  static const int adAfterEveryNEpisodes = 3;
  static const int paywallEpisodeId = 7;
  static const int paywallPageIndex = 8;
  static const int totalFeedPages = 9;

  // Ad preload distance — start loading when this many pages ahead
  static const int adPreloadAhead = 3;

  // Video URLs — 720p lightweight clips
  static const List<String> episodeVideoUrls = [
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_2MB.mp4',
    'https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_2MB.mp4',
    'https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_2MB.mp4',
    'https://media.w3.org/2010/05/sintel/trailer_hd.mp4',
  ];

  static const List<String> episodeTitles = [
    'The Beginning',
    'Shadows Fall',
    'Burning Desires',
    'Escape from Reality',
    'Beyond the Horizon',
    'Into the Wild',
    'The Final Chapter',
  ];

  static const List<String> episodeDescriptions = [
    'Where every story begins with a spark that ignites the soul.',
    'When shadows descend, true character is revealed.',
    'Passion burns brighter than reason in the heart of darkness.',
    'Sometimes the only way out is through.',
    'The greatest adventures begin where the map ends.',
    'Nature holds secrets that civilization has forgotten.',
    'All stories must end. But some endings are just new beginnings.',
  ];

  static const Duration heartAnimationDuration = Duration(milliseconds: 1100);
  static const Duration paywallSlideUpDuration = Duration(milliseconds: 700);
  static const Duration shimmerSweepDuration = Duration(seconds: 3);
  static const Duration adAutoSkipDelay = Duration(milliseconds: 600);
  static const Duration progressBarExpandDuration = Duration(milliseconds: 250);
  static const Duration videoFadeInDuration = Duration(milliseconds: 400);
  static const Duration infoSlideInDuration = Duration(milliseconds: 500);
}
