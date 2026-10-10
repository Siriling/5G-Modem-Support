local json = require "luci.jsonc"
local util = require "luci.util"
local bands = dofile("/usr/share/modem/baiwang_band.lua")
local action, port, payload = arg[1], arg[2], arg[3]

local function at(command)
    assert(type(port) == "string" and port:match("^/dev/ttyUSB%d+$"), "Invalid AT port")
    local pipe = assert(io.popen("sh /usr/share/modem/modem_at.sh " .. util.shellquote(port) .. " " .. util.shellquote(command)
        .. '; modem_status=$?; printf "\\n__QDC507_STATUS:%s\\n" "$modem_status"'))
    local response = pipe:read("*a")
    pipe:close()
    -- Current sms_tool removes the final OK/ERROR; preserve its exit status.
    local status = response:match("\n__QDC507_STATUS:(%d+)\n$")
    assert(status == "0" and not response:find("ERROR", 1, true), "Modem rejected " .. command)
    response = response:gsub("\n__QDC507_STATUS:%d+\n$", "")
    return response
end

local function restart_radio()
    -- Reattach after changing NAS preferences; leave the USB composition intact.
    at("AT+CFUN=0")
    at("AT+CFUN=1")
end

local function get_bands()
    local file = assert(io.open("/usr/share/modem/modem_support.json"))
    local support = json.parse(file:read("*a"))
    file:close()
    local result = {}
    for band in support.modem_support.usb.qdc507.band_4g:gmatch("%d+") do result[#result + 1] = tonumber(band) end
    return result
end

local function get_mask()
    local response = at('AT+QCFG="band"')
    local legacy, lte, tds = response:match('"band",%s*([^,]+),%s*([^,]+),%s*([^,\r\n]+)')
    assert(legacy and lte and tds, "Invalid band response")
    return legacy, lte, tds
end

local function get_mode()
    return assert(tonumber(at('AT+QCFG="nwscanmodeex"'):match('"nwscanmodeex",%s*(%d+)')), "Invalid network mode response")
end

local function run()
    if action == "get" then
        local mode = get_mode()
        local _, mask = get_mask()
        return {
            band_lock = true,
            network_prefer = {
                { ["2G"] = { enable = math.floor(mode / 4) % 2, band = {} } },
                { ["3G"] = { enable = math.floor(mode / 8) % 2, band = {} } },
                { ["4G"] = { enable = math.floor(mode / 16) % 2, band = bands.decode(mask, get_bands()) } }
            }
        }
    end

    local config = assert(json.parse(payload or ""), "Invalid preference configuration")
    assert(type(config) == "table", "Invalid preference configuration")
    if action == "set_network" then
        local mode = 0
        local values = { ["2G"] = 4, ["3G"] = 8, ["4G"] = 16 }
        for name, value in pairs(config) do
            assert(values[name] and type(value) == "table", "Unsupported network type")
            assert(value.enable == 0 or value.enable == 1, "Invalid network state")
            mode = mode + values[name] * value.enable
        end
        assert(mode > 0, "Select at least one network type")
        local changed = mode ~= get_mode()
        if changed then at('AT+QCFG="nwscanmodeex",' .. mode) end
        -- QDC507 acknowledges before the NAS preference is readable.
        local applied = false
        for attempt = 1, 5 do
            if get_mode() == mode then applied = true; break end
            if attempt < 5 then util.exec("sleep 1") end
        end
        assert(applied, "Network mode did not change")
        if changed then restart_radio() end
    elseif action == "set_band" then
        assert(config["4G"] and config["4G"].enable == 1, "Enable 4G before selecting LTE bands")
        local mask = bands.encode(config["4G"].band, get_bands())
        local legacy, current, tds = get_mask()
        local changed = mask:lower():gsub("^0x0*", "") ~= current:lower():gsub("^0x0*", "")
        if changed then at('AT+QCFG="band",' .. legacy:gsub('^0[xX]', '') .. ',' .. mask:gsub('^0[xX]', '') .. ',' .. tds:gsub('^0[xX]', '') .. ',1') end
        local _, actual = get_mask()
        assert(actual:lower():gsub("^0x0*", "") == mask:lower():gsub("^0x0*", ""), "LTE band mask did not change")
        if changed then restart_radio() end
    else
        error("Unknown modem action")
    end
    return { success = true }
end

local ok, result = pcall(run)
if not ok then result = { success = false, error = tostring(result) } end
print(json.stringify(result))
if not ok then os.exit(1) end
