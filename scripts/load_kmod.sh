#!/bin/sh
# Enhanced kmod loading for WWAN cards
LOGFILE="/var/log/wwan_kmod.log"
echo "$(date): Starting kmod loading..." >> $LOGFILE
load_module() {
  MODULE="$1"
  if lsmod | grep -q "$MODULE"; then
    echo "Module $MODULE already loaded"
  else
    modprobe $MODULE && echo "Loaded $MODULE" || echo "Failed to load $MODULE"
    echo "$(date): $MODULE status: $(lsmod | grep $MODULE)" >> $LOGFILE
  fi
}
for dev in $(lsusb | awk "{print \$6}"); do
  vid=$(echo $dev | cut -d: -f1)
  pid=$(echo $dev | cut -d: -f2)
  case $vid in
    "05c6") # Quectel
      echo "Quectel modem (VID:$vid PID:$pid)"
      load_module "qmi_wwan" || load_module "cdc_mbim"
      load_module "option"
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1199" | "0f3d") # Sierra Wireless
      echo "Sierra Wireless modem (VID:$vid PID:$pid)"
      load_module "sierra" || load_module "qmi_wwan"
      load_module "option"
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1bc7") # Telit
      echo "Telit modem (VID:$vid PID:$pid)"
      load_module "qmi_wwan" || load_module "cdc_ether"
      load_module "option"
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "12d1") # Huawei
      echo "Huawei modem (VID:$vid PID:$pid)"
      load_module "cdc_ether" || load_module "qmi_wwan"
      load_module "option"
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    "1e0e") # Fibocom
      echo "Fibocom modem (VID:$vid PID:$pid)"
      load_module "qmi_wwan" || load_module "cdc_mbim"
      load_module "option"
      echo "$vid $pid" > /sys/bus/usb-serial/drivers/option1/new_id
      ;;
    *) echo "Unknown device (VID:$vid PID:$pid), trying generic drivers"
       load_module "qmi_wwan" || load_module "cdc_mbim" || load_module "cdc_ether"
       load_module "option"
       ;;
  esac
done
echo "Kmod loading complete, check $LOGFILE for details"
