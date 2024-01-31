-- Copyright 2020-2021 Rafa� Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

local dispatcher = require "luci.dispatcher"
local fs = require "nixio.fs"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

local AT_FILE_PATH = "/etc/modem/custom_at_commands.json"

m = Map("sms_tool")
m.title = translate("Configuration sms-tool")
m.description = translate("Configuration panel for sms_tool and gui application.")

-- 自定义命令 --
s = m:section(TypedSection, "custom_at_commands", translate("Custom AT Commands"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"

description = s:option(Value, "description", translate("Description"))
description.placeholder = ""
description.rmempty = false
description.optional = false

command = s:option(Value, "command", translate("Command"))
-- command.placeholder = ""
command.rmempty = false
-- command.optional = false

function command.cfgvalue(self, section)
	local custom_commands=fs.readfile(AT_FILE_PATH)
    return "模组信息 > ATI"
end

-- RAW File --
s = m:section(NamedSection, 'general' , "sms_tool" , translate(""))
s.anonymous = true

local tat = s:option(TextValue, "user_at", translate("User AT Commands"), translate("Each line must have the following format: 'AT Command name;AT Command'. Save to file '/etc/config/atcmds.user'."))
tat.rows = 20
tat.rmempty = true

function tat.cfgvalue(self, section)
    return fs.readfile(AT_FILE_PATH)
end

function tat.write(self, section, value)
	value = value:gsub("\r\n", "\n")
	fs.writefile(AT_FILE_PATH, value)
end

return m
