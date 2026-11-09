-- Blizzard's auto-quest popups: "Quête découverte !" and "Cliquer pour terminer la quête". The game keeps the list
-- and Blizzard's hidden quest section adds to it, so this only draws it, above the bars. Full size, centred and
-- scaled with the text up to the panel's width, Ikar's ruling. As AutoQuestPopUpBlockTemplate.
local _, ns = ...
local Shared = ns.Tracker.Shared

local Popups = {}
ns.Popups = Popups

local WIDTH, HEIGHT = 236, 68
local container
local pool = {}
local shown = {} -- questID .. type -> true, for the slide-in on a popup's first showing

local PARTS = "Interface\\QuestFrame\\AutoQuest-Parts"

local function texture(parent, layer, template)
    return parent:CreateTexture(nil, layer, template)
end

local function onMouseUp(self, button)
    if button ~= "LeftButton" or not self:IsMouseOver() or not self.questID then
        return
    end
    -- As a row's click: the quest window doesn't open in a fight, and the popup stays for later.
    if InCombatLockdown() then
        Shared.refuse("combat")
        return
    end
    if self.popUpType == "OFFER" then
        if ShowQuestOffer then
            ShowQuestOffer(self.questID)
        end
    elseif ShowQuestComplete then
        ShowQuestComplete(self.questID)
    end
    if RemoveAutoQuestPopUp then
        RemoveAutoQuestPopUp(self.questID)
    end
    ns.RequestRefresh()
end

local function newPopup()
    local s = Shared
    local p = s.newFrame("Frame", container)
    p:SetSize(WIDTH, HEIGHT)
    p:EnableMouse(true)
    local c = s.newFrame("Frame", p)
    c:SetAllPoints()
    p.Contents = c
    c.Bg = texture(c, "BACKGROUND")
    c.Bg:SetPoint("TOPLEFT", 36, -4)
    c.Bg:SetPoint("BOTTOMRIGHT", 0, 4)
    c.Bg:SetColorTexture(0, 0, 0, 0.5)
    c.TopLeft = texture(c, "BORDER", "AutoQuestToastBorder-TopLeft")
    c.TopLeft:SetPoint("TOPLEFT", 32, 0)
    c.TopRight = texture(c, "BORDER", "AutoQuestToastBorder-TopRight")
    c.TopRight:SetPoint("TOPRIGHT", 0, 0)
    c.BotLeft = texture(c, "BORDER", "AutoQuestToastBorder-BotLeft")
    c.BotLeft:SetPoint("BOTTOMLEFT", 32, 0)
    c.BotRight = texture(c, "BORDER", "AutoQuestToastBorder-BotRight")
    c.BotRight:SetPoint("BOTTOMRIGHT", 0, 0)
    c.Left = texture(c, "BORDER")
    c.Left:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-LeftRight", nil, "REPEAT")
    c.Left:SetTexCoord(0, 0.5, 0, 1)
    c.Left:SetWidth(8)
    c.Left:SetPoint("TOPLEFT", c.TopLeft, "BOTTOMLEFT")
    c.Left:SetPoint("BOTTOMLEFT", c.BotLeft, "TOPLEFT")
    c.Right = texture(c, "BORDER")
    c.Right:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-LeftRight", nil, "REPEAT")
    c.Right:SetTexCoord(0.5, 1, 0, 1)
    c.Right:SetWidth(8)
    c.Right:SetPoint("TOPRIGHT", c.TopRight, "BOTTOMRIGHT")
    c.Right:SetPoint("BOTTOMRIGHT", c.BotRight, "TOPRIGHT")
    c.Top = texture(c, "BORDER")
    c.Top:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-TopBot", "REPEAT")
    c.Top:SetTexCoord(0, 1, 0, 0.5)
    c.Top:SetHeight(8)
    c.Top:SetPoint("TOPLEFT", c.TopLeft, "TOPRIGHT")
    c.Top:SetPoint("TOPRIGHT", c.TopRight, "TOPLEFT")
    c.Bottom = texture(c, "BORDER")
    c.Bottom:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-TopBot", "REPEAT")
    c.Bottom:SetTexCoord(0, 1, 0.5, 1)
    c.Bottom:SetHeight(8)
    c.Bottom:SetPoint("BOTTOMLEFT", c.BotLeft, "BOTTOMRIGHT")
    c.Bottom:SetPoint("BOTTOMRIGHT", c.BotRight, "BOTTOMLEFT")
    c.IconBg = texture(c, "ARTWORK")
    c.IconBg:SetPoint("CENTER", c, "LEFT", 36, 0)
    c.Exclamation = texture(c, "ARTWORK", "QuestIcon-Exclamation")
    c.Exclamation:SetPoint("CENTER", c.IconBg, "CENTER", 0.5, 0)
    c.QuestionMark = texture(c, "ARTWORK", "QuestIcon-QuestionMark")
    c.QuestionMark:SetPoint("CENTER", c.IconBg, "CENTER", 0.5, 0)
    c.Badge = texture(c, "ARTWORK")
    c.Badge:SetAtlas("autoquest-badgeborder", true)
    c.Badge:SetPoint("TOPLEFT", c.IconBg, "TOPLEFT", 8, -8)
    c.QuestName = c:CreateFontString(nil, "BORDER", "QuestFont_Large")
    c.QuestName:SetSize(158, 30)
    c.QuestName:SetPoint("LEFT", c.IconBg, "RIGHT", -6, 0)
    c.QuestName:SetPoint("RIGHT", -12, 0)
    c.QuestName:SetTextColor(1, 1, 1)
    c.TopText = c:CreateFontString(nil, "BORDER", "GameFontNormalSmall")
    c.TopText:SetPoint("LEFT", c.IconBg, "RIGHT", -6, 0)
    c.TopText:SetPoint("RIGHT", -12, 0)
    c.BottomText = c:CreateFontString(nil, "BORDER", "GameFontDisableSmall")
    c.BottomText:SetPoint("BOTTOM", 0, 8)
    c.BottomText:SetPoint("LEFT", c.IconBg, "RIGHT", -6, 0)
    c.BottomText:SetPoint("RIGHT", -12, 0)
    -- The slide-in's shine, and the complete popup's flash until it's clicked.
    c.Shine = texture(c, "BORDER", nil)
    c.Shine:SetColorTexture(1, 1, 1, 1)
    c.Shine:SetBlendMode("ADD")
    c.Shine:SetPoint("TOPLEFT", 35, -3)
    c.Shine:SetPoint("BOTTOMRIGHT", -5, 3)
    c.Shine:SetAlpha(0)
    c.Flash = texture(c, "BORDER", "UIPanelButtonHighlightTexture")
    c.Flash:SetSize(180, 28)
    c.Flash:SetPoint("TOPLEFT", 52, -6)
    c.Flash:SetAlpha(0)

    p.SlideIn = p:CreateAnimationGroup()
    local fade = p.SlideIn:CreateAnimation("Alpha")
    fade:SetTarget(c)
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.4)
    fade:SetOrder(1)
    local shineIn = p.SlideIn:CreateAnimation("Alpha")
    shineIn:SetTarget(c.Shine)
    shineIn:SetFromAlpha(0)
    shineIn:SetToAlpha(0.4)
    shineIn:SetDuration(0.25)
    shineIn:SetOrder(2)
    local shineOut = p.SlideIn:CreateAnimation("Alpha")
    shineOut:SetTarget(c.Shine)
    shineOut:SetFromAlpha(0.4)
    shineOut:SetToAlpha(0)
    shineOut:SetStartDelay(0.05)
    shineOut:SetDuration(0.25)
    shineOut:SetOrder(3)

    p.Pulse = p:CreateAnimationGroup()
    p.Pulse:SetLooping("BOUNCE")
    local pulse = p.Pulse:CreateAnimation("Alpha")
    pulse:SetTarget(c.Flash)
    pulse:SetFromAlpha(0)
    pulse:SetToAlpha(1)
    pulse:SetDuration(0.75)

    p:SetScript("OnMouseUp", s.guarded(onMouseUp))
    p:SetScript("OnEnter", s.guarded(s.wake))
    return p
end

function Popups.Build(fixed)
    container = fixed
end

local function draw(p, questID, popUpType, title)
    local c = p.Contents
    local key = questID .. popUpType
    local changed = p.questID ~= questID or p.popUpType ~= popUpType
    p.questID, p.popUpType = questID, popUpType
    local campaign = C_QuestInfoSystem and Enum and Enum.QuestClassification and C_QuestInfoSystem.GetQuestClassification
        and C_QuestInfoSystem.GetQuestClassification(questID) == Enum.QuestClassification.Campaign
    local complete = popUpType == "COMPLETE"
    c.Badge:SetShown(not campaign)
    c.QuestionMark:SetShown(not campaign and complete)
    c.Exclamation:SetShown(not campaign and not complete)
    if campaign then
        c.IconBg:SetTexCoord(0, 1, 0, 1)
        c.IconBg:SetAtlas("autoquest-badge-campaign", true)
    else
        c.IconBg:SetTexture(PARTS)
        c.IconBg:SetTexCoord(0.30273438, 0.41992188, 0.015625, 0.953125)
        c.IconBg:SetSize(60, 60)
    end
    c.QuestName:SetText(title)
    c.TopText:ClearAllPoints()
    c.TopText:SetPoint("LEFT", c.IconBg, "RIGHT", -6, 0)
    c.TopText:SetPoint("RIGHT", -12, 0)
    c.QuestName:ClearAllPoints()
    c.QuestName:SetPoint("LEFT", c.IconBg, "RIGHT", -6, 0)
    c.QuestName:SetPoint("RIGHT", -12, 0)
    if complete then
        local task = C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(questID)
        c.TopText:SetText(task and ns.G("QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK", "Cliquer pour terminer")
            or ns.G("QUEST_WATCH_POPUP_CLICK_TO_COMPLETE", "Cliquer pour terminer la quête"))
        c.TopText:SetPoint("TOP", 0, -15)
        c.BottomText:Hide()
        local long = c.QuestName:GetStringWidth() > (c.QuestName:GetWidth() or 0)
        c.QuestName:SetPoint("TOP", 0, long and -25 or -29)
    else
        c.TopText:SetText(ns.G("QUEST_WATCH_POPUP_QUEST_DISCOVERED", "Quête découverte !"))
        c.TopText:SetPoint("TOP", 0, -9)
        c.QuestName:SetPoint("TOP", 0, -20)
        c.BottomText:SetText(ns.G("QUEST_WATCH_POPUP_CLICK_TO_VIEW", "Cliquer pour consulter la quête"))
        c.BottomText:Show()
    end
    if changed and not shown[key] then
        shown[key] = true
        p.SlideIn:Stop()
        p.SlideIn:Play()
    end
    if complete then
        if not p.Pulse:IsPlaying() then
            p.Pulse:Play()
        end
    else
        p.Pulse:Stop()
        c.Flash:SetAlpha(0)
    end
end

-- The game's popups, as Blizzard's tracker filters them. Read once per draw, for Arrived and Layout.
function Popups.Read()
    local list = {}
    local splash = SplashFrame and SplashFrame.IsShown and SplashFrame:IsShown()
    for i = 1, (not splash and GetNumAutoQuestPopUps) and GetNumAutoQuestPopUps() or 0 do
        local questID, popUpType = GetAutoQuestPopUp(i)
        local title = questID and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
        local bounty = questID and C_QuestLog.IsQuestBounty and C_QuestLog.IsQuestBounty(questID)
        if title and title ~= "" and not bounty then
            list[#list + 1] = { id = questID, type = popUpType, title = title }
        end
    end
    return list
end

local known -- the popups at the last look, nil before the first

-- True once for each popup in list added since the last look, as Blizzard's tracker expands for one. Those already
-- there at login don't count.
function Popups.Arrived(list)
    local now, arrived = {}, false
    for _, entry in ipairs(list) do
        local key = entry.id .. entry.type
        now[key] = true
        arrived = arrived or (known ~= nil and not known[key])
    end
    known = now
    return arrived
end

-- Draws list's popups from y down, centred in width. Returns the height used, nothing if there are none.
function Popups.Layout(fixed, y, width, textSize, list)
    local used = 0
    local present = {}
    for _, entry in ipairs(list) do
        present[entry.id .. entry.type] = true
    end
    -- A popup that went and comes back slides in again.
    for key in pairs(shown) do
        if not present[key] then
            shown[key] = nil
        end
    end
    if #list > 0 then
        local scale = math.min(textSize / 12, width / WIDTH)
        used = 2
        for i, entry in ipairs(list) do
            local p = pool[i] or newPopup()
            pool[i] = p
            p:SetScale(scale)
            p:ClearAllPoints()
            p:SetPoint("TOP", fixed, "TOP", 0, -(y + used) / scale)
            p:EnableMouse(not Shared.EditMode())
            draw(p, entry.id, entry.type, entry.title)
            p:Show()
            used = used + HEIGHT * scale + (i < #list and 10 or 0)
        end
        used = used + 8
    end
    for i = #list + 1, #pool do
        pool[i]:Hide()
        pool[i].questID = nil
        pool[i].Pulse:Stop()
    end
    return used
end
