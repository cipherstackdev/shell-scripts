#!/bin/bash
# inventory-macOS.sh — Pre-enrollment macOS inventory (TXT only)
# Output: /Users/Shared/MacInventory_<serial>_<YYYYmmdd-HHMMSS>.txt
set -euo pipefail

WIDTH=80
SEP="$(printf '%*s' "$WIDTH" '' | tr ' ' '=')"
DASH="$(printf '%*s' "$WIDTH" '' | tr ' ' '-')"
stamp() { date +"%Y-%m-%d %H:%M:%S %Z"; }
ts="$(date +"%Y%m%d-%H%M%S")"

trim() { awk '{$1=$1}1'; }
kv() { printf "%-28s : %s\n" "$1" "$2"; }
firstline() { head -n 1 || true; }

serial="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformSerialNumber/ {print $4}')"
: "${serial:=UNKNOWN}"

out="/Users/Shared/MacInventory_${serial}_${ts}.txt"
if ! (mkdir -p /Users/Shared && : >/Users/Shared/.w 2>/dev/null); then
  out="${HOME}/Desktop/MacInventory_${serial}_${ts}.txt"
fi
rm -f "$out"
exec 3>"$out"

OS_NAME="$(sw_vers -productName)"
OS_VER="$(sw_vers -productVersion)"
OS_BUILD="$(sw_vers -buildVersion)"
CN="$(scutil --get ComputerName 2>/dev/null || echo "")"
LH="$(scutil --get LocalHostName 2>/dev/null || echo "")"
HN="$(scutil --get HostName 2>/dev/null || echo "")"
CUR_USER="$(stat -f%Su /dev/console 2>/dev/null || echo "UNKNOWN")"
MODEL="$(sysctl -n hw.model 2>/dev/null || true)"
CHIP_RAW="$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
if [[ -z "$CHIP_RAW" ]]; then
  CHIP_RAW="$(
    /usr/sbin/system_profiler SPHardwareDataType -detailLevel mini 2>/dev/null |
    awk -F: '/Chip|Processor Name/ {sub(/^[ \t]+/, "", $2); print $2; exit}'
  )"
fi
RAM_GB="$(/usr/sbin/sysctl -n hw.memsize | awk '{printf "%.1f", $1/1073741824}')"
UPTIME="$(uptime | sed 's/^ *//')"

# Safe boot time formatting
BOOT_EPOCH="$(sysctl -n kern.boottime 2>/dev/null | awk -F'[ ,]+' '{print $4}' || true)"
if [[ -n "${BOOT_EPOCH:-}" && "$BOOT_EPOCH" =~ ^[0-9]+$ ]]; then
  BOOT_RAW="$(date -r "$BOOT_EPOCH" '+%Y-%m-%d %H:%M:%S %Z')"
else
  BOOT_RAW="Unknown"
fi

ROOT_DF="$(df -H / | tail -1 | awk '{printf "%s used / %s total (%s) on %s\n",$3,$2,$5,$1}')"

# APFS summary (short)
APFS_SUM="$(
  /usr/sbin/diskutil apfs list 2>/dev/null | awk 'NR<=40{print}' || true
)"

# Network basics
EN0_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
EN1_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
PRIMARY_DNS="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | paste -sd, -)"
WIFI_DEV="$(/usr/sbin/networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')"
AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
AIRPORT_INFO=""
if [[ -n "${WIFI_DEV:-}" && -x "$AIRPORT" ]]; then
  AIRPORT_INFO="$("$AIRPORT" -I 2>/dev/null || true)"
fi
SSID="$(echo "$AIRPORT_INFO" | awk -F': ' '/ SSID/ {print $2}')"
BSSID="$(echo "$AIRPORT_INFO" | awk -F': ' '/ BSSID/ {print $2}')"
RSSI="$(echo "$AIRPORT_INFO" | awk -F': ' '/ agrCtlRSSI/ {print $2}')"
CHANNEL="$(echo "$AIRPORT_INFO" | awk -F': ' '/ channel/ {print $2}')"

# Security posture
FV_STATUS="$(fdesetup status 2>/dev/null || true)"
FV_USERS="$(fdesetup list 2>/dev/null || true)"
GK_STATUS="$(spctl --status 2>/dev/null || true)"
SIP_STATUS="$(csrutil status 2>/dev/null || true)"
FW_STATE="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)"

# Config profiles / MDM
ENROLL_STATUS="$(profiles status -type enrollment 2>/dev/null || true)"
PROFILES_LIST="$(profiles list -type configuration 2>/dev/null | awk '{$1=$1}1' || true)"

# Battery (if laptop)
BATTERY_INFO="$(ioreg -rc AppleSmartBattery 2>/dev/null || true)"
BAT_CYCLES="$(echo "$BATTERY_INFO" | awk -F'= ' '/CycleCount/{print $2}')"
BAT_HEALTH="$(echo "$BATTERY_INFO" | awk -F'= ' '/MaxCapacity/{mc=$2} /DesignCapacity/{dc=$2} END{if(dc>0) printf "%.0f%%",(mc/dc)*100}')"
BAT_CHARGING="$(echo "$BATTERY_INFO" | awk -F'= ' '/IsCharging/{print $2}')"

# Software Updates (may be slow on some systems)
SU_LIST="$(
  /usr/sbin/softwareupdate -l 2>/dev/null |
  sed 's/^[[:space:]]*//; s/\*\* Label:/* Label:/'
)"

# Applications snapshot (names only)
APP_LIST="$(ls -1 /Applications 2>/dev/null | sed 's/\.app$//' | sort | paste -sd, - | fold -s -w 70)"

{
  echo "$SEP"
  printf "PRE-ENROLLMENT INVENTORY REPORT\n"
  printf "%s\n" "$(stamp)"
  echo "$SEP"

  echo "IDENTITY"
  echo "$DASH"
  kv "Computer Name" "${CN}"
  kv "Local Hostname" "${LH}"
  kv "Hostname" "${HN}"
  kv "Current Console User" "${CUR_USER}"
  kv "Serial Number" "${serial}"
  echo

  echo "OPERATING SYSTEM"
  echo "$DASH"
  kv "OS" "${OS_NAME}"
  kv "Version (Build)" "${OS_VER} (${OS_BUILD})"
  kv "Uptime" "${UPTIME}"
  kv "Last Boot" "${BOOT_RAW}"
  echo

  echo "HARDWARE"
  echo "$DASH"
  kv "Model Identifier" "${MODEL}"
  kv "Chip/CPU" "${CHIP_RAW}"
  kv "Memory (GB)" "${RAM_GB}"
  echo

  echo "STORAGE"
  echo "$DASH"
  kv "Root Volume" "${ROOT_DF}"
  echo
  echo "APFS (first 40 lines)"
  echo "$DASH"
  if [[ -n "${APFS_SUM}" ]]; then
    echo "$APFS_SUM" | sed 's/^/  /'
  else
    echo "  (No APFS info available.)"
  fi
  echo

  echo "NETWORK"
  echo "$DASH"
  kv "en0 IP" "${EN0_IP:-}"
  kv "en1 IP" "${EN1_IP:-}"
  kv "DNS Servers" "${PRIMARY_DNS:-}"
  kv "Wi-Fi Device" "${WIFI_DEV:-}"
  kv "SSID" "${SSID:-}"
  kv "BSSID" "${BSSID:-}"
  kv "RSSI" "${RSSI:-}"
  kv "Channel" "${CHANNEL:-}"
  echo

  echo "SECURITY & CONFIG PROFILES"
  echo "$DASH"
  kv "FileVault" "$(echo "$FV_STATUS" | firstline)"
  if [[ -n "$FV_USERS" ]]; then
    echo "  FileVault-Enabled Users:"
    echo "$FV_USERS" | sed 's/^/    - /'
  fi
  kv "Gatekeeper" "${GK_STATUS}"
  kv "SIP" "${SIP_STATUS}"
  kv "Firewall" "${FW_STATE}"
  echo
  kv "MDM Enrollment Status" "${ENROLL_STATUS}"
  if [[ -n "$PROFILES_LIST" ]]; then
    echo "  Installed Configuration Profiles:"
    echo "$PROFILES_LIST" | sed 's/^/    - /'
  else
    echo "  No configuration profiles detected."
  fi
  echo

  if [[ -n "$BATTERY_INFO" ]]; then
    echo "BATTERY"
    echo "$DASH"
    kv "Cycle Count" "${BAT_CYCLES:-N/A}"
    kv "Estimated Health" "${BAT_HEALTH:-N/A}"
    kv "Charging" "${BAT_CHARGING:-N/A}"
    echo
  fi

  echo "SOFTWARE UPDATES (raw)"
  echo "$DASH"
  if [[ -n "$SU_LIST" ]]; then
    echo "$SU_LIST"
  else
    echo "No updates info available (or none found)."
  fi
  echo

  echo "APPLICATIONS SNAPSHOT (/Applications, names only)"
  echo "$DASH"
  if [[ -n "$APP_LIST" ]]; then
    echo "$APP_LIST"
  else
    echo "No applications found or access denied."
  fi
  echo "$SEP"
} >&3

exec 3>&-
echo "Saved: $out"