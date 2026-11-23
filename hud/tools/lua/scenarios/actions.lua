-- An action of the player's that raises an error half way (UI/Hub/History.lua): what it had changed is put back, no
-- step is left to undo, and its error is kept with the place it came from. It left the saved data half changed, with
-- no way back, and its error named the undo's own file in place of what failed (the review of 2026-11-18, R2).
local F = FakeWoW
login()
local function side()
    local saved = ns.Hub.Saved("KaLiHUD_Gold")
    return saved and saved.side
end
local before, steps = side(), (ns.History.Count())

local function halfWay()
    ns.Hub.Save("KaLiHUD_Gold", { side = "free", pos = 0.3 })
    local missing
    return missing.field
end
-- the line of the fault, three down from the function's own: the stack kept must hold it
local fault = ":" .. (debug.getinfo(halfWay, "S").linedefined + 3) .. ": in "
local got = ns.History.Do("move", "KaLiHUD_Gold", halfWay)
F.RunTimers()
local n, said = errors()
expect(side() == before, "an action that fails half way leaves the saved data half changed: gold from "
    .. tostring(before) .. " to " .. tostring(side()))
expect((ns.History.Count()) == steps and got == nil, "an action that fails half way leaves a step to undo, or gives a result")
expect(n == 1 and stackOf("missing"):find(fault, 1, true) ~= nil,
    "the error of an action that fails isn't kept with the place it came from: " .. n .. " kept, " .. said)

-- The next action is one step again, undone as ever.
forget()
ns.History.Do("move", "KaLiHUD_Gold", ns.Hub.Insert, "KaLiHUD_Gold", "right", 1)
F.RunTimers()
expect((ns.History.Count()) == steps + 1 and side() == "right", "after an action that failed, the next isn't one step to undo")
ns.History.Undo()
F.RunTimers()
expect(side() == before and errors() == 0, "after an action that failed, an undo doesn't put the next one back: "
    .. tostring(side()) .. ", " .. select(2, errors()))

-- A making that fails leaves nothing made.
local folders = #ns.Folders.List()
ns.History.Do("create", nil, function()
    local id = ns.Folders.Create("Raté")
    ns.Hub.Insert(id, "right", 1)
    error("the making fails")
end)
F.RunTimers()
n, said = errors()
expect(#ns.Folders.List() == folders and ns.Folders.ByRole("emotes") ~= nil,
    "a folder's making that fails leaves the folder: " .. #ns.Folders.List() .. " folders for " .. folders)
expect(n == 1 and said:find("the making fails", 1, true) ~= nil, "a making that fails isn't kept as one error: " .. said)
