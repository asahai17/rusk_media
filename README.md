# MD Television — micro-drama interactive player

A vertical short-video feed for episodic drama, built in Flutter for Android. Seven episodes, a native ad after every third, a paywall on episode 7, first-run walkthrough and cinematic transitions throughout. The interesting part is not the UI — it is keeping video controllers alive while you flick through a feed mixed with native ads, without the app stuttering or leaking.

This file is about how the thing is actually built and why. If you only want to run it, the next section is enough.

## Running it

```bash
flutter pub get
flutter run                          # debug on connected device
flutter analyze                      # should report zero issues
flutter build apk --release          # release APK
```

Portrait only, Android first. There is no backend; the catalogue is seeded from test-videos.co.uk URLs in `app_constants.dart`. Ads load from Google's sample Ad Manager units (`/21775744923/example/native`), so you will see the GAM test creative on debug builds. That is Google's debug overlay, not ours.

## What it does

**Feed.** E1 E2 E3 AD E4 E5 E6 AD E7. Swipe up for the next one. The focused episode plays, neighbours sit ready, and ads are preloaded from the moment the feed initialises — before the user reaches them.

**Gestures.** Tap pauses. Double-tap likes (heart burst at the finger with satellite particles and a glow pulse). The bottom bar is a draggable seek bar with haptic feedback, an expanding thumb, and a time preview tooltip that follows the finger. The sound button mutes the app; it persists across episodes.

**Ads.** Native ads from GAM test units, loaded immediately on feed init, shown as a "Sponsored" break in the story: Google's dark-themed native template inside a safe area, with a swipe hint underneath. A slot that errors, comes back empty or takes more than 8 seconds is auto-skipped — the feed moves forward without anything on screen jumping.

**Paywall.** Episode 7 is locked. You can see its poster behind a real-time BackdropFilter blur, you cannot scroll past it (custom scroll physics), and "Unlock Episode" opens the rest. The CTA has a continuous shimmer sweep every 3 seconds. Returning to episode 7 before unlocking re-triggers the paywall. Once unlocked: paywall dismisses with a reverse elastic animation, scroll lock lifts, video initialises and plays instantly.

**Walkthrough.** A tips sheet on the first launch with six gesture tips and a "Start watching" CTA. Persisted via SharedPreferences — shows once, never again. Video playback is held while the sheet is visible.

**Splash.** Cinematic animated splash screen with staggered logo reveal (play icon → "MD" → "Television" → tagline → accent line), scan lines, and vignette. Transitions smoothly into the feed.

**Lifecycle.** App pauses video on background (hidden/paused/detached), resumes on foreground. Screen stays on via wakelock during playback.

## How it is put together

```
lib/
  main.dart                    boot order, non-blocking ads SDK init, edge-to-edge posture
  app.dart                     splash → feed transition shell
  core/
    constants/                 app_constants.dart (ad units, videos, timings), app_colors.dart
    di/                        injection_container.dart — all concrete construction lives here
    lifecycle/                 AppLifecycleObserver: background/foreground → pause/resume + wakelock
    theme/                     dark Material theme
    utils/                     DurationFormatter
  features/
    splash/presentation/       cinematic staggered splash animation
    feed/
      data/
        models/                EpisodeModel (DTO)
        repositories/          FeedRepositoryImpl (seed source)
        services/              AdPreloadManager (NativeAd lifecycle, timeout, retry, sealed state)
      domain/
        entities/              EpisodeEntity (pure Dart), FeedItem (sealed: Episode | Ad)
        policies/              FeedComposer (ad interleaving), EpisodePaywall (lock logic)
        repositories/          FeedRepository (interface)
        usecases/              GetFeedUseCase
      presentation/
        bloc/                  FeedBloc (feed data, page tracking, ad status, paywall state)
        pages/                 FeedPage (PageView, scroll physics, lifecycle, onboarding)
        widgets/
          episode_player_widget    full-screen player with pause/play, mute, buffering
          episode_info_overlay     brand bar, episode info, action rail, mute toggle
          ad_slot_widget           native ad display with auto-skip on failure
          paywall_overlay_widget   blur + elastic slide-up card + shimmer CTA
          onboarding_sheet         first-run walkthrough tips
          progress_bar_widget      custom-painted seekbar with expand + tooltip
          heart_animation_overlay  double-tap heart burst with satellites
          shimmer_skeleton         cinematic loading skeleton with scan lines
          shimmer_cta_button       shimmer sweep CTA for paywall
          custom_scroll_physics    paywall lock scroll physics
```

Layers are the usual ones. `domain/` is pure Dart and knows nothing about Flutter — no `package:flutter` imports, no `Color` class, no `dart:ui`. `data/` turns seed data into entities. Presentation talks to blocs, blocs talk to use cases. Concrete classes are built only in `core/di/`.

## The ad system

`AdPreloadManager` owns the `NativeAd` objects and their lifetimes. It uses a sealed state machine (`AdSlotIdle → AdSlotLoading → AdSlotLoaded | AdSlotFailed`) with an 8-second load timeout. Two streams notify the BLoC: `successes` and `failures`.

Ads are `NativeAd.fromAdManagerRequest` with `NativeTemplateStyle` — dark-themed templates (headline, body, icon, CTA button) that render as rich styled content, not just a small banner. Two different GAM test units for variety: `/21775744923/example/native` and `/21775744923/example/native-video`.

The `AdWidget` is never placed under `Opacity` or `Transform` — on Android, native views draw incorrectly under those. The shimmer skeleton sits on top and is replaced, not faded over the ad.

On failure, the feed auto-skips past the ad slot with a smooth animation. No visible jump, no broken page.

## The paywall

`EpisodePaywall` is a pure Dart policy (which episode is locked, which page that is in the composed feed). `ReelScrollPhysics` stops the scroll at the locked page. The locked episode never plays — not even partially. The controller is not even created until after unlock.

The paywall overlay uses a live `BackdropFilter(sigmaX: 20, sigmaY: 20)` over the poster gradient. The card slides up with `Curves.elasticOut` (overshoot bounce). The CTA button has a continuous shimmer light sweep every 3 seconds.

## Domain policies

The parts that are easy to get wrong are pure Dart, testable without a widget tree:

- **`FeedComposer`** — interleaves ad slots into episodes, knows which slots to preload given the current page
- **`EpisodePaywall`** — lock logic: which episode, which page index, whether to show paywall given current state

## Decisions worth knowing about

| Decision | Rationale |
|----------|-----------|
| Non-blocking ads SDK init | Splash animation provides head start; if SDK fails, slots timeout and leave |
| NativeAd not BannerAd | Rich styled templates fill the screen properly; banners are tiny rectangles |
| `FeedComposer` in domain | Feed composition is a policy, not UI logic; testable without mocks |
| Stable content keys (not page index) | `findChildIndexCallback` + `ValueKey('ep_${id}')` means dropping an ad slot never reloads a video |
| `buildWhen` on BlocBuilder | Multi-field state only rebuilds PageView when relevant fields change |
| Manual animation curves | `TweenSequence` crashes when curves overshoot past 1.0; manual functions are safe |
| `static _globalMuted` on player | Mute persists across episodes without bloc involvement — ephemeral UI state |
| Wakelock during playback | Screen stays on while watching; disabled on dispose |
| `PageScrollPhysics` as base | Flutter's built-in page snapping — one page per swipe, crisp and reliable |

## Evaluation criteria alignment

| Criterion | Implementation |
|-----------|---------------|
| **Animation Fidelity** | Manual spring curves on hearts, elastic paywall bounce, staggered splash sequence, cinematic pause indicator with ring pulse, shimmer CTA sweep, info overlay slide-in |
| **UX Intuition** | Tap pause/play with haptic, double-tap heart at exact position, horizontal drag scrub with expanding thumb + tooltip, mute toggle persists globally, first-run walkthrough |
| **Performance** | `buildWhen` on BlocBuilder, `AutomaticKeepAliveClientMixin`, non-blocking SDK init, ad preloading on feed init, stable content keys, no `Opacity` on native views |
| **Code Architecture** | Clean Architecture (domain pure Dart, data DTOs, presentation BLoC), sealed `FeedItem`, domain policies, DI centralized, lifecycle observer, sealed ad state machine |

## What is not real yet

- **Content.** Seven test-videos.co.uk clips in 720p.
- **Ad units.** Google's sample GAM units. Never a production unit in this repo.
- **Purchase.** "Unlock Episode" is a simulated unlock — dismisses the paywall, no real transaction.
- **Backend.** Feed is seeded from constants. Swap `FeedRepositoryImpl` for a real API.
