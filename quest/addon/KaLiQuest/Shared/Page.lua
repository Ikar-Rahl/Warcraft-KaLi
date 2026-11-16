-- Copied from shared/addon/Page.lua by tools/sync_shared.py: edit the source, not this copy.
-- The addon's page in the game's options, under AddOns: a frame of the addon's own (a "canvas" page), laid out as
-- Blizzard's own pages are, at their sizes: a title over a divider, white section headings, then rows, each a gold
-- name with its control beside it (the game's check box, the game's button), the name's side lit under the pointer
-- with a tooltip.
--
-- Why not Blizzard's own list of settings (its "vertical layout"), which the KaLi addons used until 2026-11-16. The
-- rows an addon puts in that list are drawn in frames the game hands on to its own pages, and its search box reads
-- them. What an addon's values went through keeps the addon's mark (taint), and the game then blames the addon for
-- what its own page does there: KaLi Quest was named three times for C_Discord.IsUserOAuthed, which only the Social
-- page calls (2026-11-12 20:55), each time with the game's « disable this addon? » popup. Nothing of a canvas page
-- goes into those lists: the game shows the frame, and that's all. Every other addon Ikar runs has one (FlareUI,
-- Auctionator, Baganator, DialogueUI).
--
-- ns.Page.New(spec) registers the page and gives its handle; nothing is drawn before the page first shows. spec:
--   name        its name in the list
--   title       its title, the name unless given
--   rows()      its rows, asked for when it first shows, so the saved data is in:
--     { kind = "header", text }                          a section heading
--     { kind = "button", name, text, click(), tip }      a name, then the game's button
--     { kind = "check", name, tip, get(), set(value) }   a name, then the game's check box
--   frame       or a frame the addon made itself, shown as it is, in place of rows
--   pages       pages listed under this one: { { name, title, rows or frame }, ... }; their handles are handle.pages
-- handle:Open()      shows the page in the game's options. They don't open from an addon in a fight: false then, with
--                    the game's own line saying why
-- handle:Refresh()   the page's controls as their values are now, while it shows
local _, ns = ...

local Page = {}
ns.Page = Page

local Handle = {}
Handle.__index = Handle

-- Blizzard's sizes. The page's header (Blizzard_SettingsList.xml): the title, the divider under it. Its list
-- (Blizzard_SettingsList.lua): where the rows start, their sides, the gap between two. A row and a section heading
-- (Blizzard_SettingControls.xml and .lua): their heights, the name's left and its end left of the row's middle, where
-- the check box and the button start from the middle, the button's width, the check box's size.
local TITLE_LEFT, TITLE_TOP, DIVIDER_TOP = 7, 22, 50
local ROWS_TOP, ROWS_LEFT, ROWS_RIGHT, ROW_GAP = 62, 10, 20, 9
local ROW_HEIGHT, HEADING_HEIGHT, HEADING_LEFT, HEADING_TOP = 26, 45, 7, 16
local NAME_LEFT, NAME_END, CHECK_START, BUTTON_START, BUTTON_WIDTH = 37, 85, 80, 40, 200
local CHECK_WIDTH, CHECK_HEIGHT = 30, 29

-- Frames start without a parent: SmartNavigationMixin hooks CreateFrame and rebuilds the caller's button groups.
local function newFrame(kind, parent, template)
    local f = CreateFrame(kind, nil, nil, template)
    if parent then
        f:SetParent(parent)
    end
    return f
end

local function makeHeading(self, row)
    local f = newFrame("Frame", self.frame)
    f:SetHeight(HEADING_HEIGHT)
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.Title:SetPoint("TOPLEFT", HEADING_LEFT, -HEADING_TOP)
    f.Title:SetJustifyH("LEFT")
    f.Title:SetText(row.text)
    return f
end

-- What a row does, as Blizzard's rows say it: its name in white, then its tip.
local function showTip(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", -10, 0)
    GameTooltip:SetText((row.name and row.name ~= "") and row.name or row.text, 1, 1, 1)
    if row.tip then
        GameTooltip:AddLine(row.tip, nil, nil, nil, true)
    end
    GameTooltip:Show()
end

local function hideTip(owner)
    if GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

-- A row: its name on the left, cut rather than wrapped as Blizzard's; the left side, up to the control, lights the
-- whole row under the pointer and says what the row does, as the control does under the pointer.
local function newRow(self, row)
    local f = newFrame("Frame", self.frame)
    f:SetHeight(ROW_HEIGHT)
    f.row = row
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Text:SetJustifyH("LEFT")
    f.Text:SetWordWrap(false)
    f.Text:SetPoint("LEFT", NAME_LEFT, 0)
    f.Text:SetPoint("RIGHT", f, "CENTER", -NAME_END, 0)
    f.Text:SetText(row.name or "")
    f.Light = f:CreateTexture(nil, "BACKGROUND")
    f.Light:SetAllPoints()
    f.Light:SetColorTexture(1, 1, 1, 0.1)
    f.Light:Hide()
    f.Hover = newFrame("Frame", f)
    f.Hover:SetPoint("TOPLEFT")
    f.Hover:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -CHECK_START, 0)
    f.Hover:EnableMouse(true)
    f.Hover:SetScript("OnEnter", function(hover)
        f.Light:Show()
        showTip(hover, row)
    end)
    f.Hover:SetScript("OnLeave", function(hover)
        f.Light:Hide()
        hideTip(hover)
    end)
    return f
end

local function withTip(control, row)
    control:SetScript("OnEnter", function(c)
        showTip(c, row)
    end)
    control:SetScript("OnLeave", hideTip)
end

local function makeButton(self, row)
    local f = newRow(self, row)
    f.Button = newFrame("Button", f, "UIPanelButtonTemplate")
    f.Button:SetWidth(BUTTON_WIDTH)
    f.Button:SetPoint("LEFT", f, "CENTER", -BUTTON_START, 0)
    f.Button:SetText(row.text)
    f.Button:SetScript("OnClick", function()
        ns.SafeCall(row.click)
        ns.SafeCall(self.Refresh, self)
    end)
    withTip(f.Button, row)
    return f
end

-- Blizzard's SettingsCheckboxTemplate: its art, at its size, its two sounds. A click on the name's side ticks it too,
-- as Blizzard's.
local function makeCheck(self, row)
    local f = newRow(self, row)
    local b = newFrame("CheckButton", f)
    b:SetSize(CHECK_WIDTH, CHECK_HEIGHT)
    b:SetPoint("LEFT", f, "CENTER", -CHECK_START, 0)
    b:SetNormalAtlas("checkbox-minimal")
    b:SetPushedAtlas("checkbox-minimal")
    b:SetCheckedTexture("checkmark-minimal")
    b:SetDisabledCheckedTexture("checkmark-minimal-disabled")
    local function set(value)
        PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        ns.SafeCall(row.set, value)
        ns.SafeCall(self.Refresh, self)
    end
    b:SetScript("OnClick", function(button)
        set(button:GetChecked() and true or false)
    end)
    f.Hover:SetScript("OnMouseUp", function()
        ns.SafeCall(function()
            set(not row.get())
        end)
    end)
    withTip(b, row)
    f.Check = b
    function f:Update()
        self.Check:SetChecked(row.get() and true or false)
    end
    return f
end

local MAKERS = { header = makeHeading, button = makeButton, check = makeCheck }

-- Drawn once, when the page first shows.
function Handle:Build()
    if self.built then
        return
    end
    self.built = true
    local frame, spec = self.frame, self.spec
    frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    frame.Title:SetPoint("TOPLEFT", TITLE_LEFT, -TITLE_TOP)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText(spec.title or spec.name)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", 0, -DIVIDER_TOP)
    frame.rows = {}
    local y = ROWS_TOP
    for _, row in ipairs(spec.rows()) do
        local f = MAKERS[row.kind](self, row)
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", ROWS_LEFT, -y)
        f:SetPoint("RIGHT", frame, "RIGHT", -ROWS_RIGHT, 0)
        y = y + f:GetHeight() + ROW_GAP
        frame.rows[#frame.rows + 1] = f
    end
end

function Handle:Refresh()
    local frame = self.frame
    if not (frame and frame.rows and frame:IsShown()) then
        return
    end
    for _, f in ipairs(frame.rows) do
        if f.Update then
            f:Update()
        end
    end
end

function Handle:Open()
    if not self.category or ns.CombatRefused() then
        return false
    end
    Settings.OpenToCategory(self.category:GetID())
    return true
end

-- A page's frame: the addon's own as it is, or one drawn from the rows when it first shows. The game hides the page it
-- showed each time its options open, then shows the one asked for: each showing draws the controls as their values
-- are then.
local function pageFrame(self)
    local spec = self.spec
    if spec.frame then
        return spec.frame
    end
    local frame = newFrame("Frame")
    frame:Hide()
    frame:SetScript("OnShow", function()
        ns.SafeCall(self.Build, self)
        ns.SafeCall(self.Refresh, self)
    end)
    return frame
end

function Page.New(spec)
    local self = setmetatable({ spec = spec, pages = {} }, Handle)
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return self
    end
    self.frame = pageFrame(self)
    self.category = Settings.RegisterCanvasLayoutCategory(self.frame, spec.name)
    -- The pages under it first, as the game lists a page with what it holds when it joins the list.
    for i, sub in ipairs(spec.pages or {}) do
        local page = setmetatable({ spec = sub, pages = {} }, Handle)
        if Settings.RegisterCanvasLayoutSubcategory then
            page.frame = pageFrame(page)
            page.category = Settings.RegisterCanvasLayoutSubcategory(self.category, page.frame, sub.name)
        end
        self.pages[i] = page
    end
    Settings.RegisterAddOnCategory(self.category)
    return self
end
