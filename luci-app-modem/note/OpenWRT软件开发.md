# OpenWRT软件开发

# 一、相关文档

UCI系统：https://openwrt.org/docs/guide-user/base-system/uci

OpenWRT命令解释器：https://openwrt.org/zh/docs/guide-user/base-system/user.beginner.cli

热插拔：https://openwrt.org/zh/docs/guide-user/base-system/hotplug

网络基础配置：https://openwrt.org/zh/docs/guide-user/base-system/basic-networking

Web界面相关

- 自定义主题：https://github.com/openwrt/luci/wiki/HowTo:-Create-Themes
- 模块参考：https://github.com/openwrt/luci/wiki/Modules
- 模板参考：https://github.com/openwrt/luci/wiki/Templates
- 实例参考：https://blog.csdn.net/byb123/article/details/77921486/

# 二、网络配置

在任何网络配置更改(通过uci或其他方式)之后，你需要输入以下内容来重载网络配置：

```shell
service network reload
```

如果您安装的版本没有提供`service`命令，则可以使用：

```shell
/etc/init.d/network reload
```

# 三、拨号程序

拨号步骤

```shell
run_dial()
{
	local enabled
	config_get_bool enabled $1 enabled

	if [ "$enabled" = "1" ]; then
		local apn
		local user
		local password
		local auth
		local ipv6
		local device

		#获取配置
		config_get apn $1 apn
		config_get user $1 user
		config_get password $1 password
		config_get auth $1 auth
		config_get ipv6 $1 ipv6
		config_get device $1 device

		devname="$(basename "$device")" #获取调制解调器，/dev/cdc-wdm0->cdc-wdm0
		devicepath="$(find /sys/class/ -name $devname)" #找到设备快捷路径，/sys/class/net/cdc-wdm0
		devpath="$(readlink -f $devicepath/device/)" #找出连接的物理设备路径，/sys/devices/.../
		ifname="$( ls "$devpath"/net )" #获取设备名，/sys/devices/.../net->cdc-wdm0

		procd_open_instance #打开一个示例？
		procd_set_param command quectel-CM #设置参数？
		if [ "$ipv6" = 1 ]; then
			procd_append_param command -4 -6
		fi
		if [ "$apn" != "" ];then
			procd_append_param command -s $apn
		fi
		if [ "$user" != "" ]; then
			procd_append_param command $user
		fi
		if [ "$password" != "" ]; then
			procd_append_param command $password
		fi
		if [ "$auth" != "" ]; then
			procd_append_param command $auth
		fi
		if [ "$device" != "" ]; then
			procd_append_param command -i $ifname
		fi
		procd_set_param respawn
		procd_close_instance

		if [ -d /sys/class/net/rmnet_mhi0 ]; then
			pre_set rmnet_mhi0.1
		elif [ -d /sys/class/net/wwan0_1 ]; then
			pre_set wwan0_1
		elif [ -d /sys/class/net/wwan0.1 ]; then
			pre_set wwan0.1
		elif [ -d /sys/class/net/wwan0 ]; then
			pre_set wwan0
		fi
	fi

	sleep 15
}
```

# 四、shell

获取设备物理路径

device_bus_path.sh

```shell
#!/bin/sh

#获取物理设备地址
local device_name="$(basename "$1")"
local device_path="$(find /sys/class/ -name $device_name)"
local device_physical_path="$(readlink -f $device_path/device/)"
local device_bus_path=$(dirname "$device_physical_path")
return $device_bus_path
```

设置配置

setConfig.sh

```shell
#!/bin/sh

#处理获取到的路径
substr="${parentDir/\/sys\/devices\//}"
echo $substr

#写入到配置中
uci set modem.modem1.path="$substr"
uci commit modem2
```

