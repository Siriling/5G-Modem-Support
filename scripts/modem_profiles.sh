#!/bin/sh
# Advanced modem profile database
get_profile() {
  VID="$1"
  case $VID in
    "05c6") echo "Quectel|qmi_wwan,option|AT+CGMR,AT+CSQ|nr5g_band|QMI" ;;
    "1199" | "0f3d") echo "Sierra Wireless|sierra,option|AT+CGMR,AT!GSTATUS?|band|MBIM" ;;
    "1bc7") echo "Telit|qmi_wwan,option|AT+CGMR,AT#CSQ|band|QMI" ;;
    "12d1") echo "Huawei|cdc_ether,option|AT+CGMR,AT+CSQ|band|PPP" ;;
    "1e0e") echo "Fibocom|qmi_wwan,option|AT+CGMR,AT+CSQ|nr5g_band|QMI" ;;
    *) echo "Unknown|qmi_wwan,option|AT+CGMR,AT+CSQ|band|QMI" ;;
  esac
}
