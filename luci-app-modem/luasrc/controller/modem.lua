-- Copyright 2020 Lienol <lawlienol@gmail.com>
module("luci.controller.modem", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/modem") then
        return
    end
    entry({"admin", "network", "modem"}, alias("admin", "network", "modem", "index"), translate("Modem"), 100).dependent = true
	entry({"admin", "network", "modem", "index"},cbi("modem/index"),translate("Modem Config"),10).leaf = true
	entry({"admin", "network", "modem", "at_commands"},template("modem/at_commands"),translate("AT Commands"),20).leaf = true
	entry({"admin", "network", "modem", "config"}, cbi("modem/config")).leaf = true
	entry({"admin", "network", "modem", "modem_info"}, template("modem/modem_info"), translate("Modem Info"),30).leaf = true
	
	--模块状态
	entry({"admin", "network", "modem", "get_csq"}, call("action_get_csq"))

	--AT命令
	entry({"admin", "network", "modem", "status"}, call("act_status")).leaf = true
	entry({"admin", "network", "modem", "run_at"}, call("at"), nil).leaf = true
	entry({"admin", "network", "modem", "user_atc"}, call("useratc"), nil).leaf = true
	entry({"admin", "network", "modem", "at_port_select"}, call("modemSelect"), nil).leaf = true
end

-- 模块列表状态函数
function act_status()
	local e = {}
	e.index = luci.http.formvalue("index")
	e.status = luci.sys.call(string.format("busybox ps -w | grep -v 'grep' | grep '/var/etc/socat/%s' >/dev/null", luci.http.formvalue("id"))) == 0
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

-- 模块状态获取
function action_get_csq()
	local file
	stat = "/tmp/modem_cell.file"
	file = io.open(stat, "r")
	local rv ={}

	-- echo 'RM520N-GL'
	-- echo 'manufacturer'
	-- echo '1e0e:9001'
	-- echo $COPS #运营商
	-- echo '' #端口
	-- echo '' #温度
	-- echo '' #拨号模式
    rv["modem"] = file:read("*line")
	rv["manufacturer"] = file:read("*line")
	rv["modid"] = file:read("*line")
	rv["cops"] = file:read("*line")
	rv["port"] = file:read("*line")
	rv["tempur"] = file:read("*line")
	rv["proto"] = file:read("*line")
	rv["mode"] = file:read("*line")


	-- echo $IMEI #imei
	-- echo $IMSI #imsi
	-- echo $ICCID #iccid
	-- echo $phone #phone
	rv["imei"] = file:read("*line")
	rv["imsi"] = file:read("*line")
	rv["iccid"] =file:read("*line")
	rv["phone"] = file:read("*line")
	file:read("*line")


	-- echo $net_type
	-- echo $CSQ
	-- echo $CSQ_PER
	-- echo $CSQ_RSSI
	-- echo '' #参考信号接收质量 RSRQ ecio
	-- echo '' #参考信号接收质量 RSRQ ecio1
	-- echo '' #参考信号接收功率 RSRP rscp
	-- echo '' #参考信号接收功率 RSRP rscp1
	-- echo '' #信噪比 SINR  rv["sinr"]
	-- echo '' #连接状态监控 rv["netmode"]
	rv["net_type"] = file:read("*line")
	rv["csq"] = file:read("*line")
	rv["per"] = file:read("*line")
	rv["rssi"] = file:read("*line")
	rv["ecio"] = file:read("*line")
	rv["ecio1"] = file:read("*line")
	rv["rscp"] = file:read("*line")
	rv["rscp1"] = file:read("*line")
	rv["sinr"] = file:read("*line")
	rv["netmode"] = file:read("*line")
	file:read("*line")
	
	rssi = rv["rssi"]
	ecio = rv["ecio"]
	rscp = rv["rscp"]
	ecio1 = rv["ecio1"]
	rscp1 = rv["rscp1"]
	if ecio == nil then
		ecio = "-"
	end
	if ecio1 == nil then
		ecio1 = "-"
	end
	if rscp == nil then
		rscp = "-"
	end
	if rscp1 == nil then
		rscp1 = "-"
	end

	if ecio ~= "-" then
		rv["ecio"] = ecio .. " dB"
	end
	if rscp ~= "-" then
		rv["rscp"] = rscp .. " dBm"
	end
	if ecio1 ~= " " then
		rv["ecio1"] = " (" .. ecio1 .. " dB)"
	end
	if rscp1 ~= " " then
		rv["rscp1"] = " (" .. rscp1 .. " dBm)"
	end

	rv["mcc"] = file:read("*line")
	rv["mnc"] = file:read("*line")
    rv["rnc"] = file:read("*line")
	rv["rncn"] = file:read("*line")
	rv["lac"] = file:read("*line")
	rv["lacn"] = file:read("*line")
	rv["cid"] = file:read("*line")
	rv["cidn"] = file:read("*line")
	rv["lband"] = file:read("*line")
	rv["channel"] = file:read("*line")
	rv["pci"] = file:read("*line")

	rv["date"] = file:read("*line")
	
	-- rv["phonen"] = file:read("*line")
	--rv["host"] = "0"

	-- rv["simerr"] = "0"
	
	-- rv["down"] = file:read("*line")
	-- rv["up"] = file:read("*line")

	-- rv["cell"] = file:read("*line")
	-- rv["modtype"] = file:read("*line")

	-- rv["lat"] = "-"
	-- rv["long"] = "-"	

	rv["crate"] = translate("快速(每10秒更新一次)")
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

-- at页面命令函数
function at()
    local devv = tostring(uci:get("modem", "general", "atport"))

    local at_code = http.formvalue("code")
    if at_code then
	    local odpall = io.popen("sms_tool -d " .. devv .. " at "  ..at_code:gsub("[$]", "\\\$"):gsub("\"", "\\\"").." 2>&1")
	    local odp =  odpall:read("*a")
	    odpall:close()
        http.write(tostring(odp))
    else
        http.write_json(http.formvalue())
    end
end

-- AT界面模块选择
function modemSelect()

	local at_ports={}
	local at={}
	local modem_number=uci:get('modem','global','modem_number')
	for i=0,modem_number do
		local at_port = uci:get('modem','modem'..i,'at_port')
		at_ports[#at_ports+1]=at_port
		-- table.insert(at_ports,at_port)
	end
	
	-- 遍历查找AT串口
	-- uci:foreach("modem", "modem-device", function (modem_device)
	-- 	at_port = modem_device["at_port"]
	-- 	at_ports[#at_ports+1]=at_port
	-- end)
	luci.http.prepare_content("application/json")
	luci.http.write_json(at_ports)
end

-- 用户AT命令读取
function uat(rv)
	local command_file = nixio.fs.access("/etc/config/atcmds.user") and
		io.popen("cat /etc/config/atcmds.user")

	if command_file then
		for line in command_file:lines() do
			local i = line
			if i then
				rv[#rv + 1] = {
					atu = i
				}
			end
		end
		command_file:close()
	end
end

-- 用户AT命令写入函数
function useratc()
	local atu = { }
	uat(atu)
	luci.http.prepare_content("application/json")
	luci.http.write_json(atu)
end
