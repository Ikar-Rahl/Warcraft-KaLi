-- A map button put away as its addon's broker object's twin (KaLi Recipe's), with the info bar off: back on the map,
-- as LibDBIcon's buttons and plain ones are, while the hub shows its object nowhere. It stayed away, its addon out of
-- reach (the review of 2026-11-18, R7).
local F = FakeWoW
login()
expect(F.recipeButton:GetParent() ~= Minimap and F.dbiButton:GetParent() ~= Minimap and ns.Hub.Entry("KaLi Recipe") ~= nil,
    "setup: the twin and LibDBIcon's button put away, the twin's object an element of the hub")

ns.db.options.infoBar = false
ns.ApplyAll()
F.RunTimers()
expect(F.dbiButton:GetParent() == Minimap, "setup: the info bar off, LibDBIcon's button back on the map")
expect(F.recipeButton:GetParent() == Minimap,
    "the info bar off, a button put away as its object's twin stays away, its object shown nowhere")

ns.db.options.infoBar = true
ns.ApplyAll()
F.RunTimers()
expect(F.recipeButton:GetParent() ~= Minimap, "the info bar back on, a twin isn't put away again")

-- Its object hidden in the hub: the player's own choice, bar or no bar.
ns.Hub.SetShown("KaLi Recipe", false)
F.RunTimers()
ns.db.options.infoBar = false
ns.ApplyAll()
F.RunTimers()
expect(F.recipeButton:GetParent() ~= Minimap, "an object hidden in the hub has its twin back on the map with the bar off")
expect(errors() == 0, "errors: " .. select(2, errors()))
