#!/bin/sh
# Optimize WWAN network settings
source /usr/bin/modem_profiles.sh
VID=$(lsusb | grep "$(dmesg | grep ttyUSB | tail -1 | awk "{print \$NF}")" | awk "{print \$6}" | cut -d: -f1)
PROFILE=$(get_profile $VID)
BAND_PARAM=$(echo $PROFILE | cut -d"|" -f4)
if [ -e "$DEVICE" ]; then
  signal=$(echo "AT+CSQ" | atinout - /dev/ttyUSB2 - | grep "+CSQ" | awk "{print \$2}" | cut -d"," -f1)
  if [ "$signal" -lt 10 ]; then
    echo "Weak signal ($signal), optimizing bands..."
    sh /usr/bin/band_lock.sh "1,3,41"  # Example strong bands
  else
    echo "Signal strength OK ($signal)"
  fi
fi
sh /usr/bin/modem_connect.sh
