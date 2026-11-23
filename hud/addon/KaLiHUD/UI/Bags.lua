-- Standalone bag bar folding and clean Blizzard bar art, without depending on FlareUI (adapted from FlareUI's MIT
-- pattern so KaLi HUD works by itself and steps aside cleanly if FlareUI's own bag toggle is already active).
local _, ns = ...

local Bags = {}
ns.Bags = Bags

local arrow, hooked, artTouched, collapsible = nil, false, false, false
local folded = setmetatable({}, { __mode = "k" })

local function manager()
    return _G.MainMenuBarBagManager
end

local function flareOwnsToggle()
    local t = _G.FlareUI_BagBarToggle
    return type(t) == "table" and t.IsShown and t:IsShown()
end

local function expanded()
    local m = manager()
    return not (m and type(m.ShouldBarExpand) == "function") or m:ShouldBarExpand() and true or false
end

local function canTouch(button)
    return type(button) == "table" and not (InCombatLockdown() and button.IsProtected and button:IsProtected())
end

local function rotation(bar)
    local open = expanded()
    if bar.IsHorizontal and bar:IsHorizontal() then
        if bar.IsDirectionLeft and bar:IsDirectionLeft() then
            return open and math.pi or 0
        end
        return open and 0 or math.pi
    end
    local up, down = 3 * math.pi / 2, math.pi / 2
    if bar.IsDirectionUp and bar:IsDirectionUp() then
        return open and down or up
    end
    return open and up or down
end

local function placeArrow()
    local bar, backpack, m = _G.BagsBar, _G.MainMenuBarBackpackButton, manager()
    if not (arrow and collapsible and bar and backpack and m) or flareOwnsToggle() then
        if arrow then
            arrow:Hide()
        end
        return
    end
    if type(bar.GetBagButtonAnchorPoints) ~= "function" then
        return
    end
    local point, relativePoint, x, y = bar:GetBagButtonAnchorPoints()
    local horizontal = bar.IsHorizontal and bar:IsHorizontal()
    arrow:SetSize(horizontal and 10 or 16, horizontal and 16 or 10)
    arrow:ClearAllPoints()
    arrow:SetPoint(point, backpack, relativePoint, 0, 0)
    local rot = rotation(bar)
    arrow.Art:SetRotation(rot)
    arrow.Glow:SetRotation(rot)
    if type(m.EnumerateBagButtons) == "function" then
        for _, button in m:EnumerateBagButtons() do
            if button ~= backpack and button:IsShown() and canTouch(button) then
                button:ClearAllPoints()
                button:SetPoint(point, arrow, relativePoint, x, y)
                break
            end
        end
    end
    arrow:Show()
end

local function fold(collapse)
    local bar, backpack, m = _G.BagsBar, _G.MainMenuBarBackpackButton, manager()
    if not (bar and m and type(m.EnumerateBagButtons) == "function") or flareOwnsToggle() then
        return
    end
    local changed = false
    for _, button in m:EnumerateBagButtons() do
        if button ~= backpack and canTouch(button) then
            if collapse and button:IsShown() then
                folded[button] = true
                button:Hide()
                changed = true
            elseif not collapse and folded[button] then
                folded[button] = nil
                button:Show()
                changed = true
            end
        end
    end
    if changed and type(bar.Layout) == "function" then
        bar:Layout()
    else
        placeArrow()
    end
end

local function ensureArrow()
    if arrow or not _G.BagsBar then
        return arrow
    end
    arrow = CreateFrame("Button", "KaLiHUD_BagBarToggle", nil)
    arrow:SetParent(_G.BagsBar)
    arrow:SetFrameLevel(_G.BagsBar:GetFrameLevel() + 5)
    arrow.Art = arrow:CreateTexture(nil, "ARTWORK")
    arrow.Art:SetAtlas("bag-arrow")
    arrow.Art:SetSize(10, 16)
    arrow.Art:SetPoint("CENTER")
    arrow.Glow = arrow:CreateTexture(nil, "HIGHLIGHT")
    arrow.Glow:SetAtlas("bag-arrow")
    arrow.Glow:SetSize(10, 16)
    arrow.Glow:SetPoint("CENTER")
    arrow.Glow:SetBlendMode("ADD")
    arrow.Glow:SetAlpha(0.4)
    arrow:RegisterForClicks("LeftButtonUp")
    arrow:SetScript("OnClick", ns.Guarded(function()
        local m = manager()
        if m and type(m.ToggleExpandBar) == "function" then
            m:ToggleExpandBar()
        end
    end))
    return arrow
end

local BAR_ART_FRAMES = { "MainActionBar", "BagsBar", "MicroMenu" }

local function applyBarArt(clean)
    if not (clean or artTouched) then
        return
    end
    local alpha = clean and 0 or 1
    for _, name in ipairs(BAR_ART_FRAMES) do
        local f = _G[name]
        if type(f) == "table" then
            if f.BorderArt and f.BorderArt.SetAlpha then
                f.BorderArt:SetAlpha(alpha)
            end
            if f.BackgroundArt and f.BackgroundArt.SetAlpha then
                f.BackgroundArt:SetAlpha(alpha)
            end
        end
    end
    local bar = _G.BagsBar
    if type(bar) == "table" then
        for _, pool in ipairs({ bar.HorizontalDividersPool or false, bar.VerticalDividersPool or false }) do
            if pool and type(pool.EnumerateActive) == "function" then
                for divider in pool:EnumerateActive() do
                    divider:SetAlpha(alpha)
                end
            end
        end
    end
    artTouched = clean
end

local function hookOnce()
    if hooked then
        return
    end
    local bar, m = _G.BagsBar, manager()
    if not (bar and m) then
        return
    end
    hooked = true
    if type(bar.Layout) == "function" then
        hooksecurefunc(bar, "Layout", function()
            ns.SafeCall(placeArrow)
        end)
    end
    if type(bar.UpdateDividers) == "function" then
        hooksecurefunc(bar, "UpdateDividers", ns.Guarded(function()
            if ns.db then
                applyBarArt(ns.db.options.cleanBarArt)
            end
        end))
    end
    if EventRegistry then
        EventRegistry:RegisterCallback("MainMenuBarManager.OnExpandChanged", function()
            if collapsible and not flareOwnsToggle() then
                ns.SafeCall(fold, not expanded())
            end
        end, Bags)
    end
    if type(m.EnumerateBagButtons) == "function" then
        for _, button in m:EnumerateBagButtons() do
            if button ~= _G.MainMenuBarBackpackButton and button.HookScript then
                button:HookScript("OnShow", ns.Guarded(function(self)
                    if collapsible and not flareOwnsToggle() and not expanded() and canTouch(self) then
                        folded[self] = true
                        self:Hide()
                    end
                end))
            end
        end
    end
end

function Bags.Apply()
    if not ns.db then
        return
    end
    local o = ns.db.options
    applyBarArt(o.cleanBarArt)
    if InCombatLockdown() then
        Bags.pending = true
        return
    end
    Bags.pending = false
    local want = not flareOwnsToggle()
    if want or hooked then
        hookOnce()
    end
    local was = collapsible
    collapsible = want
    if collapsible then
        ensureArrow()
        fold(not expanded())
        placeArrow()
    elseif was then
        if arrow then
            arrow:Hide()
        end
        fold(false)
        if _G.BagsBar and type(_G.BagsBar.Layout) == "function" then
            _G.BagsBar:Layout()
        end
    end
end

function Bags.Start()
    ns.On("PLAYER_REGEN_ENABLED", function()
        if Bags.pending then
            Bags.Apply()
        end
    end)
    Bags.Apply()
end