#!/bin/sh
INTERFACE="wwan0"
PROTOCOL="qmi"
while true; do if ! ip addr show $INTERFACE | grep -q "inet "; then echo "No IP detected, reconnecting..."; sh /usr/bin/modem_connect.sh $PROTOCOL; sleep 5; else echo "IP present"; fi; sleep 30; done
