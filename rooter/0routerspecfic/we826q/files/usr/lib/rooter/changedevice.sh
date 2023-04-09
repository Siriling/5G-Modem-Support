#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Change Device" "$@"
}

uci set system.led_wan.dev=$1
uci commit system
/etc/init.d/led restart