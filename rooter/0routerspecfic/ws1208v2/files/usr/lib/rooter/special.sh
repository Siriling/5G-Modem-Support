#!/bin/sh

LED=0
SM=$(uci get system.wifi)
if [ -z $SM ]; then
	uci set system.wifi=led
	uci set system.wifi.name="5Gwifi"
	uci set system.wifi.sysfs="wifi"
	uci set system.wifi.trigger="netdev"
	uci set system.wifi.dev="wlan1"
	uci set system.wifi.mode="link tx rx"
	
	uci set system.4g5g=led
	uci set system.4g5g.name="4G5G"
	uci set system.4g5g.sysfs="green:4g5g"
	uci set system.4g5g.trigger="netdev"
	uci set system.4g5g.dev="wwan0"
	uci set system.4g5g.mode="link tx rx"
	uci set system.4g5g.default='0'
	
	uci set system.Usb=led
	uci set system.Usb.name="USB2.0"
	uci set system.Usb.sysfs="usb"
	uci set system.Usb.trigger="usbport"
	uci set system.Usb.port='usb1-port1'

	uci commit system
	/etc/init.d/led restart
fi

echo none > /sys/class/leds/green:status/trigger
echo 0  > /sys/class/leds/green:status/brightness

