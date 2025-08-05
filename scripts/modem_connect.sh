#!/bin/sh
# Auto-detect and connect modem
source /usr/bin/modem_profiles.sh
DEVICE="/dev/ttyUSB2"
if [ ! -e "$DEVICE" ]; then echo "Error: $DEVICE not found"; exit 1; fi
VID=$(lsusb | grep "$(dmesg | grep ttyUSB | tail -1 | awk "{print \$NF}")" | awk "{print \$6}" | cut -d: -f1)
PROFILE=$(get_profile $VID)
PROTOCOL=$(echo $PROFILE | cut -d"|" -f5)
echo "Using protocol: $PROTOCOL for $(echo $PROFILE | cut -d"|" -f1)"
for i in 1 2 3; do
  case $PROTOCOL in
    "QMI") qmicli -d /dev/cdc-wdm0 --wda-set-data-format && break ;;
    "MBIM") mbimcli -d /dev/cdc-wdm0 --query-device-caps && break ;;
    "PPP") echo "ATDT*99#" | atinout - $DEVICE - && break ;;
    *) echo "Falling back to QMI"; qmicli -d /dev/cdc-wdm0 --wda-set-data-format && break ;;
  esac
  echo "Attempt $i failed, retrying..."
  sleep 5
done
