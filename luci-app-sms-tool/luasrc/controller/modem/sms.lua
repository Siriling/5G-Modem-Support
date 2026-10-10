	local util = require "luci.util"
	local fs = require "nixio.fs"
	local sys = require "luci.sys"
	local http = require "luci.http"
	local dispatcher = require "luci.dispatcher"
	local http = require "luci.http"
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()

module("luci.controller.modem.sms", package.seeall)

function index()
	if not fs.access("/etc/config/modem") then
		entry({"admin", "network", "modem"}, firstchild(), translate("Modem"), 100).dependent = false
	end

	entry({"admin", "network", "modem", "sms"}, alias("admin", "network", "modem", "sms", "readsms"), translate("短信"), 60)
	entry({"admin", "network", "modem", "sms", "readsms"},template("modem/readsms"),translate("收到的信息"), 10)
	entry({"admin", "network", "modem", "sms", "sendsms"},template("modem/sendsms"),translate("发送短信"), 20)
	entry({"admin", "network", "modem", "sms", "ussd"},template("modem/ussd"),translate("USSD 代码"), 30)
	entry({"admin", "network", "modem", "sms", "atcommands"},template("modem/atcommands"),translate("AT 命令"), 40)
	entry({"admin", "network", "modem", "sms", "smsconfig"},cbi("modem/smsconfig"),translate("配置"), 50)
	entry({"admin", "network", "modem", "sms", "get_inbox"}, call("get_inbox"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "delete_saved"}, post("delete_saved"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "run_ussd"}, call("ussd"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "run_at"}, call("at"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "run_sms"}, call("sms"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "readsim"}, call("slots"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "countsms"}, call("count_sms"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "user_ussd"}, call("userussd"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "user_atc"}, call("useratc"), nil).leaf = true
	entry({"admin", "network", "modem", "sms", "user_phonebook"}, call("userphb"), nil).leaf = true
end


-- Modified by ainuoyan, 2026-10-10: serve durable SMS without polling the serial port.
function get_inbox()
    local inbox = require "luci.model.sms_tool.inbox"
    local ok, result = pcall(inbox.snapshot)
    if not ok then
        http.status(503, "Service Unavailable")
        result = {ok = false, error = tostring(result):gsub("^.-:%d+: ", "")}
    end
    http.header("Cache-Control", "no-store, private")
    http.prepare_content("application/json")
    http.write_json(result)
end

function delete_saved()
    local ids = http.formvalue("ids") or ""
    if #ids > 8192 or not ids:match("^%d+[,%d]*$") then
        http.status(400, "Bad Request")
        http.prepare_content("application/json")
        http.write_json({ok = false, error = "请选择要删除的本地短信"})
        return
    end
    local output = util.exec("flock -n /var/lock/sms-tool-inbox.lock /usr/bin/lua "
        .. "/usr/share/sms-tool/inbox-worker.lua delete " .. util.shellquote(ids))
    local result = require("luci.jsonc").parse(output)
    if type(result) ~= "table" then result = {ok = false, error = "正在保存新短信，请稍后再试"} end
    if not result.ok then http.status(409, "Conflict") end
    http.prepare_content("application/json")
    http.write_json(result)
end

function get_ussd()
    local cursor = luci.model.uci.cursor()
    if cursor:get("sms_tool", "general", "ussd") == "1" then
        return " -R"
    else
        return ""
    end
end


function get_pdu()
    local cursor = luci.model.uci.cursor()
    if cursor:get("sms_tool", "general", "pdu") == "1" then
        return " -r"
    else
        return ""
    end
end

-- All SMS UI operations share the collector's serial lock.
local function locked_sms(port, arguments)
    if not port:match("^/dev/tty[%w_.%-]+$") then return "请先配置有效的短信端口" end
    local output = util.exec("flock -n " .. util.shellquote("/var/lock/modem-at-" .. port:match("[^/]+$") .. ".lock")
        .. " sms_tool -d " .. util.shellquote(port) .. arguments .. " 2>&1")
    return output ~= "" and output or "短信端口正忙或未返回数据，请稍后重试。"
end


function ussd()
    local devv = tostring(uci:get("sms_tool", "general", "ussdport"))

	local ussd = get_ussd()
	local pdu = get_pdu()

    local ussd_code = http.formvalue("code")
    if ussd_code then
        http.write(locked_sms(devv, ussd .. pdu .. " ussd " .. util.shellquote(ussd_code)))
    else
        http.write_json(http.formvalue())
    end
end


function at()
    local devv = tostring(uci:get("sms_tool", "general", "atport"))

    local at_code = http.formvalue("code")
    if at_code then
        http.write(locked_sms(devv, " at " .. util.shellquote(at_code)))
    else
        http.write_json(http.formvalue())
    end
end


function sms()
    local devv = tostring(uci:get("sms_tool", "general", "sendport"))
    local sms_code = http.formvalue("scode")

    if sms_code then
        local nr = string.sub(sms_code, 1, 20):match("^%s*(.-)%s*$")
        local msg = string.sub(sms_code, 21):gsub("\n", " ")
        http.write(locked_sms(devv, " send " .. util.shellquote(nr) .. " " .. util.shellquote(msg)))
    else
        http.write_json(http.formvalue())
    end

end

function slots()
	local sim = { }
	local devv = tostring(uci:get("sms_tool", "general", "readport"))
	local led = tostring(uci:get("sms_tool", "general", "smsled"))
	local dsled = tostring(uci:get("sms_tool", "general", "ledtype"))
	local ln = tostring(uci:get("sms_tool", "general", "lednotify"))

	local smsmem = tostring(uci:get("sms_tool", "general", "storage"))

	local statusb = luci.util.exec("flock /var/lock/modem-at-" .. devv:match("[^/]+$") .. ".lock sms_tool -s" .. smsmem .. " -d ".. devv .. " status")
	local usex = string.sub (statusb, 23, 27)
	local max = statusb:match('[^: ]+$')
	sim["use"] = string.match(usex, '%d+')
	local smscount = string.match(usex, '%d+')
	if ln == "1" then
      		luci.sys.call("echo " .. smscount .. " > /etc/config/sms_count")
		if dsled == "S" then
		luci.util.exec("/etc/init.d/led restart")
		end
		if dsled == "D" then
		luci.sys.call("echo 0 > '/sys/class/leds/" .. led .. "/brightness'")
		end
 	end
	sim["all"] = string.match(max, '%d+')
	luci.http.prepare_content("application/json")
	luci.http.write_json(sim)
end


function count_sms()
    os.execute("sleep 3")
    local cursor = luci.model.uci.cursor()
    if cursor:get("sms_tool", "general", "lednotify") == "1" then
        local devv = tostring(uci:get("sms_tool", "general", "readport"))

	 local smsmem = tostring(uci:get("sms_tool", "general", "storage"))

        local statusb = luci.util.exec("flock /var/lock/modem-at-" .. devv:match("[^/]+$") .. ".lock sms_tool -s" .. smsmem .. " -d ".. devv .. " status")
        local smsnum = string.sub (statusb, 23, 27)
        local smscount = string.match(smsnum, '%d+')
        os.execute("echo " .. smscount .. " > /etc/config/sms_count")
    end
end


function uussd(rv)
	local c = nixio.fs.access("/etc/config/ussd.user") and
		io.popen("cat /etc/config/ussd.user")

	if c then
		for l in c:lines() do
			local i = l
			if i then
				rv[#rv + 1] = {
					usd = i
				}
			end
		end
		c:close()
	end
end



function userussd()
	local usd = { }
	uussd(usd)
	luci.http.prepare_content("application/json")
	luci.http.write_json(usd)
end


function uat(rv)
	local c = nixio.fs.access("/etc/config/atcmds.user") and
		io.popen("cat /etc/config/atcmds.user")

	if c then
		for l in c:lines() do
			local i = l
			if i then
				rv[#rv + 1] = {
					atu = i
				}
			end
		end
		c:close()
	end
end



function useratc()
	local atu = { }
	uat(atu)
	luci.http.prepare_content("application/json")
	luci.http.write_json(atu)
end



function uphb(rv)
	local c = nixio.fs.access("/etc/config/phonebook.user") and
		io.popen("cat /etc/config/phonebook.user")

	if c then
		for l in c:lines() do
			local i = l
			if i then
				rv[#rv + 1] = {
					phb = i
				}
			end
		end
		c:close()
	end
end



function userphb()
	local phb = { }
	uphb(phb)
	luci.http.prepare_content("application/json")
	luci.http.write_json(phb)
end
