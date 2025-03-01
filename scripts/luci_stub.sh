#!/bin/sh
# LuCI stub for WWAN status
echo "WWAN Status Report"
sh /usr/bin/detect_modem.sh
if [ -e /dev/ttyUSB2 ]; then
  signal=$(echo "AT+CSQ" | atinout - /dev/ttyUSB2 -)
  echo "Signal Strength: $signal"
fi
ip addr show wwan0
