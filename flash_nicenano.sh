#!/usr/bin/env bash
set -euo pipefail

RIGHT_FW="/home/zach/Dev/zmk-workspace/firmware/corne_right-nice_nano_v2.uf2"
LEFT_FW="/home/zach/Dev/zmk-workspace/firmware/corne_left-nice_nano_v2.uf2"

printf "▶  Looking 60 s for NICENANO…\n"
for i in {1..60}; do
    DEV=$(lsblk -pnlo NAME,LABEL | awk '$2=="NICENANO"{print $1;exit}')
    [[ -n $DEV ]] && break
    sleep 1
done
[[ -z ${DEV:-} ]] && {
    echo "❌  Drive not found."
    exit 1
}
echo "✔  Found $DEV"

# Mount through UDisks2 (no sudo, auto-unmount on disconnect)
MNT=$(udisksctl mount -b "$DEV" | awk '{print $NF}')
echo "▶  Mounted at $MNT"
sleep 5

echo "▶  Copying firmware…"
cp "$RIGHT_FW" "$MNT/"
cp "$LEFT_FW" "$MNT/"
sync # good hygiene; seldom really needed

echo "▶  Waiting for reset…"
while lsblk -pnlo LABEL | grep -q NICENANO; do sleep 0.2; done

echo "✅  Flash complete; keyboard just rebooted!"
