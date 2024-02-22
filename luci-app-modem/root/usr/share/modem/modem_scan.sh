#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/modem_debug.sh"

#获取USB串口总线地址
# $1:USB串口
getUSBDeviceBusPath()
{
    local device_name="$(basename "$1")"
    local device_path="$(find /sys/class/ -name $device_name)"
    local device_physical_path="$(readlink -f $device_path/device/)"

    #获取父路径的上两层
    local tmp=$(dirname "$device_physical_path")
    local device_bus_path=$(dirname $tmp)
    
    echo $device_bus_path
}

#获取设备总线地址
# $1:网络设备或PCIE串口
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
# $2:设备数据接口
# $3:总线地址
setModemConfig()
{
    #判断地址是否为net
    local path=$(basename "$3")
    if [ "$path" = "net" ]; then
        return
    fi

    #处理获取到的地址
    # local substr="${3/\/sys\/devices\//}" #x86平台，替换掉/sys/devices/
    # local substr="${3/\/sys\/devices\/platform\//}" #arm平台，替换掉/sys/devices/platform/
    # local substr="${3/\/sys\/devices\/platform\/soc\//}" #arm平台，替换掉/sys/devices/platform/soc/
    local substr=$3 #路径存在不同，暂不处理

    #获取网络接口
    local net_path="$(find $substr -name net | sed -n '1p')"
    local net_net_interface_path=$net_path

    #子目录下存在网络接口
    local net_count="$(find $substr -name net | wc -l)"
    if [ "$net_count" = "2" ]; then
        net_net_interface_path="$(find $substr -name net | sed -n '2p')"
    fi
    local network=$(ls $net_path)
    local network_interface=$(ls $net_net_interface_path)
    
    #设置配置
    uci set modem.modem$1="modem-device"
    uci set modem.modem$1.data_interface="$2"
    uci set modem.modem$1.path="$substr"
    uci set modem.modem$1.network="$network"
    uci set modem.modem$1.network_interface="$network_interface"
    
    #增加模组计数
    modem_count=$((modem_count + 1))
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
            local response=$(sh $current_dir/modem_at.sh $2 "ATI")
            local str1="No" #No response from modem.
            local str2="failed"
            if [[ "$response" != *"$str1"* ]] && [[ "$response" != *"$str2"* ]]; then
                #原先的AT串口会被覆盖掉（是否需要加判断）
                uci set modem.modem$i.at_port="$2"
                setModemInfoConfig $i $2
            fi
            break
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
    local line_count=$(wc -l < "$modem_support_file")
    local line_context
    for i in $(seq 1 $(($line_count))); do

        #获取一行的内容
        local line_context=$(sed -n $i'p' "$modem_support_file")
        #获取数据接口内容
        local data_interface_info=$(echo "$line_context" | cut -d ";" -f 4)
        if [ "$data_interface" = "$data_interface_info" ]; then
            #获取模块名
            local modem_name=$(echo "$line_context" | cut -d ";" -f 2)
            
            local at_result
            if [ "$modem_name" != "unknown" ]; then
                #获取AT命令返回的内容
                at_result=$(echo `sh $current_dir/modem_at.sh $2 "ATI" | sed -n '3p' | tr 'A-Z' 'a-z'`)
            else
                #数据库中没有此模块的信息，使用默认值
                at_result="unknown"
            fi

            if [[ "$at_result" = *"$modem_name"* ]]; then
                #设置模块名
                uci set modem.modem$1.name="$modem_name"

                #设置制造商
                local manufacturer=$(echo "$line_context" | cut -d ";" -f 1)
                uci set modem.modem$1.manufacturer="$manufacturer"

                #设置平台
                local platform=$(echo "$line_context" | cut -d ";" -f 3)
                uci set modem.modem$1.platform="$platform"

                #设置当前的拨号模式
                local mode
                if [ "$manufacturer" = "unknown" ]; then
                    mode="unknown"
                else
                    mode=$(source $current_dir/$manufacturer.sh && get_mode $2 $platform)
                fi
                uci set modem.modem$1.mode="$mode"

                #设置支持的拨号模式
                local modes=$(echo "$line_context" | cut -d ";" -f 5 | tr ',' ' ')

                #删除原来的拨号模式列表
                uci -q del modem.modem$1.modes
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
    
    #数量为0时，清空模块列表
    if [ "$modem_count" = "0" ]; then
        for i in $(seq 0 $((modem_count-1))); do
            uci -q del modem.modem$i
        done
    fi
}

#模块计数
modem_count=0
#模块支持文件
modem_support_file="$current_dir/modem_support"
#设置模块信息
modem_scan()
{
    #初始化
    modem_count=0
    ########设置模块基本信息########
    #USB  
    local usb_network
    usb_network=$(find /sys/class/net -name usb*)
    for network in $usb_network; do
        local usb_device_bus_path=$(getDeviceBusPath $network)
        setModemConfig $modem_count "usb" $usb_device_bus_path
    done
    usb_network=$(find /sys/class/net -name wwan*)
    for network in $usb_network; do
        local usb_device_bus_path=$(getDeviceBusPath $network)
        setModemConfig $modem_count "usb" $usb_device_bus_path
    done
    #PCIE
    local pcie_network
    pcie_network=$(find /sys/class/net -name mhi_hwip*) #（通用mhi驱动）
    for network in $pcie_network; do
        local pcie_device_bus_path=$(getDeviceBusPath $network)
        setModemConfig $modem_count "pcie" $pcie_device_bus_path
    done
    pcie_network=$(find /sys/class/net -name rmnet_mhi*) #（制造商mhi驱动）
    for network in $pcie_network; do
        local pcie_device_bus_path=$(getDeviceBusPath $network)
        setModemConfig $modem_count "pcie" $pcie_device_bus_path
    done

    ########设置模块串口########
    #清除原串口配置
    for i in $(seq 0 $((modem_count-1))); do
        uci -q del modem.modem$i.ports
    done
    #USB串口
    local usb_port=$(find /dev -name ttyUSB*)
    for port in $usb_port; do
        local usb_port_device_bus_path=$(getUSBDeviceBusPath $port)
        setPortConfig $usb_port_device_bus_path $port
    done
    #PCIE串口
    local pcie_port
    pcie_port=$(find /dev -name wwan*)
    for port in $pcie_port; do
        local pcie_port_device_bus_path=$(getDeviceBusPath $port)
        setPortConfig $pcie_port_device_bus_path $port
    done
    pcie_port=$(find /dev -name mhi*)
    for port in $pcie_port; do
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