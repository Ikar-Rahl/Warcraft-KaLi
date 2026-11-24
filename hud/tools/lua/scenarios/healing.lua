-- KaLi HUD's healing taken (UI/Hub/Infos/Stats.lua's HealTaken; Ikar 2026-11-24: "add the healing taken"): the effects
-- on the character, a share of each heal (aura 118), several multiplying each other, and points on each heal (115),
-- each named on its card; 0 with none. Mortal Strike's -50 %, Tree of Life's +10 % with it (-45 %), Amplify Magic's +45.
local F = FakeWoW
login()
local L = ns.L
local function plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t%s*", ""):gsub("|A.-|a", "?"))
end
local STAT = {}
for _, s in ipairs(ns.Stats.LIST) do
    STAT[s.key] = s
end
local function value(key)
    return plain(STAT[key].value())
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
local function refresh()
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
end
local P = ns.Format.Percent

expect(value("HEALTAKEN") == P(0) and value("HEALTAKEN_FLAT") == "0",
    "with nothing on the character, the healing taken isn't 0: " .. value("HEALTAKEN") .. " / " .. value("HEALTAKEN_FLAT"))

F.auras.HARMFUL[1] = { name = "Frappe mortelle", spellId = 12294 }
refresh()
local t = hover("HEALTAKEN")
expect(value("HEALTAKEN") == P(-0.5) and t:find("Frappe mortelle\n" .. P(-0.5), 1, true),
    "Mortal Strike's -50 % isn't the healing taken, or its card doesn't name it: " .. value("HEALTAKEN") .. " / " .. t)

F.auras.HELPFUL[1] = { name = "Arbre de vie", spellId = 439745 }
refresh()
expect(value("HEALTAKEN") == P(-0.45),
    "Mortal Strike's -50 % and Tree of Life's +10 % don't multiply each other: " .. value("HEALTAKEN"))

F.auras.HARMFUL[1], F.auras.HELPFUL[1] = nil, { name = "Amplification de la magie", spellId = 1008 }
refresh()
t = hover("HEALTAKEN_FLAT")
expect(value("HEALTAKEN_FLAT") == "+45" and t:find("Amplification de la magie\n+45", 1, true),
    "Amplify Magic's +45 on each heal isn't the healing taken per heal: " .. value("HEALTAKEN_FLAT") .. " / " .. t)
F.auras.HELPFUL[1] = nil
refresh()

-- The healing done (Ikar 2026-11-24: "heal power should count only when it affect all spels. Or the main spells at
-- least"): Purification, +10 % on every shaman's main heal, counts; Improved Renew, Renew's alone, doesn't; Power
-- Infusion's +20 % multiplies with it, +32 %.
expect(value("HEALDONE") == P(0), "with nothing, the healing done isn't 0: " .. value("HEALDONE"))
F.talents = { { spell = 16178, rank = 5, ranks = 5 }, { spell = 14908, rank = 3, ranks = 3 } }
F.spellNames[16178], F.spellNames[14908] = "Purification", "Rénovation améliorée"
F.Fire("PLAYER_TALENT_UPDATE")
refresh()
t = hover("HEALDONE")
expect(value("HEALDONE") == "+" .. P(0.1) and t:find("Purification", 1, true) and not t:find("Rénovation", 1, true),
    "Purification isn't the healing done, or a talent of one heal counts: " .. value("HEALDONE") .. " / " .. t)
F.auras.HELPFUL[1] = { name = "Infusion de puissance", spellId = 10060 }
refresh()
expect(value("HEALDONE") == "+" .. P(0.32),
    "Purification's +10 % and Power Infusion's +20 % don't multiply each other: " .. value("HEALDONE"))
F.auras.HELPFUL[1], F.talents = nil, {}
F.Fire("PLAYER_TALENT_UPDATE")
refresh()
