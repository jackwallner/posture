---
paths:
  - "Posture/**"
  - "Shared/**"
  - "PostureWatch/**"
  - "PostureWidget/**"
  - "PostureWatchWidget/**"
  - "Tools/Localization/**"
---

# Posture: localization (added 2026-11-04)

The app, widgets and Watch ship in English plus de, es, it, ja, nl and ru (added
2026-11-04, picked from each market's revenue, customers and impressions). A new
language also goes in `CFBundleLocalizations` in each Info.plist, in `LANGS` in
`check.py` and in `LocalizationTests.languages`.

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`, every key with an `en` value). `Shared/` is a source
  of every target, so app, widgets, Watch and tests all compile it. XcodeGen
  2.39+ reads its languages into `knownRegions`.
- App Shortcut phrases live in `Posture/AppShortcuts.xcstrings`, keyed with
  `${applicationName}`, because the system reads them from that table. Their
  `shortTitle` and intent titles are in the main catalog.
- Purpose strings live in `Posture/InfoPlist.xcstrings` and
  `PostureWatch/InfoPlist.xcstrings`, keyed by the plist key. Display names are
  the brand and stay out.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on a
  source literal with no key, a key with no source, a missing `en` value,
  mismatched format specifiers, and plain copy that can reach the screen: a
  `return "..."`, a ternary or `??` of literals, a `case .x: "..."`, an
  assignment, a copy-named argument, a sentence-shaped literal, or a literal
  beside a String expression inside `Text(...)`. Run it before every build that
  touches copy. Identifiers it mistakes for copy go in its `ALLOWED` set.
- `LocalizationTests` proves the catalog compiles to `en.lproj` and that plural,
  substitution, percent and formatter output keep the English wording.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `Section`, `navigationTitle`, `alert` and
  friends localize themselves. Copy held in a `String` (view parameters, enums,
  catalogs, notifications, error messages) must be `String(localized: "...")`.
  Logs, analytics, RevenueCat ids, stored keys and tags stay plain.
- `Text(flag ? "literal" : someString)` compiles to String and shows the literal
  verbatim. Wrap the literal in `String(localized:)`.
- Whole sentences only, never spliced fragments. Branch and give each variant its
  own key (see `doneSubtitle` in `CalibrationView` and `postureTrialCopy` in
  `SubscriptionService`). No `.capitalized` or `.lowercased()` on copy.
- Counts go in plural variations, or a `%#@n@` substitution when the sentence has
  other arguments. A count whose English never changes still carries a plural
  with `other` only, so a translator sees it is a count.
- A count label drawn beside a separately rendered number cannot be a plural key:
  Xcode rejects plural variants that omit the number. `PluralLabel` asks the
  catalog's `"%lld plural category"` key for the CLDR category, then picks one
  whole key per category. The `(few)` and `(many)` keys carry an `en` value so
  English never shows the key.
- Dates, hours, durations, clocks and distances go through `DisplayFormat`. Its
  US English output is the app's wording. Prices come only from StoreKit.
- Never localize stored values, `PostureMode.rawValue`, notification ids,
  `context.state.quality`, or anything written to the store.
- Brand stays untranslated in meaning: Posture, Posture+, AirPods, Apple Watch.

## Proving a change
`python3 Tools/Localization/check.py`, then `gh-sim test --scheme Posture`.

## Language row

Settings has a Language row that names the running localization in itself
(`Bundle.main.preferredLocalizations`) and opens `openSettingsURLString`, Apple's
route for a per-app language change. iOS hides the app's Language option on a
device with one preferred language unless `UIPrefersShowingLanguageSettings` is
YES in `Info.plist`, so keep that key. The simulator's Settings opens at its root
for this link; check the landing on a real iPhone.
