module("luci.controller.speedtest", package.seeall)
function index()
	local page
	entry({"admin", "speed"}, firstchild(), "Speed Test", 81).dependent=false
	page = entry({"admin", "speed", "speedtest"}, template("speedtest/speedtest"), "OpenSpeedTest", 71)
	page.dependent = true
end
