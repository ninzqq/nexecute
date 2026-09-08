# Assistant particle release validation

This document is the release gate for the animated particle field behind the
Assistant conversation. The effect must remain decorative: it may not delay or
obscure messages, status banners, focus indicators, controls, or assistive
technology output.

## Automated coverage

Run the static checks and relevant widget suites:

```sh
flutter analyze
flutter test test/ai test/app_theme_controller_test.dart test/home_navigation_test.dart
```

The particle widget suite covers deterministic rendering, bounded area-based
density, theme palettes, motion and wrapping, twinkle, resize stability,
inactive-view suspension, reduced motion, pointer passthrough, semantic
exclusion, keyboard focus, and text contrast at 320x720 and 1440x900 under all
theme presets.

Run the interaction benchmark in profile mode on each release target:

```sh
flutter drive --driver test_driver/integration_test.dart \
  --target integration_test/assistant_particle_performance_test.dart \
  -d <device-id> --profile
```

The benchmark exercises the real Assistant page while opening keyboard focus,
typing, streaming a long response, scrolling, and changing viewport sizes. It
requires both 90th-percentile build and raster times to remain below Flutter's
16 ms frame budget. Keep the emitted `ASSISTANT_PARTICLE_PERFORMANCE` summary
with the release record so changes can be compared over time.

## Manual device matrix

For both a representative Android phone and macOS computer:

1. Open an empty Assistant conversation under every theme.
2. Focus the composer, type continuously, and open and dismiss the keyboard.
3. Stream a long answer while repeatedly scrolling through existing messages.
4. On Android, rotate between portrait and landscape. On macOS, continuously
   resize the window from compact to wide.
5. Confirm message text, error and context banners, focus rings, links, and
   composer controls remain readable and responsive.
6. Enable the platform reduced-motion preference and confirm particles remain
   static. Navigate away from Assistant and confirm its animation stops.
7. Observe CPU and energy use in Android Studio and Instruments during at least
   one minute of idle animation and one minute of active interaction. Compare
   with the previous release when investigating a regression.

Do not add a dedicated animation preference for the initial release. Revisit
that decision only if device testing or user feedback shows that the platform
reduced-motion preference is insufficient.

## Visual baselines

No golden images are intentionally changed by this feature. The particle field
is deterministic, but animated pixels make full-screen animation goldens poor
release signals; model, layout, interaction, contrast, and profile-mode tests
provide the stable regression coverage instead.

## Phase 4 validation record — 2026-09-08

- macOS 26.6.2 on Apple silicon, profile mode: 317 measured frames; average
  build 0.332 ms; p90 build 0.410 ms; p99 build 1.469 ms; average raster
  0.696 ms; p90 raster 0.969 ms; p99 raster 1.230 ms; zero build or raster
  frames over 16 ms. No particle-bound or repaint-frequency tuning was needed.
- Android 16 physical-device profile APK: built successfully, but the device
  disconnected from ADB before installation. The Android hardware run and its
  manual CPU/energy observation remain release-gate follow-up work.
- Automated foreground validation: all five themes passed at 320x720 and
  1440x900, including semantic exclusion, focus retention, controls, status
  content, and Flutter's text-contrast guideline.
- Relevant Assistant, theme, and navigation suites: 354 tests passed; static
  analysis reported no issues. The macOS profile integration scenario passed.
- Intentional golden or screenshot changes: none.
