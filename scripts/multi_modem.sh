#!/bin/sh
# Detect and manage multiple modems
for dev in /dev/ttyUSB*; do
  if [ -e "$dev" ]; then
    echo "Found modem at $dev"
    sh /usr/bin/detect_modem.sh
    sh /usr/bin/modem_diag.sh
  fi
done
