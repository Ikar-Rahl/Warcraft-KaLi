-- Numbers as the player's language writes them.
local T = KaLiHUDTests
local ns = KaLiHUDDev.ns
local Format, L = ns.Format, ns.L

T.Add("format", "thousands, decimals and percentages", function()
    T.Eq(Format.Number(1234567), "1" .. L.THOUSANDS .. "234" .. L.THOUSANDS .. "567", "thousands")
    T.Eq(Format.Number(999), "999", "under a thousand")
    T.Eq(Format.Number(-1500), "-1" .. L.THOUSANDS .. "500", "negative")
    T.Eq(Format.Decimal(40.26, 1), "40" .. L.DECIMAL .. "3", "decimal")
    T.Eq(Format.Percent(0.423), string.format(L.PERCENT, 42), "percent")
    T.Eq(Format.Coords(0.402, 0.428), "40" .. L.DECIMAL .. "2 · 42" .. L.DECIMAL .. "8", "coordinates")
    -- the game's own French puts a no-break space there; its fonts lack the narrow one (a square, Ikar 2026-11-15)
    T.Eq(L.THOUSANDS, ns.LOCALE == "frFR" and "\194\160" or ",", "a thousands separator the game's fonts draw")
end)

-- Each language's own rules (Ikar 2026-11-21: "with each language it own rules"): Castilian groups thousands as the
-- RAE does, by a space and from five figures; English from four, by a comma.
T.Add("format", "thousands as each language writes them: Castilian from five figures, by a space", function()
    local was = ns.LOCALE
    ns.LOCALE = "esES"
    local four, five = Format.Number(1500), Format.Number(12500)
    ns.LOCALE = "enUS"
    local english = Format.Number(1500)
    ns.LOCALE = was
    T.Eq(four, "1500", "Castilian: four figures, not grouped")
    T.Eq(five, "12\194\160500", "Castilian: five, a no-break space")
    T.Eq(english, "1,500", "English: four, a comma")
end)

T.Add("format", "short numbers", function()
    T.Eq(Format.Short(950), "950", "small")
    T.Eq(Format.Short(12400), "12" .. L.DECIMAL .. "4k", "thousands")
    T.Eq(Format.Short(2500000), "2" .. L.DECIMAL .. "5M", "millions")
end)

T.Add("format", "durations, and none for a time that never comes", function()
    T.Eq(Format.Duration(45), string.format(L.SECONDS, 45), "seconds")
    T.Eq(Format.Duration(125), string.format(L.MINUTES, 2), "minutes")
    T.Eq(Format.Duration(7500), string.format(L.HOURS_MINUTES, 2, 5), "hours")
    T.Eq(Format.Duration(nil), "?", "nil")
    T.Eq(Format.Duration(0 / 0), "?", "nan")
    T.Eq(Format.Duration(math.huge), "?", "inf")
    T.Eq(Format.Duration(-3), "?", "negative")
end)
