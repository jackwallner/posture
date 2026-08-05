# iOS 27 compatibility audit: Posture

- Audit date: 2026-08-05
- Runtime: iOS 27.0 (24A5390f)
- Xcode: 26.6 (17F113)
- Scheme: `Posture`
- Unit target: `PostureTests`
- Overall: Pass with UI-test concurrency warnings

## Checks

- Debug build: Pass.
- Unit tests: Pass.
- Normal rebuild after tests: Pass.
- Install and launch smoke test: Pass.
- Runtime UI snapshot: Pass. Onboarding and Restore Purchases controls rendered.

## Findings

- `Shared/Services/SubscriptionService.swift:161` contains code after a `return`.
- `PostureWatch/Services/BackgroundPostureWorkout.swift:93` ignores the result of `try?`.
- `PostureUITests/OnboardingUITests.swift`, `ProgressTabUITests.swift`, and `NewUserWalkthroughUITests.swift` contain numerous main-actor isolation warnings.
- No iOS 27-specific compiler error or runtime blocker was observed.

## Recommended follow-up

- Remove or restructure unreachable subscription code, handle the background workout result explicitly, and clean UI-test actor isolation.
