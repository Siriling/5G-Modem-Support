-- QDC507 LTE masks include B66/B71 and exceed Lua's exact integer range.
local M = {}

function M.decode(mask, bands)
    assert(type(mask) == "string", "Missing LTE band mask")
    mask = mask:lower():gsub("^0x", "")
    assert(mask:match("^[0-9a-f]+$"), "Invalid LTE band mask")
    local result = {}
    for _, band in ipairs(bands) do
        local position = math.floor((band - 1) / 4)
        local digit = tonumber(mask:sub(-position - 1, -position - 1), 16) or 0
        result[#result + 1] = { ["B" .. band] = math.floor(digit / 2 ^ ((band - 1) % 4)) % 2 }
    end
    return result
end

function M.encode(selection, bands)
    assert(type(selection) == "table" and #selection > 0, "Select at least one LTE band")
    local allowed, digits, seen = {}, {}, {}
    for _, band in ipairs(bands) do allowed["B" .. band] = band end
    local selected, highest = 0, 0
    for _, item in ipairs(selection) do
        assert(type(item) == "table", "Invalid LTE band selection")
        for name, enabled in pairs(item) do
            local band = assert(allowed[name], "Unsupported LTE band: " .. tostring(name))
            assert(enabled == 0 or enabled == 1, "Invalid LTE band state")
            assert(not seen[name], "Duplicate LTE band: " .. name)
            seen[name] = true
            if enabled == 1 then
                local position = math.floor((band - 1) / 4)
                digits[position] = (digits[position] or 0) + 2 ^ ((band - 1) % 4)
                highest = math.max(highest, position)
                selected = selected + 1
            end
        end
    end
    assert(selected > 0, "Select at least one LTE band")
    local result = {}
    for position = highest, 0, -1 do result[#result + 1] = string.format("%x", digits[position] or 0) end
    return "0x" .. table.concat(result)
end

return M
