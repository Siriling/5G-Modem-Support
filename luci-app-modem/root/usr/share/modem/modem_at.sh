#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/modem_debug.sh"

#发送at命令
# $1 AT串口
# $2 AT命令
at $1 $2