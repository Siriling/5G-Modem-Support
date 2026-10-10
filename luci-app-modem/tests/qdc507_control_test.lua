-- Run on OpenWrt with luci-base; no modem commands are sent by this test.
local control = arg[1] or '/usr/share/modem/baiwang_control.lua'
local json = require 'luci.jsonc'
local util = require 'luci.util'
local real_popen, real_print, real_exit, real_exec = io.popen, print, os.exit, util.exec
local checks = 0

local function run(action, payload, replies)
    local output, index, sleeps = nil, 0, 0
    arg = { action, '/dev/ttyUSB2', payload }
    io.popen = function(command)
        index = index + 1
        local reply = assert(replies[index], 'Unexpected AT command: ' .. command)
        assert(command:find(reply.command, 1, true), 'Wrong AT command: ' .. command)
        if reply.exclude then assert(not command:find(reply.exclude, 1, true), 'Unexpected AT argument') end
        return {
            read = function() return (reply.body or '') .. '\n__QDC507_STATUS:' .. (reply.status or '0') .. '\n' end,
            close = function() end
        }
    end
    print = function(value) output = json.parse(value) end
    os.exit = function(code) error('exit:' .. code) end
    util.exec = function(command) assert(command == 'sleep 1'); sleeps = sleeps + 1 end
    local ok, err = pcall(dofile, control)
    io.popen, print, os.exit, util.exec = real_popen, real_print, real_exit, real_exec
    assert(ok or tostring(err):find('exit:1', 1, true), tostring(err))
    assert(index == #replies, 'Missing AT commands')
    return assert(output), sleeps
end

local mode = '+QCFG: "nwscanmodeex",16\r\n'
local result, sleeps = run('set_network', '{"4G":{"enable":1}}', {
    {command='AT+QCFG="nwscanmodeex"', body=mode},
    {command='AT+QCFG="nwscanmodeex"', body=mode}
})
assert(result.success and sleeps == 0); checks = checks + 1

result, sleeps = run('set_network', '{"2G":{"enable":1},"3G":{"enable":1},"4G":{"enable":1}}', {
    {command='AT+QCFG="nwscanmodeex"', body=mode},
    {command='AT+QCFG="nwscanmodeex",28', exclude=',28,1'},
    {command='AT+QCFG="nwscanmodeex"', body=mode},
    {command='AT+QCFG="nwscanmodeex"', body='+QCFG: "nwscanmodeex",28\r\n'},
    {command='AT+CFUN=0'}, {command='AT+CFUN=1'}
})
assert(result.success and sleeps == 1); checks = checks + 1

result = run('set_band', '{"4G":{"enable":1,"band":[{"B3":1}]}}', {
    {command='AT+QCFG="band"', body='+QCFG: "band",0xbff,0x42000001e20b0e18df,0x0\r\n'},
    {command='AT+QCFG="band",bff,4,0,1', exclude='0x'},
    {command='AT+QCFG="band"', body='+QCFG: "band",0xbff,0x4,0x0\r\n'},
    {command='AT+CFUN=0'}, {command='AT+CFUN=1'}
})
assert(result.success); checks = checks + 1

result = run('get', nil, {{command='AT+QCFG="nwscanmodeex"', status='1'}})
assert(result.success == false and result.error:find('Modem rejected', 1, true)); checks = checks + 1
result = run('set_network', '{"5G":{"enable":1}}', {})
assert(result.success == false); checks = checks + 1
result = run('set_band', '{"4G":{"enable":1,"band":[]}}', {})
assert(result.success == false); checks = checks + 1
real_print('QDC507 control tests passed: ' .. checks)
