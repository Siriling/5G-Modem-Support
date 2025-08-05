#!/bin/sh
# Multi-modem load balancing with mwan3
MOD EMS=()
i=1
for dev in /dev/ttyUSB*; do
  [ -e "$dev" ] || continue
  sh /usr/bin/detect_modem.sh
  sh /usr/bin/modem_connect.sh
  uci set network.wwan$i=interface
  uci set network.wwan$i.proto="qmi"
  uci set network.wwan$i.device="/dev/cdc-wdm$((i-1))"
  uci commit network
  MODEMS+=("wwan$i")
  i=$((i+1))
done
opkg update && opkg install mwan3
for modem in "${MODEMS[@]}"; do
  uci set mwan3.$modem=interface
  uci set mwan3.$modem.enabled="1"
done
uci commit mwan3
/etc/init.d/mwan3 restart
