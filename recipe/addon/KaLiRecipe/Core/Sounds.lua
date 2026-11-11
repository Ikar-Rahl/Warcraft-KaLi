-- Two sounds (Ikar, 2026-11-10): one when a visit notes a recipe that wasn't in the notebook yet, a smaller one when
-- it notes a new place for a recipe already there. The game's own sound kits, by number: they follow the player's
-- effects volume and mute, and the addon ships no sound file. Each can be heard on the bench (bench/index.html, panel
-- « Sounds ») and chosen in the options, or turned off.
local _, ns = ...

local Sounds = {}
ns.Sounds = Sounds

Sounds.NONE = "none"

-- Ikar kept the quill, the quest log's: the game has no other writing sound. Its shorter strokes are the same kit
-- stopped early, fading out; the parchments are the bags' own for a paper item picked up or laid down.
-- { key, sound kit, what the offline checks hold it against: its name in Blizzard's SOUNDKIT, or a file it plays,
--   the seconds after which it fades out (none: to its end) }. tools/bench_sounds.py gives the bench the same list.
local WRITING = {
    { "quill", 3093, "IG_WRITE_QUEST" },  -- three takes, one at random, of 2.2 to 3 seconds
    { "note", 3093, "IG_WRITE_QUEST", 0.9 },
    { "stroke", 3093, "IG_WRITE_QUEST", 0.4 },
    { "parchment", 1209, 567556 },  -- Sound/Interface/PickUp/PutDownParchment_Paper.ogg, 0.33 seconds
    { "sheet", 1192, 567562 },  -- Sound/Interface/PickUp/PickUpParchment_Paper.ogg, 0.52 seconds
}
-- Both settings offer the same list.
Sounds.CHOICES = { recipe = WRITING, place = WRITING }
-- Ikar's picks, 2026-11-10.
Sounds.DEFAULTS = { recipe = "quill", place = "stroke" }
-- The option behind each kind.
Sounds.OPTION = { recipe = "soundRecipe", place = "soundPlace" }

-- Between two of the addon's sounds, at least this many seconds: an auction house's pages of results or a run of loot
-- make one sound, not one each, and the quill finishes before another starts.
Sounds.QUIET = 3
-- A stroke's fade-out, in seconds.
Sounds.FADE = 0.2

-- The kit of a kind's choice, and when it stops.
function Sounds.Kit(kind, key)
    for _, c in ipairs(Sounds.CHOICES[kind] or {}) do
        if c[1] == key then
            return c[2], c[4]
        end
    end
end

-- The keys an option may hold, "none" included: { [key] = true }.
function Sounds.Keys(kind)
    local set = { [Sounds.NONE] = true }
    for _, c in ipairs(Sounds.CHOICES[kind] or {}) do
        set[c[1]] = true
    end
    return set
end

-- What PlaySound did, for the API check: how many it played, and the kits it refused while the game's sound was on.
Sounds.stats = { played = 0, refused = {} }

-- The player's mute: then the game refuses every sound, and that says nothing about the kit.
local function soundOn()
    local ok, all, sfx = pcall(function()
        return C_CVar.GetCVar("Sound_EnableAllSound"), C_CVar.GetCVar("Sound_EnableSFX")
    end)
    return not ok or all ~= "0" and sfx ~= "0"
end

local function play(kit, stop)
    local ok, willPlay, handle = pcall(PlaySound, kit)
    if ok and willPlay ~= false then
        Sounds.stats.played = Sounds.stats.played + 1
        if stop and handle then
            C_Timer.After(stop, function()
                ns.SafeCall(StopSound, handle, Sounds.FADE * 1000)
            end)
        end
    elseif soundOn() then
        Sounds.stats.refused[kit] = ok and "not played" or tostring(willPlay)
    end
end

-- The kit to play for a kind, "recipe" or "place", and when it stops: the options' choice, or nil when it's "none" or
-- another sound played less than QUIET seconds before (lastTime). preview: the options' own, whatever the time. Pure,
-- for the tests.
function Sounds.Pick(options, kind, now, lastTime, preview)
    local kit, stop = nil, nil
    if options then
        kit, stop = Sounds.Kit(kind, options[Sounds.OPTION[kind] or ""])
    end
    if not kit or not preview and lastTime and now - lastTime < Sounds.QUIET then
        return nil
    end
    return kit, stop
end

local last
-- Plays the chosen sound of a kind. Returns whether a sound went out.
function Sounds.Play(kind, preview)
    local now = GetTime()
    local kit, stop = Sounds.Pick(ns.db and ns.db.options, kind, now, last, preview)
    if not kit then
        return false
    end
    last = now
    play(kit, stop)
    return true
end
