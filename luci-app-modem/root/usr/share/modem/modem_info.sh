#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/modem_debug.sh"
source "$current_dir/quectel.sh"
source "$current_dir/fibocom.sh"
source "$current_dir/simcom.sh"

#初值化数据结构
init_modem_info()
{
	#基本信息
	name='' 		#名称
	manufacturer='' #制造商
	revision='-'	#固件版本
	at_port='-'		#AT串口
	mode=''			#拨号模式
	temperature="NaN $(printf "\xc2\xb0")C"	#温度
    update_time=''	#更新时间

	#SIM卡信息
	isp="-"			#运营商（互联网服务提供商）
	imei='-'		#IMEI
	imsi='-'		#IMSI
	iccid='-'		#ICCID
	phone='-'		#SIM卡号码（手机号）

	#信号信息
	net_type="-"	#蜂窝网络类型
	csq=""			#CSQ
	per=""			#信号强度
	rssi="" 		#信号接收强度 RSSI
	ECIO="-"		#参考信号接收质量 RSRQ ecio
	ECIO1=" "		#参考信号接收质量 RSRQ ecio1
	RSCP="-"		#参考信号接收功率 RSRP rscp0
	RSCP1=" "		#参考信号接收功率 RSRP rscp1
	SINR="-"		#信噪比 SINR  rv["sinr"]
	NETMODE="-"		#连接状态监控 rv["netmode"]

	#基站信息
	MCC=""
	eNBID=""
	TAC=""
	cell_id=""
	LBAND="-" #频段
	CHANNEL="-" #频点
	PCI="-" #物理小区标识
	qos="" #最大Qos级别
}

#保存模块数据
info_to_json()
{
    modem_info="{
		\"manufacturer\":\"$manufacturer\",
		\"revision\":\"$revision\",
		\"at_port\":\"$at_port\",
		\"mode\":\"$mode\",
		\"temperature\":\"$temperature\",
		\"update_time\":\"$update_time\",

		\"isp\":\"$isp\",
		\"imei\":\"$imei\",
		\"imsi\":\"$imsi\",
		\"iccid\":\"$iccid\",
		\"phone\":\"$phone\",

		\"net_type\":\"$net_type\",
		\"csq\":\"$csq\",
		\"per\":\"$per\",
		\"rssi\":\"$rssi\"

    
    }"
}
        # echo $ECIO #参考信号接收质量 RSRQ ecio
        # echo $ECIO1 #参考信号接收质量 RSRQ ecio1
        # echo $RSCP #参考信号接收功率 RSRP rscp0
        # echo $RSCP1 #参考信号接收功率 RSRP rscp1
        # echo $SINR #信噪比 SINR  rv["sinr"]
        # echo $NETMODE #连接状态监控 rv["netmode"]
        # echo '---------------------------------'
		# #基站信息
        # echo $COPS_MCC #MCC
        # echo $$COPS_MNC #MNC
        # echo $LAC  #eNB ID
        # echo ''  #LAC_NUM
        # echo $RNC #TAC
        # echo '' #RNC_NUM
        # echo $CID
        # echo ''  #CID_NUM
        # echo $LBAND
        # echo $CHANNEL
        # echo $PCI
        # echo $MODTYPE
        # echo $QTEMP

#获取模组信息
get_modem_info()
{
	update_time=$(date +"%Y-%m-%d %H:%M:%S")

	debug "检查模块的AT串口"
	#获取模块AT串口
	if [ -z "$at_port" ]; then
		debug "模块0没有找到AT串口"
		return
	fi

	debug "检查SIM状态"
	local sim_status=$(echo `sh $current_dir/modem_at.sh $at_port "AT+CPIN?"`)
    local sim_error=$(echo "$sim_status" | grep "ERROR")
	if [ -n "$sim_error" ]; then
		debug "未插入SIM卡"
        sleep 1s
		return
	fi
	local sim_ready=$(echo "$sim_status" | grep "READY")
	if [ -n "$sim_ready" ]; then
		debug "SIM卡正常"
	else
		debug "SIM卡被锁定"
		sleep 1s
		return
	fi

    debug "根据模块类型开始采集数据"
	#更多信息获取
	case $manufacturer in
		"quectel") get_quectel_info $at_port ;;
		"fibocom") get_fibocom_info $at_port ;;
		"simcom") get_simcom_info $at_port ;;
		"*") debug "未适配该模块" ;;
	esac

	#获取更新时间
	update_time=$(date +"%Y-%m-%d %H:%M:%S")
}

#获取模组数据信息
# $1:AT串口
# $2:制造商
modem_info()
{
	#初值化模组信息
    debug "初值化模组信息"
    init_modem_info
    debug "初值化模组信息完成"

    #获取模组信息
	at_port=$1
	manufacturer=$2
	debug "获取模组信息"
	get_modem_info
	
    #整合模块信息
    info_to_json
	echo $modem_info

    #移动网络联网检查
	# checkMobileNetwork
}

modem_info $1 $2