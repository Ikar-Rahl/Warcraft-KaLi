-- A settings window in the look of Blizzard's Edit Mode dialog, built from the pieces that dialog is made of, at its
-- sizes: a title and a close button, the folding sections of the game's Keybindings page (one open at a time, so it
-- stays short), rows of sliders, check boxes, dropdowns and buttons, then the window's own buttons. It's the addon's
-- own frame: nothing is written into Blizzard's. Changes apply at once; « Annuler les modifications » puts back what
-- the last snapshot held. KaLi Quest's dialog in Edit Mode and KaLi Recipe's options window are made with it.
--
-- ns.Dialog.New(spec) gives the window's handle; nothing is built before it first opens. spec:
--   name, title    the frame's global name, and its title
--   sections()     the sections, asked for once the saved data is in: { { id, name, rows }, ... }
--   open           the section open at first
--   options()      the table the values are kept in, unless a row says otherwise
--   defaults       the default values, by key, unless a row gives its own
--   ranges         the sliders' ranges, by key: { min, max }
--   apply(row, value, how)   after a value changed, once the row's own onChange ran
--   buttons        the window's buttons, in order: { key, text, click(handle), tip, wide, enabled(handle) }, or
--                  { key, divider = true }; each is the frame's field of that key
--   onClose()      what the close button does; else it hides the window
--   onKeyDown(frame, key)    takes the keyboard while shown: true when it used the key, which then goes no further.
--                  In a fight every key goes on to the game
--   combatLock     rows and buttons greyed in a fight
--   escape         Escape closes it, as it closes Blizzard's windows
--   snapshotOnOpen what « Annuler les modifications » goes back to is taken each time it opens
--   place(frame)   where it opens
--   extra          the rest of a snapshot, beyond the rows' values: { take(), same(held), put(held) }
--   look           "dialog", Edit Mode's (the default), or "window": a window of the game's, as KaLi Recipe's notebook
--                  in its « Épuré » style (Ikar, 2026-11-13: "similaire a celle des recette ... style minimaliste"): the
--                  title bar and close button of ButtonFrameTemplate, its dark inset under the rows, the notebook's own
--                  section bars (a gold name, a + or a −, a thin gold rule), and the buttons along the bottom
--
-- A row: { kind, key, name, tip, ... }
--   kind "slider": step, format(value), current() (what shows while no value is kept)
--   kind "check"
--   kind "choice": values = { { value, label }, ... }
--   kind "button": text, click(), width; it holds no value
--   any row: tbl() (where its value is kept), default, onChange(value, how), redraw = false (no apply)
--   how is nil for a change made in the window, "revert" or "defaults" for the window's buttons.
local _, ns = ...

local Dialog = {}
ns.Dialog = Dialog

-- Blizzard's sizes: EditModeSettingSliderTemplate's row, label and slider, its dropdown's width, the Keybindings page's
-- section bar, then the dialog's title, gaps and padding, its buttons and the divider between them, and the options
-- page's button in a row.
local ROW_WIDTH, ROW_HEIGHT, LABEL_WIDTH, SLIDER_WIDTH, DROPDOWN_WIDTH, SECTION_HEIGHT = 343, 32, 100, 200, 225, 30
local TITLE_TOP, GAP, SPACING, PADDING = 15, 12, 2, 20
local BUTTON_WIDTH, WIDE_BUTTON_WIDTH, BUTTON_HEIGHT, DIVIDER_HEIGHT = 180, 330, 28, 16
local ROW_BUTTON_WIDTH, ROW_BUTTON_HEIGHT = 120, 22
Dialog.WIDTH = ROW_WIDTH + 2 * PADDING
-- The window look: the template's title bar, the inset 10 in from the frame's sides, the rows 12 in from the inset's,
-- the notebook's section bar, and the template's buttons, 22 high, along the bottom.
local WINDOW_TOP, INSET_SIDE, INSET_PAD, WINDOW_SECTION, WINDOW_BUTTON, WINDOW_FOOT = 26, 10, 12, 24, 22, 32
Dialog.WINDOW_WIDTH = ROW_WIDTH + 2 * (INSET_SIDE + INSET_PAD)

local Handle = {}
Handle.__index = Handle

function Dialog.New(spec)
    return setmetatable({ spec = spec, openSection = spec.open }, Handle)
end

-- Frames start without a parent: SmartNavigationMixin hooks CreateFrame and rebuilds the caller's button groups.
local function newFrame(kind, parent, template, name)
    local f = CreateFrame(kind, name, nil, template)
    if parent then
        f:SetParent(parent)
    end
    return f
end

function Handle:Sections()
    if not self.sections then
        self.sections = self.spec.sections()
    end
    return self.sections
end

-- Every row that holds a value.
function Handle:Rows()
    local rows = {}
    for _, section in ipairs(self:Sections()) do
        for _, row in ipairs(section.rows) do
            if row.kind ~= "button" then
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

function Handle:Table(row)
    return row.tbl and row.tbl() or self.spec.options()
end

function Handle:Default(row)
    if row.default ~= nil then
        return row.default
    end
    return self.spec.defaults and self.spec.defaults[row.key]
end

function Handle:Range(row)
    return row.range or self.spec.ranges[row.key]
end

-- What the row shows: the value kept, or while there's none what's used instead.
function Handle:Value(row)
    local value = self:Table(row)[row.key]
    if row.kind ~= "slider" then
        if value == nil then
            return self:Default(row)
        end
        return value
    end
    if type(value) ~= "number" then
        value = row.current and row.current() or self:Default(row)
    end
    local range = self:Range(row)
    return math.max(range[1], math.min(range[2], value))
end

local function applied(self, row, value, how)
    if row.onChange then
        ns.SafeCall(row.onChange, value, how)
    end
    if row.redraw ~= false and self.spec.apply then
        ns.SafeCall(self.spec.apply, row, value, how)
    end
end

function Handle:Set(row, value)
    if row.kind == "slider" then
        value = math.floor(value + 0.5)
    end
    local t = self:Table(row)
    if t[row.key] ~= value then
        t[row.key] = value
        applied(self, row, value)
        self:UpdateButtons()
    end
end

-- The values as they are, and the rest the addon holds, for « Annuler les modifications ».
function Handle:Snapshot()
    local values = {}
    for _, row in ipairs(self:Rows()) do
        values[row] = { self:Table(row)[row.key] }
    end
    local extra = self.spec.extra
    self.snapshot = { values = values, extra = extra and extra.take() }
    self:Changed()
end

function Handle:HasChanges()
    local snapshot = self.snapshot
    if not snapshot then
        return false
    end
    for row, held in pairs(snapshot.values) do
        if self:Table(row)[row.key] ~= held[1] then
            return true
        end
    end
    local extra = self.spec.extra
    return extra ~= nil and not extra.same(snapshot.extra)
end

function Handle:Revert()
    if not self:HasChanges() then
        return
    end
    for row, held in pairs(self.snapshot.values) do
        local t = self:Table(row)
        if t[row.key] ~= held[1] then
            t[row.key] = held[1]
            applied(self, row, held[1], "revert")
        end
    end
    if self.spec.extra then
        self.spec.extra.put(self.snapshot.extra)
    end
    self:Changed()
end

-- Every row back to its default. Not what the addon holds beyond them, which has its own buttons.
function Handle:Defaults()
    for _, row in ipairs(self:Rows()) do
        local default = self:Default(row)
        local t = self:Table(row)
        if t[row.key] ~= default then
            t[row.key] = default
            applied(self, row, default, "defaults")
        end
    end
    self:Changed()
end

local function tooltip(owner, title, text)
    if not text then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    GameTooltip:AddLine(text, nil, nil, nil, true)
    GameTooltip:Show()
end

local function hideTooltip(owner)
    if GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

local function withTooltip(frame, title, text)
    if text then
        frame:SetScript("OnEnter", function(self)
            tooltip(self, title, text)
        end)
        frame:SetScript("OnLeave", hideTooltip)
    end
end

-- A label of Blizzard's: 100 wide, two lines at most.
local function label(f, text)
    f.Label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    f.Label:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    f.Label:SetPoint("LEFT")
    f.Label:SetJustifyH("LEFT")
    f.Label:SetText(text)
end

local function newRow(self, row)
    local f = newFrame("Frame", self.frame)
    f:SetSize(ROW_WIDTH, ROW_HEIGHT)
    f.row = row
    -- The label's side of the row says what the row does, as the options page's rows do.
    if row.tip then
        f:EnableMouse(true)
        withTooltip(f, (row.name and row.name ~= "") and row.name or row.text, row.tip)
    end
    return f
end

local function makeSlider(self, row)
    local f = newRow(self, row)
    label(f, row.name)
    f.Slider = newFrame("Frame", f, "MinimalSliderWithSteppersTemplate")
    f.Slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
    f.Slider:SetPoint("LEFT", f.Label, "RIGHT", 5, 0)
    f.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not f.initializing then
            ns.SafeCall(self.Set, self, row, value)
        end
    end, f)
    f.formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
        MinimalSliderWithSteppersMixin.Label.Right, row.format) }
    local handle = self
    function f:Update(enabled)
        if not (self.Slider.Slider and self.Slider.Slider:IsDraggingThumb()) then
            local range = handle:Range(row)
            self.initializing = true
            self.Slider:Init(handle:Value(row), range[1], range[2], (range[2] - range[1]) / row.step, self.formatters)
            self.initializing = false
        end
        self.Slider:SetEnabled(enabled)
    end
    return f
end

-- Blizzard's EditModeSettingCheckboxTemplate: the game's check box, its label beside it.
local function makeCheck(self, row)
    local f = newRow(self, row)
    local b = newFrame("CheckButton", f)
    b:SetSize(32, 32)
    b:SetPoint("LEFT", -5, 0)
    b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function(button)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.SafeCall(self.Set, self, row, button:GetChecked() and true or false)
    end)
    withTooltip(b, row.name, row.tip)
    f.Button = b
    f.Label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    f.Label:SetPoint("LEFT", b, "RIGHT", 5, 0)
    f.Label:SetPoint("RIGHT", f, "RIGHT")
    f.Label:SetJustifyH("LEFT")
    f.Label:SetText(row.name)
    local handle = self
    function f:Update(enabled)
        self.Button:SetChecked(handle:Value(row) and true or false)
        self.Button:SetEnabled(enabled)
        self.Label:SetFontObject(enabled and "GameFontHighlightMedium" or "GameFontDisableMed2")
    end
    return f
end

-- Blizzard's EditModeSettingDropdownTemplate: the label, then the game's dropdown with a radio for each value.
local function makeChoice(self, row)
    local f = newRow(self, row)
    label(f, row.name)
    f.Dropdown = newFrame("DropdownButton", f, "WowStyle1DropdownTemplate")
    f.Dropdown:SetWidth(DROPDOWN_WIDTH)
    f.Dropdown:SetPoint("LEFT", f.Label, "RIGHT", 5, 0)
    f.Dropdown:SetupMenu(function(_, root)
        for _, v in ipairs(row.values) do
            root:CreateRadio(v[2], function()
                return self:Value(row) == v[1]
            end, function()
                ns.SafeCall(self.Set, self, row, v[1])
            end, v[1])
        end
    end)
    function f:Update(enabled)
        if self.Dropdown.GenerateMenu then
            self.Dropdown:GenerateMenu()
        end
        self.Dropdown:SetEnabled(enabled)
    end
    return f
end

-- The options page's button row: its label, then the game's button, under the controls beside it.
local function makeRowButton(self, row)
    local f = newRow(self, row)
    label(f, row.name or "")
    f.Button = newFrame("Button", f, "UIPanelButtonTemplate")
    f.Button:SetSize(row.width or ROW_BUTTON_WIDTH, ROW_BUTTON_HEIGHT)
    f.Button:SetPoint("LEFT", f.Label, "RIGHT", 5, 0)
    f.Button:SetText(row.text)
    f.Button:SetMotionScriptsWhileDisabled(true)
    f.Button:SetScript("OnClick", function()
        ns.SafeCall(row.click)
    end)
    withTooltip(f.Button, row.text, row.tip)
    function f:Update(enabled)
        self.Button:SetEnabled(enabled)
    end
    return f
end

local function toggle(self, section)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    self.openSection = self.openSection ~= section.id and section.id or nil
    ns.SafeCall(self.Layout, self)
end

-- The window look's bar, the notebook's own section header: the gold name, a + or a − on the right, a thin gold rule.
local function makeWindowSection(self, section)
    local b = newFrame("Button", self.frame)
    b:SetSize(ROW_WIDTH, WINDOW_SECTION)
    b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.Text:SetPoint("LEFT", 4, 0)
    b.Text:SetText(section.name)
    b.Sign = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.Sign:SetPoint("RIGHT", -6, 0)
    b.Line = b:CreateTexture(nil, "ARTWORK")
    b.Line:SetHeight(1)
    b.Line:SetPoint("BOTTOMLEFT", 2, 1)
    b.Line:SetPoint("BOTTOMRIGHT", -2, 1)
    b.Line:SetColorTexture(0.6, 0.5, 0.25, 0.45)
    b:SetScript("OnEnter", function(bar)
        bar.Text:SetFontObject("GameFontHighlight")
    end)
    b:SetScript("OnLeave", function(bar)
        bar.Text:SetFontObject("GameFontNormal")
    end)
    b.section = section
    b:SetScript("OnClick", function()
        toggle(self, section)
    end)
    return b
end

-- The Keybindings page's folding bar: its gold name, a plus that turns to a minus once open.
local function makeSection(self, section)
    if self.spec.look == "window" then
        return makeWindowSection(self, section)
    end
    local b = newFrame("Button", self.frame)
    b:SetSize(ROW_WIDTH, SECTION_HEIGHT)
    b.Left = b:CreateTexture(nil, "BACKGROUND")
    b.Left:SetAtlas("Options_ListExpand_Left", true)
    b.Left:SetPoint("TOPLEFT")
    b.Right = b:CreateTexture(nil, "BACKGROUND")
    b.Right:SetAtlas("Options_ListExpand_Right", true)
    b.Right:SetPoint("TOPRIGHT")
    local middle = b:CreateTexture(nil, "BACKGROUND")
    middle:SetAtlas("_Options_ListExpand_Middle", true)
    middle:SetPoint("TOPLEFT", b.Left, "TOPRIGHT")
    middle:SetPoint("TOPRIGHT", b.Right, "TOPLEFT")
    b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.Text:SetPoint("LEFT", 21, 2)
    b.Text:SetText(section.name)
    -- Hover brightens it, as it does Blizzard's gold names.
    b:SetScript("OnEnter", function(bar)
        bar.Text:SetFontObject("GameFontHighlight")
    end)
    b:SetScript("OnLeave", function(bar)
        bar.Text:SetFontObject("GameFontNormal")
    end)
    b.section = section
    b:SetScript("OnClick", function()
        toggle(self, section)
    end)
    return b
end

local function makeButton(self, spec)
    local b = newFrame("Button", self.frame, "UIPanelButtonTemplate")
    if self.spec.look == "window" then
        b:SetHeight(WINDOW_BUTTON)
    else
        b:SetSize(spec.wide and WIDE_BUTTON_WIDTH or BUTTON_WIDTH, BUTTON_HEIGHT)
    end
    b:SetText(spec.text)
    -- In the window look, as wide as its text needs, as the game's windows' own buttons.
    if self.spec.look == "window" then
        local fs = b.GetFontString and b:GetFontString()
        b:SetWidth(math.max(ROW_BUTTON_WIDTH, (fs and fs:GetStringWidth() or 0) + 30))
    end
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function()
        ns.SafeCall(spec.click, self)
    end)
    withTooltip(b, spec.text, spec.tip)
    return b
end

-- The window look's frame: ButtonFrameTemplate without its portrait, as the notebook, its title in the title bar,
-- its own close button, and its inset where the rows go, the buttons below it.
local function windowFrame(frame, title)
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if frame.SetTitle then
        frame:SetTitle(title)
    end
    frame.Title = frame.TitleContainer and frame.TitleContainer.TitleText
    if not frame.Title then
        frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.Title:SetPoint("TOP", 0, -5)
        frame.Title:SetText(title)
    end
    frame.Close = frame.CloseButton
    if not frame.Close then
        frame.Close = newFrame("Button", frame, "UIPanelCloseButton")
        frame.Close:SetPoint("TOPRIGHT")
    end
    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", INSET_SIDE, -WINDOW_TOP)
        frame.Inset:SetPoint("BOTTOMRIGHT", -INSET_SIDE, WINDOW_FOOT)
    end
end

local function build(self)
    local spec = self.spec
    local window = spec.look == "window"
    local frame = newFrame("Frame", UIParent, window and "ButtonFrameTemplate" or nil, spec.name)
    self.frame = frame
    if window then
        frame:SetFrameStrata("HIGH")
        frame:SetToplevel(true)
    else
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
    end
    frame:SetSize(window and Dialog.WINDOW_WIDTH or Dialog.WIDTH, 1)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    pcall(frame.SetDontSavePosition, frame, true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        pcall(f.SetUserPlaced, f, false)
    end)
    if spec.onKeyDown then
        frame:EnableKeyboard(true)
        frame:SetScript("OnKeyDown", function(f, key)
            ns.SafeCall(function()
                if not InCombatLockdown() then
                    f:SetPropagateKeyboardInput(not spec.onKeyDown(f, key))
                end
            end)
        end)
    end
    frame:Hide()
    if window then
        windowFrame(frame, spec.title)
    else
        frame.Border = newFrame("Frame", frame, "DialogBorderTranslucentTemplate")
        frame.Border:SetAllPoints()
        frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        frame.Title:SetPoint("TOP", 0, -TITLE_TOP)
        frame.Title:SetText(spec.title)
        frame.Close = newFrame("Button", frame, "UIPanelCloseButton")
        frame.Close:SetPoint("TOPRIGHT")
    end
    frame.Close:SetScript("OnClick", function()
        if spec.onClose then
            ns.SafeCall(spec.onClose)
        else
            self:Close()
        end
    end)
    frame.sections, frame.rows = {}, {}
    local makers = { slider = makeSlider, check = makeCheck, choice = makeChoice, button = makeRowButton }
    for _, section in ipairs(self:Sections()) do
        frame.sections[#frame.sections + 1] = makeSection(self, section)
        for _, row in ipairs(section.rows) do
            local f = makers[row.kind](self, row)
            f.section = section
            frame.rows[#frame.rows + 1] = f
        end
    end
    for _, b in ipairs(spec.buttons or {}) do
        if b.divider and window then
            frame[b.key] = frame:CreateTexture(nil, "ARTWORK")
            frame[b.key]:Hide()
        elseif b.divider then
            local divider = frame:CreateTexture(nil, "ARTWORK")
            divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
            divider:SetSize(WIDE_BUTTON_WIDTH, DIVIDER_HEIGHT)
            frame[b.key] = divider
        else
            frame[b.key] = makeButton(self, b)
        end
    end
    -- A fight greys the rows, and lets every key through before it starts.
    if spec.combatLock or spec.onKeyDown then
        for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
            ns.On(event, function()
                if event == "PLAYER_REGEN_DISABLED" and spec.onKeyDown then
                    pcall(frame.SetPropagateKeyboardInput, frame, true)
                end
                if spec.combatLock and frame:IsShown() then
                    ns.SafeCall(self.Layout, self)
                end
            end)
        end
    end
    if spec.escape and type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, spec.name)
    end
end

-- The open section's rows under its bar, the others' bars only, then the buttons; the window as tall as all that.
function Handle:Layout()
    local frame = self.frame
    if not frame then
        return
    end
    local enabled = not (self.spec.combatLock and InCombatLockdown())
    local window = self.spec.look == "window"
    local y = window and WINDOW_TOP + INSET_PAD / 2 or TITLE_TOP + frame.Title:GetStringHeight() + GAP
    local index = 1
    for _, bar in ipairs(frame.sections) do
        local open = bar.section.id == self.openSection
        bar:ClearAllPoints()
        bar:SetPoint("TOP", frame, "TOP", 0, -y)
        if window then
            bar.Sign:SetText(open and "–" or "+")
        else
            bar.Right:SetAtlas(open and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true)
        end
        y = y + (window and WINDOW_SECTION or SECTION_HEIGHT) + SPACING
        while frame.rows[index] and frame.rows[index].section == bar.section do
            local f = frame.rows[index]
            f:SetShown(open)
            if open then
                f:ClearAllPoints()
                f:SetPoint("TOP", frame, "TOP", 0, -y)
                f:Update(enabled)
                y = y + ROW_HEIGHT + SPACING
            end
            index = index + 1
        end
    end
    if window then
        -- The inset ends under the last row; the first button sits at the bottom left, the others at the bottom right,
        -- the last one rightmost, as the game's windows lay theirs out.
        frame:SetHeight(y - SPACING + INSET_PAD / 2 + WINDOW_FOOT)
        local right
        for i, b in ipairs(self.spec.buttons or {}) do
            local region = frame[b.key]
            if not b.divider then
                region:ClearAllPoints()
                if i == 1 then
                    region:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", INSET_SIDE - 4, 5)
                end
            end
        end
        for i = #(self.spec.buttons or {}), 2, -1 do
            local b = self.spec.buttons[i]
            if not b.divider then
                local region = frame[b.key]
                if right then
                    region:SetPoint("RIGHT", right, "LEFT", -4, 0)
                else
                    region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(INSET_SIDE - 4), 5)
                end
                right = region
            end
        end
        self:UpdateButtons()
        return
    end
    y = y - SPACING + GAP
    for _, b in ipairs(self.spec.buttons or {}) do
        local region = frame[b.key]
        region:ClearAllPoints()
        if b.divider then
            region:SetPoint("TOP", frame, "TOP", 0, -y)
            y = y + DIVIDER_HEIGHT + SPACING
        else
            if b.wide then
                region:SetPoint("TOP", frame, "TOP", 0, -y)
            else
                region:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y)
            end
            y = y + BUTTON_HEIGHT + SPACING
        end
    end
    y = y - SPACING + PADDING
    frame:SetHeight(y)
    self:UpdateButtons()
end

-- Each button enabled as its own test says, none in a fight when the rows are greyed.
function Handle:UpdateButtons()
    local frame = self.frame
    if not frame then
        return
    end
    local enabled = not (self.spec.combatLock and InCombatLockdown())
    for _, b in ipairs(self.spec.buttons or {}) do
        if not b.divider then
            frame[b.key]:SetEnabled(enabled and (not b.enabled or b.enabled(self)) and true or false)
        end
    end
end

function Handle:Open()
    if not self.frame then
        build(self)
    end
    if not self.frame:IsShown() then
        if self.spec.snapshotOnOpen then
            self:Snapshot()
        end
        if self.spec.place then
            self.spec.place(self.frame)
        end
    end
    self:Layout()
    self.frame:Show()
end

function Handle:Close()
    if self.frame then
        self.frame:Hide()
    end
end

function Handle:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

-- After a change from elsewhere, the rows and buttons say so.
function Handle:Changed()
    if self:IsShown() then
        self:Layout()
    end
end
