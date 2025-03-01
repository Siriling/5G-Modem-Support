#!/bin/sh
# Usage: ./modem_connect.sh qmi|mbim|ppp
PROTOCOL="$1"
DEVICE="/dev/ttyUSB2"
if [ -z "$PROTOCOL" ]; then
  echo "Error: Specify protocol (qmi, mbim, ppp)"
  exit 1
fi
case $PROTOCOL in
  "qmi") qmicli -d /dev/cdc-wdm0 --wda-set-data-format ;;
  "mbim") mbimcli -d /dev/cdc-wdm0 --query-device-caps ;;
  "ppp") echo "ATDT*99#" | atinout - $DEVICE - ;;
  *) echo "Unsupported protocol: $PROTOCOL" ;;
esac
