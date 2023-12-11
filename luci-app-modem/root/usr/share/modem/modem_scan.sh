#!/bin/sh

#获取设备总线地址
getDeviceBusPath()
{
    local device_name="$(basename "$1")"
    local device_path="$(find /sys/class/ -name $device_name)"
    local device_physical_path="$(readlink -f $device_path/device/)"

    local device_bus_path=$device_physical_path
	if [ "$device_name" != "mhi_BHI" ]; then #未考虑多个mhi_BHI的情况
		device_bus_path=$(dirname "$device_physical_path")
	fi
    echo $device_bus_path
}

#设置模块配置
# $1:模块序号
# $2:设备(设备节点)
# $3:设备数据接口
# $4:总线地址
setModemConfig()
{
    #处理获取到的地址
    # local substr="${4/\/sys\/devices\//}" #x86平台，替换掉/sys/devices/
    # local substr="${4/\/sys\/devices\/platform\//}" #arm平台，替换掉/sys/devices/platform/
    # local substr="${4/\/sys\/devices\/platform\/soc\//}" #arm平台，替换掉/sys/devices/platform/soc/
    local substr=$4 #路径存在不同，暂不处理

    #获取网络接口
    local net_path="$(find $substr -name net | sed -n '1p')"
    local net_net_interface_path=$net_path

    #子目录下存在网络接口
    local net_count="$(find $substr -name net | wc -l)"
    if [ "$net_count" = "2" ]; then
        net_net_interface_path="$(find $substr -name net | sed -n '2p')"

    fi
    local net=$(ls $net_path)
    local net_interface=$(ls $net_net_interface_path)
    
    #设置配置
    uci set modem.modem$1="modem-device"
    uci set modem.modem$1.device_node="$2"
    uci set modem.modem$1.data_interface="$3"
    uci set modem.modem$1.path="$substr"
    uci set modem.modem$1.net="$net"
    uci set modem.modem$1.net_interface="$net_interface"
}

#设置模块网络接口
# $1:模块序号
# $2:总线地址
setModemNet()
{
    local net_count="$(find $2 -name net | wc -l)"
    local net_path
    if [ "$net_count" = "1" ]; then
        net_path="$(find $2 -name net | sed -n '1p')"
    elif [ "$net_count" = "2" ]; then
        net_path="$(find $2 -name net | sed -n '2p')"
    fi
    local net=$(ls $net_path)

    #设置配置
    uci set modem.modem$1.net="$net"
}

#设置模块串口配置
# $modem_count:模块计数
# $1:总线地址
# $2:串口
setPortConfig()
{
    #处理获取到的地址
    # local substr="${1/\/sys\/devices\//}" #x86平台，替换掉/sys/devices/
    # local substr="${1/\/sys\/devices\/platform\//}" #arm平台，替换掉/sys/devices/platform/
    # local substr="${1/\/sys\/devices\/platform\/soc\//}" #arm平台，替换掉/sys/devices/platform/soc/
    local substr=$1 #路径存在不同，暂不处理

    for i in $(seq 0 $((modem_count-1))); do
        #当前模块的物理地址
        local path=$(uci -q get modem.modem$i.path)
    	if [ "$substr" = "$path" ]; then
            #添加新的串口
            uci add_list modem.modem$i.ports="$2"
            #判断是不是AT串口
            local result=$(sh modem_at.sh $2 "ATI")
            local str1="No response from modem."
            local str2="failed"
            if [ "$result" != "$str1" ] && [[ "$result" != *"failed"* ]]; then
                uci set modem.modem$i.at_port="$2"
                setModemInfoConfig $i $2
            fi
	    fi
    done
}

#设置模块信息（名称、制造商、拨号模式）
# $modem_count:模块计数
# $1:模块序号
# $2:AT串口
setModemInfoConfig()
{
    #获取数据接口
    local data_interface=$(uci -q get modem.modem$1.data_interface)
    
    #遍历模块信息文件
    local line_count=$(wc -l < "$modem_info_file")
    local line_context
    for i in $(seq 1 $(($line_count))); do

        #获取一行的内容
        local line_context=$(sed -n $i'p' "$modem_info_file")
        #获取数据接口内容
        local data_interface_info=$(echo "$line_context" | cut -d ";" -f 3)
        if [ "$data_interface" = "$data_interface_info" ]; then
            #获取模块名
            local modem_name=$(echo "$line_context" | cut -d ";" -f 2)
            #获取AT命令返回的内容
            local at_result=$(echo `sh modem_at.sh $2 "ATI" | sed -n '3p' | tr 'A-Z' 'a-z'`)
            if [[ "$at_result" = *"$modem_name"* ]]; then
                #设置模块名
                uci set modem.modem$1.name="$modem_name" 

                #设置制造商
                local manufacturer=$(echo "$line_context" | cut -d ";" -f 1)
                uci set modem.modem$1.manufacturer="$manufacturer"

                #设置拨号模式
                local modes=$(echo "$line_context" | cut -d ";" -f 4 | tr ',' ' ')

                #删除原来的拨号模式列表
                uci del modem.modem$1.modes
                #添加新的拨号模式列表
                for mode in $modes; do
                    uci add_list modem.modem$1.modes="$mode"
                done
                break
            fi

            #数据库中没有此模块的信息，使用默认值
            if [ $i -ge $(($line_count-1)) ]; then

                #设置模块名
                uci set modem.modem$1.name="$modem_name" 
                #设置制造商
                local manufacturer=$(echo "$line_context" | cut -d ";" -f 1)
                uci set modem.modem$1.manufacturer="$manufacturer"
                #删除原来的拨号模式列表
                uci del modem.modem$1.modes
                #添加新的拨号模式列表
                for mode in $modes; do
                    uci add_list modem.modem$1.modes="$mode"
                done
                break
            fi
        fi
    done
}

#设置模块数量
setModemCount()
{
    uci set modem.global.modem_number="$modem_count"
}

#模块计数
modem_count=0
#模块信息文件
modem_info_file="modem_info"
#设置模块信息
modem_scan()
{
    #初始化
    modem_count=0
    ########设置模块基本信息########
    #USB
    local usb_devices=$(ls /dev/cdc-wdm*)
    for device in $usb_devices; do
        local usb_device_bus_path=$(getDeviceBusPath $device)
        setModemConfig $modem_count $device "usb" $usb_device_bus_path
        modem_count=$((modem_count + 1))
    done
    #PCIE
    local pcie_devices=$(ls /dev/mhi_QMI*)
    for device in $pcie_devices; do
        local pcie_device_bus_path=$(getDeviceBusPath $device)
        setModemConfig $modem_count $device "pcie" $pcie_device_bus_path
        modem_count=$((modem_count + 1))
    done

    #写入到配置中
    # uci commit modem

    ########设置模块串口########
    #清除原串口配置
    for i in $(seq 0 $((modem_count-1))); do
        uci del modem.modem$i.ports
    done
    #USB串口
    local usb_port=$(ls /dev/ttyUSB*)
    for port in $usb_port; do
        local device_node=$(uci -q get modem.modem$i.device_node)
        if [ "$port" = "$device_node" ]; then
            continue
        fi
        local usb_port_device_bus_path=$(getDeviceBusPath $port)
        setPortConfig $usb_port_device_bus_path $port
    done
    #PCIE串口
    local pcie_port=$(ls /dev/mhi*)
    for port in $pcie_port; do
        local device_node=$(uci -q get modem.modem$i.device_node)
        if [ "$port" = "$device_node" ]; then
            continue
        fi
        local pcie_port_device_bus_path=$(getDeviceBusPath $port)
        setPortConfig $pcie_port_device_bus_path $port
    done

    ########设置模块数量########
    setModemCount

    #写入到配置中
    uci commit modem
}

#测试时打开
# modem_scan