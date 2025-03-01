#!/bin/sh
for dev in $(lsusb | awk "{print \$6}"); do vid=$(echo $dev | cut -d: -f1); pid=$(echo $dev | cut -d: -f2); [ -n "$vid" ] && echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id; done
