-- Copyright (C) 2026 ainuoyan
-- Licensed under the GNU General Public License v3.
-- Local SMS archive and verified modem storage cleanup, 2026-10-10.

local nixio = require "nixio"
local fs = require "nixio.fs"
local json = require "luci.jsonc"
local util = require "luci.util"
local uci = require "luci.model.uci"
local M = {}
local directory = "/etc/sms-tool"
local archive_path = directory .. "/inbox.json"
local status_path = "/var/run/sms-tool-inbox/status.json"

local function ensure_directory(path)
    if not fs.stat(path) then assert(fs.mkdir(path, "700"), "无法创建短信保存目录") end
    assert(fs.stat(path, "type") == "dir" and fs.chmod(path, "700"), "短信保存目录不可用")
end

local function atomic_write(path, bytes, durable)
    local temporary = path .. ".tmp." .. nixio.getpid()
    local file = assert(nixio.open(temporary, "w", "600"), "无法写入短信文件，请检查磁盘空间")
    local ok, err = pcall(function()
        local offset = 0
        while offset < #bytes do
            local written = file:write(bytes, offset)
            assert(written and written > 0, "短信写入未完成，卡上短信已保留")
            offset = offset + written
        end
        if durable then assert(file:sync(), "短信文件同步失败，卡上短信已保留") end
        assert(file:close(), "短信文件关闭失败")
        file = nil
        assert(fs.rename(temporary, path), "短信文件保存失败，卡上短信已保留")
    end)
    if file then file:close() end
    if not ok then fs.unlink(temporary); error(err, 0) end
end

local function verify_archive(bytes)
    local file = assert(nixio.open(archive_path, "r"), "无法复核已保存短信")
    local synced = file:sync()
    file:close()
    local parent = assert(nixio.open(directory, "r"), "无法同步短信目录")
    local directory_synced = parent:sync()
    parent:close()
    assert(synced and directory_synced and fs.readfile(archive_path) == bytes,
        "短信保存核验失败，卡上短信已保留")
end

local function valid_pdu(pdu)
    return type(pdu) == "string" and #pdu >= 2 and #pdu % 2 == 0
        and not pdu:find("[^%x]")
end

local function load_archive()
    local bytes = fs.readfile(archive_path)
    if not bytes then
        assert(not fs.stat(archive_path), "无法读取本地短信文件")
        return {version = 1, next_id = 1, messages = {}}
    end
    local store = json.parse(bytes)
    assert(type(store) == "table" and store.version == 1
        and type(store.messages) == "table" and type(store.next_id) == "number"
        and store.next_id >= 1 and store.next_id == math.floor(store.next_id),
        "本地短信文件损坏，已停止释放卡上空间")
    for key in pairs(store.messages) do
        assert(type(key) == "number" and key >= 1 and key <= #store.messages
            and key == math.floor(key), "本地短信列表损坏，已停止释放短信空间")
    end
    local seen = {}
    for _, message in ipairs(store.messages) do
        assert(type(message) == "table" and type(message.index) == "number" and message.index > 0
            and message.index == math.floor(message.index)
            and message.index < store.next_id and not seen[message.index]
            and type(message.sim) == "string" and valid_pdu(message.pdu)
            and (message.storage == "SM" or message.storage == "ME")
            and type(message.sender) == "string" and type(message.timestamp) == "string"
            and type(message.content) == "string" and type(message.released) == "boolean",
            "本地短信记录不完整，已停止释放卡上空间")
        seen[message.index] = true
    end
    return store, bytes
end

local function save_archive(store, previous)
    local bytes = assert(json.stringify(store), "无法编码本地短信文件")
    ensure_directory(directory)
    if bytes ~= previous then atomic_write(archive_path, bytes, true) end
    verify_archive(bytes)
    return bytes
end

function M.set_status(status)
    ensure_directory("/var/run/sms-tool-inbox")
    status.checked_at = os.time()
    atomic_write(status_path, assert(json.stringify(status)), false)
end

local function run(command)
    local output = util.exec(command .. " 2>/dev/null; printf '\\nSMS_TOOL_EXIT=%s\\n' \"$?\"")
    local body, code = output:match("^(.*)\nSMS_TOOL_EXIT=(%d+)\n$")
    assert(body and tonumber(code) == 0, "模组读取失败，已保存的短信仍可查看")
    return body:gsub("\r", "")
end

local function configuration()
    local cursor = uci.cursor()
    local port = cursor:get("sms_tool", "general", "readport") or ""
    local storage = cursor:get("sms_tool", "general", "storage") or "SM"
    assert(port:match("^/dev/tty[%w_.%-]+$"), "请先设置有效的短信读取端口")
    assert(storage == "SM" or storage == "ME", "短信读取区仅支持 SIM 或模组内存")
    return port, storage
end

local function connection(port)
    local command = "sms_tool -d " .. util.shellquote(port)
    return function(at_command)
        local reply = run(command .. " -D at " .. util.shellquote(at_command))
        assert(reply:match("\nOK%s*$") or reply:match("^OK%s*$"), "模组命令未成功，卡上短信已保留")
        return reply
    end, command
end

local function sim_identity(at)
    local sim = at("AT+QCCID"):match("%+QCCID:%s*(%d+)")
    assert(sim and #sim >= 18 and #sim <= 22, "无法确认 SIM 身份，暂不释放短信空间")
    return sim
end

local function capacity(at)
    local reply = at("AT+CPMS?")
    local storage, used, total, write_storage, receive = reply:match(
        '%+CPMS:%s*"(%w+)"%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*"(%w+)"%s*,%s*%d+%s*,%s*%d+%s*,%s*"(%w+)"')
    assert(storage and receive and (write_storage == "SM" or write_storage == "ME"
        or write_storage == "MT" or write_storage == "SR"), "无法确认短信存储状态")
    return {storage = storage, used = tonumber(used), total = tonumber(total)}, receive, write_storage
end

local function record_key(sim, storage, pdu)
    return sim .. ":" .. storage .. ":" .. pdu:upper()
end

local function timestamp_with_zone(record)
    local clock = record.timestamp:gsub(" ", "T"):gsub("Z$", "")
    if not clock:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$") then return record.timestamp end
    local function octet(offset)
        return tonumber(record.pdu:sub(offset * 2 + 1, offset * 2 + 2), 16)
    end
    local deliver = 1 + octet(0)
    local first, address_length = octet(deliver), octet(deliver + 1)
    if not first or first % 4 ~= 0 or not address_length then return clock end
    local zone = octet(deliver + 3 + math.floor((address_length + 1) / 2) + 8)
    if not zone or math.floor(zone / 16) > 9 then return clock end
    -- sms_tool ignores TP-SCTS timezone; retain the service-centre clock and offset.
    -- TS 23.040 9.2.3.11: signed semi-octet quarter hours, sign in bit 3.
    local quarters = zone % 8 * 10 + math.floor(zone / 16)
    return clock .. string.format("%s%02d:%02d", zone % 16 >= 8 and "-" or "+",
        math.floor(quarters / 4), quarters % 4 * 15)
end

function M.collect()
    local port, preferred = configuration()
    local at, command = connection(port)
    local sim = sim_identity(at)
    local _, receive, write_storage = capacity(at)
    assert(receive == "SM" or receive == "ME", "当前接收区不受支持，卡上短信已保留")
    local readable, writable, receivable = at("AT+CPMS=?"):match('%+CPMS:%s*%((.-)%)%s*,%s*%((.-)%)%s*,%s*%((.-)%)')
    assert(readable and writable and receivable and readable:find('"' .. preferred .. '"', 1, true)
        and receivable:find('"' .. preferred .. '"', 1, true), "模组不支持所选短信缓冲区")
    local storages = {preferred}
    for _, storage in ipairs({"SM", "ME"}) do
        if storage ~= preferred and readable:find('"' .. storage .. '"', 1, true) then
            storages[#storages + 1] = storage
        end
    end
    local store, previous = load_archive()
    local existing, live, candidates, capacities, scanned = {}, {}, {}, {}, {}
    for _, message in ipairs(store.messages) do
        existing[record_key(message.sim, message.storage, message.pdu)] = message
    end
    for _, storage in ipairs(storages) do
        scanned[storage] = true
        at('AT+CPMS="' .. storage .. '"')
        local current = capacity(at)
        local output = run(command .. " -s " .. storage .. " -f '%Y-%m-%dT%H:%M:%S' -j recv")
        local data = json.parse(output)
        local messages = type(data) == "table" and (data.msg or data.sms)
        assert(type(messages) == "table" and (#messages > 0 or current.used == 0),
            "短信列表读取不完整，卡上短信已保留")
        for _, message in ipairs(messages) do
            assert(type(message.index) == "number" and message.index >= 0
                and message.index == math.floor(message.index) and valid_pdu(message.pdu)
                and type(message.sender) == "string" and type(message.timestamp) == "string"
                and type(message.content) == "string",
                "短信工具缺少完整原始数据，请更新后重试；卡上短信已保留")
            local key = record_key(sim, storage, message.pdu)
            live[key] = true
            local record = existing[key]
            if not record then
                record = {}
                for name, value in pairs(message) do record[name] = value end
                record.index, record.slot = store.next_id, message.index
                record.sim, record.storage, record.released = sim, storage, false
                store.next_id = store.next_id + 1
                store.messages[#store.messages + 1] = record
                existing[key] = record
            end
            record.released = false
            candidates[#candidates + 1] = {record = record, slot = message.index, storage = storage}
        end
    end
    -- Every original PDU must be durable and read back before any deletion.
    previous = save_archive(store, previous)
    local warning
    for _, candidate in ipairs(candidates) do
        local record = candidate.record
        if record.error then
            warning = "有短信暂时无法解码，原始数据已保存，卡上短信保留"
        else
            assert(sim_identity(at) == sim, "SIM 已变化，已停止释放短信空间")
            at('AT+CPMS="' .. candidate.storage .. '"')
            local reply = at("AT+CMGR=" .. candidate.slot)
            local pdu = reply:match("%+CMGR:[^\n]*\n%s*(%x+)%s*\n")
            if pdu and pdu:upper() == record.pdu:upper() then
                assert(sim_identity(at) == sim, "SIM 已变化，已停止释放短信空间")
                at("AT+CMGD=" .. candidate.slot)
                record.released = true
            else
                warning = "短信槽位内容已变化，已保留卡上短信，稍后重新读取"
            end
        end
    end
    for _, record in ipairs(store.messages) do
        if record.sim == sim and scanned[record.storage]
            and not live[record_key(sim, record.storage, record.pdu)] then
            record.released = true
        end
    end
    save_archive(store, previous)
    for _, storage in ipairs(storages) do
        at('AT+CPMS="' .. storage .. '"')
        capacities[#capacities + 1] = capacity(at)
    end
    if receive ~= preferred then
        at('AT+CPMS="' .. preferred .. '","' .. write_storage .. '","' .. preferred .. '"')
    else at('AT+CPMS="' .. preferred .. '"') end
    local _, confirmed_receive = capacity(at)
    assert(confirmed_receive == preferred, "短信接收区设置未生效，稍后重试")
    local status = {ok = true, warning = warning, capacity = capacities, receive_storage = confirmed_receive}
    M.set_status(status)
    return status
end

function M.snapshot()
    local store = load_archive()
    local status = json.parse(fs.readfile(status_path) or "") or {}
    local messages, sim_groups, sim_count = {}, {}, 0
    for _, record in ipairs(store.messages) do
        if not sim_groups[record.sim] then
            sim_count = sim_count + 1
            sim_groups[record.sim] = sim_count
        end
        local message = {scope = sim_groups[record.sim]}
        for _, name in ipairs({"index", "sender", "timestamp", "content", "reference", "part", "total", "error", "released"}) do
            message[name] = record[name]
        end
        message.timestamp = timestamp_with_zone(record)
        messages[#messages + 1] = message
    end
    local cursor = uci.cursor()
    return {ok = true, messages = messages, capacity = status.capacity or {},
        checked_at = status.checked_at, warning = status.warning,
        error = status.error, receive_storage = status.receive_storage,
        merge = cursor:get("sms_tool", "general", "mergesms") ~= "0"}
end

function M.delete_saved(ids)
    assert(type(ids) == "string" and ids:match("^%d+[,%d]*$") and #ids <= 8192, "请选择要删除的本地短信")
    local selected = {}
    for id in ids:gmatch("%d+") do selected[tonumber(id)] = true end
    local store, previous = load_archive()
    local kept = {}
    for _, record in ipairs(store.messages) do
        if selected[record.index] then
            assert(record.released, "短信仍在等待缓冲区清理，暂不能删除本地备份")
        else kept[#kept + 1] = record end
    end
    store.messages = kept
    save_archive(store, previous)
    return {ok = true}
end

return M
