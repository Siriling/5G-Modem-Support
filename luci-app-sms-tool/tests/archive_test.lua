-- Copyright (C) 2026 ainuoyan; GNU General Public License v3.
-- In-memory filesystem and modem only; never opens a real serial port.
local json = require "luci.jsonc"
local source = assert(arg[1], "pass the inbox.lua path")
local path = "/etc/sms-tool/inbox.json"
local cases, checks = 0, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function equal(actual, expected, message) check(actual == expected, message) end
local function message(pdu, extra)
    local value = {pdu = pdu, sender = "fixture", timestamp = "2026-10-10 12:00:00", content = "测试短信"}
    for name, item in pairs(extra or {}) do value[name] = item end
    return value
end
local function setup(options)
    local state = options or {}
    state.files, state.dirs = state.files or {}, { ["/var/run"] = true }
    state.slots = state.slots or {SM = {[55] = message("00AA")}, ME = {[80] = message("00BB")}}
    state.preferred, state.read, state.receive = state.preferred or "ME", "SM", state.receive or "SM"
    state.deletions, state.sim_reads = 0, 0
    state.sim = "8900000000000000001" -- synthetic fixture identity
    local fs = {}
    function fs.stat(name, field)
        local kind = state.dirs[name] and "dir" or state.files[name] and "reg"
        if field == "type" then return kind end
        return kind and {type = kind}
    end
    function fs.mkdir(name) state.dirs[name] = true; return true end
    function fs.chmod() return true end
    function fs.unlink(name) state.files[name] = nil; return true end
    function fs.rename(old, new)
        if state.fail == "rename" then return nil end
        state.files[new], state.files[old] = state.files[old], nil
        return true
    end
    function fs.readfile(name)
        if name == path and state.file_synced and state.directory_synced then
            if state.fail == "readback" then return "different bytes" end
            state.verified = true
        end
        return state.files[name]
    end
    local nixio = {getpid = function() return 123 end}
    function nixio.open(name, mode)
        if mode == "w" then
            if state.fail == "open" then return nil end
            state.files[name], state.verified = "", false
        elseif not fs.stat(name) then return nil end
        local file = {}
        function file:write(bytes, offset)
            if state.fail == "write" then return nil end
            local count = math.min(state.short_writes and 7 or #bytes, #bytes - offset)
            state.files[name] = state.files[name] .. bytes:sub(offset + 1, offset + count)
            return count
        end
        function file:sync()
            if name:find(".tmp.", 1, true) and state.fail == "write_sync" then return nil end
            if name == path then
                if state.fail == "file_sync" then return nil end
                state.file_synced = true
            elseif name == "/etc/sms-tool" then
                if state.fail == "directory_sync" then return nil end
                state.directory_synced = true
            end
            return true
        end
        function file:close() return state.fail ~= "close" end
        return file
    end
    local function used(storage)
        local count = 0
        for _ in pairs(state.slots[storage]) do count = count + 1 end
        return count
    end
    local util = {shellquote = function(value) return "'" .. value .. "'" end}
    function util.exec(command)
        local at = command:match(" %-D at '(.-)'")
        local body
        if at == "AT+QCCID" then
            state.sim_reads = state.sim_reads + 1
            local identity = state.swap_at and state.sim_reads >= state.swap_at and "8900000000000000002" or state.sim
            body = "+QCCID: " .. identity .. "\n\nOK\n"
        elseif at == "AT+CPMS=?" then
            local supported = state.no_me and '"SM"' or '"SM","ME"'
            body = "+CPMS: (" .. supported .. "),(" .. supported .. "),(" .. supported .. ")\nOK\n"
        elseif at == "AT+CPMS?" then
            body = string.format('+CPMS: "%s",%d,100,"SM",%d,100,"%s",%d,100\nOK\n',
                state.read, used(state.read), used("SM"), state.receive, used(state.receive))
        elseif at and at:match('^AT%+CPMS=') then
            local read, write, receive = at:match('^AT%+CPMS="(%w+)","(%w+)","(%w+)"$')
            read = read or at:match('^AT%+CPMS="(%w+)"$')
            assert(read, "unexpected CPMS command")
            state.read = read
            if receive and not state.ignore_receive then state.receive = receive end
            if write then equal(write, "SM", "sending storage must remain unchanged") end
            body = "OK\n"
        elseif at and at:match('^AT%+CMGR=') then
            local slot = tonumber(at:match("=(%d+)$"))
            local record = assert(state.slots[state.read][slot])
            if state.slot_reused then record.pdu = "00CC" end
            body = "+CMGR: 1,,2\n" .. record.pdu .. "\n\nOK\n"
        elseif at and at:match('^AT%+CMGD=') then
            check(state.verified, "cleanup requires durable archive readback")
            local slot = tonumber(at:match("=(%d+)$"))
            local current = assert(state.slots[state.read][slot])
            local saved = json.parse(assert(state.files[path]))
            local found = false
            for _, record in ipairs(saved.messages) do
                if record.pdu == current.pdu and record.storage == state.read and record.sim == state.sim then found = true end
            end
            check(found, "the exact PDU must already be archived")
            state.slots[state.read][slot] = nil
            state.deletions = state.deletions + 1
            body = "OK\n"
        elseif command:match(" %-j recv") then
            local storage = assert(command:match(" %-s (%u+)"))
            local list = {}
            for slot, record in pairs(state.slots[storage]) do
                local item = {}
                for name, value in pairs(record) do item[name] = value end
                item.index = slot
                list[#list + 1] = item
            end
            body = json.stringify({msg = list})
        else error("unexpected test command") end
        return body .. "\nSMS_TOOL_EXIT=0\n"
    end
    package.loaded["nixio"], package.loaded["nixio.fs"], package.loaded["luci.util"] = nixio, fs, util
    package.loaded["luci.model.uci"] = {cursor = function() return {get = function(_, _, _, key)
        if key == "readport" then return state.port or "/dev/ttyUSB-fixture" end
        if key == "storage" then return state.preferred end
        if key == "mergesms" then return "1" end
    end} end}
    return dofile(source), state
end
local function test(name, run)
    local ok, err = pcall(run)
    assert(ok, name .. ": " .. tostring(err))
    cases = cases + 1
end
test("persist both stores, release slots above 49, restart", function()
    local inbox, state = setup({short_writes = true})
    local status = inbox.collect()
    equal(state.deletions, 2)
    equal(status.receive_storage, "ME")
    local saved = json.parse(state.files[path])
    equal(#saved.messages, 2)
    equal(saved.next_id, 3)
    local public = inbox.snapshot()
    equal(public.messages[1].timestamp, "2026-10-10T12:00:00", "missing timezone data must not invent UTC")
    check(public.messages[1].pdu == nil and public.messages[1].sim == nil, "private originals must not be exposed")
    check(public.messages[1].released and public.messages[2].released)
    inbox = setup(state)
    inbox.collect()
    equal(#inbox.snapshot().messages, 2, "restart must preserve history")
    equal(state.deletions, 0, "empty modem must not cause repeat deletion")
end)
for _, failure in ipairs({"open", "write", "write_sync", "close", "rename", "file_sync", "directory_sync", "readback"}) do
    test("failure before cleanup: " .. failure, function()
        local inbox, state = setup({fail = failure})
        check(not pcall(inbox.collect), "save failure must stop collection")
        equal(state.deletions, 0, "save failure must never delete a modem message")
    end)
end
test("unchanged bytes still require successful sync", function()
    local inbox, state = setup({fail = "directory_sync"})
    check(not pcall(inbox.collect))
    local retained = state.files[path]
    check(retained ~= nil)
    check(not pcall(inbox.collect))
    equal(state.deletions, 0)
    equal(state.files[path], retained)
    state.fail = nil
    inbox.collect()
    equal(state.deletions, 2)
end)
test("corrupt archive remains untouched", function()
    for _, bytes in ipairs({"broken", '{"version":1,"next_id":2,"messages":{"lost":{}}}',
        '{"version":1,"next_id":2,"messages":[{"index":1,"pdu":"00"}]}'}) do
        local inbox, state = setup({files = {[path] = bytes}})
        check(not pcall(inbox.collect))
        equal(state.deletions, 0)
        equal(state.files[path], bytes)
    end
end)
for _, when in ipairs({2, 3}) do
    test("SIM swap before cleanup " .. when, function()
        local inbox, state = setup({swap_at = when})
        check(not pcall(inbox.collect))
        equal(state.deletions, 0)
        equal(#json.parse(state.files[path]).messages, 2)
    end)
end
test("reused slots remain on modem", function()
    local inbox, state = setup({slot_reused = true})
    check(inbox.collect().warning ~= nil)
    equal(state.deletions, 0)
    check(not inbox.snapshot().messages[1].released)
end)
test("decoding failure preserves original and modem message", function()
    local inbox, state = setup({slots = {SM = {[1] = message("00AA", {error = "decode failure"})}, ME = {}}})
    check(inbox.collect().warning ~= nil)
    equal(state.deletions, 0)
    equal(json.parse(state.files[path]).messages[1].pdu, "00AA")
    check(not pcall(inbox.delete_saved, "1"), "pending backup cannot be deleted")
end)
test("missing original stops cleanup", function()
    local inbox, state = setup({slots = {SM = {[1] = message(nil)}, ME = {}}})
    check(not pcall(inbox.collect))
    equal(state.deletions, 0)
end)
test("local deletion uses stable IDs and keeps new arrivals", function()
    local inbox, state = setup()
    inbox.collect()
    state.slots.ME[81] = message("00DD")
    inbox.collect()
    equal(#inbox.snapshot().messages, 3)
    local deletions = state.deletions
    inbox.delete_saved("1,2")
    local records = inbox.snapshot().messages
    equal(#records, 1)
    equal(records[1].index, 3)
    equal(state.deletions, deletions, "local deletion must not issue modem commands")
    check(not pcall(inbox.delete_saved, "1;command"))
end)
test("unsupported secondary store is not scanned", function()
    local inbox, state = setup({no_me = true, preferred = "SM", slots = {SM = {[1] = message("00AA")}, ME = {}}})
    inbox.collect()
    equal(state.deletions, 1)
end)
test("receiver change requires readback", function()
    local inbox = setup({ignore_receive = true})
    check(not pcall(inbox.collect))
end)
test("invalid port cannot execute a command", function()
    local inbox, state = setup({port = "/dev/ttyUSB2;command"})
    check(not pcall(inbox.collect))
    equal(state.sim_reads, 0)
end)
test("service-centre timezone is applied to old and new records", function()
    for _, fixture in ipairs({{"00", "+00:00"}, {"40", "+01:00"}, {"23", "+08:00"},
        {"48", "-01:00"}, {"0A", "-05:00"}, {"22", "+05:30"}, {"59", "-03:45"}}) do
        local pdu = "0000049121430008620190210000" .. fixture[1] .. "0C4E2D658790018D39FF1A00A3"
        local stamp = fixture[1] == "40" and "2026-10-10T12:00:00Z" or
            fixture[1] == "23" and "2026-10-10T12:00:00" or "2026-10-10 12:00:00"
        local inbox = setup({slots = {SM = {[1] = message(pdu, {timestamp = stamp})}, ME = {}}})
        inbox.collect()
        equal(inbox.snapshot().messages[1].timestamp, "2026-10-10T12:00:00" .. fixture[2])
    end
end)
print(string.format("SMS archive: %d cases, %d assertions passed; no real filesystem or modem operations", cases, checks))
