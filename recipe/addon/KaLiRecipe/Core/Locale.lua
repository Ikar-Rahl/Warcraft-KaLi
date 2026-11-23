-- Names shown to the player. The game's own strings come first, through ns.G, so they translate themselves. The
-- rest are the addon's, one language a file under Locale/ (Ikar 2026-11-21: "each language in it own file"):
-- French first, English, German, Spanish (Castilian, and Mexican as Castilian but for the game's own Mexican words).
-- Other languages fall back to English. Each translation keeps English's blanks (%s, %d) in English's order: the
-- tests check it, since the offline Lua has no positional %1$s. Each language's file puts its own typography in as
-- its strings load (ns.Typeset). This file loads first; the languages' files after it, before any other.
local _, ns = ...

ns.LOCALE = GetLocale and GetLocale() or "enUS"

-- The house editor's mouse icons (Blizzard_HouseEditor's hints) in place of the words left click and right click,
-- as KaLi HUD (Ikar 2026-11-21: "About icons, yes. As much as possible."), at 16, the size Blizzard gives a mouse
-- button in a line of text.
ns.MOUSE_ATLAS = { left = "housing-hotkey-icon-leftclick", right = "housing-hotkey-icon-rightclick" }
ns.LEFT_CLICK = "|A:" .. ns.MOUSE_ATLAS.left .. ":16:16|a"
ns.RIGHT_CLICK = "|A:" .. ns.MOUSE_ATLAS.right .. ":16:16|a"

-- Each language's strings, which its file under Locale/ adds (the tests hold every one against English's).
local OWN = {}
ns.STRINGS = OWN

-- A language's own typography, put in by its file as its strings load, so the files keep plain spaces and straight
-- apostrophes, easy to read and to write: rule(text) gives the text as the language prints it. The game's fonts have
-- the no-break space, not the narrow one.
ns.NBSP = "\194\160"
function ns.Typeset(strings, rule)
    for key, value in pairs(strings) do
        if type(value) == "string" then
            strings[key] = rule(value)
        elseif type(value) == "table" then
            ns.Typeset(value, rule)
        end
    end
    return strings
end


-- A client language's own strings: its table, or English's for a language without one (enGB among them).
function ns.StringsFor(locale)
    return OWN[locale] or OWN.enUS
end

-- Read when used, so the languages' files, loaded after this one, are there.
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = ns.StringsFor(ns.LOCALE)[key]
        if v == nil then
            v = OWN.enUS[key]
        end
        return v ~= nil and v or key
    end,
})

-- A game string by its global name, with a fallback for when it's missing.
function ns.G(name, fallback)
    local v = _G[name]
    return type(v) == "string" and v or fallback
end

-- Whether a count n takes the singular: 1 alone, in each language the addon speaks (French's « 0 vues » is tested).
-- The one place a language with more forms, such as Russian, would change.
function ns.One(n)
    return n == 1
end

-- "%d vue" or "%d vues": the form for n, filled in.
function ns.Plural(n, one, many)
    return string.format(ns.One(n) and one or many, n)
end

-- Sorting and searching that ignore case and accents, so "Éruption" sorts among the E's. Lowercasing is done by
-- hand: string.lower and %u follow the C library's locale, which may not be UTF-8.
local FOLD = {}
for letters, base in pairs({
    ["àáâãäåÀÁÂÃÄÅ"] = "a", ["çÇ"] = "c", ["èéêëÈÉÊË"] = "e", ["ìíîïÌÍÎÏ"] = "i", ["ñÑ"] = "n",
    ["òóôõöÒÓÔÕÖ"] = "o", ["ùúûüÙÚÛÜ"] = "u", ["ýÿÝ"] = "y", ["æÆ"] = "ae", ["œŒ"] = "oe", ["ß"] = "ss",
    ["’‘"] = "'",
}) do
    for ch in letters:gmatch("[\194-\244][\128-\191]*") do
        FOLD[ch] = base
    end
end
for byte = 65, 90 do
    FOLD[string.char(byte)] = string.char(byte + 32)
end

function ns.Fold(s)
    return (tostring(s or ""):gsub("[\194-\244][\128-\191]*", FOLD):gsub("[A-Z]", FOLD))
end

function ns.TextLess(a, b)
    local ka, kb = ns.Fold(a), ns.Fold(b)
    if ka ~= kb then
        return ka < kb
    end
    return a < b
end
