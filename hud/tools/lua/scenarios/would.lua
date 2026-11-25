-- What a value would be with the item under the pointer, on a card kept open (UI/Hub/Infos/Stats.lua's WOULD): the
-- attack power's, a chest of strength tried. Its base rows are the level's and the class's as without it, « Base » once:
-- the rest of its parts worked out again from what would be had come as one more (found 2026-11-25, when every
-- deliberate break was run against its link: the smoke's case of it tried the armour, which has no parts' rest since
-- its sources come from its whole, 2026-11-19).
local F = FakeWoW
local L = ns.L
login()
local function kept()
    return table.concat((ns.StatCard.PinnedLines(true)), "\n")
end
local function link(id, name)
    return "|cffffffff|Hitem:" .. id .. ":::::::::60:::::|h[Objet " .. name .. "]|h|r"
end
local function count(t, line)
    local n = 0
    for l in (t .. "\n"):gmatch("([^\n]*)\n") do
        n = n + (l == line and 1 or 0)
    end
    return n
end
ns.StatCard.Unpin()
ns.Hub.Object("KaLiHUD_Attr_ATTACK_AP").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_ATTACK_AP") or UIParent, "LeftButton")
F.RunTimers()
local before = kept()
F.items[2005] = { class = 4, subclass = 4, equip = "INVTYPE_CHEST" }
F.itemStats[42] = { ITEM_MOD_STRENGTH_SHORT = 10 }
F.Hover("Item", { id = 2005, hyperlink = link(2005, 42) })
F.RunTimers()
local would = kept()
expect(would:find(L.STAT_WOULD_HINT, 1, true) and count(before, L.STAT_BASE) == 1 and count(would, L.STAT_BASE) == 1,
    "the attack power's base rows aren't as without the item under the pointer: " .. (before:gsub("\n", " | "))
    .. " / " .. (would:gsub("\n", " | ")))
F.RunScript(GameTooltip, "OnHide")
F.RunTimers()

-- A consumable whose buff the data gives no figure of (one that follows its caster's power): what the value would be
-- can't be said, the game's question mark in its place, no figure given all the same (the smoke's case of it was a
-- meal's, whose figure is the data's since 2026-11-19).
ns.EFFECTS[999003] = "1,1;674:1:0:0:"
ns.ITEM_USES[3004] = "999003"
F.items[3004] = { class = 0, subclass = 2 }
ns.StatCard.Unpin()
ns.Hub.Object("KaLiHUD_Attr_ARMOR").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_ARMOR") or UIParent, "LeftButton")
F.RunTimers()
F.Hover("Item", { id = 3004, hyperlink = link(3004, 80) })
F.RunTimers()
local head = ns.StatCard.PinnedLines()[2] or ""
expect(head:find(ns.Stats.UNKNOWN, 1, true), "what the armour would be with a buff of no known figure is given all the "
    .. "same: " .. head .. " / " .. (kept():gsub("\n", " | ")))
F.RunScript(GameTooltip, "OnHide")
F.RunTimers()
ns.EFFECTS[999003], ns.ITEM_USES[3004], F.items[3004] = nil, nil, nil
ns.StatCard.Unpin()
expect(errors() == 0, "what would be errs: " .. select(2, errors()))
