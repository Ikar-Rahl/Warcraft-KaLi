-- The minimap button, and the same button for the information bars (Ikar, 2026-11-10: "a minimap button, ideally
-- something that will be caught by Titan Panel"). Both do what the compartment does: a click opens the notebook, a right
-- click the options, and the tooltip gives each profession's counts.
--
-- The bars (Titan Panel, ChocolateBar, Bazooka...) find addons through LibDataBroker-1.1. No library is shipped: each
-- bar loads LibDataBroker itself, so it is there whenever a bar is, and the launcher is made at login, once every addon
-- has loaded. Its type is "launcher" (an icon and a name, no text), so no total shows (Ikar's ruling of 2026-11-09).
--
-- The minimap button is the addon's own, built as the common minimap buttons are (the tracking border, the round
-- background, the icon), so it sits among them and button collectors gather it by its name. Dragged, it goes round the
-- minimap's edge, round or square: SexyMap and the like say which through GetMinimapShape. Its place is kept in ui.minimap.
local _, ns = ...
local L = ns.L

local Button = {}
ns.MinimapButton = Button

local NAME = "KaLiRecipeMinimapButton"
-- The TOC's ## IconTexture: F2, « Plume fendue » (Ikar's pick, 2026-11-11), made by recipe/tools/make_icon.py.
local ICON = "Interface\\AddOns\\KaLiRecipe\\Media\\Icon"
local DEFAULT_ANGLE = 200
-- Past the minimap's edge, as the other buttons sit.
local OUTSIDE = 5
-- Which quarters of each shape are round: bottom right, bottom left, top right, top left. Elsewhere the edge is square.
local SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button

-- Where an angle puts the button, from the minimap's centre: on the circle in a round quarter, on the square's edge in
-- a square one.
function Button.Offset(angle, width, height, shape)
    local a = math.rad(angle)
    local x, y = math.cos(a), math.sin(a)
    local q = (x < 0 and 2 or 1) + (y > 0 and 2 or 0)
    local w, h = width / 2 + OUTSIDE, height / 2 + OUTSIDE
    if (SHAPES[shape] or SHAPES.ROUND)[q] then
        return x * w, y * h
    end
    local dw, dh = math.sqrt(2) * w - 10, math.sqrt(2) * h - 10
    return math.max(-w, math.min(x * dw, w)), math.max(-h, math.min(y * dh, h))
end

local function angle()
    return ns.db.ui.minimap or DEFAULT_ANGLE
end

local function place()
    local shape = ns.Call(GetMinimapShape) or "ROUND"
    local x, y = Button.Offset(angle(), Minimap:GetWidth() or 0, Minimap:GetHeight() or 0, shape)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- The pointer's angle around the minimap's centre, in degrees.
local function pointerAngle()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and px and scale and scale > 0) then
        return nil
    end
    return math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
end

-- The icon slightly cropped at rest and whole while pressed, as the other minimap buttons look pressed.
local function iconCrop(pressed)
    local c = pressed and 0 or 0.05
    button.icon:SetTexCoord(c, 1 - c, c, 1 - c)
end

-- The tooltip on the side of the screen with room for it.
local function showTooltip(self)
    local x, y = self:GetCenter()
    local right = (x or 0) > (UIParent:GetWidth() or 0) / 2
    local top = (y or 0) > (UIParent:GetHeight() or 0) / 2
    local side = right and "RIGHT" or "LEFT"
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint((top and "TOP" or "BOTTOM") .. side, self, (top and "BOTTOM" or "TOP") .. side)
    ns.Options.FillTooltip(GameTooltip, not ns.db.options.minimapLock)
    GameTooltip:Show()
end

local function make()
    local b = CreateFrame("Button", NAME, Minimap)
    button = b
    -- Above the minimap's own layers, and kept there when an addon reshuffles the minimap's children.
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    if b.SetFixedFrameStrata then
        b:SetFixedFrameStrata(true)
        b:SetFixedFrameLevel(true)
    end
    b:SetSize(31, 31)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    -- The common minimap button's art; the client's own sizes differ between retail's and classic's art.
    local retail = WOW_PROJECT_ID == nil or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.border:SetPoint("TOPLEFT")
    b.border:SetSize(retail and 50 or 53, retail and 50 or 53)
    b.background = b:CreateTexture(nil, "BACKGROUND")
    b.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(ICON)
    if retail then
        b.background:SetSize(24, 24)
        b.background:SetPoint("CENTER")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("CENTER")
    else
        b.background:SetSize(20, 20)
        b.background:SetPoint("TOPLEFT", 7, -5)
        b.icon:SetSize(17, 17)
        b.icon:SetPoint("TOPLEFT", 7, -6)
    end
    iconCrop(false)

    b:SetScript("OnClick", function(_, mouse)
        Button.Click(mouse)
    end)
    b:SetScript("OnMouseDown", function()
        iconCrop(true)
    end)
    b:SetScript("OnMouseUp", function()
        iconCrop(false)
    end)
    b:SetScript("OnEnter", function(self)
        if not self.dragging then
            ns.SafeCall(showTooltip, self)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        if ns.db.options.minimapLock then
            return
        end
        self.dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            ns.SafeCall(Button.DragTo, pointerAngle())
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.dragging = nil
        iconCrop(false)
    end)
end

function Button.Click(mouse)
    ns.Options.Click(mouse)
end

-- While dragged: the button follows the pointer round the edge.
function Button.DragTo(a)
    if a and button then
        ns.db.ui.minimap = a
        place()
    end
end

-- Shown or hidden as its option says, at its place.
function Button.Refresh()
    if ns.db.options.minimap then
        if not button then
            make()
        end
        place()
        button:Show()
    elseif button then
        button:Hide()
    end
end

function Button.Get()
    return button
end

-- The information bars' launcher, when one of them has loaded LibDataBroker.
local function launcher()
    local stub = LibStub
    local ldb = type(stub) == "table" and ns.Call(stub.GetLibrary, stub, "LibDataBroker-1.1", true)
    if type(ldb) ~= "table" or ns.Call(ldb.GetDataObjectByName, ldb, ns.TITLE) then
        return nil
    end
    return ns.Call(ldb.NewDataObject, ldb, ns.TITLE, {
        type = "launcher",
        label = ns.TITLE,
        icon = ICON,
        OnClick = function(_, mouse)
            Button.Click(mouse)
        end,
        OnTooltipShow = function(tooltip)
            ns.SafeCall(ns.Options.FillTooltip, tooltip)
        end,
    })
end

function Button.Start()
    if Minimap then
        Button.Refresh()
    end
    Button.launcher = launcher()
end
