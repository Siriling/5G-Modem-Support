#!/bin/sh
current_dir="$(dirname "$0")"
source "$current_dir/quectel.sh"
source "$current_dir/fibocom.sh"
source "$current_dir/simcom.sh"

#调试开关
# 0关闭
# 1打开
# 2输出到文件
switch=0
out_file="/tmp/modem.log"	#输出文件
#日志信息
debug()
{
	time=$(date "+%Y-%m-%d %H:%M:%S")	#获取系统时间
	if [ $switch = 1 ]; then
		echo $time $1					#打印输出
	elif [ $switch = 2 ]; then
		echo $time $1 >> $outfile		#输出到文件
	fi
}

#发送at命令
# $1 AT串口
# $2 AT命令
at()
{
	local new_str="${2/[$]/$}"
	local atCommand="${new_str/\"/\"}"

	#echo
	# echo -e $2 > $1 2>&1

	#sms_tool
	sms_tool -d $1 at $atCommand 2>&1
}

#测试时打开
# debug $1
# at $1 $2

#获取快捷命令
# $1:快捷选项
# $2:制造商
get_quick_commands()
{
	local quick_commands
	case $1 in
		"auto") quick_commands=$(cat $current_dir/$2_at_commands.json) ;;
		"custom") quick_commands=$(cat /etc/modem/custom_at_commands.json) ;;
		*) quick_commands=$(cat $current_dir/$2_at_commands.json) ;;
	esac
	echo "$quick_commands"
}