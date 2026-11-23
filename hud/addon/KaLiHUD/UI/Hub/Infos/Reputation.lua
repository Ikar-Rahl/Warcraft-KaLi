-- The character's reputations (Ikar 2026-11-17, offered a reputation of its own for each progress bar: "We can add a
-- reputation folder"): one item for each faction the game's reputation pane lists for this character, its standing
-- in that standing's colour and how far into it, as the pane and the progress bar read them (C_Reputation). They
-- stand in the reputations' folder, any of them dragged from it onto the bar; a faction met shows at once, one the
-- pane no longer lists (under a header the player folded there) goes until it does again. A click opens the pane; its
-- menu has the game's own « Afficher comme barre d'expérience », which a progress bar set on the reputation shows.
-- Nothing kept: each read from the game's calls.
local _, ns = ...

local Infos, Hub, L, Format = ns.Infos, ns.Hub, ns.L, ns.Format

local Reputation = {}
ns.Reputation = Reputation

local PREFIX = "KaLiHUD_Reputation_"
Reputation.PREFIX = PREFIX

-- The factions as last read, by id: { name, description, standing, colour, value, max, capped, watched }.
local have = {}
local made = {}
-- How many were made: one met later goes after the others in its folder.
local count = 0

-- A standing's colour as a text's, "aarrggbb": the game's own for its bars, white without one.
local function colourOf(reaction)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if type(c) ~= "table" or not c.r then
        return "ffffffff"
    end
    return string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- A faction of the pane's as an item reads it: its standing by its name for the character ("Honoré", "Honorée": the
-- game's own, by the character's sex, as UI/StatusBars.lua's), how far into it, none at the last one.
local function reading(data)
    local reaction = data.reaction or 4
    local key = "FACTION_STANDING_LABEL" .. reaction
    local low, high = data.currentReactionThreshold or 0, data.nextReactionThreshold or 0
    local max = high - low
    return {
        name = data.name, description = data.description,
        standing = ns.Call(GetText, key, ns.Call(UnitSex, "player")) or ns.G(key, ""),
        colour = colourOf(reaction),
        value = (data.currentStanding or 0) - low, max = max,
        capped = reaction >= (MAX_REPUTATION_REACTION or 8) or max <= 0,
        watched = data.isWatched == true,
    }
end

local function textOf(f)
    local text = f.name .. " " .. Infos.Color(f.standing, f.colour)
    if not f.capped then
        text = text .. " " .. Format.Percent(f.value / f.max)
    end
    return text
end

local function tooltip(id)
    return function(tt)
        local f = have[id]
        if not f then
            return
        end
        Infos.Title(tt, f.name)
        if f.standing ~= "" then
            Infos.Text(tt, Infos.Color(f.standing, f.colour), false)
        end
        if not f.capped then
            Infos.Line(tt, ns.G("REPUTATION", L.STATUS_rep), Format.Number(f.value) .. " / " .. Format.Number(f.max))
            Infos.Line(tt, "", string.format(L.STATUS_TO_GO, Format.Number(math.max(0, f.max - f.value))))
        end
        if type(f.description) == "string" and f.description ~= "" then
            Infos.Hint(tt, f.description)
        end
        Infos.Hint(tt, L.HINT_XP)
    end
end

local read

-- The game's own watched faction, the one a progress bar set on the reputation shows: this one, or none if it is.
local function watch(id)
    local f = have[id]
    if not (f and C_Reputation) then
        return
    end
    ns.Call(C_Reputation.SetWatchedFactionByID, f.watched and 0 or id)
    ns.Later("infos reputations", read)
    ns.SafeCall(ns.StatusBars.Refresh)
end

local function object(id)
    local o = made[id]
    if o then
        return o
    end
    o = {
        type = "data source", text = "", category = "reputations", home = "reputations",
        available = function()
            return have[id] ~= nil
        end,
        OnTooltipShow = tooltip(id),
        OnClick = Infos.Opener(function()
            ToggleCharacter("ReputationFrame")
        end),
        menu = {
            { text = ns.G("SHOW_FACTION_ON_MAINSCREEN", L.REP_WATCH), checked = function()
                return have[id] ~= nil and have[id].watched
            end, func = function()
                watch(id)
            end },
        },
    }
    made[id] = o
    return o
end

-- The pane's factions read again: one item for each, made the first time; drawn again if one came or went. A header
-- with no standing of its own is none.
function read()
    local was = {}
    for id in pairs(have) do
        was[id] = true
    end
    wipe(have)
    -- in the pane's order: the first made are listed so
    local order = {}
    local n = C_Reputation and ns.Call(C_Reputation.GetNumFactions) or 0
    for i = 1, n do
        local data = ns.Call(C_Reputation.GetFactionDataByIndex, i)
        if type(data) == "table" and type(data.factionID) == "number" and type(data.name) == "string" and data.name ~= ""
            and (not data.isHeader or data.isHeaderWithRep) and not have[data.factionID] then
            have[data.factionID] = reading(data)
            order[#order + 1] = data.factionID
        end
    end
    local changed = false
    for _, id in ipairs(order) do
        local f = have[id]
        local name = PREFIX .. id
        if not made[id] then
            count = count + 1
            Hub.Add(name, object(id), "hidden", 1200 + count)
        end
        changed = changed or not was[id]
        was[id] = nil
        Hub.Set(name, "label", f.name)
        Hub.Set(name, "text", textOf(f))
    end
    if changed or next(was) then
        Hub.Changed()
    end
end

Infos.Updates(read, { "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" })
