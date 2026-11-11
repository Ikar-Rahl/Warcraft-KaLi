-- Quest item buttons. Using a quest item takes a secure button, and addon code can't show, hide, move or reparent
-- one in combat, nor anything it's anchored to. So the buttons sit on UIParent, placed over their row's slot after
-- each layout and scroll and never anchored to it, and rows stay free to move in combat. There a button stays where
-- it was and dims if its row moved, and a row whose item has no button lined up shows the icon grey, doing
-- nothing, until the fight ends. See organiser-design.md, Combat.
local _, ns = ...
local Shared = ns.Tracker.Shared

local Items = {}
ns.Items = Items

local free, byQuest = {}, {}
local built = false
local MISALIGNED_ALPHA = 0.45
local placedAt -- where the tracker was when the buttons were last placed
local watcher

local function trackerAlpha()
    local root = Shared.frames and Shared.frames.root
    if not (root and root:IsVisible()) then
        return 0
    end
    local parent = UIParent:GetEffectiveAlpha()
    return parent > 0 and math.min(1, root:GetEffectiveAlpha() / parent) or 1
end

-- Read each time: in a fight the buttons aren't set up again, and a quest leaving the log moves the ones below it.
local function logIndexOf(b)
    return b.questID and C_QuestLog.GetLogIndexForQuestID(b.questID)
end

-- The tracker's place and scale on screen, or nil while it has none.
local function trackerPlace()
    local root = Shared.frames and Shared.frames.root
    local left, top = root and root:GetLeft(), root and root:GetTop()
    if left and top then
        return string.format("%.1f %.1f %.3f", left, top, root:GetEffectiveScale())
    end
end

local function updateCooldown(b)
    local index = logIndexOf(b)
    if not index or not GetQuestLogSpecialItemCooldown then
        return
    end
    local start, duration, enable = GetQuestLogSpecialItemCooldown(index)
    if start and CooldownFrame_Set then
        CooldownFrame_Set(b.Cooldown, start, duration, enable)
        local grey = duration > 0 and enable == 0
        b.icon:SetVertexColor(grey and 0.4 or 1, grey and 0.4 or 1, grey and 0.4 or 1)
    end
end

local function setCharges(b, charges)
    b.charges = charges
    b.Count:SetText(charges and charges > 1 and charges or "")
    b.Count:SetShown(charges ~= nil and charges > 1)
end

-- The quest area glow, as Blizzard's: six slow pulses on entering the quest's area.
local function glow(b)
    if not b.GlowAnim:IsPlaying() then
        b.Glow:Show()
        b.loops = 0
        b.GlowAnim:Play()
    end
end

local function onEvent(b, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        b.rangeTimer = -1
    elseif event == "BAG_UPDATE_COOLDOWN" then
        updateCooldown(b)
    elseif event == "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED" then
        local questID, inside = ...
        if questID == b.questID and inside then
            glow(b)
        end
    end
end

-- The range dot, and a change in charges, which redraws the row.
local function onUpdate(b, elapsed)
    if not b.rangeTimer then
        return
    end
    b.rangeTimer = b.rangeTimer - elapsed
    if b.rangeTimer > 0 then
        return
    end
    b.rangeTimer = TOOLTIP_UPDATE_TIME or 0.2
    local index = logIndexOf(b)
    if not index then
        return
    end
    local _, _, charges = GetQuestLogSpecialItemInfo(index)
    if charges ~= b.charges then
        -- Kept here too: in combat the buttons aren't set up again, and every tick would redraw.
        setCharges(b, charges)
        ns.RequestRefresh()
        return
    end
    local valid = IsQuestLogSpecialItemInRange and IsQuestLogSpecialItemInRange(index)
    if valid == 0 then
        b.HotKey:Show()
        b.HotKey:SetVertexColor(1, 0.1, 0.1)
    elseif valid == 1 then
        b.HotKey:Show()
        b.HotKey:SetVertexColor(0.6, 0.6, 0.6)
    else
        b.HotKey:Hide()
    end
end

-- As QuestObjectiveItemButtonTemplate, on a secure button. A shift-click links the item while a chat box is open,
-- and otherwise uses it, as Blizzard's. Attributes can't change in combat, so there a shift-click only links.
local function newButton()
    local s = Shared
    local b = s.newFrame("Button", UIParent, "SecureActionButtonTemplate")
    b:SetSize(26, 26)
    b:RegisterForClicks("AnyUp")
    -- An addon's secure button otherwise acts on the press when "act on key down" is on, the game's default, and
    -- this one only hears the release. See SecureActionButton_OnClick.
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "item")
    b:SetAttribute("shift-type*", "")
    b.Glow = b:CreateTexture(nil, "BACKGROUND")
    b.Glow:SetAtlas("ui-questtrackerbutton-questitem-frame-glow", true)
    b.Glow:SetPoint("CENTER")
    b.Glow:Hide()
    b.GlowAnim = b:CreateAnimationGroup()
    b.GlowAnim:SetLooping("BOUNCE")
    local pulse = b.GlowAnim:CreateAnimation("Alpha")
    pulse:SetTarget(b.Glow)
    pulse:SetFromAlpha(0)
    pulse:SetToAlpha(1)
    pulse:SetDuration(1)
    b.GlowAnim:SetScript("OnLoop", function()
        b.loops = (b.loops or 0) + 1
        if b.loops >= 6 then
            b.GlowAnim:Stop()
            b.Glow:Hide()
        end
    end)
    b.icon = b:CreateTexture(nil, "BORDER")
    b.icon:SetAllPoints()
    b.Count = b:CreateFontString(nil, "BORDER", "NumberFontNormal")
    b.Count:SetJustifyH("RIGHT")
    b.Count:SetPoint("BOTTOMRIGHT", -3, 2)
    b.HotKey = b:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmallGray")
    b.HotKey:SetSize(29, 10)
    b.HotKey:SetJustifyH("LEFT")
    b.HotKey:SetText(RANGE_INDICATOR or "●")
    b.HotKey:SetPoint("TOPRIGHT", 16, -2)
    b.HotKey:Hide()
    b.Cooldown = s.newFrame("Cooldown", b, "CooldownFrameTemplate")
    b.Cooldown:SetAllPoints()
    b:SetNormalAtlas("ui-questtrackerbutton-questitem-frame")
    local normal = b:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetPoint("CENTER")
        normal:SetSize(42, 42)
    end
    b:SetPushedAtlas("ui-questtrackerbutton-questitem-frame")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local guarded = s.guarded
    b:SetScript("PreClick", guarded(function(self)
        if not IsModifiedClick("CHATLINK") then
            return
        end
        local chat = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
        if chat or InCombatLockdown() then
            if self.link and ChatFrameUtil and ChatFrameUtil.InsertLink then
                ChatFrameUtil.InsertLink(self.link)
            end
        else
            self:SetAttribute("shift-type*", "item")
        end
    end))
    b:SetScript("PostClick", guarded(function(self)
        if not InCombatLockdown() then
            self:SetAttribute("shift-type*", "")
        end
    end))
    b:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        local index = logIndexOf(self)
        if index then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetQuestLogSpecialItem(index)
        end
    end))
    b:SetScript("OnLeave", guarded(function(self)
        Shared.hideTip(self)
    end))
    b:SetScript("OnEvent", guarded(onEvent))
    b:SetScript("OnUpdate", guarded(onUpdate))
    b:RegisterEvent("PLAYER_TARGET_CHANGED")
    b:RegisterEvent("BAG_UPDATE_COOLDOWN")
    b:RegisterEvent("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED")
    b:Hide()
    return b
end

function Items.Build()
    if built then
        return
    end
    built = true
    -- Other addons fade the host by name, and the buttons aren't its children, so they follow its alpha here.
    if ObjectiveTrackerFrame then
        hooksecurefunc(ObjectiveTrackerFrame, "SetAlpha", function()
            ns.SafeCall(Items.UpdateAlpha)
        end)
    end
    -- Buttons can't go in a fight, so ones a tracker turned off meanwhile left behind go once it ends.
    ns.On("PLAYER_REGEN_ENABLED", function()
        Items.Sync()
    end)
    -- The tracker can move with no layout, as when the UI scale changes or the right-hand frames shift. While buttons
    -- show, a light check lines them up again.
    watcher = Shared.newFrame("Frame", UIParent)
    watcher:Hide()
    watcher.wait = 0
    watcher:SetScript("OnUpdate", function(self, elapsed)
        self.wait = self.wait - (elapsed or 0)
        if self.wait > 0 then
            return
        end
        self.wait = 0.2
        if trackerPlace() ~= placedAt then
            ns.SafeCall(Items.Sync)
        end
    end)
end

local function notePlace()
    placedAt = trackerPlace()
    watcher:SetShown(next(byQuest) ~= nil)
end

-- The quest's item, if its row shows one, as Blizzard's: QuestShowsItemByIndex, else an item not done with.
function Items.Of(q)
    if not q.logIndex or not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link, icon, charges, showWhenComplete = GetQuestLogSpecialItemInfo(q.logIndex)
    if not icon then
        return nil
    end
    local shows
    if QuestUtil and QuestUtil.QuestShowsItemByIndex then
        shows = QuestUtil.QuestShowsItemByIndex(q.logIndex, q.complete)
    else
        shows = not q.complete or showWhenComplete
    end
    if not shows then
        return nil
    end
    return { id = q.id, link = link, icon = icon, charges = charges, logIndex = q.logIndex }
end

-- During a row's layout: its slot at the right edge, offset right from the row's right. True if it has an item.
-- The slot stays shown, clear: a region the game never showed has no position for the button to take.
function Items.Slot(row, q, right)
    local item = Items.Of(q)
    row.item = item
    local slot = row.ItemSlot
    if not item then
        slot:Hide()
        return false
    end
    slot:SetTexture(item.icon)
    slot:ClearAllPoints()
    slot:SetPoint("TOPRIGHT", row, "TOPRIGHT", right, 0)
    slot:SetAlpha(0)
    slot:Show()
    return true
end

-- Rows whose slot is wholly inside the list's visible part, by quest, and whether a slot had no position yet.
local function wantedSlots()
    local s = Shared
    local frames = s.frames
    local wanted, unplaced = {}, false
    if not (frames and ns.Tracker.IsActive() and frames.root:IsVisible()) or s.EditMode() then
        return wanted, unplaced
    end
    local view = frames.scroll
    local viewTop, viewBottom = view:GetTop(), view:GetBottom()
    if not (viewTop and viewBottom) then
        return wanted, true
    end
    for _, row in pairs(ns.Tracker.QuestRows()) do
        if row:IsShown() and row.item then
            local slot = row.ItemSlot
            local left, top, bottom = slot:GetLeft(), slot:GetTop(), slot:GetBottom()
            if not (left and top and bottom) then
                unplaced = true
            elseif top <= viewTop + 1 and bottom >= viewBottom - 1 then
                wanted[row.item.id] = { row = row, item = row.item, left = left, top = top, scale = slot:GetEffectiveScale() }
            end
        end
    end
    return wanted, unplaced
end

local function configure(b, item)
    b.questID = item.id
    if b.link ~= item.link then
        b.link = item.link
        b:SetAttribute("item", item.link)
    end
    b.icon:SetTexture(item.icon)
    setCharges(b, item.charges)
    b.rangeTimer = -1
    updateCooldown(b)
    if C_Minimap and C_Minimap.IsInsideQuestBlob and C_Minimap.IsInsideQuestBlob(item.id) then
        glow(b)
    end
end

-- Out of combat, buttons follow their slots, appear and go. In combat they stay, and only their alpha and the
-- rows' grey icons follow.
local retried = false
function Items.Sync()
    if not built then
        return
    end
    local wanted, unplaced = wantedSlots()
    -- A slot shown this frame may only get its position at the next layout pass: one more try then, and only one,
    -- so a slot that never gets one doesn't retry each frame. The flag clears even if that try fails.
    if unplaced and not retried then
        retried = true
        ns.Later("items", function()
            ns.SafeCall(Items.Sync)
            retried = false
        end)
    end
    local alpha = trackerAlpha()
    if not InCombatLockdown() then
        for id, b in pairs(byQuest) do
            if not wanted[id] then
                b:Hide()
                b.questID = nil
                byQuest[id] = nil
                free[#free + 1] = b
            end
        end
        local root = Shared.frames.root
        for id, w in pairs(wanted) do
            local b = byQuest[id] or table.remove(free) or newButton()
            byQuest[id] = b
            configure(b, w.item)
            local parentScale = UIParent:GetEffectiveScale()
            b:SetScale(parentScale > 0 and w.scale / parentScale or 1)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", w.left, w.top)
            b.left, b.top = w.left, w.top
            b:SetFrameStrata(root:GetFrameStrata())
            b:SetFrameLevel((root:GetFrameLevel() or 1) + 30)
            b:SetAlpha(alpha)
            b:Show()
            w.row.ItemSlot:SetAlpha(0)
        end
        notePlace()
        return
    end
    for id, b in pairs(byQuest) do
        local w = wanted[id]
        local aligned = w ~= nil and math.abs(w.left - (b.left or 0)) < 1 and math.abs(w.top - (b.top or 0)) < 1
        b:SetAlpha(alpha * (aligned and 1 or MISALIGNED_ALPHA))
        if aligned then
            w.covered = true
        end
    end
    for _, w in pairs(wanted) do
        w.row.ItemSlot:SetAlpha(w.covered and 0 or 1)
    end
    notePlace()
end

function Items.UpdateAlpha()
    if not built then
        return
    end
    if InCombatLockdown() then
        Items.Sync()
        return
    end
    local alpha = trackerAlpha()
    for _, b in pairs(byQuest) do
        b:SetAlpha(alpha)
    end
end

function Items.IsMouseOver()
    for _, b in pairs(byQuest) do
        if b:IsShown() and b:IsMouseOver() then
            return true
        end
    end
    return false
end

-- For the debug panel: each quest in the log with an item, and what became of its button.
function Items.Status()
    local out = {}
    if not (ns.categories and Shared.frames) then
        return out
    end
    local rows = {}
    for _, row in pairs(ns.Tracker.QuestRows()) do
        if row:IsShown() and row.item then
            rows[row.item.id] = row
        end
    end
    local quests, order = ns.QuestLog.Read(ns.categories.Classify)
    for _, id in ipairs(order) do
        if Items.Of(quests[id]) then
            local row, b = rows[id], byQuest[id]
            local state = "outside"
            if b and b:IsShown() then
                state = "shown"
            elseif not row then
                state = "norow"
            elseif not row.ItemSlot:GetTop() then
                state = "unplaced"
            elseif InCombatLockdown() then
                state = "combat"
            end
            out[#out + 1] = { title = quests[id].title, state = state }
        end
    end
    return out
end

-- For /kq status and the offline smoke test.
function Items.Buttons()
    return byQuest
end

-- For the offline smoke test.
function Items.Watcher()
    return watcher
end
