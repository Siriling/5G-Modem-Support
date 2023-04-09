--[[
luci-app-argon-config
]]--

module("luci.controller.splashset", package.seeall)

function index()
	if nixio.fs.access("/etc/config/splash") then
		entry({"admin", "theme", "splashset"}, cbi("splash"), _("Splash Screen"), 71)
	end
end
