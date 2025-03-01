module("luci.controller.blacklist", package.seeall)

function index()
	local page
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
	if lock == "1" then
		page = entry({"admin", "adminmenu", "blacklist"}, cbi("blacklist"), "---Blacklist by Mac", 10)
		page.dependent = true
	end
end
