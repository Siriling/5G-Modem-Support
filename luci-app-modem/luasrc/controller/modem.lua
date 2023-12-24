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
	entry({"admin", "network", "modem", "modem_info"}, template("modem/modem_info"), translate("Modem Info"),10).leaf = true
	entry({"admin", "network", "modem", "get_modem_info"}, call("getModemInfo"))

	--模块设置
	entry({"admin", "network", "modem", "index"},cbi("modem/index"),translate("Modem Config"),20).leaf = true
	entry({"admin", "network", "modem", "config"}, cbi("modem/config")).leaf = true
	entry({"admin", "network", "modem", "get_modems"}, call("getModems"), nil).leaf = true
	entry({"admin", "network", "modem", "status"}, call("act_status")).leaf = true

	--AT命令
	-- local modem_number=uci:get('modem','@global[0]','modem_number')
	-- if modem_number ~= "0" or modem_number == nil then
		entry({"admin", "network", "modem", "at_commands"},template("modem/at_commands"),translate("AT Commands"),30).leaf = true
	-- end
	entry({"admin", "network", "modem", "mode_info"}, call("modeInfo"), nil).leaf = true
	entry({"admin", "network", "modem", "send_at_command"}, call("sendATCommand"), nil).leaf = true
	entry({"admin", "network", "modem", "user_at_command"}, call("userATCommand"), nil).leaf = true
	entry({"admin", "network", "modem", "get_at_port"}, call("getATPort"), nil).leaf = true
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
function getModemConnectStatus(at_port)
	local at_command="AT+CGDCONT?"
	local response=at(at_port,at_command)

	-- 第六个引号的索引
	local sixth_index=1
	for i = 1, 5 do
		sixth_index=string.find(response,'"',sixth_index)+1
	end
	-- 第七个引号的索引
	local seven_index=string.find(response,'"',sixth_index+1)

	-- 获取IPv4和IPv6
	local ip=string.sub(response,sixth_index,seven_index-1)

	local not_ip="0.0.0.0,0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0"
	if string.find(ip,not_ip) then
        return "disconnect"
    else
        return "connect"
    end
end

-- 获取模组基本信息
function getModemBaseInfo(at_port)
	local modem_base_info={}

	uci:foreach("modem", "modem-device", function (modem_device)
		if at_port == modem_device["at_port"] then
			--获取数据接口
			local data_interface=modem_device["data_interface"]:upper()
			--获取连接状态
			local connect_status
			if modem_device["at_port"] then
				connect_status=getModemConnectStatus(modem_device["at_port"])
			end

			--设置值
			modem_base_info=modem_device
			modem_base_info["data_interface"]=data_interface
			modem_base_info["connect_status"]=connect_status
			return true
		end
	end)

	return modem_base_info
end

-- 获取模组更多信息
function getModemMoreInfo(at_port,manufacturer)
	local odpall = io.popen("sh "..script_path.."modem_info.sh".." "..at_port.." "..manufacturer)
	local opd = odpall:read("*a")
	odpall:close()
	local modem_more_info=json.parse(opd)
	return modem_more_info
end

-- 模块状态获取
function getModemInfo()

	--获取AT串口
    local at_port = http.formvalue("port")

	--获取值
	local modem_base_info
	local modem_more_info
	if at_port then
		modem_base_info=getModemBaseInfo(at_port)
		modem_more_info=getModemMoreInfo(at_port,modem_base_info["manufacturer"])
	end

	--设置值
	local modem_info={}
	modem_info["base_info"]=modem_base_info
	modem_info["more_info"]=modem_more_info

	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(modem_info)
end

-- 获取模组信息
function getModems()

	local modems={}

	-- 获取所有模组
	uci:foreach("modem", "modem-device", function (modem_device)
		--获取连接状态
		local connect_status
		if modem_device["at_port"] then
			connect_status=getModemConnectStatus(modem_device["at_port"])
		end

		--设置值
		local modem=modem_device
		modem["connect_status"]=connect_status
		modems[modem_device[".name"]]=modem
	end)

	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(modems)
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
		--获取模块的备注
		local network=modem_device["network"]
		local remarks=getModemRemarks(network)

		local name=modem_device["name"]:upper()..remarks
		local at_port = modem_device["at_port"]
		at_ports[at_port]=name
	end)
	-- 写入Web界面
	luci.http.prepare_content("application/json")
	luci.http.write_json(at_ports)
end
