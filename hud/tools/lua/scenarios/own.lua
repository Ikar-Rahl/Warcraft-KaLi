-- A character who has settings of its own (Core/Sets.lua) plays on them from its login to the file's writing: its own
-- in the settings' place as the addon loads, the account's back there as the game writes the file.
local F = FakeWoW
local me = (GetRealmName() or "?") .. "-" .. (UnitName("player") or "?")
KaLiHUDDB = { version = 1, options = { reach = 55 }, chars = { [me] = { own = true, settings = { options = { reach = 90 } } } } }
login()
expect(ns.CharKey() == me and ns.Sets.Own() and ns.db.options.reach == 90 and ns.db.account.options.reach == 55,
    "a character's own settings aren't in place once it has logged in: reach " .. tostring(ns.db.options.reach))
ns.db.options.reach = 95
F.Fire("PLAYER_LOGOUT")
expect(KaLiHUDDB.live == nil and KaLiHUDDB.options.reach == 55 and KaLiHUDDB.chars[me].own == true
    and KaLiHUDDB.chars[me].settings.options.reach == 95,
    "the file isn't written with the account's settings in their place and the character's own under its name")
expect(errors() == 0, "a character on its own settings errs: " .. select(2, errors()))
