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
    for spec in (s:gsub("%%%%", "")):gmatch("%%[-+#0-9.]*[A-Za-z]") do
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
    -- One of Castilian's strings Mexican Spanish has no word of its own for, whichever the addon has.
    local common
    for key, value in pairs(ns.STRINGS.esES) do
        if type(value) == "string" and rawget(ns.STRINGS.esMX, key) == nil then
            common = key
            break
        end
    end
    T.Eq(common ~= nil and ns.StringsFor("esMX")[common], common ~= nil and ns.STRINGS.esES[common],
        "Mexican Spanish: Castilian's where it has no word of its own")
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

-- Each language's own typography (Ikar 2026-11-21: "make the translation correct in each language, with each language
-- it own rules"), as the player gets each string, its file's rules put in: French a no-break space before : ; ? ! and
-- », after «, and before %, its apostrophe and quotes « »; English quotes " ", no space before %; German „ ", Spanish
-- « » and an opening ¿ and ¡ for each ? and !, both a no-break space before %. Written in bytes: this file stays ASCII.
local OPEN_FR, CLOSE_FR = "\194\171", "\194\187"
local LOW, HIGH_OPEN, HIGH_CLOSE = "\226\128\158", "\226\128\156", "\226\128\157"

local function count(s, mark)
    local n, at = 0, 1
    while true do
        local i = s:find(mark, at, true)
        if not i then
            return n
        end
        n, at = n + 1, i + #mark
    end
end

-- A plain space before a percent sign, in text ("100 %") or in a format ("%d %%").
local function spaceBeforePercent(s)
    return s:find("%d %%") or s:find("%%[%-%d%.]*[A-Za-z] %%%%")
end

local RULES = {
    frFR = function(s)
        for _, mark in ipairs({ " :", " ;", " ?", " !", " " .. CLOSE_FR, OPEN_FR .. " " }) do
            if s:find(mark, 1, true) then
                return "a plain space at \"" .. mark .. "\""
            end
        end
        if spaceBeforePercent(s) then
            return "a plain space before %"
        elseif s:find("[A-Za-z]'[A-Za-z]") then
            return "a straight apostrophe"
        elseif s:find('"', 1, true) or count(s, OPEN_FR) ~= count(s, CLOSE_FR) then
            return "quotes not in pairs of French ones"
        end
    end,
    enUS = function(s)
        if spaceBeforePercent(s) then
            return "a space before %"
        elseif s:find('"', 1, true) or s:find(LOW, 1, true) or s:find(OPEN_FR, 1, true)
            or count(s, HIGH_OPEN) ~= count(s, HIGH_CLOSE) then
            return "quotes not in pairs of English ones"
        end
    end,
    deDE = function(s)
        if spaceBeforePercent(s) then
            return "a plain space before %"
        elseif s:find('"', 1, true) or s:find(HIGH_CLOSE, 1, true) or count(s, LOW) ~= count(s, HIGH_OPEN) then
            return "quotes not in pairs of German ones"
        end
    end,
    esES = function(s)
        if spaceBeforePercent(s) then
            return "a plain space before %"
        elseif s:find('"', 1, true) or s:find(HIGH_OPEN, 1, true) or count(s, OPEN_FR) ~= count(s, CLOSE_FR) then
            return "quotes not in pairs of Spanish ones"
        elseif count(s, "?") ~= count(s, "\194\191") or count(s, "!") ~= count(s, "\194\161") then
            return "a ? or ! without its opening mark"
        end
    end,
}
RULES.esMX = RULES.esES

T.Add("Locale", "each language follows its own typography, as the player gets its strings", function()
    local problems = {}
    local function walk(t, path, rule)
        for key, value in pairs(t) do
            if type(value) == "table" then
                walk(value, path .. "." .. tostring(key), rule)
            elseif type(value) == "string" then
                local why = rule(value)
                if why then
                    problems[#problems + 1] = path .. "." .. tostring(key) .. ": " .. why
                end
            end
        end
    end
    for _, locale in ipairs(LANGUAGES) do
        if type(ns.STRINGS[locale]) == "table" then
            walk(ns.STRINGS[locale], locale, RULES[locale])
        end
    end
    table.sort(problems)
    T.Eq(table.concat(problems, "\n"), "", "what breaks its language's typography")
end)

-- The mouse buttons as the house editor's icons, never in words (Ikar 2026-11-17 for KaLi HUD: "Replace all click
-- gauche and droit text by the new icon"; 2026-11-21 for every addon: "About icons, yes. As much as possible."). The
-- plain noun in a sentence ("un clic sur le suivi") stays.
local CLICK_WORDS = {
    frFR = { "[Cc]lic droit", "[Cc]lic gauche", "Clic :", "Clic\194\160:", "Cliquer pour" },
    enUS = { "[Rr]ight%-click", "[Ll]eft%-click", "Click:", "Click to " },
    deDE = { "Rechtsklick", "Linksklick", "Klick:", "Klicken zum", "Klicken, um" },
    esES = { "[Cc]lic derecho", "[Cc]lic izquierdo", "Clic:", "Clic para" },
}
CLICK_WORDS.esMX = CLICK_WORDS.esES

T.Add("Locale", "no language names a mouse button in words: the house editor's icons stand for them", function()
    local problems = {}
    local function walk(t, path, words)
        for key, value in pairs(t) do
            if type(value) == "table" then
                walk(value, path .. "." .. tostring(key), words)
            elseif type(value) == "string" then
                for _, word in ipairs(words) do
                    if value:find(word) then
                        problems[#problems + 1] = path .. "." .. tostring(key) .. ": " .. word
                    end
                end
            end
        end
    end
    for _, locale in ipairs(LANGUAGES) do
        if type(ns.STRINGS[locale]) == "table" then
            walk(ns.STRINGS[locale], locale, CLICK_WORDS[locale])
        end
    end
    table.sort(problems)
    T.Eq(table.concat(problems, "\n"), "", "a mouse button in words")
end)

T.Add("Locale", "Mexican Spanish writes a decimal with a point, in every string a Mexican player gets", function()
    local problems = {}
    local mexican, castilian = ns.STRINGS.esMX, ns.STRINGS.esES
    if type(mexican) == "table" and type(castilian) == "table" then
        local keys = {}
        for key in pairs(castilian) do
            keys[key] = true
        end
        for key in pairs(mexican) do
            keys[key] = true
        end
        for key in pairs(keys) do
            local value = mexican[key]
            if type(value) == "string" and value:find("%d,%d") then
                problems[#problems + 1] = "esMX." .. tostring(key)
            end
        end
    end
    table.sort(problems)
    T.Eq(table.concat(problems, ", "), "", "a decimal comma in Mexican Spanish")
end)

T.Add("Locale", "a chat line's colon is the game's, in the player's language", function()
    local was = HEADER_COLON
    HEADER_COLON = "\194\160:"
    local french = ns.Colon()
    HEADER_COLON = ":"
    local other = ns.Colon()
    HEADER_COLON = was
    T.Eq(french, "\194\160:", "the French client's: after a no-break space")
    T.Eq(other, ":", "the others': alone")
end)

T.Add("Locale", "the singular: 1 alone, in each language the addon speaks", function()
    T.Eq(tostring(ns.One(0)) .. "/" .. tostring(ns.One(1)) .. "/" .. tostring(ns.One(2)), "false/true/false", "0, 1 and 2")
end)
