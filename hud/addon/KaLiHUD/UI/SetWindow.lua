-- The sets of settings, for the player (Core/Sets.lua keeps and applies them): the one picked on the options'
-- « Préréglages » page, in its dropdown, what its buttons do to it, and the window it is applied from. Ikar
-- 2026-11-19, of a sketch that had « appliquer » on every row: "appliquer shown when ? Ideally I will have a checkbox
-- for each state, on by default"; so « Appliquer… » opens the set in its window, a box for each part of it, all
-- ticked, what is unticked staying as the player has it, then « Appliquer ». Then, of the list a button opened and
-- the window that held the rest: "vos prereglage can't be a drop down with button in it own section ? Grayed when
-- innactive": the sets, another character's own settings and the settings as they were before a set was applied in
-- a dropdown on the page, its buttons under it (apply, bring up to date, rename, share, delete), each greyed while
-- the one picked doesn't allow it.
-- Shared, a set is a text to copy (Sets.Export), shown selected in the family's text window; a text pasted in the
-- import's window becomes one more set, which then opens: nothing changes until it is applied.
local _, ns = ...
local L = ns.L
local Sets = ns.Sets

local Window = {}
ns.SetWindow = Window

local NAME = "KaLiHUDSetWindow"
local WIDTH, PAD, GAP, BOX, BUTTON_HEIGHT = 360, 18, 8, 26, 22
local NAME_LETTERS = 32
local GOLD, WARN = { 1, 0.82, 0 }, { 1, 0.5, 0.25 }

local frame
-- What it shows: { label, settings, set (one kept, else nil), backup (the settings as they were) }
local shown
-- What the options page's dropdown has picked (« The one picked », below)
local picked

-- The options page drawn again, its dropdown and its buttons as they now are.
local function changed()
    ns.SafeCall(ns.Options.Changed)
end

-- ---------- What a set holds ----------

-- How many elements have a place in it, and its folders, macros and notes.
function Window.Holds(settings)
    local elements, folders, macros, notes = 0, 0, 0, 0
    for _ in pairs(settings.items or {}) do
        elements = elements + 1
    end
    for _ in pairs(settings.folders or {}) do
        folders = folders + 1
    end
    for _, m in pairs(settings.macros or {}) do
        if type(m) == "table" and m.note then
            notes = notes + 1
        else
            macros = macros + 1
        end
    end
    return elements, folders, macros, notes
end

-- The game's macros it names that this character hasn't, by name.
function Window.Missing(settings)
    local names = {}
    for _, m in pairs(settings.macros or {}) do
        if type(m) == "table" and not m.note and type(m.macro) == "string" and not ns.Macros.Game(m.macro) then
            names[#names + 1] = m.macro
        end
    end
    table.sort(names)
    return names
end

-- ---------- Asking ----------

local function editBoxOf(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

-- A set's name asked, `current` filled in; done(name) once one is given.
function Window.AskName(current, done)
    StaticPopupDialogs.KALIHUD_SET_NAME = StaticPopupDialogs.KALIHUD_SET_NAME or {
        text = L.SET_NAME_ASK,
        button1 = ns.G("ACCEPT", "Accepter"),
        button2 = ns.G("CANCEL", "Annuler"),
        hasEditBox = 1,
        maxLetters = NAME_LETTERS,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = ns.Guarded(function(dialog, data)
            local box = editBoxOf(dialog)
            if box then
                box:SetText(data and data.name or "")
                box:HighlightText()
            end
        end),
        OnAccept = ns.Guarded(function(dialog, data)
            local box = editBoxOf(dialog)
            data.done(box and box:GetText())
        end),
        EditBoxOnEnterPressed = ns.Guarded(function(box, data)
            data.done(box:GetText())
            box:GetParent():Hide()
        end),
        EditBoxOnEscapePressed = ns.Guarded(function(box)
            box:GetParent():Hide()
        end),
    }
    StaticPopup_Show("KALIHUD_SET_NAME", nil, nil, { name = current, done = function(text)
        if type(text) == "string" and not text:match("^%s*$") then
            ns.SafeCall(done, (text:gsub("^%s+", ""):gsub("%s+$", "")))
        end
    end })
end

-- A yes or no: `text` with `name` in it; done() on yes.
local function confirm(text, name, done)
    StaticPopupDialogs.KALIHUD_SET_CONFIRM = StaticPopupDialogs.KALIHUD_SET_CONFIRM or {
        text = "%s",
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = ns.Guarded(function(_, data)
            data()
        end),
    }
    StaticPopup_Show("KALIHUD_SET_CONFIRM", string.format(text, name), nil, function()
        ns.SafeCall(done)
    end)
end

-- The settings as they are kept under a name the player gives; no room left for one more: said.
function Window.AskSave()
    local kept = 0
    for _, p in ipairs(Sets.List()) do
        kept = kept + (p.backup and 0 or 1)
    end
    if kept >= Sets.MOST then
        ns.Say(string.format(L.SET_FULL, Sets.MOST))
        return
    end
    Window.AskName("", function(name)
        picked = Sets.Save(name) or picked
        changed()
    end)
end

-- ---------- The window ----------

local function text(font, color)
    local t = frame:CreateFontString(nil, "OVERLAY", font)
    t:SetJustifyH("LEFT")
    t:SetWidth(WIDTH - 2 * PAD)
    t:SetWordWrap(true)
    if color then
        t:SetTextColor(color[1], color[2], color[3])
    end
    return t
end

local function button(label, width, click)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(width, BUTTON_HEIGHT)
    b:SetText(label)
    b:SetScript("OnClick", ns.Guarded(click))
    return b
end

local function close()
    frame:Hide()
end

-- The parts ticked.
local function ticked()
    local parts = {}
    for _, part in ipairs(Sets.PARTS) do
        if frame.Boxes[part]:GetChecked() then
            parts[#parts + 1] = part
        end
    end
    return parts
end

local function apply()
    local parts = ticked()
    if #parts > 0 and Sets.Apply(shown.settings, parts, string.format(L.SET_BEFORE, shown.label)) then
        close()
        ns.SafeCall(ns.Options.Changed)
    end
end

-- What is done to a set kept, each asked first but the rename, the page drawn again after.
local function update(set)
    confirm(L.SET_UPDATE_ASK, set.name, function()
        Sets.Update(set)
        changed()
    end)
end
local function rename(set)
    Window.AskName(set.name, function(name)
        Sets.Rename(set, name)
        changed()
    end)
end
local function delete(set)
    confirm(L.SET_DELETE_ASK, set.name, function()
        Sets.Delete(set)
        if shown and shown.set == set then
            close()
        end
        changed()
    end)
end

local function build()
    frame = CreateFrame("Frame", NAME, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(70)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetWidth(WIDTH)
    frame:SetPoint("CENTER")
    frame:Hide()
    tinsert(UISpecialFrames, NAME)
    ns.IconPicker.Plain(frame)
    frame:SetScript("OnHide", ns.Guarded(function()
        shown = nil
    end))
    -- shut by a fight: nothing of it can be done in one
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", ns.Guarded(close))
    frame.Title = text("GameFontNormalLarge", GOLD)
    frame.Saved = text("GameFontDisableSmall")
    frame.Take = text("GameFontNormalSmall", GOLD)
    frame.Take:SetText(L.SET_TAKE)
    frame.Boxes, frame.Labels = {}, {}
    for _, part in ipairs(Sets.PARTS) do
        local b = CreateFrame("CheckButton", nil, frame)
        b:SetSize(BOX, BOX)
        b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b:SetScript("OnClick", ns.Guarded(function(self)
            PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            frame.Apply:SetEnabled(#ticked() > 0)
        end))
        frame.Boxes[part] = b
        local label = text("GameFontHighlight")
        label:SetWidth(WIDTH - 2 * PAD - BOX - 4)
        frame.Labels[part] = label
    end
    frame.Hint = text("GameFontDisableSmall")
    frame.Hint:SetText(L.SET_TAKE_HINT)
    frame.Missing = text("GameFontNormalSmall", GOLD)
    frame.Warn = text("GameFontNormalSmall", WARN)
    frame.Warn:SetText(L.SET_IMPORTED_MACROS)
    frame.Kept = text("GameFontDisableSmall")
    frame.Kept:SetText(L.SET_KEPT_NOTE)
    local half = (WIDTH - 2 * PAD - GAP) / 2
    frame.Close = button(ns.G("CLOSE", "Fermer"), half, close)
    frame.Apply = button(L.SET_APPLY, half, apply)
end

-- What a part's box says: its name, and for the look and the info bar what the set holds of it.
local function partLabel(part, settings)
    local label = L["SET_PART_" .. part]
    local detail
    if part == "look" then
        local style = settings.options and settings.options.preset or ns.PRESETS[1].id
        detail = L["PRESET_" .. tostring(style)]
    elseif part == "bar" then
        detail = string.format(L.SET_HOLDS, Window.Holds(settings))
    end
    return detail and (label .. " |cff999999" .. detail .. "|r") or label
end

-- The window on `what`: { label, settings, set, backup }.
function Window.Open(what)
    if ns.CombatRefused() then
        return false
    end
    if not frame then
        build()
    end
    shown = what
    local y = -PAD
    local function place(region, gap, x)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (x or 0), y)
        region:Show()
        y = y - math.max(region.GetStringHeight and region:GetStringHeight() or region:GetHeight() or 0, 10) - (gap or GAP)
    end
    frame.Title:SetText(what.label)
    place(frame.Title, 4)
    local set = what.set
    if set and set.at then
        frame.Saved:SetText(string.format(L.SET_SAVED, date("%d/%m/%Y", set.at), tostring(set.by or "?"):match("%-(.+)$")
            or tostring(set.by or "?")))
        place(frame.Saved)
    else
        frame.Saved:Hide()
        y = y - GAP
    end
    place(frame.Take, 4)
    for _, part in ipairs(Sets.PARTS) do
        local box, label = frame.Boxes[part], frame.Labels[part]
        box:SetChecked(true)
        label:SetText(partLabel(part, what.settings))
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 4, y)
        box:Show()
        label:ClearAllPoints()
        label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        label:Show()
        y = y - math.max(BOX, label:GetStringHeight() or 0) - 2
    end
    y = y - 4
    place(frame.Hint)
    local missing = Window.Missing(what.settings)
    if #missing > 0 then
        frame.Missing:SetText(string.format(L.SET_MISSING_MACROS, table.concat(missing, ", ")))
        place(frame.Missing)
    else
        frame.Missing:Hide()
    end
    -- a set from a text, which someone else wrote: a macro's commands run on a click, whatever they are, and the
    -- window says so before its info bar is taken (the review of 2026-11-19)
    local _, _, macros = Window.Holds(what.settings)
    if set and set.imported and macros > 0 then
        place(frame.Warn)
    else
        frame.Warn:Hide()
    end
    place(frame.Kept, GAP + 4)
    frame.Close:ClearAllPoints()
    frame.Close:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    frame.Apply:ClearAllPoints()
    frame.Apply:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
    frame.Apply:SetEnabled(true)
    y = y - BUTTON_HEIGHT
    frame:SetHeight(-y + PAD)
    frame:Show()
    frame:Raise()
    return true
end

function Window.Shown()
    return frame ~= nil and frame:IsShown() and shown or nil
end

-- ---------- A text taken or given ----------
-- (Ikar 2026-11-19, of the export: "it is quite convoluted to export": the settings had to be kept as a set, the set
-- found in the list and opened, its « Partager » clicked, and the text copied out of the family's debug window, which
-- said nothing of copying.) One window both ways, as Edit Mode's own for a layout. To import, a box to paste a set's
-- text in; what is wrong with a text is said under it, the window staying; a text that reads is kept as a set under a
-- name asked for, and opens. To share, the set's text in that box, selected, kept whole and selected whatever is
-- typed or clicked in it, what to do said over it; Ctrl+C (Cmd+C) shuts it once copied, a line saying so. The
-- settings as they are are shared from the presets' page in one click (Window.ShareCurrent), or /kh export.

local IMPORT = "KaLiHUDSetImport"
local taker

local function take()
    if taker.shared then
        return
    end
    local settings, why = Sets.Read(taker.Box:GetText())
    if not settings then
        taker.Wrong:SetText(L["SET_IMPORT_" .. why])
        return
    end
    Window.AskName(L.SET_IMPORTED, function(name)
        local set = Sets.Save(name, settings, true)
        if not set then
            taker.Wrong:SetText(string.format(L.SET_FULL, Sets.MOST))
            return
        end
        taker:Hide()
        picked = set
        changed()
        Window.Open({ label = set.name, settings = set.settings, set = set })
    end)
end

-- Its parts, made once.
local function buildTaker()
    do
        taker = CreateFrame("Frame", IMPORT, UIParent)
        taker:SetFrameStrata("DIALOG")
        taker:SetFrameLevel(70)
        taker:SetToplevel(true)
        taker:SetClampedToScreen(true)
        taker:EnableMouse(true)
        taker:SetSize(WIDTH, 230)
        taker:SetPoint("CENTER")
        taker:Hide()
        tinsert(UISpecialFrames, IMPORT)
        ns.IconPicker.Plain(taker)
        local function line(font, color, top)
            local t = taker:CreateFontString(nil, "OVERLAY", font)
            t:SetJustifyH("LEFT")
            t:SetWidth(WIDTH - 2 * PAD)
            t:SetWordWrap(true)
            t:SetPoint("TOPLEFT", PAD, -top)
            if color then
                t:SetTextColor(color[1], color[2], color[3])
            end
            return t
        end
        taker.Title = line("GameFontNormalLarge", GOLD, PAD)
        taker.Title:SetText(L.SET_IMPORT_TITLE)
        taker.Hint = line("GameFontDisableSmall", nil, PAD + 24)
        taker.Hint:SetText(L.SET_IMPORT_HINT)
        local scroll = CreateFrame("ScrollFrame", nil, taker, "InputScrollFrameTemplate")
        scroll:SetSize(WIDTH - 2 * PAD - 10, 80)
        scroll:SetPoint("TOPLEFT", PAD + 5, -(PAD + 46))
        scroll.CharCount:Hide()
        taker.Box = scroll.EditBox
        taker.Box:SetMaxLetters(0)
        taker.Box:SetWidth(scroll:GetWidth() - 18)
        taker.Box:SetAutoFocus(false)
        -- (Escape: a text shared shuts, one being pasted loses the focus first)
        taker.Box:SetScript("OnEscapePressed", ns.Guarded(function(box)
            if taker.shared then
                taker:Hide()
            else
                box:ClearFocus()
            end
        end))
        -- a text shared: whole and selected, whatever is typed or clicked in it; copied, the window shuts
        local function reselect(box)
            if taker.shared then
                box:HighlightText()
            end
        end
        taker.Box:HookScript("OnTextChanged", ns.Guarded(function(box, user)
            if taker.shared and user and box:GetText() ~= taker.shared then
                box:SetText(taker.shared)
                box:HighlightText()
            end
        end))
        taker.Box:HookScript("OnEditFocusGained", ns.Guarded(reselect))
        taker.Box:HookScript("OnMouseUp", ns.Guarded(reselect))
        taker.Box:HookScript("OnKeyUp", ns.Guarded(function(_, key)
            if taker.shared and key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
                taker:Hide()
                ns.Say(L.SET_COPIED)
            end
        end))
        taker:SetScript("OnHide", ns.Guarded(function()
            taker.shared = nil
        end))
        taker.Wrong = line("GameFontNormalSmall", { 1, 0.3, 0.3 }, PAD + 46 + 80 + 12)
        local half = (WIDTH - 2 * PAD - GAP) / 2
        local function key(label, click, point, x)
            local b = CreateFrame("Button", nil, taker, "UIPanelButtonTemplate")
            b:SetSize(half, BUTTON_HEIGHT)
            b:SetText(label)
            b:SetPoint(point, taker, point, x, PAD)
            b:SetScript("OnClick", ns.Guarded(click))
            return b
        end
        taker.Cancel = key(ns.G("CANCEL", "Annuler"), function()
            taker:Hide()
        end, "BOTTOMLEFT", PAD)
        taker.Take = key(L.SET_IMPORT_GO, take, "BOTTOMRIGHT", -PAD)
    end
end

-- The window in one of its two ways: its title and its words, the text in its box, its buttons.
local function openTaker(title, hint, shared)
    if not taker then
        buildTaker()
    end
    taker:Hide()
    taker.Title:SetText(title)
    taker.Hint:SetText(hint)
    taker.Wrong:SetText("")
    taker.Take:SetShown(not shared)
    -- shared, its one button shuts it, on the right where a dialog's last button stands
    taker.Cancel:SetText(shared and ns.G("CLOSE", "Close") or ns.G("CANCEL", "Annuler"))
    taker.Cancel:ClearAllPoints()
    taker.Cancel:SetPoint(shared and "BOTTOMRIGHT" or "BOTTOMLEFT", taker, shared and "BOTTOMRIGHT" or "BOTTOMLEFT",
        shared and -PAD or PAD, PAD)
    taker:Show()
    taker.shared = shared
    taker.Box:SetText(shared or "")
    taker:Raise()
    taker.Box:SetFocus()
    taker.Box:HighlightText()
end

function Window.AskImport()
    if ns.CombatRefused() then
        return false
    end
    openTaker(L.SET_IMPORT_TITLE, L.SET_IMPORT_HINT, nil)
    return true
end

-- `settings` as a text to copy, under the name `label`: false when it can't be made one, said.
function Window.Share(label, settings)
    local text = Sets.Export(settings)
    if not text then
        ns.Say(L.SET_SHARE_FAILED)
        return false
    end
    openTaker(string.format(L.SET_SHARE_TITLE, label), L.SET_SHARE_HINT, text)
    return true
end

-- The settings as they are, shared without being kept as a set first.
function Window.ShareCurrent()
    return Window.Share(L.SET_CURRENT, Sets.Capture())
end

-- ---------- The one picked ----------
-- The page's dropdown: the sets kept, the other characters' own settings, the settings as they were, each group under
-- its title; a set by itself, another character's by its key ("char:<realm-name>"). Nothing picked at first, and
-- nothing once the one picked has gone.

function Window.Choices()
    local list, backups = {}, {}
    for _, p in ipairs(Sets.List()) do
        if p.backup then
            backups[#backups + 1] = p
        else
            list[#list + 1] = { p, p.name }
        end
    end
    if #list == 0 then
        list[1] = { title = L.SET_NONE }
    end
    local others = Sets.Others()
    if #others > 0 then
        list[#list + 1] = { divider = true }
        list[#list + 1] = { title = L.SET_OTHERS }
        for _, c in ipairs(others) do
            list[#list + 1] = { "char:" .. c.key, string.format(L.SET_OF, c.name) }
        end
    end
    if #backups > 0 then
        list[#list + 1] = { divider = true }
        list[#list + 1] = { title = L.SET_BACKUPS }
        for _, p in ipairs(backups) do
            list[#list + 1] = { p, p.name }
        end
    end
    return list
end

-- What is picked, as the window takes it ({ label, settings, set }), or nil.
function Window.Picked()
    if type(picked) == "table" then
        for _, p in ipairs(Sets.List()) do
            if p == picked then
                return { label = p.name, settings = p.settings, set = p }
            end
        end
    elseif type(picked) == "string" then
        for _, c in ipairs(Sets.Others()) do
            if "char:" .. c.key == picked then
                return { label = string.format(L.SET_OF, c.name), settings = c.settings }
            end
        end
    end
    picked = nil
end
function Window.PickedValue()
    Window.Picked()
    return picked
end
function Window.Pick(value)
    picked = value
end

-- What the one picked allows: any applied and shared; a set kept brought up to date and renamed; a set kept or the
-- settings as they were deleted (another character's are its own).
function Window.Can(what)
    local p = Window.Picked()
    if not p then
        return false
    elseif what == "update" or what == "rename" then
        return p.set ~= nil and not p.set.backup
    elseif what == "delete" then
        return p.set ~= nil
    end
    return true
end
function Window.Do(what)
    local p = Window.Picked()
    if not (p and Window.Can(what)) then
        return
    elseif what == "apply" then
        Window.Open(p)
    elseif what == "share" then
        Window.Share(p.label, p.settings)
    elseif what == "update" then
        update(p.set)
    elseif what == "rename" then
        rename(p.set)
    elseif what == "delete" then
        delete(p.set)
    end
end
