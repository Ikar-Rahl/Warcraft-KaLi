-- The selected recipe, below the notebook's list (Ikar, 2026-11-09: the separate recipe window folded into the
-- notebook, as the classic professions window and quest log laid theirs out). It takes only the room its content
-- needs, up to half the notebook, then scrolls, its bar shown only then: each section on one line beside its label,
-- reagents wrapping as many to a line as fit, « Connue de » only when a character knows it.
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local Detail = {}
ns.Detail = Detail

local PAD, GAP, LINE, CHIP_GAP = 6, 12, 18, 14

local function makeChip(parent)
    local b = W.Frame("Button", parent)
    b:SetHeight(LINE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 0, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.text:SetJustifyH("LEFT")
    b.pin = W.Frame("Button", b)
    b.pin:SetSize(14, 14)
    b.pin.tex = b.pin:CreateTexture(nil, "ARTWORK")
    b.pin.tex:SetAllPoints()
    W.SetAtlas(b.pin.tex, W.ATLAS.pin)
    b:SetScript("OnLeave", W.HideTooltip)
    b.pin:SetScript("OnLeave", W.HideTooltip)
    return b
end

local function makeLabel(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    return fs
end

function Detail.New(parent)
    local d = W.Frame("Frame", parent)
    d.rule = d:CreateTexture(nil, "ARTWORK")
    d.rule:SetHeight(1)
    d.rule:SetPoint("TOPLEFT", 0, 0)
    d.rule:SetPoint("TOPRIGHT", 0, 0)
    d.rule:SetColorTexture(0.42, 0.33, 0.15, 0.9)
    d.icon = W.Frame("Button", d)
    d.icon:SetSize(32, 32)
    d.icon:SetPoint("TOPLEFT", 4, -PAD)
    d.icon.tex = d.icon:CreateTexture(nil, "ARTWORK")
    d.icon.tex:SetAllPoints()
    d.icon:SetScript("OnLeave", W.HideTooltip)
    d.name = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -1)
    d.name:SetPoint("RIGHT", d, "RIGHT", -30, 0)
    d.name:SetJustifyH("LEFT")
    d.badge = W.Badge(d, 24, 15)
    d.badge:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -2)
    d.sub = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.sub:SetPoint("LEFT", d.badge, "RIGHT", 6, 0)
    d.sub:SetPoint("RIGHT", d, "RIGHT", -30, 0)
    d.sub:SetJustifyH("LEFT")
    d.close = W.Frame("Button", d, "UIPanelCloseButton")
    d.close:SetSize(22, 22)
    d.close:SetPoint("TOPRIGHT", 0, -2)
    d.close:SetScript("OnClick", function()
        ns.SafeCall(ns.Notebook.Select, nil)
    end)
    d.close:SetScript("OnEnter", function(self)
        W.TextTooltip(self, L.CLOSE_DETAIL)
    end)
    d.close:SetScript("OnLeave", W.HideTooltip)

    d.scroll = W.Frame("ScrollFrame", d)
    d.scroll:SetPoint("TOPLEFT", 0, -(PAD + 38))
    d.scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    d.scroll:EnableMouseWheel(true)
    d.body = W.Frame("Frame", d.scroll)
    d.body:SetSize(10, 10)
    d.scroll:SetScrollChild(d.body)
    d.bar = W.Frame("EventFrame", d, "MinimalScrollBar")
    d.bar:SetPoint("TOPLEFT", d.scroll, "TOPRIGHT", 4, 0)
    d.bar:SetPoint("BOTTOMLEFT", d.scroll, "BOTTOMRIGHT", 4, 0)
    if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
        ScrollUtil.InitScrollFrameWithScrollBar(d.scroll, d.bar)
    end
    -- No bar when it all fits (Ikar, 2026-11-10: a tiny bar showed with nothing to scroll).
    if d.bar.SetHideIfUnscrollable then
        d.bar:SetHideIfUnscrollable(true)
    end
    d.chips = W.Pool(function()
        return makeChip(d.body)
    end)
    d.labels = W.Pool(function()
        return makeLabel(d.body)
    end)
    d:Hide()
    return d
end

-- Ink on Book's parchment, the game's light text on Clean.
local function colours(book)
    if book then
        return W.INK, { 0, 0, 0 }, { 0.3, 0.22, 0.12 }
    end
    return W.WHITE, W.GOLD, W.GRAY
end

-- Fills the detail for a recipe at a width; returns the height it wants (header and all its lines).
function Detail.Fill(d, spell, width, book)
    local m = ns.book
    local info = m:Info(spell)
    d.chips:ReleaseAll()
    d.labels:ReleaseAll()
    if not info then
        d:Hide()
        return 0
    end
    local text, label, dim = colours(book)
    local me = m.me
    local product = info.product
    local icon = product and ns.Call(C_Item.GetItemIconByID, product) or ns.Call(C_Spell and C_Spell.GetSpellTexture, spell)
    d.icon.tex:SetTexture(icon or ns.Game.ProfIcon(info.skill))
    d.icon:SetScript("OnEnter", function(self)
        if product then
            W.ItemTooltip(self, product)
        else
            W.RecipeTooltip(self, spell)
        end
    end)
    local productName = product and m.game:ItemName(product)
    d.name:SetText(productName or m:Name(spell))
    local quality = product and ns.Call(C_Item.GetItemQualityByID, product)
    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if book then
        d.name:SetTextColor(0, 0, 0)
    elseif qc then
        d.name:SetTextColor(qc.r, qc.g, qc.b)
    else
        d.name:SetTextColor(1, 1, 1)
    end
    W.SetBadge(d.badge, spell, me)
    local sub = m:CategoryName(info.cat)
    if productName and productName ~= m:Name(spell) then
        sub = sub .. " · " .. m:Name(spell)
    end
    d.sub:SetText(sub)
    d.sub:SetTextColor(dim[1], dim[2], dim[3])

    -- The lines: a label in its column, values flowing beside it.
    local lines = {}
    if #info.reagents > 0 then
        local chips = {}
        for _, r in ipairs(info.reagents) do
            local have = m.game:ItemCount(r[1])
            chips[#chips + 1] = { icon = ns.Call(C_Item.GetItemIconByID, r[1]), text = string.format("%d/%d %s", have, r[2],
                m.game:ItemName(r[1]) or "?"), colour = have >= r[2] and text or dim, item = r[1] }
        end
        lines[#lines + 1] = { L.D_COMPONENTS, chips }
    end
    for i, s in ipairs(m:Sightings(spell)) do
        local where = ns.Text.Where(m, s)
        local price = ns.Text.Price(s)
        if price then
            where = where .. " · " .. price
        end
        if s.k ~= "ah" then
            where = where .. " · " .. ns.Text.Date(s.t)
        end
        lines[#lines + 1] = { i == 1 and L.D_SEEN or "", { { text = where, colour = text, pin = s.x and s or nil } } }
    end
    local o = ns.db.options
    local pos = m:Possession(spell, me)
    local holds = {}
    if pos and pos.mine and o.nbOwned then
        holds[#holds + 1] = { atlas = W.ATLAS.banker, colour = text,
            text = string.format(L.HELD_MINE, pos.mine.total, ns.Text.HeldIn(pos.mine.bags, pos.mine.bank, true)) }
    end
    if pos and o.nbAlt then
        for _, a in ipairs(pos.alts) do
            holds[#holds + 1] = { atlas = W.ATLAS.friend, colour = text,
                text = string.format(L.HELD_ALT, m:CharName(a.key), a.total, ns.Text.HeldIn(a.bags, a.bank, false)) }
        end
    end
    if #holds > 0 then
        lines[#lines + 1] = { L.D_HELD, holds }
    end
    local who = m:Knowers(spell)
    if #who > 0 then
        local names = {}
        for i, key in ipairs(who) do
            names[i] = string.format(L.NAME_RANK, key == me and L.THIS_CHAR or m:CharName(key), m:Rank(key, info.skill))
        end
        lines[#lines + 1] = { L.D_KNOWN, { { text = table.concat(names, ", "), colour = text } } }
    end
    -- No rank anywhere yet: a trainer's recipe met before the addon, whose trainer hides known ones by default.
    if not info.req then
        lines[#lines + 1] = { L.D_RANK, { { text = string.format(L.RANK_UNKNOWN, ns.G("USED", "Déjà connu")), colour = dim } } }
    end

    -- The label column is as wide as the longest label shown.
    local labelWidth = 0
    local labels = {}
    for i, line in ipairs(lines) do
        local fs = d.labels:Acquire()
        fs:SetText(line[1])
        fs:SetTextColor(label[1], label[2], label[3])
        labels[i] = fs
        labelWidth = math.max(labelWidth, fs:GetStringWidth())
    end
    local valueLeft = 4 + labelWidth + GAP
    local valueWidth = math.max(60, width - valueLeft - 18)
    local y = 0
    for i, line in ipairs(lines) do
        labels[i]:SetPoint("TOPLEFT", d.body, "TOPLEFT", 4, -y - 2)
        local x, rowY = 0, y
        for _, c in ipairs(line[2]) do
            local chip = d.chips:Acquire()
            chip.icon:SetShown(c.icon ~= nil or c.atlas ~= nil)
            if c.atlas then
                W.SetAtlas(chip.icon, c.atlas)
            else
                chip.icon:SetTexture(c.icon)
            end
            chip.text:ClearAllPoints()
            if chip.icon:IsShown() then
                chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 4, 0)
            else
                chip.text:SetPoint("LEFT", chip, "LEFT", 0, 0)
            end
            chip.text:SetText(c.text)
            chip.text:SetTextColor(c.colour[1], c.colour[2], c.colour[3])
            chip.text:SetWordWrap(false)
            -- Longer than the room on a line (a long name, a narrow notebook): cut with the game's ellipsis, whole on hover.
            local room = valueWidth - (chip.icon:IsShown() and 20 or 0) - (c.pin and 19 or 0)
            local cut = chip.text:GetStringWidth() > room
            chip.text:SetWidth(cut and room or 0)
            local w = (chip.icon:IsShown() and 20 or 0) + (cut and room or chip.text:GetStringWidth())
            chip.pin:SetShown(c.pin ~= nil)
            if c.pin then
                chip.pin:ClearAllPoints()
                chip.pin:SetPoint("LEFT", chip.text, "RIGHT", 5, 0)
                local s = c.pin
                chip.pin:SetScript("OnClick", function()
                    ns.SafeCall(W.Waypoint, s)
                end)
                chip.pin:SetScript("OnEnter", function(self)
                    W.TextTooltip(self, L.PLACE_WAYPOINT, { { string.format("%s (%d, %d)", m.game:MapName(s.map) or "?",
                        math.floor(s.x * 100 + 0.5), math.floor(s.y * 100 + 0.5)) } })
                end)
                w = w + 19
            end
            if x > 0 and x + w > valueWidth then
                x, rowY = 0, rowY + LINE
            end
            chip:SetWidth(math.min(w, valueWidth))
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", d.body, "TOPLEFT", valueLeft + x, -rowY)
            if c.item then
                local item = c.item
                chip:SetScript("OnEnter", function(self)
                    W.ItemTooltip(self, item)
                end)
            elseif cut then
                local whole = c.text
                chip:SetScript("OnEnter", function(self)
                    W.TextTooltip(self, whole)
                end)
            else
                chip:SetScript("OnEnter", nil)
            end
            x = x + w + CHIP_GAP
        end
        y = rowY + LINE
    end
    d.body:SetSize(width - 18, math.max(1, y))
    d.wanted = PAD + 38 + y + 10
    d:Show()
    return d.wanted
end
