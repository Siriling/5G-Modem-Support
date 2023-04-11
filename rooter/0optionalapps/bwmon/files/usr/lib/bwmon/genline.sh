#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh

genline() {
	MONLIST=$MONLIST"<tr>"
		t1="<td width=\"160px\"><div align=\"center\"><strong> $START</strong></div></td>"
		t2="<td width=\"200px\"><div align=\"center\"><strong> $updata</strong></div></td>"
		t3="<td width=\"150px\"><div align=\"center\"><strong> $downdata</strong></div></td>"
		t4="<td width=\"150px\"><div align=\"center\"><strong> $totaldata</strong></div></td>"
		t5="<td width=\"340\" ></td>"
	MONLIST=$MONLIST$t1$t2$t3$t4$t5"</tr>"
}

bwdata() {
	START="-"
	END="-"
	header=0
	while IFS= read -r line; do
		if [ $header -eq 0 ]; then
			days=$line
			read -r line
			DOWN=$line
			read -r line
			UP=$line
			read -r line
			TOTAL=$line
			read -r line
			line=$(echo $line" " | tr "|" ",")
			END=$(echo $line | cut -d, -f1)
			START=$END
			updata=$(echo $line | cut -d, -f2)
			downdata=$(echo $line | cut -d, -f3)
			totaldata=$(echo $line | cut -d, -f4)
			genline
			read -r line
			header=1
			if [ -z "$line" ]; then
				break
			fi
		fi
		line=$(echo $line" " | tr "|" ",")
		START=$(echo $line | cut -d, -f1)
		updata=$(echo $line | cut -d, -f2)
		downdata=$(echo $line | cut -d, -f3)
		totaldata=$(echo $line | cut -d, -f4)
		genline

	done < /usr/lib/bwmon/data/monthly.data
}

	MONLIST=""
	rm -f /tmp/monlist
	rm -f /tmp/montot
	if [ -e /usr/lib/bwmon/data/monthly.data ]; then
		bwdata
		echo $MONLIST > /tmp/monlist
		echo $days > /tmp/montot
		echo $DOWN >> /tmp/montot
		echo $UP >> /tmp/montot
		echo $TOTAL >> /tmp/montot
		
	fi
	