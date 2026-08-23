# Posture Coach audit823

Audit date: 2026-08-23

Scope: Posture Coach in /Users/jackwallner/posture only. This is a fresh max-reasoning rerun covering acquisition, downloads, first-use UX, trials, purchases, RevenueCat, ratings, paywalls, experiments, website and legal consistency, production regression signals, and Cursor, Claude, and Codex documentation hygiene.

Change scope: this audit file only. No app code, configuration, metadata, website, scripts, generated assets, commits, or pushes were changed.

Evidence labels used below:

- Observed: directly read from the repository or the existing ASC context snapshot.
- Inference: a likely consequence that needs runtime or live-service validation.
- Unknown: not present in local evidence and should not be guessed by the implementation agent.

## Executive assessment

There is no confirmed production outage in the local evidence, but there are several production-facing issues that should be checked before spending time on broad A/B testing:

1. Price, version, app name, and release-status sources disagree. The local StoreKit catalog says monthly $4.99, yearly $29.99, and lifetime $79.99. The landing page structured data says $2.99, $19.99, and $39.99, and version 1.0.2. The repository project is 1.0.4 build 86. The ASC context snapshot from 2026-08-23 showed app 6768514450, Posture Coach: Sit Straight, version 1.0.4, Ready for Distribution. A stale local state file still says the live version is 1.0.2. This is the highest-confidence acquisition and trust defect.

2. Purchase state handling is inconsistent. SubscriptionService.purchase returns .pending when StoreKit has not yet produced an active entitlement. The main paywall displays a pending message, but the Settings and Today walk flows treat .pending the same as .purchased and dismiss the offer. This can make a legitimate deferred purchase look like a failed or completed flow without a clear next step.

3. The live RevenueCat entitlement identifier is documented in code as a display name rather than the canonical pro identifier. The fallback to any active entitlement currently masks the mismatch, but it will unlock all future active entitlements and makes catalog mistakes hard to detect. Confirm the live entitlement and product mapping immediately.

4. There is no remote funnel or crash telemetry in the repository. AnalyticsService only writes structured events to local unified logging. RevenueCat receives custom paywall impressions, but there is no evidence of a complete trial-start, purchase-result, onboarding, or feature-gate funnel. A Mac watchdog cannot detect live-user crashes from production unless a remote crash or metrics source is added.

5. SwiftData failure handling can destroy local history and then continue with an in-memory store. DataService deletes store files after a load failure and silently falls back to memory. Session saves and several monitor saves use try?. This is a data-integrity and regression risk even when the app does not crash.

6. The product loop is now a daily AirPods practice, not the old camera or all-day-first product described in several documents and website sections. The current implementation has a coherent free practice loop, a no-AirPods fallback, and focused Posture+ gates, but the source-of-truth documentation is mixed with historical camera plans. Agents can make incorrect changes unless this is cleaned up.

No P0 outage is proven by repository evidence. P1 items 1 through 5 above should be treated as same-day confirmation items. Do not call a trial started until an active subscription entitlement is observed, not merely after a CTA tap or a pending StoreKit result.

## Product and evidence inventory

### Current local product shape

Observed in project.yml, Info.plist files, and current source:

- iOS bundle: com.jackwallner.posture.
- Watch bundle: com.jackwallner.posture.watch.
- iOS widget bundle: com.jackwallner.posture.widget.
- Watch widget bundle: com.jackwallner.posture.watch.widget.
- Project and scheme: Posture.
- Deployment targets: iOS 17 and watchOS 10.
- Project version: 1.0.4.
- Project build: 86.
- RevenueCat package: purchases-ios-spm, minimum version 5.71.0 in project.yml.
- iOS includes the local Posture.storekit file and RevenueCat under HAS_REVENUECAT.
- iOS has an App Group entitlement but no HealthKit entitlement. The Watch target has HealthKit and App Group entitlements. This is consistent with the current architecture, where HealthKit is Watch-only.
- iOS declares motion, location, audio background, and Live Activities capabilities. The audio background mode exists to keep headphone motion active and is a material App Review and battery risk.

### ASC evidence

Observed from repository context available for this rerun:

- ASC app ID: 6768514450.
- App Store name in the context snapshot: Posture Coach: Sit Straight.
- Context snapshot date: 2026-08-23.
- Context snapshot status: Ready for Distribution, version 1.0.4.
- A Review Issues link was visible in that ASC context. The Resolution Center and review history were not re-read in this rerun.

Observed in local state, which conflicts with the context snapshot:

- scripts/.asc-state.json says draft 1.0.4, live 1.0.2, updated 2026-08-17T07:08:45Z.
- fastlane/metadata/review_information/notes.txt is written for v1.0.2, build 85.

Inference: .asc-state.json and review notes are stale local snapshots, or ASC has a state discrepancy that needs verification. The implementation agent must pull the live ASC record before making metadata or release decisions.

Unknown:

- Current ASC ratings count, average rating, rating distribution, review volume, review text, and review-issue status.
- Current live screenshot order and product-page configuration.
- Current download, product-page-view, conversion, and source-channel numbers.

### RevenueCat evidence

Observed from shared fleet context:

- Posture RevenueCat project ID: a1790d83.
- The source configures a public RevenueCat key in Shared/Services/SubscriptionService.swift:124-125 and uses entitlement constant pro at line 127.
- No reliable per-project RevenueCat metrics snapshot was captured for this rerun.

Observed in source:

- RevenueCat is configured only on a real device release path. Simulator and debug override paths avoid production RevenueCat customers in SubscriptionService.swift:144-169.
- Products are loaded from the default offering, falling back to current, in SubscriptionService.swift:185-198 and the offering extension near lines 110-113.
- Intro eligibility is deliberately false until RevenueCat confirms it in SubscriptionService.swift:200-218.
- Custom paywall impressions are sent with IDs in SubscriptionService.swift:220-234.

Unknown:

- Live offerings, products, prices, trial duration, eligibility, entitlement IDs, subscription group, package placement, and RevenueCat experiment assignment.
- Trial starts, active trials, trial-to-paid conversion, refunds, cancellations, renewals, MRR, proceeds, and customer counts.
- Whether the live entitlement display-name mismatch documented in source is still present.

### Chrome likes evidence

The requested read-only Chrome inspection was attempted at https://x.com/i/history/likes using the existing Chrome profile. The page did not return a readable state within the browser connection window, so no likes were used as evidence and no lead from likes is claimed here. This is an explicit data gap, not a conclusion that no relevant likes exist.

## Priority register

| ID | Priority | Finding | Evidence | Impact | Required validation |
| --- | --- | --- | --- | --- | --- |
| P1-01 | P1 | Price, version, naming, and release-status sources disagree | Posture.storekit; docs/index.html:23-64,484-486; project.yml; scripts/.asc-state.json; ASC context | Users can see a different price or an apparently unreleased product; search and structured-data trust are weakened | Pull live ASC and RevenueCat catalogs, then compare every displayed and indexed value |
| P1-02 | P1 | Deferred purchase is handled as success in two focused trial flows | SettingsView.swift:424-445; TodayView.swift:526-590 | Pending or Ask to Buy can dismiss the offer without a clear pending state or confirmed feature access | Test pending/deferred StoreKit response and verify UI, entitlement, retry, restore, and analytics |
| P1-03 | P1 | Any active RevenueCat entitlement unlocks Posture+ | SubscriptionService.swift:265-274 | A future unrelated entitlement, misconfigured entitlement, or stale catalog entry can unlock all premium features | Confirm live entitlement IDs, then require an explicit allowlist |
| P1-04 | P1 | No remote production crash or conversion signal | AnalyticsService.swift:4-14; no crash SDK or MetricKit integration found | A Mac cannot alert on live-user crashes, hangs, trial failures, or regression spikes from local logs alone | Choose a remote crash and event source, then test release/build-level alerts |
| P1-05 | P1 | Store-load failure can delete history and fall back silently to memory | DataService.swift; PracticeSessionController.swift save sites | Users can lose visible history or receive a false completion after persistence failure | Simulate corrupted and unavailable stores; verify backup, error state, and no false credit |
| P1-06 | P1 | Silent background audio is a product and App Review risk | AudioKeepAlive.swift; Info.plist; Settings copy | Background monitoring may be rejected, drain battery, or stop while UI says it is enabled | Test interruptions, audio-session failure, device lock, route changes, and review compliance |
| P1-07 | P1 | Trial offer path has ambiguous loading and pending states | OnboardingTrialView.swift; TrialOfferSheet.swift; PaywallView.swift | Product-load failures can look like a trial CTA, while deferred purchase can strand the user | Test offline, no offerings, ineligible user, cancellation, pending, restore, and retry |
| P1-08 | P1 | Review prompt is only tied to acknowledgment moments | AcknowledgmentView.swift:50-54; ReviewPromptTracker.swift; CLAUDE.md | Strong practice completions and level-ups are not used as high-intent positive moments | Trace every positive event and measure prompt display, App Store click, review, and feedback outcome |
| P1-09 | P1 | 49 localized marketing URLs are blank and review notes are stale | fastlane/metadata; fastlane/metadata/review_information/notes.txt | Localized product pages lose a useful landing-page path and reviewers may follow outdated instructions | Query ASC per-locale state and compare submitted metadata with the current build |
| P1-10 | P1 | Current agent instructions mix camera-era and practice-era product truths | CLAUDE.md; docs/MVP_AUDIT.md; docs/POSTURE_EXPANSION_PLAN.md; phasec.md; missing referenced plan | Cursor, Claude, or Codex may reintroduce removed camera architecture or old pricing | Establish one current source of truth and mark historical documents machine-visible as archived |
| P2-01 | P2 | Current funnel has little instrumentation around activation and gates | AnalyticsService.swift contains only a small local event set | A/B decisions will optimize clicks without knowing activation, trial quality, or retention | Add stable event schema and customer-context attributes |
| P2-02 | P2 | Screenshot and ASO source sets conflict | fastlane/screenshots; claude-design/output/store; docs/sim76-screenshots; design handoff docs | A future release can upload the wrong narrative or duplicate seeded screenshots | Declare one canonical source and run dimension, duplication, and copy checks |
| P2-03 | P2 | Support and landing-page copy describe an older flow | docs/support.html; docs/index.html | Users arrive with wrong expectations about onboarding, check-ins, streaks, and pricing | Align website and support copy with the shipped flow, then verify the deployed mirror |
| P2-04 | P2 | No local watchdog or release gate currently exists | No watchdog program found in the requested scope | Regressions depend on manual review and delayed user reports | Build the read-only Mac and fleet checks described below |

## Acquisition and App Store metadata

### Metadata inventory

Observed:

- There are 50 locale directories under fastlane/metadata, excluding review_information.
- Every locale has name.txt, subtitle.txt, keywords.txt, description.txt, promotional_text.txt, support_url.txt, marketing_url.txt, and privacy_url.txt.
- en-US name is Posture Coach: Sit Straight, 27 characters.
- en-US subtitle is Fix Slouch: Neck & Back Care, 28 characters.
- en-US keyword field is 92 characters: tech,text,pain,ergonomic,reminder,spine,desk,habit,airpods,watch,align,stand,upright,monitor.
- en-US promotional text is: A free daily posture practice with live AirPods coaching. Start at 3 minutes, build a streak, and try every level free for 7 days.
- en-US support URL is https://jackwallner.github.io/posture/support.html.
- en-US marketing URL is https://jackwallner.github.io/posture/.
- en-US privacy URL is https://jackwallner.github.io/posture/privacy-policy.html.
- All localized support and privacy URL files contain the same URLs.
- Only the English marketing URL is populated. The other 49 marketing URL files are empty.
- The descriptions include subscription details, free-trial language, auto-renewal, cancellation, management, privacy, and Apple EULA links. This is directionally correct for review requirements, but each localized description still needs a live ASC and native-language QA pass.

Inference and recommendations:

1. The keyword field is not full, and tech, text, and pain may be low-intent or semantically risky compared with terms that describe the current product loop. Run a search-volume and competitor review before replacing them. Do not add medical claims such as treatment, cure, diagnosis, or pain relief.

2. Several localized names and subtitles are materially shorter than the English fields. The observed examples include Japanese at about 11 and 11 characters, Korean at about 10 and 10, Simplified Chinese at about 11 and 8, and Traditional Chinese at about 11 and 8. Apple limits are not violated, but the available discovery surface is underused if those strings are natural and accurate in the target language.

3. A non-English marketing URL should normally point to a localized landing page only if that page exists. If it does not, populate all locales with the canonical English page only after confirming the product-page experience is still coherent. Empty fields are preferable to broken links, but the current state should be an intentional decision recorded in the metadata source.

4. Keep the current distinction between the free daily practice and Posture+ all-day monitoring. The app should not lead acquisition with an all-day promise if background monitoring is disabled by default and the core activation is a bounded practice.

### Metadata and review-information inconsistencies

Observed in fastlane/metadata/review_information/notes.txt:

- Notes say v1.0.2, build 85, while the project is 1.0.4, build 86.
- The notes describe a first-launch flow with a dismissible trial offer after the first completed practice, which matches the current intended direction, but they use old labels such as Continue without AirPods.
- Current source labels the path I don't have AirPods in CalibrationView.swift:241-244,422-430,466-468.
- The notes describe the old release state and should be refreshed before the next review submission.

Validation:

- Pull current ASC review notes and compare them to OnboardingView, CalibrationView, PracticeSessionView, OnboardingTrialView, and the current version/build.
- Have a reviewer follow the exact first-launch path from a clean install, with compatible AirPods, without AirPods, with Motion permission denied, and with an ineligible trial account.
- Include the current Restore Purchases, Terms, Privacy, and subscription disclosure behavior in the notes.

### Screenshot inventory

Observed:

- fastlane/screenshots contains seven PNGs: six phone screenshots at 1320 x 2868 and one Watch screenshot at 416 x 496.
- claude-design/output/store contains ten phone-sized 1320 x 2868 variants.
- docs/sim76-screenshots/final contains many raw simulator screenshots at 1206 x 2622, including onboarding, free, Pro, paywall, walk, and check-in states.
- The repository therefore contains multiple plausible store-image sources and multiple narrative sets. The raw simulator images are not the same dimensions as the canonical App Store phone set.

Acquisition recommendations:

- Declare fastlane/screenshots or one explicitly named replacement as the only upload source. Keep raw simulator captures under a clearly marked non-upload directory.
- The first three store images should make the value proposition legible without requiring the user to understand the entire product: daily practice, live AirPods coaching, and the visible progress or Posture+ benefit.
- Include the no-AirPods fallback in either the product page copy or a later image so users who do not own compatible hardware do not install under a false expectation.
- Do not use older camera-era screenshots or copy. Search all image handoff notes for camera, scan, and body scan before selecting assets.
- Validate every uploaded image dimension, locale, file name, duplicate hash, visible app version, and copy against the current source.

## Download and landing-page funnel

### Current path

Observed current path:

1. Search or browse reaches the App Store product page for app ID 6768514450.
2. The product page promises a daily AirPods-coached posture practice in the current en-US metadata.
3. After install, OnboardingView presents five pages before the user reaches AirPods calibration.
4. Calibration either creates an AirPods baseline or offers a no-AirPods escape after the wait path.
5. The user reaches Today and can start a practice, self-report check-in, or a feature gate.
6. A completed non-Pro practice opens OnboardingTrialView through PracticeSessionView.swift:51-53,511-518 when the first-trial flag has not been seen.
7. Settings, Walk, Watch monitoring, AirPods background monitoring, Progress, and the Posture+ tab expose additional upgrade entry points.

The biggest acquisition issue is not a missing CTA. It is inconsistent product truth between the App Store, website, local price catalog, current build, and review notes.

### Landing page findings

Observed in docs/index.html:

- Canonical URL is https://jackwallner.com/ios/posture/ at line 10.
- App ID is correct at line 11 and the App Store link at line 57 uses id6768514450.
- JSON-LD offers are $2.99 monthly, $19.99 yearly, and $39.99 lifetime at lines 30-48.
- JSON-LD aggregate rating is 5 with count 1 at lines 50-54. No current ASC evidence was captured to support those values.
- JSON-LD software version is 1.0.2 at line 59.
- The main download button says Coming soon on the App Store at line 486, despite ASC context showing Ready for Distribution.
- The hero says all-day monitoring and no check-ins; current code contains a no-AirPods manual check-in mode and a bounded daily practice.
- The page says No onboarding flow, no tutorial at line 607, while current OnboardingView has five pages and calibration.
- The page describes a free trial and subscription plans, but the structured-data prices are inconsistent with the local StoreKit file and need live catalog confirmation.
- The page describes HealthKit in a framework table. That is valid only when clearly scoped to the Watch companion, because iOS has no HealthKit entitlement.

Per the requested scope, the landing page statement about analytics and the RevenueCat purchase path is noted but not escalated as a defect about data-collection disclosure. The priority defects are price, version, status, flow, and feature claims.

Recommended landing-page fixes:

- Make app name, live version, status, prices, trial duration, and feature availability derive from one reviewed source.
- Change Coming soon to the current download CTA only after confirming the live listing is actually available in the intended storefront.
- Replace the old no-onboarding and no-check-in claims with the current daily-practice and no-AirPods behavior.
- Ensure the JSON-LD aggregateRating is removed or refreshed from a verified live source. Do not keep a stale count of one as if it were current.
- Use product copy that states the AirPods hardware requirement early, then explains the manual fallback honestly.
- Add a visible support, privacy, and terms link group in the landing-page footer if not already present in the deployed mirror.

### Landing-page A/B opportunities

| Test | Control | Variant | Primary metric | Guardrail |
| --- | --- | --- | --- | --- |
| Hero promise | Always-on monitoring | Daily practice with live coaching | App Store click-through and install rate | Refunds, early uninstall, support contacts |
| First screen | AirPods-first hero | Practice-first hero with AirPods proof | Product-page click-through | AirPods incompatibility complaints |
| CTA status | Download on the App Store | Start your free posture practice | Click-through | Misleading trial expectations |
| Proof | Feature list | Three-step flow: calibrate, practice, progress | Scroll depth and App Store click-through | Bounce rate |
| Pricing | No price on hero | Live localized starting price, if allowed and accurate | Click-through to install | Price mismatch and legal review |

Keep experiments in the landing page or ASC product-page layer separate from in-app paywall experiments. Record the page version and source channel in the eventual funnel events.

## First-use UX and activation

### Onboarding sequence

Observed in Posture/Views/OnboardingView.swift:

- Five pages are presented through a page-style TabView at lines 16-25.
- The flow teaches the product, asks for posture focus, explains standing and sitting shape, and ends with Set up my baseline.
- The final action sets postureFocus, sets hasAirpods = true, and sets hasCompletedOnboarding = true at lines 31-40.
- Calibration is the next root state after onboarding.

Risk:

- The final onboarding action assumes AirPods before the hardware question is answered. The calibration screen later corrects that state if the user skips, but the interim assumption can affect Today, notifications, and other conditional UI.

Validation:

- Fresh install without AirPods: verify no AirPods-only reminder or live-monitor UI becomes an apparent required path before the six-second escape.
- Fresh install with AirPods already connected: verify the first sample is not missed because isConnected was true before the view observer attached.
- Fresh install with Motion permission denied: verify the user sees Motion access is off, not We need compatible AirPods.
- Record page-level completion and exits. Five pages may be intentional education, but there is no local event proving the drop-off cost.

### Calibration

Observed in Posture/Views/CalibrationView.swift:

- The view supports onboarding, full quick recalibration, and posture-specific standing or sitting recalibration.
- It waits up to 30 seconds for a connection and reveals I don't have AirPods after six seconds at lines 79-83 and 556-587.
- Unsupported hardware and denied permission have separate screens at lines 394-477.
- Onboarding can calibrate only the selected posture focus; the full sequence is available later.
- Each captured pose has a prep, capture, and review state. The user can redo a read. Slouch reads can be skipped to use a standard range.
- Capture requires at least ten pitch samples in a roughly two-second window at lines 721-750.
- The no-AirPods path saves a neutral calibration, marks hasAirpods = false, and sets calibrationDeferred = true at lines 601-620.
- A completed AirPods calibration sets hasAirpods = true, clears the deferred flag, and records calibrate_completed at lines 760-827.

UX opportunities:

- Test whether the six-second no-AirPods escape should appear earlier or as an explicit hardware choice before onboarding completion. This is especially important for download growth from users who do not own supported AirPods.
- Add a clear estimate of calibration duration and explain that the user can start the no-AirPods check-in loop if hardware is unavailable.
- Log calibration start, each step shown, redo, skip, timeout, permission denial, unsupported hardware, and completion. The current AnalyticsService only has start and complete helpers.
- Give the calibration completion screen a direct first-practice CTA and an explicit expectation about the three-minute first session.
- Test whether requiring a full calibration before any first value produces more activation than offering a short manual practice first. This is a product experiment, not a recommendation to remove calibration without evidence.

### Current value loop

Observed in Shared/Services/PracticeProgression.swift:

- Session length begins at 180 seconds and grows by 60 seconds per level, capped at 900 seconds.
- The target begins at 50 percent and grows by 3 percentage points per level, capped at 80 percent.
- The free tier cap is level 2, not level 5. This contradicts older phasec.md language.
- Passed sessions advance the level. Completing duration credits the streak.

Observed in PracticeSessionView.swift and SessionSummaryView.swift:

- The first completed non-Pro practice can open the dismissible onboarding trial offer.
- The session teaches a ring, a deliberate slouch, and the hold before the main practice.
- The summary exposes target, level, streak, and achievement outcomes.

Activation events that should be defined:

install_or_first_launch, onboarding_page_viewed, onboarding_completed, focus_selected, calibration_started, calibration_step_completed, calibration_redone, calibration_skipped, calibration_deferred, calibration_completed, first_value_reached, practice_started, warmup_completed, warmup_skipped, practice_paused, practice_resumed, practice_cancelled, practice_completed, practice_target_passed, level_up, paywall_viewed, trial_cta_tapped, trial_started, purchase_pending, purchase_cancelled, purchase_failed, purchase_completed, restore_attempted, restore_completed, review_prompt_shown, review_yes, review_feedback, and review_link_opened.

Do not count trial_cta_tapped, .pending, or a paywall impression as trial_started. The reliable trial-start definition should be a verified active introductory subscription entitlement or a RevenueCat transaction event confirmed by the backend.

## Trial, purchase, and paywall audit

### RevenueCat integration

Observed in Shared/Services/SubscriptionService.swift:

- Production device release configures RevenueCat and asynchronously refreshes customer info and offerings.
- Products use the default offering first and current offering second.
- Product loading failures set a user-readable lastError, but only the view displaying the error can expose it.
- Intro eligibility is false until eligibility is confirmed, which is a good protection against promising a trial to an ineligible customer.
- Custom paywall impression IDs are sent to RevenueCat and local analytics.
- Purchase attempts and completed purchases are logged locally. Completion is only logged when isProSubscriber becomes true.
- applyProStatus accepts the canonical pro entitlement or any non-empty active entitlement.

P1 entitlement issue:

- The comment at lines 265-270 says the live RevenueCat entitlement is currently configured as Posture Check - Active Daily Pro, described as a display name rather than pro.
- The code therefore uses !active.isEmpty as a compatibility fallback.
- This prevents a known lockout today only if the comment is accurate, but it makes every future active entitlement a Posture+ grant.

Required fix direction for the implementation agent:

1. Pull the live RevenueCat entitlement identifiers and product mappings for project a1790d83.
2. Rename the live entitlement to a stable ID if that can be done without breaking existing customers, or define an explicit allowlist of every intended premium entitlement ID.
3. Add a diagnostic event when the expected entitlement is absent after a successful transaction, instead of silently treating an arbitrary active entitlement as valid.
4. Test lifetime, monthly introductory purchase, yearly introductory purchase, restore, cancellation, expired subscription, deferred purchase, and a customer with an unrelated active entitlement.

### Local StoreKit and live price source

Observed in Posture.storekit:

- com.jackwallner.posture.pro.lifetime, local display price $79.99.
- com.jackwallner.posture.pro.monthly, $4.99, one-month period, seven-day free trial.
- com.jackwallner.posture.pro.yearly, $29.99, one-year period, seven-day free trial.

Observed in PaywallView.swift:

- The custom SwiftUI paywall uses localized StoreKit product prices.
- Yearly, monthly, and lifetime packages are shown as plan cards.
- Yearly is marked best value and savings are computed from localized annual and monthly prices.
- Trial reassurance shows no payment today, reminder day, billing day, and the auto-renew disclosure.
- The paywall has Restore, Terms, and Privacy links.
- Empty offerings show a retry state rather than a purchase CTA.

Unknown: whether the local StoreKit catalog matches the live RevenueCat and ASC catalog. Do not update website or metadata prices from the local file alone. The implementation agent must capture the live US price and at least one non-US localized price from the live product catalog.

### Purchase-state bug

Observed in SubscriptionService.purchase:

- A purchase attempt is recorded before StoreKit purchase.
- Cancellation returns .cancelled.
- If the customer info does not yet show an active entitlement, the method returns .pending.

Observed in PaywallView.swift:

- .pending stays on the paywall and shows a restore or pending message. This is the most honest of the current paths.

Observed in SettingsView.swift:424-445:

- The direct trial purchase switch groups .purchased, .pending and closes showTrialOffer.

Observed in TodayView.swift:526-590:

- The walk-gate direct purchase switch also groups .purchased, .pending and closes the trial sheet.

Observed in OnboardingTrialView.swift:

- The direct purchase switch groups .purchased, .pending without an explicit pending message or direct continuation. Its later isProSubscriber observation only proceeds when the entitlement becomes active.

Inference:

- A deferred or delayed entitlement can dismiss Settings or Walk without enabling the requested feature, while the first-practice trial flow can remain visually ambiguous. This is a conversion and trust defect, not evidence that a customer is incorrectly granted Pro.

Required behavior:

- .purchased: confirm active entitlement, close the sheet, apply the requested feature, and record purchase_completed.
- .pending: keep the sheet or show a dedicated pending state with the exact next step, do not call it a trial start, do not apply the feature, and offer Restore or retry after a bounded refresh.
- .cancelled: preserve the user's place and state that no purchase was made.
- Error: show a retryable error with the source category, not a generic dead end.
- On app foreground and after purchase return, refresh customer info and offerings once before deciding the final state.

### Trial offer path

Observed in OnboardingTrialView.swift:

- The intended offer is shown after the first completed practice.
- It tracks posture_onboarding_trial as a custom paywall impression.
- The yearly intro-eligible package is preferred when available.
- The primary copy says the daily practice is free forever and Posture+ can be tried for seven days.
- The screen has a Keep the free practice escape and a legal footer.
- If no direct intro-eligible package is loaded, it falls through to the full paywall.

Observed in TrialOfferSheet.swift and SettingsView.swift:

- Feature-gate entry points lead with a focused trial sheet.
- When no direct purchase package exists, the sheet is still visually capable of showing a Start My Free Trial CTA, but the action routes to the full paywall.
- In that state, offer label and price can be absent.

P1 UX issue:

- A CTA that says Start My Free Trial while no direct trial package is available is misleading. Use See Posture+ plans or equivalent when direct purchase is false, and show the reason the full paywall is needed.

### Paywall entry points and impression IDs

Observed gate IDs:

| Entry | Impression ID or source | User intent |
| --- | --- | --- |
| First completed practice | posture_onboarding_trial | Continue a successful practice |
| Posture+ tab | posture_pro_tab | Explore premium value |
| Settings focused offer | posture_settings_sheet or feature-specific ID | Enable a feature |
| Progress tab | posture_progress_tab | See locked program depth |
| Walk gate | posture_walk_gate | Start a walk |
| Quiet AirPods background | posture_airpods_background_gate | Turn on background monitoring |
| Always-on Watch | posture_always_on_watch_gate | Enable Watch nudges |

The source uses a custom SwiftUI paywall, not a RevenueCat-hosted native paywall view. RevenueCat custom impression tracking is present, but no evidence of a live RevenueCat Paywall experiment or remote variant assignment was found in the repository.

## A/B test plan

Do not run tests until the source-of-truth price and entitlement checks pass. Every test needs a persistent assignment, an entry-point ID, an offer-eligibility flag, a selected product ID, and a verified outcome.

| ID | Hypothesis | Control | Variant | Primary metric | Guardrails |
| --- | --- | --- | --- | --- | --- |
| A1 | Immediate value creates more qualified trial starts than delayed upsell | Offer after first completed practice | Offer after a second completed practice, with a feature-gate offer available earlier | Verified trial starts per activated install | Practice completion, D7 retention, refunds |
| A2 | A focused offer preserves intent better than a full plan wall | Full PaywallView | Focused TrialOfferSheet for walk, Watch, or background feature | Gate-to-trial conversion | Dismissal, restore errors, support contacts |
| A3 | Annual trial is the clearest default | Yearly selected first | Monthly selected first | Verified trial starts and paid conversion | Revenue per install, cancellation before billing |
| A4 | A lower-commitment lifetime option improves trust | Lifetime secondary | Lifetime visible but framed as one-time unlock with savings context | Paywall purchase completion by plan | Price comprehension and plan switching |
| A5 | Outcome-focused copy beats feature inventory | Feature list order in PaywallView | Put daily practice, levels, and weekly trends before background features | Paywall CTA rate and trial starts | Refunds, retention, feature activation |
| A6 | Feature-specific copy reduces irrelevant upgrade traffic | Generic Posture+ copy | Walk, Watch, background, and Progress-specific benefit copy | Gate conversion | Repeated paywall impressions per user |
| A7 | A visible free-cap explanation reduces frustration | Blurred progress and generic unlock banner | Show level 2 cap, what remains free, and what Pro unlocks | Progress-to-trial conversion | Free-practice completion and review sentiment |
| A8 | Hardware choice earlier reduces calibration abandonment | AirPods assumption followed by calibration | Ask whether compatible AirPods are available before calibration | Onboarding completion and first-value rate | AirPods activation and no-AirPods check-in use |
| A9 | Landing-page practice framing is broader than monitoring framing | Current always-on hero | Daily practice hero with AirPods proof and no-AirPods honesty | App Store click-through and install rate | Misunderstanding complaints |
| A10 | Review requests after success outperform generic settings requests | Current eligibility plus acknowledgment | Add successful practice target, level-up, or streak moments | Native prompt eligibility and review conversion | Negative feedback rate, prompt cooldown compliance |

Implementation details:

- Persist the experiment assignment before the paywall is shown. Do not assign a different arm on every SwiftUI render.
- Use the existing paywall impression IDs as the entry-point dimension, not as the experiment arm.
- Separate direct trial CTA taps, StoreKit pending results, active intro entitlement, and first paid renewal.
- Keep legal disclosure identical across arms unless legal review approves a copy change.
- Do not optimize for raw paywall CTA taps at the expense of practice completion, trial-to-paid conversion, refunds, or early churn.

## RevenueCat customer attributes and event schema

### Current state

Observed:

- No setAttributes, setAttribute, setCustomerAttributes, or equivalent customer-attribute writes were found in the repository.
- AnalyticsService writes only to os.Logger under subsystem com.jackwallner.posture.
- Current local events do not include onboarding completion, calibration failure, gate source, trial CTA, pending purchase, restore, review, product-load failure, or app version.

This means the implementation agent cannot currently answer which entry point produces trials, whether no-AirPods users activate, or whether a release caused a purchase or calibration regression from the production app alone.

### Recommended coarse customer context

Use customer attributes for slowly changing, low-cardinality state. Use an event system for transitions. Do not send raw posture angles, motion samples, health data, photos, or free-form user text.

| Attribute | Values | Write point | Why |
| --- | --- | --- | --- |
| app_version | Semantic version | SubscriptionService.configure and foreground refresh | Segment release regressions |
| app_build | Build number | Same | Separate build from marketing version |
| posture_focus | standing, sitting, both | After OnboardingView focus selection and completion | Compare activation by use case |
| has_airpods | true, false, unknown | After calibration or no-AirPods escape | Identify hardware friction |
| calibration_state | not_started, deferred, completed, permission_denied, unsupported | Calibration transitions | Diagnose activation loss |
| calibration_confidence_bucket | low, medium, high | After calibration save | Correlate quality with retention without raw motion |
| current_level | Integer or bounded bucket | After completed practice | Understand progression friction |
| free_cap_reached | true, false | When level reaches 2 | Attribute Progress paywall intent |
| passed_session_bucket | 0, 1, 2-4, 5+ | After session finish | Measure qualified activation |
| paywall_entrypoint | Existing impression ID | Immediately before showing a paywall | Segment trial and purchase outcomes |
| trial_offer_eligible | true, false, unknown | After eligibility response | Explain direct versus full-paywall paths |
| selected_plan | monthly, yearly, lifetime | On selection, or event only | Compare plan choice |
| watch_state | not_paired, paired, enabled, error | Watch sync transitions | Diagnose Watch gate demand |
| notification_permission | authorized, denied, not_determined, provisional | Permission refresh | Explain reminder activation |
| last_practice_age_bucket | same_day, 1-3_days, 4-7_days, 8+_days | App foreground, debounced | Identify reactivation cohorts |
| last_error_category | Bounded categories only | On product, entitlement, calibration, or persistence failure | Alert on experience failures |

Recommended write locations:

- Add one debounced context-sync method in SubscriptionService, called after RevenueCat configuration, after customer info refresh, and after important GoalSettings or calibration transitions. Do not set attributes in every SwiftUI body evaluation.
- Call context sync after OnboardingView writes focus and completion.
- Call it after CalibrationView.save and skipWithoutAirpods.
- Call it after PracticeSessionController successfully persists a session and after a failed save.
- Set paywall_entrypoint before the view sends the custom paywall impression. Keep it separate from paywall_variant.
- Record plan selection and purchase outcomes as events. A persistent customer attribute should not be the sole source for a sequence of purchases.
- On purchase, restore, pending, and entitlement refresh, record the result category and expected entitlement presence.

Privacy and data minimization:

- Keep all values coarse and operational.
- Do not use attributes as a substitute for a clear privacy review.
- The requested scope excludes a defect report about RevenueCat versus data-not-collected wording. That exclusion does not change the recommendation to avoid raw posture or health data in telemetry.

## Ratings and review funnel

### Current implementation

Observed in Shared/Services/ReviewPromptTracker.swift:

- Launches, positive moments, first-open date, last-shown date, outcome, and cooldown state are stored in the App Group.
- Eligibility requires at least five launches, seven days since first open, three positive moments, no prior outcome, and a 120-day cooldown.
- The tracker has separate states for enjoyment, App Store review, and feedback.

Observed in Posture/Views/ReviewPromptSheet.swift:

- The first sheet asks whether the user is enjoying Posture.
- A positive answer leads to the native review request after dismissal.
- A negative answer leads to feedback composition.
- The direct App Store link uses AppStoreReviewLinks.writeReviewURL with app ID 6768514450 and action=write-review.

Observed in Posture/App.swift:

- The prompt is scheduled after posturePositiveMomentForReview and when the user changes to Today.
- The native request is delayed after the sheet outcome.

Observed call site:

- AcknowledgmentView.swift:50-54 records a positive moment only when the acknowledgment flow marks earnedReviewPositiveMoment.
- A repository search found AnalyticsService.streakMilestone, but no call site that posts a review-positive event after a completed practice, passed target, level-up, or streak milestone.

Mismatch:

- CLAUDE.md says the review funnel should use a good scan or streak milestone at 7, 14, 30, 60, or 100 days. The current call-site evidence supports acknowledgment-based positive moments, not the full documented promise.

Recommendations:

- Keep the current three-positive-moments, seven-day, and 120-day guardrails.
- Add a positive moment only after a completed practice with a successful target, a level-up, or a meaningful streak milestone. Do not prompt after a canceled or failed session.
- Add event capture for prompt shown, enjoyment answer, native request attempt, App Store URL open, feedback composer open, mail failure, and result when available.
- Keep Settings Rate or Send Feedback as an explicit user-initiated path.
- Inspect ASC Review Issues before the next submission, since a review-issue link was visible in the context snapshot.
- Pull current ASC rating and review counts before quoting ratings anywhere in the landing page or marketing material.

Unknown: current public rating, review count, recent review themes, and whether the native request has been shown at the expected rate. No values are invented here.

## Feature gates and UX conversion surfaces

| Feature | Gate ID | Current entry | Current user intent | Improvement opportunity |
| --- | --- | --- | --- | --- |
| Walk mode | posture_walk_gate | Today walk card | Start a walk now | Keep the trial pitch specific to walking and explain the 30-second walking baseline |
| Quiet AirPods background | posture_airpods_background_gate | Settings toggle | Enable background monitoring | Explain battery, orange indicator, and what happens when audio activation fails |
| Always-on Watch | posture_always_on_watch_gate | Settings toggle | Enable haptic Watch nudges | Explain pairing, HealthKit-on-Watch requirement, and first sync |
| Full Progress | posture_progress_tab | Progress banner and locked details | See deeper program progression | Explain level 2 free cap and show concrete remaining value |
| Posture+ tab | posture_pro_tab | Main tab for non-Pro users | Explore all premium value | Use as broad exploration, not the only conversion path |
| Settings offer | posture_settings_sheet or feature ID | Locked Pro toggle | Enable a feature in context | Preserve the selected feature when purchase becomes active |

Observed positives:

- All-day monitoring is opt-in and off by default.
- Free users retain an in-app live readout and a no-AirPods manual check-in loop.
- The current Settings copy explains that silent audio is used and no audio is recorded.
- The focused feature gate preserves intent better than a generic upgrade prompt in principle.

Risks to validate:

- The feature is described as Posture+ in Settings, while metadata and source comments contain old Posture Check names.
- A user who starts a focused purchase and gets .pending can lose the original feature context.
- Walk setup and baseline requirements need an explicit failure path when AirPods disconnect.
- The Pro tab and Progress tab can create multiple paywall impressions during navigation. Check whether oncePerSession is used at every intended surface and whether repeated impressions are meaningful.

## Production crash, watchdog, and regression signals

### What exists today

Observed:

- AnalyticsService emits local structured logs under com.jackwallner.posture, category analytics.
- AirpodsBackgroundMonitor keeps in-memory connection, sample, monitoring, and error state, and persists minute aggregates through SwiftData.
- PracticeSessionController logs session starts, pauses, resumes, cancellations, and completion locally.
- NotificationService schedules reminders and ReminderScheduler reschedules after settings changes.
- ActivityKit cleanup runs on app launch for orphaned practice activities.
- The simulator path avoids production RevenueCat customers and uses local StoreKit/debug overrides.

Not found:

- Crashlytics, Sentry, Bugsnag, MetricKit collection, a remote event endpoint, or a remote log upload path.
- A production crash-free session metric.
- A launch hang, watchdog termination, memory warning, audio-session failure, or SwiftData failure alert that reaches the owner.
- A release/build comparison for trial starts, revenue, ratings, or purchase failures.

Conclusion:

- A Mac script can monitor ASC, RevenueCat, GitHub Actions, the landing page, and locally generated test results. It cannot detect a live-user crash by itself from this app. A remote crash source or a server-side aggregation endpoint is required for that requirement.

### Concrete local regression risks

#### Data persistence

Observed in Shared/Services/DataService.swift:

- The persistent store is created with SwiftData.
- On load failure, the implementation attempts store recovery and can delete store files before falling back to an in-memory container.
- Critical errors are logged, but the user is not clearly told that history may be unavailable.

Observed in PracticeSessionController.swift and monitor services:

- Session and minute persistence uses try? at multiple save sites.
- The UI can still show a completion or current in-memory state when a save fails.

Validation:

- Run with a read-only or corrupted store copy.
- Disconnect storage or force a save error in a test build.
- Verify that the app does not delete the only recoverable history without a backup or user-visible warning.
- Verify that a failed session save does not advance a level or streak without a durable receipt.

#### Background monitor state

Observed in Shared/Services/AirpodsBackgroundMonitor.swift and AudioKeepAlive.swift:

- Background monitoring depends on a silent AVAudioEngine path.
- If audio setup fails, the monitor records an error and returns. The monitor state can still appear armed unless the caller clears it.
- The shared monitor and foreground scan coordinate by suspending and resuming ownership of the headphone-motion stream.

Validation:

- Force audio-session activation failure.
- Test AirPods insertion after the app starts, removal during a session, route changes, phone lock, incoming audio interruption, Bluetooth changes, and app foregrounding.
- Assert that isMonitoring, isConnected, lastSampleAt, and visible Today copy agree.
- Add a watchdog condition for monitoring enabled with no new sample after a bounded interval.

#### Review and permissions

Observed:

- Notifications denied state is surfaced in Settings and includes an allow action.
- Motion denial has a dedicated calibration state.
- The Watch target has HealthKit strings and entitlements; the iOS target does not.

Validation:

- Test first permission denial, later Settings grant, and app return.
- Test notification denial after a reminder is enabled.
- Test Watch pairing and HealthKit denial without making iOS appear to require HealthKit.

#### Audio and App Review

Observed:

- Info.plist declares UIBackgroundModes audio.
- AudioKeepAlive.swift plays a very quiet or silent engine to keep the AirPods sensor delivering motion.
- Support and Settings explain the orange indicator and silent audio.

Inference:

- This may work technically but remains a review and user-trust risk because the background audio mode is not used for audible media. Treat it as a release gate, not just documentation.

Validation:

- Confirm the exact App Review justification and current Apple policy interpretation before the next submission.
- Measure battery impact on a physical device over a normal workday.
- Verify the feature is opt-in, visibly indicated, and completely off after purchase restoration or reinstall until the user enables it.

### Watchdog program specification

No script is created in this audit because the current request explicitly limits writes to audit823.md. The eventual Mac program should be read-only by default and configurable through environment variables or a small ignored config file.

Recommended checks:

1. App identity: bundle ID, ASC app ID, marketing version, build, app name, and release status.
2. Metadata: every locale has required fields, length limits, legal footer, valid URLs, current product name, current trial wording, and intentional marketing URL state.
3. Price consistency: live RevenueCat or StoreKit catalog versus local StoreKit, App Store metadata, website JSON-LD, and review notes.
4. Entitlement consistency: expected product IDs map to one explicit premium entitlement, with no unknown active entitlement accepted.
5. Trial funnel: daily trial starts, pending purchases, purchase failures, active intro entitlements, conversion, renewal, refund, and cancellation thresholds.
6. Crash and hang: crash-free users, crash-free sessions, launch failures, fatal exceptions, hangs, memory terminations, and background task failures by build. This requires a remote source.
7. Paywall health: product-load error rate, empty offerings, eligibility lookup failures, paywall impression counts by entry point, and CTA-to-entitlement conversion.
8. UX health: calibration timeout rate, no-AirPods escape rate, practice start and completion rate, session cancellation, audio-monitoring no-sample rate, and restore success.
9. Reviews: new one-star and two-star review spikes, review themes, and ASC Review Issues.
10. Website: HTTP status, canonical and App Store link, deployed mirror freshness, JSON-LD version and prices, and legal-link status.
11. CI: GitHub Actions sync-landing-page.yml success, because it mirrors docs/** into the portfolio site and can leave the public page stale if it fails.
12. Local release test: headless simulator UI test result, local StoreKit product-load result, and a physical-device TestFlight smoke-test checklist.

Alert policy:

- Alert only on a threshold crossing or a changed state, not every poll.
- Include app version, build, time window, baseline, current value, affected entry point, and a direct dashboard link.
- Keep a local state file with last alert values and cooldown timestamps.
- Email scaffolding is reasonable, but do not put App Store or RevenueCat secrets in command-line arguments or committed files.
- Do not claim a crash signal exists until a remote crash source is connected and a test crash is visible in the dashboard.

## Website, terms, privacy, and release consistency

| Source | Observed current state | Consistency issue | Priority |
| --- | --- | --- | --- |
| docs/index.html | App ID and canonical URL are correct | Prices, version, Coming soon, no-onboarding, no-check-in, and rating data are stale or unverified | P1 |
| docs/privacy-policy.html | Updated August 17, 2026; describes on-device posture data and RevenueCat purchase processing | More current than support and landing page; verify links and deployed mirror | P2 |
| docs/terms.html | Updated August 17, 2026; wellness disclaimer, subscriptions, trial, renewals, refunds, and restore | Recheck prices are intentionally omitted and legal links match paywall | P2 |
| docs/support.html | Updated July 4, 2026; AirPods, Watch, notifications, and subscriptions | Streak troubleshooting says monitored minutes sync, while current streak is based on practice or acknowledgment logic | P1 |
| fastlane/metadata/* | 50 locales with required files | Marketing URL blank in 49 locales, release notes and review notes need current version audit | P1 |
| scripts/.astro-app.json | App ID is correct; temporary is false | Name is Posture Check: Neck & Back, while current app name is Posture Coach: Sit Straight; synced July 27 | P1 |
| scripts/.asc-state.json | Draft 1.0.4 | Live version says 1.0.2, conflicting with ASC context Ready for Distribution 1.0.4 | P1 |
| .github/workflows/sync-landing-page.yml | Mirrors docs/** into the portfolio repository on main pushes | External mirror can become stale without an alert | P2 |

Legal and product language to validate:

- Keep the wellness framing in docs/terms.html and avoid claims to diagnose, treat, cure, or prevent.
- Keep the Apple standard EULA and privacy links available from every purchase surface.
- Add a Terms link to Settings if users can currently reach only Privacy from the Help section. The paywall has Terms and Privacy, but Settings only exposes Privacy at SettingsView.swift:219-225.
- Keep support instructions aligned with the current streak source. Current StreakService and AcknowledgmentView indicate that a reminder acknowledgment or completed daily practice, not merely opening the app with AirPods, is what matters.
- Explain the no-AirPods path on support pages, since it is a real current product mode.
- Verify the public deployment at both https://jackwallner.github.io/posture/ and https://jackwallner.com/ios/posture/. The repository workflow says the latter is mirrored into the portfolio repository.

## Agent documentation hygiene

### Current and stale sources

Observed in CLAUDE.md:

- The opening description still says the app uses the iPhone camera and later AirPods at line 3.
- Lines 12-13 describe Vision face detection and an AVFoundation camera pipeline.
- Later lines, including line 24, correctly state that there is no camera or Vision pipeline and that the current core is the AirPods practice and self-report check-in loop.
- Lines 49-50 still describe an old plan with a camera-first Phase 1.
- The file references /Users/jackwallner/.claude/plans/plan-first-floating-pretzel.md, which does not exist.
- The file says the review funnel includes good scans and streak milestones, which is not supported by current call sites.

Observed in other documents:

- docs/MVP_AUDIT.md is a historical camera and reminder audit. Several findings are now fixed or obsolete, including camera QuickScan, old session model, iOS HealthKit mismatch, one-shot reminders, and old reminder caps. Its background-audio and data-integrity concerns remain relevant.
- docs/POSTURE_EXPANSION_PLAN.md describes a camera, Vision, SessionEngine, and older architecture that does not match the current code.
- phasec.md describes the practice pivot but says the free cap is level 5. Current PracticeProgression.freeLevelCap is level 2.
- aso-plan.md and docs/astro-aso-setup.md contain old Astro placeholder or pre-launch instructions and old product names. The local Astro state has app ID 6768514450 but an old name.
- docs/localization-aso.md refers to ASC version 1.0 in PREPARE_FOR_SUBMISSION, while current local project metadata is 1.0.4 build 86.
- docs/app-store-screenshots-handoff.md contains camera-era screenshot copy and an older narrative. claude-design/CAPTURE-LIST.md, claude-design/SCREENSHOT-PROMPT.md, and claude-design/scripts/compose-screenshots.py also need one declared source of truth because they describe different screenshot sequences.
- archive/README.md clearly says archive material is historical, which is good, but broad agent searches can still ingest it. Historical files should have a machine-readable archived marker or live under an explicitly excluded archive path.

### Cursor, Claude, and Codex view

Observed:

- AGENTS.md is a symlink to CLAUDE.md, so the shared root instructions are unified for tools that read either file.
- .claude/skills/posture-architecture/SKILL.md is tracked.
- .agents/skills/posture-architecture/SKILL.md is untracked, is a separate regular file rather than a symlink, and is byte-identical to the tracked .claude copy at audit time.
- No repository-specific .cursor/rules directory was found.
- The untracked .agents tree will not reliably be present for another agent or a clean checkout.

Recommended source-of-truth layout:

~~~text
CLAUDE.md                         small, current product and agent contract
AGENTS.md -> CLAUDE.md            compatibility symlink
.claude/skills/...                tracked Claude/Codex skill source
.cursor/rules/...                 optional Cursor-specific adapter, if needed
docs/current/...                  current product, release, ASO, and legal references
docs/audits/...                   dated audits and findings
docs/archive/...                  historical plans, clearly marked and excluded from current instructions
~~~

Recommended cleanup order:

1. Rewrite the top of CLAUDE.md as a short current-state contract: AirPods practice, no camera, no-AirPods fallback, level 2 free cap, current bundles, current paywall IDs, and current release process.
2. Remove or clearly label the old camera paragraphs and old phase references.
3. Replace the missing external plan reference with a tracked current plan or a path that is intentionally optional.
4. Keep exactly one tracked architecture skill source. If both Claude and agents directories must exist, generate or symlink one from the other and add a consistency check.
5. Add a Cursor rule adapter if Cursor is expected to work in this repo. It should point to the same current-state facts and should not duplicate long architecture text.
6. Move historical audits and expansion plans under docs/archive or add an archived: true frontmatter marker. Do not delete them as part of this audit.
7. Add a small docs/current/source-of-truth.md covering live product IDs, prices, entitlements, legal URLs, screenshot source, and release status. Update the implementation agent and watchdog to read it.

## Validation plan for the implementation agent

### Live catalog and metadata

- Pull ASC app status, version, build, all submitted locale metadata, screenshots, ratings, reviews, and Review Issues for app 6768514450.
- Pull RevenueCat project a1790d83 offerings, products, entitlements, trial eligibility configuration, and experiments.
- Compare live product IDs and localized prices against Posture.storekit, PaywallView, website JSON-LD, App Store metadata, review notes, and any release scripts.
- Decide the canonical app display name and remove old Posture Check and camera-era names from active sources.

### Headless simulator and local StoreKit

Follow the repository iOS rules:

- Lease a shared headless simulator through agent-sim checkout posture and release it afterward.
- Never use a named simulator destination and never open Simulator.app.
- Never use the production RevenueCat key in a simulator run.
- Use local StoreKit configuration or the debug Pro override for UI exploration.

Run these scenarios:

1. Fresh install, complete every onboarding page, AirPods unavailable, use the six-second escape.
2. Fresh install, Motion permission denied, open Settings, grant permission, return, and retry.
3. Compatible AirPods connected before launch and connected after launch.
4. Calibration redo, slouch skip, disconnect during capture, and partial recalibration.
5. First practice start, warmup skip, pause, resume, cancel, successful completion, target pass, level-up, and first trial sheet.
6. Offerings loading, no offerings, offline retry, trial-eligible account, trial-ineligible account, and restored purchase.
7. .cancelled, .pending, StoreKit error, and active entitlement arriving after a delay.
8. Walk gate, background monitoring gate, Watch gate, Progress gate, and Settings gate, ensuring the feature intent is preserved through purchase.
9. Notification denial, Motion denial, AirPods removal, app backgrounding, phone lock, audio interruption, and return to foreground.
10. SwiftData corruption and save failure in a controlled test build.

A simulator cannot prove real headphone motion, background audio, Watch HealthKit, or live StoreKit behavior. Those require a physical device and a TestFlight build.

### Physical-device release validation

- Run the same path with supported AirPods and without AirPods.
- Test iPhone lock, Bluetooth route changes, AirPods insertion and removal, audio interruption, Watch pairing, and battery usage.
- Verify a real eligible monthly and yearly introductory purchase, a canceled purchase, a deferred purchase if available, restore, expiration, and entitlement refresh.
- Confirm that the app never reports a trial start before the active entitlement is visible.
- Capture a build/version and a short outcome log for the watchdog baseline.

### Website and CI validation

- Check both public URLs and compare deployed HTML to docs/index.html, docs/support.html, docs/privacy-policy.html, and docs/terms.html.
- Validate JSON-LD prices, version, rating, app ID, canonical URL, and download URL.
- Validate every legal link and locale URL.
- Verify .github/workflows/sync-landing-page.yml succeeds after any docs/** change.
- Alert if the portfolio mirror is older than the latest app-repository docs commit.

## Recommended implementation order

1. Confirm the live ASC and RevenueCat catalog, entitlement IDs, prices, trial configuration, status, ratings, and Review Issues.
2. Fix pending purchase state handling in Settings, Walk, and the first-trial flow. Add explicit purchase-result instrumentation.
3. Replace the any-active-entitlement fallback with an explicit entitlement allowlist and a diagnostic for mismatches.
4. Reconcile website JSON-LD, landing-page status, version, prices, rating data, onboarding claims, check-in claims, app name, and support instructions.
5. Refresh ASC review notes and verify the current submitted metadata and screenshot set.
6. Add the coarse RevenueCat customer context and a remote event or crash source. Keep raw posture and health data out of telemetry.
7. Make persistence failure visible and recoverable before optimizing conversion. Do not delete the only store copy without a backup or explicit recovery path.
8. Instrument the current review funnel and add positive practice, target, level, and streak moments under the existing cooldown rules.
9. Run the headless simulator matrix, then physical-device TestFlight validation for audio, AirPods, Watch, StoreKit, and persistence.
10. Clean the agent documentation and establish the current source-of-truth layout.
11. Build the read-only Mac watchdog and fleet consistency checker only after the live API sources and thresholds are defined.
12. Run A/B tests in the order A1, A2, A6, A3, and A5, with verified entitlement conversion and retention guardrails.

## Evidence ledger and unresolved questions

### High-confidence observed facts

- Current code is AirPods-practice-first and has no active iPhone camera/Vision path.
- No-AirPods users can defer calibration and use manual check-ins.
- Free progression caps at level 2 in current source.
- The custom SwiftUI paywall shows yearly, monthly, and lifetime options and uses localized product prices.
- RevenueCat custom impression tracking exists, but customer attributes and remote funnel events do not.
- The review tracker has meaningful guardrails, but its positive event call site is narrow.
- The landing page and several release documents are stale relative to the current code.
- Current local worktree contains unrelated untracked screenshots and scripts. They were not modified.

### Inferences that require confirmation

- The local Astro and ASC state files are stale rather than evidence of a live ASC problem.
- The live RevenueCat entitlement display-name mismatch is still present.
- The landing page is currently deployed with the stale HTML shown in the repository.
- The pending purchase paths have been observed by real users.
- The audio keep-alive path causes battery or App Review problems in the current live build.

### Unknowns the next agent must answer

- What are the current live monthly, yearly, and lifetime prices in the US and key target storefronts?
- What exact RevenueCat entitlement IDs and product mappings are live?
- How many installs reach calibration, first value, first practice, first completion, trial CTA, active trial, paid conversion, renewal, and restore?
- What are the current ASC rating, review count, review themes, and Review Issues?
- Has version 1.0.4 build 86 reached users, or is the local state file correct and the ASC context stale?
- What crash, hang, audio failure, persistence failure, and memory termination rates exist by build?
- Which screenshot set is actually submitted to ASC?
- Which Chrome likes, if any, contain useful posture, paywall, ASO, crash-monitoring, RevenueCat, or review-funnel leads?

## Completion criteria for this audit

This audit is complete when the implementation agent has a concrete path to:

- reconcile one live source of truth for app identity, release status, prices, products, entitlements, trial rules, and legal URLs;
- repair pending and entitlement handling before calling a trial or feature unlocked;
- measure the full acquisition, activation, trial, purchase, review, and regression funnel;
- detect production crashes and severe user-experience regressions through a remote signal, with Mac watchdog scaffolding for the checks it can actually perform;
- align ASC metadata, screenshots, landing page, support, terms, privacy, and review notes;
- remove camera-era or stale documents from the active agent context without deleting history;
- validate all changes with local StoreKit, headless simulator tests, physical-device testing, and live ASC and RevenueCat evidence.

