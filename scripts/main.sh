#!/bin/sh
# Main script for 5G-Modem-Support
ACTION="$1"
case $ACTION in
  "detect") sh /usr/bin/detect_modem.sh ;;
  "lock") sh /usr/bin/band_lock.sh "$2" ;;
  "diag") sh /usr/bin/modem_diag.sh ;;
  "connect") sh /usr/bin/modem_connect.sh "$2" ;;
  "auto") sh /usr/bin/auto_reconnect.sh ;;
  *) echo "Usage: $0 {detect|lock <bands>|diag|connect <protocol>|auto}" ;;
esac
