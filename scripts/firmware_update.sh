#!/bin/sh
# Update WWAN modem firmware
DEVICE="/dev/ttyUSB2"
FIRMWARE_PATH="$1"
if [ ! -e "$DEVICE" ]; then echo "Error: $DEVICE not found"; exit 1; fi
if [ -z "$FIRMWARE_PATH" ] || [ ! -f "$FIRMWARE_PATH" ]; then
  echo "Error: Provide valid firmware file path"; exit 1
fi
VID=$(lsusb | grep "$(dmesg | grep ttyUSB | tail -1 | awk "{print \$NF}")" | awk "{print \$6}" | cut -d: -f1)
case $VID in
  "05c6") # Quectel
    qmi-firmware-update --update -d "$DEVICE" "$FIRMWARE_PATH"
    ;;
  *) echo "Firmware update not supported for VID:$VID yet"; exit 1 ;;
esac
