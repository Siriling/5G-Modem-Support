#!/bin/sh
# Baiwang/DJI QDC507 uses the LTE Quectel AT dialect, not the RM5xx dialect.
SCRIPT_DIR="/usr/share/modem"
source "${SCRIPT_DIR}/quectel.sh"

baiwang_get_mode() { quectel_get_mode "$@"; }
baiwang_get_connect_status() { quectel_get_connect_status "$@"; }
baiwang_get_voltage() { quectel_get_voltage "$@"; }
baiwang_get_temperature() { quectel_get_temperature "$@"; }

baiwang_set_mode()
{
    [ "$2" = "ecm" ] || return 1
    quectel_set_mode "$@"
}

baiwang_get_network_prefer()
{
    lua "${SCRIPT_DIR}/baiwang_control.lua" get "$1"
}

baiwang_set_network_prefer()
{
    lua "${SCRIPT_DIR}/baiwang_control.lua" set_network "$1" "$2"
}

baiwang_set_band_prefer()
{
    lua "${SCRIPT_DIR}/baiwang_control.lua" set_band "$1" "$2"
}

baiwang_dial()
{
    local at_port="$1"
    local define_connect="${2:-1}"
    local response=$(at "$at_port" "AT+CGACT?")
    echo "$response" | grep -q "+CGACT: ${define_connect},1" && return 0
    at "$at_port" "AT+CGACT=1,${define_connect}" >/dev/null
}

baiwang_stop_dial()
{
    at "$1" "AT+CGACT=0,${2:-1}"
}

get_baiwang_info()
{
    at_port="$1"
    platform="$2"
    define_connect="$3"
    quectel_base_info
    quectel_sim_info
    [ "$sim_status" = "ready" ] || return
    iccid=$(at "$at_port" 'AT+QCCID' | sed -n 's/^+QCCID: *//p' | tr -d '\r')
    connect_status=$(baiwang_get_connect_status "$at_port" "$define_connect")
    [ "$connect_status" = "connect" ] || return
    network_type=$(at "$at_port" 'AT+QNWINFO' | awk -F'"' '/^\+QNWINFO:/ {print $2}')
    quectel_cell_info
    # This LTE firmware ends QENG after CQI (RM5xx has more fields).
    lte_cql=$(printf '%s' "$lte_cql" | tr -d '\r')
    [ -n "$lte_freq_band_ind" ] && lte_band="B${lte_freq_band_ind}"
}
