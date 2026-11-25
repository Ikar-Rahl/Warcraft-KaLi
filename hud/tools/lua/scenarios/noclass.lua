-- A class the original game's tables don't have (Data/BaseStats.lua: the nine of 2004): no split of the bases, each
-- named as the game names such a level (UI/Hub/Infos/Stats.lua's baseName): an attribute's after the level, the race
-- and the class, « Niveau 23 Humaine Moine »; the health's after the level and the class; the rest « Base ». Since the
-- split by the tables (2026-11-23, 0.9.1), only such a class still meets these names, which no other test does.
local F = FakeWoW
UnitClass = function()
    return "Moine", "MONK", 10
end
login()
local Stats = ns.Stats
local function lines(key)
    local name = "KaLiHUD_Attr_" .. key
    ns.Hub.Object(name).OnEnter(ns.HubButtons.Get(name) or UIParent)
    local text = table.concat((ns.StatCard.Lines()), "\n")
    ns.Hub.Object(name).OnLeave()
    return text
end
local level = UnitLevel("player")
local template = ns.G("UNIT_TYPE_LEVEL_TEMPLATE", "Level %d %s")
local strength, health = lines("STRENGTH"), lines("HEALTH")
expect(strength:find(string.format(template, level, UnitRace("player") .. " Moine"), 1, true),
    "a class with no table: the attribute's base isn't named after the level, the race and the class: "
    .. strength:gsub("\n", " | "))
expect(health:find(string.format(template, level, "Moine"), 1, true),
    "a class with no table: the health's base isn't named after the level and the class: " .. health:gsub("\n", " | "))
expect(errors() == 0, "a class with no table errs: " .. select(2, errors()))
