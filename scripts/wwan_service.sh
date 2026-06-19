#!/bin/sh /etc/rc.common
# WWAN service for OpenWrt
START=90
STOP=10
start() {
  echo "Starting WWAN service..."
  sh /usr/bin/detect_modem.sh
  sh /usr/bin/auto_reconnect.sh &
}
stop() {
  echo "Stopping WWAN service..."
  killall auto_reconnect.sh
}
