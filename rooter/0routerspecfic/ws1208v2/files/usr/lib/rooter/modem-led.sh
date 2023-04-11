#!/bin/sh

log() {
	logger -t "modem-led " "$@"
}
exit 0
CURRMODEM=$1
COMMD=$2

	case $COMMD in
		"0" )
			echo none > /sys/class/leds/green:status/trigger
			echo 0  > /sys/class/leds/green:status/brightness
			;;
		"1" )
			echo timer > /sys/class/leds/green:status/trigger
			echo 500  > /sys/class/leds/green:status/delay_on
			echo 500  > /sys/class/leds/green:status/delay_off
			;;
		"2" )
			echo timer > /sys/class/leds/green:status/trigger
			echo 200  > /sys/class/leds/green:status/delay_on
			echo 200  > /sys/class/leds/green:status/delay_off
			;;
		"3" )
			echo timer > /sys/class/leds/green:status/trigger
			echo 1000  > /sys/class/leds/green:status/delay_on
			echo 0  > /sys/class/leds/green:status/delay_off
			;;
		"4" )
			echo none > /sys/class/leds/green:status/trigger
			echo 1  > /sys/class/leds/green:status/brightness
			;;
	esac
