-- « Suite », the folder KaLi HUD makes for what doesn't fit on the bar (UI/Hub/Seeds.lua), made again from the bar's
-- menu after it was deleted (Seeds.Restore): the one that takes what doesn't fit again (the review of 2026-11-20, D03).
-- Another folder told to take it meanwhile gives it back.
local F = FakeWoW
login()
local Folders, Seeds = ns.Folders, ns.Seeds
local mine = Folders.Create("Essai")
ns.Hub.Insert(mine, "left", 1)
Folders.SetOverflow(mine, true)
local suite = Seeds.Restore("overflow")
F.RunTimers()
expect(suite and Folders.ByRole("overflow") == suite and Folders.Overflow() == suite,
    "« Suite » made again isn't the folder that takes what doesn't fit: " .. tostring(Folders.Overflow()) .. " for "
    .. tostring(suite))
expect(errors() == 0, "« Suite » made again errs: " .. select(2, errors()))
