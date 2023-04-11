#!/bin/sh

while [ true ]
do
	curl https://api64.ipify.org?format=json > /tmp/xpip
	mv /tmp/xpip /tmp/ipip
	sleep 10
done