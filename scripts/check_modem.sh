#!/bin/bash
echo "Detecting modem..."
lsusb
echo "Checking modem status..."
mmcli -m 0
