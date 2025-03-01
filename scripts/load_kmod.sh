#!/bin/sh
# Load kernel modules for WWAN cards based on VID:PID
echo "Scanning for WWAN devices..."
for dev in $(lsusb | awk "{print \$6}"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  case $vid in
    "05c6") # Quectel
      echo "Detected Quectel modem (VID:$vid PID:$pid)"
      modprobe qmi_wwan
      modprobe option
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1199" | "0f3d") # Sierra Wireless
      echo "Detected Sierra Wireless modem (VID:$vid PID:$pid)"
      modprobe sierra
      modprobe option
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1bc7") # Telit
      echo "Detected Telit modem (VID:$vid PID:$pid)"
      modprobe qmi_wwan
      modprobe option
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "12d1") # Huawei
      echo "Detected Huawei modem (VID:$vid PID:$pid)"
      modprobe cdc_ether
      modprobe option
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1e0e") # Fibocom
      echo "Detected Fibocom modem (VID:$vid PID:$pid)"
      modprobe qmi_wwan
      modprobe option
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    *) echo "Unknown WWAN device (VID:$vid PID:$pid)" ;;
  esac
done
echo "Kernel modules loaded"
