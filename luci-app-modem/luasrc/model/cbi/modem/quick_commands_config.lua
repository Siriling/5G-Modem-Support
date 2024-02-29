-- Copyright 2024 Siriling <siriling@qq.com>

local dispatcher = require "luci.dispatcher"
local fs = require "nixio.fs"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

m = Map("modem")
m.title = translate("Custom quick commands")
m.description = translate("Customize your quick commands")
m.redirect = dispatcher.build_url("admin", "network", "modem","modem_debug")

-- 自定义命令 --
s = m:section(TypedSection, "custom-commands", translate("Custom Commands"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"

description = s:option(Value, "description", translate("Description"))
description.placeholder = translate("Not Null")
description.rmempty = true
description.optional = false

command = s:option(Value, "command", translate("Command"))
command.placeholder = translate("Not Null")
command.rmempty = true
command.optional = false

return m
