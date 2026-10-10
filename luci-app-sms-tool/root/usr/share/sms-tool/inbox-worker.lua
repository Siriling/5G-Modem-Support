#!/usr/bin/lua
-- Copyright (C) 2026 ainuoyan; GNU General Public License v3.
local inbox = require "luci.model.sms_tool.inbox"
local json = require "luci.jsonc"
local action = arg[1]
local ok, result = pcall(function()
    if action == "collect" then return inbox.collect() end
    if action == "delete" then return inbox.delete_saved(arg[2]) end
    error("未知短信操作")
end)
if not ok then
    result = {ok = false, error = tostring(result):gsub("^.-:%d+: ", "")}
    if action == "collect" then pcall(inbox.set_status, result) end
end
if action ~= "collect" then io.write(json.stringify(result), "\n") end
os.exit(ok and 0 or 1)
