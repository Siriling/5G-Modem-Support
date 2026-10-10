-- Exercise route registration without LuCI, a modem, or filesystem writes.
-- Modified by ainuoyan, 2026-10-10: require POST for local archive deletion.
local source = arg[1] or "luci-app-sms-tool/luasrc/controller/modem/sms.lua"

for _, modem_installed in ipairs({ false, true }) do
    local routes = {}
    local environment = setmetatable({
        module = function() end,
        require = function(name)
            if name == "nixio.fs" then
                return { access = function(path)
                    assert(path == "/etc/config/modem")
                    return modem_installed
                end }
            elseif name == "luci.model.uci" then
                return { cursor = function() return {} end }
            end
            return {}
        end,
        entry = function(path, target, title)
            local route = { target = target, title = title }
            routes[table.concat(path, "/")] = route
            return route
        end,
        alias = function(...) return table.concat({...}, "/") end,
        translate = function(text) return text end,
        firstchild = function() return "firstchild" end,
        template = function(name) return name end,
        cbi = function(name) return name end,
        call = function(name) return name end,
        post = function(name) return "post:" .. name end
    }, { __index = _G })
    local controller = assert(loadfile(source))
    setfenv(controller, environment)
    controller()
    environment.index()
    local parent = routes["admin/network/modem"]
    if modem_installed then
        assert(parent == nil, "Do not replace the modem plugin's menu")
    else
        assert(parent and parent.title == "Modem" and parent.dependent == false)
    end
    assert(routes["admin/network/modem/sms"].target == "admin/network/modem/sms/readsms")
    for _, name in ipairs({"readsms", "sendsms", "ussd", "atcommands", "smsconfig",
            "get_inbox", "delete_saved", "run_ussd", "run_at", "run_sms", "readsim",
            "countsms", "user_ussd", "user_atc", "user_phonebook"}) do
        assert(routes["admin/network/modem/sms/" .. name], "Missing SMS route: " .. name)
    end
    assert(routes["admin/network/modem/sms/delete_saved"].target == "post:delete_saved")
    assert(routes["admin/network/modem/sms/delete_one"] == nil)
    assert(routes["admin/network/modem/sms/delete_all"] == nil)
    assert(routes["admin/modem"] == nil, "Do not create a duplicate top-level menu")
end

print("SMS menu: standalone and combined installation passed")
