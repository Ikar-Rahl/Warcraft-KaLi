-- Numbers as the player's language writes them: decimals, thousands, percentages, durations. No game call but the
-- locale's strings, so the tests run it as it is.
local _, ns = ...

local Format = {}
ns.Format = Format

local floor, abs = math.floor, math.abs

-- 1234567 -> "1 234 567" in French, "1,234,567" in English; grouped from the language's THOUSANDS_FROM figures
-- (Castilian's five, as the RAE writes them: 1500, 12 500).
function Format.Number(n)
    n = floor(n + 0.5)
    local s = tostring(abs(n))
    if #s < (tonumber(ns.L.THOUSANDS_FROM) or 4) then
        return (n < 0 and "-" or "") .. s
    end
    local parts = {}
    local first = #s % 3
    if first > 0 then
        parts[1] = s:sub(1, first)
    end
    for i = first + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return (n < 0 and "-" or "") .. table.concat(parts, ns.L.THOUSANDS)
end

-- 40.25 -> "40,3" in French.
function Format.Decimal(v, places)
    local s = string.format("%." .. (places or 1) .. "f", v)
    return (s:gsub("%.", ns.L.DECIMAL))
end

-- 12400 -> "12,4k"; 2500000 -> "2,5M"; below 1000 as it is.
function Format.Short(n)
    local a = abs(n)
    if a >= 1e6 then
        return Format.Decimal(n / 1e6, 1) .. "M"
    elseif a >= 1e4 then
        return Format.Decimal(n / 1e3, 1) .. "k"
    end
    return Format.Number(n)
end

-- 0.423 -> "42 %" in French.
function Format.Percent(fraction)
    return string.format(ns.L.PERCENT, floor(fraction * 100 + 0.5))
end

-- A percentage given as one, with decimals: 12.46 -> "12,5 %" in French (the character sheet's one place).
function Format.PercentOf(value, places)
    return (ns.L.PERCENT:gsub("%%d", "%%s")):format(Format.Decimal(value, places or 1))
end

-- Seconds as "2 h 05", "12 min", "45 s"; nil or a negative or endless time as "?".
function Format.Duration(seconds)
    if not ns.Finite(seconds) or seconds < 0 then
        return "?"
    end
    local L = ns.L
    if seconds >= 3600 then
        local h = floor(seconds / 3600)
        if h >= 100 then
            return string.format(L.HOURS, h)
        end
        return string.format(L.HOURS_MINUTES, h, floor(seconds % 3600 / 60))
    elseif seconds >= 60 then
        return string.format(L.MINUTES, floor(seconds / 60))
    end
    return string.format(L.SECONDS, floor(seconds))
end

-- Map coordinates (0..1) as the map shows them: "40,2 · 42,8".
function Format.Coords(x, y)
    return Format.Decimal(x * 100, 1) .. " · " .. Format.Decimal(y * 100, 1)
end
