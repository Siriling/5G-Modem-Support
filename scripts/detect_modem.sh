#!/bin/sh
# Detect WWAN cards with profile support
source /usr/bin/modem_profiles.sh
echo "Starting modem detection..."
sh /usr/bin/load_kmod.sh
for dev in $(lsusb | awk "{print \$6}"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  profile=$(get_profile $vid)
  name=$(echo $profile | cut -d: -f1)
  echo "Detected $name (VID:$vid PID:$pid)"
done
echo "Detection complete"
