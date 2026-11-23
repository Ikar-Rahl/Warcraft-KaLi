-- Forever's coordinates under the map (UI/Minimap.lua): off while the HUD holds the map, put back as the player had
-- them at each logout, marked, and taken again at the next login (the review of 2026-11-23: disabled or removed, the
-- HUD had left them off). Whether the game keeps a setting changed at a logout or not, the player's value isn't lost;
-- one the player ticked again while the HUD held the map stays as set, at a logout and at the next login.
local F = FakeWoW
local C = "minimapShowPlayerCoords"
local Coords = ns.Minimap.Coords
local function now()
    return tostring(F.cvars[C]) .. " kept " .. tostring(ns.db and ns.db.cvars[C])
end
-- the last logout put them back, and the game kept it
KaLiHUDDB = { version = 1, cvars = { [C] = "1:back" } }
F.cvars[C] = "1"
login()
expect(F.cvars[C] == "0" and ns.db.cvars[C] == "1",
    "the coordinates put back at the last logout aren't taken again at the next login: " .. now())
-- a logout (a reload's too): back as the player had them, marked
F.Fire("PLAYER_LOGOUT")
expect(F.cvars[C] == "1" and KaLiHUDDB.cvars[C] == "1:back",
    "a logout leaves the coordinates off, or unmarked: " .. now())
-- the next login, the game having kept the HUD's 0 (a setting changed at a logout not kept): the value kept stands
F.cvars[C] = "0"
Coords.Take()
expect(F.cvars[C] == "0" and ns.db.cvars[C] == "1",
    "the coordinates put back too late for the game to keep it lose the player's value: " .. now())
-- ticked again by the player while the HUD holds the map: as set at a logout, and at the next login
F.cvars[C] = "1"
F.Fire("PLAYER_LOGOUT")
expect(F.cvars[C] == "1" and ns.db.cvars[C] == "1", "the coordinates ticked again aren't left as set at a logout: " .. now())
Coords.Take()
expect(F.cvars[C] == "1" and ns.db.cvars[C] == "1",
    "the coordinates ticked again are turned off at the next login: " .. now())
-- the map given back with the mark still on: the player's value, the mark gone
ns.db.cvars[C] = "1:back"
Coords.Give()
expect(F.cvars[C] == "1" and ns.db.cvars[C] == nil, "the map given back leaves the mark in the setting: " .. now())
expect(errors() == 0, "the coordinates err: " .. select(2, errors()))
