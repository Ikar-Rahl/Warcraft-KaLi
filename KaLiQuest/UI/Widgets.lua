-- The tracker's shared pieces, used by every file that draws it: layout values and colours, the guard on clicks,
-- frame pools, small builders, tooltips, menus and refusals. Values come from the test bench's defaults (bench.js
-- DEFAULT_TOKENS and tracker.css), which follow Blizzard's templates.
local _, ns = ...

local Tracker = {}
ns.Tracker = Tracker
local Shared = {}
Tracker.Shared = Shared

Shared.TITLE_HEIGHT = 32
Shared.BAR_HEIGHT = 26
Shared.SIDE = 30 -- room left of the rows inside the scrolling area, for the bars' art
Shared.TOOLS_REST_ALPHA = 0.5
Shared.AREA_ARROW = "|A:poi-traveldirections-arrow:%d:%d|a"

local COLOR = {
    gold = { 1, 0.824, 0 },
    white = { 1, 1, 1 },
    title = { 0.890, 0.867, 0.812 },
    normal = { 0.706, 0.706, 0.706 },
    complete = { 0.510, 0.510, 0.510 },
    failed = { 0.8, 0.1, 0.1 },
    failedHover = { 1, 0.125, 0.125 },
    group = { 0.784, 0.722, 0.557 },
    groupHover = { 0.910, 0.847, 0.659 },
    count = { 0.561, 0.529, 0.439 },
    barCount = { 0.722, 0.659, 0.471 },
    subbar = { 0.804, 0.722, 0.471 },
    moved = { 0.486, 0.486, 0.486 },
    movedHover = { 0.690, 0.690, 0.690 },
    status = { 0.784, 0.784, 0.784 },
}
Shared.COLOR = COLOR

-- These follow the options page and are set again at each layout. The values here are Ikar's defaults.
local D = ns.DB.DEFAULTS
local layout = {
    width = D.width,
    titleGap = D.titleGap, -- Suivi starts 4 inside the title's height, Ikar's ruling
    barGap = D.barGap,
    groupGap = D.groupGap,
    groupIndent = D.groupIndent,
    questIndent = D.questIndent,
    markerSize = D.markerSize,
    blockRest = D.blockRest / 100,
    blockCombat = D.blockCombat / 100,
    blockHover = D.blockHover / 100,
    saturation = D.saturation / 100,
}
Shared.layout = layout
local HEADER = {}
Shared.HEADER = HEADER

-- CSS's saturate(), which the bench applies to the title and bars: 1 leaves a colour as it is, 0 makes it grey.
local function saturate(c, s)
    local r, g, b = c[1], c[2], c[3]
    return {
        (0.213 + 0.787 * s) * r + (0.715 - 0.715 * s) * g + (0.072 - 0.072 * s) * b,
        (0.213 - 0.213 * s) * r + (0.715 + 0.285 * s) * g + (0.072 - 0.072 * s) * b,
        (0.213 - 0.213 * s) * r + (0.715 - 0.715 * s) * g + (0.072 + 0.928 * s) * b,
    }
end

function Shared.ApplyOptions()
    local o = ns.db.options
    layout.width = o.width or D.width
    layout.titleGap = o.titleGap or D.titleGap
    layout.barGap = o.barGap or D.barGap
    layout.groupGap = o.groupGap or D.groupGap
    layout.groupIndent = o.groupIndent or D.groupIndent
    layout.questIndent = o.questIndent or D.questIndent
    layout.markerSize = o.markerSize or D.markerSize
    layout.blockRest = (o.blockRest or D.blockRest) / 100
    layout.blockCombat = (o.blockCombat or D.blockCombat) / 100
    layout.blockHover = (o.blockHover or D.blockHover) / 100
    layout.saturation = (o.saturation or D.saturation) / 100
    HEADER.gold = saturate(COLOR.gold, layout.saturation)
    HEADER.subbar = saturate(COLOR.subbar, layout.saturation)
    HEADER.barCount = saturate(COLOR.barCount, layout.saturation)
end

function Shared.Width()
    return layout.width
end

local editMode = false
function Shared.EditMode()
    return editMode
end
function Shared.SetEditMode(on)
    editMode = on
end

function Shared.paint(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

local function results(ok, ...)
    if ok then
        return ...
    end
end

-- Errors in clicks and menus reach /kq errors, as event handlers' do.
local function guarded(fn)
    return function(...)
        return results(ns.SafeCall(fn, ...))
    end
end
Shared.guarded = guarded

-- Pools: frames are never destroyed, so each kind is reused from one layout to the next.
function Shared.Pool(create)
    return { frames = {}, used = 0, create = create }
end
function Shared.acquire(pool)
    pool.used = pool.used + 1
    local f = pool.frames[pool.used]
    if not f then
        f = pool.create()
        pool.frames[pool.used] = f
    end
    f:ClearAllPoints()
    f:Show()
    f:EnableMouse(not editMode)
    return f
end
function Shared.finish(pool)
    for i = pool.used + 1, #pool.frames do
        pool.frames[i]:Hide()
    end
    pool.used = 0
end

function Shared.playToggle()
    if PlaySound and SOUNDKIT then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function Shared.refuse(reason)
    if reason == "combat" and UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
        UIErrorsFrame:AddExternalErrorMessage(ns.G("ERR_NOT_IN_COMBAT", "In combat"))
    else
        ns.Refused(reason)
    end
end

-- Frames start without a parent: SmartNavigationMixin hooks CreateFrame and rebuilds the caller's button groups.
function Shared.newFrame(kind, parent, template)
    local f = CreateFrame(kind, nil, nil, template)
    f:SetParent(parent)
    return f
end
local newFrame = Shared.newFrame

function Shared.simpleTip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(text, 1, 1, 1)
    GameTooltip:Show()
end

function Shared.hideTip(owner)
    if GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

-- The title's buttons stay quiet until the pointer is over the tracker, Ikar's ruling. A short delay before
-- dimming keeps moving between rows from flickering.
local sleepPending = false
local function overTracker()
    local f = Tracker.frames
    return f.background:IsMouseOver() or f.title:IsMouseOver() or (f.scrollBar ~= nil and f.scrollBar:IsMouseOver())
        or ns.Items.IsMouseOver()
end
local checkSleep
checkSleep = guarded(function()
    if overTracker() then
        C_Timer.After(0.4, checkSleep)
        return
    end
    sleepPending = false
    Tracker.frames.title.Tools:SetAlpha(Shared.TOOLS_REST_ALPHA)
end)
function Shared.wake()
    local title = Tracker.frames and Tracker.frames.title
    if not title then
        return
    end
    title.Tools:SetAlpha(1)
    if not sleepPending then
        sleepPending = true
        C_Timer.After(0.4, checkSleep)
    end
end

-- One unit high, kept whole on screen pixels so it neither blurs nor vanishes at any UI scale.
function Shared.separator(parent)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetAtlas("options_horizontaldivider", false)
    t:SetHeight(1)
    t:SetRoundLayoutToNearestPixel(true)
    t:SetAlpha(0.5)
    return t
end

function Shared.arrow(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetAtlas("covenantsanctum-renown-doublearrow", false)
    t:SetSize(9, 12)
    t:SetPoint("CENTER", parent, "RIGHT", -9, 0)
    return t
end

-- The game's double arrow points left when closed and is turned a quarter, to point down, when open.
function Shared.setArrow(t, open)
    t:SetRotation(open and math.pi / 2 or 0)
end

function Shared.iconButton(parent, atlas, size, iconSize, alpha, tip)
    local b = newFrame("Button", parent)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp")
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAtlas(atlas, false)
    b.Icon:SetSize(iconSize, iconSize)
    b.Icon:SetPoint("CENTER")
    b.restAlpha = alpha
    b:SetAlpha(alpha)
    b:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        self:SetAlpha(1)
        if tip then
            Shared.simpleTip(self, tip)
        end
    end))
    b:SetScript("OnLeave", guarded(function(self)
        self:SetAlpha(self.restAlpha)
        Shared.hideTip(self)
    end))
    return b
end

function Shared.menu(owner, build)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, description)
        ns.SafeCall(build, description)
    end)
end

function Shared.button(description, text, fn)
    return description:CreateButton(text, guarded(fn))
end
