-- The two status bars, « Barre de progression 1 » and « 2 » (Ikar 2026-11-15), drawn and filled as FlareUI's XP bar
-- (Ikar 2026-11-14: "Flare XP bar looks much better"; its code is MIT, adapted here; its art isn't, our textures are
-- tools/make_media.py's): a dark glazed track, the fill gliding forward (towards the map unless reversed), Blizzard's
-- blue once rested with the rested bonus ahead of it, a flash on each gain, 5 % bubbles, outlined numbers in four
-- formats, the percentage filled in an end cap at either end or none (the map's side by default), a tooltip with what's
-- left, the rested, the XP an hour and the time to the level; every setting each bar's own. Each side shows experience,
-- the watched reputation, honour or nothing (right click; Ikar 2026-11-15: no automatic choice), experience on the
-- left and the reputation on the right by default. They lie along the info bar under the bars the
-- plate takes, in to the map's ring, until dragged in Edit Mode: then each stays where it was let go, a frame the plate
-- takes within reach as any other. A bar with nothing to show isn't drawn; its place on the plate goes the next time
-- Edit Mode reads the game, the plate static outside it.
local _, ns = ...

local StatusBars = {}
ns.StatusBars = StatusBars

local Format = ns.Format
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
-- FlareUI's colours: Blizzard's XP purple and rested blue, the rested bonus lighter.
local XP, RESTED, REST_BONUS = { 0.58, 0, 0.549 }, { 0, 0.388, 0.878 }, { 0.4, 0.8, 1 }
local HONOR, REP = { 0.878, 0.325, 0.122 }, { 0, 0.6, 0.1 }
-- Drawn less vivid than the game's (Ikar 2026-11-15: "less saturated, a bit darker"): this much of their saturation,
-- this much of their light.
local SATURATION, SHADE = 0.7, 0.85
-- Under the fill, the dark ground and the track in the bar's texture; ahead of it, the rested bonus.
local GROUND, TRACK = { 0, 0, 0, 0.8 }, { 0.15, 0.15, 0.15, 0.9 }
local AHEAD = 0.55
-- What each side shows; its settings' keys start so.
local SIDES = { [-1] = "statusLeft", [1] = "statusRight" }
-- Where a bar dragged in Edit Mode is kept, in KaLiHUDDB.statusPlaces: { x, y, w }.
local PLACES = { [-1] = "left", [1] = "right" }
local KINDS = { "xp", "rep", "honor", "none" }
local NUMBERS = { "values", "percent", "both", "remaining" }
-- Each bar's end cap: at which end, and its shape ("auto": the corners'); its fill reversed, away from the map (Ikar
-- 2026-11-15: "right, left, or none, per bar, and type of cap").
local CAP_ENDS, CAP_SHAPES = { "right", "left", "none" }, { "auto", "bevel", "round", "square" }
-- Each bar's settings, its own (Ikar 2026-11-15: "make all the setting local to each bar"): "statusLeftCap" and so on.
local KEYS = {}
for side, key in pairs(SIDES) do
    KEYS[side] = { cap = key .. "Cap", shape = key .. "CapShape", reverse = key .. "Reverse", text = key .. "Text",
        texture = key .. "Texture", ticks = key .. "Ticks", numbers = key .. "Numbers", size = key .. "FontSize",
        width = key .. "Width" }
end
-- Each bar's own section in the Edit Mode dialog.
local SECTIONS = { [-1] = "barLeft", [1] = "barRight" }

-- A bar's name: the left one « Barre de progression 1 », the right one « 2 » (Ikar 2026-11-15).
function StatusBars.Name(side)
    return string.format(L.STATUS_BAR_NAME, side < 0 and 1 or 2)
end

local BUBBLES = 19 -- 20 classic 5% bubbles = 19 etched dividers
local INSET = 2
-- A bar's box: its text's size and this much room; its end cap this much taller each way, the slot that tall.
local BOX_ROOM, CAP_OVER = 3, 2
-- The percentage's digits this tall, a share of the text's size (Friz Quadrata's ink); their middle this much of it
-- under their line's (ascender 0.965 from its top, digits 0 to 0.746): lifted that much, as Blizzard lifts its XP bar's
-- text, they're centred.
local INK, LIFT = 0.76, 0.1
StatusBars.INK, StatusBars.LIFT = INK, LIFT
-- Round and square ends hug the percentage, where a pointed one's tip leaves it room: this much more each way, of the
-- text's size (Ikar 2026-11-15: it looked off to the right in them).
local CAP_ROOM = 0.2
StatusBars.CAP_ROOM = CAP_ROOM
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local bars = {}
local externalSaved = {}

-- A colour as the bars draw it, into `into`: towards its grey by SATURATION, darker by SHADE.
local function muted(c, into)
    local grey = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    for i = 1, 3 do
        into[i] = (grey + (c[i] - grey) * SATURATION) * SHADE
    end
    return into
end
local REST_DRAWN = muted(REST_BONUS, {})

local function barTexture(side)
    local kind = ns.db.options[KEYS[side].texture]
    if kind == "striped" then
        return ns.BAR_STRIPED
    elseif kind == "flat" then
        return WHITE
    end
    return ns.BAR_FOREVER
end

-- Where a side's bar was dragged in Edit Mode, or nil while it lies along the info bar.
local function placeOf(side)
    return ns.db.statusPlaces[PLACES[side]]
end

-- A side's end cap: the end it's at ("right" or "left"), nil for none, and its shape.
local function capOf(side)
    local o, k = ns.db.options, KEYS[side]
    local at, shape = o[k.cap], o[k.shape]
    return at ~= "none" and at or nil, shape == "auto" and o.cornerStyle or shape
end

-- A bar's box's height and its slot's, its cap's when it has one: one size, its text's (Ikar 2026-11-15: "no need for
-- 2 options").
local function heights(side)
    local box = ns.db.options[KEYS[side].size] + BOX_ROOM
    return box, capOf(side) and box + 2 * CAP_OVER or box
end

-- The slots' heights of the bars lying along the info bar, by side: 0 for one dragged elsewhere or showing nothing;
-- and the widths set, 0 for Auto. One table each, filled again at each layout.
local along, widths = {}, {}
function StatusBars.Heights()
    local o = ns.db.options
    for _, side in ipairs({ -1, 1 }) do
        local _, slot = heights(side)
        along[side] = (o[SIDES[side]] ~= "none" and not placeOf(side)) and slot or 0
    end
    return along
end

function StatusBars.Widths()
    local o = ns.db.options
    for _, side in ipairs({ -1, 1 }) do
        widths[side] = o[KEYS[side].width]
    end
    return widths
end

-- The row along the info bar: as tall as the taller bar in it, 0 when none is.
function StatusBars.RowHeight()
    local h = StatusBars.Heights()
    return math.max(h[-1], h[1])
end

-- Alpha 0 leaves a frame's mouse on: under a bar hidden so, each frame that takes the mouse (Blizzard's bars, the
-- rested tick, a button in MEDIUM over the info bar) is made deaf too, kept in `deaf` to be given it back. Edit Mode's
-- boxes ignore their parent's alpha and stay seen: they, and what's under them, are left as they are.
local function deafen(f, deaf)
    for _, child in ipairs({ f:GetChildren() }) do
        if not (child.IsIgnoringParentAlpha and child:IsIgnoringParentAlpha()) then
            if child:IsMouseEnabled() and not (InCombatLockdown() and child:IsProtected()) then
                deaf[child] = true
                child:EnableMouse(false)
            end
            deafen(child, deaf)
        end
    end
end

-- One the game protects waits for the fight's end, as deafen leaves it be during one: kept deaf, it is heard again
-- at the next change out of a fight.
local function hearAgain(deaf)
    for child in pairs(deaf) do
        if not (InCombatLockdown() and child:IsProtected()) then
            deaf[child] = nil
            child:EnableMouse(true)
        end
    end
end

local function syncExternalXP()
    local o = ns.db.options
    local hide = o.hideExternalXP and (o.statusLeft ~= "none" or o.statusRight ~= "none")
    for _, name in ipairs({ "StatusTrackingBarManager", "FlareUI_XPBar" }) do
        local f = _G[name]
        if type(f) == "table" then
            local st = externalSaved[name]
            if not st then
                st = {
                    alpha = f.GetAlpha and f:GetAlpha() or 1,
                    mouse = f.IsMouseEnabled and f:IsMouseEnabled(),
                    hooked = false,
                    deaf = {},
                }
                externalSaved[name] = st
            end
            if st.hidden ~= hide then
                st.hidden = hide
                if hide then
                    st.guard = true
                    if f.SetAlpha then
                        f:SetAlpha(0)
                    end
                    st.guard = false
                    if f.EnableMouse then
                        f:EnableMouse(false)
                    end
                    if f.GetChildren then
                        deafen(f, st.deaf)
                    end
                    if not st.hooked and f.SetAlpha then
                        st.hooked = true
                        hooksecurefunc(f, "SetAlpha", ns.Guarded(function(target, a)
                            if st.hidden and not st.guard and a > 0 then
                                st.guard = true
                                target:SetAlpha(0)
                                st.guard = false
                            end
                        end))
                    end
                else
                    st.guard = true
                    if f.SetAlpha then
                        f:SetAlpha(st.alpha or 1)
                    end
                    st.guard = false
                    if st.mouse ~= nil and f.EnableMouse then
                        f:EnableMouse(st.mouse)
                    end
                    hearAgain(st.deaf)
                end
            end
        end
    end
end

-- Below the cap, unless the game turned experience off: Blizzard's bar asks the same.
local function canShowXP()
    local rules = GameRulesUtil and GameRulesUtil.CanShowExperienceBar
    if rules then
        return ns.Call(rules) == true
    end
    local max = ns.Call(GetMaxLevelForPlayerExpansion)
    return not (type(max) == "number" and UnitLevel("player") >= max)
end

-- "4 120 / 9 800", "42 %", both, or what's left, as the side's own setting says.
local function numbers(value, max, side)
    local format = ns.db.options[KEYS[side].numbers]
    local percent = Format.Percent(max > 0 and math.min(1, value / max) or 0)
    if format == "percent" then
        return percent
    elseif format == "remaining" then
        return string.format(L.STATUS_TO_GO, Format.Number(math.max(0, max - value)))
    end
    local values = Format.Number(value) .. " / " .. Format.Number(max)
    return format == "both" and values .. " (" .. percent .. ")" or values
end

local function rgb(c, fallback)
    return type(c) == "table" and c.r and { c.r, c.g, c.b } or fallback
end

-- What a side's bar shows, read as Blizzard's bars read it: { kind, value, max, rested, colour, text, ... } or nil.
local Read = {}

function Read.xp(side)
    if not canShowXP() then
        return nil
    end
    local value, max = UnitXP("player"), UnitXPMax("player")
    if not (max and max > 0) then
        return nil
    end
    local rested = GetXPExhaustion() or 0
    return { kind = "xp", value = value, max = max, rested = rested, colour = rested > 0 and RESTED or XP,
        text = L.STATUS_XP .. "  " .. numbers(value, max, side), level = UnitLevel("player") }
end

-- The watched faction, paragon, renown and friendship included; at the top standing only its name shows, as Blizzard's.
function Read.rep(side)
    local data = C_Reputation and ns.Call(C_Reputation.GetWatchedFactionData)
    if type(data) ~= "table" or not data.name or data.name == "" then
        return nil
    end
    local id = data.factionID
    local low, high, value = data.currentReactionThreshold or 0, data.nextReactionThreshold or 1, data.currentStanding or 0
    local reaction, tint, capped, standing = data.reaction or 4, nil, false, nil
    if id and ns.Call(C_Reputation.IsFactionParagonForCurrentPlayer, id) then
        local current, threshold, _, pending = C_Reputation.GetFactionParagonInfo(id)
        threshold = threshold or 1
        low, high, value = 0, threshold, (current or 0) % threshold + (pending and threshold or 0)
    elseif id and ns.Call(C_Reputation.IsMajorFaction, id) then
        local major = C_MajorFactions and ns.Call(C_MajorFactions.GetMajorFactionData, id)
        low, high, value = 0, major and major.renownLevelThreshold or 1, major and major.renownReputationEarned or 0
        tint = RESTED
    else
        local friend = id and C_GossipInfo and ns.Call(C_GossipInfo.GetFriendshipReputation, id)
        if type(friend) == "table" and (friend.friendshipFactionID or 0) > 0 then
            reaction, standing = 5, friend.reaction
            if friend.nextThreshold then
                low, high, value = friend.reactionThreshold, friend.nextThreshold, friend.standing
            else
                capped = true
            end
        elseif reaction >= (MAX_REPUTATION_REACTION or 8) then
            capped = true
        end
    end
    local max = (high or 0) - (low or 0)
    value = (value or 0) - (low or 0)
    if capped or max <= 0 then
        value, max = 1, 1
    end
    tint = tint or rgb(FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction], REP)
    -- "Honoré", "Honorée": the game's own, by the character's sex
    local key = "FACTION_STANDING_LABEL" .. reaction
    standing = standing or ns.Call(GetText, key, ns.Call(UnitSex, "player")) or ns.G(key, "")
    return { kind = "rep", name = data.name, standing = standing, capped = capped, value = value, max = max, rested = 0,
        colour = tint, text = capped and data.name or data.name .. "  " .. numbers(value, max, side), id = id }
end

function Read.honor(side)
    local value, max = ns.Call(UnitHonor, "player"), ns.Call(UnitHonorMax, "player")
    if not (value and max and max > 0) then
        return nil
    end
    local faction = ns.Call(UnitFactionGroup, "player")
    local index = faction == "Alliance" and 1 or faction == "Horde" and 0 or nil
    return { kind = "honor", level = ns.Call(UnitHonorLevel, "player"), value = value, max = max, rested = 0,
        colour = rgb(index and PLAYER_FACTION_COLORS and PLAYER_FACTION_COLORS[index], HONOR),
        text = ns.G("HONOR", L.STATUS_honor) .. "  " .. numbers(value, max, side) }
end

-- A side's: what it's set to show, read as Blizzard's bars read it.
local function read(side)
    local kind = ns.db.options[SIDES[side]]
    return Read[kind] and Read[kind](side) or nil
end

local function showText(bar)
    bar.Text:SetShown(ns.db.options[KEYS[bar.side].text] == "always" or bar:IsMouseOver() or bar.Cap:IsMouseOver())
end

local function pixelSize(region)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    local scale = region and region.GetEffectiveScale and region:GetEffectiveScale()
    if not (factor and factor > 0 and scale and scale > 0) then
        return 1
    end
    return factor / scale
end

-- The 5 % bubbles, a dark and a lit line each, on whole pixels; laid out again only when the bar's size, the pixel
-- size or the option changed.
local function layoutTicks(bar, width, height)
    local show = ns.db.options[KEYS[bar.side].ticks] and width > 60
    local px = pixelSize(bar)
    if bar._tw == width and bar._th == height and bar._tpx == px and bar._tshow == show then
        return
    end
    bar._tw, bar._th, bar._tpx, bar._tshow = width, height, px, show
    local total = math.floor(width / px + 0.5)
    for i = 1, BUBBLES do
        local dark, light = bar.Ticks[i], bar.TickLights[i]
        if show then
            local x = math.floor(total * i / (BUBBLES + 1) + 0.5) * px
            dark:ClearAllPoints()
            dark:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x - px, 0)
            dark:SetSize(px, height)
            dark:Show()
            light:ClearAllPoints()
            light:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
            light:SetSize(px, height)
            light:Show()
        else
            dark:Hide()
            light:Hide()
        end
    end
end

-- The bar's texture on the fill, the track and the rested bonus; its numbers and its label outlined, at their size.
local function look(bar)
    local tex = barTexture(bar.side)
    if bar._tex ~= tex then
        bar._tex = tex
        bar:SetStatusBarTexture(tex)
        for _, layer in ipairs({ bar.Track, bar.Rested }) do
            layer:SetTexture(tex)
        end
        -- the gain's flash covers the fill only, which exists once the texture is set
        bar.Flash:ClearAllPoints()
        bar.Flash:SetAllPoints(bar:GetStatusBarTexture() or bar)
    end
    local size = ns.db.options[KEYS[bar.side].size]
    local font = GameFontHighlightSmall:GetFont()
    if font and bar.Text.kaliSize ~= size then
        bar.Text:SetFont(font, size, "OUTLINE")
        bar.Label:SetFont(font, size, "OUTLINE")
        bar.Text.kaliSize = size
        local lift = size * LIFT
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("LEFT", 4, lift)
        bar.Text:SetPoint("RIGHT", -4, lift)
        bar.Label:ClearAllPoints()
        bar.Label:SetPoint("CENTER", 0, lift)
    end
end

-- An end cap's width, h tall: the percentage at the text's size, two digits wide or "100 %" while it says so (Ikar
-- 2026-11-15: "reduce ... the width"), its ends past it as far as their shape needs.
local function capWidth(bar, h, style)
    local size = bar.Text.kaliSize
    if bar._labelFor ~= size or not bar._twoW then
        local was = bar.Label:GetText()
        bar._full = Format.Percent(1)
        bar.Label:SetText(Format.Percent(0.88))
        bar._twoW = math.ceil(bar.Label:GetStringWidth())
        bar.Label:SetText(bar._full)
        bar._fullW = math.ceil(bar.Label:GetStringWidth())
        bar.Label:SetText(was)
        bar._labelFor = size
    end
    local label = bar.Label:GetText() == bar._full and bar._fullW or bar._twoW
    local room = style == "bevel" and 0 or size * CAP_ROOM
    return label + 2 * (ns.Border.CapEnds(h, size * INK / 2, style) + room)
end

-- How far into an end cap (its ends r round) the track runs: past the cap's side at the track's top and foot (half its
-- height from the middle), under its metal.
local function tuck(style, r, half)
    if style == "bevel" then
        return half + 1
    elseif style == "round" then
        return r - math.sqrt(math.max(0, r * r - half * half)) + 1
    end
    return 1
end

-- A bar into its slot (x, y, w, h): its bordered box there, the fill inside it, from the end its side and option say;
-- with an end cap, the cap at that end of the slot, as tall as the slot, over the box's end, the track running under
-- its metal. Set again only when something changed.
local function put(bar, slot)
    look(bar)
    bar.slot = slot
    local at, shape = capOf(bar.side)
    local reverse = (bar.side > 0) ~= ns.db.options[KEYS[bar.side].reverse]
    local fw, fh = math.max(slot.w, 4), math.max(slot.h, 4)
    local box = math.min((heights(bar.side)), fh)
    local cw = at and capWidth(bar, fh, shape) or 0
    local track = math.max(box - 2 * INSET, 1)
    if bar._x ~= slot.x or bar._y ~= slot.y or bar._fw ~= fw or bar._fh ~= fh or bar._cw ~= cw or bar._box ~= box
        or bar._style ~= shape or bar._at ~= at or bar._reverse ~= reverse then
        bar._x, bar._y, bar._fw, bar._fh, bar._cw, bar._box = slot.x, slot.y, fw, fh, cw, box
        bar._style, bar._at, bar._reverse = shape, at, reverse
        local y = slot.y + (fh - box) / 2
        -- the track's ends from the slot's left, the one at the cap under its metal
        local under = cw > 0 and cw - tuck(shape, fh / 2, track / 2) or INSET
        local left, right = at == "left" and under or INSET, at == "right" and fw - under or fw - INSET
        bar.Holder:ClearAllPoints()
        bar.Holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", slot.x + (at == "left" and cw / 2 or 0), y)
        bar.Holder:SetSize(fw - cw / 2, box)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", slot.x + left, y + INSET)
        bar.width = math.max(right - left, 1)
        bar:SetSize(bar.width, track)
        if cw > 0 then
            bar.Cap:ClearAllPoints()
            bar.Cap:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", slot.x + (at == "left" and 0 or fw - cw), slot.y)
            bar.Cap:SetSize(cw, fh)
        end
        -- the fill and the rested bonus grow from the bar's start
        bar:SetReverseFill(reverse)
        local from = reverse and "RIGHT" or "LEFT"
        bar.Rested:ClearAllPoints()
        bar.Rested:SetPoint("TOP" .. from)
        bar.Rested:SetPoint("BOTTOM" .. from)
        bar.Selection:ClearAllPoints()
        bar.Selection:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", slot.x, slot.y)
        bar.Selection:SetSize(fw, fh)
    end
    local d = bar.Cap.Border
    if d.role.style ~= shape then
        d.role.style = shape
        ns.Border.Update(d)
    end
    layoutTicks(bar, bar.width, track)
end

-- A layer from the bar's left end to `reach` (a fraction of it), under the fill: what shows of it runs ahead.
local function ahead(bar, layer, reach, tint, alpha)
    if reach then
        layer:SetWidth(math.max(1, math.min(1, reach) * (bar.width or 1)))
        layer:SetVertexColor(tint[1], tint[2], tint[3], alpha)
        layer:Show()
    else
        layer:Hide()
    end
end

local function pair(left, right, tint)
    tint = tint or { 1, 1, 1 }
    GameTooltip:AddDoubleLine(left, right, 1, 1, 1, tint[1], tint[2], tint[3])
end

local function counted(value, max)
    return Format.Number(value) .. " / " .. Format.Number(max) .. " (" .. Format.Percent(max > 0 and value / max or 0) .. ")"
end

-- FlareUI's tooltip: experience with what's left, the rested, the XP an hour and the time to the level, then what
-- raises the experience gained and their sum; a reputation with its standing and what raises it; honour with its level.
local function tooltip(bar)
    local info = bar.info
    if not info then
        return
    end
    GameTooltip:SetOwner(bar, "ANCHOR_TOP")
    if info.kind == "xp" then
        GameTooltip:SetText(string.format(L.XP_LEVEL, info.level or UnitLevel("player")), 1, 0.82, 0)
        pair(L.ITEM_XP, counted(info.value, info.max))
        pair(L.STATUS_XP_LEFT, Format.Number(math.max(0, info.max - info.value)))
        if info.rested > 0 then
            pair(L.XP_RESTED, Format.Number(info.rested) .. " (" .. Format.Percent(info.rested / info.max) .. ")", REST_BONUS)
        end
        local rate, toLevel = ns.Items.XPRate()
        if rate > 0 then
            pair(L.XP_PER_HOUR, Format.Short(rate))
            pair(L.XP_TO_LEVEL, Format.Duration(toLevel))
        end
        -- what raises the experience gained now, each its share, of the creatures' or the quests' where they differ,
        -- then their sum with the game's question mark: the game doesn't say how they add up (UI/Hub/Infos/Stats.lua's
        -- XPBonuses; Ikar 2026-11-23: "the xp bar shoudl also have all the bonuses listed (and the total)")
        local bonuses = ns.Stats and ns.Stats.XPBonuses and ns.Stats.XPBonuses() or {}
        if #bonuses > 0 then
            local function share(kills, quests)
                local function plus(v)
                    return "+" .. Format.Percent(v / 100)
                end
                if kills == quests then
                    return plus(kills)
                end
                local out = {}
                if kills ~= 0 then
                    out[#out + 1] = string.format(L.XP_ON_KILLS, plus(kills))
                end
                if quests ~= 0 then
                    out[#out + 1] = string.format(L.XP_ON_QUESTS, plus(quests))
                end
                return table.concat(out, ", ")
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.XP_BONUSES, 1, 0.82, 0)
            local kills, quests = 0, 0
            for _, bonus in ipairs(bonuses) do
                kills, quests = kills + bonus.kills, quests + bonus.quests
                pair(bonus.name, share(bonus.kills, bonus.quests))
            end
            if #bonuses > 1 then
                pair(L.XP_TOTAL .. " " .. ns.Stats.UNKNOWN, share(kills, quests))
                GameTooltip:AddLine(ns.Stats.UNKNOWN .. " " .. L.XP_SUMMED, 0.5, 0.5, 0.5, true)
            end
        end
    elseif info.kind == "rep" then
        GameTooltip:SetText(info.name, 1, 0.82, 0)
        if info.standing ~= "" then
            GameTooltip:AddLine(info.standing, info.colour[1], info.colour[2], info.colour[3])
        end
        if not info.capped then
            pair(ns.G("REPUTATION", L.STATUS_rep), counted(info.value, info.max))
        end
        -- what raises the reputation gained with it now (Ikar 2026-11-23: "Reputation bonuses to the rep bar"), their
        -- sum with the game's question mark where there are several, as the experience's (UI/Hub/Infos/Stats.lua's
        -- RepBonuses)
        local raises = info.id and ns.Stats and ns.Stats.RepBonuses and ns.Stats.RepBonuses(info.id) or {}
        if #raises > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.REP_BONUSES, 1, 0.82, 0)
            local sum = 0
            for _, bonus in ipairs(raises) do
                sum = sum + bonus.share
                pair(bonus.name, "+" .. Format.Percent(bonus.share / 100))
            end
            if #raises > 1 then
                pair(L.XP_TOTAL .. " " .. ns.Stats.UNKNOWN, "+" .. Format.Percent(sum / 100))
                GameTooltip:AddLine(ns.Stats.UNKNOWN .. " " .. L.XP_SUMMED, 0.5, 0.5, 0.5, true)
            end
        end
    else
        GameTooltip:SetText(ns.G("HONOR", L.STATUS_honor), 1, 0.82, 0)
        local label = ns.G("HONOR_LEVEL_LABEL", "")
        if info.level and label ~= "" then
            GameTooltip:AddLine(string.format(label, info.level), 1, 1, 1)
        end
        pair(ns.G("HONOR", L.STATUS_honor), counted(info.value, info.max))
    end
    GameTooltip:AddLine(L.STATUS_RIGHT_CLICK, 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

-- Whether a side's bar has its place on the plate: set to show something that it had to show as the plate was frozen
-- (Ikar 2026-11-15: the plate doesn't change with what happens in game; a bar at the level cap leaves it the next
-- time Edit Mode reads the game); live in Edit Mode, or once set to show something else.
local function hasPlace(side)
    local kind = ns.db.options[SIDES[side]]
    if kind == "none" then
        return false
    end
    local had = ns.Plate.FrozenBar(PLACES[side])
    if had and had.kind == kind then
        return had.shows
    end
    return read(side) ~= nil
end

-- What each bar shows, for the plate's freeze: { left = { kind, shows }, right = ... }.
function StatusBars.Shows()
    local out = {}
    for side, key in pairs(PLACES) do
        out[key] = { kind = ns.db.options[SIDES[side]], shows = read(side) ~= nil }
    end
    return out
end

-- gained: experience just came in, the fill flashes. The plate keeps the bar's place shown or not.
local function update(bar, _, gained)
    look(bar)
    local info = bar.slot and read(bar.side)
    local wasShown = bar:IsShown()
    if not info then
        bar:Hide()
        bar.Holder:Hide()
        bar.Cap:Hide()
        bar.info = nil
    else
        local fraction = info.max > 0 and math.min(1, info.value / info.max) or 0
        -- it glides forward only: a level-up or another faction lands at once, not sliding back across the bar
        if SMOOTH and wasShown and bar.kind == info.kind and bar.fraction and fraction >= bar.fraction then
            bar:SetValue(fraction, SMOOTH)
        else
            bar:SetValue(fraction)
        end
        bar.fraction, bar.kind = fraction, info.kind
        local c = muted(info.colour, bar.tint)
        bar:SetStatusBarColor(c[1], c[2], c[3])
        local rested = info.rested or 0
        ahead(bar, bar.Rested, rested > 0 and (info.value + rested) / info.max, REST_DRAWN, AHEAD)
        bar.Text:SetText(info.text)
        bar.Label:SetText(Format.Percent(fraction))
        -- "100 %" takes a wider cap than two digits
        put(bar, bar.slot)
        -- the cap in the bar's colour
        local tint = bar.Cap.Border.tint
        if not (tint and tint[1] == c[1] and tint[2] == c[2] and tint[3] == c[3]) then
            ns.Border.Tint(bar.Cap.Border, c[1], c[2], c[3])
        end
        bar.info = info
        showText(bar)
        bar.Holder:Show()
        bar:Show()
        bar.Cap:SetShown((bar._cw or 0) > 0)
        if gained and info.kind == "xp" then
            bar.Flash.anim:Stop()
            bar.Flash.anim:Play()
        end
        if GameTooltip:IsOwned(bar) then
            tooltip(bar)
        end
    end
end

-- Puts the bars not dragged elsewhere where the plate says, along the info bar (Geometry.StatusSlots), and fills them.
-- Returns the slots of those that show, for the plate to draw. fast (live drags): placed without reading what they show
-- again; a bar where it was isn't touched.
function StatusBars.Place(slots, fast)
    local shown = {}
    for _, side in ipairs({ -1, 1 }) do
        local bar = bars[side]
        if bar and not placeOf(side) then
            local hadSlot = bar.slot ~= nil
            local slot = slots[side]
            if slot then
                put(bar, slot)
            else
                bar.slot = nil
            end
            if not fast or not hadSlot or not slot then
                update(bar, true)
            end
            if slot and hasPlace(side) then
                shown[#shown + 1] = slot
            end
        end
    end
    if not fast then
        syncExternalXP()
    end
    return shown
end

-- Puts the bars dragged in Edit Mode where they were let go, at the width set or the one they had, and fills them as
-- Place does. Returns those that show as frames for the plate, which takes them within reach as any other: key, kind,
-- place, size, no padding and the status bars' margin.
function StatusBars.PlaceMoved(margin, fast)
    local o, out = ns.db.options, {}
    for _, side in ipairs({ -1, 1 }) do
        local bar, p = bars[side], placeOf(side)
        if bar and p then
            local hadSlot = bar.slot ~= nil
            local _, h = heights(side)
            local w = o[KEYS[side].width]
            local slot = { key = "status" .. side, kind = "status", x = p.x, y = p.y, h = h, pad = 0,
                w = w > 0 and w or p.w, margin = margin }
            put(bar, slot)
            if not fast or not hadSlot then
                update(bar, true)
            end
            if hasPlace(side) then
                out[#out + 1] = slot
            end
        end
    end
    return out
end

-- Experience came in since the last look: the XP or the level went up.
local last = {}
local function gainedXP()
    local value, level = UnitXP("player"), UnitLevel("player")
    local gained = last.value ~= nil and (level > last.level or level == last.level and value > last.value)
    last.value, last.level = value, level
    return gained
end

-- Fills the bars where they are; one that starts or stops showing has the plate redrawn.
function StatusBars.Refresh()
    syncExternalXP()
    local gained = gainedXP()
    for _, bar in pairs(bars) do
        if bar.slot then
            put(bar, bar.slot)
        end
        update(bar, false, gained)
    end
end

function StatusBars.Request()
    ns.Later("status", StatusBars.Refresh)
end

local function menu(owner, root)
    local o = ns.db.options
    -- what an entry does, under the handlers' guard (ns.Guarded), as the hub's menus
    local function radios(parent, key, values, prefix)
        for _, v in ipairs(values) do
            parent:CreateRadio(L[prefix .. v], function()
                return o[key] == v
            end, ns.Guarded(function()
                o[key] = v
                StatusBars.Refresh()
                ns.Plate.Request()
            end))
        end
    end
    local side = owner.side
    local k = KEYS[side]
    root:CreateTitle(StatusBars.Name(side))
    radios(root, SIDES[side], KINDS, "STATUS_")
    root:CreateDivider()
    root:CreateCheckbox(L.STATUS_ALWAYS, function()
        return o[k.text] == "always"
    end, ns.Guarded(function()
        o[k.text] = o[k.text] == "always" and "hover" or "always"
        showText(owner)
    end))
    root:CreateCheckbox(L.STATUS_TICKS, function()
        return o[k.ticks]
    end, ns.Guarded(function()
        o[k.ticks] = not o[k.ticks]
        StatusBars.Refresh()
    end))
    local cap = root:CreateButton(L.OPT_STATUS_CAP)
    radios(cap, k.cap, CAP_ENDS, "CAP_")
    cap:CreateDivider()
    cap:CreateTitle(L.OPT_STATUS_SHAPE)
    radios(cap, k.shape, CAP_SHAPES, "SHAPE_")
    root:CreateCheckbox(L.OPT_STATUS_REVERSE, function()
        return o[k.reverse]
    end, ns.Guarded(function()
        o[k.reverse] = not o[k.reverse]
        StatusBars.Refresh()
    end))
    radios(root:CreateButton(L.OPT_STATUS_NUMBERS), k.numbers, NUMBERS, "NUM_")
end
menu = ns.Guarded(menu)
StatusBars.Menu = menu

-- Edit Mode: a box over each bar, as over Blizzard's frames. A click opens KaLi HUD's dialog at the bar's own settings;
-- a drag moves the bar under the pointer, the plate following, and it stays where it's let go.
local dragging

local function cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function dragTo()
    local d = dragging
    local x, y = cursor()
    d.place.x = math.max(0, math.min(UIParent:GetWidth() - d.w, x - d.dx))
    d.place.y = math.max(0, math.min(UIParent:GetHeight() - d.h, y - d.dy))
    ns.Plate.Redraw(true)
end

local function dragStart(bar)
    local s = bar.slot
    if not s then
        return
    end
    local places, key = ns.db.statusPlaces, PLACES[bar.side]
    places[key] = places[key] or { x = s.x, y = s.y, w = s.w }
    local x, y = cursor()
    dragging = { place = places[key], dx = x - s.x, dy = y - s.y, w = s.w, h = s.h }
    -- An error there lets go of the bar where it last was (ns.EveryFrame).
    ns.EveryFrame(bar.Selection, dragTo, function()
        dragging = nil
        ns.Plate.Request()
    end)
end

local function dragStop(bar)
    ns.EveryFrame(bar.Selection, nil)
    if dragging then
        dragTo()
        dragging = nil
        ns.Plate.Request()
        ns.EditPanel.Changed()
    end
end

-- The boxes show while Edit Mode is open; a drag still going when it closes stops there.
function StatusBars.SyncEdit()
    local editing = ns.Frames.IsEditing()
    for _, bar in pairs(bars) do
        if editing then
            bar.Selection:ShowHighlighted()
        else
            bar.Selection:SetScript("OnUpdate", nil)
            bar.Selection:Hide()
        end
    end
    if not editing then
        dragging = nil
    end
end

-- A bar dragged elsewhere back along the info bar.
function StatusBars.PutBack(side)
    ns.db.statusPlaces[PLACES[side]] = nil
    ns.ApplyAll()
end

local function build(side)
    local holder = CreateFrame("Frame", nil, nil)
    holder:SetParent(UIParent)
    holder:SetFrameStrata("LOW")
    holder:EnableMouse(false)
    holder.Ground = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    holder.Ground:SetAllPoints()
    holder.Ground:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], GROUND[4])

    local bar = CreateFrame("StatusBar", nil, nil)
    bar:SetParent(UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel((holder:GetFrameLevel() or 1) + 2)
    bar:SetMinMaxValues(0, 1)
    bar.side = side
    bar.Holder = holder
    bar.tint = {}

    bar.Track = bar:CreateTexture(nil, "BACKGROUND")
    bar.Track:SetAllPoints()
    bar.Track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    -- ahead of the fill, from the bar's left end: the rested bonus
    bar.Rested = bar:CreateTexture(nil, "BORDER", nil, -1)
    bar.Rested:SetPoint("TOPLEFT")
    bar.Rested:SetPoint("BOTTOMLEFT")
    bar.Rested:Hide()
    -- a short light over the fill on each gain
    local flash = bar:CreateTexture(nil, "OVERLAY")
    flash:SetColorTexture(1, 1, 1, 1)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    local anim = flash:CreateAnimationGroup()
    local up = anim:CreateAnimation("Alpha")
    up:SetFromAlpha(0)
    up:SetToAlpha(0.35)
    up:SetDuration(0.15)
    up:SetOrder(1)
    local down = anim:CreateAnimation("Alpha")
    down:SetFromAlpha(0.35)
    down:SetToAlpha(0)
    down:SetDuration(0.5)
    down:SetOrder(2)
    flash.anim = anim
    bar.Flash = flash

    holder.Border = ns.Border.Attach(holder, { level = 4, bg = false })
    holder.Border:EnableMouse(false)

    bar.Ticks, bar.TickLights = {}, {}
    for i = 1, BUBBLES do
        local dark = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        dark:SetTexture(WHITE)
        dark:SetVertexColor(0, 0, 0, 0.72)
        dark:Hide()
        bar.Ticks[i] = dark
        local light = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        light:SetTexture(WHITE)
        light:SetVertexColor(1, 1, 1, 0.20)
        light:Hide()
        bar.TickLights[i] = light
    end
    local textHolder = CreateFrame("Frame", nil, bar)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(bar:GetFrameLevel() + 4)
    textHolder:EnableMouse(false)
    bar.Text = textHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", 4, 0)
    bar.Text:SetPoint("RIGHT", -4, 0)
    bar.Text:SetWordWrap(false)
    -- the percentage's end cap, over the box's right end, the bar and its text: its border and colour (Border's), the
    -- percentage over them
    local cap = CreateFrame("Frame", nil, nil)
    cap:SetParent(UIParent)
    cap:SetFrameStrata("LOW")
    cap:SetFrameLevel((holder:GetFrameLevel() or 1) + 8)
    cap.Border = ns.Border.Attach(cap, { level = 1, cap = true })
    cap.Border:EnableMouse(false)
    local capText = CreateFrame("Frame", nil, cap)
    capText:SetAllPoints()
    capText:SetFrameLevel(cap:GetFrameLevel() + 2)
    capText:EnableMouse(false)
    bar.Label = capText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Label:SetPoint("CENTER")
    bar.Label:SetWordWrap(false)
    cap:Hide()
    bar.Cap = cap
    local function enter()
        showText(bar)
        tooltip(bar)
    end
    local function leave()
        showText(bar)
        if GameTooltip:IsOwned(bar) then
            GameTooltip:Hide()
        end
    end
    local function click(_, button)
        if button == "RightButton" then
            -- the menu takes the tooltip away, as every menu of the HUD (UI/Hub/Menus.lua's OpenElement)
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(bar, menu)
        end
    end
    -- under the handlers' guard (ns.Guarded), the same three for the bar and its cap
    enter, leave, click = ns.Guarded(enter), ns.Guarded(leave), ns.Guarded(click)
    for _, f in ipairs({ bar, cap }) do
        f:EnableMouse(true)
        f:SetScript("OnEnter", enter)
        f:SetScript("OnLeave", leave)
        f:SetScript("OnMouseUp", click)
    end
    -- over the whole slot, the cap's too: put() places it
    local sel = CreateFrame("Frame", nil, holder, "EditModeSystemSelectionTemplate")
    sel:SetSystem({ GetSystemName = function()
        return StatusBars.Name(side)
    end })
    sel:SetScript("OnMouseDown", function()
        ns.SafeCall(ns.EditFrame.Select, SECTIONS[side])
    end)
    sel:SetScript("OnDragStart", function()
        ns.SafeCall(dragStart, bar)
    end)
    sel:SetScript("OnDragStop", function()
        ns.SafeCall(dragStop, bar)
    end)
    sel:Hide()
    bar.Selection = sel
    holder:Hide()
    bar:Hide()
    bars[side] = bar
end

function StatusBars.Start()
    build(-1)
    build(1)
    StatusBars.bars = bars
    -- a new zone may start or end a battleground's honour
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN",
        "DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
        "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "HONOR_XP_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
        ns.On(event, StatusBars.Request)
    end
    -- the player's level alone, not every unit's (UI/Hub/Infos/Infos.lua's OnPlayer)
    ns.Infos.OnPlayer("UNIT_LEVEL", StatusBars.Request)
    ns.On("CVAR_UPDATE", function(_, name)
        if name == "showHonorAsExperience" then
            StatusBars.Request()
        end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        for _, event in ipairs({ "EditMode.Enter", "EditMode.Exit" }) do
            EventRegistry:RegisterCallback(event, function()
                ns.SafeCall(StatusBars.SyncEdit)
            end, StatusBars)
        end
    end
    StatusBars.SyncEdit()
    StatusBars.Refresh()
end
