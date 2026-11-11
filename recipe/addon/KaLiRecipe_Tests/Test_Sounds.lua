local T = KaLiRecipeTests
local ns = KaLiRecipeDev.ns
local L = ns.L
local R = T.R
local S = ns.Sounds

T.Add("Sounds", "what a sighting brings: a recipe new to the notebook, or a new place for one in it", function()
    local m, db = T.NewBook()
    local isNew, what = m:Note(R.ribs, T.Vendor(), 100)
    T.True(isNew, "new")
    T.Eq(what, "recipe", "never seen, known by none: a recipe new to the notebook")
    isNew, what = m:Note(R.ribs, T.Vendor(9999), 200)
    T.Eq(what, "place", "another vendor: a new place")
    T.Eq(m:Note(R.ribs, T.Vendor(9999), 300), false, "the same vendor again: nothing")
    db.chars.alt.known[R.robe] = true
    m:Invalidate()
    isNew, what = m:Note(R.robe, T.Vendor(), 400)
    T.Eq(what, "place", "never seen but Elorah knows it: already in the notebook, so a new place")
end)

T.Add("Sounds", "the chosen kit, « Aucun », and the quiet gap between two sounds", function()
    local o = { soundRecipe = "quill", soundPlace = "stroke" }
    local kit, stop = S.Pick(o, "recipe", 10, nil)
    T.Eq(kit, 3093, "a recipe: the quill")
    T.Eq(stop, nil, "written to its end")
    kit, stop = S.Pick(o, "place", 10, nil)
    T.Eq(kit, 3093, "a place: the quill too")
    T.True(stop and stop > 0 and stop < 1, "a stroke: stopped within a second")
    T.Eq(S.Pick(o, "recipe", 10, 10 - S.QUIET / 2), nil, "another sound just played: none")
    T.Eq(S.Pick(o, "recipe", 10, 10 - S.QUIET), 3093, "after the gap: plays")
    T.Eq(S.Pick(o, "recipe", 10, 9.9, true), 3093, "the options' preview: whatever the time")
    T.True(S.QUIET >= 3, "the gap outlasts the quill's longest take, 2.95 seconds")
    o.soundRecipe = S.NONE
    T.Eq(S.Pick(o, "recipe", 10, nil, true), nil, "« Aucun »: nothing, even as a preview")
    o.soundPlace = "bogus"
    T.Eq(S.Pick(o, "place", 10, nil), nil, "a key the list doesn't have: nothing")
    T.Eq(S.Pick(nil, "place", 10, nil), nil, "no options yet: nothing")
end)

T.Add("Sounds", "one sound a visit; the bigger may still follow the smaller", function()
    local C = ns.Chat
    T.Eq(C.SoundFor("recipe", nil), "recipe", "a recipe new to the notebook first: the bigger")
    T.Eq(C.SoundFor("place", nil), "place", "a new place first: the smaller")
    T.Eq(C.SoundFor("place", "place"), nil, "another new place: nothing more")
    T.Eq(C.SoundFor("recipe", "place"), "recipe", "then a recipe new to the notebook: the bigger")
    T.Eq(C.SoundFor("place", "recipe"), nil, "after the bigger: nothing")
    T.Eq(C.SoundFor("recipe", "recipe"), nil, "the bigger twice: once")
    T.Eq(C.SoundFor(nil, nil), nil, "nothing noted: nothing")
end)

T.Add("Sounds", "every choice has its words, and saved data keeps only a choice the list has", function()
    for _, kind in ipairs({ "recipe", "place" }) do
        T.True(S.Kit(kind, S.DEFAULTS[kind]) ~= nil, kind .. ": the default is in the list")
        for _, c in ipairs(S.CHOICES[kind]) do
            T.True(L["SOUND_" .. c[1]] ~= "SOUND_" .. c[1], kind .. " " .. c[1] .. ": a label")
            T.True(type(c[2]) == "number" and c[2] > 0, c[1] .. ": a kit")
            T.True(c[4] == nil or c[4] > 0, c[1] .. ": stopped after some time, or not at all")
        end
    end
    local db = ns.DB.Load({ options = { soundRecipe = "bogus", soundPlace = S.NONE } })
    T.Eq(db.options.soundRecipe, S.DEFAULTS.recipe, "an unknown sound: the default")
    T.Eq(db.options.soundPlace, S.NONE, "« Aucun » kept")
end)

T.Add("Game", "the bank's numbers are this character's bank tabs, from the game's own enum", function()
    local E = Enum.BagIndex
    local bank = ns.Game.BagIDs(true)
    T.True(#bank > 0, "some bank containers")
    T.Eq(bank[1], E.CharacterBankTab_1, "the first is the character's first tab")
    for _, id in ipairs(bank) do
        T.True(id >= E.CharacterBankTab_1 and (not E.AccountBankTab_1 or id < E.AccountBankTab_1),
            "a character's tab, not the account's or the keyring: " .. id)
    end
    local bags = ns.Game.BagIDs(false)
    T.Eq(bags[1], E.Backpack, "the backpack first")
    T.Eq(bags[#bags], E.ReagentBag, "the reagent bag last")
end)
