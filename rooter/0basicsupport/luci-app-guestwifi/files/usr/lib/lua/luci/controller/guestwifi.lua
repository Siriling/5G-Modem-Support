module("luci.controller.guestwifi", package.seeall)

function index()
	local page
	if not nixio.fs.access("/etc/config/wireless") then
		return
	end
	
	page = entry({"admin", "network", "guestwifi"}, cbi("guestwifi", {hidesavebtn=true, hideresetbtn=true}), "Guest Wifi", 22)
	page.dependent = true
	entry( {"admin", "network", "guestwifi", "edit"},    cbi("guestwifi-edit"),    nil ).leaf = true
	
	entry({"admin", "network", "createwifi"}, call("action_createwifi"))
end

function action_createwifi()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/guestwifi/create.sh " .. set)
end