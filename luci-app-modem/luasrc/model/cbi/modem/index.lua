local d = require "luci.dispatcher"
local e = luci.model.uci.cursor()

m = Map("modem")
m.title = translate("Modem Config")
m.description = translate("Configuration panel for Modem, Add and configure all modules on this page")

s = m:section(NamedSection, "global", "global")
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enable", translate("Enable"))
o.rmempty = false

s = m:section(TypedSection, "config", translate("Modem List"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
s.extedit = d.build_url("admin", "network", "modem", "config", "%s")

function s.create(e, t)
    local uuid = string.gsub(luci.sys.exec("echo -n $(cat /proc/sys/kernel/random/uuid)"), "-", "")
    t = uuid
    TypedSection.create(e, t)
    luci.http.redirect(e.extedit:format(t))
end
function s.remove(e, t)
    e.map.proceed = true
    e.map:del(t)
    luci.http.redirect(d.build_url("admin", "network", "modem"))
end

o = s:option(Flag, "enable", translate("Enable"))
o.width = "5%"
o.rmempty = false

-- o = s:option(DummyValue, "status", translate("Status"))
-- o.template = "modem/status"
-- o.value = translate("Collecting data...")

o = s:option(DummyValue, "remarks", translate("Remarks"))

o = s:option(DummyValue, "moblie_net", translate("Moblie Network"))
o.cfgvalue = function(t, n)
    -- 检测移动网络设备是否存在
    local moblie_net = (Value.cfgvalue(t, n) or "")
    local odpall = io.popen("ls /sys/class/net/ | grep -w "..moblie_net.." | wc -l")
    local odp =  odpall:read("*a"):gsub("\n","")
    odpall:close()
    if odp ~= "0" then
        return moblie_net
    else
        return "The network device was not found"
    end
end

o = s:option(DummyValue, "mode", translate("Mode"))
o.cfgvalue = function(t, n)
    local mode = (Value.cfgvalue(t, n) or ""):upper()
    return mode
end

o = s:option(DummyValue, "pdp_type", translate("PDP Type"))
o.cfgvalue = function(t, n)
    local pdp_type = (Value.cfgvalue(t, n) or ""):gsub("_","/"):upper():gsub("V","v")
    return pdp_type
end

-- m:append(Template("modem/list_status"))

return m
