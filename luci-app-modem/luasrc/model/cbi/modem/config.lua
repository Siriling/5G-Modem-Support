local d = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

m = Map("modem", translate("Modem Config"))
m.redirect = d.build_url("admin", "network", "modem")

s = m:section(NamedSection, arg[1], "config", "")
s.addremove = false
s.dynamic = false
s:tab("general", translate("General Settings"))
s:tab("advanced", translate("Advanced Settings"))

--------general--------

-- 是否启用
enable = s:taboption("general", Flag, "enable", translate("Enable"))
enable.default = "0"
enable.rmempty = false

-- 备注
remarks = s:taboption("general", Value, "remarks", translate("Remarks"))
remarks.rmempty = true

-- 移动网络
-- moblie_net = s:taboption("general", Value, "moblie_net", translate("Moblie Network"))
moblie_net = s:taboption("general", ListValue, "moblie_net", translate("Moblie Network"))
-- moblie_net.default = ""
moblie_net.rmempty = false

-- 拨号模式
-- mode = s:taboption("general", ListValue, "mode", translate("Mode"))
-- mode.rmempty = false

-- 根据调制解调器节点获取模块名
-- function getDeviceName(device_node)
-- 	local deviceName
-- 	uci:foreach("modem", "modem-device", function (modem_device)
-- 		if device_node == modem_device["device_node"] then
-- 			deviceName = modem_device["name"]
-- 		end
-- 	end)
-- 	return string.upper(deviceName)
-- end

-- 显示设备通用信息（网络，拨号模式）（有bug）
function devicesGeneralInfo()
	local modem_number=uci:get('modem','global','modem_number')
	for i=0,modem_number do
		--获取模块名
		local deviceName = uci:get('modem','modem'..i,'name')
		if deviceName == nil then
			deviceName = "unknown"
		end
		--设置网络
		local net = uci:get('modem','modem'..i,'net')
		if net ~= nil then
			moblie_net:value(net,net.." ("..translate(deviceName:upper())..")")

			--设置拨号模式
			local mode = s:taboption("general", ListValue, "mode", translate("Mode"))
			mode.rmempty = false

			local modes = uci:get_list('modem','modem'..tostring(i),'modes')
			for i in ipairs(modes) do
				mode:value(modes[i],string.upper(modes[i]))
			end
			mode:depends("moblie_net", net)
		end
	end
end

devicesGeneralInfo()

--------advanced--------

-- 拨号工具
dial_tool = s:taboption("advanced", Value, "dial_tool", translate("Dial Tool"))
dial_tool.rmempty = true
dial_tool:value("", translate("Auto Choose"))
dial_tool:value("quectel-CM", translate("quectel-CM"))

-- 网络类型
pdp_type= s:taboption("advanced", ListValue, "pdp_type", translate("PDP Type"))
pdp_type.default = "ipv4_ipv6"
pdp_type.rmempty = false
pdp_type:value("ipv4", translate("IPv4"))
pdp_type:value("ipv6", translate("IPv6"))
pdp_type:value("ipv4_ipv6", translate("IPv4/IPv6"))

-- 接入点
apn = s:taboption("advanced", Value, "apn", translate("APN"))
apn.default = ""
apn.rmempty = true
apn:value("", translate("Auto Choose"))
apn:value("cmnet", translate("China Mobile"))
apn:value("3gnet", translate("China Unicom"))
apn:value("ctnet", translate("China Telecom"))
apn:value("cbnet", translate("China Broadcast"))
apn:value("5gscuiot", translate("Skytone"))

username = s:taboption("advanced", Value, "username", translate("PAP/CHAP Username"))
username.rmempty = true

password = s:taboption("advanced", Value, "password", translate("PAP/CHAP Password"))
password.rmempty = true

auth = s:taboption("advanced", Value, "auth", translate("Authentication Type"))
auth.default = ""
auth.rmempty = true
auth:value("", translate("NONE"))
auth:value("both", "PAP/CHAP (both)")
auth:value("pap", "PAP")
auth:value("chap", "CHAP")
-- auth:value("none", "NONE")

return m
