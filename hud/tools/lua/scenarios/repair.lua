-- A saved file the load had to put right: /kh status and the bug report say so, and the last repair is kept. The
-- count went to the debug log alone, which is kept only while debug mode is on (the review of 2026-11-18, V3). The
-- file here holds a folder saved under a key that isn't a folder's id, which raised an error at every layout (R6), and
-- a place on no side.
local F = FakeWoW
KaLiHUDDB = { version = 1, options = {}, gold = {},
    folders = { Outils = { name = "Outils" } },
    items = { Outils = { side = "right", order = 1 }, casse = { side = "nulle part" } } }
login()
ns.Hub.Changed()
F.RunTimers()
expect(errors() == 0, "a folder saved under a key that isn't a folder's id raises an error at login or at a layout: "
    .. select(2, errors()))
expect(ns.Folders.Get("Outils") == nil and ns.dbInfo.fixed == 2,
    "a folder under a key that isn't a folder's id isn't dropped at load, counted: " .. tostring(ns.dbInfo.fixed))

local status = ns.Commands.FullStatus()
expect(status:find("2 values repaired at this login", 1, true) ~= nil, "what the load repaired isn't said in /kh status")
expect(status:find("last repair", 1, true) ~= nil and type(KaLiHUDDevDB.lastRepair) == "table"
    and KaLiHUDDevDB.lastRepair.fixed == 2, "the last repair isn't kept, or not said in /kh status")
expect(ns.Report.Text():find("2 values repaired at this login", 1, true) ~= nil,
    "what the load repaired isn't said in the bug report")
