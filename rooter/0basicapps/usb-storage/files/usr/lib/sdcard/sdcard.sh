#!/bin/sh

log() {
	modlog "sdcard" "$@"
}

h721() {
	if [ $1 = "add" ]; then
		echo "17" > /sys/class/gpio/export
		echo "out" > /sys/class/gpio/gpio17/direction
		echo 0 > /sys/class/gpio/gpio17/value
	else
		echo "17" > /sys/class/gpio/export
		echo "out" > /sys/class/gpio/gpio17/direction
		echo 1 > /sys/class/gpio/gpio17/value
fi
}

ws1208() {
	if [ $1 = "add" ]; then
		echo none > /sys/class/leds/usb/trigger
		echo 1  > /sys/class/leds/usb/brightness
	else
		echo none > /sys/class/leds/usb/trigger
		echo 0  > /sys/class/leds/usb/brightness
	fi
}

ws1688() {
	if [ $1 = "add" ]; then
		echo none > /sys/class/leds/usb/trigger
		echo 1  > /sys/class/leds/usb/brightness
	else
		echo none > /sys/class/leds/usb/trigger
		echo 0  > /sys/class/leds/usb/brightness
	fi
}

ACTION=$1
model=$(cat /tmp/sysinfo/model)
case $ACTION in
	"add"|"remove" )
		mod=$(echo $model | grep "H721")
		if [ ! -z "$mod" ]; then
			h721 $ACTION
		fi
		mod=$(echo $model | grep "WS1208V2")
		if [ ! -z "$mod" ]; then
			ws1208 $ACTION
		fi
		mod=$(echo $model | grep "WS1218")
		if [ ! -z "$mod" ]; then
			ws1208 $ACTION
		fi

		mod=$(echo $model | grep "WS1688")
		if [ ! -z "$mod" ]; then
			ws1688 $ACTION
		fi
		;;
	"detect" )
		mod=$(echo $model | grep "Raspberry")
		if [ $mod ]; then
			echo 'detect="'"1"'"' > /tmp/detect.file
		else
			echo 'detect="'"0"'"' > /tmp/detect.file
		fi
		;;
esac


