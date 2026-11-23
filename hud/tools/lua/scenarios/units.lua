-- The player's own unit events alone (UI/Hub/Infos/Infos.lua's OnPlayer; the review of 2026-11-23: registered the
-- shared way, every unit's came, a raid's and the nameplates' many times a second, to be dropped). Another unit's aura,
-- a raid member's, a nameplate's, the target's, reaches nothing of the addon's, not even its count; the player's reads
-- the attributes again and is counted as any event; the status bars follow the player's level, not another unit's.
local F = FakeWoW
login()
local unitStat, strength = UnitStat, 110
UnitStat = function(unit, i)
    if i == 1 then
        return strength, strength, 0, 0
    end
    return unitStat(unit, i)
end
local item = ns.Hub.Object("KaLiHUD_Attr_STRENGTH")
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local before, counted = tostring(item.text), ns.EventCounts().UNIT_AURA or 0
strength = 140
for _, unit in ipairs({ "raid7", "nameplate3", "target" }) do
    F.Fire("UNIT_AURA", unit)
end
F.RunTimers()
expect(tostring(item.text) == before and (ns.EventCounts().UNIT_AURA or 0) == counted,
    "another unit's aura reaches the addon: " .. tostring(item.text) .. ", counted " .. tostring(ns.EventCounts().UNIT_AURA))
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(tostring(item.text):find(ns.Format.Number(140), 1, true) and (ns.EventCounts().UNIT_AURA or 0) == counted + 1,
    "the player's aura doesn't read the attributes again, or isn't counted: " .. tostring(item.text))

-- the status bars: the player's level, never another unit's
local refresh, refreshes = ns.StatusBars.Refresh, 0
ns.StatusBars.Refresh = function(...)
    refreshes = refreshes + 1
    return refresh(...)
end
F.Fire("UNIT_LEVEL", "party1")
F.RunTimers()
local others = refreshes
F.Fire("UNIT_LEVEL", "player")
F.RunTimers()
ns.StatusBars.Refresh = refresh
expect(others == 0 and refreshes == 1,
    "the status bars follow another unit's level, or not the player's: " .. others .. ", " .. refreshes)
UnitStat = unitStat
expect(errors() == 0, "the player's unit events err: " .. select(2, errors()))
