#!/bin/sh
# Detect WWAN cards and load kernel modules
echo "Starting modem detection..."
sh /usr/bin/load_kmod.sh
for dev in $(lsusb | awk "{print \$6}"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  [ -n "$vid" ] && echo "Modem detected: VID:$vid PID:$pid"
done
echo "Modem detection complete"
