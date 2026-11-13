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

T.Add("Sounds", "« Volume des sons »: a share of each kit's own volume, at most full, nothing asked at 100 %, silence at 0 %", function()
    local o = { soundRecipe = "quill", soundPlace = "parchment" }
    T.Eq(select(3, S.Pick(o, "recipe", 10, nil)), nil, "no volume in the options: nothing asked of the game")
    T.Eq(ns.DB.DEFAULTS.soundVolume, 200, "200 % by default: at the game's own level they were barely heard (Ikar, 2026-11-13)")
    o.soundVolume = 200
    T.True(math.abs(select(3, S.Pick(o, "recipe", 10, nil)) - 0.6) < 1e-9, "200 %: the quill at twice its own 0.3")
    T.True(math.abs(select(3, S.Pick(o, "place", 10, nil)) - 1) < 1e-9, "the parchment at twice its own 0.5: full")
    o.soundVolume = 300
    T.True(math.abs(select(3, S.Pick(o, "recipe", 10, nil)) - 0.9) < 1e-9, "300 %: the quill at 0.9")
    T.Eq(select(3, S.Pick(o, "place", 10, nil)), 1, "the parchment no more than full")
    o.soundVolume = 100
    T.Eq(select(3, S.Pick(o, "recipe", 10, nil)), nil, "100 %: nothing asked, the sound as before the option")
    o.soundVolume = 50
    local kit, _, volume = S.Pick(o, "recipe", 10, nil)
    T.Eq(kit, 3093, "50 %: the quill still")
    T.True(math.abs(volume - 0.15) < 1e-9, "at half its own 0.3: " .. tostring(volume))
    T.True(math.abs(select(3, S.Pick(o, "place", 10, nil)) - 0.25) < 1e-9, "the parchment at half its own 0.5")
    o.soundVolume = 0
    T.Eq(S.Pick(o, "recipe", 10, nil, true), nil, "0 %: nothing, even as a preview")
    for _, kind in ipairs({ "recipe", "place" }) do
        for _, c in ipairs(S.CHOICES[kind]) do
            local own = S.KIT_VOLUME[c[2]]
            T.True(own and own > 0 and own <= 1, c[1] .. ": its kit's own volume is known")
            T.True(S.Override(c[2], 95) < own, c[1] .. ": below 100 %, never louder than the game's own")
        end
    end
    local db = ns.DB.Load({ options = { soundVolume = 350 } })
    T.Eq(db.options.soundVolume, 300, "more than 300 %: 300 %")
    db = ns.DB.Load({ options = { soundVolume = -5 } })
    T.Eq(db.options.soundVolume, 0, "less than 0 %: 0 %")
    db = ns.DB.Load({ options = { soundVolume = "loud" } })
    T.Eq(db.options.soundVolume, 200, "not a number: the default")
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
