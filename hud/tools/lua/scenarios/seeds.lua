-- The locked folders KaLi HUD makes (UI/Hub/Seeds.lua's Sync), one of them raising an error at a first run: nothing is
-- left of it, those after it are made all the same, and the next login makes it. All made in a row, « Emote » once
-- stayed empty for good and none of the ten other folders was made that session (the review of 2026-11-18, R5).
local F = FakeWoW
F.Fire("ADDON_LOADED", "KaLiHUD")
local real, calls = ns.Hub.Insert, 0
ns.Hub.Insert = function(...)
    calls = calls + 1
    if calls == 1 then
        error("the first folder's placing fails")
    end
    return real(...)
end
F.Fire("PLAYER_LOGIN")
F.Fire("PLAYER_ENTERING_WORLD")
F.RunTimers()
local ROLES = { "weapons", "professions", "stats", "reagents", "statistics", "guild", "group", "session", "infos", "reputations" }
local function others()
    local n = 0
    for _, role in ipairs(ROLES) do
        n = n + (ns.Folders.ByRole(role) and 1 or 0)
    end
    return n
end
local function emoteMacros()
    local n = 0
    for _, id in ipairs(ns.Macros.List()) do
        local seed = ns.Macros.Get(id).seed
        n = n + (type(seed) == "string" and seed:find("^emotes:") and 1 or 0)
    end
    return n
end
local n, said = errors()
expect(ns.Folders.ByRole("emotes") == nil and emoteMacros() == 0,
    "a locked folder that fails is left half made: its folder " .. tostring((ns.Folders.ByRole("emotes")))
    .. ", " .. emoteMacros() .. " of its macros")
expect(others() == #ROLES, "a locked folder that fails takes those after it: " .. others() .. " folders made of "
    .. #ROLES)
expect(n == 1 and said:find("placing fails", 1, true) ~= nil, "its error isn't kept once: " .. n .. " kept, " .. said)

-- The next login makes it.
forget()
ns.Hub.Insert = real
ns.Seeds.Run()
F.RunTimers()
local emotes = ns.Folders.ByRole("emotes")
-- (the fake game has a few emotes of each kind, each kind under its title)
expect(emotes ~= nil and #ns.Hub.InFolder(emotes) >= 3 and errors() == 0,
    "a locked folder that failed isn't made at the next login: its folder " .. tostring(emotes) .. ", "
    .. (emotes and #ns.Hub.InFolder(emotes) or 0) .. " in it, " .. select(2, errors()))
local titles = 0
for _, e in ipairs(emotes and ns.Hub.InFolder(emotes) or {}) do
    titles = titles + (e.isSeparator and 1 or 0)
end
expect(others() == #ROLES and emoteMacros() >= 2 and titles == 2 and emoteMacros() == #ns.Hub.InFolder(emotes) - titles,
    "the next login makes the others twice, or not the emotes' macros: " .. others() .. " folders, " .. emoteMacros()
    .. " macros")

-- What the hub makes is listed in the order it was made, by its id's number (UI/Hub/Hub.lua's Made): the twelfth
-- folder after the second, not between the first and the second as their texts sort.
local list, ordered = ns.Folders.List(), true
for i = 2, #list do
    ordered = ordered and tonumber(list[i]:match("%d+$")) > tonumber(list[i - 1]:match("%d+$"))
end
expect(#list >= 11 and ordered, "the folders aren't listed in the order they were made: " .. table.concat(list, " "))
expect(ns.Folders.IsId("KaLiHUD_Folder3") and not ns.Folders.IsId("KaLiHUD_Macro3") and ns.Macros.IsId("KaLiHUD_Macro3")
    and ns.Separators.IsId("KaLiHUD_Separator1") and not ns.Folders.IsId("Outils"),
    "a name isn't told for its kind's id by its prefix and number")
