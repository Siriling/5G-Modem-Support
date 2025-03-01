

local sys   = require "luci.sys"
local zones = require "luci.sys.zoneinfo"
local fs    = require "nixio.fs"
local conf  = require "luci.config"

m = Map("iframe", "Splash Screen Configuration",translate("Change the configuration of the Splash and Login screen."))
m:chain("luci")
	
s = m:section(TypedSection, "iframe", "Status Page Configuration")
s.anonymous = true
s.addremove = false

c1 = s:option(ListValue, "splashpage", "Enable Network Status Page Before Login :");
c1:value("0", "Disabled")
c1:value("1", "Enabled")
c1.default=0

a1 = s:option(Value, "splashtitle", "Network Status Title :"); 
a1.optional=false;
a1.default = "ROOter Status"
a1:depends("splashpage", "1")

dc1 = s:option(ListValue, "dual", "Enable Modem 2 Status :");
dc1:value("0", "Disabled")
dc1:value("1", "Enabled")
dc1.default=0
dc1:depends("splashpage", "1")

cc1 = s:option(ListValue, "speed", "Enable OpenSpeedTest :");
cc1:value("0", "Disabled")
cc1:value("1", "Enabled")
cc1.default=0
cc1:depends("splashpage", "1")

ec1 = s:option(ListValue, "band", "Enable Bandwidth Summary :");
ec1:value("0", "Disabled")
ec1:value("1", "Enabled")
ec1.default=0
ec1:depends("splashpage", "1")

	
return m