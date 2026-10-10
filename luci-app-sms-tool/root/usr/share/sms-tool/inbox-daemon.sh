#!/bin/sh
# Copyright (C) 2026 ainuoyan; GNU General Public License v3.
# Save and verify SMS before releasing their modem slots, 2026-10-10.
while :; do
    port="$(uci -q get sms_tool.general.readport)"
    case "$port" in
        /dev/tty*)
            flock -n /var/lock/sms-tool-inbox.lock \
                flock -n "/var/lock/modem-at-${port##*/}.lock" \
                /usr/bin/lua /usr/share/sms-tool/inbox-worker.lua collect
            ;;
    esac
    sleep 10
done
