#!/bin/sh
BANDS="$1"
echo "AT+QNWPREFCFG=\"nr5g_band\",$BANDS" | atinout - /dev/ttyUSB2 /tmp/band_result
