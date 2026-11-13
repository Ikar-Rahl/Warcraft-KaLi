-- Marks on recipe items wherever the game shows an item slot: vendors and bags (Blizzard's and Baganator's, through its
-- own corner widgets). The addon's own small frames ride on top of Blizzard's buttons; it reads them through post-hooks
-- and changes nothing of theirs. Each mark is an option.
--   top left: the state (known: the tracker's check; to learn: the required rank in its colour; too low: in red),
--             or, on an item a recipe makes, the profession's small icon;
--   bottom left: this character holds it (the banker on a dark disc); bottom right: another character does (friend).
-- None on the auction house's rows, Blizzard's or Auctionator's (Ikar, 2026-11-13: they clashed with what those lists
-- already do): there the recipe's tooltip says it all, and « Relever les recettes » notes them.
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local Markers = {}
ns.Markers = Markers

local overlays = setmetatable({}, { __mode = "k" })

local function disc(o, size)
    local t = o:CreateTexture(nil, "OVERLAY", nil, 1)
    t:SetSize(size, size)
    t:SetColorTexture(0, 0, 0, 0.75)
    local mask = o:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(t)
    t:AddMaskTexture(mask)
    return t
end

-- slot: icon marks inside a 37-unit item slot; inline: one row of small marks (Baganator's corner widgets).
local function overlay(button, inline)
    local o = overlays[button]
    if o then
        return o
    end
    o = W.Frame("Frame", button)
    o:SetFrameLevel(button:GetFrameLevel() + 5)
    o.check = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.check:SetSize(16, 16)
    W.SetAtlas(o.check, W.ATLAS.known)
    o.badge = W.Badge(o, 24, 15)
    o.craft = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.craft:SetSize(17, 14)
    o.discMine = disc(o, 15)
    o.mine = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.mine:SetSize(14, 14)
    W.SetAtlas(o.mine, W.ATLAS.banker)
    o.alt = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.alt:SetSize(15, 15)
    W.SetAtlas(o.alt, W.ATLAS.friend)
    if inline then
        o:SetSize(110, 18)
        o.inline = true
    else
        o:SetAllPoints(button)
        o.check:SetPoint("TOPLEFT", -2, 2)
        o.badge:SetPoint("TOPLEFT", -3, 3)
        o.craft:SetPoint("TOPLEFT", -1, 1)
        o.discMine:SetPoint("BOTTOMLEFT", 0, 0)
        o.mine:SetPoint("CENTER", o.discMine, "CENTER", 0, 0)
        o.alt:SetPoint("BOTTOMRIGHT", 1, -1)
    end
    overlays[button] = o
    return o
end

local function hideAll(o)
    for _, part in ipairs({ o.check, o.badge, o.craft, o.discMine, o.mine, o.alt }) do
        part:Hide()
    end
end

-- In a row, the shown marks one after another.
local function lineUp(o, parts)
    local x = 0
    for _, part in ipairs(parts) do
        part:ClearAllPoints()
        part:SetPoint("LEFT", o, "LEFT", x, 0)
        x = x + part:GetWidth() + 3
    end
    o.discMine:SetShown(o.mine:IsShown())
    if o.discMine:IsShown() then
        o.discMine:ClearAllPoints()
        o.discMine:SetPoint("CENTER", o.mine, "CENTER", 0, 0)
    end
    return #parts
end

-- The best of the recipes that make an item: one this character knows, then one another knows, then one seen.
local function crafter(m, item, withSeen)
    local best, bestRank
    for _, x in ipairs(m:MadeBy(item)) do
        local rank = m:Knows(m.me, x.spell) and 1 or (#x.who > 0 and 2) or (withSeen and x.seen and 3) or nil
        if rank and (not bestRank or rank < bestRank) then
            best, bestRank = x, rank
        end
    end
    return best, bestRank
end

-- ctx: { owned = false in the character's own bags, where "you hold it" says nothing }. Returns whether anything shows.
function Markers.Apply(o, item, ctx)
    hideAll(o)
    local m = ns.book
    if not (item and m) then
        return false
    end
    local opt = ns.db.options
    ctx = ctx or {}
    local shown = {}
    local spell = ns.RECIPE_ITEMS[item]
    if spell then
        local state = m:State(spell)
        if state == "known" and opt.mKnown then
            o.check:Show()
            shown[#shown + 1] = o.check
        elseif state == "learnable" and opt.mLearnable or state == "toolow" and opt.mTooLow then
            W.SetBadge(o.badge, spell, m.me)
            o.badge:Show()
            shown[#shown + 1] = o.badge
        end
        local pos = m:Possession(spell)
        if pos and pos.mine and opt.mOwned and ctx.owned ~= false then
            o.discMine:Show()
            o.mine:Show()
            shown[#shown + 1] = o.mine
        end
        if pos and #pos.alts > 0 and opt.mAlt then
            o.alt:Show()
            shown[#shown + 1] = o.alt
        end
    elseif opt.mCraft then
        local x, rank = crafter(m, item, opt.mCraftSeen)
        if x and W.SetAtlas(o.craft, W.PROF_ATLAS[m:Info(x.spell).skill] or "") then
            o.craft:SetDesaturated(rank ~= 1)
            o.craft:SetAlpha(rank == 1 and 1 or 0.55)
            o.craft:Show()
            shown[#shown + 1] = o.craft
        end
    end
    if o.inline then
        return lineUp(o, shown) > 0
    end
    return #shown > 0
end

-- ---------- Vendors ----------

local function updateMerchant()
    if not (MerchantFrame and MerchantFrame:IsShown()) or MerchantFrame.selectedTab == 2 then
        return
    end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local item = GetMerchantItemID((page - 1) * perPage + i)
            Markers.Apply(overlay(button), button:IsShown() and item or nil)
        end
    end
end

local function hideMerchant()
    for i = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button and overlays[button] then
            hideAll(overlays[button])
        end
    end
end

-- ---------- Bags ----------

local containerFrames = {}

local function updateContainer(frame)
    if not (frame and frame:IsShown() and frame.EnumerateValidItems) then
        return
    end
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button:GetBagID(), button:GetID()
        local item = bag and slot and ns.Call(C_Container.GetContainerItemID, bag, slot)
        Markers.Apply(overlay(button), item, { owned = false })
    end
end

local function hookContainers()
    local frames = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        frames[#frames + 1] = _G["ContainerFrame" .. i]
    end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems and not containerFrames[frame] then
            containerFrames[frame] = true
            hooksecurefunc(frame, "UpdateItems", function(self)
                ns.SafeCall(updateContainer, self)
            end)
        end
    end
end

-- Baganator draws its own bags: its corner widgets are the way it offers to mark them.
local function baganator()
    local API = Baganator and Baganator.API
    if not (API and API.RegisterCornerWidget) then
        return false
    end
    local function make(button, which)
        local f = W.Frame("Frame", button)
        f:SetSize(which == "state" and 24 or 15, 15)
        f.o = overlay(f, true)
        f.o:SetAllPoints(f)
        f.which = which
        return f
    end
    local function update(f, details)
        local item = details and details.itemID
        if not item then
            return nil
        end
        local any = Markers.Apply(f.o, item, { owned = false })
        -- One widget per corner: the state or the crafted mark top left, another character's copy bottom right.
        if f.which == "state" then
            f.o.alt:Hide()
            return f.o.check:IsShown() or f.o.badge:IsShown() or f.o.craft:IsShown()
        end
        local alt = f.o.alt:IsShown()
        hideAll(f.o)
        if alt then
            f.o.alt:ClearAllPoints()
            f.o.alt:SetPoint("CENTER")
            f.o.alt:Show()
        end
        return any and alt
    end
    API.RegisterCornerWidget(L.CARNET .. " · " .. L.OPT_MARKS, "kalirecipe_state", function(f, details)
        return update(f, details)
    end, function(button)
        return make(button, "state")
    end, { corner = "top_left", priority = 1 })
    API.RegisterCornerWidget(L.CARNET .. " · " .. L.OPT_M_ALT, "kalirecipe_alt", function(f, details)
        return update(f, details)
    end, function(button)
        return make(button, "alt")
    end, { corner = "bottom_right", priority = 1 })
    return true
end

-- ---------- The auction house: the button, no marks ----------

local auctionButton
-- Shown with the browse list only: other pages (an item's auctions, selling, Auctionator's tabs) have their own buttons
-- down there.
local function syncAuctionButton()
    local browse = AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame
    if auctionButton then
        auctionButton:SetShown(browse ~= nil and browse:IsVisible())
    end
end

-- The addon never searches in the player's place (Ikar, 2026-11-10: "it should never take control over the user"):
-- this button does it, on a click, the whole Recipes category as Blizzard's list on the left would. Whatever the
-- player searches, the recipes in it are noted anyway. In the empty strip along the bottom, right of the money (at the
-- top it sat over « Filtrer » and « Recherche »); a child of the auction house, so its dialogs cover it.
local function makeAuctionButton(browse)
    auctionButton = W.Frame("Button", AuctionHouseFrame, "UIPanelButtonTemplate")
    auctionButton:SetSize(150, 22)
    auctionButton:SetText(L.AH_QUERY)
    auctionButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -10, 4)
    auctionButton:SetScript("OnClick", function()
        ns.SafeCall(ns.Scan.QueryAuctions)
    end)
    auctionButton:SetScript("OnEnter", function(self)
        W.TextTooltip(self, L.AH_QUERY, { { L.AH_QUERY_TIP } })
    end)
    auctionButton:SetScript("OnLeave", W.HideTooltip)
    browse:HookScript("OnShow", syncAuctionButton)
    browse:HookScript("OnHide", syncAuctionButton)
    syncAuctionButton()
end

function Markers.AuctionButton()
    return auctionButton
end

local function hookAuctions()
    local browse = AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame
    if browse and browse.HookScript then
        makeAuctionButton(browse)
        return true
    end
    return false
end

-- ---------- Start ----------

local auctionsHooked = false
function Markers.Start()
    if MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            ns.SafeCall(updateMerchant)
        end)
    end
    if MerchantFrame_UpdateBuybackInfo then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
            ns.SafeCall(hideMerchant)
        end)
    end
    hookContainers()
    Markers.baganator = baganator()
    auctionsHooked = hookAuctions()
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_AuctionHouseUI" and not auctionsHooked then
            auctionsHooked = hookAuctions()
        end
    end)
    ns.OnChange(function()
        updateMerchant()
        for frame in pairs(containerFrames) do
            updateContainer(frame)
        end
        if Markers.baganator and Baganator.API.RequestItemButtonsRefresh then
            Baganator.API.RequestItemButtonsRefresh()
        end
    end)
end
