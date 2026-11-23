-- Sets of settings (Core/Sets.lua; Ikar 2026-11-19: "we should have to duplicate from another alt too. Maybe
-- save/update/create custom preset", "a checkbox for each state, on by default"): the settings as they are kept
-- under a name, applied part by part with what they were kept as the way back; and a character on settings of its
-- own, the account's waiting aside until the file is written.
local F = FakeWoW
login()
local Sets, DB, db = ns.Sets, ns.DB, ns.db
local me = ns.CharKey()
local o = db.options
local function deep(v)
    if type(v) ~= "table" then
        return v
    end
    local t = {}
    for k, x in pairs(v) do
        t[k] = deep(x)
    end
    return t
end

-- A set kept: all the settings, copied (what changes after isn't in it).
o.borderColor, o.reach, o.minimapAutoZoom, o.statusLeftWidth, o.infoSize = "112233", 55, 7, 300, 12
local folder = ns.Folders.Create("Essai")
F.RunTimers()
local kept = Sets.Save("Tank")
ns.Folders.Get(folder).name = "Autre"
expect(kept and #Sets.List() == 1 and kept.name == "Tank" and kept.by == me and not kept.backup
    and kept.settings.options.reach == 55 and kept.settings.folders[folder] ~= nil
    and kept.settings.folders[folder].name == "Essai",
    "the settings as they are aren't kept under a name, whole and as a copy")
expect(Sets.Save("") == nil and Sets.Save("   ") == nil, "a set is kept under no name")

-- Applied by parts: the look and the info bar taken, the plate, the status bars and what the HUD does left as they
-- are; the settings as they were kept as a set of their own, the way back.
o.borderColor, o.reach, o.minimapAutoZoom, o.statusLeftWidth, o.infoSize = "445566", 60, 3, 400, 14
ns.Folders.Delete(folder)
F.RunTimers()
-- (a step of the bar's to undo, which a set applied leaves none of: it is a step of what won't be there)
ns.History.Do("move", "KaLiHUD_Gold", ns.Hub.Insert, "KaLiHUD_Gold", "right", 1)
F.RunTimers()
local steps = (ns.History.Count())
local done = Sets.Apply(kept.settings, { "look", "bar" }, "Avant « Tank »")
F.RunTimers()
expect(done == true and o.borderColor == "112233" and o.infoSize == 12 and ns.Folders.IsFolder(folder)
    and ns.Folders.Get(folder).name == "Essai",
    "a set applied doesn't put the parts asked for in the settings: border " .. tostring(o.borderColor) .. ", size "
    .. tostring(o.infoSize) .. ", folder " .. tostring(ns.Folders.IsFolder(folder)))
expect(o.reach == 60 and o.minimapAutoZoom == 3 and o.statusLeftWidth == 400,
    "a set applied changes parts that weren't asked for: reach " .. tostring(o.reach) .. ", zoom "
    .. tostring(o.minimapAutoZoom) .. ", width " .. tostring(o.statusLeftWidth))
local was = Sets.List()[2]
expect(was and was.backup == true and was.name == "Avant « Tank »" and was.settings.options.borderColor == "445566"
    and was.settings.options.infoSize == 14 and was.settings.folders[folder] == nil,
    "the settings as they were aren't kept when a set is applied")
expect(steps == 1 and (ns.History.Count()) == 0,
    "the bar's steps to undo outlive a set applied, steps of what is no longer there: " .. steps .. " before")
-- the way back, whole
Sets.Apply(was.settings)
F.RunTimers()
expect(o.borderColor == "445566" and o.infoSize == 14 and not ns.Folders.IsFolder(folder) and #Sets.List() == 2,
    "the settings as they were, applied, don't bring them back; or applying with no name to keep them under keeps one")
-- all of a set with no parts named
Sets.Apply(kept.settings, nil, "b0")
F.RunTimers()
expect(o.reach == 55 and o.minimapAutoZoom == 7 and o.statusLeftWidth == 300 and o.borderColor == "112233",
    "a set applied with no parts named isn't applied whole")
-- the settings as they were: the last few kept, the oldest going
for i = 1, 4 do
    Sets.Apply(kept.settings, nil, "b" .. i)
end
F.RunTimers()
local backups, names = 0, {}
for _, p in ipairs(Sets.List()) do
    backups = backups + (p.backup and 1 or 0)
    names[#names + 1] = p.name
end
expect(backups == Sets.BACKUPS and table.concat(names, " ") == "Tank b2 b3 b4",
    "more of the settings as they were are kept than there is room for, or not the last: " .. table.concat(names, " "))

-- Settings that aren't: nothing done; wrong values in a set: dropped, the rest applied.
expect(Sets.Apply("Tank") == false and Sets.Apply(nil) == false, "what isn't settings is applied")
expect(Sets.Apply({ options = { reach = "wide", borderColor = "red", bridge = 80 } }) == true and o.reach == 40
    and o.bridge == 80 and o.borderColor == DB.DEFAULTS.borderColor,
    "a set's wrong values are applied as they are, or stop the rest: reach " .. tostring(o.reach))
-- How things stand is no setting (the review of 2026-11-19): the chat folded, the padlock open are neither kept in a
-- set nor taken from one, which folded the chat and opened the padlock of whoever applied another player's.
rawset(o, "chatFolded", true)
local stood = Sets.Capture()
rawset(o, "chatFolded", nil)
expect(stood.options.chatFolded == nil and stood.options.bridge == 80, "how things stand, the chat folded, is kept in a set")
expect(Sets.Apply({ options = { chatFolded = true, slotsLocked = false, bridge = 81 } }, { "plate", "behaviour" }) == true
    and o.bridge == 81 and o.chatFolded == false and o.slotsLocked == true,
    "a set applied folds the chat or opens the padlock of whoever applies it")
-- A set that fails half way leaves nothing of itself: every table as it was, those the bar's undo doesn't follow too.
db.buttonsLeft.Essai = true
local tripped = false
setmetatable(db.seeds, { __newindex = function(t, k, v)
    if not tripped then
        tripped = true
        error("seeds")
    end
    rawset(t, k, v)
end })
local half = Sets.Capture()
half.buttonsLeft, half.options.bridge = {}, 82
half.seeds.essai = true
local failed = Sets.Apply(half) == false
setmetatable(db.seeds, nil)
expect(failed and tripped and db.buttonsLeft.Essai == true and db.seeds.essai == nil and o.bridge == 81,
    "a set that fails half way leaves a table half replaced: the buttons left " .. tostring(db.buttonsLeft.Essai)
    .. ", bridge " .. tostring(o.bridge))
db.buttonsLeft.Essai = nil
forget()
-- Not in a fight: the bar's buttons are the game's protected ones.
F.combat = true
local reach = o.reach
expect(Sets.Apply(kept.settings) == false and o.reach == reach, "a set is applied in a fight")
F.combat = false

-- Brought up to date, renamed, deleted; no more kept than there is room for.
o.reach = 70
expect(Sets.Update(kept) and kept.settings.options.reach == 70 and Sets.Rename(kept, "Raid") and kept.name == "Raid"
    and not Sets.Rename(kept, " "), "a set isn't brought up to date or renamed")
for i = 2, Sets.MOST do
    Sets.Save("S" .. i)
end
expect(Sets.Save("un de trop") == nil, "more sets are kept than there is room for")
expect(Sets.Delete(kept) and not Sets.Delete(kept), "a set isn't deleted, or twice")
while #Sets.List() > 0 do
    Sets.Delete(Sets.List()[1])
end

-- A character on settings of its own: a copy of the account's to start from, which those no longer follow.
o.reach = 55
rawset(o, "meterFolded", true)
expect(not Sets.Own() and Sets.SetOwn(true) and Sets.Own() and db.live == me and db.account.options.reach == 55
    and db.options == o, "a character doesn't take settings of its own, the settings in use staying where they are")
-- (how things stand is no part of a set, and the account's all the same)
expect(db.account.options.meterFolded == true, "the account's copy forgets how things stand as a character takes its own")
rawset(o, "meterFolded", nil)
db.account.options.meterFolded = nil
o.reach = 90
expect(db.account.options.reach == 55, "the account's settings follow a character's own")
-- The file as the game writes it: the account's where the settings are read, the character's own under its name.
local file = deep(db)
DB.BeforeSave(file)
expect(file.live == nil and file.account == nil and file.options.reach == 55 and file.chars[me].own == true
    and file.chars[me].settings.options.reach == 90,
    "the file isn't written with the account's settings in their place and the character's own under its name")
-- It logs in again: its own in place, the account's aside. Another character: the account's, and this one's among
-- those it may take from.
local opened = DB.Open(deep(file))
expect(DB.Enter(opened, me) == true and opened.options.reach == 90 and opened.account.options.reach == 55
    and opened.live == me and opened.chars[me].settings == nil, "a character's own settings aren't in place as it logs in")
-- (a file written with them still in place, the game gone before its last event: read as it should have been)
local torn = DB.Open(deep(opened))
expect(torn.live == nil and torn.options.reach == 55 and torn.chars[me].settings.options.reach == 90,
    "a file written with a character's own settings in the account's place is opened as it is")
local other = DB.Open(deep(file))
expect(DB.Enter(other, "Royaume-Autre") == false and other.options.reach == 55 and other.live == nil,
    "another character plays on the first's own settings")
local charKey, live = ns.CharKey, ns.db
ns.CharKey = function()
    return "Royaume-Autre"
end
ns.db = other
local others = Sets.Others()
ns.CharKey, ns.db = charKey, live
expect(#others == 1 and others[1].key == me and others[1].settings.options.reach == 90,
    "a character's own settings aren't among those another may take from")
-- What isn't a set, or a character's settings, doesn't stay in the file.
local odd = deep(file)
odd.presets = { "x", { name = "", settings = {} },
    { name = "ok", at = "hier", by = 7, backup = "oui", imported = 1, settings = {} }, { name = "none" } }
odd.chars.broken = "x"
odd = DB.Open(odd)
expect(#odd.presets == 1 and odd.presets[1].name == "ok" and odd.chars.broken == nil,
    "what isn't a set or a character's settings stays in the file")
-- (a set's date that was a text stopped its window from opening: the review of 2026-11-19)
local mended = odd.presets[1] or {}
expect(mended.at == nil and mended.by == nil and mended.backup == nil and mended.imported == nil,
    "a set's date, owner or marks that can't be stay in the file")

-- Back on the account's: those in place, its own kept as a set.
local back = Sets.SetOwn(false)
F.RunTimers()
local own = Sets.List()[1]
expect(back == true and not Sets.Own() and db.live == nil and db.account == nil and o.reach == 55
    and db.chars[me].own == false, "a character back on the account's settings isn't on them")
expect(own and not own.backup and own.name == string.format(ns.L.SET_OWN_KEPT, UnitName("player"))
    and own.settings.options.reach == 90, "a character's own settings are lost as it goes back to the account's")
-- (a set of the player's, not the settings as they were, of which the oldest goes: it stays as later sets are applied)
for i = 1, Sets.BACKUPS + 1 do
    Sets.Apply(own.settings, { "look" }, "c" .. i)
end
F.RunTimers()
expect(Sets.List()[1] == own, "a character's own settings, kept as it went back to the account's, go as later sets are applied")
-- settings left under its name that nothing reads (a file from elsewhere) aren't dropped as it takes its own anew
db.chars[me] = { own = false, settings = { options = { reach = 77 } } }
local n = #Sets.List()
expect(Sets.SetOwn(true) and #Sets.List() == n + 1 and Sets.List()[n + 1].settings.options.reach == 77
    and db.chars[me].settings == nil, "settings left under a character's name are dropped as it takes its own")
expect(errors() == 0, "sets of settings err: " .. select(2, errors()))
