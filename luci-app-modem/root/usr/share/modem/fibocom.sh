#!/bin/sh
current_dir="$(dirname "$0")"

#获取拨号模式
# $1:AT串口
get_fibocom_mode()
{
    local at_port="$1"
    at_command="AT+GTUSBMODE?"
    local mode_num=$(sh $current_dir/modem_at.sh $at_port $at_command | grep "+GTUSBMODE:" | sed 's/+GTUSBMODE: //g' | sed 's/\r//g')
    
    local mode
    case "$mode_num" in
        "17") mode="qmi" ;; #-
        "31") mode="qmi" ;; #-
        "32") mode="qmi" ;;
        # "32") mode="gobinet" ;;
        "18") mode="ecm" ;;
        "23") mode="ecm" ;; #-
        "33") mode="ecm" ;; #-
        "29") mode="mbim" ;; #-
        "30") mode="mbim" ;;
        "24") mode="rndis" ;;
        "18") mode='ncm' ;;
        *) mode="$mode_num" ;;
    esac
    echo "$mode"
}

#获取AT命令
get_fibocom_at_commands()
{
    local quick_commands="{\"quick_commands\":
        [
            {\"模组信息 > ATI\":\"ATI\"},
            {\"查询SIM卡状态 > AT+CPIN?\":\"AT+CPIN?\"},
            {\"查询此时信号强度 > AT+CSQ\":\"AT+CSQ\"},
            {\"查询网络信息 > AT+COPS?\":\"AT+COPS?\"},
            {\"查询PDP信息 > AT+CGDCONT?\":\"AT+CGDCONT?\"},
            {\"最小功能模式 > AT+CFUN=0\":\"AT+CFUN=0\"},
            {\"全功能模式 > AT+CFUN=1\":\"AT+CFUN=1\"},
            {\"设置当前使用的为卡1 > AT+GTDUALSIM=0\":\"AT+GTDUALSIM=0\"},
            {\"设置当前使用的为卡2 > AT+GTDUALSIM=1\":\"AT+GTDUALSIM=1\"},
            {\"ECM手动拨号 > AT+GTRNDIS=1,1\":\"AT+GTRNDIS=1,1\"},
            {\"ECM拨号断开 > AT+GTRNDIS=0,1\":\"AT+GTRNDIS=0,1\"},
            {\"查询当前端口模式 > AT+GTUSBMODE?\":\"AT+GTUSBMODE?\"},
            {\"QMI/GobiNet拨号 > AT+GTUSBMODE=32\":\"AT+GTUSBMODE=32\"},
            {\"ECM拨号 > AT+GTUSBMODE=18\":\"AT+GTUSBMODE=18\"},
            {\"MBIM拨号 > AT+GTUSBMODE=30\":\"AT+GTUSBMODE=30\"},
            {\"RNDIS拨号 > AT+GTUSBMODE=24\":\"AT+GTUSBMODE=24\"},
            {\"NCM拨号 > AT+GTUSBMODE=18\":\"AT+GTUSBMODE=18\"},
            {\"锁4G > AT+GTACT=2\":\"AT+GTACT=2\"},
            {\"锁5G > AT+GTACT=14\":\"AT+GTACT=14\"},
            {\"恢复自动搜索网络 > AT+GTACT=20\":\"AT+GTACT=20\"},
            {\"查询当前连接的网络类型 > AT+PSRAT?\":\"AT+PSRAT?\"},
            {\"查询模组IMEI > AT+CGSN?\":\"AT+CGSN?\"},
            {\"查询模组IMEI > AT+GSN?\":\"AT+GSN?\"},
            {\"更改模组IMEI > AT+GTSN=1,7,\\\"IMEI\\\"\":\"AT+GTSN=1,7,\\\"在此设置IMEI\\\"\"},
            {\"报告一次当前BBIC的温度 > AT+MTSM=1,6\":\"AT+MTSM=1,6\"},
            {\"报告一次当前射频的温度 > AT+MTSM=1,7\":\"AT+MTSM=1,7\"},
            {\"重置模组 > AT+CFUN=15\":\"AT+CFUN=15\"}
        ]
    }"
    echo "$quick_commands"
}

#获取连接状态
# $1:AT串口
get_connect_status()
{
    local at_port="$1"
    at_command="AT+CGDCONT?"

	local response=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'"' '{print $6}')
	local not_ip="0.0.0.0,0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0"

    local connect_status
	if [ "$response" = "$not_ip" ]; then
        connect_status="disconnect"
    else
        connect_status="connect"
    fi

    echo "$connect_status"
}

#基本信息
fibocom_base_info()
{
    debug "Fibocom base info"

    at_command="ATI"
    response=$(sh $current_dir/modem_at.sh $at_port $at_command)

    #Name（名称）
    name=$(echo "$response" | sed -n '3p' | sed 's/Model: //g' | sed 's/\r//g')
    #Manufacturer（制造商）
    manufacturer=$(echo "$response" | sed -n '2p' | sed 's/Manufacturer: //g' | sed 's/\r//g')
    #Revision（固件版本）
    revision=$(echo "$response" | sed -n '4p' | sed 's/Revision: //g' | sed 's/\r//g')

    #Mode（拨号模式）
    mode=$(get_fibocom_mode $at_port | tr 'a-z' 'A-Z')

    #Temperature（温度）
    at_command="AT+MTSM=1,6"
	response=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/+MTSM: //g' | sed 's/\r//g')
	if [ -n "$response" ]; then
		temperature="$response$(printf "\xc2\xb0")C"
	fi
}

#SIM卡信息
fibocom_sim_info()
{
    debug "Fibocom sim info"
    
    #SIM Slot（SIM卡卡槽）
    at_command="AT+GTDUALSIM"
	sim_slot=$(sh $current_dir/modem_at.sh $at_port $at_command | grep "+GTDUALSIM:" | awk -F'"' '{print $2}' | sed 's/SUB//g')

    #IMEI（国际移动设备识别码）
    at_command="AT+CGSN"
	imei=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/\r//g')

    #SIM Status（SIM状态）
    at_command="AT+CPIN?"
	response=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p')
    if [[ "$response" = *"READY"* ]]; then
        sim_status="ready"
    elif [[ "$response" = *"ERROR"* ]]; then
        sim_status="miss"
	else
        sim_status="locked"
    fi

    if [ "$sim_status" != "ready" ]; then
        return
    fi

    #ISP（互联网服务提供商）
    at_command="AT+COPS?"
    isp=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'"' '{print $2}')
    # if [ "$isp" = "CHN-CMCC" ] || [ "$isp" = "CMCC" ]|| [ "$isp" = "46000" ]; then
    #     isp="中国移动"
    # elif [ "$isp" = "CHN-UNICOM" ] || [ "$isp" = "UNICOM" ] || [ "$isp" = "46001" ]; then
    #     isp="中国联通"
    # elif [ "$isp" = "CHN-CT" ] || [ "$isp" = "CT" ] || [ "$isp" = "46011" ]; then
    #     isp="中国电信"
    # fi

    #SIM Number（SIM卡号码，手机号）
    at_command="AT+CNUM?"
	sim_number=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'"' '{print $2}')

    #IMSI（国际移动用户识别码）
    at_command="AT+CIMI"
	imsi=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/\r//g')

    #ICCID（集成电路卡识别码）
    at_command="AT+ICCID"
	iccid=$(sh $current_dir/modem_at.sh $at_port $at_command | grep -o "+ICCID:[ ]*[-0-9]\+" | grep -o "[-0-9]\{1,4\}")
}

#网络信息
fibocom_network_info()
{
    debug "Fibocom network info"

    #Connect Status（连接状态）
    connect_status=$(get_connect_status $at_port)
    if [ "$connect_status" != "connect" ]; then
        return
    fi

    #Network Type（网络类型）
    at_command="AT+PSRAT?"
    network_type=$(sh $current_dir/modem_at.sh $at_port $at_command | grep "+PSRAT:" | sed 's/+PSRAT: //g' | sed 's/\r//g')

    # #CSQ
    # local at_command="AT+CSQ"
    # csq=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'[ ,]+' '{print $2}')
    # if [ $CSQ = "99" ]; then
    #     csq=""
    # fi

    # #PER（信号强度）
    # if [ -n "$csq" ]; then
    #     per=$(($csq * 100/31))"%"
    # fi

    # #RSSI（信号接收强度）
    # if [ -n "$csq" ]; then
    #     rssi=$((2 * $csq - 113))" dBm"
    # fi
}

#获取频段
# $1:网络类型
# $2:频段数字
get_band()
{
    local band
    case $1 in
		"WCDMA") band="$2" ;;
		"LTE") band="$(($2-100))" ;;
        "NR") band="$2" band="${band#*50}" ;;
	esac
    echo "$band"
}

#获取上行带宽
# $1:上行带宽数字
get_ul_bandwidth()
{
    local ul_bandwidth
	case $1 in
        "6") ul_bandwidth="1.4" ;;
		"15"|"25"|"50"|"75"|"100") ul_bandwidth=$(( $1 / 5 )) ;;
	esac
    echo "$ul_bandwidth"
}

#获取下行带宽
# $1:下行带宽数字
get_dl_bandwidth()
{
    local dl_bandwidth
	case $1 in
        "6") ul_bandwidth="1.4" ;;
        "15"|"25"|"50"|"75"|"100") ul_bandwidth=$(( $1 / 5 )) ;;
	esac
    echo "$dl_bandwidth"
}

#获取NR下行带宽
# $1:下行带宽数字
get_nr_dl_bandwidth()
{
    local nr_dl_bandwidth
	case $1 in
		"0") nr_dl_bandwidth="5" ;;
		"10"|"15"|"20"|"25"|"30"|"40"|"50"|"60"|"70"|"80"|"90"|"100"|"200"|"400") nr_dl_bandwidth="$1" ;;
	esac
    echo "$nr_dl_bandwidth"
}

#获取参考信号接收功率
# $1:网络类型
# $2:参考信号接收功率数字
get_rsrp()
{
    local rsrp
    case $1 in
        "LTE") rsrp=$(($2-141)) ;;
        "NR") rsrp=$(($2-157)) ;;
	esac
    echo "$rsrp"
}

#获取参考信号接收质量
# $1:网络类型
# $2:参考信号接收质量数字
get_rsrq()
{
    local rsrq
    case $1 in
        "LTE") rsrq=$(awk "BEGIN{ printf \"%.2f\", $2 * 0.5 - 20 }" | sed 's/\.*0*$//') ;;
        "NR") rsrq=$(awk -v num="$2" "BEGIN{ printf \"%.2f\", (num+1) * 0.5 - 44 }" | sed 's/\.*0*$//') ;;
	esac
    echo "$rsrq"
}

#获取信号干扰比
# $1:信号干扰比数字
get_rssnr()
{
    #去掉小数点后的0
    local rssnr=$(awk "BEGIN{ printf \"%.2f\", $1 / 2 }" | sed 's/\.*0*$//')
    echo "$rssnr"
}

#获取接收信号功率
# $1:网络类型
# $2:接收信号功率数字
get_rxlev()
{
    local rxlev
    case $1 in
        "WCDMA") rxlev=$(($2-121)) ;;
        "LTE") rxlev=$(($2-141)) ;;
        "NR") rxlev=$(($2-157)) ;;
	esac
    echo "$rxlev"
}

#获取Ec/Io
# $1:Ec/Io数字
get_ecio()
{
    local ecio=$(awk "BEGIN{ printf \"%.2f\", $1 * 0.5 - 24.5 }" | sed 's/\.*0*$//')
    echo "$ecio"
}

#小区信息
fibocom_cell_info()
{
    debug "Fibocom cell info"

    #RSRQ，RSRP，SINR
    at_command='AT+GTCCINFO?'
    response=$(sh $current_dir/modem_at.sh $at_port $at_command)
    
    local rat=$(echo "$response" | grep "service" | awk -F' ' '{print $1}')
    response=$(echo "$response" | sed -n '4p')
    case $rat in
        "NR")
            network_mode="NR5G-SA Mode"
            nr_mcc=$(echo "$response" | awk -F',' '{print $3}')
            nr_mnc=$(echo "$response" | awk -F',' '{print $4}')
            nr_tac=$(echo "$response" | awk -F',' '{print $5}')
            nr_cell_id=$(echo "$response" | awk -F',' '{print $6}')
            nr_arfcn=$(echo "$response" | awk -F',' '{print $7}')
            nr_physical_cell_id=$(echo "$response" | awk -F',' '{print $8}')
            nr_band_num=$(echo "$response" | awk -F',' '{print $9}')
            nr_band=$(get_band "NR" $nr_band_num)
            nr_dl_bandwidth_num=$(echo "$response" | awk -F',' '{print $10}')
            nr_dl_bandwidth=$(get_nr_dl_bandwidth $nr_dl_bandwidth_num)
            nr_sinr=$(echo "$response" | awk -F',' '{print $11}')
            nr_rxlev_num=$(echo "$response" | awk -F',' '{print $12}')
            nr_rxlev=$(get_rxlev "NR" $nr_rxlev_num)
            nr_rsrp_num=$(echo "$response" | awk -F',' '{print $13}')
            nr_rsrp=$(get_rsrp "NR" $nr_rsrp_num)
            nr_rsrq_num=$(echo "$response" | awk -F',' '{print $14}' | sed 's/\r//g')
            nr_rsrq=$(get_rsrq "NR" $nr_rsrq_num)
        ;;
        "LTE-NR")
            network_mode="EN-DC Mode"
            #LTE
            endc_lte_mcc=$(echo "$response" | awk -F',' '{print $3}')
            endc_lte_mnc=$(echo "$response" | awk -F',' '{print $4}')
            endc_lte_tac=$(echo "$response" | awk -F',' '{print $5}')
            endc_lte_cell_id=$(echo "$response" | awk -F',' '{print $6}')
            endc_lte_earfcn=$(echo "$response" | awk -F',' '{print $7}')
            endc_lte_physical_cell_id=$(echo "$response" | awk -F',' '{print $8}')
            endc_lte_band_num=$(echo "$response" | awk -F',' '{print $9}')
            endc_lte_band=$(get_band "LTE" $endc_lte_band_num)
            ul_bandwidth_num=$(echo "$response" | awk -F',' '{print $10}')
            endc_lte_ul_bandwidth=$(get_ul_bandwidth $ul_bandwidth_num)
            endc_lte_dl_bandwidth="$endc_lte_ul_bandwidth"
            endc_lte_rssnr_num=$(echo "$response" | awk -F',' '{print $11}')
            endc_lte_rssnr=$(get_rssnr $endc_lte_rssnr_num)
            endc_lte_rxlev_num=$(echo "$response" | awk -F',' '{print $12}')
            endc_lte_rxlev=$(get_rxlev "LTE" $endc_lte_rxlev_num)
            endc_lte_rsrp_num=$(echo "$response" | awk -F',' '{print $13}')
            endc_lte_rsrp=$(get_rsrp "LTE" $endc_lte_rsrp_num)
            endc_lte_rsrq_num=$(echo "$response" | awk -F',' '{print $14}' | sed 's/\r//g')
            endc_lte_rsrq=$(get_rsrq "LTE" $endc_lte_rsrq_num)
            #NR5G-NSA
            endc_nr_mcc=$(echo "$response" | awk -F',' '{print $3}')
            endc_nr_mnc=$(echo "$response" | awk -F',' '{print $4}')
            endc_nr_tac=$(echo "$response" | awk -F',' '{print $5}')
            endc_nr_cell_id=$(echo "$response" | awk -F',' '{print $6}')
            endc_nr_arfcn=$(echo "$response" | awk -F',' '{print $7}')
            endc_nr_physical_cell_id=$(echo "$response" | awk -F',' '{print $8}')
            endc_nr_band_num=$(echo "$response" | awk -F',' '{print $9}')
            endc_nr_band=$(get_band "NR" $endc_nr_band_num)
            nr_dl_bandwidth_num=$(echo "$response" | awk -F',' '{print $10}')
            endc_nr_dl_bandwidth=$(get_nr_dl_bandwidth $nr_dl_bandwidth_num)
            endc_nr_sinr=$(echo "$response" | awk -F',' '{print $11}')
            endc_nr_rxlev_num=$(echo "$response" | awk -F',' '{print $12}')
            endc_nr_rxlev=$(get_rxlev "NR" $endc_nr_rxlev_num)
            endc_nr_rsrp_num=$(echo "$response" | awk -F',' '{print $13}')
            endc_nr_rsrp=$(get_rsrp "NR" $endc_nr_rsrp_num)
            endc_nr_rsrq_num=$(echo "$response" | awk -F',' '{print $14}' | sed 's/\r//g')
            endc_nr_rsrq=$(get_rsrq "NR" $endc_nr_rsrq_num)
            ;;
        "LTE"|"eMTC"|"NB-IoT")
            network_mode="LTE Mode"
            lte_mcc=$(echo "$response" | awk -F',' '{print $3}')
            lte_mnc=$(echo "$response" | awk -F',' '{print $4}')
            lte_tac=$(echo "$response" | awk -F',' '{print $5}')
            lte_cell_id=$(echo "$response" | awk -F',' '{print $6}')
            lte_earfcn=$(echo "$response" | awk -F',' '{print $7}')
            lte_physical_cell_id=$(echo "$response" | awk -F',' '{print $8}')
            lte_band_num=$(echo "$response" | awk -F',' '{print $9}')
            lte_band=$(get_band "LTE" $lte_band_num)
            ul_bandwidth_num=$(echo "$response" | awk -F',' '{print $10}')
            lte_ul_bandwidth=$(get_ul_bandwidth $ul_bandwidth_num)
            lte_dl_bandwidth="$lte_ul_bandwidth"
            lte_rssnr=$(echo "$response" | awk -F',' '{print $11}')
            lte_rxlev_num=$(echo "$response" | awk -F',' '{print $12}')
            lte_rxlev=$(get_rxlev "LTE" $lte_rxlev_num)
            lte_rsrp_num=$(echo "$response" | awk -F',' '{print $13}')
            lte_rsrp=$(get_rsrp "LTE" $lte_rsrp_num)
            lte_rsrq_num=$(echo "$response" | awk -F',' '{print $14}' | sed 's/\r//g')
            lte_rsrq=$(get_rsrq "LTE" $lte_rsrq_num)
        ;;
        "WCDMA"|"UMTS")
            network_mode="WCDMA Mode"
            wcdma_mcc=$(echo "$response" | awk -F',' '{print $3}')
            wcdma_mnc=$(echo "$response" | awk -F',' '{print $4}')
            wcdma_lac=$(echo "$response" | awk -F',' '{print $5}')
            wcdma_cell_id=$(echo "$response" | awk -F',' '{print $6}')
            wcdma_uarfcn=$(echo "$response" | awk -F',' '{print $7}')
            wcdma_psc=$(echo "$response" | awk -F',' '{print $8}')
            wcdma_band_num=$(echo "$response" | awk -F',' '{print $9}')
            wcdma_band=$(get_band "WCDMA" $wcdma_band_num)
            wcdma_ecno=$(echo "$response" | awk -F',' '{print $10}')
            wcdma_rscp=$(echo "$response" | awk -F',' '{print $11}')
            wcdma_rac=$(echo "$response" | awk -F',' '{print $12}')
            wcdma_rxlev_num=$(echo "$response" | awk -F',' '{print $13}')
            wcdma_rxlev=$(get_rxlev "WCDMA" $wcdma_rxlev_num)
            wcdma_reserved=$(echo "$response" | awk -F',' '{print $14}')
            wcdma_ecio_num=$(echo "$response" | awk -F',' '{print $15}' | sed 's/\r//g')
            wcdma_ecio=$(get_ecio $wcdma_ecio_num)
        ;;
    esac
}


# fibocom获取基站信息
Fibocom_Cellinfo()
{
    #baseinfo.gcom
    OX=$( sh $current_dir/modem_at.sh $at_port "ATI")
    OX=$( sh $current_dir/modem_at.sh $at_port "AT+CGEQNEG=1")

    #cellinfo0.gcom
    # OX1=$( sh $current_dir/modem_at.sh $at_port "AT+COPS=3,0;+COPS?")
    # OX2=$( sh $current_dir/modem_at.sh $at_port "AT+COPS=3,2;+COPS?")
    OX=$OX1" "$OX2

    #cellinfo.gcom
    OY1=$( sh $current_dir/modem_at.sh $at_port "AT+CREG=2;+CREG?;+CREG=0")
    OY2=$( sh $current_dir/modem_at.sh $at_port "AT+CEREG=2;+CEREG?;+CEREG=0")
    OY3=$( sh $current_dir/modem_at.sh $at_port "AT+C5GREG=2;+C5GREG?;+C5GREG=0")
    OY=$OY1" "$OY2" "$OY3


    OXx=$OX
    OX=$(echo $OX | tr 'a-z' 'A-Z')
    OY=$(echo $OY | tr 'a-z' 'A-Z')
    OX=$OX" "$OY

    #debug "$OX"
    #debug "$OY"

    COPS="-"
    COPS_MCC="-"
    COPS_MNC="-"
    COPSX=$(echo $OXx | grep -o "+COPS: [01],0,.\+," | cut -d, -f3 | grep -o "[^\"]\+")

    if [ "x$COPSX" != "x" ]; then
        COPS=$COPSX
    fi

    COPSX=$(echo $OX | grep -o "+COPS: [01],2,.\+," | cut -d, -f3 | grep -o "[^\"]\+")

    if [ "x$COPSX" != "x" ]; then
        COPS_MCC=${COPSX:0:3}
        COPS_MNC=${COPSX:3:3}
        if [ "$COPS" = "-" ]; then
            COPS=$(awk -F[\;] '/'$COPS'/ {print $2}' $ROOTER/signal/mccmnc.data)
            [ "x$COPS" = "x" ] && COPS="-"
        fi
    fi

    if [ "$COPS" = "-" ]; then
        COPS=$(echo "$O" | awk -F[\"] '/^\+COPS: 0,0/ {print $2}')
        if [ "x$COPS" = "x" ]; then
            COPS="-"
            COPS_MCC="-"
            COPS_MNC="-"
        fi
    fi
    COPS_MNC=" "$COPS_MNC

    OX=$(echo "${OX//[ \"]/}")
    CID=""
    CID5=""
    RAT=""
    REGV=$(echo "$OX" | grep -o "+C5GREG:2,[0-9],[A-F0-9]\{2,6\},[A-F0-9]\{5,10\},[0-9]\{1,2\}")
    if [ -n "$REGV" ]; then
        LAC5=$(echo "$REGV" | cut -d, -f3)
        LAC5=$LAC5" ($(printf "%d" 0x$LAC5))"
        CID5=$(echo "$REGV" | cut -d, -f4)
        CID5L=$(printf "%010X" 0x$CID5)
        RNC5=${CID5L:1:6}
        RNC5=$RNC5" ($(printf "%d" 0x$RNC5))"
        CID5=${CID5L:7:3}
        CID5="Short $(printf "%X" 0x$CID5) ($(printf "%d" 0x$CID5)), Long $(printf "%X" 0x$CID5L) ($(printf "%d" 0x$CID5L))"
        RAT=$(echo "$REGV" | cut -d, -f5)
    fi
    REGV=$(echo "$OX" | grep -o "+CEREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{5,8\}")
    REGFMT="3GPP"
    if [ -z "$REGV" ]; then
        REGV=$(echo "$OX" | grep -o "+CEREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{1,3\},[A-F0-9]\{5,8\}")
        REGFMT="SW"
    fi
    if [ -n "$REGV" ]; then
        LAC=$(echo "$REGV" | cut -d, -f3)
        LAC=$(printf "%04X" 0x$LAC)" ($(printf "%d" 0x$LAC))"
        if [ $REGFMT = "3GPP" ]; then
            CID=$(echo "$REGV" | cut -d, -f4)
        else
            CID=$(echo "$REGV" | cut -d, -f5)
        fi
        CIDL=$(printf "%08X" 0x$CID)
        RNC=${CIDL:1:5}
        RNC=$RNC" ($(printf "%d" 0x$RNC))"
        CID=${CIDL:6:2}
        CID="Short $(printf "%X" 0x$CID) ($(printf "%d" 0x$CID)), Long $(printf "%X" 0x$CIDL) ($(printf "%d" 0x$CIDL))"

    else
        REGV=$(echo "$OX" | grep -o "+CREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{2,8\}")
        if [ -n "$REGV" ]; then
            LAC=$(echo "$REGV" | cut -d, -f3)
            CID=$(echo "$REGV" | cut -d, -f4)
            if [ ${#CID} -gt 4 ]; then
                LAC=$(printf "%04X" 0x$LAC)" ($(printf "%d" 0x$LAC))"
                CIDL=$(printf "%08X" 0x$CID)
                RNC=${CIDL:1:3}
                CID=${CIDL:4:4}
                CID="Short $(printf "%X" 0x$CID) ($(printf "%d" 0x$CID)), Long $(printf "%X" 0x$CIDL) ($(printf "%d" 0x$CIDL))"
            else
                LAC=""
            fi
        else
            LAC=""
        fi
    fi
    REGSTAT=$(echo "$REGV" | cut -d, -f2)
    if [ "$REGSTAT" == "5" -a "$COPS" != "-" ]; then
        COPS_MNC=$COPS_MNC" (Roaming)"
    fi
    if [ -n "$CID" -a -n "$CID5" ] && [ "$RAT" == "13" -o "$RAT" == "10" ]; then
        LAC="4G $LAC, 5G $LAC5"
        CID="4G $CID<br />5G $CID5"
        RNC="4G $RNC, 5G $RNC5"
    elif [ -n "$CID5" ]; then
        LAC=$LAC5
        CID=$CID5
        RNC=$RNC5
    fi
    if [ -z "$LAC" ]; then
        LAC="-"
        CID="-"
        RNC="-"
    fi
}

#获取Fibocom模块信息
# $1:AT串口
get_fibocom_info()
{
    debug "get fibocom info"
    #设置AT串口
    at_port=$1

    #基本信息
    fibocom_base_info

	#SIM卡信息
    fibocom_sim_info
    if [ "$sim_status" != "ready" ]; then
        return
    fi

    #网络信息
    fibocom_network_info
    if [ "$connect_status" != "connect" ]; then
        return
    fi

    #小区信息
    fibocom_cell_info

    return

    # Fibocom_Cellinfo

    #基站信息
	OX=$( sh $current_dir/modem_at.sh $at_port "AT+CPSI?")
	rec=$(echo "$OX" | grep "+CPSI:")
	w=$(echo $rec |grep "NO SERVICE"| wc -l)
	if [ $w -ge 1 ];then
		debug "NO SERVICE"
		return
	fi
	w=$(echo $rec |grep "NR5G_"| wc -l)
	if [ $w -ge 1 ];then

		w=$(echo $rec |grep "32768"| wc -l)
		if [ $w -ge 1 ];then
			debug "-32768"
			return
		fi

		debug "$rec"
		rec1=${rec##*+CPSI:}
		#echo "$rec1"
		MODE="${rec1%%,*}" # MODE="NR5G"
		rect1=${rec1#*,}
		rect1s="${rect1%%,*}" #Online
		rect2=${rect1#*,}
		rect2s="${rect2%%,*}" #460-11
		rect3=${rect2#*,}
		rect3s="${rect3%%,*}" #0xCFA102
		rect4=${rect3#*,}
		rect4s="${rect4%%,*}" #55744245764
		rect5=${rect4#*,}
		rect5s="${rect5%%,*}" #196
		rect6=${rect5#*,}
		rect6s="${rect6%%,*}" #NR5G_BAND78
		rect7=${rect6#*,}
		rect7s="${rect7%%,*}" #627264
		rect8=${rect7#*,}
		rect8s="${rect8%%,*}" #-940
		rect9=${rect8#*,}
		rect9s="${rect9%%,*}" #-110
		# "${rec1##*,}" #最后一位
		rect10=${rect9#*,}
		rect10s="${rect10%%,*}" #最后一位
		PCI=$rect5s
		LBAND="n"$(echo $rect6s | cut -d, -f0 | grep -o "BAND[0-9]\{1,3\}" | grep -o "[0-9]\+")
		CHANNEL=$rect7s
		RSCP=$(($(echo $rect8s | cut -d, -f0) / 10))
		ECIO=$(($(echo $rect9s | cut -d, -f0) / 10))
		if [ "$CSQ_PER" = "-" ]; then
			CSQ_PER=$((100 - (($RSCP + 31) * 100/-125)))"%"
		fi
		SINR=$(($(echo $rect10s | cut -d, -f0) / 10))" dB"
	fi
	w=$(echo $rec |grep "LTE"|grep "EUTRAN"| wc -l)
	if [ $w -ge 1 ];then
		rec1=${rec#*EUTRAN-}
		lte_band=${rec1%%,*} #EUTRAN-BAND
		rec1=${rec1#*,}
		rec1=${rec1#*,}
		rec1=${rec1#*,}
		rec1=${rec1#*,}
		#rec1=${rec1#*,}
		rec1=${rec1#*,}
		lte_rssi=${rec1%%,*} #LTE_RSSI
		lte_rssi=`expr $lte_rssi / 10` #LTE_RSSI
		debug "LTE_BAND=$lte_band LTE_RSSI=$lte_rssi"
		if [ $rssi == 0 ];then
			rssi=$lte_rssi
		fi
	fi
	w=$(echo $rec |grep "WCDMA"| wc -l)
	if [ $w -ge 1 ];then
		w=$(echo $rec |grep "UNKNOWN"|wc -l)
		if [ $w -ge 1 ];then
			debug "UNKNOWN BAND"
			return
		fi
	fi

	#CNMP
	OX=$( sh $current_dir/modem_at.sh $at_port "AT+CNMP?")
	CNMP=$(echo "$OX" | grep -o "+CNMP:[ ]*[0-9]\{1,3\}" | grep -o "[0-9]\{1,3\}")
	if [ -n "$CNMP" ]; then
		case $CNMP in
		"2"|"55" )
			NETMODE="1" ;;
		"13" )
			NETMODE="3" ;;
		"14" )
			NETMODE="5" ;;
		"38" )
			NETMODE="7" ;;
		"71" )
			NETMODE="9" ;;
		"109" )
			NETMODE="8" ;;
		* )
			NETMODE="0" ;;
		esac
	fi
	
	# CMGRMI 信息
	OX=$( sh $current_dir/modem_at.sh $at_port "AT+CMGRMI=4")
	CAINFO=$(echo "$OX" | grep -o "$REGXz" | tr ' ' ':')
	if [ -n "$CAINFO" ]; then
		for CASV in $(echo "$CAINFO"); do
			LBAND=$LBAND"<br />B"$(echo "$CASV" | cut -d, -f4)
			BW=$(echo "$CASV" | cut -d, -f5)
			decode_bw
			LBAND=$LBAND" (CA, Bandwidth $BW MHz)"
			CHANNEL="$CHANNEL, "$(echo "$CASV" | cut -d, -f2)
			PCI="$PCI, "$(echo "$CASV" | cut -d, -f7)
		done
	fi
}