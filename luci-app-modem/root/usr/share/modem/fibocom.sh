#!/bin/sh
current_dir="$(dirname "$0")"

#获取拨号模式
# $1:AT串口
get_fibocom_mode()
{
    local at_port="$1"
    local at_command="AT+GTUSBMODE?"
    local mode_num=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/+GTUSBMODE: //g' | sed 's/\r//g')
    
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
        "*") mode="$mode_num" ;;
    esac
    echo "$mode"
}


#基本信息
fibocom_base_info()
{
    debug "Fibocom base info"

    local at_command="ATI"
    local response=$(sh $current_dir/modem_at.sh $at_port $at_command)

    #名称
    name=$(echo "$response" | sed -n '3p' | sed 's/Model: //g' | sed 's/\r//g')
    #制造商
    manufacturer=$(echo "$response" | sed -n '2p' | sed 's/Manufacturer: //g' | sed 's/\r//g')
    #固件版本
    revision=$(echo "$response" | sed -n '4p' | sed 's/Revision: //g' | sed 's/\r//g')

    #拨号模式
    mode=$(get_fibocom_mode $at_port | tr 'a-z' 'A-Z')

    #温度
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
    
    #ISP（互联网服务提供商）
    local at_command="AT+COPS?"
    isp=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'"' '{print $2}')
    if [ "$isp" = "CHN-CMCC" ] || [ "$isp" = "CMCC" ]|| [ "$isp" = "46000" ]; then
        isp="中国移动"
    elif [ "$isp" = "CHN-UNICOM" ] || [ "$isp" = "UNICOM" ] || [ "$isp" = "46001" ]; then
        isp="中国联通"
    elif [ "$isp" = "CHN-CT" ] || [ "$isp" = "CT" ] || [ "$isp" = "46011" ]; then
        isp="中国电信"
    fi

    #IMEI
    at_command="AT+CGSN"
	imei=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/\r//g')

	#IMSI
    at_command="AT+CIMI"
	imsi=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/\r//g')

	#ICCID
    at_command="AT+ICCID"
	iccid=$(sh $current_dir/modem_at.sh $at_port $at_command | grep -o "+ICCID:[ ]*[-0-9]\+" | grep -o "[-0-9]\{1,4\}")
	
    #SIM卡号码（手机号）
    at_command="AT+CNUM?"
	phone=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'"' '{print $2}')
}

#网络信息
fibocom_net_info()
{
    debug "Fibocom net info"

    #Network Type（网络类型）
    local at_command="AT+PSRAT?"
    net_type=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | sed 's/+PSRAT: //g' | sed 's/\r//g')

    #CSQ
    local at_command="AT+CSQ"
    csq=$(sh $current_dir/modem_at.sh $at_port $at_command | sed -n '2p' | awk -F'[ ,]+' '{print $2}')
    if [ $CSQ = "99" ]; then
        csq=""
    fi

    #PER（信号强度）
    if [ -n "$csq" ]; then
        per=$(($csq * 100/31))"%"
    fi

    #RSSI（信号接收强度）
    if [ -n "$csq" ]; then
        rssi=$((2 * $csq - 113))" dBm"
    fi
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
    #网络信息
    fibocom_net_info

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