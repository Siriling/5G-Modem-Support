local d = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local http = require "luci.http"

m = Map("modem", translate("Modem Config"))
m.redirect = d.build_url("admin", "network", "modem","index")

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

-- 配置ID
uci:set('modem',arg[1],'id',arg[1])

-- 备注
remarks = s:taboption("general", Value, "remarks", translate("Remarks"))
remarks.rmempty = true

-- 移动网络
-- network = s:taboption("general", Value, "network", translate("Mobile Network"))
network = s:taboption("general", ListValue, "network", translate("Mobile Network"))
-- network.default = ""
network.rmempty = false

-- 获取移动网络，并显示设备名
function getMobileNetwork()
	local modem_number=uci:get('modem','global','modem_number')
	if modem_number == "0" then
		network:value("",translate("Mobile network not found"))
	end

	for i=0,modem_number-1 do
		--获取模块名
		local modem_name = uci:get('modem','modem'..i,'name')
		if modem_name == nil then
			modem_name = "unknown"
		end
		--设置网络
		modem_network = uci:get('modem','modem'..i,'network')
		if modem_network ~= nil then
			network:value(modem_network,modem_network.." ("..translate(modem_name:upper())..")")
		end
	end
end

getMobileNetwork()

-- 拨号模式
-- mode = s:taboption("general", ListValue, "mode", translate("Mode"))
-- mode.rmempty = false
-- mode.description = translate("Only display the modes available for the adaptation modem")
-- local modes = {"qmi","gobinet","ecm","mbim","rndis","ncm"}
-- for i in ipairs(modes) do
-- 	mode:value(modes[i],string.upper(modes[i]))
-- end

-- 添加获取拨号模式信息
-- m:append(Template("modem/mode_info"))

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
