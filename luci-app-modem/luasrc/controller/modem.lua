-- Copyright 2020 Lienol <lawlienol@gmail.com>
module("luci.controller.modem", package.seeall)
local http = require "luci.http"
local fs = require "nixio.fs"
local json = require("luci.jsonc")
uci = luci.model.uci.cursor()
local script_path="/usr/share/modem/"

function index()
    if not nixio.fs.access("/etc/config/modem") then
        return
    end

	entry({"admin", "network", "modem"}, alias("admin", "network", "modem", "modem_info"), translate("Modem"), 100).dependent = true

	--模块状态
	entry({"admin", "network", "modem", "modem_info"}, template("modem/modem_info"), translate("Modem Information"),10).leaf = true
	entry({"admin", "network", "modem", "get_modem_info"}, call("getModemInfo"))

	--模块设置
	entry({"admin", "network", "modem", "index"},cbi("modem/index"),translate("Modem Config"),20).leaf = true
	entry({"admin", "network", "modem", "config"}, cbi("modem/config")).leaf = true
	entry({"admin", "network", "modem", "get_modems"}, call("getModems"), nil).leaf = true
	entry({"admin", "network", "modem", "status"}, call("act_status")).leaf = true

	--AT命令
	entry({"admin", "network", "modem", "at_commands"},template("modem/at_commands"),translate("AT Commands"),30).leaf = true
	entry({"admin", "network", "modem", "mode_info"}, call("modeInfo"), nil).leaf = true
	entry({"admin", "network", "modem", "send_at_command"}, call("sendATCommand"), nil).leaf = true
	entry({"admin", "network", "modem", "user_at_command"}, call("userATCommand"), nil).leaf = true
	entry({"admin", "network", "modem", "get_at_port"}, call("getATPort"), nil).leaf = true

	entry({"admin", "network", "modem", "at"},template("modem/at"),translate("AT"),40).leaf = true
end

-- 判断字符串是否含有字母
function hasLetters(str)
    local pattern = "%a" -- 匹配字母的正则表达式
    return string.find(str, pattern) ~= nil
end

-- AT命令
function at(at_port,at_command)
	-- local odpall = io.popen("sh modem_at.sh "..at_port.." '"..at_command.."'")
	local odpall = io.popen("sms_tool -d " .. at_port .. " at "  ..at_command:gsub("[$]", "\\\$"):gsub("\"", "\\\"").." 2>&1")
	local odp =  odpall:read("*a")
	odpall:close()
	return odp
end

-- 获取模组连接状态
function getModemConnectStatus(at_port,manufacturer)

	local connect_status="unknown"

	if at_port and manufacturer then
		local odpall = io.popen("cd "..script_path.." && source "..script_path..manufacturer..".sh && get_connect_status "..at_port)
		connect_status = odpall:read("*a")
		connect_status=string.gsub(connect_status, "\n", "")
		odpall:close()
	end

	return connect_status
end

-- 获取模组基本信息
function getModemDeviceInfo(at_port)
	local modem_device_info={}

	uci:foreach("modem", "modem-device", function (modem_device)
		if at_port == modem_device["at_port"] then
			--获取数据接口
			local data_interface=modem_device["data_interface"]:upper()
			--获取连接状态
			local connect_status=getModemConnectStatus(modem_device["at_port"],modem_device["manufacturer"])

			--设置值
			modem_device_info=modem_device
			modem_device_info["data_interface"]=data_interface
			modem_device_info["connect_status"]=connect_status
			return true
		end
	end)

	return modem_device_info
end

-- 获取模组更多信息
function getModemMoreInfo(at_port,manufacturer)

	--获取模组信息
	local odpall = io.popen("sh "..script_path.."modem_info.sh".." "..at_port.." "..manufacturer)
	local opd = odpall:read("*a")
	odpall:close()

	--设置值
	local modem_more_info=json.parse(opd)
	return modem_more_info
end

-- 模块状态获取
function getModemInfo()

	--获取AT串口
    local at_port = http.formvalue("port")

	--获取信息
	local modem_device_info
	local modem_more_info
	if at_port then
		modem_device_info=getModemDeviceInfo(at_port)
		modem_more_info=getModemMoreInfo(at_port,modem_device_info["manufacturer"])
	end

	--设置信息
	local modem_info={}
	modem_info["device_info"]=modem_device_info
	modem_info["more_info"]=modem_more_info

	--设置翻译
	local translation={}
	--SIM卡信息翻译
	if modem_more_info["sim_info"] then

		local sim_info=modem_more_info["sim_info"]
		for i = 1, #sim_info do
			local info = sim_info[i]
			for key in pairs(info) do
				translation[key]=luci.i18n.translate(key)
				local value=info[key]
				if hasLetters(value) then
					translation[value]=luci.i18n.translate(value)
				end
			end
		end
	end
	--网络信息翻译
	if modem_more_info["network_info"] then
		for key in pairs(modem_more_info["network_info"]) do
			translation[key]=luci.i18n.translate(key)
			local value=modem_more_info["network_info"][key]
			if hasLetters(value) then
				translation[value]=luci.i18n.translate(value)
			end
		end
	end
	--小区信息翻译
	if modem_more_info["cell_info"] then
		for key in pairs(modem_more_info["cell_info"]) do
			translation[key]=luci.i18n.translate(key)
			local network_mode=modem_more_info["cell_info"][key]
			for i = 1, #network_mode do
				local info = network_mode[i]
				for key in pairs(info) do
					translation[key]=luci.i18n.translate(key)
				end
			end
		end
	end

	--整合数据
	local data={}
	data["modem_info"]=modem_info
	data["translation"]=translation
	
	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

-- 获取模组信息
function getModems()
	
	-- 获取所有模组
	local modems={}
	local translation={}
	uci:foreach("modem", "modem-device", function (modem_device)
		-- 获取连接状态
		local connect_status=getModemConnectStatus(modem_device["at_port"],modem_device["manufacturer"])

		-- 获取翻译
		translation[connect_status]=luci.i18n.translate(connect_status)
		translation[modem_device["name"]]=luci.i18n.translate(modem_device["name"])
		translation[modem_device["mode"]]=luci.i18n.translate(modem_device["mode"])

		-- 设置值
		local modem=modem_device
		modem["connect_status"]=connect_status
		modems[modem_device[".name"]]=modem
	end)
	
	-- 设置值
	local data={}
	data["modems"]=modems
	data["translation"]=translation

	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

-- 模块列表状态函数
function act_status()
	local e = {}
	e.index = luci.http.formvalue("index")
	e.status = luci.sys.call(string.format("busybox ps -w | grep -v 'grep' | grep '/var/etc/socat/%s' >/dev/null", luci.http.formvalue("id"))) == 0
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

-- 模式信息
function modeInfo()
	-- 设置默认值
	local modes={"qmi","gobinet","ecm","mbim","rndis","ncm"}
	-- 获取移动网络
	local network = http.formvalue("network")

	local modem_number=uci:get('modem','global','modem_number')
	for i=0,modem_number-1 do
		local modem_network = uci:get('modem','modem'..i,'network')
		if network == modem_network then
			-- 清空表
			modes={}
			-- 把找到的模块存入表中
			local modes_arr = uci:get_list('modem','modem'..i,'modes')
			for i in ipairs(modes_arr) do
				modes[i]=modes_arr[i]
			end
		end
	end
	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(modes)
end

-- 发送AT命令
function sendATCommand()
    local at_port = http.formvalue("port")
	local at_command = http.formvalue("command")

	local response
    if at_port and at_command then
		response=at(at_port,at_command)
        http.write(tostring(response))
    else
        http.write_json(http.formvalue())
    end
end

-- 用户AT命令
function userATCommand()
	local at_commands={}
	-- 获取模块AT命令
	local command_file
	if nixio.fs.access("/etc/config/modem_command.user") then
		command_file=io.popen("cat /etc/config/modem_command.user")
	end
	if command_file then
		local i=0
		for line in command_file:lines() do
			if line then
				-- 分割为{key,value}
				local command_table=string.split(line, ";")
				-- 整合为{0:{key:value},1:{key:value}}
				local at_command={}
				at_command[command_table[1]]=command_table[2]
				at_commands[tostring(i)]=at_command
				i=i+1
			end
		end
		command_file:close()
	end
	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(at_commands)
end

-- 获取模组的备注
-- @Param network 移动网络
function getModemRemarks(network)
	local remarks=""
	uci:foreach("modem", "config", function (config)
		---配置启用，且备注存在
		if network == config["network"] and config["enable"] == "1" then
			if config["remarks"] then
				remarks=" ("..config["remarks"]..")" --" (备注)"
				return true --跳出循环
			end
		end
	end)
	return remarks
end

-- 获取AT串口
function getATPort()
	local at_ports={}
	uci:foreach("modem", "modem-device", function (modem_device)
		--获取模组的备注
		local network=modem_device["network"]
		local remarks=getModemRemarks(network)

		--设置模组AT串口
		if modem_device["name"] and modem_device["at_port"] then
			
			local name=modem_device["name"]:upper()..remarks
			if modem_device["name"] == "unknown" then
				-- name=modem_device["at_port"]..remarks
				name=modem_device["name"]..remarks
			end

			local at_port = modem_device["at_port"]
			at_ports[at_port]=name
		end
	end)
	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(at_ports)
end
