#!/bin/sh
# Hotplug script for WWAN devices
ACTION="$1"
DEVICENAME="$2"
if [ "$ACTION" = "add" ] && echo "$DEVICENAME" | grep -q "usb"; then
  logger "WWAN device added: $DEVICENAME"
  sh /usr/bin/detect_modem.sh
  sh /usr/bin/modem_connect.sh
elif [ "$ACTION" = "remove" ]; then
  logger "WWAN device removed: $DEVICENAME"
  killall auto_reconnect.sh 2>/dev/null
fi
