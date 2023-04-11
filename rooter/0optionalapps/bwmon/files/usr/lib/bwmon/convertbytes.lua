#!/usr/bin/lua

bytes=arg[1]

function ltrim(s)
  return s:match'^%s*(.*)'
end

function calc(total)
	if total < 1000000 then
		tstr = string.format("%.2f", total)
		tstr = string.format("%.2f", total/1000)
		tfm = " K"
	else
		if total < 1000000000 then
			tstr = string.format("%.2f", total/1000000)
			tfm = " MB"
		else
			tstr = string.format("%.2f", total/1000000000)
			tfm = " GB"
		end
	end
	str = tstr .. tfm
	return ltrim(str)
end

conbytes = "BYTES='" .. calc(tonumber(bytes)) .. "'"
tfile = io.open("/tmp/bytes", "w")
tfile:write(conbytes, "\n")
tfile:close()