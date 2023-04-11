#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "QMI Connect $CURRMODEM" "$@"
}

log "Starting QMI"

proto_qmi_init_config() {
	available=1
	no_device=1
	proto_config_add_string "device:device"
	proto_config_add_string apn
	proto_config_add_string auth
	proto_config_add_string username
	proto_config_add_string password
	proto_config_add_string pincode
	proto_config_add_int delay
	proto_config_add_string modes
	proto_config_add_string pdptype
	proto_config_add_int profile
	proto_config_add_boolean dhcp
	proto_config_add_boolean dhcpv6
	proto_config_add_boolean autoconnect
	proto_config_add_int plmn
	proto_config_add_int timeout
	proto_config_add_int mtu
	proto_config_add_defaults
}

proto_qmi_setup() {
	local interface="$1"
	local dataformat connstat plmn_mode mcc mnc
	local device apn auth username password pincode delay modes pdptype
	local profile dhcp dhcpv6 autoconnect plmn timeout mtu $PROTO_DEFAULT_OPTIONS
	local ip4table ip6table
	local cid_4 pdh_4 cid_6 pdh_6
	local ip_6 ip_prefix_length gateway_6 dns1_6 dns2_6
	
	if [ ! -f /tmp/bootend.file ]; then
		return 0
	fi

	CURRMODEM=$(uci -q get network.$interface.currmodem)
	uci set modem.modem$CURRMODEM.connected=0
	uci commit modem
	rm -f $ROOTER_LINK/reconnect$CURRMODEM
	jkillall getsignal$CURRMODEM
	rm -f $ROOTER_LINK/getsignal$CURRMODEM
	jkillall con_monitor$CURRMODEM
	rm -f $ROOTER_LINK/con_monitor$CURRMODEM
	jkillall mbim_monitor$CURRMODEM
	rm -f $ROOTER_LINK/mbim_monitor$CURRMODEM

	json_get_vars device apn auth username password pincode delay modes
	json_get_vars pdptype profile dhcp dhcpv6 autoconnect plmn ip4table
	json_get_vars ip6table timeout mtu $PROTO_DEFAULT_OPTIONS
	
	case $auth in
		"0" )
			auth=
		;;
		"1" )
			auth="pap"
		;;
		"2" )
			auth="chap"
		;;
		"*" )
			auth=
		;;
	esac

	[ "$timeout" = "" ] && timeout="10"

	[ "$metric" = "" ] && metric="0"

	[ -n "$ctl_device" ] && device=$ctl_device

	[ -n "$device" ] || {
		log "No control device specified"
		proto_notify_error "$interface" NO_DEVICE
		proto_set_available "$interface" 0
		return 1
	}

	[ -n "$delay" ] && sleep "$delay"

	device="$(readlink -f $device)"
	[ -c "$device" ] || {
		log "The specified control device does not exist"
		proto_notify_error "$interface" NO_DEVICE
		proto_set_available "$interface" 0
		return 1
	}

	devname="$(basename "$device")"
	devpath="$(readlink -f /sys/class/usbmisc/$devname/device/)"
	ifname="$( ls "$devpath"/net )"
	[ -n "$ifname" ] || {
		log "The interface could not be found."
		proto_notify_error "$interface" NO_IFACE
		proto_set_available "$interface" 0
		return 1
	}

	[ -n "$mtu" ] && {
		log "Setting MTU to $mtu"
		/sbin/ip link set dev $ifname mtu $mtu
	}

	timeout=1

	# Cleanup current state if any
	uqmi -s -d "$device" --stop-network 0xffffffff --autoconnect > /dev/null 2>&1

	# Go online
	uqmi -s -d "$device" --set-device-operating-mode online > /dev/null 2>&1

	# Set IP format
	uqmi -s -d "$device" --set-data-format 802.3 > /dev/null 2>&1
	uqmi -s -d "$device" --wda-set-data-format 802.3 > /dev/null 2>&1
	if [ $RAW -eq 1 ]; then
		dataformat='"raw-ip"'
	else
		if [ $idV = 1199 -a $idP = 9055 ]; then
			$ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "reset.gcom" "$CURRMODEM"
			dataformat='"802.3"'
			uqmi -s -d "$device" --set-data-format 802.3
			uqmi -s -d "$device" --wda-set-data-format 802.3
		else
			dataformat=$(uqmi -s -d "$device" --wda-get-data-format)
		fi
	fi
	log "WDA-GET-DATA-FORMAT is $dataformat"

	if [ "$dataformat" = '"raw-ip"' ]; then

		[ -f /sys/class/net/$ifname/qmi/raw_ip ] || {
			log "Device only supports raw-ip mode but is missing this required driver attribute: /sys/class/net/$ifname/qmi/raw_ip"
			return 1
		}

		log "Device does not support 802.3 mode. Informing driver of raw-ip only for $ifname .."
		echo "Y" > /sys/class/net/$ifname/qmi/raw_ip
	fi

	uqmi -s -d "$device" --sync > /dev/null 2>&1

	uqmi -s -d "$device" --network-register > /dev/null 2>&1

	log "Waiting for network registration"
	sleep 1
	local registration_timeout=0
	local registration_state=""
	while true; do
		registration_state=$(uqmi -s -d "$device" --get-serving-system 2>/dev/null | jsonfilter -e "@.registration" 2>/dev/null)
		log "Registration State : $registration_state"
		[ "$registration_state" = "registered" ] && break

		if [ "$registration_state" = "searching" ] || [ "$registration_state" = "not_registered" ]; then
			if [ "$registration_timeout" -lt "$timeout" ] || [ "$timeout" = "0" ]; then
				[ "$registration_state" = "searching" ] || {
					log "Device stopped network registration. Restart network registration"
					uqmi -s -d "$device" --network-register > /dev/null 2>&1
				}
				let registration_timeout++
				sleep 1
				continue
			fi
			log "Network registration failed, registration timeout reached"
		else
			# registration_state is 'registration_denied' or 'unknown' or ''
			log "Network registration failed (reason: '$registration_state')"
		fi

		proto_notify_error "$interface" NETWORK_REGISTRATION_FAILED
		proto_block_restart "$interface"
		return 1
	done

	[ -n "$modes" ] && uqmi -s -d "$device" --set-network-modes "$modes" > /dev/null 2>&1
	
	pdptype="ipv4v6"
	IPVAR=$(uci -q get modem.modem$CURRMODEM.pdptype)
	case "$IPVAR" in
		"IP" )
			pdptype="ipv4"
		;;
		"IPV6" )
			pdptype="ipv6"
		;;
		"IPV4V6" )
			pdptype="ipv4v6"
		;;
	esac
			
	pdptype=$(echo "$pdptype" | awk '{print tolower($0)}')
	[ "$pdptype" = "ip" -o "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] || pdptype="ip"
	if [ "$pdptype" = "ip" ]; then
		[ -z "$autoconnect" ] && autoconnect=1
		[ "$autoconnect" = 0 ] && autoconnect=""
	else
		[ "$autoconnect" = 1 ] || autoconnect=""
	fi
	
	isplist=$(uci -q get modem.modeminfo$CURRMODEM.isplist)
	apn2=$(uci -q get modem.modeminfo$CURRMODEM.apn2)
	for isp in $isplist 
		do
			NAPN=$(echo $isp | cut -d, -f2)
			NPASS=$(echo $isp | cut -d, -f4)
			CID=$(echo $isp | cut -d, -f5)
			NUSER=$(echo $isp | cut -d, -f6)
			NAUTH=$(echo $isp | cut -d, -f7)
			if [ "$NPASS" = "nil" ]; then
				NPASS="NIL"
			fi
			if [ "$NUSER" = "nil" ]; then
				NUSER="NIL"
			fi
			if [ "$NAUTH" = "nil" ]; then
				NAUTH="0"
			fi
			apn=$NAPN
			username="$NUSER"
			password="$NPASS"
			auth=$NAUTH
			case $auth in
				"0" )
					auth="none"
				;;
				"1" )
					auth="pap"
				;;
				"2" )
					auth="chap"
				;;
				"*" )
					auth="none"
				;;
			esac
			
			
			if [ ! -e /etc/config/isp ]; then
				log "Connect to network using $NAPN"
			else
				log "Connect to network"
			fi
			
			if [ ! -e /etc/config/isp ]; then
				log "Connection Parameters : $NAPN $auth $username $password"
			fi
			conn=0
			
			[ "$pdptype" = "ip" -o "$pdptype" = "ipv4v6" ] && {
				cid_4=$(uqmi -s -d "$device" --get-client-id wds)
				if ! [ "$cid_4" -eq "$cid_4" ] 2> /dev/null; then
					log "Unable to obtain client ID"
				fi
			}
			uqmi -s -d "$device" --set-client-id wds,"$cid_4" --set-ip-family ipv4 > /dev/null 2>&1
			v4s=0	
			pdh_4=$(uqmi -s -d "$device" --set-client-id wds,"$cid_4" \
				--start-network \
				${apn:+--apn $apn} \
				${auth:+--auth-type $auth} \
				${username:+--username $username} \
				${password:+--password $password} \
				${autoconnect:+--autoconnect})
			log "IPv4 Connection returned : $pdh_4"
			CONN4=$(uqmi -s -d "$device" --set-client-id wds,"$cid_4" --get-current-settings)
			log "GET-CURRENT-SETTINGS is $CONN4"
			# pdh_4 is a numeric value on success
			if ! [ "$pdh_4" -eq "$pdh_4" ] 2> /dev/null; then
				log "Unable to connect IPv4"
				v4s=0
			else
				# Check data connection state
				v4s=1
				conn=1
			fi

			[ "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] && {
				cid_6=$(uqmi -s -d "$device" --get-client-id wds)
				if ! [ "$cid_6" -eq "$cid_6" ] 2> /dev/null; then
					log "Unable to obtain client ID"
					#proto_notify_error "$interface" NO_CID
				fi
			}

			uqmi -s -d "$device" --set-client-id wds,"$cid_6" --set-ip-family ipv6 > /dev/null 2>&1
			v6s=0
			pdh_6=$(uqmi -s -d "$device" --set-client-id wds,"$cid_6" \
				--start-network \
				${apn:+--apn $apn} \
				${auth:+--auth-type $auth} \
				${username:+--username $username} \
				${password:+--password $password} \
				${autoconnect:+--autoconnect})
			log "IPv6 Connection returned : $pdh_6"

			# pdh_6 is a numeric value on success
			if ! [ "$pdh_6" -eq "$pdh_6" ] 2> /dev/null; then
				log "Unable to connect IPv6"
				v6s=0
			else
				# Check data connection state
				CONN6=$(uqmi -s -d "$device" --set-client-id wds,"$cid_6" --get-current-settings)
				log "GET-CURRENT-SETTINGS is $CONN6"
				v6s=1
				conn=1
			fi
			if [ $conn -eq 1 ]; then
				break;
			fi
		done

	if [ $conn -eq 0 ]; then
		proto_notify_error "$interface" CALL_FAILED
		return 1
	else
		log "Setting up $ifname"
		proto_init_update "$ifname" 1
		proto_set_keep 1
		proto_add_data
		[ -n "$pdh_4" ] && {
			json_add_string "cid_4" "$cid_4"
			json_add_string "pdh_4" "$pdh_4"
		}
		[ -n "$pdh_6" ] && {
			json_add_string "cid_6" "$cid_6"
			json_add_string "pdh_6" "$pdh_6"
		}
		proto_close_data
		proto_send_update "$interface"

		zone="$(fw3 -q network "$interface" 2>/dev/null)"
		dhcp=0
		dhcpv6=0

		[ "$v6s" -eq 1 ] && {
			if [ -z "$dhcpv6" -o "$dhcpv6" = 0 ]; then
				json_load "$(uqmi -s -d $device --set-client-id wds,$cid_6 --get-current-settings)"
				json_select ipv6
				json_get_var ip_6 ip
				json_get_var gateway_6 gateway
				json_get_var dns1_6 dns1
				json_get_var dns2_6 dns2
				json_get_var ip_prefix_length ip-prefix-length

				proto_init_update "$ifname" 1
				proto_set_keep 1
				proto_add_ipv6_address "$ip_6" "128"
				proto_add_ipv6_prefix "${ip_6}/${ip_prefix_length}"
				proto_add_ipv6_route "$gateway_6" "128"
				[ "$defaultroute" = 0 ] || proto_add_ipv6_route "::0" 0 "$gateway_6" "" "" "${ip_6}/${ip_prefix_length}"
				[ "$peerdns" = 0 ] || {
					proto_add_dns_server "$dns1_6"
					proto_add_dns_server "$dns2_6"
				}
				[ -n "$zone" ] && {
					proto_add_data
					json_add_string zone "$zone"
					proto_close_data
				}
				proto_send_update "$interface"
				v6dns="$dns1_6 $dns2_6"
				log "IPv6 address : $ip_6"
				log "IPv6 DNS : $v6dns"
			else
				json_init
				json_add_string name "${interface}_6"
				json_add_string ifname "@$interface"
				json_add_string proto "dhcpv6"
				[ -n "$ip6table" ] && json_add_string ip6table "$ip6table"
				proto_add_dynamic_defaults
				# RFC 7278: Extend an IPv6 /64 Prefix to LAN
				json_add_string extendprefix 1
				[ -n "$zone" ] && json_add_string zone "$zone"
				json_close_object
				ubus call network add_dynamic "$(json_dump)"
			fi
		}

		[ "$v4s" -eq 1 ] && {
			if [ "$dhcp" = 0 ]; then
				json_load "$(uqmi -s -d $device --set-client-id wds,$cid_4 --get-current-settings)"
				json_select ipv4
				json_get_var ip_4 ip
				json_get_var gateway_4 gateway
				json_get_var dns1_4 dns1
				json_get_var dns2_4 dns2
				json_get_var subnet_4 subnet

				proto_init_update "$ifname" 1
				proto_set_keep 1
				proto_add_ipv4_address "$ip_4" "$subnet_4"
				proto_add_ipv4_route "$gateway_4" "128"
				[ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$gateway_4"
				[ "$peerdns" = 0 ] || {
					proto_add_dns_server "$dns1_4"
					proto_add_dns_server "$dns2_4"
				}
				[ -n "$zone" ] && {
					proto_add_data
					json_add_string zone "$zone"
					proto_close_data
				}
				proto_send_update "$interface"
				log "IPv4 address : $ip_4"
				log "IPv4 DNS : $dns1_4 $dns2_4"
			else
				json_init
				json_add_string name "${interface}_4"
				json_add_string ifname "@$interface"
				json_add_string proto "dhcp"
				[ -n "$ip4table" ] && json_add_string ip4table "$ip4table"
				proto_add_dynamic_defaults
				[ -n "$zone" ] && json_add_string zone "$zone"
				json_close_object
				ubus call network add_dynamic "$(json_dump)"
			fi
		}

		if [ -n "$ip_6" -a -z "$ip_4" ]; then
			log "Running IPv6-only mode"
			nat46=1
		fi
		if [[ $(echo "$ip_6" | grep -o "^[23]") ]]; then
			# Global unicast IP acquired
			v6cap=1
		elif
			[[ $(echo "$ip_6" | grep -o "^[0-9a-fA-F]\{1,4\}:") ]]; then
			# non-routable address
			v6cap=2
		else
			v6cap=0
		fi
		if [ $v4s -eq 0 -a $v6s -eq 1 ]; then
			INTER=$(uci get modem.modem$CURRMODEM.inter)
			if [ "$v6cap" -gt 0 ]; then
				zone="$(fw3 -q network "$interface" 2>/dev/null)"
			fi
			if [ "$v6cap" = 2 ]; then
				log "Adding IPv6 dynamic interface"
				json_init
				json_add_string name "${interface}_6"
				json_add_string ${ifname1} "@$interface"
				json_add_string proto "dhcpv6"
				json_add_string extendprefix 1
				[ -n "$zone" ] && json_add_string zone "$zone"
				[ "$nat46" = 1 ] || json_add_string iface_464xlat 0
				json_add_boolean peerdns 0
				json_add_array dns
					for DNSV in $(echo "$v6dns"); do
						json_add_string "" "$DNSV"
					done
				json_close_array
				proto_add_dynamic_defaults
				json_close_object
				ubus call network add_dynamic "$(json_dump)"
			elif
				[ "$v6cap" = 1 -a "$nat46" = 1 ]; then
				log "Adding 464XLAT (CLAT) dynamic interface"
				json_init
				json_add_string name "CLAT$INTER"
				json_add_string proto "464xlat"
				json_add_string tunlink "${interface}"
				[ -n "$zone" ] && json_add_string zone "$zone"
				proto_add_dynamic_defaults
				json_close_object
				ubus call network add_dynamic "$(json_dump)"
			fi
		fi
		if [ -e $ROOTER/modem-led.sh ]; then
			$ROOTER/modem-led.sh $CURRMODEM 3
		fi

		log "Modem $CURRMODEM Connected"
		COMMPORT=$(uci get modem.modem$CURRMODEM.commport)
		if [ ! -z $COMMPORT ]; then
			$ROOTER/sms/check_sms.sh $CURRMODEM &
			ln -s $ROOTER/signal/modemsignal.sh $ROOTER_LINK/getsignal$CURRMODEM
			# send custom AT startup command
			if [ $(uci -q get modem.modeminfo$CURRMODEM.at) -eq "1" ]; then
				ATCMDD=$(uci -q get modem.modeminfo$CURRMODEM.atc)
				if [ ! -z "${ATCMDD}" ]; then
					OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$COMMPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
					OX=$($ROOTER/common/processat.sh "$OX")
					ERROR="ERROR"
					if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
					then
						log "Error sending custom AT command: $ATCMDD with result: $OX"
					else
						log "Sent custom AT command: $ATCMDD with result: $OX"
					fi
				fi
			fi
		fi
		ln -s $ROOTER/connect/reconnect.sh $ROOTER_LINK/reconnect$CURRMODEM
		$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
		ln -s $ROOTER/connect/conmon.sh $ROOTER_LINK/con_monitor$CURRMODEM
		$ROOTER_LINK/con_monitor$CURRMODEM $CURRMODEM &
		uci set modem.modem$CURRMODEM.connected=1
		uci commit modem
		
		if [ -e $ROOTER/connect/postconnect.sh ]; then
			$ROOTER/connect/postconnect.sh $CURRMODEM
		fi
		
		if [ -e $ROOTER/timezone.sh ]; then
			TZ=$(uci -q get modem.modeminfo$CURRMODEM.tzone)
			if [ "$TZ" = "1" ]; then
				$ROOTER/timezone.sh &
			fi
		fi
		CLB=1
		if [ -e /etc/config/mwan3 ]; then
			INTER=$(uci get modem.modeminfo$CURRMODEM.inter)
			if [ -z $INTER ]; then
				INTER=0
			else
				if [ $INTER = 0 ]; then
					INTER=$CURRMODEM
				fi
			fi
			ENB=$(uci -q get mwan3.wan$CURRMODEM.enabled)
			if [ ! -z $ENB ]; then
				if [ $CLB = "1" ]; then
					uci set mwan3.wan$INTER.enabled=1
				else
					uci set mwan3.wan$INTER.enabled=0
				fi
				uci commit mwan3
				/usr/sbin/mwan3 restart
			fi
		fi
		rm -f /tmp/usbwait

		return 0
	fi
}

qmi_wds_stop() {
	local cid="$1"
	local pdh="$2"

	[ -n "$cid" ] || return

	uqmi -s -d "$device" --set-client-id wds,"$cid" \
		--stop-network 0xffffffff \
		--autoconnect > /dev/null 2>&1

	[ -n "$pdh" ] && {
		uqmi -s -d "$device" --set-client-id wds,"$cid" \
			--stop-network "$pdh" > /dev/null 2>&1
	}

	uqmi -s -d "$device" --set-client-id wds,"$cid" \
		--release-client-id wds > /dev/null 2>&1
}

proto_qmi_teardown() {
	local interface="$1"

	local device cid_4 pdh_4 cid_6 pdh_6
	json_get_vars device

	[ -n "$ctl_device" ] && device=$ctl_device

	log "Stopping network $interface"

	json_load "$(ubus call network.interface.$interface status)"
	json_select data
	json_get_vars cid_4 pdh_4 cid_6 pdh_6

	qmi_wds_stop "$cid_4" "$pdh_4"
	qmi_wds_stop "$cid_6" "$pdh_6"

	proto_init_update "*" 0
	proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol qmi
}
