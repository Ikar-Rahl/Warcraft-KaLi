-- The Edit Mode dialog's styles (UI/EditPanel.lua), each a minimap ring and a colour (Ikar 2026-11-16: "presets ...
-- centered around a minimap style, and a color"), in the menu's order. Each sets the look alone, never a size, a
-- margin, an opacity or what a bar shows, so no style moves anything. The first is the defaults' (Ikar 2026-11-17:
-- the defaults "blizard"), Core/DB.lua's DB.DEFAULTS holding the same values.
-- Its border colours are taken from its ring's own metal, its highlights (MinimapRing*.tga, sampled 2026-11-16).
-- The cartouches marked "stand-in": none in the style's colour yet, the nearest until Ikar's own (2026-11-17: "wait
-- for the dedicated ones"); Forest's and Rune's their own (the same day), Steampunk's and Silver's (2026-11-18: "Two
-- new cartouche, the first for steampunk, second for the silver"), Golden's and Astronomy's (the same day: "I added
-- arts for the gold and the astronomy version").
local _, ns = ...

-- What a style sets, in the order its question names them.
ns.PRESET_KEYS = { "minimapRing", "borderColor", "bgColor", "bgStyle", "foldArt", "cornerStyle" }

ns.PRESETS = {
    -- copper; the cartouche a stand-in
    { id = "blizzard", minimapRing = "blizzard", borderColor = "c4977c", bgColor = "4a3a2a", bgStyle = "stone",
        foldArt = "bronze1", cornerStyle = "round" },
    { id = "steel", minimapRing = "steel", borderColor = "c9cdd1", bgColor = "2a2c2e", bgStyle = "darkstone",
        foldArt = "silver", cornerStyle = "bevel" },
    { id = "golden", minimapRing = "golden", borderColor = "c8ad7f", bgColor = "3b3026", bgStyle = "marble",
        foldArt = "golden", cornerStyle = "round" },
    -- green, the ring's verdigris
    { id = "forest", minimapRing = "forest", borderColor = "a0b4a8", bgColor = "2e3324", bgStyle = "wood",
        foldArt = "forest", cornerStyle = "round" },
    -- taupe
    { id = "rune", minimapRing = "rune", borderColor = "9a8b74", bgColor = "4a4036", bgStyle = "masonry",
        foldArt = "rune", cornerStyle = "bevel" },
    -- bronze, the border's dark bronze, the defaults' until 2026-11-17
    { id = "steampunk", minimapRing = "steampunk", borderColor = "aa9273", bgColor = "3b3026", bgStyle = "leather",
        foldArt = "steampunk", cornerStyle = "bevel" },
    -- pink and gold; the cartouche its own since 2026-11-18 (Ikar: "4th for the gem"), the Ornate 1 in gold before; the
    -- background a light old rose, its art's colours, since 2026-11-19 (Ikar: "much clearer"), a dark bordeaux before
    { id = "gem", minimapRing = "gem", borderColor = "c9a08f", bgColor = "5e4a48", bgStyle = "marble",
        foldArt = "gem", cornerStyle = "bevel" },
    -- blue
    { id = "astronomy", minimapRing = "astronomy", borderColor = "a4afbf", bgColor = "1f2a33", bgStyle = "smooth",
        foldArt = "astronomy", cornerStyle = "round" },
    -- red (Ikar 2026-11-18: "add the fire - red as a preset"): the fire ring and its cartouche, the border an ember red
    -- (the ring's own metal is dark iron, its red the lava's), the background charred dark stone
    { id = "fire", minimapRing = "fire", borderColor = "b4544a", bgColor = "2e1f1c", bgStyle = "darkstone",
        foldArt = "fire", cornerStyle = "bevel" },
}

ns.PRESET_BY_ID = {}
for _, preset in ipairs(ns.PRESETS) do
    ns.PRESET_BY_ID[preset.id] = preset
end
