-- KaLi HUD's health and mana bases split as the attributes' (UI/Hub/Infos/Stats.lua's baseRows; Ikar 2026-11-24: "why
-- mana and health are not broken by race, class and profession like the rest"): the class's at level 1, then what
-- levels 2 to N have given, the health's from the original game's table (Data/BaseStats.lua's health), the mana's
-- from Forever's own (BASE_MANA); no race's; what the game's figure leaves, « Autres ». The fake's level 23 human
-- warrior: 1013 health, 243 the table's and 770 its stamina's; as a mage, 431 the table's mana at 23, 100 at 1.
local F = FakeWoW
login()
local L, Number = ns.L, ns.Format.Number
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t%s*", ""):gsub("|A.-|a", "?"))
end
local function hover(key)
    local name = "KaLiHUD_Attr_" .. key
    ns.Hub.Object(name).OnEnter(ns.HubButtons.Get(name) or UIParent)
    local lines = {}
    for i, line in ipairs((ns.StatCard.Lines(true))) do
        lines[i] = plain(line)
    end
    ns.Hub.Object(name).OnLeave()
    return table.concat(lines, "\n")
end
local level23 = string.format(ns.G("UNIT_LEVEL_TEMPLATE", "Level %d"), 23)

local t = hover("HEALTH")
expect(t:find("Guerrière\n" .. Number(20) .. "\n" .. level23 .. "\n" .. Number(223) .. "\n", 1, true)
    and not t:find(L.STAT_OTHER, 1, true) and not t:find(L.STAT_ADDON_ERROR, 1, true),
    "the health's base isn't the class's 20 at level 1 and the 223 levels 2 to 23 gave, all of it: " .. t)

-- the attack power's: « Base » first, the warrior's -20, then its level's, « Niveau 23 (x3) », 69 (Ikar 2026-11-24:
-- "base shoudl come before level", "Level 26 (x2)")
t = hover("ATTACK_AP")
expect(t:find(L.STAT_BASE .. "\n" .. Number(-20) .. "\n" .. level23 .. " (x3)\n" .. Number(69) .. "\n", 1, true)
    and not t:find(L.STAT_ADDON_ERROR, 1, true),
    "the attack power's base isn't « Base » -20 then the level's 3 a level: " .. t)

local unitClass, powerType, powerMax = UnitClass, UnitPowerType, UnitPowerMax
local intellect = select(2, UnitStat("player", 4))
UnitClass = function()
    return "Mage", "MAGE", 8
end
UnitPowerType = function()
    return 0, "MANA"
end
UnitPowerMax = function()
    return 431 + math.min(20, intellect) + math.max(0, intellect - 20) * 15 + 7
end
t = hover("POWER")
UnitClass, UnitPowerType, UnitPowerMax = unitClass, powerType, powerMax
expect(t:find("Mage\n" .. Number(100) .. "\n" .. level23 .. "\n" .. Number(331) .. "\n", 1, true)
    and t:find(L.STAT_OTHER .. "\n+7", 1, true),
    "the mana's base isn't the class's 100 at level 1 and the 331 levels 2 to 23 gave, 7 left: " .. t)
