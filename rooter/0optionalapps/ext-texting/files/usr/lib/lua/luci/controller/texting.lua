module("luci.controller.texting", package.seeall)
function index()
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
	if lock == "1" then
		entry({"admin", "adminmenu", "texting"}, cbi("fullmenu/texting"), "---Random Texting", 8)
	end
	
	entry({"admin", "services", "chksms"}, call("action_chksms"))
end

function action_chksms()
	local rv = {}
	os.execute("/usr/lib/fullmenu/chksms.sh")
	file = io.open("/tmp/texting", "r")
	if file ~= nil then
		rv["sms"] = "1"
		file:close()
	else
		rv["sms"] = "0"
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end