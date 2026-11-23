-- Blizzard's minimap widgets as elements of the slot hub: Tracking, Mail, Calendar, the Addon Compartment and the
-- Day/Night cycle, round the map (UI/Minimap.lua's dome), on the bar or in folders like any other, their art at the
-- icon size, their own clicks kept, a right-click opening their hub menu. While the map is ours (UI/Minimap.lua's
-- Owned: the option on and the plate taking it); else each is given back to Blizzard as it was, from the bar and the
-- folders too (Ikar 2026-11-15).
local _, ns = ...

local Natives = {}
ns.Natives = Natives

local Hub, Buttons, Frames = ns.Hub, ns.HubButtons, ns.Frames
local L = ns.L

local NAME = {
    TRACKING = "KaLiHUD_Tracking", MAIL = "KaLiHUD_Mail", CALENDAR = "KaLiHUD_Calendar",
    COMPARTMENT = "KaLiHUD_Compartment", DIEL = "KaLiHUD_Diel",
}
Natives.NAME = NAME
local ORDER = { NAME.TRACKING, NAME.MAIL, NAME.CALENDAR, NAME.COMPARTMENT, NAME.DIEL }

-- Blizzard's DropdownButtons among them (Blizzard_Minimap's XML): their menu opens on a left press, never by Click();
-- their OnLoad_Intrinsic registers the left button's press and release alone.
local DROPDOWN = { [NAME.TRACKING] = true, [NAME.COMPARTMENT] = true }
-- A widget's own click registration (its OnLoad's), muted while a right-click goes to the hub.
local OWN_CLICKS = { [NAME.CALENDAR] = "AnyUp" }
-- Their frames at Blizzard's own size (Blizzard_Minimap's XML) wherever they stand, which DRAWN was measured at.
local SIZE = { [NAME.TRACKING] = { 23, 23 }, [NAME.CALENDAR] = { 23, 23 }, [NAME.COMPARTMENT] = { 23, 22 } }
-- The longer side of each one's art (Forever's atlases, texels over 40/255 alpha: the framed buttons 22 of 23, the
-- compartment's 18.5, the envelope 28 of 32, the day/night ring 38.5 of 42).
local DRAWN = {
    [NAME.TRACKING] = 22, [NAME.MAIL] = 28, [NAME.CALENDAR] = 22, [NAME.COMPARTMENT] = 18.5, [NAME.DIEL] = 38.5,
}
-- Each one's icon on its handle while it doesn't show (no mail, no invite), for it to be dragged all the same.
local HANDLE_ATLAS = {
    [NAME.TRACKING] = "ui-hud-minimap-tracking-button",
    [NAME.MAIL] = "ui-hud-minimap-mail-icon",
    [NAME.CALENDAR] = "ui-hud-minimap-calendar-button",
    [NAME.COMPARTMENT] = "ui-hud-minimap-addon-indicator",
    [NAME.DIEL] = "UI-HUD-Minimap-DayCycle",
}
-- The day/night ring stands this far past the map's ring.
local DIEL_GAP = 2

-- How Blizzard had each (Frames.Keep), and where each on the bar was put, to put it back there if Blizzard moves it.
local kept, onBar = {}, {}
-- Those whose frame raised an error as it was placed, for the rest of the session: given back to Blizzard as it was,
-- it takes no place in the hub (Size answers 0), which is laid out without it. A patch may change what one of these
-- frames lets an addon do; its error took the bar's whole layout with it (the review of 2026-11-18).
local refused = {}

local function frameOf(name)
    if name == NAME.TRACKING then
        return _G.MinimapCluster.Tracking
    elseif name == NAME.MAIL then
        return _G.MinimapCluster.IndicatorFrame
    elseif name == NAME.CALENDAR then
        return _G.GameTimeFrame
    elseif name == NAME.COMPARTMENT then
        return _G.AddonCompartmentFrame
    elseif name == NAME.DIEL then
        return _G.MinimapCluster.DielFrame
    end
end
Natives.Frame = frameOf

-- What takes its clicks: the tracking frame's button, the mail's envelope, else itself.
local function clickTarget(name)
    local f = frameOf(name)
    if name == NAME.TRACKING and f and f.Button then
        return f.Button
    elseif name == NAME.MAIL and f and f.MailFrame then
        return f.MailFrame
    end
    return f
end
Natives.ClickTarget = clickTarget

function Natives.IsDropdown(name)
    return DROPDOWN[name] == true
end

-- Its art's longer side at the icon size, as every icon of ours (Ikar 2026-11-14: "all the icons").
local function scaleOf(name)
    return Hub.IconSize() / DRAWN[name]
end

local function hasMail(f)
    local mf = f.MailFrame
    return (mf and mf:IsShown()) or ns.Call(HasNewMail) == true
end

-- The mail with none to read, the slots locked: its envelope doesn't show.
local function noMail(name, f)
    return name == NAME.MAIL and Hub.IsLocked() and not hasMail(f)
end

-- The width it takes: the icon size; 0 when it can't show at all (the map not ours). On the bar the mail keeps its
-- place with no mail, empty: the items beside it stand still as mail comes and goes (Ikar's rule: outside Edit Mode
-- nothing moves on a game event; its place given up and taken back shifted them each time). In a folder's list
-- (inList), laid out as it opens, it is left out then.
function Natives.Size(name, inList)
    local f = frameOf(name)
    if not (f and ns.Minimap.Owned()) or refused[name] then
        return 0
    end
    if inList and noMail(name, f) then
        return 0
    end
    return Hub.IconSize()
end

-- Its centre at (ux, uy) in UIParent's units, whatever its own scale.
local function placeAt(f, ux, uy)
    local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux * k, uy * k)
end

-- Taken out of the map's cluster into `parent` (UIParent, or a folder's list), shown at its size and `scale`: the
-- cluster is a ResizeLayoutFrame, and Edit Mode's size slider has its Layout() size it round its children, one on the
-- bar stretching it up the screen, the map on its top (Ikar 2026-11-14). Never MarkIgnoreInLayout: it taints.
local function take(name, f, parent, strata, level, scale)
    Frames.Keep(kept, name, f, true)
    if f:GetParent() ~= parent then
        f:SetParent(parent)
    end
    f:Show()
    f:SetFrameStrata(strata)
    f:SetFrameLevel(level)
    local size = SIZE[name]
    if size then
        f:SetSize(size[1], size[2])
    end
    if name == NAME.TRACKING then
        if f.Background then
            f.Background:Hide()
        end
        if f.Button then
            Frames.Keep(kept, "trackingButton", f.Button, true)
            f.Button:ClearAllPoints()
            f.Button:SetAllPoints(f)
        end
    end
    f:SetScale(scale)
end

-- Its handle where it stands while the slots are unlocked: with its icon while it doesn't show.
local function placeHandle(name, ux, uy)
    if not ux then
        Buttons.PlaceHandle(name, nil)
        return
    end
    local target = clickTarget(name)
    local shown = target ~= nil and target:IsVisible() and frameOf(name):GetAlpha() > 0
    Buttons.PlaceHandle(name, ux, uy, Hub.IconSize() + 4, shown, HANDLE_ATLAS[name])
end

-- Its clicks taken or not; how its click target took them is kept, to give back.
local function setClicks(name, f, on)
    local click = clickTarget(name)
    if click and click ~= f then
        Frames.Keep(kept, name .. " click", click)
        click:EnableMouse(on)
    elseif click then
        click:EnableMouse(on)
    end
end

-- One whose frame raised an error under our hands: the error is kept (ns.SafeCall), the frame given back to Blizzard
-- as far as it lets itself be, and the hub laid out again without it.
local function refuse(name)
    refused[name] = true
    onBar[name] = nil
    ns.SafeCall(Frames.GiveBack, kept, name)
    ns.SafeCall(Frames.GiveBack, kept, name .. " click")
    Buttons.PlaceHandle(name, nil)
    ns.InfoBar.Request()
end

local function placeOnBar(name, f, ux, uy, holder)
    if holder then
        onBar[name] = nil
    else
        local at = onBar[name] or {}
        at.ux, at.uy = ux, uy
        onBar[name] = at
    end
    take(name, f, holder or UIParent, holder and holder:GetFrameStrata() or "MEDIUM",
        holder and holder:GetFrameLevel() + 5 or 18, scaleOf(name))
    -- The mail with none to read keeps its place on the bar, its envelope out of sight.
    local hide = noMail(name, f)
    Frames.SetHidden(kept, name, f, hide)
    setClicks(name, f, not hide)
    if ns.HubDrag.Current() ~= name then
        placeAt(f, ux, uy)
    end
    placeHandle(name, ux, uy)
end

-- On the bar at (ux, uy), or in `holder`, a folder's list, shown and hidden with it.
function Natives.PlaceOnBar(name, ux, uy, holder)
    local f = frameOf(name)
    if not f or refused[name] then
        return
    end
    if not ns.SafeCall(placeOnBar, name, f, ux, uy, holder) then
        refuse(name)
    end
end

local function invited()
    local t = _G.GameTimeCalendarInvitesTexture
    return t ~= nil and t:IsShown()
end

-- Seen or not, each as its side says: on the bar while it shows (and has room), in a folder, round the map always or
-- on hover (or while unlocked, or the calendar with an invite) while the map shows, never hidden; the mail never
-- without mail while locked.
function Natives.UpdateVisibility(hovered)
    if not ns.Minimap.Owned() then
        return
    end
    local unlocked, d, onPlate = not Hub.IsLocked(), ns.Minimap.Dome()
    local mapShown, T = d ~= nil, ns.InfoBar.Top()
    for _, name in ipairs(ORDER) do
        local f, e = frameOf(name), Hub.Entry(name)
        if f and e and not refused[name] then
            local show
            if e.side == "hidden" then
                show = false
            elseif e.side == "folder" then
                show = Natives.Size(name, true) > 0
            elseif Hub.BAR[e.side] then
                -- on the bar while it has room for it; else in the list of what doesn't fit, or nowhere
                -- (UI/Hub/InfoBar.lua's fit)
                local where = ns.InfoBar.Where(name)
                if where == "bar" then
                    show = ns.db.options.infoBar and Natives.Size(name) > 0 and not noMail(name, f)
                else
                    show = where ~= nil and Natives.Size(name, true) > 0
                end
            elseif Hub.Spills(e, d, T, onPlate) then
                show = onBar[name] ~= nil and Natives.Size(name) > 0 and not noMail(name, f)
            else
                show = mapShown and (unlocked or e.show ~= "hover" or hovered or name == NAME.CALENDAR and invited())
                if name == NAME.MAIL and not unlocked and f.MailFrame and not hasMail(f) and not f:IsShown() then
                    show = false
                end
            end
            Frames.SetHidden(kept, name, f, not show)
            setClicks(name, f, show)
        end
    end
end

-- One of them where its side says: round the map's dome `d`, on the bar where InfoBar last put it, in a folder by
-- that folder's list.
local function placeOne(name, f, e, d, onPlate)
    local o, T, drag = ns.db.options, ns.InfoBar.Top(), ns.HubDrag.Current()
    local spills = Hub.Spills(e, d, T, onPlate)
    if spills and not (o.infoBar and ns.InfoBar.Placed(name)) then
        -- past its pocket's places with no room left on the bar: nowhere
        onBar[name] = nil
        placeHandle(name, nil)
    elseif Hub.BAR[e.side] or spills then
        local at = onBar[name]
        local where = ns.InfoBar.Where(name)
        if Hub.BAR[e.side] and where ~= "bar" then
            -- no room for it on the bar: in the list of what doesn't fit, whose layout places it, or nowhere
            onBar[name] = nil
            if not where then
                placeHandle(name, nil)
            end
        elseif at and o.infoBar then
            Natives.PlaceOnBar(name, at.ux, at.uy)
        end
    elseif e.side == "folder" then
        onBar[name] = nil
    elseif e.side ~= "hidden" and d then
        onBar[name] = nil
        local diel = name == NAME.DIEL
        take(name, f, UIParent, "MEDIUM", 18, scaleOf(name) * (diel and o.minimapDielScale / 100 or 1))
        local ux, uy = Hub.SlotPoint(e, d, T, onPlate, diel and d.ring + DIEL_GAP or nil)
        if drag ~= name then
            placeAt(f, ux, uy)
        end
        placeHandle(name, ux, uy)
    else
        placeHandle(name, nil)
    end
end

-- Each where it goes (placeOne), on its own: one whose frame raises an error leaves the others theirs (refuse). Then
-- seen or not.
function Natives.Place()
    if not ns.Minimap.Owned() then
        return
    end
    local d, onPlate = ns.Minimap.Dome()
    for _, name in ipairs(ORDER) do
        local f, e = frameOf(name), Hub.Entry(name)
        if f and e and not refused[name] and not ns.SafeCall(placeOne, name, f, e, d, onPlate) then
            refuse(name)
        end
    end
    Natives.UpdateVisibility(ns.Minimap.IsHovered())
end

local function placeIfOn()
    Natives.Place()
end

-- Placed again once, on the next frame, however many ask.
function Natives.Request()
    ns.Later("natives", placeIfOn)
end

-- The minimap option on: the DropdownButtons hear the right release too, for their hub menu (never its press, which
-- would open their own).
function Natives.Activate()
    for name in pairs(DROPDOWN) do
        local t = clickTarget(name)
        if t and t.RegisterForMouse then
            t:RegisterForMouse("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
        end
    end
end

-- The minimap option off: each given back to Blizzard as it was (parent, place, size, scale, layer, alpha, mouse),
-- the DropdownButtons on the left button alone again, the handles gone.
function Natives.Restore()
    Frames.GiveBack(kept, "trackingButton")
    for _, name in ipairs(ORDER) do
        Frames.GiveBack(kept, name)
        Frames.GiveBack(kept, name .. " click")
        Buttons.PlaceHandle(name, nil)
        onBar[name] = nil
    end
    local tracking = frameOf(NAME.TRACKING)
    if tracking and tracking.Background then
        tracking.Background:Show()
    end
    for name in pairs(DROPDOWN) do
        local t = clickTarget(name)
        if t and t.RegisterForMouse then
            t:RegisterForMouse("LeftButtonDown", "LeftButtonUp")
        end
    end
end

local function over(r)
    return r ~= nil and r:IsShown() and r:IsMouseOver()
end

-- Whether the pointer is on one of them.
function Natives.IsHovered()
    for _, name in ipairs(ORDER) do
        local f, click = frameOf(name), clickTarget(name)
        if over(f) or click ~= f and over(click) then
            return true
        end
    end
    return false
end

-- ---------- Their clicks and tooltips ----------

local function hubOn()
    return ns.Minimap.Owned()
end

-- None of them has a right-click of its own (UI/Hub/Menus.lua's Theirs): theirs opens the hub menu (Ikar 2026-11-17:
-- "Let's focus on having a consistent right click"), the padlock shut or open.
local function hubClick(btn)
    return btn == "RightButton" and hubOn()
end

-- The hints under the widget's own tooltip, or under its name when it shows none.
local function addHints(self, name)
    if not hubOn() then
        return
    end
    if not GameTooltip:IsOwned(self) then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(Hub.Label(name), 1, 0.82, 0)
    end
    ns.HubMenus.AddHints(GameTooltip, name)
    GameTooltip:Show()
end

-- A right-click opening its hub menu and the hints on its tooltip, its own clicks left as they are; dragging goes
-- through the handle over it while unlocked.
local function wire(name)
    local target = clickTarget(name)
    if not (target and target.HookScript) then
        return
    end
    -- each hook under the handlers' guard (ns.Guarded), or doing nothing but a guarded call
    target:HookScript("OnMouseDown", ns.Guarded(function(self, btn)
        if OWN_CLICKS[name] and hubClick(btn) then
            self:RegisterForClicks("LeftButtonUp")
            self._khMuted = true
        end
        -- what its left button opens (a menu at once, the calendar on release) takes its tooltip away, as our buttons'
        -- click does (UI/Hub/Buttons.lua's onClick); the game keeps it, Blizzard's own calendar button rebuilding it
        -- while it owns it, which it no longer does once hidden. The mail and the day/night ring open nothing.
        if btn == "LeftButton" and (DROPDOWN[name] or OWN_CLICKS[name]) and hubOn() and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end))
    target:HookScript("OnMouseUp", ns.Guarded(function(self, btn)
        if hubClick(btn) then
            ns.SafeCall(ns.HubMenus.OpenElement, self, name)
        end
        if self._khMuted then
            self._khMuted = nil
            C_Timer.After(0, function()
                self:RegisterForClicks(OWN_CLICKS[name])
            end)
        end
    end))
    -- Hooked, never set: these are Blizzard's frames, and their own scripts stay theirs. DielFrame is a plain Frame
    -- without a tooltip of its own: the hints make one, which its leaving hides.
    local plain = name == NAME.DIEL and not target:GetScript("OnEnter")
    target:HookScript("OnEnter", function(self)
        ns.SafeCall(addHints, self, name)
    end)
    if plain then
        target:HookScript("OnLeave", ns.Guarded(function(self)
            if GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end))
    end
    -- The calendar rebuilds its tooltip every frame while it owns it, so the hints go back under it every frame. An
    -- error there would come back every frame too: the first one is kept, and the hints left off until a reload.
    if name == NAME.CALENDAR then
        local failed = false
        local function hintsAgain()
            ns.HubMenus.AddHints(GameTooltip, name)
            GameTooltip:Show()
        end
        target:HookScript("OnUpdate", function(self)
            if not failed and hubOn() and GameTooltip:IsOwned(self) then
                failed = not ns.SafeCall(hintsAgain)
            end
        end)
    end
end

function Natives.Start()
    Hub.AddNative(NAME.TRACKING, { label = L.OPT_MM_TRACKING, side = "pocketLeft", order = 51,
        angle = Hub.POCKET_ANGLE.pocketLeft, show = "always" })
    Hub.AddNative(NAME.MAIL, { label = L.ITEM_MAIL, side = "pocketRight", order = 52,
        angle = Hub.POCKET_ANGLE.pocketRight, show = "always" })
    Hub.AddNative(NAME.CALENDAR, { label = L.OPT_MM_CALENDAR, side = "ring", order = 53, angle = 138, show = "always" })
    Hub.AddNative(NAME.COMPARTMENT, { label = L.OPT_MM_COMPARTMENT, side = "ring", order = 54, angle = 160,
        show = "always" })
    Hub.AddNative(NAME.DIEL, { label = L.OPT_MM_DIEL, side = "ring", order = 55, angle = 48, show = "always" })
    for _, name in ipairs(ORDER) do
        wire(name)
        ns.Minimap.HookHover(frameOf(name))
        ns.Minimap.HookHover(clickTarget(name))
    end
    ns.On("CALENDAR_UPDATE_PENDING_INVITES", ns.Minimap.UpdateHover)
    -- the mail shows or hides where it stands; in a folder's list it joins or leaves it
    ns.On("UPDATE_PENDING_MAIL", function()
        if ns.Minimap.Owned() then
            Natives.Request()
            local e = Hub.Entry(NAME.MAIL)
            if e and e.side == "folder" then
                ns.InfoBar.Request()
            end
        end
    end)
end
