-- What the stat cards' rows say in cases the smoke's session no longer meets (found 2026-11-25, when every
-- deliberate break was run against its link: each had passed for caught while the smoke's state had moved on).
-- - The hit chance's « Effets », each kind's: melee, ranged, spells (UI/Hub/Infos/Stats.lua's GIVES.HITCHANCE).
-- - A source of one school alone on the spell penetration's card: named with its school, « Pénétration du feu
--   (Fire) » (the spell power's cards are a school each since 2026-11-23: their sources never say it).
-- - A value nothing changes, the game giving no bonus of it: what it stands on all the same, the defence's skill;
--   and what a set's next pieces would give it (the armour's sources come from its whole since 2026-11-19: it is never
--   a value nothing changes, which the smoke's case of this took it for).
local F = FakeWoW
local L = ns.L
login()
local function card(key)
    local name = "KaLiHUD_Attr_" .. key
    ns.Hub.Object(name).OnEnter(ns.HubButtons.Get(name) or UIParent)
    local text = table.concat((ns.StatCard.Lines()), "\n")
    ns.Hub.Object(name).OnLeave()
    return text
end
local function flat(t)
    return (t:gsub("\n", " | "))
end

-- the hit chance's effects, each kind's
local hit = card("HITCHANCE")
local effects = hit:find("\n" .. L.STAT_EFFECTS .. "\n", 1, true)
local gives = effects and hit:sub(effects) or ""
expect(effects and gives:find(ns.G("MELEE", "Melee"), 1, true) and gives:find(ns.G("RANGED", "Ranged"), 1, true)
    and gives:find(ns.G("SPELLS", "Spells"), 1, true),
    "the hit chance's card doesn't say what each kind's hit gives: " .. flat(hit))

-- one school's penetration, named with its school
F.spellNames[25766] = "Pénétration du feu"
F.auras.HELPFUL[1] = { name = "Pénétration du feu", spellId = 25766, points = { -30 }, auraInstanceID = 52 }
local spells = card("SPELLPENETRATION")
F.auras.HELPFUL[1] = nil
expect(spells:find("Pénétration du feu (" .. ns.G("DAMAGE_SCHOOL3", "Fire") .. ")", 1, true),
    "a source of one school alone isn't named with its school: " .. flat(spells))

-- a value nothing changes: its skill all the same, and a set's next pieces
local unitDefense = UnitDefenseSkill
UnitDefenseSkill = function()
    return 140, 0
end
local defense = card("DEFENSE")
expect(defense:find(ns.G("SKILL_LEVEL", "Skill Level") .. "\n140", 1, true),
    "a value nothing changes doesn't show what it stands on: " .. flat(defense))
ns.ITEM_SETS[999] = "2:7427;4:7427;6:7427"
for _, id in ipairs({ 1001, 1003, 1007 }) do
    F.items[id] = { class = 4, subclass = 4, set = 999 }
end
F.setNames[999] = "Armure d'essai"
defense = card("DEFENSE")
expect(defense:find(string.format(ns.G("ITEM_SET_NAME", "%s (%d/%d)"), "Armure d'essai", 3, 4) .. "\n+3", 1, true),
    "a set's next pieces aren't said for a value nothing changes: " .. flat(defense))
UnitDefenseSkill = unitDefense
expect(errors() == 0, "the cards' rows err: " .. select(2, errors()))
