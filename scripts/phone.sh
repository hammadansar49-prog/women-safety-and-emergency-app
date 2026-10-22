#!/usr/bin/env bash
# Drives SafeHer on a connected Android phone the way a person would: taps,
# typing, screenshots. Flutter draws into a canvas, so there is no accessibility
# tree to click by name — look at a screenshot, then tap the coordinates.
#
#   scripts/phone.sh shot [name]      screenshot -> $TEMP/safeher-<name>.png
#   scripts/phone.sh tap X Y          tap at screen pixels (720x1612 on this phone)
#   scripts/phone.sh text "hello"     type into the focused field
#   scripts/phone.sh key BACK|ENTER|HOME|VOLUME_UP|POWER
#   scripts/phone.sh swipe X1 Y1 X2 Y2 [ms]
#   scripts/phone.sh drag  X1 Y1 X2 Y2    slow drag (for the SOS slider)
#   scripts/phone.sh launch           start SafeHer
#   scripts/phone.sh restart          force-stop, then start
#   scripts/phone.sh clear            wipe app data (fresh install state)
#   scripts/phone.sh log [pattern]    recent app log lines
#   scripts/phone.sh perms            grant camera/mic/location/notifications
#   scripts/phone.sh size             screen size
set -u
ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
PKG=com.safeher.safeher
OUT="${TEMP:-/tmp}"

case "${1:-}" in
  shot)
    name="${2:-shot}"
    "$ADB" exec-out screencap -p > "$OUT/safeher-$name.png"
    echo "$OUT/safeher-$name.png"
    ;;
  tap)    "$ADB" shell input tap "$2" "$3" ;;
  text)   "$ADB" shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')" ;;
  key)    "$ADB" shell input keyevent "KEYCODE_$2" ;;
  swipe)  "$ADB" shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  drag)   "$ADB" shell input swipe "$2" "$3" "$4" "$5" 1200 ;;
  launch) "$ADB" shell am start -n "$PKG/.MainActivity" >/dev/null && echo started ;;
  restart)
    "$ADB" shell am force-stop "$PKG"
    sleep 1
    "$ADB" shell am start -n "$PKG/.MainActivity" >/dev/null && echo restarted
    ;;
  clear)  "$ADB" shell pm clear "$PKG" ;;
  log)    "$ADB" logcat -d -v brief 2>/dev/null | grep -iE "${2:-safeher|flutter}" | tail -40 ;;
  perms)
    for p in CAMERA RECORD_AUDIO ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do
      "$ADB" shell pm grant "$PKG" "android.permission.$p" 2>/dev/null
    done
    echo granted
    ;;
  size)   "$ADB" shell wm size ;;
  *) sed -n '2,20p' "$0" ;;
esac
