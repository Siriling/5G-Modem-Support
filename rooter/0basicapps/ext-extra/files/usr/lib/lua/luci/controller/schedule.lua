-- Licensed to the public under the Apache License 2.0.

module("luci.controller.schedule", package.seeall)

function index()
	local page
	page = entry({"admin", "services", "schedule"}, cbi("schedule"), _("Scheduled Reboot"), 61)
	page.dependent = true
end
