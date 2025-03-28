#!/bin/sh
# Advanced WWAN detection with error handling
source /usr/bin/modem_profiles.sh
LOGFILE="/var/log/wwan_detect.log"
sh /usr/bin/smart_kmod.sh || { echo "kmod loading failed" >> $LOGFILE; exit 1; }
for dev in $(lsusb | awk "{print \$6}" | grep -v "^$"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  profile=$(get_profile $vid)
  name=$(echo $profile | cut -d"|" -f1)
  if [ -z "$vid" ] || [ -z "$pid" ]; then
    echo "Invalid device info, skipping..." >> $LOGFILE
    continue
  fi
  echo "Detected $name (VID:$vid PID:$pid)"
  [ -e /dev/ttyUSB2 ] || { echo "No ttyUSB2 for $name" >> $LOGFILE; continue; }
  timeout 5 echo "AT" | atinout - /dev/ttyUSB2 - || echo "Modem $name unresponsive" >> $LOGFILE
done
echo "Detection finished, CPU usage: $(top -bn1 | grep "Cpu(s)" | awk "{print \$2}")%"
