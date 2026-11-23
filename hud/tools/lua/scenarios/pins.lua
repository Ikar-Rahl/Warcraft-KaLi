-- KaLi HUD's stat cards kept open, several at once (UI/Hub/Infos/StatCard.lua; Ikar 2026-11-23: "when clicking againt
-- on a stat, it shoudl close the popup, and when clickinkg, it should show it on top of the stat menu. Also add a
-- possibility to add multiple (stacking bottom uo, left to right, then right to left"): each apart, from the bottom up
-- then the next column, right then left; over the folders' lists; a click again shuts its own alone. What their rows
-- show on hover ("On hover, we shoudl show the item/spell/talent tooltip"): an item's, a buff's, a talent's tooltip,
-- how a base is worked out; none on the hover's card. The bases the cards work out, said ("I told you to mark any
-- formulas no ?"). The sheet's French full stops at their line's end ("some lines start with a '.'"). The XP bar's
-- bonuses and their sum ("the xp bar shoudl also have all the bonuses listed (and the total)"). (What the game's
-- figure doesn't count, the camp's well and the health seated: the regenerations' tables, scenarios/regen.lua.)
local F = FakeWoW
login()
local L, Card, UNKNOWN, Number = ns.L, ns.StatCard, ns.Stats.UNKNOWN, ns.Format.Number
local function button(key)
    return ns.HubButtons.Get("KaLiHUD_Attr_" .. key) or UIParent
end
local function click(key)
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnClick(button(key), "LeftButton")
    F.RunTimers()
end
local function hover(key)
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnEnter(button(key))
    local lines = Card.Lines(true)
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnLeave()
    return table.concat(lines, "\n"), lines
end
local function has(lines, text)
    for _, line in ipairs(lines) do
        if line == text then
            return true
        end
    end
    return false
end
-- (where a card kept open stands: left, bottom, right, top)
local function at(key)
    local l, b, r, t = Card.BoxOf(key)
    return l and { l, b, r, t } or nil
end
local function apart(a, b)
    return a[3] <= b[1] or b[3] <= a[1] or a[4] <= b[2] or b[4] <= a[2]
end
local function box(e)
    return e and string.format("%.0f,%.0f-%.0f,%.0f", e[1], e[2], e[3], e[4]) or "none"
end

-- several at once: apart, the second over the first, the third over it or in the next column to the right; over the
-- folders' lists (HIGH), under the tooltips
click("STRENGTH")
click("STAMINA")
click("AGILITY")
local a, b, c = at("STRENGTH"), at("STAMINA"), at("AGILITY")
local where = box(a) .. " " .. box(b) .. " " .. box(c)
expect(a and b and c and apart(a, b) and apart(b, c) and apart(a, c),
    "three cards kept open at once don't stand apart: " .. where)
expect(a and b and b[2] >= a[4] and math.abs(b[1] - a[1]) < 0.5,
    "the second card kept open isn't over the first, from the bottom up: " .. where)
expect(a and b and c and (c[2] >= b[4] and math.abs(c[1] - a[1]) < 0.5 or c[1] >= math.max(a[3], b[3])),
    "the third card kept open isn't over the second nor in the next column to the right: " .. where)
local first = Card.PinnedFrame("STRENGTH")
expect(first and first:GetFrameStrata() == "DIALOG", "a card kept open isn't over the folders' lists")
-- a click on one again shuts it alone, the others staying where they are
click("STAMINA")
local still = at("STRENGTH")
expect(not Card.Pinned("STAMINA") and Card.Pinned("STRENGTH") and Card.Pinned("AGILITY")
    and still and a and still[1] == a[1] and still[2] == a[2],
    "a click on an attribute whose card is kept open doesn't shut it alone, or moves the others")
-- as many as there is room: once the right is full, the columns go to the left of the first
for _, s in ipairs(ns.Stats.LIST) do
    if not Card.Pinned(s.key) then
        click(s.key)
    end
end
local leftmost = a and a[1] or 0
for _, s in ipairs(ns.Stats.LIST) do
    local e = at(s.key)
    if e then
        leftmost = math.min(leftmost, e[1])
    end
end
expect(a and leftmost < a[1], "with the right full, no card kept open goes to the left of the first")
Card.Unpin()
expect(not Card.Pinned(), "the cards kept open aren't all shut by Unpin")

-- each row's tooltip on a card kept open: the item worn, the buff's own, how the race's and the levels' are had
F.itemStats[1], F.itemQuality[1] = { ITEM_MOD_STRENGTH_SHORT = 10 }, 2
F.auras.HELPFUL[1] = { name = "Bénédiction des rois", spellId = 20217, points = { 10 }, auraInstanceID = 7 }
F.Fire("UNIT_AURA", "player")
F.RunTimers()
click("STRENGTH")
local kept, said = Card.PinnedFrame("STRENGTH"), {}
for _, r in ipairs(kept and kept.tips or {}) do
    if r:IsShown() then
        F.RunScript(r, "OnEnter")
        said[#said + 1] = table.concat(F.tooltip.lines, "|")
        F.RunScript(r, "OnLeave")
    end
end
local all = table.concat(said, "\n")
expect(all:find("item:1", 1, true), "an item's row doesn't show the item's tooltip: " .. all)
expect(all:find("aura:7", 1, true), "a buff's row doesn't show the buff's own tooltip: " .. all)
Card.Unpin()
-- none on the hover's card, which the pointer can't reach
hover("STRENGTH")
local hovered = KaLiHUDStatCard and KaLiHUDStatCard.tips or {}
local lit = false
for _, r in ipairs(hovered) do
    lit = lit or r:IsShown()
end
expect(not lit, "the hover's card has rows to hover")
-- a talent's row, its own tooltip at its rank
F.spellNames[13712] = "Esquive"
F.talents = { { spell = 13712, rank = 2, ranks = 3 } }
F.Fire("TRAIT_CONFIG_UPDATED", 1)
F.RunTimers()
click("DODGE")
kept, said = Card.PinnedFrame("DODGE"), {}
for _, r in ipairs(kept and kept.tips or {}) do
    if r:IsShown() then
        F.RunScript(r, "OnEnter")
        said[#said + 1] = table.concat(F.tooltip.lines, "|")
        F.RunScript(r, "OnLeave")
    end
end
all = table.concat(said, "\n")
expect(all:find("trait:", 1, true), "a talent's row doesn't show the talent's tooltip: " .. all)
Card.Unpin()
F.talents, F.spellNames[13712] = {}, nil
F.Fire("TRAIT_CONFIG_UPDATED", 1)
F.auras.HELPFUL[1], F.itemStats[1] = nil, nil
F.Fire("UNIT_AURA", "player")
F.RunTimers()

-- an attribute's base split by the original table (the fake's human warrior at 23), the table's base beside the game's
-- where they differ; no line of what a level gave or what the next will (Ikar 2026-11-23: "you still kept the Level 26
-- in the main state note (+1) etc, unecessary. Remove thoses")
local t, lines = hover("STRENGTH")
local gap = t:find(L.STAT_FOREVER, 1, true) and t:find("Humaine", 1, true) and not t:find(L.STAT_ADDON_ERROR, 1, true)
expect(gap and not t:find(UNKNOWN, 1, true) and not t:find("table d'origine)", 1, true)
    and not t:find("vu en jeu)", 1, true), "an attribute's card doesn't split its base, or says what a level gives: " .. t)
-- the two Skyborne, one race token, each its own offset by its ID, read from Forever's sheets (EV-0093)
local human = UnitRace
UnitRace = function() return "Céleste", "Skyborne", 95 end
local high = ns.Stats.BaseSplit(1)
UnitRace = function() return "Céleste", "Skyborne", 96 end
local wind = ns.Stats.BaseSplit(1)
UnitRace = human
expect(high and wind and high.race == 17 and wind.race == 16 and high.read and wind.read
    and not ns.Stats.BaseSplit(1).read, "the Skyborne's race rows aren't their own")

-- the sheet's French text with a paragraph's full stop at the start of the next: back at its end
STAT_SPELLPOWER_TOOLTIP = "Augmente les dégâts de vos |cFFFFFFFFsorts|r d’un maximum de %d\n\n.Augmenté par les "
    .. "|cFFFFFFFFdégâts des sorts|r et la |cFFFFFFFFpuissance des sorts|r\n\n|cffBCBCBC.Les temps d’incantation plus "
    .. "longs tirent généralement davantage profit des dégâts des sorts.\n\nLes rangs des sorts bien inférieurs à votre "
    .. "niveau actuel bénéficient moins des dégâts des sorts.|r"
t = hover("SPELLPOWER_FIRE")
local dotted
for line in (t .. "\n"):gmatch("([^\n]*)\n") do
    local bare = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if bare:sub(1, 1) == "." then
        dotted = line
    end
end
expect(not dotted and t:find("puissance des sorts|r.", 1, true) and t:find("d’un maximum de %d+%."),
    "a line of the sheet's French text starts with its full stop: " .. tostring(dotted) .. " / " .. t)
STAT_SPELLPOWER_TOOLTIP = nil

-- the XP bar: the rest's, the sleeping bag's « Bien reposé » at its own figures, a meal's hidden one from its tooltip,
-- then their sum, marked, the game not saying how they add up
F.auras.HELPFUL[1] = { name = "Bien reposé", spellId = 429959, points = { 3, 3 }, auraInstanceID = 61 }
F.auras.HELPFUL[2] = { name = "Bien nourri", spellId = 1248406, auraInstanceID = 62, points = { 10 },
    says = "Endurance augmentée de 10. Expérience gagnée en éliminant des adversaires augmentée de 5\194\160%." }
F.xp.rested = 2350
local bar = ns.StatusBars.bars[-1]
F.RunScript(bar, "OnEnter")
local tip = table.concat(F.tooltip.lines, "\n")
F.RunScript(bar, "OnLeave")
local function plus(v)
    return "+" .. ns.Format.Percent(v / 100)
end
expect(tip:find(L.XP_BONUSES, 1, true) and tip:find("Reposé\n" .. string.format(L.XP_ON_KILLS, plus(100)), 1, true)
    and tip:find("Bien reposé\n" .. plus(3), 1, true)
    and tip:find("Bien nourri\n" .. string.format(L.XP_ON_KILLS, plus(5)), 1, true)
    and tip:find(L.XP_TOTAL .. " " .. UNKNOWN .. "\n" .. string.format(L.XP_ON_KILLS, plus(108)) .. ", "
        .. string.format(L.XP_ON_QUESTS, plus(3)), 1, true)
    and tip:find(UNKNOWN .. " " .. L.XP_SUMMED, 1, true),
    "the XP bar's tooltip doesn't list the bonuses and their sum: " .. tip)
F.auras.HELPFUL[1], F.auras.HELPFUL[2] = nil, nil
local count = errors()
expect(count == 0, "errors: " .. select(2, errors()))
