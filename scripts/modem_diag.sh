#!/bin/sh
# Diagnostics for modem
echo "AT+CMEE=1;+CSQ;+QNWINFO" | atinout - /dev/ttyUSB2 /tmp/diag_result
cat /tmp/diag_result
echo "$(date): $(cat /tmp/diag_result)" >> /var/log/modem_diag.log
echo "Logged to /var/log/modem_diag.log"
