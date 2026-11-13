-- Copied from shared/tests/Locales.lua by tools/sync_shared.py: edit the source, not this copy.
-- Every language an addon speaks holds each of its English strings, with English's blanks in English's order, so a
-- translation can neither make string.format fail nor fill a blank with the wrong thing. The offline Lua, like
-- Lua 5.1, has no positional %1$s, so the order has to be English's. Loaded after the harness by each <Addon>_Tests.
local ADDON = ...
local BASE = (ADDON:gsub("_Tests$", ""))
local T = _G[BASE .. "Tests"]
local ns = _G[BASE .. "Dev"].ns

-- The languages the addons speak, as GetLocale names them (2026-11-13: German and Spanish after French and English).
local LANGUAGES = { "frFR", "enUS", "deDE", "esES", "esMX" }

-- A string's blanks, in order: %s, %d, %.1f and the like; a literal %% is none. "100 %" is none either: a flag
-- space isn't taken, so "Bei 100 % hat" holds no "% h".
local function blanks(s)
    local out = {}
    for spec in (s:gsub("%%%%", "")):gmatch("%%[-+#0-9.]*%a") do
        out[#out + 1] = spec
    end
    return table.concat(out, " ")
end

local function compare(english, other, path, problems)
    if type(english) == "table" then
        if type(other) ~= "table" then
            problems[#problems + 1] = path .. " isn't a list, as English's is"
            return
        end
        for key, value in pairs(english) do
            compare(value, other[key], path .. "." .. tostring(key), problems)
        end
    elseif type(other) ~= "string" or other == "" then
        problems[#problems + 1] = path .. " is missing"
    elseif blanks(other) ~= blanks(english) then
        problems[#problems + 1] = string.format("%s has the blanks \"%s\", English \"%s\"", path, blanks(other),
            blanks(english))
    end
end

-- What a language has that English doesn't: a misspelt key, never shown.
local function extra(english, other, path, problems)
    if type(english) ~= "table" or type(other) ~= "table" then
        return
    end
    for key, value in pairs(other) do
        if english[key] == nil then
            problems[#problems + 1] = path .. "." .. tostring(key) .. " isn't one of English's"
        else
            extra(english[key], value, path .. "." .. tostring(key), problems)
        end
    end
end

T.Add("Locale", "every language has each English string, with the same blanks in the same order", function()
    local english = ns.STRINGS.enUS
    local problems = {}
    for _, locale in ipairs(LANGUAGES) do
        local own = ns.STRINGS[locale]
        if type(own) ~= "table" then
            problems[#problems + 1] = locale .. " has no strings"
        else
            compare(english, own, locale, problems)
            extra(english, own, locale, problems)
        end
    end
    T.Eq(table.concat(problems, "\n"), "", "what doesn't match English")
end)

T.Add("Locale", "a client language picks its strings, Mexican Spanish Castilian's but for its own words, others English's", function()
    T.Eq(ns.StringsFor("deDE"), ns.STRINGS.deDE, "German")
    T.Eq(ns.StringsFor("esMX").OPTIONS, ns.STRINGS.esES.OPTIONS, "Mexican Spanish: Castilian's where it has no word of its own")
    T.Eq(ns.StringsFor("ptBR"), ns.STRINGS.enUS, "a language without strings: English")
    T.Eq(ns.StringsFor("enGB"), ns.STRINGS.enUS, "British English: English")
    local same = {}
    for key, value in pairs(ns.STRINGS.esMX) do
        if value == ns.STRINGS.esES[key] then
            same[#same + 1] = key
        end
    end
    T.Eq(table.concat(same, ", "), "", "each Mexican string says something Castilian's doesn't")
end)

T.Add("Locale", "the singular: 1 alone, in each language the addon speaks", function()
    T.Eq(tostring(ns.One(0)) .. "/" .. tostring(ns.One(1)) .. "/" .. tostring(ns.One(2)), "false/true/false", "0, 1 and 2")
end)
