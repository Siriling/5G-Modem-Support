#!/bin/sh
# Advanced WWAN card detection
source /usr/bin/modem_profiles.sh
sh /usr/bin/smart_kmod.sh
for dev in $(lsusb | awk "{print \$6}"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  profile=$(get_profile $vid)
  name=$(echo $profile | cut -d"|" -f1)
  at_cmds=$(echo $profile | cut -d"|" -f3)
  echo "Detected $name (VID:$vid PID:$pid)"
  if [ -e /dev/ttyUSB2 ]; then
    for cmd in $(echo $at_cmds | tr "," " "); do
      result=$(echo "$cmd" | atinout - /dev/ttyUSB2 -)
      echo "$cmd: $result"
    done
  fi
done
