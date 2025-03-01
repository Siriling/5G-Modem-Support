#!/bin/sh
# Usage: ./band_lock.sh "1,3,41"
BANDS="$1"
if [ -z "$BANDS" ]; then
  echo "Error: Please provide band list (e.g., 1,3,41)"
  exit 1
fi
echo "AT+QNWPREFCFG=\"nr5g_band\",$BANDS" | atinout - /dev/ttyUSB2 /tmp/band_result
cat /tmp/band_result
