#!/bin/bash
echo "Connecting to 5G network..."
mmcli -i 0 -c "apn=internet"
echo "Connection established. Check IP:"
ip addr show
