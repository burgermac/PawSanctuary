#!/usr/bin/env bash
#
# Seed (or restore) the Kibble Drive state in a Simulator save, for the manual
# acceptance checklist (specs/Spec_KibbleDrive_Draft.md §6h).
#
# Usage:
#   scripts/seed_kibble_drive.sh POINTS true|false [options]
#   scripts/seed_kibble_drive.sh --restore [options]
#
# Examples:
#   scripts/seed_kibble_drive.sh 20 false    # steps 5-8: 20 points, unpurchased
#   scripts/seed_kibble_drive.sh 300 true    # step 10: full ladder, purchased
#   scripts/seed_kibble_drive.sh --restore   # put back the original save
#
# Options:
#   --bundle ID   app bundle ID (default com.timothyherburger.pawsanctuary1,
#                 which is what the Debug Simulator build installs as)
#   --file PATH   edit this gameState.json instead of looking one up with simctl
#
# STOP THE APP FIRST (Xcode's stop button). It autosaves and would overwrite the
# edit. Relaunch afterwards. Claimed rungs are always cleared. The first run
# keeps a copy of the original save next to it as gameState.json.seed-original;
# --restore puts that copy back and removes it.
#
# If it reports that no Drive exists, cold launch the app once inside the Drive
# window first: the Drive is created only at launch.

set -euo pipefail

BUNDLE="com.timothyherburger.pawsanctuary1"
FILE=""
RESTORE=0
POINTS=""
PURCHASED=""

usage() { sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --restore) RESTORE=1 ;;
    --bundle)  BUNDLE="${2:?--bundle needs a value}"; shift ;;
    --file)    FILE="${2:?--file needs a path}"; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "Unknown option: $1" >&2; usage 1 ;;
    *)
      if   [ -z "$POINTS" ];    then POINTS="$1"
      elif [ -z "$PURCHASED" ]; then PURCHASED="$1"
      else echo "Too many arguments." >&2; usage 1; fi ;;
  esac
  shift
done

if [ -z "$FILE" ]; then
  command -v xcrun >/dev/null 2>&1 || { echo "xcrun not found. Run this on your Mac, or pass --file." >&2; exit 1; }
  CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE" data 2>/dev/null)" || {
    echo "Could not find $BUNDLE on a booted Simulator." >&2
    echo "Boot a Simulator and install the Debug build first, or check --bundle." >&2
    exit 1
  }
  FILE="$CONTAINER/Library/Application Support/PawSanctuary/gameState.json"
fi

[ -f "$FILE" ] || { echo "No save at: $FILE" >&2; exit 1; }
BACKUP="$FILE.seed-original"

if [ "$RESTORE" -eq 1 ]; then
  [ -f "$BACKUP" ] || { echo "Nothing to restore: no $BACKUP." >&2; exit 1; }
  mv "$BACKUP" "$FILE"
  echo "Restored the original save."
  exit 0
fi

case "$POINTS" in ''|*[!0-9]*) echo "POINTS must be a whole number." >&2; usage 1 ;; esac
case "$PURCHASED" in true|false) ;; *) echo "Second argument must be true or false." >&2; usage 1 ;; esac

[ -f "$BACKUP" ] || cp "$FILE" "$BACKUP"

python3 - "$FILE" "$POINTS" "$PURCHASED" <<'PY'
import json, sys
path, points, purchased = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "true"
with open(path) as f:
    state = json.load(f)
drive = state.get("kibbleDrive")
if drive is None:
    sys.exit("No Kibble Drive in this save. Cold launch the app once inside the "
             "Drive window (it is created only at launch), stop it, and rerun.")
drive["points"] = points
drive["purchased"] = purchased
drive["claimedRungs"] = []
with open(path, "w") as f:
    json.dump(state, f)
print(f"Seeded {drive['eventID']}: points={points}, purchased={purchased}, claimedRungs=[].")
PY
echo "Original save kept as: $BACKUP   (restore with: $0 --restore)"
echo "Now relaunch the app."
