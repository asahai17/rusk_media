# MD Television — micro-drama interactive player

A vertical short-video feed for episodic drama, built in Flutter for Android. Eight episodes, a native ad after every third, a paywall on episode 7, and cinematic transitions throughout. The interesting part is not the UI — it is keeping exactly the right video controllers alive while you flick through a feed mixed with native ads, without the app stuttering, leaking, or playing in the background.

This file describes how the thing is actually built. Every claim below is backed by a test in `test/` or a line in `lib/`.

## Running it

```bash
flutter pub get
flutter run                          # debug on a connected device
flutter analyze                      # 0 issues
flutter test                         # 76 tests: policies, pool, bloc, lifecycle, physics, widgets
flutter build apk --release          # release APK
```

Flutter is pinned to 3.47.7 via `.fvmrc`. Portrait only, Android first. There is no backend; the catalogue is seeded from test-videos.co.uk and w3.org clips in `app_constants.dart`. Ads load from Google's sample Ad Manager units (`/21775744923/example/native`), so you will see the GAM test creative on debug builds.

## What it does

**Feed.** `E1 E2 E3 AD E4 E5 E6 AD E7 E8`. Swipe up for the next one; clips loop. Only the focused episode plays. The episode on either side of it holds an initialised, paused player waiting at its first frame, so the next swipe lands on a surface that is already decoded. Ad pages do not count towards that window, which means the episode after an ad is warm before you reach the ad.

**Gestures.** Tap pauses; the pause survives backgrounding but clears when you move to another page. Double-tap likes with a spring-driven heart burst at the finger, plus satellites and a glow. The bottom bar is a draggable seek bar with haptic feedback, an expanding thumb, and a time preview tooltip that follows the finger. The sound button mutes the session; every live player applies the current mute immediately before it plays.

**Ads.** Native ads from GAM test units, requested only for slots within three pages ahead of the user. Each slot has an 8-second timeout. A slot that errors, comes back empty, or times out is removed from the feed, but only once the scroll is at rest: a removal mid-gesture would fight the finger. If you are looking at the failed slot, the page animates to the next episode first and the slot is removed behind you. If the slot was behind you, the page index shifts up and the `PageController` jumps in the same frame, so the viewport does not move; content keys keep the players alive.

**Paywall.** Episode 7 is locked. Its poster frame is blurred behind a card that slides up with an elastic bounce each time you arrive, the CTA shimmers every 3 seconds, and the forward scroll stops at that page while episode 8 waits behind it. The locked episode never gets a video controller, in either scroll direction. "Unlock Episode" reverses the card, lifts the lock, and the player warms and plays.

**Lifecycle.** `hidden`, `paused` and `detached` pause the active episode; `inactive` is ignored so the notification shade does not stop playback. Coming back resumes only if you had not paused it yourself. The wakelock is held only while a video is actually being played: off on pause, on ad pages, on the paywall, and on dispose.

**Splash.** A staggered logo reveal with scan lines and a vignette, then the feed.

## How it is put together

```
lib/
  main.dart                    boot order, non-blocking ads SDK init, edge-to-edge posture
  app.dart                     splash → feed shell
  core/
    constants/                 app_constants.dart (ad units, clips, posters, windows), app_colors.dart
    di/                        injection_container.dart — every concrete type is built here
    lifecycle/                 AppLifecycleObserver: lifecycle state → bloc event, nothing else
    theme/, utils/
  features/
    splash/presentation/
    feed/
      data/
        models/                EpisodeModel (DTO)
        repositories/          FeedRepositoryImpl (seed source)
        services/              AdPreloader (interface) + AdPreloadManager (NativeAd lifecycle)
                               EpisodePlayerPool (every VideoPlayerController in the feed)
      domain/
        entities/              EpisodeEntity, FeedItem (sealed: Episode | Ad)
        policies/              FeedComposer: ad interleaving, ad window, player window
        repositories/          FeedRepository (interface)
        usecases/              GetFeedUseCase
      presentation/
        bloc/                  FeedBloc: one state, one pool sync per state change
        pages/                 FeedPage: PageView, scroll notifications, same-frame index sync
        widgets/
          episode_player_widget    composes the four layers below (198 lines)
          episode_video_surface    gradient, shimmer, retry card, video, buffering ring
          episode_gesture_layer    tap / double-tap, pause glyph, heart burst
          episode_info_overlay     brand bar, episode info, action rail, mute toggle
          progress_bar_widget      EpisodeSeekBar + custom-painted scrubber
          paywall_overlay_widget   poster blur + elastic card + shimmer CTA
          ad_slot_widget           native ad page, plus the native template style
          heart_animation_overlay  SpringSimulation pop with satellites and glow
          custom_scroll_physics    ReelScrollPhysics: forward lock at the paywall page
          shimmer_skeleton, shimmer_cta_button, wip_snackbar
```

`domain/` is pure Dart and imports nothing from Flutter. `data/` owns the two SDK-backed services. Presentation talks to the bloc; the bloc talks to the use case and to the two services. Concrete classes are built only in `core/di/`. There is no service locator access from any widget.

## Playback: one state, one pool

`FeedState` is the single source of truth for the feed: the composed items, the current page, which episode is locked, mute, foreground, user pause, pending ad removals and whether a scroll is in progress. `FeedBloc.onChange` turns every state change into one call to `EpisodePlayerPool.apply`, which receives:

- the episodes that must be warm — `FeedComposer.episodesToWarm`: the current episode and one neighbour each side, ads skipped, stopping at the locked episode;
- the one episode that may play;
- whether it should play — `isAppInForeground && !isUserPaused`;
- the current mute.

The pool reconciles: anything outside the window is disposed, anything missing is created, the active controller is told to play after the mute is applied, everything else is paused and rewound to zero. It pauses before it plays, so two players are never audible at once. Playback is intent-based — the pool tracks what it last told each controller, never `controller.value.isPlaying`, because ExoPlayer can report not-playing while it waits for audio focus and then resume on its own. Every async continuation re-checks that its controller is still the one registered for that episode, so a late `initialize()` can never touch a controller that was evicted while it was loading. The plugin's own background observer is disabled (`allowBackgroundPlayback: true`) so there is exactly one owner of pause and resume.

Pages subscribe to the pool and render whatever controller it holds for their episode: shimmer while loading, a retry card on failure, the video when ready. They never call play or pause.

## The ad system

`AdPreloadManager` (behind the `AdPreloader` interface) owns the `NativeAd` objects: a sealed `idle → loading → loaded | failed` state machine per slot, an 8-second timeout, identity checks against stale callbacks, and full disposal. It is a factory in DI and is owned and disposed by the `FeedBloc`, because a singleton disposed by one bloc would be dead for the next. The loaded ads themselves are mirrored into `FeedState.loadedAds`, which is the only copy the UI reads; `AdSlotWidget` takes the ad through its constructor.

The `AdWidget` is never placed under `Opacity` or `Transform`, because Android native views draw incorrectly under those.

The native template style lives next to the ad page in presentation and is injected into the manager, so the data layer never imports Material or the app colours.

## The paywall

Lock state is a property of the episode, not of scroll position: `FeedState.isEpisodeLocked(id)` is the one place it is decided, and both the page lock and the player window read it. `ReelScrollPhysics` reads the locked page through a callback on every scroll update rather than capturing it at construction — Flutter keeps the `ScrollPosition` (and the physics inside it) as long as the physics *type* is unchanged, so a new instance with a different value would never take effect. That is also why episode 8 exists: with 7 episodes the forward lock could never be exercised.

## Domain policies

The parts that are easy to get wrong are pure Dart and tested without a widget tree:

- **`FeedComposer.compose`** — interleaves ad slots into episodes and drops removed ones without renumbering the rest.
- **`FeedComposer.slotsToLoad`** — which ad slots to request for the current page.
- **`FeedComposer.episodesToWarm`** — which episodes keep a player for the current page.

## Tests

`flutter test` runs 76 tests, all with hand-written fakes and no mocks:

| File | What it proves |
|---|---|
| `feed_policies_test.dart` | composition, ad window, player window including the lock |
| `episode_player_pool_test.dart` | exactly current ±1 warm, eviction, one player at a time, locked episode never created, evicted-mid-init guard, retry, looping, mute before play, background pause not gated on `isPlaying`, wakelock only while playing |
| `feed_bloc_test.dart` | windowed ad loads, loaded ads in state, slot removal before / on / behind the current page and mid-scroll, background round trip with and without a user pause, unlock |
| `feed_page_test.dart` | real swipes through the `PageView`: failure before arrival, on the slot, behind the page, mid-drag; a fling past E7 is absorbed while locked and moves after unlock |
| `episode_player_widget_test.dart` | shimmer → video, retry card, buffering ring from the controller, tap-to-pause, no Material spinner |
| `app_lifecycle_observer_test.dart` | `inactive` ignored, one pause per background, one resume per return |
| `reel_scroll_physics_test.dart` | boundary clamp, live unlock |

The fakes are `FakeVideoPlayerPlatform` (records every platform call per player, can hold or fail `create`) and `FakeAdPreloader` / `FakeFeedRepository`.

## Decisions worth knowing about

| Decision | Rationale |
|----------|-----------|
| One pool, driven from `FeedBloc.onChange` | Playback is a function of state; one sync point instead of play/pause calls scattered through widgets |
| Window counted in episodes, not pages | The episode after an ad is warm before the ad, so leaving the ad is as snappy as any other swipe |
| Intent-based pause | A pause gated on `isPlaying` misses the audio-focus case and lets ExoPlayer resume on its own |
| Wakelock owned by the pool | It is the only object that knows whether a video is really being played |
| Removal only at scroll rest | A `jumpToPage` during a drag fights the finger |
| Physics reads the lock through a callback | Same-type physics instances never replace the `ScrollPosition` |
| `allowImplicitScrolling: true` | The neighbour's video surface is mounted before the swipe; the player underneath is already warm regardless |
| `SpringSimulation` for the heart | The overshoot and settle come from physics rather than a hand-drawn curve; opacity is clamped before it reaches `Opacity` |
| Non-blocking ads SDK init | The splash gives it a head start; if it fails, slots time out and leave |

## What I changed after review and why

**1. Background pause.** The lifecycle observer used to be wired to empty callbacks, and the later fix still gated the pause on `controller.value.isPlaying` and tied the wakelock to foreground rather than playback. Now the observer only reports `hidden`/`paused`/`detached` and `resumed` to the bloc; the pool pauses by intent, resumes only when the user had not paused, and holds the wakelock only while it has told a controller to play. Tests cover the round trip with and without a user pause, and the case where the platform reports not-playing.

**2. Video preload window.** Controllers were created in each page's `initState` and kept forever by `AutomaticKeepAliveClientMixin`. They now live in `EpisodePlayerPool`, which keeps exactly the current episode and one neighbour each side, disposes everything else, never creates one for a locked episode, and re-checks identity after every `await`. The keep-alive mixin is gone from the episode widget. A fake `VideoPlayerPlatform` lets the tests count controllers and play calls without a device.

**3. Looping.** `setLooping(true)` is applied to every controller and there is no auto-advance; a test asserts both.

**4. Failed ad slots.** Failure used to recompose the feed immediately, even under the user's finger. Now a failed slot goes into `pendingAdRemovals` and leaves the feed only when `ScrollEndNotification` says the scroll is at rest and the user is not on it; if they are, the page animates to the next episode first. The "Continuing..." page, the spinner and the auto-skip event were already gone. Widget tests drive the real `PageView` through all four cases.

**5. Ad window and DI.** Ads were already windowed and the preloader was already a factory; the comment now says why. The duplicate `AdLoadStatus` map is gone: the manager keeps its state machine, and `FeedState.loadedAds` is the only representation the UI sees. `AdSlotWidget` receives the ad through its constructor.

**6. Mute.** Mute lives in `FeedState`; the pool applies it to every live controller on change, on creation, and again immediately before every play. The old `static bool` and the `didUpdateWidget` volume call are gone.

**7. Errors and buffering.** An init failure sets the pool's status to `error` and the page shows a retry card instead of an infinite shimmer. The buffering ring is a `ValueListenableBuilder` on the controller. No `CircularProgressIndicator` remains, and a test asserts it. The widget test also found that the full-screen gesture layer sat above the retry card and won every tap, so the layer is no longer mounted in the error state.

**8. Heart.** The scale pop is a `SpringSimulation` on an unbounded `AnimationController`; the timeline controller still drives rise, fade, rotation and the satellites. Opacity values are clamped to 0..1.

**9. Paywall.** Lock visibility derives from the episode's lock state, not from `currentPageIndex`. The blur sits over the episode's real poster frame. Episode 8 was added behind the lock, and the tests for it found that the lock never lifted: Flutter ignores a new `ScrollPhysics` instance of the same type, so `ReelScrollPhysics` now reads the locked page through a callback. The card also animates on each arrival, not once while the page is pre-built off-screen.

**10. Structure and dead code.** The 581-line player widget is split into a video surface, a gesture layer and a composer, each under 200 lines; the info overlay and snackbar were already separate. `FeedState.isEpisodeLocked` is the one source of truth for the lock, and the one-field `EpisodePaywall` class is gone with it. `AdFeedItem.adUnitId` is removed (the manager decides the unit). `buildWhen` on the feed page lists only what the `PageView` lays out; mute and pause are read per page with `context.select`. The `// ignore:` lines are replaced by private named parameters. The native template style moved out of the data layer.

**11. README.** Rewritten against the code, with this section.

## What is not real yet

- **Content.** Eight test clips in 720p; no disk cache, so scrolling back more than one episode re-downloads a clip.
- **Ad units.** Google's sample GAM units only.
- **Purchase.** "Unlock Episode" is a simulated unlock.
- **Backend.** The feed is seeded from constants; swap `FeedRepositoryImpl` for a real API.
- **Ad pages** stay mounted once visited (a `NativeAd` is bound to one `AdWidget`); bounded by the number of ads, two here.
