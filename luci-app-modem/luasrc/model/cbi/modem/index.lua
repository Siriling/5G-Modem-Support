local d = require "luci.dispatcher"
local uci = luci.model.uci.cursor()

m = Map("modem")
m.title = translate("Modem Config")
m.description = translate("Configuration panel for Modem, Add configuration to all modems on this page")

--全局配置
s = m:section(NamedSection, "global", "global", translate("Global Config"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enable", translate("Enable"))
o.rmempty = false
o.description = translate("Check to enable all configurations")

-- 添加模块状态
m:append(Template("modem/modem_status"))

s = m:section(TypedSection, "config", translate("Config List"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
s.extedit = d.build_url("admin", "network", "modem", "config", "%s")

function s.create(uci, t)
    local uuid = string.gsub(luci.sys.exec("echo -n $(cat /proc/sys/kernel/random/uuid)"), "-", "")
    t = uuid
    TypedSection.create(uci, t)
    luci.http.redirect(uci.extedit:format(t))
end
function s.remove(uci, t)
    uci.map.proceed = true
    uci.map:del(t)
    luci.http.redirect(d.build_url("admin", "network", "modem","index"))
end

o = s:option(Flag, "enable", translate("Enable"))
o.width = "5%"
o.rmempty = false

-- o = s:option(DummyValue, "status", translate("Status"))
-- o.template = "modem/status"
-- o.value = translate("Collecting data...")

o = s:option(DummyValue, "remarks", translate("Remarks"))

o = s:option(DummyValue, "network", translate("Moblie Network"))
o.cfgvalue = function(t, n)
    -- 检测移动网络是否存在
    local network = (Value.cfgvalue(t, n) or "")
    local odpall = io.popen("ls /sys/class/net/ | grep -w "..network.." | wc -l")
    local odp = odpall:read("*a"):gsub("\n","")
    odpall:close()
    if odp ~= "0" then
        return network
    else
        return "The network device was not found"
    end
end

o = s:option(DummyValue, "dial_tool", translate("Dial Tool"))
o.cfgvalue = function(t, n)
    local dial_tool = (Value.cfgvalue(t, n) or "")
    if dial_tool == "" then
        dial_tool=translate("Auto Choose")
    end
    return dial_tool
end

o = s:option(DummyValue, "pdp_type", translate("PDP Type"))
o.cfgvalue = function(t, n)
    local pdp_type = (Value.cfgvalue(t, n) or ""):gsub("_","/"):upper():gsub("V","v")
    return pdp_type
end

o = s:option(DummyValue, "apn", translate("APN"))
o.cfgvalue = function(t, n)
    local apn = (Value.cfgvalue(t, n) or ""):gsub("_","/"):upper():gsub("V","v")
    if apn == "" then
        apn=translate("Auto Choose")
    end
    return apn
end

-- m:append(Template("modem/list_status"))

return m
