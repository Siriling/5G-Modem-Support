#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/modem_debug.sh"
source "$current_dir/modem_scan.sh"

#拨号
# $1:AT串口
# $2:制造商
ecm_dial()
{
    #拨号
    local manufacturer=$2
    local at_command
    if [ "$manufacturer" = "quectel" ]; then
        at_command='ATI'
    elif [ "$manufacturer" = "fibocom" ]; then
        at_command='AT+GTRNDIS=1,1'
    else
        at_command='ATI'
    fi
    sh "$current_dir/modem_at.sh" $1 $at_command
}

#拨号
# $1:AT串口
# $2:制造商
gobinet_dial()
{
    #拨号
    local manufacturer=$2
    local at_command
    if [ "$manufacturer" = "quectel" ]; then
        at_command='ATI'
    elif [ "$manufacturer" = "fibocom" ]; then
        at_command='AT$QCRMCALL=1,1'
    else
        at_command='ATI'
    fi
    sh "$current_dir/modem_at.sh" $1 $at_command
}

#检查模组网络连接
# $1:配置ID
# $2:AT串口
# $3:制造商
# $4:拨号模式
modem_network_task()
{
    while true; do
        local enable=$(uci -q get modem.@global[0].enable)
        if [ "$enable" != "1" ] ;then
            break
        fi
        enable=$(uci -q get modem.$1.enable)
        if [ "$enable" != "1" ] ;then
            break
        fi

        #网络连接检查
        debug "开启网络连接检查任务"
        local at_port=$2
        local at_command="AT+COPS?"
        local connect_status=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p')
        if [ "$connect_status" = "0" ]; then
            case "$4" in
                "ecm") ecm_dial $at_port $3 ;;
                "gobinet") gobinet_dial $at_port $3 ;;
                *) ecm_dial $at_port $3 ;;
            esac
        fi
        debug "结束网络连接检查任务"
        sleep 10s
    done
}

modem_network_task $1 $2 $3 $4