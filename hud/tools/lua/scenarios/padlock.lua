-- The padlock shut at every connection and every reload, whatever was saved, and saved shut at logout, a disconnection
-- too (Ikar 2026-11-20: "make it lock on combat (no unlock after) on disconnect, on connect, on reload").
local F = FakeWoW
KaLiHUDDB = { version = 1, options = { slotsLocked = false } }
login()
expect(ns.Hub.IsLocked(), "the padlock saved open is open after a connection or a reload")
ns.Hub.SetLocked(false)
F.Fire("PLAYER_LOGOUT")
expect(KaLiHUDDB.options.slotsLocked ~= false, "the padlock open is saved open at logout")
expect(errors() == 0, "the padlock at login or logout errs: " .. select(2, errors()))
