#!/bin/sh
# Modem profile database
get_profile() {
  VID="$1"
  case $VID in
    "05c6") echo "Quectel: qmi_wwan,option|AT+CSQ|nr5g_band" ;;
    "1199" | "0f3d") echo "Sierra Wireless: sierra,option|AT!GSTATUS?|band" ;;
    "1bc7") echo "Telit: qmi_wwan,option|AT#CSQ|band" ;;
    "12d1") echo "Huawei: cdc_ether,option|AT+CSQ|band" ;;
    "1e0e") echo "Fibocom: qmi_wwan,option|AT+CSQ|nr5g_band" ;;
    *) echo "Unknown: qmi_wwan,option|AT+CSQ|band" ;;
  esac
}
