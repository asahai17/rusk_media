part of 'feed_bloc.dart';

sealed class FeedEvent {
  const FeedEvent();
}

final class FeedInitialized extends FeedEvent {
  const FeedInitialized();
}

final class PageChanged extends FeedEvent {
  final int pageIndex;
  const PageChanged(this.pageIndex);
}

final class AdLoaded extends FeedEvent {
  final String adId;
  const AdLoaded(this.adId);
}

/// Ad failed, returned no fill, or timed out. The slot is removed from the
/// feed as soon as the scroll is at rest and the user is not on it.
final class AdFailed extends FeedEvent {
  final String adId;
  const AdFailed(this.adId);
}

/// The PageView started (true) or finished (false) scrolling, whether by a
/// drag, a fling or a programmatic animation.
final class ScrollStateChanged extends FeedEvent {
  final bool isScrolling;
  const ScrollStateChanged({required this.isScrolling});
}

final class PaywallUnlockRequested extends FeedEvent {
  const PaywallUnlockRequested();
}

final class MuteToggled extends FeedEvent {
  const MuteToggled();
}

/// The user tapped the current episode to pause or resume it.
final class PlaybackToggled extends FeedEvent {
  const PlaybackToggled();
}

/// App moved to background (false) or came back to foreground (true).
final class AppVisibilityChanged extends FeedEvent {
  final bool isForeground;
  const AppVisibilityChanged({required this.isForeground});
}
