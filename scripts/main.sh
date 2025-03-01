#!/bin/sh
# Main script for 5G-Modem-Support
ACTION="$1"
case $ACTION in
  "detect") sh /usr/bin/detect_modem.sh ;;
  "install") sh /usr/bin/smart_kmod.sh ;;
  "lock") sh /usr/bin/band_lock.sh "$2" ;;
  "diag") sh /usr/bin/modem_diag.sh ;;
  "connect") sh /usr/bin/modem_connect.sh ;;
  "auto") sh /usr/bin/auto_reconnect.sh ;;
  "update") sh /usr/bin/firmware_update.sh "$2" ;;
  "optimize") sh /usr/bin/optimize_network.sh ;;
  "luci") sh /usr/bin/luci_wwan.sh ;;
  *) echo "Usage: $0 {detect|install|lock <bands>|diag|connect|auto|update <firmware>|optimize|luci}" ;;
esac
