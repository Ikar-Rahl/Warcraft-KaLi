-- The titles of KaLi HUD's own folders' separators, in the game's words taken as the folder is made (UI/Hub/Seeds.lua's
-- Title: a function, its words the client's language's): each made a title, as a folder made at a first run and as
-- one the next login puts back after it was taken out (Seeds.Sync). A function left as it was made a plain rule
-- (2026-11-20, « fais un tour sur tous nos menus »); the smoke's lists name a separator by its place alone.
local F = FakeWoW
local L = ns.L
login()
local Hub, Separators = ns.Hub, ns.Separators
local function titles(role)
    local out = {}
    for _, e in ipairs(Hub.InFolder(ns.Folders.ByRole(role) or 0)) do
        if e.isSeparator then
            out[#out + 1] = Separators.Name(e.name) or ""
        end
    end
    return out
end
local function holds(list, text)
    for _, t in ipairs(list) do
        if t == text then
            return true
        end
    end
    return false
end
local group, stats = titles("group"), titles("stats")
expect(holds(group, L.GROUP_MARKERS), "the group's markers have no title: " .. table.concat(group, " | "))
expect(holds(stats, ns.G("STAT_CATEGORY_PRIMARY_ATTRIBUTES", "Primary Attributes")),
    "the attributes' folder has no title for the primary attributes: " .. table.concat(stats, " | "))

-- Taken out, the next login's Sync puts it back with its title.
for _, e in ipairs(Hub.InFolder(ns.Folders.ByRole("group"))) do
    if e.isSeparator and Separators.Name(e.name) == L.GROUP_MARKERS then
        Separators.Delete(e.name)
    end
end
F.RunTimers()
ns.Seeds.Run()
F.RunTimers()
group = titles("group")
expect(holds(group, L.GROUP_MARKERS), "the group's markers' title put back by the next login is a plain rule: "
    .. table.concat(group, " | "))
expect(errors() == 0, "the folders' titles err: " .. select(2, errors()))
