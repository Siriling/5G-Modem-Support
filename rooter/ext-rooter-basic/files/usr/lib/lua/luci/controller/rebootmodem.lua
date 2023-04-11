module("luci.controller.rebootmodem", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
        local page
		local multilock = uci:get("custom", "multiuser", "multi") or "0"
		local rootlock = uci:get("custom", "multiuser", "root") or "0"
		if (multilock == "0") or (multilock == "1" and rootlock == "1") then
			page = entry({"admin", "system", "rebootmodem"}, template("admin_system/rebootmodem"), _(translate("Reboot")), 93)
			page.dependent = true
		else
			page = entry({"admin", "system", "rebootmodem"}, template("admin_system/rebootmodem"), _(translate("Restart Router")), 93)
			page.dependent = true
		end
		entry({"admin", "system", "do_reboot"}, call("action_doreboot"))
end

function action_doreboot()
     os.execute("/usr/lib/rooter/luci/rebootmodem.sh")
end