#!/bin/sh
# Diagnostics for modem signal and status
echo "AT+CMEE=1;+CSQ;+QNWINFO" | atinout - /dev/ttyUSB2 /tmp/diag_result
cat /tmp/diag_result
echo "$(date): $(cat /tmp/diag_result)" >> /var/log/modem_diag.log
echo "Signal and network info logged to /var/log/modem_diag.log"
