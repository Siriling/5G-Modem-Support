#!/bin/sh
# WWAN status for LuCI integration
echo "{"
sh /usr/bin/detect_modem.sh > /tmp/wwan_detect
DETECT=$(cat /tmp/wwan_detect | grep "Detected" | sed "s/Detected /\\"/; s/ (VID:/\\", \\"vid\\": \\"/; s/ PID:/\\", \\"pid\\": \\"/; s/)$/\\"}/")
if [ -e /dev/ttyUSB2 ]; then
  SIGNAL=$(echo "AT+CSQ" | atinout - /dev/ttyUSB2 - | grep "+CSQ" | awk "{print \$2}" | cut -d"," -f1)
  FIRMWARE=$(echo "AT+CGMR" | atinout - /dev/ttyUSB2 - | grep -v "AT+CGMR")
  echo "\\"modems\\": [$DETECT],"
  echo "\\"signal\\": \\"$SIGNAL\\","
  echo "\\"firmware\\": \\"$FIRMWARE\\""
else
  echo "\\"modems\\": [], \\"signal\\": \\"N/A\\", \\"firmware\\": \\"N/A\\""
fi
echo "}"
