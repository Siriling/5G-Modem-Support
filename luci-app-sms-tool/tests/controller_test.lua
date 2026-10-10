-- Copyright (C) 2026 ainuoyan; GNU General Public License v3.
-- Captures commands only; does not execute or send SMS.
local quote = require("luci.util").shellquote
local json = require "luci.jsonc"
local commands, form, written, status = {}, {}, nil, nil
local worker_result
local port = "/dev/ttyUSB-fixture"
package.loaded["luci.util"] = {shellquote = quote, exec = function(command)
    commands[#commands + 1] = command
    if command:find("inbox-worker.lua delete", 1, true) then return worker_result end
    return "fixture output"
end}
package.loaded["nixio.fs"] = {}
package.loaded["luci.sys"] = {}
package.loaded["luci.dispatcher"] = {}
package.loaded["luci.http"] = {formvalue = function(key) return form[key] end,
    write = function(value) written = value end,
    status = function(code) status = code end, prepare_content = function() end,
    write_json = function(value) written = value end}
package.loaded["luci.model.uci"] = {cursor = function() return {get = function(_, _, _, key)
    if key:match("port$") then return port end
    return "0"
end} end}
luci.model = luci.model or {}
luci.model.uci = package.loaded["luci.model.uci"]
dofile(assert(arg[1]))
local controller = require "luci.controller.modem.sms"
form.code = 'AT+CPMS="ME"; $(fixture)'
controller.at()
assert(commands[1]:find("flock -n '" .. "/var/lock/modem-at-ttyUSB-fixture.lock'", 1, true))
assert(commands[1]:find(" at " .. quote(form.code), 1, true))
assert(written == "fixture output")
form.code = "*123#"
controller.ussd()
assert(commands[2]:find(" ussd " .. quote(form.code), 1, true))
form.scode = string.format("%-20s", "12345") .. "fixture's text\nsecond line"
controller.sms()
assert(commands[3]:find(" send '12345' " .. quote("fixture's text second line"), 1, true))
port = "/dev/ttyUSB-fixture;command"
controller.at()
assert(#commands == 3 and written:find("有效"))
form.scode = nil
controller.sms()
assert(#commands == 3)

form.ids = "1,2"
worker_result = json.stringify({ok = true})
controller.delete_saved()
assert(commands[4]:find("flock -n /var/lock/sms-tool-inbox.lock", 1, true))
assert(commands[4]:find("inbox-worker.lua delete " .. quote(form.ids), 1, true))
assert(written.ok == true, "valid local deletion must return the worker result")
form.ids = "1;fixture"
controller.delete_saved()
assert(#commands == 4 and status == 400, "invalid IDs must never reach a command")
form.ids = string.rep("1", 8193)
controller.delete_saved()
assert(#commands == 4 and status == 400, "oversized requests must not reach a command")
form.ids, worker_result = "1", ""
controller.delete_saved()
assert(#commands == 5 and status == 409 and written.ok == false,
    "a busy collector must return a visible conflict without deleting a modem slot")
print("SMS controller: 13 assertions passed; commands captured only")
