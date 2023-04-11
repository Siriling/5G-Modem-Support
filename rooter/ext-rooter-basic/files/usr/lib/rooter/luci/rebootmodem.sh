#!/bin/sh

ROOTER=/usr/lib/rooter


CURRMODEM=1
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
if [ ! -z "$CPORT" ]; then
	ATCMDD="AT+CFUN=1,1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
fi
CURRMODEM=2
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
if [ ! -z "$CPORT" ]; then
	ATCMDD="AT+CFUN=1,1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
fi
reboot -f