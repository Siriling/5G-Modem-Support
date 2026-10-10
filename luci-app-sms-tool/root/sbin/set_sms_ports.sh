#!/bin/sh
# Copyright 2020-2021 Rafał Wabik (IceG) - From eko.one.pl forum
# Licensed to the GNU General Public License v3.0.

# Reuse the known QDC507 AT port; do not probe its DIAG/GNSS ports.
count=$(uci -q get modem.global.modem_number)
for i in $(seq 0 $(( ${count:-0} - 1 ))); do
    [ "$(uci -q get modem.modem${i}.name)" = "qdc507" ] || continue
    port=$(uci -q get modem.modem${i}.at_port)
    [ -c "$port" ] || continue
    for setting in readport sendport ussdport atport; do
        uci set sms_tool.general.${setting}="$port"
    done
    uci commit sms_tool
    exit 0
done

work=false
for port in /dev/ttyUSB*
do
    [[ -e $port ]] || continue
    gcom -d $port info &> /tmp/testusb
    testUSB=`cat /tmp/testusb | grep "Error\|Can't"`
    if [ -z "$testUSB" ]; then 
        work=$port
        break
    fi
done
rm -rf /tmp/testusb

if [ $work != false ]; then
uci set sms_tool.general.readport=$work
uci set sms_tool.general.sendport=$work
uci set sms_tool.general.ussdport=$work
uci set sms_tool.general.atport=$work
uci commit sms_tool
fi
