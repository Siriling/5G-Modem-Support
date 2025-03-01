#!/bin/sh
echo "AT+CMEE=1;+CSQ;+QNWINFO" | atinout - /dev/ttyUSB2 /tmp/diag_result
cat /tmp/diag_result >> /var/log/modem_diag.log
