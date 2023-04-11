#!/usr/bin/lua

monthly = '/usr/lib/bwmon/data/monthly.data'
datafile='/tmp/bwmon/bwdata/daily.js'
monline = {}
monlist = {}

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

local function bubblesort(a)
  repeat
    local swapped = false
    for i = 1, table.getn(a) do
      if a[i - 1] < a[i] then
        a[i], a[i - 1] = a[i - 1], a[i]
        swapped = true
      end -- if
    end -- for
  until swapped == false
end

function ConBytes(line)
	local s, e, bs, be
	s, e = line:find(" ")
	bs, be = line:find("K", e+1)
	if bs == nil then
		bs, be = line:find("MB", e+1)
		if bs == nil then
			val = tonumber(line:sub(1, e-1)) * 1000000000
		else
			val = tonumber(line:sub(1, e-1)) * 1000000
		end
	else
		val = tonumber(line:sub(1, e-1)) * 1000
	end
	return val
end

kdwn = 0
kup = 0
ktotal = 0
file = io.open(datafile, "r")
if file ~= nil then
	total = file:read("*line")
	dwn = file:read("*line")
	up = file:read("*line")
	lin = file:read("*line")
	file:close()
	kdwn = tonumber(dwn)
	kup = tonumber(up)
	ktotal = tonumber(total)
	dwn = calc(tonumber(dwn))
	up = calc(tonumber(up))
	total = calc(tonumber(total))
	print(ktotal, kdwn, kup)
	dataline = lin .. "|" .. dwn .. "|" .. up .. "|" .. total
	print(dataline)
	monline[lin] = dataline
	monlist[0] = lin
	ksize = 1
end
k = 1
tfile = io.open(monthly, "r")
if tfile ~= nil then
	ksize = tfile:read("*line")
	ksize = tostring(tonumber(ksize) + 1)
	kdwn1 = tfile:read("*line")
	kdwn1=ConBytes(kdwn1)
	kdwn = (kdwn1 + kdwn)
	kup1 = tfile:read("*line")
	kup1=ConBytes(kup1)
	kup = (kup1 + kup)
	ktotal1 = tfile:read("*line")
	ktotal1=ConBytes(ktotal1)
	ktotal = (ktotal1 + ktotal)
	repeat
		line = tfile:read("*line")
		if line == nil then
			break
		end
		s, e = line:find("|")
		ymd = line:sub(1, s-1)
		monline[ymd] = line
		monlist[k] = ymd
		k = k + 1
	until 1==0
	tfile:close()
	bubblesort(monlist)
end
if k > 30 then
	k = 30
end

tfile = io.open(monthly, "w")
tfile:write(tostring(k), "\n")
tfile:write(calc(kdwn), "\n")
tfile:write(calc(kup), "\n")
tfile:write(calc(ktotal), "\n")
for j = 0,k-1
do
	lin = monlist[j]
	dataline = monline[lin]
	print(dataline)
	tfile:write(dataline, "\n")
end
tfile:close()
--os.execute("uci set custom.bwday.bwday=" .. calc(ktotal) .. ";uci commit custom")
