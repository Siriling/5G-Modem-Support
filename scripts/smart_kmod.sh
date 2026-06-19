#!/bin/sh
# Smart kmod management for WWAN cards
LOGFILE="/var/log/wwan_kmod.log"
KERNEL_VERSION=$(uname -r)
check_and_install() {
  MODULE="$1"
  if lsmod | grep -q "$MODULE"; then
    echo "Module $MODULE already loaded"
  elif opkg list-installed | grep -q "$MODULE"; then
    modprobe $MODULE && echo "Loaded $MODULE" || echo "Failed to load $MODULE"
  else
    echo "Installing $MODULE for kernel $KERNEL_VERSION..."
    opkg update
    opkg install $MODULE
    modprobe $MODULE && echo "Loaded $MODULE" || echo "Failed, check kernel compatibility"
  fi
  echo "$(date): $MODULE status: $(lsmod | grep $MODULE)" >> $LOGFILE
}
for mod in kmod-usb-serial kmod-qmi-wwan kmod-cdc-mbim kmod-sierra kmod-cdc-ether; do
  check_and_install $mod
done
echo "Smart kmod management complete"
