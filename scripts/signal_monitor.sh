#!/bin/sh
# Monitor modem signal continuously
while true; do
  sh /usr/bin/modem_diag.sh
  sleep 10
done
