-- Licensed to the public under the Apache License 2.0.

module("luci.controller.blockport", package.seeall)

function index()
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
	if lock == "1" then
		local page
		page = entry({"admin", "adminmenu", "blockport"}, cbi("portblk"), _("---Port Blocking"), 10)
		page.dependent = true
	end
end
