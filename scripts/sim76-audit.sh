#!/usr/bin/env bash
# sim76-audit.sh — headless simulator tour for sim76.md audit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/sim76-screenshots"
APP="/tmp/agent-dd-posture/Build/Products/Debug-iphonesimulator/Posture.app"
BID="com.jackwallner.posture"

shot() {
  local udid="$1" name="$2" subdir="$3"
  local dir="$OUT/$subdir"
  mkdir -p "$dir"
  axe screenshot --output "$dir/$name.png" --udid "$udid" 2>/dev/null || agent-sim screenshot posture "$dir/$name.png"
  echo "  shot: $subdir/$name.png"
}

tap_label() {
  local udid="$1" label="$2"
  axe tap --label "$label" --udid "$udid" 2>/dev/null || return 1
}

tap_contains() {
  local udid="$1" text="$2"
  axe tap --label "$text" --udid "$udid" 2>/dev/null || return 1
}

launch() {
  local udid="$1"; shift
  xcrun simctl terminate "$udid" "$BID" 2>/dev/null || true
  sleep 0.5
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" "$BID" "$@" 2>/dev/null
  sleep 2
}

describe() {
  axe describe-ui --udid "$1" 2>/dev/null | head -200
}

run_free_fresh() {
  local udid="$1" subdir="free-fresh"
  echo "=== FREE FRESH USER on $udid ==="
  launch "$udid" -UITEST_FRESH
  sleep 1
  shot "$udid" "01-onboarding-welcome" "$subdir"

  for i in 2 3 4 5; do
    tap_label "$udid" "Continue" && sleep 0.8
    shot "$udid" "0${i}-onboarding-page" "$subdir" || true
  done

  tap_label "$udid" "Set up my baseline" && sleep 2
  shot "$udid" "06-calibration-waiting" "$subdir"

  # Wait for no-AirPods escape
  sleep 8
  shot "$udid" "07-calibration-no-airpods-visible" "$subdir"
  tap_label "$udid" "I don't have AirPods" && sleep 2
  shot "$udid" "08-today-no-airpods" "$subdir"

  # Trial pitch after skip? Actually skip goes to deferred calibration - may show trial later
  # Navigate tabs
  for tab in "History" "Progress" "Posture+" "Settings" "Today"; do
    tap_label "$udid" "$tab" 2>/dev/null && sleep 1.2
    local safe=$(echo "$tab" | tr ' +' '-' | tr '[:upper:]' '[:lower:]')
    shot "$udid" "tab-${safe}" "$subdir" || true
  done

  # Check in flow
  tap_label "$udid" "Today" 2>/dev/null; sleep 0.5
  tap_label "$udid" "Check in now" 2>/dev/null && sleep 1.5
  shot "$udid" "09-checkin-choice" "$subdir"
  tap_label "$udid" "I'm sitting aligned" 2>/dev/null && sleep 2
  shot "$udid" "10-checkin-result" "$subdir"
  tap_label "$udid" "Done" 2>/dev/null && sleep 1

  # Practice session pre-start (if visible)
  tap_label "$udid" "Today" 2>/dev/null; sleep 0.5
  tap_label "$udid" "Start practice" 2>/dev/null && sleep 1.5
  shot "$udid" "11-practice-prestart" "$subdir" || true
  tap_label "$udid" "Close" 2>/dev/null || axe button home --udid "$udid" 2>/dev/null || true
  sleep 0.5

  # Level ladder, streak, achievements from Today
  tap_label "$udid" "Today" 2>/dev/null; sleep 0.5
  for chip in "Level" "day streak" "Badges"; do
    axe tap --label "$chip" --udid "$udid" 2>/dev/null && sleep 1.2
    shot "$udid" "sheet-${chip// /-}" "$subdir" || true
    axe tap --label "Close" --udid "$udid" 2>/dev/null || axe tap --label "Done" --udid "$udid" 2>/dev/null || true
    sleep 0.5
  done

  # Walk gate (free)
  tap_label "$udid" "Posture walk" 2>/dev/null && sleep 1.5
  shot "$udid" "12-walk-gate" "$subdir" || true
  tap_label "$udid" "Close" 2>/dev/null || tap_label "$udid" "Maybe later" 2>/dev/null || true
  sleep 0.5

  # Settings paywall postcard
  tap_label "$udid" "Settings" 2>/dev/null; sleep 0.5
  axe swipe --direction up --udid "$udid" 2>/dev/null; sleep 0.5
  shot "$udid" "13-settings-scrolled" "$subdir"
}

run_pro_seeded() {
  local udid="$1" subdir="pro-seeded"
  echo "=== PRO SEEDED USER on $udid ==="
  launch "$udid" -SCREENSHOT_SEED -PostureProOverride
  sleep 2
  shot "$udid" "01-today-pro" "$subdir"

  for tab in "History" "Progress" "Settings"; do
    tap_label "$udid" "$tab" 2>/dev/null && sleep 1.2
    local safe=$(echo "$tab" | tr '[:upper:]' '[:lower:]')
    shot "$udid" "tab-${safe}" "$subdir" || true
    if [[ "$tab" == "History" ]]; then
      axe swipe --direction up --udid "$udid" 2>/dev/null; sleep 0.5
      shot "$udid" "history-scrolled" "$subdir" || true
    fi
  done

  tap_label "$udid" "Today" 2>/dev/null; sleep 0.5
  tap_label "$udid" "Start practice" 2>/dev/null && sleep 1.5
  shot "$udid" "02-practice-prestart" "$subdir" || true

  tap_label "$udid" "Posture walk" 2>/dev/null && sleep 1.5
  shot "$udid" "03-walk-prestart" "$subdir" || true
  tap_label "$udid" "Close" 2>/dev/null || true

  tap_label "$udid" "Progress" 2>/dev/null; sleep 0.5
  shot "$udid" "04-progress-ladder" "$subdir"

  tap_label "$udid" "Settings" 2>/dev/null; sleep 0.5
  axe swipe --direction up --udid "$udid" 2>/dev/null; sleep 0.5
  shot "$udid" "05-settings-pro" "$subdir"
}

run_free_seeded() {
  local udid="$1" subdir="free-seeded"
  echo "=== FREE SEEDED USER on $udid ==="
  launch "$udid" -SCREENSHOT_SEED
  sleep 2
  shot "$udid" "01-today-free-capped" "$subdir"

  tap_label "$udid" "Progress" 2>/dev/null && sleep 1.2
  shot "$udid" "02-progress-blurred" "$subdir"
  axe swipe --direction up --udid "$udid" 2>/dev/null; sleep 0.5
  shot "$udid" "03-progress-scrolled" "$subdir"

  tap_label "$udid" "Posture+" 2>/dev/null && sleep 1.2
  shot "$udid" "04-pro-tab" "$subdir"

  tap_label "$udid" "History" 2>/dev/null && sleep 1.2
  shot "$udid" "05-history-free" "$subdir"
}

run_paywall_modes() {
  local udid="$1" subdir="paywall"
  echo "=== PAYWALL MODES on $udid ==="
  for mode in trial monthly yearly lifetime; do
    launch "$udid" "-PaywallSnapshot" "$mode"
    sleep 2
    shot "$udid" "paywall-${mode}" "$subdir"
  done
}

run_device() {
  local device_name="$1" udid="$2"
  echo "=== DEVICE $device_name ($udid) ==="
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 2>/dev/null || true
  launch "$udid" -SCREENSHOT_SEED
  sleep 2
  local safe=$(echo "$device_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  shot "$udid" "today-${safe}" "devices"
  tap_label "$udid" "Progress" 2>/dev/null && sleep 1
  shot "$udid" "progress-${safe}" "devices"
  xcrun simctl shutdown "$udid" 2>/dev/null || true
}

# Main
UDID=$(agent-sim checkout posture)
trap 'agent-sim checkin posture' EXIT
agent-sim boot posture >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 2>/dev/null || true

run_free_fresh "$UDID"
run_free_seeded "$UDID"
run_pro_seeded "$UDID"
run_paywall_modes "$UDID"

# Additional device-size coverage is provided by the shared pool. This audit
# intentionally uses only its checked-out group.

echo "=== AUDIT COMPLETE ==="
find "$OUT" -name '*.png' | wc -l | xargs echo "Total screenshots:"
