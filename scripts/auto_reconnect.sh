#!/bin/sh
# Auto-reconnect modem when IP is lost
INTERFACE="wwan0"  # Adjust to your modem interface
PROTOCOL="qmi"     # Default protocol, adjust as needed
while true; do
  # Check if interface has an IP address
  if ! ip addr show $INTERFACE | grep -q "inet "; then
    echo "No IP detected on $INTERFACE, attempting to reconnect..."
    sh /usr/bin/modem_connect.sh $PROTOCOL
    sleep 5  # Wait for connection to stabilize
  else
    echo "IP is present on $INTERFACE, no action needed"
  fi
  sleep 30  # Check every 30 seconds
done
