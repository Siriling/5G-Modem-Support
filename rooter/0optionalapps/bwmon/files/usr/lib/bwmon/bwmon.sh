#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh

log() {
	modlog "wrtbwmon" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

networkFuncs=/lib/functions/network.sh
uci=`which uci 2>/dev/null`
nslookup=`which nslookup 2>/dev/null`
nvram=`which nvram 2>/dev/null`
binDir=/usr/sbin

setbackup() { 
	extn=$(uci -q get bwmon.general.external)
	if [ "$extn" = "0" ]; then
		backPath=/usr/lib/bwmon/bwdata/
	else
		if [ -e "$extn""/" ]; then
			backPath=$extn"/data/"
		else
			backPath=/usr/lib/bwmon/bwdata/
			uci set bwmon.general.external="0"
			uci commit bwmon
		fi
	fi
	if [ ! -e "$backpath" ]; then
		mkdir -p $backPath
	fi
}

detectIF()
{
    if [ -f "$networkFuncs" ]; then
	IF=`. $networkFuncs; network_get_device netdev $1; echo $netdev`
	[ -n "$IF" ] && echo $IF && return
    fi

    if [ -n "$uci" -a -x "$uci" ]; then
	IF=`$uci get network.${1}.$ifname 2>/dev/null`
	[ $? -eq 0 -a -n "$IF" ] && echo $IF && return
    fi

    if [ -n "$nvram" -a -x "$nvram" ]; then
	IF=`$nvram get ${1}_$ifname 2>/dev/null`
	[ $? -eq 0 -a -n "$IF" ] && echo $IF && return
    fi
}

detectWAN()
{
    [ -n "$WAN_IF" ] && echo $WAN_IF && return
    wan=$(detectIF wan)
    [ -n "$wan" ] && echo $wan && return
    wan=$(ip route show 2>/dev/null | grep default | sed -re '/^default/ s/default.*dev +([^ ]+).*/\1/')
    [ -n "$wan" ] && echo $wan && return
    [ -f "$networkFuncs" ] && wan=$(. $networkFuncs; network_find_wan wan; echo $wan)
    [ -n "$wan" ] && echo $wan && return
}

device_get_stats() {
	iface=$1
	st=$(ubus -v call network.interface.$iface status)
	json_init
	json_load "$st"
	json_get_var iface l3_device
	json_get_var status up
	if [ $status = "1" ]; then
		js="{ \"name\": \"$iface\" }"
		st=$(ubus -v call network.device status "$js")
		json_init
		json_load "$st"
		json_select statistics &>/dev/null
		json_get_var val $2
	else
		val="0"
	fi
	echo $val
}

update() {
	interfaces=""
	wan=$(detectWAN)
	C1=$(uci -q get modem.modem1.connected)
	C2=$(uci -q get modem.modem2.connected)
	if [ "$C1" = "1" ]; then
		interfaces="wan1"
	fi
	if [ "$C2" = "1" ]; then
		interfaces="interfaces wan2"
	fi
	WW=$(uci -q get bwmon.bwwan.wan)
	if [ "$WW" -eq 1 ]; then
		interfaces="$interfaces wan wwan2 wwan5"
	fi

	val="0"
	rxval="0"
	txval="0"
	for interface in $interfaces; do
		rval=$(device_get_stats $interface "rx_bytes")
		let rxval=$rxval+$rval
		tval=$(device_get_stats $interface "tx_bytes")
		let txval=$txval+$tval
	done
	
#log "Offset $offsetotal $offsetrx $offsettx"
	orxval=$rxval
	otxval=$txval
	let xval=$rxval+$txval
	otot=$xval
	let val=$val+$xval
#log "Update $val $rxval $txval"
	let rxval=$rxval-$offsetrx
	let txval=$txval-$offsettx
	let val=$val-$offsetotal
	rtxval=$val
	# backup daily values
	let ttotal=$basedailytotal+$val
	let trx=$basedailyrx+$rxval
	let ttx=$basedailytx+$txval
	echo "$ttotal" > $dataPath"daily.js"
	echo "$trx" >> $dataPath"daily.js"
	echo "$ttx" >> $dataPath"daily.js"
	cd=$cDay
	if [ $cd -lt 10 ]; then
		ct="0"$cd
	fi
	dt="$cYear-$cMonth-$cd"
	echo "$dt" >> $dataPath"daily.js"
	# backup monthly values
	let mtotal=$basemontotal+$val
	let mrx=$basemonrx+$rxval
	let mtx=$basemontx+$txval
	alloc=$(uci -q get custom.bwallocate.allocate)
	if [ -z "$alloc" ]; then
		alloc=1000000000
	else
		alloc=$alloc"000000000"
	fi
	/usr/lib/bwmon/excede.sh $mtotal $alloc
	if [ -e /usr/lib/bwmon/period.sh ]; then
		/usr/lib/bwmon/period.sh "$mtotal"
	fi
}

createAmt() 
{
	while [ true ]; do
		valid=$(cat /var/state/dnsmasqsec)
		st=$(echo "$valid" | grep "ntpd says time is valid")
		if [ ! -z "$st" ]; then
			break
		fi
		sleep 10
	done
	cYear=$(uci -q get bwmon.backup.year)
	if [ "$cYear" = '0' ]; then
		cYear=$(date +%Y)
		cDay=$(date +%d)
		cMonth=$(date +%m)
		uci set bwmon.backup.year=$cYear
		uci set bwmon.backup.month=$cMonth
		uci set bwmon.backup.day=$cDay
		uci commit bwmon
	else
		cYear=$(uci -q get bwmon.backup.year)
		cMonth=$(uci -q get bwmon.backup.month)
		cDay=$(uci -q get bwmon.backup.day)
	fi
	basedailytotal=$(uci -q get bwmon.backup.dailytotal)
	basedailyrx=$(uci -q get bwmon.backup.dailyrx)
	basedailytx=$(uci -q get bwmon.backup.dailytx)
	basemontotal=$(uci -q get bwmon.backup.montotal)
	basemonrx=$(uci -q get bwmon.backup.monrx)
	basemontx=$(uci -q get bwmon.backup.montx)
	if [ -z "$1" ]; then
		offsetotal='0'
		offsetrx='0'
		offsettx='0'
	else
		offsetotal=$otot
		offsetrx=$orxval
		offsettx=$otxval
	fi
}

checkTime() 
{
	pDay=$(date +%d)
	pYear=$(date +%Y)
	pMonth=$(date +%m)
#pDay=$(uci -q get bwmon.backup.tday)
	if [ "$cDay" -ne "$pDay" ]; then
#log "Day Changed"
		# save to periodic
		/usr/lib/bwmon/createdata.lua	
		bt=$(uci -q get custom.bwday)
		if [ -z "$bt" ]; then
			uci set custom.bwday='bwday'
		fi
		uci set custom.bwday.bwday=$(convert_bytes $mtotal)
		uci commit custom
		bwday=$(uci -q get modem.modeminfo1.bwday)
		if [ ! -z "$bwday" ]; then
			if [ $bwday = $pDay -a $bwday != "0" ]; then
				if [ -e /usr/lib/bwmon/sendsms ]; then
					/usr/lib/bwmon/sendsms.sh &
				fi
			fi
		fi
		# backup month
		offsetotal=$rtxval
		offsetrx=$rxval
		offsettx=$txval
#log "Offset $offsetotal $offsetrx $offsettx"
		uci set bwmon.backup.montotal=$mtotal
		uci set bwmon.backup.monrx=$mrx
		uci set bwmon.backup.montx=$mtx
		# clear daily
		basedailytotal='0'
		uci set bwmon.backup.dailytotal='0'
		basedailyrx='0'
		uci set bwmon.backup.dailyrx='0'
		basedailytx='0'
		uci set bwmon.backup.dailytx='0'
		# increase days
		days=$(uci -q get bwmon.backup.days)
		let days=$days+1
		uci set bwmon.backup.days=$days
		# day and date
		uci set bwmon.backup.year=$pYear
		uci set bwmon.backup.month=$pMonth
		uci set bwmon.backup.day=$pDay
		uci commit bwmon
		basemontotal=$(uci -q get bwmon.backup.montotal)
		basemonrx=$(uci -q get bwmon.backup.monrx)
		basemontx=$(uci -q get bwmon.backup.montx)
		cDay=$pDay
		cMonth=$pMonth
		cYear=$pYear
		roll=$(uci -q get custom.bwallocate.rollover)
		[ -z $roll ] && roll=1
		if [ "$roll" -eq "$pDay" ]; then
#log "Month Change"
			# clear monthly
			basemontotal='0'
			mtotal='0'
			uci set bwmon.backup.montotal='0'
			basemonrx='0'
			mrx='0'
			uci set bwmon.backup.monrx='0'
			basemontx='0'
			mtx='0'
			uci -q get bwmon.backup.montx='0'
			# reset days
			uci set bwmon.backup.days='1'
			uci commit bwmon
			uci set custom.texting.used='0'
			uci commit custom
			if [ -e /usr/lib/bwmon/periodreset.sh ]; then
				/usr/lib/bwmon/periodreset.sh
			fi
		fi
	fi
}
checkBackup() 
{
	CURRTIME=$(date +%s)
	let ELAPSE=CURRTIME-STARTIMEZ
	bs=$(uci -q get bwmon.general.backup)
#bs="1"
	let "bs=$bs*60"
	backup_time=$bs
	en=$(uci -q get bwmon.general.enabled)
	if [ "$en" = '1' ]; then
		if [ $ELAPSE -gt $backup_time ]; then
			STARTIMEZ=$CURRTIME
			# save monthly
			uci set bwmon.backup.montotal=$mtotal
			uci set bwmon.backup.monrx=$mrx
			uci set bwmon.backup.montx=$mtx
			# save daily
			uci set bwmon.backup.dailytotal=$ttotal
			uci set bwmon.backup.dailyrx=$trx
			uci set bwmon.backup.dailytx=$ttx
			# save day and date
			uci set bwmon.backup.year=$cYear
			uci set bwmon.backup.month=$cMonth
			uci set bwmon.backup.day=$cDay
			# total days
			uci commit bwmon
#log "Backup $mtotal $val"
		fi
	fi
}

convert_bytes() {
	local val=$1
	rm -f /tmp/bytes
	/usr/lib/bwmon/convertbytes.lua $val
	source /tmp/bytes
	echo "$BYTES"
}

createGUI()
{
	days=$(uci -q get bwmon.backup.days)
	echo "$days" > /tmp/bwdata
	tb=$(convert_bytes $mtotal)
	echo "$mtotal" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	tb=$(convert_bytes $mrx)
	echo "$mrx" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	tb=$(convert_bytes $mtx)
	echo "$mtx" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	let ptotal=$mtotal/$days
	let ptotal=$ptotal*30
	tb=$(convert_bytes $ptotal)
	echo "$ptotal" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	alloc=$(uci -q get custom.bwallocate.allocate)
	pass=$(uci -q get custom.bwallocate.password)
	if [ -z "$alloc" ]; then
		alloc=1000000000
		pass="password"
	else
		alloc=$alloc"000000000"
	fi
	tb=$(convert_bytes $alloc)
	echo "$alloc" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	echo "$pass" >> /tmp/bwdata
	echo "0" >> /tmp/bwdata
}

basePath="/tmp/bwmon/"
mkdir -p $basePath"bwdata"
dataPath=$basePath"bwdata/"
setbackup
STARTIMEX=$(date +%s)
STARTIMEY=$(date +%s)
STARTIMEZ=$(date +%s)
update_time=20

createAmt
while [ true ] ; do
	update
	if [ -e /tmp/bwchange ]; then
		newamt=$(cat /tmp/bwchange)
		rm -f /tmp/bwchange
		uci set bwmon.backup.dailytotal=$newamt
		uci set bwmon.backup.dailyrx=$newamt
		uci set bwmon.backup.dailytx=0
		uci set bwmon.backup.montotal=$newamt
		uci set bwmon.backup.monrx=$newamt
		uci set bwmon.backup.montx=0
		uci commit bwmon
		createAmt 1
		mtotal=0
		mrx=0
		mtx=0
		createGUI
	fi
	checkTime
	checkBackup
	createGUI
#log "$(convert_bytes $mtotal) $(convert_bytes $mrx) $(convert_bytes $mtx)     $(convert_bytes $val) $(convert_bytes $rxval) $(convert_bytes $txval)"
	sleep $update_time
done