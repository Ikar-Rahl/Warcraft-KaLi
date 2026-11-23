-- The info bar along the foot, and where the slot hub's elements are drawn: along the bar (from its left end, the
-- block below the minimap with the zone right under its centre, set free anywhere, from its right end, the padlock at
-- the far right), round the map (UI/Minimap.lua's dome: the ring, the plate's two lower pockets, what doesn't fit in
-- one beside the block below the map), in folders
-- (UI/Hub/Folders.lua). Drawn whole when the elements change (Refresh, once a frame however many ask); one element's
-- text or icon changing draws its button alone (Update); the dome moving puts back what stands by it (Reflow).
-- During a fight it holds (Ikar 2026-11-16, accepting it for folders that open and macros that run in combat): the
-- folders' and macros' buttons are secure, and the game forbids any addon to move, show, hide or size them then, nor
-- what holds them (the bar), so nothing is laid out; a text that grows past its place runs into its margin, and what
-- waited is drawn once the fight is over.
-- Since the review of 2026-11-17: an item keeps a place as wide as the widest it has needed, so a text that changes
-- moves nothing (Places that hold); what has no room on the bar leaves it for the list of the folder made for it
-- (What doesn't fit); one element failing to draw leaves the others theirs (HubButtons.SafeFill); a fight that starts
-- with the padlock open shuts it, to open again after.
local _, ns = ...

local InfoBar = {}
ns.InfoBar = InfoBar

local Hub, Buttons = ns.Hub, ns.HubButtons
local L = ns.L
local max, min = math.max, math.min

-- The bar's items start this far from the screen's left end, and from the padlock's place at its right end.
local EDGE_X, LOCK_W = 10, 22
-- The padlock's art (Media/Lock, Unlock): texels 7..25 across, 3..29 down of 32.
local LOCK_ART = { 7 / 32, 3 / 32, 25 / 32, 29 / 32 }
local EMPTY = {}

local bar, lockBtn
-- The last layout. rows: the bar's items by side, each { name, w, pos, x, y, b | native | foreign }; round: the
-- elements round the map but Blizzard's (UI/Hub/Natives.lua's); members: each folder's; then by name where each is.
local rows = { left = {}, free = {}, centre = {}, right = {} }
local round, members = {}, {}
local inRow, inRound, inFolder = {}, {}, {}
-- On the bar by name ({ x, w }), where its ends stop and the screen's edges for them, the block below the map.
local placed = {}
local ends = { left = EDGE_X, right = 0, leftEdge = EDGE_X, rightEdge = 0 }
local centreSpan, centre = { x0 = 0, x1 = 0 }, nil
-- pass: which full layout a button was last put out in; version: bumped each time the bar is laid out.
local pass, version = 0, 0
local dirty = false
local pending = {}
-- Something waited for the fight's end: a layout, a secure button's content, a width that changed.
local held = false
-- Full layouts, for the tests.
InfoBar.refreshes = 0
-- The widest each of our items on the bar has needed since the player last arranged it (Forget), by name: its place.
local places = {}
-- What had no room on the bar at the last layout, by name: the folder it was put in for now, false for nowhere.
local unfitted = {}

-- Where the plate's foot and the elements round the map stand: the info bar's top, or the screen's foot with the bar
-- off.
function InfoBar.Top()
    return ns.db.options.infoBar and Hub.BarHeight() or 0
end

-- With the bar off, whether an element shows nowhere: one that stands on the bar, or in a folder that does. The hub
-- then has no place for it, and another addon's button gathered there is given back to its addon, on the map, where
-- it can still be clicked (put away, it was out of reach, as was every button of LibDBIcon's: the review, 2026-11-16).
function InfoBar.OffBar(e)
    if ns.db.options.infoBar then
        return false
    end
    local side = e.side
    if side == "folder" then
        local folder = Hub.Entry(e.folder)
        side = folder and folder.side
    end
    return Hub.BAR[side] == true
end

-- An item on the bar: { x, w }, its centre and width; nil when it isn't on it.
function InfoBar.Placed(name)
    return placed[name]
end

-- Where the last layout drew an element: "bar", the id of the folder whose list holds it (its own, or the one for
-- what doesn't fit), "round" for one of ours round the map; nil for nowhere.
function InfoBar.Where(name)
    if placed[name] then
        return "bar"
    end
    return inFolder[name] or inRound[name] and "round" or nil
end

-- What had no room on the bar at the last layout, { [name] = the folder it's in for now, or false }: read it, never
-- change it.
function InfoBar.Unfitted()
    return unfitted
end

-- ---------- Places that hold ----------
-- Nothing moves on a game event outside Edit Mode (Ikar 2026-11-16, of the mail's place). A text that lost or gained a
-- letter moved everything laid out after it (the review of 2026-11-17: the frame rate crossing 100 shifted the whole
-- right side, each time), so an item keeps a place as wide as the widest it has needed, its text at its left: a text
-- that grows widens its place once, one that shrinks leaves it. Forgotten when the player arranges the bar himself (a
-- drag, a menu, an undo, the padlock, a setting): then each takes its width again.
local function hold(name, w)
    -- the zone keeps to its own width: it stands centred under the map, and a place wider than its name would leave
    -- that name to one side of the centre
    if Hub.IsFixed(name) then
        return w
    end
    local widest = places[name]
    if not widest or w > widest then
        places[name] = w
        return w
    end
    return widest
end

function InfoBar.Forget()
    wipe(places)
end

-- The bar's ends: { left, right } where its end items stop, { leftEdge, rightEdge } where the first ones start.
function InfoBar.Ends()
    return ends
end

-- The block below the minimap, { x0, x1 }, or nil.
function InfoBar.Centre()
    return centre
end

function InfoBar.Version()
    return version
end

-- A button a folder's list put out in this layout: not hidden after it.
function InfoBar.Keep(b)
    b._pass = pass
end

-- ---------- The padlock ----------
-- A block closing the bar at its right end (Ikar 2026-11-20: "a separate design for the bar cap. Maybe a slightly
-- bigger rectangle with the lock? With textures, something that look nice and catches the eye when enabled", then "go
-- for bloc", picked from sketches drawn over the game's own bar; nothing that implies a style, as it is the same in
-- all, the padlock kept, a cap closing the bar rather than a button on it): flush with the screen's edge and foot, a
-- little taller than the bar, the border's metal lit from the top and brushed along (Media/BandGrain.tga's specks, as
-- the border carries them, run across), its top and left side catching the light, its shadow on the bar beside it, the
-- padlock carved in over the bar's middle. Shut, the HUD used: the metal, the padlock dark in it. Open, the HUD arranged
-- as in Edit Mode, every right-click the hub's (UI/Hub/Menus.lua), it says so ("when unlocked, it should be gold
-- background, clearly visible. Maybe with a small aura around?"): the whole block the game's gold (NORMAL_FONT_COLOR),
-- the open padlock dark on it, and a soft gold aura round it that fades in once as it opens, then holds still, as Edit
-- Mode's selection does: nothing of the HUD moves at rest (the game's own glows stop). Hover lights it.
-- Its size from the bar's height (the sketch's at 4K: 56 by 36 over a bar 31 tall, the padlock 17): this many times as
-- wide, this much of it above the bar's top, the padlock this tall.
local LOCK_WIDE, LOCK_RISE, LOCK_SIZE = 1.8, 0.16, 0.55
-- The metal at the block's top, middle and foot, of the border's colour; the gold's top this much nearer white, its
-- foot this much of it.
local METAL, GOLD_TOP, GOLD_FOOT = { 0.95, 0.62, 0.36 }, 0.6, 0.55
-- Its edges: the dark line along its top and down its left side, the lit one inside it, the shadow it casts on the bar
-- this wide and dark.
local EDGE_DARK, TOP_LIT, SIDE_LIT = { 0.07, 0.05, 0.02, 0.8 }, { 1, 0.96, 0.88, 0.55 }, { 1, 0.96, 0.88, 0.22 }
local SHADOW_W, SHADOW_A = 5, 0.6
-- The padlock carved: dark, its lower lip lit a pixel under it; on the gold, dark brown.
local CARVED, CARVED_LIP, LOCK_DARK = { 0.11, 0.08, 0.04 }, { 1, 0.95, 0.84, 0.35 }, { 0.16, 0.1, 0.02 }
-- The aura: how far past the block, how strong, how fast it comes (the game's acknowledgements: under 0.3 s).
local AURA_REACH, AURA_ALPHA, AURA_IN = 7, 0.8, 0.3
-- On hover, the gold this much nearer white, the metal this much brighter.
local HOVER_LIGHT = 0.18
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function gold()
    local c = NORMAL_FONT_COLOR
    if type(c) == "table" and c.GetRGB then
        return c:GetRGB()
    end
    return 1, 0.82, 0
end

-- The room the padlock takes at the bar's right end: its block, as wide as it is at this size, LOCK_W at the least.
local function lockRoom()
    return math.max(LOCK_W, lockBtn and lockBtn._w or 0)
end

-- One half of the block lit from its foot (lo) to its top (hi), each { r, g, b }.
local function shade(t, lo, hi)
    t.lo:SetRGBA(lo[1], lo[2], lo[3], 1)
    t.hi:SetRGBA(hi[1], hi[2], hi[3], 1)
    t:SetGradient("VERTICAL", t.lo, t.hi)
end

local top, mid, foot = {}, {}, {}

function InfoBar.UpdateLock()
    if not lockBtn then
        return
    end
    local locked, hover = Hub.IsLocked(), lockBtn._hover == true
    local barH = Hub.BarHeight()
    local rise = math.max(math.floor(barH * LOCK_RISE + 0.5), 2)
    local w, h = math.ceil(barH * LOCK_WIDE), barH + rise
    if lockBtn._w ~= w or lockBtn._h ~= h then
        lockBtn._w, lockBtn._h = w, h
        lockBtn:SetSize(w, h)
        lockBtn.Upper:SetHeight(h / 2)
        -- the grain's rows along the block as along the border, at the border's scale for a band as deep as the block
        -- is tall (Media/BandGrain.tga: 16 texels across, 64 rows along)
        local along = w / (4 * h)
        lockBtn.Grain:SetTexCoord(0, 0, 1, 0, 0, along, 1, along)
        -- the padlock over the bar's middle
        lockBtn.Icon:ClearAllPoints()
        lockBtn.Icon:SetPoint("CENTER", lockBtn, "CENTER", 0, -rise / 2)
    end
    local size = math.max(math.floor(barH * LOCK_SIZE + 0.5), 4)
    for _, t in ipairs({ lockBtn.Lip, lockBtn.Icon }) do
        t:SetTexture(locked and ns.LOCK or ns.UNLOCK)
        Buttons.FitTexture(t, LOCK_ART, 1, 1, size)
    end
    lockBtn.Grain:SetVertexColor(1, 1, 1, ns.Border.GRAIN.strength / 100)
    local r, g, b
    if locked then
        r, g, b = ns.Border.Color()
        if hover then
            r, g, b = min(1, r * (1 + HOVER_LIGHT)), min(1, g * (1 + HOVER_LIGHT)), min(1, b * (1 + HOVER_LIGHT))
        end
        top[1], top[2], top[3] = min(1, r * METAL[1]), min(1, g * METAL[1]), min(1, b * METAL[1])
        mid[1], mid[2], mid[3] = r * METAL[2], g * METAL[2], b * METAL[2]
        foot[1], foot[2], foot[3] = r * METAL[3], g * METAL[3], b * METAL[3]
        lockBtn.Icon:SetVertexColor(CARVED[1], CARVED[2], CARVED[3], 1)
        lockBtn.Aura:Hide()
        lockBtn.AuraIn:Stop()
    else
        r, g, b = gold()
        if hover then
            r, g, b = r + (1 - r) * HOVER_LIGHT, g + (1 - g) * HOVER_LIGHT, b + (1 - b) * HOVER_LIGHT
        end
        top[1], top[2], top[3] = r + (1 - r) * GOLD_TOP, g + (1 - g) * GOLD_TOP, b + (1 - b) * GOLD_TOP
        mid[1], mid[2], mid[3] = r, g, b
        foot[1], foot[2], foot[3] = r * GOLD_FOOT, g * GOLD_FOOT, b * GOLD_FOOT
        lockBtn.Icon:SetVertexColor(LOCK_DARK[1], LOCK_DARK[2], LOCK_DARK[3], 1)
        lockBtn.Aura:SetVertexColor(r, g, b, AURA_ALPHA)
        if not lockBtn.Aura:IsShown() then
            lockBtn.Aura:Show()
            lockBtn.AuraIn:Play()
        end
    end
    lockBtn.tint[1], lockBtn.tint[2], lockBtn.tint[3] = r, g, b
    shade(lockBtn.Upper, mid, top)
    shade(lockBtn.Lower, foot, mid)
end

-- A texture of the block's, in one colour or in two (lit from the foot to the top, set by UpdateLock).
local function part(layer, sub, colour)
    local t = lockBtn:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    if colour then
        t:SetVertexColor(colour[1], colour[2], colour[3], colour[4] or 1)
    else
        t.lo, t.hi = CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1)
    end
    return t
end

local function makeLock()
    lockBtn = CreateFrame("Button", nil, nil)
    lockBtn:SetParent(bar)
    -- flush with the screen's edge and foot, over the bar's end
    lockBtn:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    lockBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    lockBtn.tint = {}
    -- the aura under the block, round it: Media/Shadow.tga's soft disc, its middle under the block, in gold, added
    lockBtn.Aura = lockBtn:CreateTexture(nil, "BACKGROUND", nil, -8)
    lockBtn.Aura:SetTexture(ns.SHADOW)
    lockBtn.Aura:SetBlendMode("ADD")
    lockBtn.Aura:SetPoint("TOPLEFT", -AURA_REACH, AURA_REACH)
    lockBtn.Aura:SetPoint("BOTTOMRIGHT", AURA_REACH, -AURA_REACH)
    lockBtn.Aura:Hide()
    local fade = lockBtn.Aura:CreateAnimationGroup()
    local rise = fade:CreateAnimation("Alpha")
    rise:SetFromAlpha(0)
    rise:SetToAlpha(1)
    rise:SetDuration(AURA_IN)
    lockBtn.AuraIn = fade
    -- its shadow on the bar, left of it, darkest against it
    local shadow = part("BACKGROUND", -7)
    shadow:SetPoint("TOPRIGHT", lockBtn, "TOPLEFT", 0, 0)
    shadow:SetPoint("BOTTOMRIGHT", lockBtn, "BOTTOMLEFT", 0, 0)
    shadow:SetWidth(SHADOW_W)
    shadow.lo:SetRGBA(0, 0, 0, 0)
    shadow.hi:SetRGBA(0, 0, 0, SHADOW_A)
    shadow:SetGradient("HORIZONTAL", shadow.lo, shadow.hi)
    -- the metal in two halves, lit from the top, the grain over it
    lockBtn.Upper = part("BORDER", 0)
    lockBtn.Upper:SetPoint("TOPLEFT")
    lockBtn.Upper:SetPoint("TOPRIGHT")
    lockBtn.Lower = part("BORDER", 0)
    lockBtn.Lower:SetPoint("TOPLEFT", lockBtn.Upper, "BOTTOMLEFT")
    lockBtn.Lower:SetPoint("BOTTOMRIGHT")
    lockBtn.Grain = lockBtn:CreateTexture(nil, "BORDER", nil, 1)
    lockBtn.Grain:SetTexture(ns.BAND_GRAIN, "CLAMP", "REPEAT")
    lockBtn.Grain:SetAllPoints()
    -- its edges, a pixel each: dark along the top and down the left side, lit inside them
    local darkTop, darkSide = part("ARTWORK", 0, EDGE_DARK), part("ARTWORK", 0, EDGE_DARK)
    darkTop:SetPoint("TOPLEFT")
    darkTop:SetPoint("TOPRIGHT")
    PixelUtil.SetHeight(darkTop, 1, 1)
    darkSide:SetPoint("TOPLEFT")
    darkSide:SetPoint("BOTTOMLEFT")
    PixelUtil.SetWidth(darkSide, 1, 1)
    local topLit, sideLit = part("ARTWORK", 1, TOP_LIT), part("ARTWORK", 1, SIDE_LIT)
    topLit:SetPoint("TOPLEFT", darkTop, "BOTTOMLEFT")
    topLit:SetPoint("TOPRIGHT", darkTop, "BOTTOMRIGHT")
    PixelUtil.SetHeight(topLit, 1, 1)
    sideLit:SetPoint("TOPLEFT", darkSide, "TOPRIGHT")
    sideLit:SetPoint("BOTTOMLEFT", darkSide, "BOTTOMRIGHT")
    PixelUtil.SetWidth(sideLit, 1, 1)
    -- the padlock carved in, its lit lip a pixel under it
    lockBtn.Icon = lockBtn:CreateTexture(nil, "OVERLAY", nil, 1)
    lockBtn.Icon:SetPoint("CENTER", 0, 0)
    lockBtn.Lip = lockBtn:CreateTexture(nil, "OVERLAY", nil, 0)
    lockBtn.Lip:SetPoint("CENTER", lockBtn.Icon, "CENTER", 0, -1)
    lockBtn.Lip:SetVertexColor(CARVED_LIP[1], CARVED_LIP[2], CARVED_LIP[3], CARVED_LIP[4])
    -- its scripts under the handlers' guard (ns.Guarded), as every script the HUD sets: an error in one is kept
    lockBtn:SetScript("OnClick", ns.Guarded(function(self, mouseButton)
        if mouseButton == "RightButton" then
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, ns.HubMenus.Bar)
        elseif not ns.CombatRefused() then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Hub.SetLocked(not Hub.IsLocked())
            if GameTooltip:GetOwner() == self then
                self:GetScript("OnEnter")(self)
            end
        end
    end))
    lockBtn:SetScript("OnEnter", ns.Guarded(function(self)
        self._hover = true
        InfoBar.UpdateLock()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        -- its state, what that state allows, then its clicks as every tooltip's foot has them (the review of
        -- 2026-11-20: shut, its title read « Verrouiller les emplacements », and open, its text still said to unlock)
        local locked = Hub.IsLocked()
        GameTooltip:SetText(locked and L.SLOTS_LOCKED_STATE or L.SLOTS_UNLOCKED, 1, 0.82, 0)
        GameTooltip:AddLine(locked and L.SLOTS_SHUT_TIP or L.SLOTS_OPEN_TIP, 0.8, 0.8, 0.8, true)
        if ns.InCombat() then
            GameTooltip:AddLine(ns.G("ERR_NOT_IN_COMBAT", "Impossible de faire ceci tout en combattant."), 1, 0.13, 0.13, true)
            GameTooltip:AddLine(L.COMBAT_HELD, 1, 0.82, 0, true)
        end
        GameTooltip:AddLine(locked and L.HINT_UNLOCK or L.HINT_LOCK, 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end))
    lockBtn:SetScript("OnLeave", ns.Guarded(function(self)
        self._hover = false
        InfoBar.UpdateLock()
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end))
    InfoBar.lockButton = lockBtn
end

-- ---------- Laying out ----------

local function addRow(side, name, w, pos)
    local list = rows[side]
    local g = { name = name, w = w, pos = pos }
    list[#list + 1] = g
    inRow[name] = g
    return g
end

-- An element as an item of the bar's `side`: a Blizzard widget at its size (none while it can't show), another addon's
-- map button at the icon size, one of ours filled for the bar. nil when it takes no place.
local function barItem(e, side, drag)
    if e.native then
        local w = ns.Natives.Size(e.name)
        if w <= 0 then
            return nil
        end
        local g = addRow(side, e.name, w, e.pos)
        g.native = true
        return g
    elseif e.foreign then
        local g = addRow(side, e.name, Hub.IconSize(), e.pos)
        g.foreign = true
        return g
    end
    local b = Buttons.Make(e.name)
    b.slotSide = side
    if e.name ~= drag then
        b:SetParent(bar)
        b:SetFrameStrata("LOW")
        b:SetFrameLevel(bar:GetFrameLevel() + 4)
    end
    local g = addRow(side, e.name, hold(e.name, Buttons.SafeFill(b, e.obj, Hub.BarHeight(), false)), e.pos)
    g.b = b
    return g
end

-- How many places each pocket had at the last full layout, what didn't fit going on the bar.
local fitted = { pocketLeft = -1, pocketRight = -1 }
local spilled = { pocketLeft = {}, pocketRight = {} }
-- Whether one of Blizzard's widgets didn't fit in its pocket in this layout, and in the one before.
local nativesNow, nativesSpilled = false, false

local function fitting(d, T, onPlate)
    if not (d and onPlate) then
        return -1, -1
    end
    local spots = Hub.PocketSpots(d, T)
    return #spots.pocketLeft, #spots.pocketRight
end

-- Sorts the elements out by where they stand and fills our buttons with what they show: on the bar, round the map,
-- in folders. Blizzard's widgets round the map are UI/Hub/Natives.lua's; map buttons their addon hides take no place.
-- A pocket's elements past the places that fit go on the bar, either side of the block below the map, its own side,
-- the innermost nearest (none with the bar off).
local function collect()
    for _, list in pairs(rows) do
        wipe(list)
    end
    for _, list in pairs(members) do
        wipe(list)
    end
    for _, list in pairs(spilled) do
        wipe(list)
    end
    wipe(round)
    wipe(inRow)
    wipe(inRound)
    wipe(inFolder)
    local o = ns.db.options
    local drag = ns.HubDrag.Current()
    local d, onPlate = ns.Minimap.Dome()
    local T = InfoBar.Top()
    fitted.pocketLeft, fitted.pocketRight = fitting(d, T, onPlate)
    nativesNow = false
    for _, e in ipairs(Hub.Entries()) do
        local side = e.side
        if InfoBar.OffBar(e) then
            -- the bar off: nowhere to show, and a map button back with its addon
            if e.foreign then
                ns.Collect.GiveBack(e.name)
            end
        elseif Hub.ROUND[side] and Hub.Spills(e, d, T, onPlate) then
            nativesNow = nativesNow or e.native
            local g = o.infoBar and not (e.foreign and not ns.Collect.Shown(e.name)) and barItem(e, "centre", drag)
            if g then
                -- set apart until the block's own are in
                table.remove(rows.centre)
                g.spill = side
                spilled[side][#spilled[side] + 1] = g
            elseif e.foreign and not o.infoBar then
                -- past its pocket's places with no bar to go on: back with its addon
                ns.Collect.GiveBack(e.name)
            elseif e.foreign then
                ns.Collect.Hide(e.name)
            end
        elseif side == "folder" then
            local list = members[e.folder]
            if not list then
                list = {}
                members[e.folder] = list
            end
            list[#list + 1] = e
            inFolder[e.name] = e.folder
        elseif side == "hidden" or not (Hub.ROUND[side] or o.infoBar) then
            if e.foreign then
                ns.Collect.Hide(e.name)
            end
        elseif e.foreign and not ns.Collect.Shown(e.name) then
            Buttons.PlaceHandle(e.name, nil)
        elseif Hub.ROUND[side] then
            if not e.native then
                round[#round + 1] = e
                if not e.foreign then
                    local b = Buttons.Make(e.name)
                    b.slotSide = side
                    Buttons.SafeFill(b, e.obj, nil, true)
                    inRound[e.name] = b
                end
            end
        else
            barItem(e, side, drag)
        end
    end
    -- the left pocket's to the block's left, outwards; the right pocket's to its right
    local list = rows.centre
    for _, g in ipairs(spilled.pocketLeft) do
        table.insert(list, 1, g)
    end
    for _, g in ipairs(spilled.pocketRight) do
        list[#list + 1] = g
    end
end

-- ---------- What doesn't fit ----------
-- More on the bar than it is wide (a large text, a narrow screen, many other addons' objects) was drawn one over
-- another and off the screen: its left items are laid out from its left end and its right ones from its right end,
-- and nothing saw to their meeting (the review of 2026-11-17; a first run needs about 950 units at size 10, and a 16:9
-- screen at the game's default UI scale has 1365). Now what has no room is taken off the bar for this layout, the
-- innermost first, from the longer end, and put in the list of the folder made for it (Ikar 2026-11-17: "Maybe a
-- special folder ?"; Folders.Overflow, UI/Hub/Seeds.lua makes « Suite » the first time), where it works as ever; its
-- place is still the bar's, and it's back on it as soon as it fits. With no such folder (deleted, hidden), it's drawn
-- nowhere until there's room. Folders stay on the bar, and the zone; what came down from the pockets still goes first
-- (placeBar). « Suite »'s own button shows on the bar only while it holds something, or while the padlock is open,
-- whether it's the folder that takes what doesn't fit or no longer; a folder of the player's told to take it stays
-- where he put it, empty too, as every folder of his does (one that left the bar as its last element was dragged out
-- would look deleted).

-- By how much the bar's items run over one another, `without` left out: the left ones, what stands between them (but
-- what came down from the pockets) and the right ones; none at 0 or less. Then how long its left and right rows are.
local function excess(without)
    local W, sp = UIParent:GetWidth(), Hub.Spacing()
    local left, right, mid = EDGE_X, EDGE_X + lockRoom(), -sp
    for _, g in ipairs(rows.left) do
        if g ~= without then
            left = left + g.w + sp
        end
    end
    for _, g in ipairs(rows.right) do
        if g ~= without then
            right = right + g.w + sp
        end
    end
    for _, g in ipairs(rows.centre) do
        if g ~= without and not g.spill then
            mid = mid + g.w + sp
        end
    end
    for _, g in ipairs(rows.free) do
        if g ~= without then
            mid = mid + g.w + sp
        end
    end
    return left + mid - (W - right), left, right
end

-- The innermost item of a row that may leave it: none of the folders, nor the zone, nor what's dragged, nor what came
-- down from a pocket.
local function leaver(row, drag)
    for i = #row, 1, -1 do
        local g = row[i]
        local e = Hub.Entry(g.name)
        if e and not e.isFolder and not g.spill and g.name ~= drag and not Hub.IsFixed(g.name) then
            return i, g, e
        end
    end
end

local fromLeft, between, fromRight = {}, {}, {}
-- Whether one of Blizzard's widgets had no room on the bar in this layout, and in the one before.
local nativesOut, nativesWereOut = false, false

-- Takes off the bar what has no room on it (above). True when the folder for it was just made: the hub has an element
-- more, and is laid out again.
local function fit()
    wipe(unfitted)
    nativesOut = false
    local home = ns.Folders.Overflow()
    local he = home and Hub.Entry(home)
    if not he or he.side == "hidden" or InfoBar.OffBar(he) then
        home, he = nil, nil
    end
    -- « Suite »'s own button on the bar: none while it holds nothing and the padlock is shut, unless it's about to
    -- take something
    local suite = ns.Folders.ByRole("overflow")
    local own = suite and inRow[suite] or nil
    if own and (own.spill or not Hub.IsLocked() or #(members[suite] or EMPTY) > 0) then
        own = nil
    end
    if own and (suite ~= home or excess(own) <= 0) then
        for _, row in pairs(rows) do
            for i = #row, 1, -1 do
                if row[i] == own then
                    table.remove(row, i)
                end
            end
        end
        inRow[suite] = nil
    end
    if excess() <= 0 then
        return false
    end
    if not home and ns.Seeds.Overflow() then
        return true
    end
    local drag = ns.HubDrag.Current()
    wipe(fromLeft)
    wipe(between)
    wipe(fromRight)
    local over, left, right = excess()
    while over > 0 do
        local row, into = nil, nil
        local longer, shorter = rows.left, rows.right
        if right - lockRoom() > left then
            longer, shorter = rows.right, rows.left
        end
        for _, candidate in ipairs({ longer, shorter, rows.free, rows.centre }) do
            if leaver(candidate, drag) then
                row = candidate
                break
            end
        end
        if not row then
            break
        end
        local i, g, e = leaver(row, drag)
        table.remove(row, i)
        inRow[g.name] = nil
        unfitted[g.name] = home or false
        nativesOut = nativesOut or g.native == true
        if home then
            into = row == rows.left and fromLeft or row == rows.right and fromRight or between
            -- as they read on the bar, left to right: the left row's are taken from its right end
            table.insert(into, row == rows.left and 1 or #into + 1, e)
        elseif g.foreign then
            ns.Collect.Hide(g.name)
        end
        over, left, right = excess()
    end
    if home then
        local list = members[home]
        if not list then
            list = {}
            members[home] = list
        end
        for _, part in ipairs({ fromLeft, between, fromRight }) do
            for _, e in ipairs(part) do
                list[#list + 1] = e
                inFolder[e.name] = home
            end
        end
    end
    return false
end

-- Puts a row's item with its centre at x, y up the bar; what didn't move isn't touched.
local function put(g, x, y, drag)
    placed[g.name] = g
    local b = g.b
    if b then
        b._pass = pass
        b:Show()
    end
    if g.x == x and g.y == y and g.at == g.w then
        return
    end
    g.x, g.y, g.at = x, y, g.w
    if b then
        b.ux, b.uy = x, y
        if g.name ~= drag then
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x - g.w / 2, 0)
        end
    elseif g.native then
        ns.Natives.PlaceOnBar(g.name, x, y)
    else
        ns.Collect.Place(g.name, nil, x, y)
    end
end

local function byWant(a, b)
    return a.want < b.want
end

-- The bar's items where they go: from its left end, from its right end before the padlock; between them the block
-- below the minimap, the zone right under its centre, and those set free each where it was dropped, none over another
-- nor past the ends.
local function placeBar()
    local W, sp, y = UIParent:GetWidth(), Hub.Spacing(), Hub.BarHeight() / 2
    local drag = ns.HubDrag.Current()
    wipe(placed)
    local x = EDGE_X
    for _, g in ipairs(rows.left) do
        put(g, x + g.w / 2, y, drag)
        x = x + g.w + sp
    end
    local leftEnd = x
    ends.left = #rows.left > 0 and x - sp or EDGE_X
    x = EDGE_X + lockRoom()
    for _, g in ipairs(rows.right) do
        put(g, W - x - g.w / 2, y, drag)
        x = x + g.w + sp
    end
    local rightEnd = W - x
    ends.leftEdge, ends.rightEdge = EDGE_X, W - EDGE_X - lockRoom()
    ends.right = #rows.right > 0 and rightEnd + sp or ends.rightEdge
    -- what came down from the pockets goes while the bar's middle can't hold it all, the outermost first
    local need = -sp
    for _, list in ipairs({ rows.centre, rows.free }) do
        for _, g in ipairs(list) do
            need = need + g.w + sp
        end
    end
    while need > rightEnd - leftEnd do
        local list = rows.centre
        local first, last = list[1], list[#list]
        local g, at
        if last and last.spill and (#spilled.pocketRight >= #spilled.pocketLeft or not first.spill) then
            g, at = last, #list
        elseif first and first.spill then
            g, at = first, 1
        else
            break
        end
        table.remove(list, at)
        table.remove(spilled[g.spill])
        inRow[g.name] = nil
        need = need - g.w - sp
        if g.foreign then
            ns.Collect.Hide(g.name)
        end
    end
    local total, zoneAt = -sp, nil
    for _, g in ipairs(rows.centre) do
        if Hub.IsFixed(g.name) then
            zoneAt = total + sp + g.w / 2
        end
        total = total + g.w + sp
    end
    local mids = {}
    if #rows.centre > 0 then
        local under = ns.Minimap.CentreX() or W / 2
        mids[1] = { w = total, want = zoneAt and under - zoneAt + total / 2 or under }
    end
    for _, g in ipairs(rows.free) do
        mids[#mids + 1] = { g = g, w = g.w, want = g.pos * W }
    end
    table.sort(mids, byWant)
    local cursor = leftEnd
    for _, m in ipairs(mids) do
        m.x0 = max(m.want - m.w / 2, cursor)
        cursor = m.x0 + m.w + sp
    end
    local limit = rightEnd
    for i = #mids, 1, -1 do
        mids[i].x0 = min(mids[i].x0, limit - mids[i].w)
        limit = mids[i].x0 - sp
    end
    centre = nil
    for _, m in ipairs(mids) do
        if m.g then
            put(m.g, m.x0 + m.w / 2, y, drag)
        else
            centre = centreSpan
            centre.x0, centre.x1 = m.x0, m.x0 + total
            x = m.x0
            for _, g in ipairs(rows.centre) do
                put(g, x + g.w / 2, y, drag)
                x = x + g.w + sp
            end
        end
    end
    version = version + 1
end

-- The elements round the map (Hub.SlotPoint), ours and other addons' map buttons, one on hover seen while the map
-- is hovered or the slots are unlocked. While the map isn't ours, ours wait hidden and other addons' go back to their
-- addon (Ikar 2026-11-15).
local function placeRound()
    local d, onPlate = ns.Minimap.Dome()
    if not d then
        for _, e in ipairs(round) do
            if e.foreign then
                ns.Collect.GiveBack(e.name)
            elseif inRound[e.name] then
                inRound[e.name]:Hide()
            end
        end
        return
    end
    local T, drag = InfoBar.Top(), ns.HubDrag.Current()
    local unlocked, hovered = not Hub.IsLocked(), ns.Minimap.IsHovered()
    for _, e in ipairs(round) do
        local ux, uy = Hub.SlotPoint(e, d, T, onPlate)
        local show = unlocked or e.show ~= "hover" or hovered
        local b = inRound[e.name]
        if b then
            b._pass = pass
            if e.name ~= drag then
                b:SetParent(UIParent)
                b:SetFrameStrata("MEDIUM")
                b:SetFrameLevel(18)
                b:ClearAllPoints()
                b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux, uy)
            end
            b.ux, b.uy = ux, uy
            b:SetShown(show or b:IsMouseOver())
        else
            ns.Collect.Place(e.name, nil, ux, uy, show or ns.Collect.Frame(e.name):IsMouseOver())
        end
    end
end

-- A folder's list next to its button, wherever that stands now (none when the button doesn't show).
local function placeFolder(id)
    local owner = Buttons.Get(id)
    if not (owner and owner._pass == pass and owner:IsShown()) then
        owner = nil
    end
    ns.SafeCall(ns.Folders.Layout, id, members[id] or EMPTY, owner)
end

-- A folder before those it holds: their buttons placed in its list, theirs opening beside it.
local function placeFolders()
    for _, id in ipairs(ns.Folders.Ordered()) do
        placeFolder(id)
    end
end

-- ---------- A sign that it's done ----------
-- An element the player shows again from the bar's menu, sends into a folder from its own, or moves by an undo, lands
-- where he isn't looking, often in a shut folder: nothing was seen to happen (the review of 2026-11-17, P4; Ikar:
-- "Flash is ok, but why the folder open ? I don't see a case", then "And the flash yes"). It is lit once where it
-- stands after the layout that follows: the padlock's aura, gold, fading out in half a second, as the game marks a new
-- item in a bag. In a list that doesn't show, the folder's button is lit, its list left shut. On the player's own
-- action alone, never on an event of the game's: the HUD notifies of nothing.
local FLASH_REACH, FLASH_ALPHA, FLASH_TIME = 6, 0.9, 0.5
local wanted, flashes = {}, {}

-- The frames that light, each lit or free: read it, never change it.
function InfoBar.Flashes()
    return flashes
end

-- Asks for `name` to be lit once the hub is next laid out.
function InfoBar.Flash(name)
    if type(name) == "string" then
        wanted[name] = true
        InfoBar.Request()
    end
end

local function flashFrame()
    for _, f in ipairs(flashes) do
        if not f:IsShown() then
            return f
        end
    end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f.Glow = f:CreateTexture(nil, "OVERLAY")
    f.Glow:SetAllPoints(f)
    f.Glow:SetTexture(ns.SHADOW)
    f.Glow:SetBlendMode("ADD")
    f.Fade = f.Glow:CreateAnimationGroup()
    local fade = f.Fade:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(FLASH_TIME)
    f.Fade:SetScript("OnFinished", ns.Guarded(function()
        f:Hide()
    end))
    f:Hide()
    flashes[#flashes + 1] = f
    return f
end

-- What to light for `name`: itself where it's seen, else the folder that holds it, and so on up: from the outermost
-- folder in, each list that's open shows the next (told by the folders themselves, not by asking a frame whether it's
-- visible). Its own button, or, on the bar with no button of ours (a widget of Blizzard's, another addon's map
-- button), its place there. Nothing for what shows nowhere.
local function flashTarget(name)
    local chain = { name }
    for _ = 1, 8 do
        local folder = inFolder[chain[#chain]]
        if not folder then
            break
        end
        chain[#chain + 1] = folder
    end
    local at = #chain
    while at > 1 and ns.Folders.IsOpen(chain[at]) do
        at = at - 1
    end
    local seen = chain[at]
    local b = Buttons.Get(seen)
    if b and b:IsShown() then
        return b
    end
    if placed[seen] then
        return nil, placed[seen]
    end
end

local function light(b, g)
    local f = flashFrame()
    local r, gr, bl = gold()
    f.Glow:SetVertexColor(r, gr, bl, FLASH_ALPHA)
    f:ClearAllPoints()
    if b then
        f:SetPoint("TOPLEFT", b, "TOPLEFT", -FLASH_REACH, FLASH_REACH)
        f:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", FLASH_REACH, -FLASH_REACH)
    else
        f:SetPoint("LEFT", bar, "LEFT", g.x - g.w / 2 - FLASH_REACH, 0)
        f:SetSize(g.w + 2 * FLASH_REACH, Hub.BarHeight() + 2 * FLASH_REACH)
    end
    f.target = b or g
    f:Show()
    f.Fade:Stop()
    f.Fade:Play()
end

-- Every element drawn where it stands, our buttons put out in no layout hidden; during a fight, once it's over.
function InfoBar.Refresh()
    if InCombatLockdown() then
        dirty, held = true, true
        return
    end
    dirty = false
    wipe(pending)
    if not bar then
        return
    end
    InfoBar.refreshes = InfoBar.refreshes + 1
    pass = pass + 1
    local o = ns.db.options
    collect()
    if o.infoBar then
        bar:SetHeight(Hub.BarHeight())
        bar:Show()
        -- the padlock's cap first: what the bar's right end has left depends on its width
        InfoBar.UpdateLock()
        if fit() then
            return InfoBar.Refresh()
        end
    else
        wipe(unfitted)
        nativesOut = false
    end
    placeRound()
    if o.infoBar then
        placeBar()
    else
        bar:Hide()
        wipe(placed)
        centre = nil
        version = version + 1
    end
    placeFolders()
    local drag = ns.HubDrag.Current()
    for name, b in pairs(Buttons.All()) do
        if b._pass ~= pass and name ~= drag then
            b:Hide()
        end
    end
    -- Blizzard's widgets come down from a pocket or go back up as this layout says, leave the bar for want of room or
    -- come back on it
    if nativesNow or nativesSpilled or nativesOut or nativesWereOut then
        ns.Natives.Request()
    end
    nativesSpilled, nativesWereOut = nativesNow, nativesOut
    -- LibDBIcon's buttons away or back on the map, as this layout shows their objects or not
    ns.SafeCall(ns.Collect.SyncIcons)
    -- what the player just showed, sent into a folder or moved by an undo, lit where it now stands
    for name in pairs(wanted) do
        wanted[name] = nil
        local b, g = flashTarget(name)
        if b or g then
            ns.SafeCall(light, b, g)
        end
    end
end

local function refreshIfAsked()
    if dirty then
        InfoBar.Refresh()
    end
end

-- Drawn whole once, on the next frame, however many ask.
function InfoBar.Request()
    dirty = true
    ns.Later("infobar", refreshIfAsked)
end

-- Whether as many places fit in each pocket as at the last full layout (the dome, the bar's size or a status bar
-- under a pocket changed); else drawn whole again, what fits now in its pocket, the rest on the bar.
function InfoBar.PocketsHold()
    if dirty or not bar then
        return true
    end
    local d, onPlate = ns.Minimap.Dome()
    local left, right = fitting(d, InfoBar.Top(), onPlate)
    if left == fitted.pocketLeft and right == fitted.pocketRight then
        return true
    end
    InfoBar.Refresh()
    return false
end

-- The dome moved: what stands round it and the block below it put back, nothing filled anew.
function InfoBar.Reflow()
    if InCombatLockdown() then
        InfoBar.Request()
        return
    end
    if dirty or not bar or not InfoBar.PocketsHold() then
        return
    end
    placeRound()
    if ns.db.options.infoBar then
        placeBar()
    end
    placeFolders()
    version = version + 1
end

-- The elements whose content changed since the last frame, each button filled again; the bar's items put back if one
-- needs a wider place (never a narrower one: hold), an open folder's list laid out again, once however many of its
-- members changed (five attributes changing laid the attributes' list out five times, more work than a layout of the
-- whole hub: the review of 2026-11-17). During a fight a secure button waits, and nothing moves: what changed is drawn
-- in place, the layout once the fight is over. One element failing to draw leaves the others theirs (SafeFill).
local again = {}
local function flush()
    if dirty or not bar then
        wipe(pending)
        return
    end
    local fight = InCombatLockdown()
    local h, moved = Hub.BarHeight(), false
    for name in pairs(pending) do
        pending[name] = nil
        local e, g = Hub.Entry(name), inRow[name]
        local b = g and g.b or inRound[name]
        if fight and b and b.secure then
            held = true
        elseif fight and inFolder[name] then
            ns.Folders.Refill(inFolder[name], name)
            held = true
        elseif not e then
            -- gone since: the full layout it asked for draws it
        elseif g and g.b then
            local w = hold(name, Buttons.SafeFill(g.b, e.obj, h, false))
            if w ~= g.w then
                g.w, moved = w, true
            end
        elseif inRound[name] then
            Buttons.SafeFill(inRound[name], e.obj, nil, true)
        elseif inFolder[name] and ns.Folders.IsOpen(inFolder[name]) then
            again[inFolder[name]] = true
        elseif inFolder[name] then
            -- shut: drawn again in place, so it's right if opened in a fight; laid out as it opens
            ns.Folders.Refill(inFolder[name], name)
        end
    end
    for id in pairs(again) do
        again[id] = nil
        placeFolder(id)
    end
    if moved then
        if fight then
            held = true
        elseif excess() > 0 then
            -- a place grown past what the bar has left: laid out whole, what has no room taken off it (fit)
            InfoBar.Request()
        else
            placeBar()
        end
    end
end

-- An element's text, icon or colour changed: its button alone is drawn again, on the next frame.
function InfoBar.Update(name)
    pending[name] = true
    ns.Later("infobar update", flush)
end

-- ---------- Hover ----------

-- Round the map, those seen on hover show while it's hovered (or the slots unlocked), or while the pointer is on them.
function InfoBar.UpdateHover(hovered)
    if not (bar and ns.Minimap.Dome()) then
        return
    end
    local unlocked, fight = not Hub.IsLocked(), InCombatLockdown()
    for _, e in ipairs(round) do
        local show = unlocked or e.show ~= "hover" or hovered
        local b = inRound[e.name]
        if b then
            -- a secure one stays as the fight found it (shown: fightStarts)
            if not (fight and b.secure) then
                b:SetShown(show or b:IsMouseOver())
            end
        else
            local f = ns.Collect.Frame(e.name)
            if f then
                ns.Collect.SetShown(e.name, show or f:IsMouseOver())
            end
        end
    end
end

-- Whether one of our buttons round the map is under the pointer.
function InfoBar.AnyHovered()
    for _, b in pairs(inRound) do
        if b:IsShown() and b:IsMouseOver() then
            return true
        end
    end
    return false
end

-- A fight starts. While this event is handled the game still lets addons touch secure buttons, for the last time until
-- it ends: what waited is drawn now, a drag goes back, and the secure elements round the map shown on hover show for the
-- fight (none could be shown during it).
-- The padlock, open as the fight starts, shut for it, and left shut after (Ikar 2026-11-20: "make it lock on combat
-- (no unlock after)"; it opened again after until then). It can't be turned during a fight, so one that began with it
-- open kept the HUD being arranged until its end: a macro's own right-click ran nothing, another addon's right-click
-- opened the hub menu, greyed, and never reached its addon (the review of 2026-11-17). Shut here, while the game still
-- lets the macros' buttons be set, a fight finds everything doing what its author wrote.
local function fightStarts()
    ns.HubDrag.Cancel()
    if not Hub.IsLocked() and not InCombatLockdown() then
        Hub.SetLocked(true)
    end
    if dirty and not InCombatLockdown() then
        InfoBar.Refresh()
        -- the folders' lists back in the game's auto-hide where this layout placed them anew
        ns.SafeCall(ns.Folders.FightStarts)
    end
    if InCombatLockdown() then
        return
    end
    for _, e in ipairs(round) do
        local b = inRound[e.name]
        if b and b.secure then
            b:Show()
        end
    end
end

-- The fight is over: what waited drawn, the map's hover as it is.
local function fightEnds()
    if held or dirty then
        held = false
        InfoBar.Request()
    end
    InfoBar.UpdateHover(ns.Minimap.IsHovered())
end

-- At login, once the hub's elements are known.
function InfoBar.Start()
    bar = CreateFrame("Frame", nil, nil)
    bar:SetParent(UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    bar:SetHeight(Hub.BarHeight())
    bar:EnableMouse(true)
    bar:SetScript("OnMouseUp", ns.Guarded(function(self, mouse)
        if mouse == "RightButton" then
            MenuUtil.CreateContextMenu(self, ns.HubMenus.Bar)
        end
    end))
    InfoBar.frame = bar
    makeLock()
    ns.On("PLAYER_REGEN_DISABLED", function()
        ns.SafeCall(fightStarts)
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        ns.SafeCall(fightEnds)
    end)
    InfoBar.Refresh()
end
