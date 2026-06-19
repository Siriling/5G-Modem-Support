#!/bin/sh
# Enhanced kmod loading
LOGFILE="/var/log/wwan_kmod.log"
echo "$(date): Starting kmod loading..." >> $LOGFILE
load_module() { MODULE="$1"; if lsmod | grep -q "$MODULE"; then echo "Module $MODULE already loaded"; else modprobe $MODULE && echo "Loaded $MODULE" || echo "Failed to load $MODULE"; fi; }
for dev in $(lsusb | awk "{print \$6}"); do vid=$(echo $dev | cut -d: -f1); pid=$(echo $dev | cut -d: -f2); case $vid in "05c6") echo "Quectel modem"; load_module "qmi_wwan"; load_module "option"; echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id ;; "1199" | "0f3d") echo "Sierra Wireless"; load_module "sierra"; load_module "option" ;; *) echo "Unknown device"; esac; done
