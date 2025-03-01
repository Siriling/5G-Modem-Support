#!/bin/bash
echo "Welcome to 5G Modem Support Tool"
echo "1. Check modem status"
echo "2. Connect to network"
echo "3. Exit"
read -p "Choose an option: " choice

case $choice in
  1) bash scripts/check_modem.sh ;;
  2) bash examples/example_connect.sh ;;
  3) echo "Goodbye!" ; exit 0 ;;
  *) echo "Invalid option" ;;
esac
