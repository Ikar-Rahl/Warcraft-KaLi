-- Dragging, from organiser-design.md, Interaction: quests into the player's groups and among them, the player's
-- groups among themselves, and the category bars inside Journal. Refused in combat and while locked, and cancelled
-- when a fight starts. OnUpdate runs only during a drag.
local _, ns = ...
local Shared = ns.Tracker.Shared

local Drag = {}
ns.Drag = Drag

local spans = { bars = {}, groups = {}, rows = {} }
local d -- the drag in progress
local driver, ghost, line
local marks = {} -- by group ID, and "mine" for the Suivi bar: lit as targets while a quest is dragged
local justDragged = false

-- What the last layout drew, in the list's own coordinates: y grows downward from its top. A drag in progress
-- carries on with the new layout.
function Drag.Record(s)
    spans = s
end

local function inside(span, y, pad)
    pad = pad or 0
    return y >= span.top - pad and y <= span.bottom + pad
end

-- Where a drag would land at list height y. Pure, so the smoke test can check it. many: several picked quests, which
-- a drop on one of their own rows gathers there.
function Drag.Target(s, kind, sourceID, y, many)
    if kind == "quest" then
        for _, r in ipairs(s.rows) do
            if r.groupID and inside(r, y, 3) then
                -- Back on its own row: nothing moves.
                if r.id == sourceID and not many then
                    return nil
                end
                return { type = "row", groupID = r.groupID, questID = r.id, after = y > (r.top + r.bottom) / 2, span = r }
            end
        end
        for _, g in ipairs(s.groups) do
            if inside(g, y) then
                return { type = "group", groupID = g.id, span = g }
            end
        end
        for _, b in ipairs(s.bars) do
            if b.id == "mine" and inside(b, y) then
                return { type = "new", span = b }
            end
        end
        return nil
    elseif kind == "group" then
        for _, g in ipairs(s.groups) do
            if g.id ~= sourceID and inside(g, y) then
                return { type = "reorder-group", groupID = g.id, after = y > (g.top + g.bottom) / 2, span = g }
            end
        end
        return nil
    end
    for _, b in ipairs(s.bars) do
        if b.line and not b.line.top and b.id ~= sourceID and inside(b, y) then
            return { type = "reorder-bar", id = b.id, after = y > (b.top + b.bottom) / 2, span = b }
        end
    end
    return nil
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
end

-- Journal's categories as they show, every known one included, so the saved order names them all.
local function categoryOrder()
    local order, seen = {}, {}
    local function add(id)
        if id ~= "mine" and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    for _, id in ipairs(ns.db.categoryOrder or {}) do
        add(id)
    end
    for _, id in ipairs(ns.Categories.ORDER) do
        add(id)
    end
    return order
end

-- Carries out a drop. kind and id are what was dragged: for quests, one ID or the picked ones in order.
function Drag.Drop(kind, id, target)
    local model = ns.model
    if kind == "quest" then
        local ids = type(id) == "table" and id or { id }
        local ok, reason = true, nil
        if target.type == "group" then
            ok, reason = model:MoveQuests(ids, target.groupID)
        elseif target.type == "new" then
            Shared.newGroup(ids)
            return
        elseif target.type == "row" then
            local g = model:GroupByID(target.groupID)
            if not g then
                return
            end
            -- Counted without the moving quests, so dropped on one of their own rows they gather there.
            local moving = {}
            for _, q in ipairs(ids) do
                moving[q] = true
            end
            local before = 0
            for _, q in ipairs(g.quests) do
                if q == target.questID then
                    break
                end
                if not moving[q] then
                    before = before + 1
                end
            end
            local after = target.after and not moving[target.questID]
            ok, reason = model:MoveQuests(ids, target.groupID, before + 1 + (after and 1 or 0))
        end
        if not ok then
            Shared.refuse(reason)
        end
    elseif kind == "group" then
        local others = {}
        for _, g in ipairs(ns.db.groups) do
            if g.id ~= id then
                others[#others + 1] = g.id
            end
        end
        local at = (indexOf(others, target.groupID) or #others) + (target.after and 1 or 0)
        local ok, reason = model:ReorderGroup(id, at)
        if not ok then
            Shared.refuse(reason)
        end
    else
        local order = categoryOrder()
        table.remove(order, indexOf(order, id))
        table.insert(order, (indexOf(order, target.id) or #order) + (target.after and 1 or 0), id)
        ns.db.categoryOrder = order
    end
    ns.RequestRefresh()
end

-- Visuals ---------------------------------------------------------------------------------------------------

local function content()
    return Shared.frames.content
end

local function ensure()
    if driver then
        return
    end
    driver = CreateFrame("Frame", nil, nil)
    driver:Hide()
    driver:SetScript("OnUpdate", Shared.guarded(function()
        Drag.Update()
    end))
    ghost = CreateFrame("Frame", nil, nil)
    ghost:SetParent(UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:Hide()
    ghost.Bg = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.Bg:SetColorTexture(0, 0, 0, 0.7)
    ghost.Text = ghost:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    ghost.Text:SetJustifyH("LEFT")
    ghost.Text:SetJustifyV("TOP")
    -- How many picked quests a drag carries, beside the copy's top right corner.
    ghost.CountBg = ghost:CreateTexture(nil, "BORDER")
    ghost.CountBg:SetColorTexture(0, 0, 0, 0.85)
    ghost.CountBg:SetSize(18, 16)
    ghost.CountBg:SetPoint("TOPLEFT", ghost, "TOPRIGHT", 6, 3)
    ghost.Count = ghost:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    ghost.Count:SetPoint("CENTER", ghost.CountBg, "CENTER", 0, 0)
    ghost.Count:SetTextColor(1, 0.824, 0)
    line = Shared.newFrame("Frame", content(), "ScrollBoxDragLineTemplate")
    line:SetHeight(2)
    line:Hide()
end

local function mark(key, span, strong)
    local m = marks[key]
    if not m then
        m = content():CreateTexture(nil, "BACKGROUND", nil, -1)
        marks[key] = m
    end
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", content(), "TOPLEFT", Shared.SIDE - 3, -(span.top - 2))
    m:SetPoint("BOTTOMRIGHT", content(), "TOPLEFT", Shared.SIDE + Shared.Width() + 3, -(span.bottom + 4))
    m:SetColorTexture(1, 0.824, 0, strong and 0.15 or 0.05)
    m:Show()
end

local function clearMarks()
    for _, m in pairs(marks) do
        m:Hide()
    end
end

-- Every player's group and the Suivi bar light up while a quest is dragged, the one under the cursor more.
local function drawMarks(target)
    clearMarks()
    if d.kind ~= "quest" then
        return
    end
    local over = target and target.groupID
    for _, g in ipairs(spans.groups) do
        mark(g.id, g, over == g.id)
    end
    for _, b in ipairs(spans.bars) do
        if b.id == "mine" then
            mark("mine", b, target ~= nil and target.type == "new")
        end
    end
end

-- The pointer in the list's own coordinates, then on screen.
local function cursor()
    local x, y = GetCursorPosition()
    local c = content()
    local scale = c:GetEffectiveScale()
    local top, left = c:GetTop(), c:GetLeft()
    if not (top and left) then
        return nil, nil, x, y
    end
    return x / scale - left, top - y / scale, x, y
end

-- Only the part of the list on screen takes a drop: not beside it, nor rows scrolled away under the title.
local function onList(listX, listY)
    local f = Shared.frames
    local from = f.scroll:GetVerticalScroll() or 0
    return listX ~= nil and listX >= 0 and listX <= f.content:GetWidth() and listY >= from and listY <= from + f.scroll:GetHeight()
end

local function follow()
    local listX, listY, screenX, screenY = cursor()
    local gs = ghost:GetEffectiveScale()
    ghost:ClearAllPoints()
    ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenX / gs - d.grabX, screenY / gs + d.grabY)
    local target = onList(listX, listY) and Drag.Target(spans, d.kind, d.id, listY, d.ids ~= nil and #d.ids > 1) or nil
    d.target = target
    drawMarks(target)
    if target and target.type ~= "group" and target.type ~= "new" then
        local span = target.span
        local y = target.after and span.bottom + 3 or span.top - 3
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", content(), "TOPLEFT", Shared.SIDE, -y + 1)
        line:SetWidth(Shared.Width())
        -- Above the rows, which share the list's level.
        line:SetFrameLevel((content():GetFrameLevel() or 1) + 10)
        line:Show()
    else
        line:Hide()
    end
end

function Drag.Update()
    if not d then
        return
    end
    -- Released without a drag stop, as when the dragged row was hidden meanwhile.
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        Drag.Stop()
        return
    end
    follow()
end

local function dim(alpha)
    for _, f in ipairs(d.dimmed) do
        f:SetAlpha(alpha)
    end
end

function Drag.Start(frame, kind)
    local l = frame.line
    if d or not l or Shared.EditMode() then
        return
    end
    local id
    if kind == "quest" then
        -- A row fading out of the log has nowhere to go.
        id = l.quest and not l.quest.leaving and l.quest.id
    elseif kind == "group" then
        id = l.group and l.group.id
    elseif not l.top then
        id = l.id
    end
    if not id then
        return
    end
    if InCombatLockdown() then
        Shared.refuse("combat")
        return
    end
    if Shared.refusedByLock() then
        return
    end
    ensure()
    local ids
    if kind == "quest" then
        -- A picked row carries every picked quest with it. Any other row goes alone.
        local picked = ns.Rows.IsPicked(id) and ns.Rows.Picked() or {}
        ids = #picked > 1 and picked or { id }
    end
    d = { kind = kind, id = id, ids = ids, source = frame, dimmed = { frame } }
    if kind == "group" then
        for _, r in ipairs(spans.rows) do
            if r.groupID == id then
                d.dimmed[#d.dimmed + 1] = r.frame
            end
        end
    elseif ids and #ids > 1 then
        local moving = {}
        for _, q in ipairs(ids) do
            moving[q] = true
        end
        for _, r in ipairs(spans.rows) do
            if moving[r.id] and r.frame ~= frame then
                d.dimmed[#d.dimmed + 1] = r.frame
            end
        end
    end
    dim(0.4)
    -- A quest's box follows the cursor, held where it was grabbed. A group or bar shows its name.
    local _, _, screenX, screenY = cursor()
    ghost:SetScale(frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local gs = ghost:GetEffectiveScale()
    if kind == "quest" then
        local texts = { frame.Title:GetText() or "" }
        for i = 1, frame.shownLines or 0 do
            texts[#texts + 1] = "  " .. (frame.lines[i].Text:GetText() or "")
        end
        ghost.Text:SetText(table.concat(texts, "\n"))
        ghost.Text:SetTextColor(1, 1, 1)
        ghost.Text:ClearAllPoints()
        ghost.Text:SetPoint("TOPLEFT", 0, 0)
        ghost.Text:SetWidth(frame:GetWidth())
        ghost:SetSize(frame:GetWidth(), frame:GetHeight())
        ghost.Bg:ClearAllPoints()
        ghost.Bg:SetPoint("TOPLEFT", -(frame.gutter or 0), 3)
        ghost.Bg:SetPoint("BOTTOMRIGHT", 2, -3)
        ghost.Bg:Show()
        ghost.Count:SetText(#ids > 1 and tostring(#ids) or "")
        ghost.CountBg:SetShown(#ids > 1)
        local left, top = frame:GetLeft(), frame:GetTop()
        d.grabX = left and screenX / gs - left or 0
        d.grabY = top and top - screenY / gs or 0
    else
        ghost.Text:SetText(kind == "group" and l.name or ns.CategoryName(l.id))
        ghost.Text:SetTextColor(1, 0.824, 0)
        ghost.Text:ClearAllPoints()
        ghost.Text:SetPoint("TOPLEFT", 0, 0)
        ghost.Text:SetWidth(0)
        ghost:SetSize(ghost.Text:GetStringWidth() + 2, 14)
        ghost.Bg:Hide()
        ghost.Count:SetText("")
        ghost.CountBg:Hide()
        d.grabX, d.grabY = -12, -4
    end
    ghost:Show()
    Shared.hideTip(frame)
    driver:Show()
    follow()
end

-- Ends the drag without dropping.
function Drag.Cancel()
    if not d then
        return
    end
    dim(1)
    d = nil
    driver:Hide()
    ghost:Hide()
    line:Hide()
    clearMarks()
end

function Drag.Stop()
    if not d then
        return
    end
    follow()
    local kind, id, target = d.kind, d.ids or d.id, d.target
    Drag.Cancel()
    justDragged = true
    C_Timer.After(0, function()
        justDragged = false
    end)
    if InCombatLockdown() then
        Shared.refuse("combat")
        return
    end
    if target then
        Drag.Drop(kind, id, target)
    end
end

-- The click a drag ends with isn't a click on the row.
function Drag.JustDragged()
    return justDragged
end

function Drag.Active()
    return d
end

function Drag.Register(frame, kind)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", Shared.guarded(function(self)
        Drag.Start(self, kind)
    end))
    frame:SetScript("OnDragStop", Shared.guarded(function()
        Drag.Stop()
    end))
end
