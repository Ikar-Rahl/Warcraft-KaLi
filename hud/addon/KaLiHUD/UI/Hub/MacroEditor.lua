-- The macro editor (Ikar 2026-11-16: "will have custom macros, with edit, copy, paste capabilities"): a macro's name,
-- its icon (the library's, UI/Hub/IconPicker.lua) and what it runs, its own commands, typed as in the game's macro
-- window (255 letters, the count under them), or one of the game's macros, picked among the account's and this
-- character's, its commands shown as they are (the game's macro window edits them). A note's, its text written here
-- (1000 letters) and read in its tooltip, with no « Exécute » (Ikar 2026-11-17: "Remove the execute from note"): a
-- note runs nothing, nor becomes a macro, nor a macro a note. Under them, but for a note, its right-click's own commands
-- (255 letters, the count under them, run while the padlock is shut: Ikar 2026-11-18, "Add the character left for the
-- secondary button click"), a short line describing each button, by its icon, said in its tooltip ("Add Description to
-- the macro right and left button, on top of infobulle. Single line enty, short"), and a tooltip of its own (1000),
-- shown in place of its commands (Ikar 2026-11-17: "Add the right click, and the tooltip"). Text copies and pastes in its boxes
-- as in any of the game's (Ctrl+C, Ctrl+V); a whole macro is copied and pasted from its menu (UI/Hub/Macros.lua). Plain
-- as the icon picker; next to the macro's button, as a folder's list opens (Ikar 2026-11-17: "I want the menu to open
-- as a folder popup, near the button"). « Sauver » keeps what was typed, greyed during a fight, when the game lets no
-- addon change a secure button; « Annuler » drops it; Escape or its X shut it and, something changed, ask whether to
-- keep it (below). It opens in combat too, to read or prepare.
-- Laid out a section for each button (Ikar 2026-11-20, of the sketch: "Macro parfaite, implémente"): its icon at its
-- head with the count of its letters, its short description (a grey line in it while empty, saying it goes in the
-- tooltip), its commands; the right-click's head with a help icon saying when they run; then the tooltip, a grey line
-- in it while empty saying its commands stand in for it.
local _, ns = ...

local Editor = {}
ns.MacroEditor = Editor

local L = ns.L

local NAME = "KaLiHUDMacroEditor"
-- Its width; inside its edge; the icon's cell; between a label and its box, and between rows; the commands' box; the
-- right-click's and the tooltip's; a button's description's line, and its icon.
local W, PAD, ICON, GAP, TEXT_H, MORE_H, DESC_H = 400, 12, 36, 6, 104, 52, 20
-- Inside a button's section; its head's row; the right-click's commands' box; the room of a game macro's line, under
-- its commands.
local SPAD, HEAD_H, RIGHT_H, NOTE_H = 8, 20, 64, 28
-- A section's ground and edge, faint: the game's gold.
local SECTION_GROUND, SECTION_EDGE = { 1, 1, 1, 0.03 }, { 0.79, 0.64, 0.35, 0.25 }
local NAME_LETTERS = 40
local HOVER = { 1, 1, 1, 0.12 }
local GREY = { 0.6, 0.6, 0.6 }

local frame
-- The macro open, and its fields as edited, unsaved.
local id, draft

local function label(text, template)
    local fs = frame:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    local c = ns.IconPicker.LABEL
    fs:SetTextColor(c[1], c[2], c[3])
    return fs
end

-- The icon it will wear: the one picked, else the game's macro's, else the text glyph (a note's book).
local function defaultIcon()
    return draft.note and ns.Macros.NOTE_ICON or not draft.macro and ns.Macros.ICON or nil
end

local function showIcon()
    local art = frame.IconButton.Art
    local atlas = draft.icon or defaultIcon()
    art:SetVertexColor(1, 1, 1)
    if atlas then
        local _, missing = ns.HubButtons.FitIcon(art, atlas, ICON - 8)
        if ns.Hub.IsGlyph(atlas) and not missing then
            art:SetVertexColor(unpack(ns.Folders.TINT))
        end
    else
        local _, icon = ns.Macros.Game(draft.macro)
        art:SetTexture(icon or QUESTION_MARK_ICON or 134400)
        art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        art:SetSize(ICON - 8, ICON - 8)
    end
end

local function count()
    local n = frame.Text:GetNumLetters() or 0
    if draft and draft.note then
        frame.Count:SetText(string.format(L.NOTE_COUNT, n, ns.Macros.NOTE_LETTERS))
    else
        frame.Count:SetText(string.format(L.MACRO_COUNT, n, ns.Macros.LETTERS))
    end
end

-- The right-click's letters, as its commands' (the game's 255 too), at its section's head.
local function rightCount()
    frame.RightCount:SetText(string.format(L.MACRO_COUNT, frame.Right:GetNumLetters() or 0, ns.Macros.LETTERS))
end

-- `region` from `x` and `top` down, to the right edge less `right` when given.
local function put(region, x, top, right)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", x, -top)
    if right then
        region:SetPoint("RIGHT", frame, "RIGHT", -right, 0)
    end
end

-- A count at a section's head, on its right.
local function putRight(region, top)
    region:ClearAllPoints()
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + SPAD), -top)
end

-- A box for many lines, `w` wide and `h` tall, from `x` and `top` down: its scroll, its edit box as wide.
local function putBox(edit, x, top, w, h)
    edit.scroll:SetSize(w, h)
    edit:SetWidth(w - 18)
    put(edit.scroll, x, top)
end

-- Where each part stands, as what's open is: a macro's « Exécute », a section for each button, then its tooltip; the
-- left's commands a game macro's as they are, the line saying where they're edited under them. A note's text where
-- « Exécute » stands for a macro, its count under it. Its buttons under what shows.
local function layout()
    local more = not draft.note
    frame.RunsLabel:SetShown(more)
    frame.Runs:SetShown(more)
    for _, r in ipairs({ frame.LeftBox, frame.LeftIcon, frame.LeftDesc, frame.RightBox, frame.RightIcon,
        frame.RightLabel, frame.RightHelp, frame.RightCount, frame.Right.scroll, frame.RightDesc, frame.TipLabel,
        frame.Tip.scroll }) do
        r:SetShown(more)
    end
    local top = frame.runsTop
    if not more then
        frame.TextLabel:SetText(L.NOTE_TEXT)
        put(frame.TextLabel, PAD, top)
        top = top + 14 + GAP + 4
        putBox(frame.Text, PAD + 5, top, W - 2 * PAD - 10, TEXT_H)
        top = top + TEXT_H + 4 + GAP
        put(frame.Count, PAD, top)
        put(frame.Note, PAD, top, PAD)
        top = top + 14 + 2 * GAP
    else
        local x, inner = PAD + SPAD, W - 2 * PAD - 2 * SPAD
        -- the left button's: its head, its description, its commands
        local from = top + frame.runsRow
        top = from + SPAD
        put(frame.LeftIcon, x, top)
        frame.TextLabel:SetText(L.MACRO_COMMANDS)
        put(frame.TextLabel, x + DESC_H + GAP, top + 4)
        putRight(frame.Count, top + 4)
        top = top + HEAD_H + GAP
        frame.LeftDesc:SetWidth(inner - 8)
        put(frame.LeftDesc, x + 4, top)
        top = top + DESC_H + GAP
        putBox(frame.Text, x + 5, top, inner - 10, TEXT_H)
        top = top + TEXT_H + 4
        if draft.macro ~= nil then
            put(frame.Note, x, top, x)
            top = top + NOTE_H
        end
        top = top + SPAD
        frame.LeftBox:ClearAllPoints()
        frame.LeftBox:SetPoint("TOPLEFT", PAD, -from)
        frame.LeftBox:SetSize(W - 2 * PAD, top - from)
        -- the right button's, its help by its name
        from = top + GAP
        top = from + SPAD
        put(frame.RightIcon, x, top)
        put(frame.RightLabel, x + DESC_H + GAP, top + 4)
        frame.RightHelp:ClearAllPoints()
        frame.RightHelp:SetPoint("LEFT", frame.RightLabel, "RIGHT", 4, 0)
        putRight(frame.RightCount, top + 4)
        top = top + HEAD_H + GAP
        frame.RightDesc:SetWidth(inner - 8)
        put(frame.RightDesc, x + 4, top)
        top = top + DESC_H + GAP
        putBox(frame.Right, x + 5, top, inner - 10, RIGHT_H)
        top = top + RIGHT_H + 4 + SPAD
        frame.RightBox:ClearAllPoints()
        frame.RightBox:SetPoint("TOPLEFT", PAD, -from)
        frame.RightBox:SetSize(W - 2 * PAD, top - from)
        -- its tooltip
        top = top + 2 * GAP
        put(frame.TipLabel, PAD, top)
        top = top + 14 + GAP + 4
        putBox(frame.Tip, PAD + 5, top, W - 2 * PAD - 10, MORE_H)
        top = top + MORE_H + 4 + 2 * GAP
    end
    frame.Save:ClearAllPoints()
    frame.Save:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -top)
    frame:SetHeight(top + 22 + PAD)
end

-- What it runs shown: its own commands, to type; or the game's macro's, as they are, to read; a note's text, longer.
local function showRuns()
    local own = draft.macro == nil
    local text = draft.text or ""
    if not own then
        local index, _, body = ns.Macros.Game(draft.macro)
        text = index and body or string.format(L.MACRO_GAME_MISSING, draft.macro)
    end
    frame.Text:SetMaxLetters(draft.note and ns.Macros.NOTE_LETTERS or ns.Macros.LETTERS)
    frame.showing = true
    frame.Text:SetText(text)
    frame.showing = false
    frame.Text:SetEnabled(own)
    local c = own and { 1, 1, 1 } or GREY
    frame.Text:SetTextColor(c[1], c[2], c[3])
    frame.Count:SetShown(own)
    frame.Note:SetShown(not own)
    if own then
        count()
    end
    if frame.Runs.GenerateMenu then
        frame.Runs:GenerateMenu()
    end
    showIcon()
    layout()
end

-- « Sauver » usable out of combat only; its tooltip says why it's greyed.
local function updateSave()
    if frame then
        frame.Save:SetEnabled(not InCombatLockdown())
    end
end

-- ---------- What was typed and not saved ----------
-- Ikar 2026-11-19: "User should never loose it settings ... a deliberate decision (confirmation popup, etc)". The
-- editor shut by « Sauver » keeps what was typed and by « Annuler » drops it, each the player's word. Shut by anything
-- else with something changed (Escape, its X, another macro opened in it, a note's second click), it dropped a note
-- of a thousand letters without a word: it asks instead, the game's yes and no. Yes saves it (in a fight, when
-- nothing is saved, the editor opens again on it); the macro opened again before the answer takes it up where it was
-- left, the question then answered by that. No Escape on the question: the key that shut the editor, pressed once
-- more, would be the no.
local unsaved
-- shut by « Sauver » or « Annuler »
local deliberate = false

-- The fields as the boxes hold them.
local function typed()
    local d = { name = frame.Name:GetText(), icon = draft.icon, text = draft.text, macro = draft.macro, note = draft.note }
    if d.macro == nil then
        d.text = frame.Text:GetText()
    end
    d.right, d.tip = frame.Right:GetText(), frame.Tip:GetText()
    d.leftDesc, d.rightDesc = frame.LeftDesc:GetText(), frame.RightDesc:GetText()
    return d
end

-- Whether fields `d` aren't macro `m`'s as saved.
local function differs(d, m)
    local function same(a, b)
        return (a or "") == (b or "")
    end
    return not (d.name == m.name and d.icon == m.icon and d.macro == m.macro and (d.macro ~= nil or same(d.text, m.text))
        and same(d.right, m.right) and same(d.tip, m.tip) and same(d.leftDesc, m.leftDesc)
        and same(d.rightDesc, m.rightDesc))
end

local function saveUnsaved(data)
    if unsaved ~= data then
        return
    end
    unsaved = nil
    if ns.Macros.Get(data.id) and not ns.History.Do("edit", data.id, ns.Macros.Update, data.id, data.draft) then
        ns.CombatRefused()
        Editor.Open(data.id, data.draft)
    end
end

local function askUnsaved(macroId, fields, name)
    unsaved = { id = macroId, draft = fields }
    StaticPopupDialogs.KALIHUD_MACRO_UNSAVED = StaticPopupDialogs.KALIHUD_MACRO_UNSAVED or {
        text = L.MACRO_UNSAVED_ASK,
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        OnAccept = ns.Guarded(function(_, data)
            saveUnsaved(data)
        end),
        OnCancel = ns.Guarded(function(_, data)
            if unsaved == data then
                unsaved = nil
            end
        end),
    }
    StaticPopup_Show("KALIHUD_MACRO_UNSAVED", name, nil, unsaved)
end

local function save()
    if not id or InCombatLockdown() then
        return
    end
    draft = typed()
    if ns.History.Do("edit", id, ns.Macros.Update, id, draft) then
        deliberate = true
        frame:Hide()
    end
end

-- The list of what a macro can run: its own commands, then the game's macros, the account's and this character's,
-- and the one it ran if the game no longer has it. Not a note: a note is no macro's choice.
local function runsMenu(_, root)
    root:CreateRadio(L.MACRO_OWN, function()
        return draft and draft.macro == nil
    end, ns.Guarded(function()
        draft.macro = nil
        showRuns()
    end))
    local account, character, found = {}, {}, false
    for _, g in ipairs(ns.Macros.GameMacros()) do
        local list = g.character and character or account
        list[#list + 1] = g
        found = found or (draft and g.name == draft.macro)
    end
    local function radios(list)
        for _, g in ipairs(list) do
            root:CreateRadio(g.name, function()
                return draft and draft.macro == g.name
            end, ns.Guarded(function()
                -- its own icon unless another is picked after
                draft.macro, draft.icon = g.name, nil
                showRuns()
            end))
        end
    end
    if #account > 0 then
        root:CreateTitle(ns.G("GENERAL_MACROS", "Macros générales"))
        radios(account)
    end
    if #character > 0 then
        -- the game's own title, its "|2" the French elision a font string writes as « de » or « d' »
        root:CreateTitle(string.format(ns.G("CHARACTER_SPECIFIC_MACROS", "%s Specific Macros"), UnitName("player") or ""))
        radios(character)
    end
    if draft and draft.macro and not found then
        local gone = draft.macro
        root:CreateRadio(string.format(L.MACRO_GAME_MISSING, gone), function()
            return draft and draft.macro == gone
        end, ns.Guarded(function()
            draft.macro = gone
            showRuns()
        end))
    end
end

-- The same library as a folder's (Ikar 2026-11-16: "it should use the same [as the] folder"), beside the editor
-- rather than over it; a pick, which shuts it, is the editor's until saved.
local function pickIcon()
    ns.IconPicker.Open(NAME, frame.IconButton, frame.Name:GetText(), draft.icon or defaultIcon(), function(atlas)
        draft.icon = atlas
        showIcon()
    end, frame)
end

-- A button's short description: one line, a grey line in it while empty saying it goes in the tooltip (the game's
-- box with instructions).
local function descBox()
    local edit = CreateFrame("EditBox", nil, frame, "InputBoxInstructionsTemplate")
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(ns.Macros.DESC_LETTERS)
    edit:SetHeight(DESC_H)
    edit.Instructions:SetText(L.MACRO_DESC_HINT)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    return edit
end

-- A box for text over many lines, as the commands' is: its edit box, the scroll on it (placed by layout).
local function box(letters)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
    scroll.CharCount:Hide()
    local edit = scroll.EditBox
    edit:SetMaxLetters(letters)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit.scroll = scroll
    return edit
end

-- A button's section: a faint ground and edge under its head, description and commands (placed by layout); drawn at
-- the editor's level, under its boxes.
local function sectionBox()
    local s = CreateFrame("Frame", nil, frame)
    s:SetFrameLevel(frame:GetFrameLevel())
    local ground = s:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(SECTION_GROUND[1], SECTION_GROUND[2], SECTION_GROUND[3], SECTION_GROUND[4])
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = s:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(SECTION_EDGE[1], SECTION_EDGE[2], SECTION_EDGE[3], SECTION_EDGE[4])
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then
            PixelUtil.SetHeight(edge, 1, 1)
        else
            PixelUtil.SetWidth(edge, 1, 1)
        end
    end
    return s
end

-- A button's icon at its section's head.
local function headIcon(atlas)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas(atlas)
    icon:SetSize(DESC_H, DESC_H)
    return icon
end

local function build()
    frame = CreateFrame("Frame", NAME, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(60)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    tinsert(UISpecialFrames, NAME)
    ns.IconPicker.Plain(frame)
    -- every script of the editor under the handlers' guard (ns.Guarded), but the boxes' own ClearFocus
    local guarded = ns.Guarded
    frame:SetScript("OnHide", guarded(function()
        -- the whole interface hidden (Alt+Z, a cinematic), which the game tells it too: not shut. It forgot its macro
        -- then, and came back with « Sauver » saving nothing (the review of 2026-11-19)
        if frame:IsShown() then
            return
        end
        ns.IconPicker.Close(NAME)
        local m = id and ns.Macros.Get(id)
        if m and draft and not deliberate then
            local fields = typed()
            if differs(fields, m) then
                askUnsaved(id, fields, m.name)
            end
        end
        deliberate = false
        id, draft = nil, nil
        if GameTooltip:IsOwned(frame.Save) then
            GameTooltip:Hide()
        end
    end))
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", guarded(updateSave))
    frame.Title = label("", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", PAD, -PAD)
    frame.Title:SetPoint("RIGHT", frame, "RIGHT", -PAD - 22, 0)
    frame.Title:SetWordWrap(false)
    frame.Close = ns.CloseButton(frame, 1, 1)
    frame.Close:SetSize(22, 22)

    -- the icon, a click opening the library; its name by it
    local top = PAD + 20
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(ICON, ICON)
    b:SetPoint("TOPLEFT", PAD, -top)
    b.Ground = b:CreateTexture(nil, "BACKGROUND")
    b.Ground:SetAllPoints()
    b.Ground:SetColorTexture(1, 1, 1, 0.06)
    b.Art = b:CreateTexture(nil, "ARTWORK")
    b.Art:SetPoint("CENTER")
    local lit = b:CreateTexture(nil, "HIGHLIGHT")
    lit:SetAllPoints()
    lit:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
    b:RegisterForClicks("LeftButtonUp")
    -- the icon library it opens takes its tooltip away (Ikar 2026-11-18: "when opening anything, the tooltip should
    -- disappear")
    b:SetScript("OnClick", guarded(function(self)
        pickIcon()
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end))
    b:SetScript("OnEnter", guarded(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.FOLDER_ICON, 1, 1, 1)
        GameTooltip:Show()
    end))
    b:SetScript("OnLeave", guarded(function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end))
    frame.IconButton = b
    local left = PAD + ICON + 2 * GAP
    frame.NameLabel = label(ns.G("NAME", "Nom"))
    frame.NameLabel:SetPoint("TOPLEFT", left, -top)
    frame.Name = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.Name:SetAutoFocus(false)
    frame.Name:SetMaxLetters(NAME_LETTERS)
    frame.Name:SetSize(W - left - PAD - 4, 20)
    frame.Name:SetPoint("TOPLEFT", frame.NameLabel, "BOTTOMLEFT", 4, -2)
    frame.Name:SetScript("OnEnterPressed", frame.Name.ClearFocus)
    frame.Name:SetScript("OnEscapePressed", frame.Name.ClearFocus)

    -- what it runs
    top = top + ICON + 2 * GAP
    frame.RunsLabel = label(L.MACRO_RUNS)
    frame.RunsLabel:SetPoint("TOPLEFT", PAD, -top - 6)
    frame.Runs = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    frame.Runs:SetWidth(W - left - PAD)
    frame.Runs:SetPoint("TOPLEFT", left, -top)
    frame.Runs:SetupMenu(guarded(runsMenu))

    -- its commands under the left button's head, as the game's macro window asks for them; a note's text in
    -- « Exécute »'s row (layout)
    frame.runsRow = 26 + 2 * GAP
    frame.runsTop = top
    frame.LeftBox = sectionBox()
    frame.LeftIcon = headIcon(ns.MOUSE_ATLAS.left)
    frame.TextLabel = label(L.MACRO_COMMANDS)
    frame.LeftDesc = descBox()
    frame.LeftDesc.icon = frame.LeftIcon
    frame.Text = box(ns.Macros.LETTERS)
    frame.Scroll = frame.Text.scroll
    frame.Text:HookScript("OnTextChanged", guarded(function(_, userInput)
        if not frame.showing and draft and draft.macro == nil then
            if userInput then
                draft.text = frame.Text:GetText()
            end
            count()
        end
    end))
    frame.Count = label("", "GameFontHighlightSmall")
    frame.Count:SetTextColor(GREY[1], GREY[2], GREY[3])
    frame.Note = label(L.MACRO_GAME_READ, "GameFontHighlightSmall")
    frame.Note:SetTextColor(GREY[1], GREY[2], GREY[3])

    -- the right button's own commands, its help saying when they run (the padlock shut); not a note's
    frame.RightBox = sectionBox()
    frame.RightIcon = headIcon(ns.MOUSE_ATLAS.right)
    frame.RightLabel = label(L.MACRO_COMMANDS)
    frame.RightHelp = CreateFrame("Button", nil, frame)
    frame.RightHelp:SetSize(16, 16)
    local help = frame.RightHelp:CreateTexture(nil, "ARTWORK")
    help:SetAllPoints()
    help:SetAtlas("glueannouncementpopup-icon-info")
    frame.RightHelp:SetScript("OnEnter", guarded(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, L.MACRO_COMMANDS)
        GameTooltip_AddNormalLine(GameTooltip, L.MACRO_RIGHT_HELP, true)
        GameTooltip:Show()
    end))
    frame.RightHelp:SetScript("OnLeave", guarded(function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end))
    frame.RightCount = label("", "GameFontHighlightSmall")
    frame.RightCount:SetTextColor(GREY[1], GREY[2], GREY[3])
    frame.RightDesc = descBox()
    frame.RightDesc.icon = frame.RightIcon
    frame.Right = box(ns.Macros.LETTERS)
    frame.Right:HookScript("OnTextChanged", guarded(rightCount))
    -- its tooltip, its commands standing in for it while empty (the grey line in it)
    frame.TipLabel = label(L.MACRO_TIP)
    frame.Tip = box(ns.Macros.NOTE_LETTERS)
    frame.Tip.Instructions:SetText(L.MACRO_TIP_HINT)
    -- Tab, as they stand: the name, the left button's description and commands, the right's, the tooltip; a note's
    -- name and text
    local order = { frame.Name, frame.LeftDesc, frame.Text, frame.RightDesc, frame.Right, frame.Tip }
    for i, edit in ipairs(order) do
        edit:SetScript("OnTabPressed", guarded(function()
            if draft and draft.note then
                (edit == frame.Name and frame.Text or frame.Name):SetFocus()
            else
                order[i % #order + 1]:SetFocus()
            end
        end))
    end

    -- save, cancel: under what shows (layout)
    frame.Save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Save:SetText(ns.G("SAVE", "Sauver"))
    frame.Save:SetSize(110, 22)
    frame.Save:SetMotionScriptsWhileDisabled(true)
    frame.Save:SetScript("OnClick", guarded(save))
    frame.Save:SetScript("OnEnter", guarded(function(self)
        if self:IsEnabled() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip_SetTitle(GameTooltip, ns.G("SAVE", "Sauver"))
        GameTooltip_AddErrorLine(GameTooltip, ns.G("ERR_NOT_IN_COMBAT", "Impossible de faire ceci tout en combattant."), true)
        GameTooltip_AddNormalLine(GameTooltip, L.MACRO_SAVE_HELD, true)
        GameTooltip:Show()
    end))
    frame.Save:SetScript("OnLeave", guarded(function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end))
    frame.Cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Cancel:SetText(ns.G("CANCEL", "Annuler"))
    frame.Cancel:SetSize(110, 22)
    frame.Cancel:SetPoint("RIGHT", frame.Save, "LEFT", -GAP, 0)
    frame.Cancel:SetScript("OnClick", guarded(function()
        deliberate = true
        frame:Hide()
    end))
    frame:SetWidth(W)
end

-- Next to the macro's button, as a folder's list opens from its own (Folders.Place): in a folder's open list, beside
-- that list the way it opens; on the bar, towards the screen's middle. Its button not shown (in a shut list), where the
-- list of the folder it stands in would open; with none shown, mid-screen. Held by its corner by the button, so a
-- note's shorter editor grows or shrinks away from it.
local function place(macroId)
    local Folders = ns.Folders
    -- laid out where it shows: in a list, that list open (a shut one's members keep their last place)
    local function shown(b, host)
        local list = host and Folders.Panel(host)
        return b ~= nil and b:IsVisible() and b.ux ~= nil and (not host or (list ~= nil and list:IsShown()))
    end
    local owner, at, steps = ns.HubButtons.Get(macroId), macroId, 0
    local host = Folders.Host(at)
    while not shown(owner, host) and host and steps < #Folders.List() do
        steps = steps + 1
        at, owner, host = host, ns.HubButtons.Get(host), Folders.Host(host)
    end
    frame:ClearAllPoints()
    if not shown(owner, host) then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        return
    end
    local dir
    if at ~= macroId then
        dir = Folders.Setting(at, "dir")
    elseif host then
        dir = Folders.Setting(host, "dir")
    else
        dir = (owner.uy < UIParent:GetHeight() / 2 and "up" or "down")
            .. (owner.ux > UIParent:GetWidth() / 2 and "left" or "right")
    end
    local ph = frame:GetHeight()
    local x, y = Folders.Place(owner, host, dir, frame:GetWidth(), ph)
    if dir:sub(1, 2) == "up" then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y + ph)
    end
end

-- Macro `macroId` in the editor, its fields as saved, or `fields` (what was typed and not saved, taken up again);
-- another open in it is shut, asked about if it was changed. What was typed in this one and is still asked about is
-- taken up where it was left.
function Editor.Open(macroId, fields)
    local m = ns.Macros.Get(macroId)
    if not m then
        return
    end
    if not frame then
        build()
    end
    frame:Hide()
    if unsaved and unsaved.id == macroId then
        fields = fields or unsaved.draft
        unsaved = nil
        StaticPopup_Hide("KALIHUD_MACRO_UNSAVED")
    end
    local from = fields or m
    id = macroId
    draft = { name = from.name, icon = from.icon, text = from.text or "", macro = from.macro, note = m.note }
    frame.Title:SetText(string.format(m.note and L.NOTE_TITLE or L.MACRO_TITLE, m.name))
    frame.Name:SetText(from.name)
    frame.Right:SetText(from.right or "")
    frame.Tip:SetText(from.tip or "")
    frame.LeftDesc:SetText(from.leftDesc or "")
    frame.RightDesc:SetText(from.rightDesc or "")
    rightCount()
    showRuns()
    updateSave()
    place(macroId)
    frame:Show()
    frame:Raise()
end

-- Shut; given a macro, only if it's the one open.
function Editor.Close(macroId)
    if frame and frame:IsShown() and (macroId == nil or macroId == id) then
        frame:Hide()
    end
end

-- The one open, for the tests.
function Editor.Current()
    return frame and frame:IsShown() and id or nil
end

function Editor.Frame()
    return frame
end
