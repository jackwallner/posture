# Constraints

Read before designing.

## Platform

- iOS 17+ only. We can use any iOS 17 API (`@Observable`, SwiftData,
  WidgetKit lockscreen accessories, `.containerBackground`, `.symbolEffect`).
- iPhone-only. No iPad layout. (TARGETED_DEVICE_FAMILY = 1.)
- Portrait orientation only. (`UISupportedInterfaceOrientations`.)
- watchOS 10 companion app — out of scope for this pass.

## SwiftUI

- All UI is SwiftUI. No UIKit screens. (One UIViewRepresentable for the
  camera preview.)
- No third-party UI libraries are in the project. RevenueCatUI is the
  only design-rendering dependency (it renders its own paywall when
  configured). Don't propose components that require new package
  dependencies unless you flag them explicitly.

## Apple HIG

- Native form rows in Settings should stay native unless the redesign
  is overwhelmingly better — system Forms get Dynamic Type, accessibility,
  and edit affordances for free.
- Tab bar is the navigation root (Today / History / Settings). Don't
  redesign into a custom bottom nav unless you propose the system-tab
  alternative explicitly.
- VoiceOver: every visible interactive element needs a sensible label.
  Decorative elements should be marked accessibility-hidden.

## App Store review

- Wellness app, not medical. No claims like "improve your spinal
  alignment" or "reduces back pain." Use language like "build a habit
  of checking your posture."
- "Before / after" photos (a planned Pro feature) must be framed as
  habit-tracking, not clinical evidence.
- The current AirPods background monitoring uses a silent-audio
  workaround to keep CoreMotion alive (`AirpodsBackgroundMonitor.swift`).
  This is a known App Store rejection risk — Engineering may cut the
  feature. **Design shouldn't lean on it being present.**

## Dark mode

- Must work in both light and dark. Semantic neutrals (`Color(.label)`,
  `Color(.systemBackground)`) handle most of it. Brand colors need
  explicit light + dark variants if you change them.

## Dynamic Type

- App must remain usable up to AX5. Don't propose layouts that depend
  on lines staying single-line at large text sizes.

## Performance

- Camera preview is live for 3 seconds in QuickScan and 5+ seconds in
  Calibration — designs should expect 30fps animations during those
  windows and not introduce expensive blur/material effects layered
  over the preview.
- TodayView re-renders on tab changes; SwiftUI bodies are cheap but
  any new animation should be `animation(_:value:)` -keyed.

## Brand / business

- Subscription pricing (placeholder): $4.99/mo, $29.99/yr. Don't bake
  these into the design — RevenueCat pulls them from the dashboard.
- The current "Posture" name and `figure.stand` motif may evolve. Don't
  build the design around the literal stick-figure-standing person.
