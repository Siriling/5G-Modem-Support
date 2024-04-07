#!/bin/sh
# Copyright (C) 2023 Siriling <siriling@qq.com>

#脚本目录
SCRIPT_DIR="/usr/share/modem"
source "${SCRIPT_DIR}/modem_debug.sh"

#获取设备物理地址
# $1:网络设备或串口
get_device_physical_path()
{
    local device_name="$(basename "$1")"
    local device_path="$(find /sys/class/ -name $device_name)"
    local device_physical_path="$(readlink -f $device_path/device/)"
    echo "$device_physical_path"
}

#获取设备总线地址
# $1:网络设备
# $2:USB或者PCIE标志
get_device_bus_path()
{
    local device_physical_path="$(get_device_physical_path $1)"

    local device_bus_path="$device_physical_path"
    if [ "$2" = "usb" ]; then
        #USB设备路径需要再获取上一层
		device_bus_path=$(dirname "$device_bus_path")

        #判断路径是否带有usb（排除其他eth网络设备）
        if [[ "$device_physical_path" = *"usb"* ]]; then
            echo "$device_bus_path"
        fi
    elif [ "$2" = "pcie" ]; then
        echo "$device_bus_path"
	fi
}

#获取USB串口总线地址
# $1:USB串口
get_usb_device_bus_path()
{
    local device_physical_path="$(get_device_physical_path $1)"

    #获取父路径的上两层
    local tmp=$(dirname "$device_physical_path")
    local device_bus_path=$(dirname $tmp)
    
    echo "$device_bus_path"
}

#获取PCIE串口总线地址
# $1:PCIE串口
get_pcie_device_bus_path()
{
    local device_physical_path="$(get_device_physical_path $1)"

    local device_bus_path="$device_physical_path"
	if [ "$device_name" != "mhi_BHI" ]; then #未考虑多个mhi_BHI的情况
		device_bus_path=$(dirname "$device_physical_path")
	fi

    echo "$device_bus_path"
}

#设置模组配置
# $1:模组序号
# $2:设备数据接口
# $3:总线地址
set_modem_config()
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

#设置模组串口配置
# $modem_count:模组计数
# $1:总线地址
# $2:串口
set_port_config()
{
    #处理获取到的地址
    # local substr="${1/\/sys\/devices\//}" #x86平台，替换掉/sys/devices/
    # local substr="${1/\/sys\/devices\/platform\//}" #arm平台，替换掉/sys/devices/platform/
    # local substr="${1/\/sys\/devices\/platform\/soc\//}" #arm平台，替换掉/sys/devices/platform/soc/
    local substr=$1 #路径存在不同，暂不处理

    for i in $(seq 0 $((modem_count-1))); do
        #当前模组的物理地址
        local path=$(uci -q get modem.modem$i.path)
    	if [ "$substr" = "$path" ]; then
            #添加新的串口
            uci add_list modem.modem${i}.ports="$2"
            #写入到配置中（解决老版本luci问题）
            uci commit modem
            #判断是不是AT串口
            local response="$(sh ${SCRIPT_DIR}/modem_at.sh $2 'ATI')"
            local str1="No" #No response from modem.
            local str2="failed"
            if [[ "$response" != *"$str1"* ]] && [[ "$response" != *"$str2"* ]] && [ -n "$response" ]; then
                #原先的AT串口会被覆盖掉（是否需要加判断）
                uci set modem.modem${i}.at_port="$2"
                set_modem_info_config "$i" "$2"
            fi
            break
	    fi
    done
}

#设置模组信息（名称、制造商、拨号模式）
# $modem_count:模组计数
# $1:模组序号
# $2:AT串口
set_modem_info_config()
{
    #获取数据接口
    local data_interface=$(uci -q get modem.modem$1.data_interface)
    
    #获取支持的模组
    local modem_support=$(cat ${SCRIPT_DIR}/modem_support.json)

    #获取模组名
    local at_response=$(sh ${SCRIPT_DIR}/modem_at.sh $2 "AT+CGMM" | sed -n '2p' | sed 's/\r//g' | tr 'A-Z' 'a-z')

    #获取模组信息
    local modem_info=$(echo $modem_support | jq '.modem_support.'$data_interface'."'$at_response'"')

    local modem_name
    local manufacturer
    local platform
    local mode
    local modes
    if [ "$modem_info" = "null" ]; then
        modem_name="unknown"
        manufacturer="unknown"
        platform="unknown"
        mode="unknown"
        modes="qmi gobinet ecm mbim rndis ncm"
    else
        #获取模组名
        modem_name="$at_response"
        #获取制造商
        manufacturer=$(echo $modem_info | jq -r '.manufacturer')
        #获取平台
        platform=$(echo $modem_info | jq -r '.platform')
        #获取当前的拨号模式
        mode=$(source ${SCRIPT_DIR}/$manufacturer.sh && "$manufacturer"_get_mode $2 $platform)
        #获取支持的拨号模式
        modes=$(echo $modem_info | jq -r '.modes[]')
    fi

    #设置模组名
    uci set modem.modem$1.name="$modem_name"
    #设置制造商
    uci set modem.modem$1.manufacturer="$manufacturer"
    #设置平台
    uci set modem.modem$1.platform="$platform"
    #设置当前的拨号模式
    uci set modem.modem$1.mode="$mode"
    #设置支持的拨号模式
    uci -q del modem.modem$1.modes #删除原来的拨号模式列表
    for mode in $modes; do
        uci add_list modem.modem$1.modes="$mode"
    done
}

#设置模组数量
set_modem_count()
{
    uci set modem.@global[0].modem_number="$modem_count"
    
    #数量为0时，清空模组列表
    if [ "$modem_count" = "0" ]; then
        for i in $(seq 0 $((modem_count-1))); do
            uci -q del modem.modem${i}
        done
    fi
}

#设置USB模组基本信息
# $1:USB网络设备
set_usb_modem_config()
{
    for network in $usb_network; do
        local usb_device_bus_path=$(get_device_bus_path $network "usb")
        if [ -z "$usb_device_bus_path" ]; then
            continue
        else
            set_modem_config $modem_count "usb" $usb_device_bus_path
        fi
    done
}

#设置PCIE模组基本信息
# $1:PCIE网络设备
set_pcie_modem_config()
{
    for network in $pcie_network; do
        local pcie_device_bus_path=$(get_device_bus_path $network "pcie")
        if [ -z "$pcie_device_bus_path" ]; then
            continue
        else
            set_modem_config $modem_count "pcie" $pcie_device_bus_path
        fi
    done
}

#模组计数
modem_count=0
#模组支持文件
modem_support_file="${SCRIPT_DIR}/modem_support"
#设置模组信息
modem_scan()
{
    #初始化
    modem_count=0
    ########设置模组基本信息########
    #USB  
    local usb_network
    usb_network="$(find /sys/class/net -name usb*)" #ECM RNDIS NCM
    set_usb_modem_config "$usb_network"
    usb_network="$(find /sys/class/net -name wwan*)" #QMI MBIM
    set_usb_modem_config "$usb_network"
    usb_network="$(find /sys/class/net -name eth*)" #RNDIS
    set_usb_modem_config "$usb_network"

    #PCIE
    local pcie_network
    pcie_network="$(find /sys/class/net -name mhi_hwip*)" #（通用mhi驱动）
    set_pcie_modem_config "$pcie_network"
    pcie_network="$(find /sys/class/net -name rmnet_mhi*)" #（制造商mhi驱动）
    set_pcie_modem_config "$pcie_network"

    ########设置模组串口########
    #清除原串口配置
    for i in $(seq 0 $((modem_count-1))); do
        uci -q del modem.modem$i.ports
    done
    #USB串口
    local usb_port=$(find /dev -name ttyUSB*)
    for port in $usb_port; do
        local usb_port_device_bus_path="$(get_usb_device_bus_path $port)"
        set_port_config $usb_port_device_bus_path $port
    done
    #PCIE串口
    local pcie_port
    pcie_port=$(find /dev -name wwan*)
    for port in $pcie_port; do
        local pcie_port_device_bus_path="$(get_pcie_device_bus_path $port)"
        set_port_config $pcie_port_device_bus_path $port
    done
    pcie_port=$(find /dev -name mhi*)
    for port in $pcie_port; do
        local pcie_port_device_bus_path="$(get_pcie_device_bus_path $port)"
        set_port_config $pcie_port_device_bus_path $port
    done
    ########设置模组数量########
    set_modem_count

    #写入到配置中
    uci commit modem
}

#测试时打开
# modem_scan