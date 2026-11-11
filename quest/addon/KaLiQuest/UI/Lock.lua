-- The padlock and the combat lock, the key bindings, collapse-all and stepping through groups, and a focus held
-- until the tracker may open it. See organiser-design.md, Combat.
local _, ns = ...
local L = ns.L
local Tracker = ns.Tracker
local Shared = Tracker.Shared
local guarded = Shared.guarded

local Lock = {}
ns.Lock = Lock

local LOCK_W, LOCK_H = 14, 17
local CUT = 0.43 -- the body's top edge, as a share of the padlock's height
local SWING = math.rad(32)
local unlockedThisFight = false
local pendingFocus -- a quest focused while locked, whose group opens once unlocked
local lastFocus

-- Combat locks the tracker for the fight, unless the player unlocks it then. Out of combat it's their choice.
function Lock.IsLocked()
    if InCombatLockdown() then
        return not unlockedThisFight
    end
    return ns.db.locked == true
end
local isLocked = Lock.IsLocked
Shared.isLocked = isLocked

-- A refused click flashes the padlock, so the reason is visible, at full strength even from a key binding.
function Lock.RefusedByLock()
    if not isLocked() then
        return false
    end
    local title = Tracker.frames and Tracker.frames.title
    if title and title.Lock.Flash then
        Shared.wake()
        title.Lock.Flash:Stop()
        title.Lock.Flash:Play()
    end
    return true
end
local refusedByLock = Lock.RefusedByLock
Shared.refusedByLock = refusedByLock

-- Focusing a quest opens its group and section, the one case where something opens by itself.
local function applyPendingFocus()
    if pendingFocus and not isLocked() and not InCombatLockdown() then
        local id = pendingFocus
        pendingFocus = nil
        ns.Menus.OpenParents(id)
    end
end

function Lock.OpenFocused()
    local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if id == lastFocus then
        return
    end
    lastFocus = id
    pendingFocus = nil
    -- The focus restored at login isn't the player's doing, and the log isn't read yet.
    if id == 0 or not ns.model.watched then
        return
    end
    -- Rows don't change in combat, where item buttons couldn't follow, nor while locked.
    if isLocked() or InCombatLockdown() then
        pendingFocus = id
        return
    end
    ns.Menus.OpenParents(id)
end

-- The focus at login, so only a later change opens anything.
function Lock.NoteFocus()
    lastFocus = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID() or 0
end

-- Each fight starts locked; once it ends, the player's own choice is back and a focus held meanwhile opens.
function Lock.FightStarted()
    unlockedThisFight = false
end
function Lock.FightEnded()
    unlockedThisFight = false
    applyPendingFocus()
end

local function lockTooltip(self)
    local fight = InCombatLockdown()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if isLocked() then
        GameTooltip:SetText(fight and L.LOCKED_FIGHT or L.LOCKED, 1, 1, 1)
        GameTooltip:AddLine(fight and L.CLICK_UNLOCK_FIGHT or L.CLICK_UNLOCK, 1, 0.82, 0)
    else
        GameTooltip:SetText(fight and L.UNLOCKED_FIGHT or L.UNLOCKED, 1, 1, 1)
        GameTooltip:AddLine(L.CLICK_LOCK, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- In combat it unlocks or locks this fight only. Out of combat it's the player's saved choice.
local function toggleLock()
    if InCombatLockdown() then
        unlockedThisFight = not unlockedThisFight
    else
        ns.db.locked = not ns.db.locked
    end
    Shared.playToggle()
    applyPendingFocus()
    ns.RequestRefresh()
end

function Lock.ToggleAll()
    if refusedByLock() then
        return
    end
    ns.db.open.tracker = not ns.db.open.tracker
    Shared.playToggle()
    ns.RequestRefresh()
end

-- The next or previous player's group opens and the others close, as the eye does, wrapping round at the ends.
local function stepGroup(dir)
    local groups = ns.db.groups
    if #groups == 0 or refusedByLock() then
        return
    end
    local current
    for i, g in ipairs(groups) do
        if ns.db.open.groups[g.id] then
            current = i
            break
        end
    end
    local from = current or (dir > 0 and 0 or 1)
    local target = groups[(from - 1 + dir) % #groups + 1]
    ns.db.open.tracker = true
    ns.Menus.OpenOnly({ group = target, name = target.name, cat = "mine" })
end

local BINDINGS = {
    lock = toggleLock,
    collapse = Lock.ToggleAll,
    next = function()
        stepGroup(1)
    end,
    previous = function()
        stepGroup(-1)
    end,
}

function Tracker.Binding(action)
    if Tracker.IsActive() and BINDINGS[action] then
        BINDINGS[action]()
    end
end

function KaLiQuest_Binding(action)
    ns.SafeCall(Tracker.Binding, action)
end

-- The closed padlock cut at its body's top edge, so no seam shows: unlocking swings the shackle open on its right
-- leg, Ikar's pick on 2026-11-08. Locked, a copy added on top makes it much brighter, as the gear's. Without the
-- atlas's data it stays one closed padlock, greyed while unlocked.
function Lock.Build(parent)
    local b = Shared.newFrame("Button", parent)
    b:SetSize(18, 18)
    b:SetPoint("RIGHT", -62, 0)
    b:RegisterForClicks("LeftButtonUp")
    local top = LOCK_H * CUT
    b.Shackle = b:CreateTexture(nil, "ARTWORK")
    b.Body = b:CreateTexture(nil, "ARTWORK")
    b.Body:SetSize(LOCK_W, LOCK_H - top)
    b.Body:SetPoint("TOPLEFT", 2, -1 - top)
    b.Shackle:SetSize(LOCK_W, top)
    b.Shackle:SetPoint("TOPLEFT", 2, -1)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("communities-icon-lock")
    local file = info and (info.file or info.filename)
    if file then
        local cut = info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) * CUT
        b.Shackle:SetTexture(file)
        b.Shackle:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, cut)
        b.Body:SetTexture(file)
        b.Body:SetTexCoord(info.leftTexCoord, info.rightTexCoord, cut, info.bottomTexCoord)
    else
        b.whole = true
        b.Shackle:Hide()
        b.Body:SetSize(LOCK_W, LOCK_H)
        b.Body:ClearAllPoints()
        b.Body:SetPoint("TOPLEFT", 2, -1)
        b.Body:SetAtlas("communities-icon-lock", false)
    end
    b.Add = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.Add:SetAtlas("communities-icon-lock", false)
    b.Add:SetSize(LOCK_W, LOCK_H)
    b.Add:SetPoint("TOPLEFT", 2, -1)
    b.Add:SetBlendMode("ADD")
    -- A refused click: the padlock swells once and glows red, as on the bench.
    b.Glow = b:CreateTexture(nil, "OVERLAY")
    b.Glow:SetAtlas("communities-icon-lock", false)
    b.Glow:SetSize(LOCK_W, LOCK_H)
    b.Glow:SetPoint("TOPLEFT", 2, -1)
    b.Glow:SetBlendMode("ADD")
    b.Glow:SetVertexColor(1, 0.35, 0.24)
    b.Glow:SetAlpha(0)
    b.Flash = b:CreateAnimationGroup()
    local steps = {
        { "Scale", 1, 0.18 }, { "Scale", 2, 0.27 }, { "Alpha", 1, 0.18 }, { "Alpha", 2, 0.27 },
    }
    for _, s in ipairs(steps) do
        local a = b.Flash:CreateAnimation(s[1])
        a:SetOrder(s[2])
        a:SetDuration(s[3])
        if s[1] == "Scale" then
            local from, to = s[2] == 1 and 1 or 1.35, s[2] == 1 and 1.35 or 1
            a:SetScaleFrom(from, from)
            a:SetScaleTo(to, to)
        else
            a:SetTarget(b.Glow)
            a:SetFromAlpha(s[2] == 1 and 0 or 1)
            a:SetToAlpha(s[2] == 1 and 1 or 0)
        end
    end
    b:SetScript("OnClick", guarded(toggleLock))
    b:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        self:SetAlpha(1)
        lockTooltip(self)
    end))
    b:SetScript("OnLeave", guarded(function(self)
        self:SetAlpha(self.restAlpha or 1)
        Shared.hideTip(self)
    end))
    return b
end

function Lock.Draw(b)
    local locked = isLocked()
    if b.whole then
        b.Body:SetDesaturated(not locked)
    else
        -- Around its right leg's foot: x across the shackle's part of the art, y up from its bottom.
        b.Shackle:SetRotation(locked and 0 or -SWING, CreateVector2D and CreateVector2D(0.75, 0) or nil)
    end
    b.Add:SetShown(locked)
    b.restAlpha = locked and 1 or 0.65
    b:SetAlpha(b.restAlpha)
    b:EnableMouse(not Shared.EditMode())
    -- Clicks, bindings and the start and end of a fight all come through here.
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == b then
        lockTooltip(b)
    end
end
