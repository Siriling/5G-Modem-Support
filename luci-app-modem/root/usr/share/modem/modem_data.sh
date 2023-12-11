#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/modem_debug.sh"
source "$current_dir/modem_scan.sh"
source "$current_dir/quectel.sh"
source "$current_dir/fibocom.sh"
source "$current_dir/simcom.sh"

#初值化数据结构
initData()
{
    Date=''
	CHANNEL="-" 
	ECIO="-"
	RSCP="-"
	ECIO1=" "
	RSCP1=" "
	NETMODE="-"
	LBAND="-"
	PCI="-"
	CTEMP="-"
	net_type="-"
	SINR="-"
	IMEI='-'
	IMSI='-'
	ICCID='-'
	phone='-'
	manufacturer=''
	modem=''
}

#保存模块数据
setData()
{
    {
        echo $modem #'RM520N-GL'
        echo $manufacturer #制造商
        # echo '1e0e:9001' #厂商号
        echo $COPS #运营商
        echo $at_port #AT串口
        echo $TEMP #温度
        echo $mode #拨号模式
        echo '---------------------------------'
        echo $IMEI #imei
        echo $IMSI #imsi
        echo $ICCID #iccid
        echo $phone #phone
        echo '---------------------------------'
        
        echo $net_type
        echo $CSQ
        echo $CSQ_PER
        echo $CSQ_RSSI
        echo $ECIO #参考信号接收质量 RSRQ ecio
        echo $ECIO1 #参考信号接收质量 RSRQ ecio1
        echo $RSCP #参考信号接收功率 RSRP rscp0
        echo $RSCP1 #参考信号接收功率 RSRP rscp1
        echo $SINR #信噪比 SINR  rv["sinr"]
        echo $NETMODE #连接状态监控 rv["netmode"]
        echo '---------------------------------'

        echo $COPS_MCC #MCC
        echo $$COPS_MNC #MNC
        echo $LAC  #eNB ID
        echo ''  #LAC_NUM
        echo $RNC #TAC
        echo '' #RNC_NUM
        echo $CID
        echo ''  #CID_NUM
        echo $LBAND
        echo $CHANNEL
        echo $PCI

        echo $Date

        echo $MODTYPE
        echo $QTEMP
    
    } > /tmp/modem_cell.file
}

#采集模块数据（暂时设置为单模块信息收集）
data_acquisition()
{
	debug "--检查模块的AT串口--"
	#获取模块AT串口
	at_port=$(uci -q get modem.modem0.at_port)
	if [ -z "$at_port" ]; then
		debug "模块0没有找到AT串口"
		return
	fi

	debug "--检查SIM状态--"
	local sim_status=$(echo `sh modem_at.sh $at_port "AT+CPIN?"`)
    local sim_error=$(echo "$sim_status" | grep "ERROR")
	if [ -n "$sim_error" ]; then
		debug "未插入SIM卡"
        sleep 5s
		return
	fi
	local sim_ready=$(echo "$sim_status" | grep "READY")
	if [ -n "$sim_ready" ]; then
		debug "SIM卡正常"
	else
		debug "SIM卡被锁定"
		sleep 5s
		return
	fi

    debug "--根据模块类型开始采集数据--"
	# 获取模块基本信息
	modem=$(uci -q get modem.modem0.name) #模块名称
    manufacturer=$(uci -q get modem.modem0.manufacturer) #制造商
	mode=$(uci -q get modem.@config[0].mode) #制造商

	#信号获取
	case $manufacturer in
		"quectel") get_quectel_data $at_port ;;
		"fibocom") get_fibocom_data $at_port ;;
		"simcom") et_simcom_data $at_port ;;
		"*") debug "未适配该模块" ;;
	esac
}

#数据采集循环
data_acquisition_task()
{
	while true; do
        enable=$(uci -q get modem.global.enable)
        if [ "$enable" = "1" ] ;then
            modem_scan
            debug "------------------------------开启任务---------------------------"
            data_acquisition
            setData
            debug "------------------------------结束任务---------------------------"
        fi
        sleep 10s
    done
}

main()
{
	#扫描并配置模块信息
	modem_scan
	sleep 1s

	#初值化模块数据
    debug "开启数据采集服务"
    initData
    debug "初值化数据完成"
    sleep 1s

    #采集模块数据
	debug "采集数据"
	data_acquisition
    #保存模块数据
    setData

	#数据采集循环
	data_acquisition_task

    #移动网络联网检查
	# checkMobileNetwork
}

main