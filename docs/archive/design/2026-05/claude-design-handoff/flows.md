# User Flows

```
Cold launch
   │
   ├─ hasCompletedOnboarding == false ──▶  OnboardingView
   │                                          │ (single screen, "Get started")
   │                                          ▼
   │                                       hasCompletedOnboarding = true
   │
   ├─ hasCalibrated == false ───────────▶  CalibrationView (.onboarding)
   │                                          │
   │                                          ├─ Step 1 "Do you have AirPods?"  ──┐
   │                                          ├─ Step 2 "Sit upright" — 5s capture │
   │                                          └─ Step 3 "You're calibrated"         │
   │                                          ▼                                    │
   │                                       hasCalibrated = true ◀───────────────────┘
   │
   └─ MainTabView
        ├─ TodayView         ← default tab
        ├─ HistoryView
        └─ SettingsView
```

## Reminder loop (the core daily flow)

```
ReminderScheduler (notification fires)
   │
   ▼
User taps notification ──▶ NotificationDelegate.didReceive
   │                              │
   │                              ▼
   │                       Sets ackScheduledAt / ackNotificationIndex
   │                              │
   ▼                              ▼
TodayView "Check in now"  ─▶  AcknowledgmentView  (fullScreenCover)
                                  │
                                  ├─ "Quick Scan" ─▶ QuickScanView (3s camera)
                                  │                       │
                                  │                       ▼
                                  │                  result {good|borderline|bad}
                                  │                       │
                                  └─ "I sat up straight" ──┤
                                                           ▼
                                                  recordAcknowledgment
                                                  StreakService.recordAcknowledgment
                                                           │
                                                           ▼
                                                       Done screen
                                                       (icon + message + tip + Done)
```

## Settings flows

```
SettingsView
  ├─ Pro section
  │   ├─ (not subscribed) "Upgrade" row ─▶ PaywallView (sheet)
  │   └─ (subscribed) Always-on watch toggle + AirPods background toggle
  │                                              │
  │                                              ▼
  │                                         AirpodsStatusView (live indicator)
  │
  ├─ Reminders
  │   ├─ Enabled toggle  (denial silently flips back — see audit P1-3)
  │   ├─ Interval picker (15 / 30 / 60 min)
  │   └─ Active hours steppers
  │
  ├─ Sensitivity (Relaxed / Normal / Strict — segmented)
  │
  ├─ Calibration
  │   └─ "Recalibrate" ─▶ confirmationDialog
  │                          ├─ Quick → CalibrationView(.quickRecalibrate) sheet
  │                          └─ Full  → clears hasCalibrated, returns to Calibration root
  │
  └─ About / Version
```

## Where each flow lives in code

| Flow | File |
|---|---|
| Onboarding | `Posture/Views/OnboardingView.swift` |
| Calibration | `Posture/Views/CalibrationView.swift` |
| Today (home) | `Posture/Views/TodayView.swift` |
| Acknowledgment (check-in) | `Posture/Views/AcknowledgmentView.swift` |
| Quick scan camera | `Posture/Views/Components/QuickScanView.swift` |
| History | `Posture/Views/HistoryView.swift` |
| Passive Pro heatmap | `Posture/Views/PassiveTimelineView.swift` |
| Habits / education | `Posture/Views/PostureHabitsView.swift` |
| Settings | `Posture/Views/SettingsView.swift` |
| Paywall | `Posture/Views/PaywallView.swift` |
| Tip card | `Posture/Views/Components/PostureTipCard.swift` |
| Ring | `Posture/Views/Components/PostureRing.swift` |
| Streak flame | `Posture/Views/Components/StreakFlame.swift` |
| Live quality pill | `Posture/Views/Components/PostureLiveIndicator.swift` |
