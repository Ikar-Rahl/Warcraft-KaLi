-- Just enough of the WoW API to load the KaLi addons and their probes outside the game, for their runners (the family's
-- checks are tools/kali/checks.py; KaLi Recipe adds recipe/tools/lua/fakewow_recipe.lua). Where the game's answer is
-- known from this build's files, the fake gives that answer, not one of its own.
-- State lives in FakeWoW so tests can set up a quest log, combat and CVars, and fire events.
FakeWoW = { frames = {}, timers = {}, cvars = { autoQuestWatch = "1", showQuestDifficultyColor = "1", ActionButtonUseKeyDown = "1" },
    combat = false, entries = {}, watched = {},
    completed = {}, repeatable = {}, menus = {}, npc = nil, questID = 0, uiErrors = {}, registry = {} }
local F = FakeWoW

-- Frames: any method exists and does nothing, apart from the ones below.
local frameMethods = {}
-- An event the client doesn't have (F.invalidEvents, as a patch that took it away) is an error, as in game. The API
-- docs give the call a result, `registered`: true here, false for an event a test has the game refuse without an
-- error (F.refusedEvents).
function frameMethods:RegisterEvent(event)
    if F.invalidEvents and F.invalidEvents[event] then
        error('Frame:RegisterEvent(): Attempt to register unknown event "' .. tostring(event) .. '"', 2)
    end
    if F.refusedEvents and F.refusedEvents[event] then
        return false
    end
    self.events[event] = true
    return true
end
-- One unit's events alone, or a few units' (RegisterUnitEvent): the event comes to the frame for those units only,
-- the unit its first value, as in game; RegisterEvent after it takes every unit's again.
function frameMethods:RegisterUnitEvent(event, ...)
    if F.invalidEvents and F.invalidEvents[event] then
        error('Frame:RegisterUnitEvent(): Attempt to register unknown event "' .. tostring(event) .. '"', 2)
    end
    if F.refusedEvents and F.refusedEvents[event] then
        return false
    end
    local units = {}
    for i = 1, select("#", ...) do
        units[select(i, ...)] = true
    end
    self.events[event] = units
    return true
end
function frameMethods:UnregisterEvent(event)
    self.events[event] = nil
end
-- Every function the game is handed to call later on the player's doing (a frame's script, a hook, a callback of the
-- game's registry, what a menu's entry does), each once: F.handlers, for a runner to check they are guarded (KaLi
-- HUD's does: an error in one goes to the game alone, and the addon's own log never has it).
F.handlers = {}
local function handed(fn)
    if type(fn) == "function" then
        F.handlers[fn] = true
    end
    return fn
end
F.Handed = handed
function frameMethods:SetScript(name, fn)
    self.scripts[name] = handed(fn)
end
function frameMethods:GetScript(name)
    return self.scripts[name]
end
function frameMethods:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], handed(fn))
end
-- Runs a script and its hooks, as the game does.
function F.RunScript(frame, name, ...)
    -- the element the pointer is on: the last one entered
    if name == "OnEnter" then
        F.entered = frame
    end
    if frame.scripts[name] then
        frame.scripts[name](frame, ...)
    end
    for _, fn in ipairs(frame.hooks[name] or {}) do
        fn(frame, ...)
    end
end
function frameMethods:CreateFontString()
    local fs = CreateFrame("FontString")
    self.fontStrings = self.fontStrings or {}
    self.fontStrings[#self.fontStrings + 1] = fs
    return fs
end
function frameMethods:CreateTexture()
    return CreateFrame("Texture")
end
-- A texture's flat colour, kept for the tests (texture.colorTexture = { r, g, b, a }).
function frameMethods:SetColorTexture(r, g, b, a)
    self.colorTexture = { r, g, b, a or 1 }
end
-- Child frames, in the order they came, as GetChildren gives them: regions and animations aren't children.
local NOT_CHILDREN = { FontString = true, Texture = true, AnimationGroup = true, Animation = true }
local function adopt(parent, frame)
    if type(parent) == "table" and not NOT_CHILDREN[frame.kind] then
        parent.fakeChildren = parent.fakeChildren or {}
        table.insert(parent.fakeChildren, frame)
    end
end
-- Frame levels: just above the parent when made or moved to another, unless the template sets one. A frame's children
-- move with it when its level changes.
local TEMPLATE_LEVELS = { UIPanelCloseButton = 510, NineSlicePanelTemplate = 500 }
local function setLevel(frame, level)
    local by = level - (frame.fakeLevel or 0)
    frame.fakeLevel = level
    for _, child in ipairs(frame.fakeChildren or {}) do
        setLevel(child, child:GetFrameLevel() + by)
    end
end
function frameMethods:SetFrameLevel(level)
    setLevel(self, level)
end
function frameMethods:GetFrameLevel()
    return self.fakeLevel or 0
end
function frameMethods:SetParent(parent)
    if parent ~= self.parent then
        for i, child in ipairs(self.parent and self.parent.fakeChildren or {}) do
            if child == self then
                table.remove(self.parent.fakeChildren, i)
                break
            end
        end
        adopt(parent, self)
        if type(parent) == "table" then
            setLevel(self, parent:GetFrameLevel() + 1)
        end
    end
    self.parent = parent
end
-- All at once, as in game, whose Lua holds about 8000 values (LUAI_MAXCSTACK): past that the call errs. It did on
-- Ikar's minimap, crowded with another addon's pins (2026-11-22, KaLi HUD's Collect.lua: "stack overflow").
F.MOST_RESULTS = 7999
function frameMethods:GetChildren()
    local children = self.fakeChildren or {}
    if #children > F.MOST_RESULTS then
        error("stack overflow", 2)
    end
    return unpack(children)
end
function frameMethods:GetNumChildren()
    return #(self.fakeChildren or {})
end
function frameMethods:GetParent()
    return self.parent
end
-- The game's list of all its frames, one after another in the order they were made: EnumerateFrames() gives the first,
-- EnumerateFrames(frame) the one after it. Regions and animations aren't frames. A walk asks for the next of the one it
-- was just given, found at once; any other is looked for.
local walked, walkedAt
function EnumerateFrames(after)
    local start = 1
    if after ~= nil then
        if after == walked and F.frames[walkedAt] == after then
            start = walkedAt + 1
        else
            start = nil
            for i, f in ipairs(F.frames) do
                if f == after then
                    start = i + 1
                    break
                end
            end
            if not start then
                return nil
            end
        end
    end
    for i = start, #F.frames do
        local f = F.frames[i]
        if not NOT_CHILDREN[f.kind] then
            walked, walkedAt = f, i
            return f
        end
    end
    walked, walkedAt = nil, nil
    return nil
end
function frameMethods:GetName()
    return self.name
end
function frameMethods:GetObjectType()
    return self.kind
end
function frameMethods:Show()
    local was = self.shown ~= false
    self.shown = true
    if not was then
        F.RunScript(self, "OnShow")
    end
end
function frameMethods:Hide()
    local was = self.shown ~= false
    self.shown = false
    if was then
        F.RunScript(self, "OnHide")
    end
end
function frameMethods:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end
function frameMethods:IsShown()
    return self.shown ~= false
end
-- Text, roughly measured: 6 units a character, 12 a line, wrapped at the width when one is set.
function frameMethods:SetText(text)
    self.text = text
    self.highlighted = nil
end
function frameMethods:GetText()
    return self.text
end
-- The keyboard's focus, and an edit box's text selected whole, which new text undoes.
function frameMethods:SetFocus()
    F.focus = self
end
function frameMethods:ClearFocus()
    if F.focus == self then
        F.focus = nil
    end
end
function frameMethods:HasFocus()
    return F.focus == self
end
function frameMethods:HighlightText()
    self.highlighted = true
end
function frameMethods:GetStringWidth()
    return #(tostring(self.text or "")) * 6
end
function frameMethods:GetStringHeight()
    local width = self.width and self.width > 0 and self.width or math.huge
    return math.max(1, math.ceil(self:GetStringWidth() / width)) * 12
end
-- A hidden region has no position, as in game, where only what's shown gets laid out.
function frameMethods:GetTop()
    if self.shown == false then
        return nil
    end
    return self.top
end
function frameMethods:IsVisible()
    return self.shown ~= false
end
function frameMethods:IsProtected()
    return false, false
end
function frameMethods:SetWidth(width)
    self.width = width
end
function frameMethods:SetHeight(height)
    self.height = height
end
function frameMethods:SetSize(width, height)
    self.width, self.height = width, height
end
function frameMethods:GetWidth()
    return self.width or 0
end
function frameMethods:GetHeight()
    return self.height or 0
end
function frameMethods:GetNumPoints()
    return 1
end
-- The first point set since the last ClearAllPoints, as given.
function frameMethods:ClearAllPoints()
    self.point = nil
end
function frameMethods:SetPoint(...)
    self.point = self.point or { ... }
end
function frameMethods:GetPoint()
    return unpack(self.point or {})
end
function frameMethods:SetHitRectInsets(left, right, top, bottom)
    self.hitRect = { left, right, top, bottom }
end
function frameMethods:GetHitRectInsets()
    return unpack(self.hitRect or { 0, 0, 0, 0 })
end
-- A button's or a control's state: enabled unless set otherwise.
function frameMethods:SetEnabled(enabled)
    self.enabled = enabled and true or false
end
function frameMethods:IsEnabled()
    return self.enabled ~= false
end
-- A check button's tick.
function frameMethods:SetChecked(checked)
    self.checked = checked and true or false
end
function frameMethods:GetChecked()
    return self.checked == true
end
function frameMethods:EnableMouse(on)
    self.mouse = on and true or false
end
function frameMethods:IsMouseEnabled()
    return self.mouse == true
end
function frameMethods:EnableMouseWheel(on)
    self.wheel = on and true or false
end
function frameMethods:IsMouseWheelEnabled()
    return self.wheel == true
end
-- Only a change fires the script, or Blizzard's two-way scrollbar link would never settle.
function frameMethods:SetVerticalScroll(offset)
    if offset == self:GetVerticalScroll() then
        return
    end
    self.verticalScroll = offset
    F.RunScript(self, "OnVerticalScroll", offset)
end
function frameMethods:GetVerticalScroll()
    return self.verticalScroll or 0
end
function frameMethods:SetScrollChild(child)
    self.scrollChild = child
end
function frameMethods:GetVerticalScrollRange()
    local child = self.scrollChild
    return child and math.max(0, (child.height or 0) - (self.height or 0)) or 0
end
-- Tests set frame.mouseOver to put the pointer on a frame.
function frameMethods:IsMouseOver()
    return self.mouseOver == true
end
function frameMethods:CreateAnimationGroup()
    return CreateFrame("AnimationGroup")
end
function frameMethods:CreateAnimation()
    return CreateFrame("Animation")
end
function frameMethods:Play()
    self.plays = (self.plays or 0) + 1
end
function frameMethods:SetAlpha(alpha)
    self.alpha = alpha
end
function frameMethods:GetAlpha()
    return self.alpha or 1
end
function frameMethods:GetEffectiveAlpha()
    local parent = self.parent
    return self:GetAlpha() * (parent and parent.GetEffectiveAlpha and parent:GetEffectiveAlpha() or 1)
end
function frameMethods:GetEffectiveScale()
    local parent = self.parent
    return (self.scale or 1) * (parent and parent.GetEffectiveScale and parent:GetEffectiveScale() or 1)
end
function frameMethods:SetScale(scale)
    self.scale = scale
end
function frameMethods:GetScale()
    return self.scale or 1
end
function frameMethods:SetTextColor(r, g, b)
    self.textColor = { r, g, b }
end
function frameMethods:SetRotation(radians, point)
    self.rotation, self.rotationPoint = radians, point
end
function frameMethods:SetAtlas(name)
    self.atlas = name
end
-- Geometry only where a test sets it: frame.left, frame.top and its height.
function frameMethods:GetLeft()
    if self.shown == false then
        return nil
    end
    return self.left
end
function frameMethods:GetRight()
    local left = self:GetLeft()
    return left and left + self:GetWidth()
end
function frameMethods:GetBottom()
    return self:GetTop() and self.top - (self.height or 0)
end
function frameMethods:SetAttribute(key, value)
    self.attributes[key] = value
end
function frameMethods:GetAttribute(key)
    return self.attributes[key]
end
function frameMethods:RegisterForClicks(...)
    self.clicks = { ... }
end
-- A frame the player moved or sized is "user placed": the game then keeps where a named one was let go in its own
-- layout file (layout-local.txt) and puts it back there itself, unless the addon says it isn't placed any more
-- (SetUserPlaced(false)) or that its place isn't the game's to save (SetDontSavePosition). F.Placed lists the named
-- frames the game would write to that file.
function frameMethods:StartMoving()
    self.moving, self.userPlaced = true, true
end
function frameMethods:StartSizing(point)
    self.sizing, self.userPlaced = point or true, true
end
function frameMethods:StopMovingOrSizing()
    self.moving, self.sizing = nil, nil
end
function frameMethods:SetUserPlaced(placed)
    self.userPlaced = placed and true or false
end
function frameMethods:IsUserPlaced()
    return self.userPlaced == true
end
function frameMethods:SetDontSavePosition(dont)
    self.dontSavePosition = dont and true or false
end
function F.Placed()
    local names = {}
    for _, frame in ipairs(F.frames) do
        if frame.name and frame.userPlaced and not frame.dontSavePosition then
            names[#names + 1] = frame.name
        end
    end
    table.sort(names)
    return names
end
-- A mouse click on an addon's SecureActionButtonTemplate, as the game sends it: the press, then the release, each
-- only if registered, each running PreClick, the template's SecureActionButton_OnClick and PostClick. An addon's
-- button gets no isKeyPress nor isSecureAction, so its "useOnKeyDown" attribute, else the ActionButtonUseKeyDown
-- CVar, says which of the two acts. An "item" action records its item in F.usedItemLink.
function F.ClickSecure(button, mouseButton)
    mouseButton = mouseButton or "LeftButton"
    local registered = {}
    for _, kind in ipairs(button.clicks or {}) do
        registered[kind] = true
    end
    local onDown = button:GetAttribute("useOnKeyDown")
    if onDown == nil then
        onDown = F.cvars.ActionButtonUseKeyDown == "1"
    end
    for _, down in ipairs({ true, false }) do
        local suffix = down and "Down" or "Up"
        if registered["Any" .. suffix] or registered[mouseButton .. suffix] then
            F.RunScript(button, "PreClick", mouseButton, down)
            if down == onDown and button:GetAttribute("type") == "item" then
                F.usedItemLink = button:GetAttribute("item")
            end
            F.RunScript(button, "PostClick", mouseButton, down)
        end
    end
end
-- ObjectiveTrackerPOIButtonTemplate's and QuestObjectiveFindGroupButtonTemplate's own methods.
function frameMethods:SetQuestID(id)
    self.poiQuestID = id
end
function frameMethods:GetQuestID()
    return self.poiQuestID
end
function frameMethods:SetUp(id)
    self.setUpQuestID = id
end
function frameMethods:UpdateButtonStyle() end

-- Any other method-like name does nothing, so missing fields still read as nil, as on a real frame.
local METHOD_PREFIXES = { "Set", "Get", "Is", "Enable", "Disable", "Register", "Unregister", "Clear", "Create", "Start", "Stop",
    "Highlight", "Hook", "Can", "Has", "Add", "Remove", "Lock", "Unlock", "Play", "Raise", "Lower", "Adjust" }
local function noop() end

-- Blizzard's templates whose OnLoad, run inside CreateFrame, reads what a frame made without a parent lacks. As in
-- game, an error there goes to the game's error handler, past the caller's own capture, and CreateFrame still returns.
F.templateErrors = {}
-- NineSlicePanelMixin:OnLoad (Blizzard_SharedXML/NineSlice.lua): its layout's type, its own or its parent's
-- (GetFrameLayoutType); with one, its texture kit, its own or its parent's (GetFrameLayoutTextureKit), so a nine-slice
-- frame made with no parent errs as in game (KaLi HUD's dialog border, 2026-11-16: "NineSlice.lua:310: attempt to index
-- a nil value").
local function nineSliceOnLoad(frame)
    local layoutType = frame.layoutType or frame:GetParent().layoutType
    if layoutType then
        return frame.layoutTextureKit or frame:GetParent()[frame.atlasKey or "layoutTextureKit"]
    end
end
-- DialogTemplates.xml's borders: nine-slice panels of the "Dialog" layout (their KeyValue).
local function dialogBorder(frame)
    frame.layoutType = "Dialog"
    return nineSliceOnLoad(frame)
end
local TEMPLATE_ONLOAD = {
    NineSlicePanelTemplate = nineSliceOnLoad,
    DialogBorderNoCenterTemplate = dialogBorder,
    DialogBorderTemplate = dialogBorder,
    DialogBorderDarkTemplate = dialogBorder,
    DialogBorderTranslucentTemplate = dialogBorder,
    DialogBorderOpaqueTemplate = dialogBorder,
}
local function isMethodName(key)
    if type(key) ~= "string" then
        return false
    end
    for _, prefix in ipairs(METHOD_PREFIXES) do
        if key:sub(1, #prefix) == prefix and (#key == #prefix or key:sub(#prefix + 1, #prefix + 1):match("[A-Z]")) then
            return true
        end
    end
    return false
end

function CreateFrame(kind, name, parent, template)
    -- A button takes the mouse from the start, as in game; other frames only once EnableMouse is called.
    local frame = setmetatable({ kind = kind, name = name, parent = parent, template = template, events = {}, scripts = {}, hooks = {},
        attributes = {}, mouse = (kind == "Button" or kind == "CheckButton") or nil }, {
        __index = function(_, key)
            return frameMethods[key] or (isMethodName(key) and noop or nil)
        end,
    })
    F.frames[#F.frames + 1] = frame
    adopt(parent, frame)
    frame.fakeLevel = TEMPLATE_LEVELS[template] or (type(parent) == "table" and parent:GetFrameLevel() + 1) or 0
    if name then
        _G[name] = frame
    end
    if template == "SearchBoxTemplate" then
        frame.clearButton = CreateFrame("Button", nil, frame)
    elseif template == "MinimalSliderWithSteppersTemplate" then
        F.MakeSlider(frame)
    elseif template == "EditModeSystemSelectionTemplate" then
        F.MakeSelection(frame)
    elseif template == "WowStyle1DropdownTemplate" then
        F.MakeDropdown(frame)
    elseif template == "DefaultPanelFlatTemplate" then
        -- Its border and title sit high, at levels 500 and 510, over a close button left just above the panel.
        frame.layoutType = "ButtonFrameTemplateNoPortrait"
        frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
        frame.TitleContainer = CreateFrame("Frame", nil, frame)
        frame.TitleContainer:SetFrameLevel(510)
        frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
        function frame:SetTitle(title)
            self.TitleContainer.TitleText:SetText(title)
        end
    elseif template == "ButtonFrameTemplate" then
        -- Its own close button, the template's CloseButton (a UIPanelCloseButton).
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    elseif template == "UIPanelCloseButton" then
        -- Blizzard's own click, which hides its window through HideUIPanel (UIPanelCloseButton_OnClick, below).
        frame.scripts.OnClick = function(self, ...)
            return UIPanelCloseButton_OnClick(self, ...)
        end
    end
    local onLoad = TEMPLATE_ONLOAD[template]
    if onLoad then
        local ok, err = pcall(onLoad, frame)
        if not ok then
            F.templateErrors[#F.templateErrors + 1] = template .. ": " .. tostring(err)
            geterrorhandler()(err)
        end
    end
    return frame
end

-- The game sends PLAYER_REGEN_DISABLED just before a fight's lockdown starts (and PLAYER_REGEN_ENABLED just after it
-- ends): while that event is handled InCombatLockdown() still says no, and an addon may do what it can't a moment
-- later. A test sets F.combat, then fires the event: its handlers see the lockdown off, as in game.
function F.Fire(event, ...)
    local combat = F.combat
    if event == "PLAYER_REGEN_DISABLED" then
        F.combat = false
    end
    for _, frame in ipairs(F.frames) do
        local registered = frame.events[event]
        if registered and frame.scripts.OnEvent and (registered == true or registered[(...)]) then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
    if event == "PLAYER_REGEN_DISABLED" then
        F.combat = combat
    end
end

-- What the game blocks: a function the API docs mark both protected and restricted (SetPassThroughButtons,
-- SetPropagateMouseClicks, SetPropagateMouseMotion) or restricted (SetPropagateKeyboardInput), called by an addon's
-- code in a fight, on any frame. Nothing happens then but the event that blames the addon: F.blame, the addon the
-- runner loaded first. F.blocked lists them. Out of a fight the call's arguments are kept in the frame's field of the
-- same name less "Set", its first letter small ("passThroughButtons").
F.blocked = {}
function F.Blocked(fn)
    F.blocked[#F.blocked + 1] = fn
    F.Fire("ADDON_ACTION_BLOCKED", F.blame, fn)
end
for _, name in ipairs({ "PassThroughButtons", "PropagateMouseClicks", "PropagateMouseMotion", "PropagateKeyboardInput" }) do
    local field = name:sub(1, 1):lower() .. name:sub(2)
    frameMethods["Set" .. name] = function(self, ...)
        if F.combat then
            F.Blocked("Frame:Set" .. name .. "()")
            return
        end
        self[field] = { ... }
    end
end

-- A secret value, as the game gives an addon while what it asks is restricted (a unit's speed in a fight, a unit's
-- name or GUID where identities are): it can be kept and passed on, and issecretvalue tells it; comparing it, joining
-- it to text, turning it into text, doing sums with it or looking inside it is an error. F.identitySecret hides every
-- unit's name and GUID but the player's own.
local function secretError(what)
    return function()
        error("attempt to " .. what .. " a secret value", 2)
    end
end
F.SECRET = setmetatable({}, { __tostring = secretError("convert to a string"), __concat = secretError("concatenate"),
    __eq = secretError("compare"), __lt = secretError("compare"), __le = secretError("compare"),
    __index = secretError("index"), __newindex = secretError("index"), __call = secretError("call"),
    __add = secretError("perform arithmetic on"), __sub = secretError("perform arithmetic on"),
    __mul = secretError("perform arithmetic on"), __div = secretError("perform arithmetic on"),
    __unm = secretError("perform arithmetic on"), __len = secretError("get the length of") })
function issecretvalue(v)
    return rawequal(v, F.SECRET)
end

C_Timer = {
    After = function(_, fn)
        F.timers[#F.timers + 1] = fn
    end,
    -- Each tick is queued at once, so one RunTimers plays them all.
    NewTicker = function(_, fn, iterations)
        local ticker = { cancelled = false }
        function ticker:Cancel()
            self.cancelled = true
        end
        for _ = 1, iterations or 1 do
            F.timers[#F.timers + 1] = function()
                if not ticker.cancelled then
                    fn(ticker)
                end
            end
        end
        return ticker
    end,
}

-- The game measures scroll ranges after the frame's code has run, then fires OnScrollRangeChanged.
function F.LayoutPass()
    for _, frame in ipairs(F.frames) do
        if frame.scrollChild then
            local range = frame:GetVerticalScrollRange()
            if range ~= frame.lastRange then
                frame.lastRange = range
                F.RunScript(frame, "OnScrollRangeChanged", 0, range)
            end
        end
    end
end

-- Runs queued timers, including ones they queue, like frames passing.
function F.RunTimers()
    for _ = 1, 100 do
        F.LayoutPass()
        if #F.timers == 0 then
            return
        end
        local queue = F.timers
        F.timers = {}
        for _, fn in ipairs(queue) do
            fn()
        end
    end
    error("timers keep queueing more timers")
end

-- Runs the timers queued now, once, as one frame passing: the ones they queue wait, as a timer of some seconds would.
-- The fake keeps no clock for timers, so a test runs a frame where it needs a later timer still to come.
function F.RunFrame()
    F.LayoutPass()
    local queue = F.timers
    F.timers = {}
    for _, fn in ipairs(queue) do
        fn()
    end
end

UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}
SlashCmdList = {}
BACKDROP_DARK_DIALOG_32_32 = {}
ChatFontNormal = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Guerrier", PALADIN = "Paladin" }
QUESTS_LABEL = "Quêtes"
-- the French client's colon after a name, a no-break space before it (GlobalStrings' HEADER_COLON)
HEADER_COLON = "\194\160:"
TRACK_QUEST_ABBREV = "Suivi"
WORLD = "Monde"
ERR_NOT_IN_COMBAT = "Impossible de faire ceci tout en combattant."
HUD_EDIT_MODE_MENU = "Mode Édition"
HUD_EDIT_MODE_REVERT_CHANGES = "Annuler les modifications"
DEFAULTS = "Par défaut"
ERROR_SLASH_EDITMODE_CANNOT_ENTER = "Impossible de passer en mode édition pour le moment"

F.printed = {}
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    F.printed[#F.printed + 1] = table.concat(parts, " ")
end

date = os.date
tinsert = table.insert
local clock = 0
function GetTime()
    clock = clock + 0.016
    return clock
end
function F.Advance(seconds)
    clock = clock + seconds
end
function GetLocale()
    return "frFR"
end
function GetBuildInfo()
    return "1.60.1", "70790", "Nov 2026", 16001
end
function GetZoneText()
    return F.zoneText or "Marche de l'Ouest"
end
function UnitLevel()
    return 23
end
function UnitFactionGroup()
    return "Alliance", "Alliance"
end
function GetScreenWidth()
    return 2133
end
function GetScreenHeight()
    return 1200
end
function debugstack()
    return debug.traceback()
end
function debugprofilestop()
    return os.clock() * 1000
end
function SecondsToClock(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
F.errors = {}
function geterrorhandler()
    return function(msg)
        F.errors[#F.errors + 1] = msg
    end
end
function InCombatLockdown()
    return F.combat
end
function GetCVar(name)
    return F.cvars[name]
end
function SetCVar(name, value)
    F.cvars[name] = tostring(value)
    F.Fire("CVAR_UPDATE", name, tostring(value))
    return true
end
function UnitClass()
    return "Guerrière", "WARRIOR", 1
end
function UnitGUID(unit)
    if F.identitySecret and unit ~= "player" then
        return F.SECRET
    end
    if unit == "questnpc" or unit == "npc" then
        return F.npc
    end
end
function GetQuestID()
    return F.questID
end
function issecurevariable()
    return true, nil
end
function hooksecurefunc(t, key, fn)
    if type(t) == "string" then
        t, key, fn = _G, t, key
    end
    local original = t[key]
    F.Handed(fn)
    t[key] = function(...)
        local results = { original(...) }
        fn(...)
        return unpack(results)
    end
end
function wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end
GetTasksTable = function()
    return {}
end
function GetQuestLogSpecialItemInfo(index)
    local row = F.entries[index]
    if row and row.item then
        return "item:" .. row.item, 134400, row.charges or 1, false
    end
end
function UseQuestLogSpecialItem(index)
    F.usedItem = index
end
function GetQuestLogQuestText()
    return "Description", "Objectifs"
end
function CollapseQuestHeader(index)
    F.entries[index].isCollapsed = true
end
function ExpandQuestHeader(index)
    F.entries[index].isCollapsed = false
end
Menu = {
    ModifyMenu = function(tag, fn)
        F.menus[tag] = fn
    end,
}

-- Blizzard's tracker, as far as the probe looks at it.
ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
ObjectiveTrackerFrame:SetSize(260, 800)
ObjectiveTrackerFrame.Header = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
ObjectiveTrackerFrame.NineSlice = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
ObjectiveTrackerFrame.modules = {}
ObjectiveTrackerFrame.Update = function() end
-- As Blizzard's: SetContainer reparents the section into the host.
function ObjectiveTrackerFrame:AddModule(module)
    module:SetParent(self)
end
RightManagedFrameContainer = CreateFrame("Frame", "RightManagedFrameContainer", UIParent)
ObjectiveTrackerModuleMixin = {
    AddBlock = function(self, block)
        self.hasTriedBlocks = true
        if not self:CanFitBlock(block) then
            self.hasSkippedBlocks = true
        end
    end,
    CanFitBlock = function()
        return true
    end,
}
-- No parent until Blizzard's setup puts it in the host, as the template has none.
QuestObjectiveTracker = CreateFrame("Frame", "QuestObjectiveTracker", nil)
QuestObjectiveTracker.AddBlock = ObjectiveTrackerModuleMixin.AddBlock
QuestObjectiveTracker.CanFitBlock = ObjectiveTrackerModuleMixin.CanFitBlock
ObjectiveTrackerFrame.modules[1] = QuestObjectiveTracker
-- The sections the addon doesn't draw. Each lays itself out as Blizzard's does, finding something to show only once a
-- test puts its name in F.filled; F.UpdateSections is Blizzard's container running them all.
F.filled = {}
for _, name in ipairs({ "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "AdventureObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }) do
    local section = CreateFrame("Frame", name, nil)
    function section:Update()
        self.hasContents = F.filled[name] == true
        self.hasTriedBlocks = self.hasContents
        return 0, false
    end
    ObjectiveTrackerFrame.modules[#ObjectiveTrackerFrame.modules + 1] = section
end
function F.UpdateSections()
    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        if module.Update then
            module:Update(800)
        end
    end
end
-- One of Edit Mode's systems (EditModeSystemMixin): it takes its own box's drag.
function ObjectiveTrackerFrame:OnDragStart()
    self.systemDragging = true
end
function ObjectiveTrackerFrame:OnDragStop()
    self.systemDragging = nil
end
QuestTimerFrame = CreateFrame("Frame", "QuestTimerFrame", ObjectiveTrackerFrame)
-- F.questTimerHeight: the panel's height while a timed quest runs, as Blizzard's 43 plus 16 per timer.
function QuestTimerFrame:GetTopPadding()
    return F.questTimerHeight and F.questTimerHeight + 18 or 0
end
function QuestTimerFrame:SetScale(scale)
    self.scale = scale
end
function QuestTimerFrame:GetScale()
    return self.scale or 1
end

-- What the addon's tracker draws with. Edit Mode's text size points Blizzard's line and header fonts at the
-- ObjectiveTrackerFont families, as SetTextSize does.
local function fontObject(size)
    local font = CreateFrame("Font")
    function font:SetFontObject(parent)
        self.parentFont = type(parent) == "string" and _G[parent] or parent
    end
    function font:GetFont()
        if self.parentFont then
            return self.parentFont:GetFont()
        end
        return "Fonts\\FRIZQT__.TTF", size, ""
    end
    return font
end
ObjectiveTrackerLineFont = fontObject(12)
ObjectiveTrackerHeaderFont = fontObject(14)
for size = 12, 22 do
    _G["ObjectiveTrackerFont" .. size] = fontObject(size)
end
ObjectiveTrackerManager = { backgroundAlpha = 0, moduleToContainerMap = {} }
function ObjectiveTrackerManager:SetTextSize(textSize)
    if textSize < 12 or textSize > 20 then
        return
    end
    ObjectiveTrackerLineFont:SetFontObject("ObjectiveTrackerFont" .. textSize)
    ObjectiveTrackerHeaderFont:SetFontObject("ObjectiveTrackerFont" .. (textSize + 2))
end
function ObjectiveTrackerManager:SetOpacity() end
function ObjectiveTrackerManager:GetContainerForModule(module)
    return self.moduleToContainerMap[module]
end
function ObjectiveTrackerManager:Init()
    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        self.moduleToContainerMap[module] = ObjectiveTrackerFrame
        ObjectiveTrackerFrame:AddModule(module)
    end
end
-- Blizzard runs Init once both events have come, which is after PLAYER_LOGIN.
local managerInit = CreateFrame("Frame")
local managerSeen = {}
managerInit:RegisterEvent("PLAYER_ENTERING_WORLD")
managerInit:RegisterEvent("VARIABLES_LOADED")
managerInit:SetScript("OnEvent", function(self, event)
    managerSeen[event] = true
    self:UnregisterEvent(event)
    if managerSeen.PLAYER_ENTERING_WORLD and managerSeen.VARIABLES_LOADED then
        ObjectiveTrackerManager:Init()
    end
end)
EventRegistry = {}
function EventRegistry:RegisterCallback(event, fn, owner)
    F.Handed(fn)
    F.registry[event] = F.registry[event] or {}
    table.insert(F.registry[event], function(...)
        fn(owner, ...)
    end)
end
function F.TriggerRegistry(event, ...)
    for _, fn in ipairs(F.registry[event] or {}) do
        fn(...)
    end
end
F.triggered = {}
function EventRegistry:TriggerEvent(event, ...)
    F.triggered[#F.triggered + 1] = { event = event, args = { ... } }
    F.TriggerRegistry(event, ...)
end

-- The tooltip records its lines: F.tooltip.lines, with party progress as "party:<questID>".
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
F.tooltip = { lines = {} }
function GameTooltip:SetOwner(owner)
    self.owner = owner
    F.tooltip = { owner = owner, lines = {} }
end
function GameTooltip:GetOwner()
    return self.owner
end
function GameTooltip:SetText(text)
    F.tooltip.lines[#F.tooltip.lines + 1] = text
end
function GameTooltip:AddLine(text)
    F.tooltip.lines[#F.tooltip.lines + 1] = text
end
function GameTooltip:SetQuestPartyProgress(questID)
    F.tooltip.lines[#F.tooltip.lines + 1] = "party:" .. questID
end
function GameTooltip:Show()
    self.shown = true
    F.tooltip.shown = true
end
function GameTooltip:Hide()
    self.owner = nil
    self.shown = false
    F.tooltip.shown = false
end

-- Blizzard's slider with steppers (MinimalSlider.lua), as far as an addon's rows use it. Init sets the range, the
-- step and the value and tells no one; SetValue, as a drag or a stepper's click, snaps to the step, stays in the range
-- and, on a change, tells the callbacks. rightText is what the label right of the bar shows.
MinimalSliderWithSteppersMixin = {
    Event = { OnValueChanged = "OnValueChanged", OnInteractStart = "OnInteractStart", OnInteractEnd = "OnInteractEnd" },
    Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 },
}
function CreateMinimalSliderFormatter(_, value)
    if value == nil then
        return function(v)
            return v
        end
    elseif type(value) == "function" then
        return value
    end
    return function()
        return value
    end
end
local sliderMethods = {}
function sliderMethods:Init(value, minValue, maxValue, steps, formatters)
    self.minValue, self.maxValue, self.step, self.formatters = minValue, maxValue, (maxValue - minValue) / steps, formatters
    self.value = value
    self:FormatValue(value)
end
function sliderMethods:FormatValue(value)
    local format = self.formatters and self.formatters[MinimalSliderWithSteppersMixin.Label.Right]
    self.rightText = format and tostring(format(value)) or nil
end
function sliderMethods:GetValue()
    return self.value
end
function sliderMethods:SetValue(value)
    value = self.minValue + math.floor((value - self.minValue) / self.step + 0.5) * self.step
    value = math.max(self.minValue, math.min(self.maxValue, value))
    if value == self.value then
        return
    end
    self.value = value
    self:FormatValue(value)
    for owner, fn in pairs(self.callbacks[MinimalSliderWithSteppersMixin.Event.OnValueChanged] or {}) do
        fn(owner, value)
    end
end
function sliderMethods:RegisterCallback(event, fn, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][owner] = fn
end
function sliderMethods:UnregisterCallback(event, owner)
    if self.callbacks[event] then
        self.callbacks[event][owner] = nil
    end
end
function sliderMethods:SetEnabled(enabled)
    self.enabled = enabled and true or false
end
function sliderMethods:IsSliderEnabled()
    return self.enabled ~= false
end
function F.MakeSlider(frame)
    for name, fn in pairs(sliderMethods) do
        frame[name] = fn
    end
    frame.callbacks = {}
    frame.Slider = CreateFrame("Slider", nil, frame)
end

-- Blizzard's Edit Mode dialog for a selected system (EditModeDialogs.lua), without its own rows: attaching updates it,
-- then shows it, and hiding forgets the system. Hidden until a test attaches it.
EditModeSystemSettingsDialog = CreateFrame("Frame", "EditModeSystemSettingsDialog", UIParent)
EditModeSystemSettingsDialog:SetSize(383, 230)
EditModeSystemSettingsDialog.shown = false
function EditModeSystemSettingsDialog:AttachToSystemFrame(systemFrame)
    self.attachedToSystem = systemFrame
    self:UpdateDialog(systemFrame)
    self:Show()
end
function EditModeSystemSettingsDialog:UpdateDialog()
end
EditModeSystemSettingsDialog:SetScript("OnHide", function(self)
    self.attachedToSystem = nil
end)

-- A frame's selection box in Edit Mode (EditModeSystemSelectionBaseTemplate and its mixin, EditModeSystemTemplates.xml
-- and .lua): highlighted, or selected with its name. state says which, nil while hidden. It comes with Blizzard's own
-- scripts and its drag registered, all of which take its parent for one of Edit Mode's systems: a press selects the
-- parent in Edit Mode's manager, a drag calls the parent's own OnDragStart and OnDragStop (EditModeSystemMixin's), the
-- pointer shows its system's name. A box on an addon's own frame has to replace the first three: a fake box with no
-- script at all hid KaLi HUD's error on a drag (2026-11-16). F.selections lists every box made.
F.selections = {}
function F.MakeSelection(frame)
    frame.Label = frame:CreateFontString()
    frame.MouseOverHighlight = CreateFrame("Frame", nil, frame)
    frame.MouseOverHighlight.shown = false
    frame.shown = false
    frame.drags = { "LeftButton" }
    function frame:SetSystem(system)
        self.system = system
    end
    function frame:ShowHighlighted()
        self.state, self.isSelected = "highlight", false
        self:Show()
    end
    function frame:ShowSelected()
        self.state, self.isSelected = "selected", true
        self.Label:SetText(self.system:GetSystemName())
        self:Show()
    end
    frame:SetScript("OnMouseDown", function(self)
        EditModeManagerFrame:SelectSystem(self.parent)
    end)
    frame:SetScript("OnDragStart", function(self)
        self.parent:OnDragStart()
    end)
    frame:SetScript("OnDragStop", function(self)
        self.parent:OnDragStop()
    end)
    frame:SetScript("OnEnter", function(self)
        self.MouseOverHighlight:Show()
        if not self.isSelected then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.system:GetSystemName())
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self.MouseOverHighlight:Hide()
        GameTooltip:Hide()
    end)
    frame.mouse = true
    F.selections[#F.selections + 1] = frame
end
-- What the mouse can do to each box that is shown and takes it, as a player trying every frame in Edit Mode: the
-- pointer on it, a press, a drag and its release, the pointer away. Returns what failed, one line a box.
function F.TrySelections()
    local failed = {}
    for i, box in ipairs(F.selections) do
        if box:IsShown() and box:IsMouseEnabled() then
            for _, step in ipairs({ { "OnEnter" }, { "OnMouseDown", "LeftButton" }, { "OnDragStart", "LeftButton" }, { "OnDragStop" },
                { "OnLeave" } }) do
                local ok, err = pcall(F.RunScript, box, unpack(step))
                if not ok then
                    failed[#failed + 1] = string.format("selection box %d, %s: %s", i, step[1], tostring(err))
                    break
                end
            end
        end
    end
    return failed
end
-- Blizzard's tracker's own box, which the addon makes see-through and deaf to the mouse.
ObjectiveTrackerFrame.Selection = CreateFrame("Frame", nil, ObjectiveTrackerFrame, "EditModeSystemSelectionTemplate")

-- Edit Mode's manager: which of Blizzard's frames is selected, its snapping and its grid. Selecting one of Blizzard's
-- frames lets go of the one before, as Blizzard's SelectSystem does, and attaches its dialog.
F.snap = false
EditModeManagerFrame = CreateFrame("Frame", "EditModeManagerFrame", UIParent)
EditModeManagerFrame.Grid = CreateFrame("Frame", nil, EditModeManagerFrame)
EditModeManagerFrame.Grid.gridSpacing = 100
EditModeManagerFrame.Grid.shown = false
function EditModeManagerFrame:SelectSystem(systemFrame)
    self.selected = systemFrame
    EditModeSystemSettingsDialog:AttachToSystemFrame(systemFrame)
end
function EditModeManagerFrame:ClearSelectedSystem()
    self.selected = nil
    self.cleared = (self.cleared or 0) + 1
    EditModeSystemSettingsDialog:Hide()
end
function EditModeManagerFrame:IsSnapEnabled()
    return F.snap
end
-- Edit Mode opens as a panel; F.editModeRefused is the game saying no (a new player's restrictions, a game rule).
EditModeManagerFrame:Hide()
function EditModeManagerFrame:CanEnterEditMode()
    return not F.editModeRefused
end

-- The panels the addons open and close, as Blizzard's panel manager does: Edit Mode's manager enters Edit Mode as it
-- shows, and leaves it as it hides, as its OnShow and OnHide do. In a fight it refuses both to an addon's code
-- (UIParentPanelManager.lua's CheckProtectedFunctionsAllowed: "We no longer allow addons to show or hide UI panels in
-- combat"): nothing happens but the game's chat line, INTERFACE_ACTION_BLOCKED, which no event tells, so no addon can
-- see it (Ikar 2026-11-22, KaLi Recipe's notebook that wouldn't close in a fight). F.panelsRefused lists the frames.
F.panelsRefused = {}
local function panelsAllowed(frame)
    if F.combat then
        F.panelsRefused[#F.panelsRefused + 1] = frame.name or tostring(frame)
        return false
    end
    return true
end
function ShowUIPanel(frame)
    if not frame or frame:IsShown() then
        return
    end
    if not panelsAllowed(frame) then
        return
    end
    F.shownPanel = frame
    frame:Show()
    if frame == EditModeManagerFrame then
        F.TriggerRegistry("EditMode.Enter")
    end
end
function HideUIPanel(frame)
    if not (frame and frame:IsShown()) then
        return
    end
    if not panelsAllowed(frame) then
        return
    end
    frame:Hide()
    if frame == EditModeManagerFrame then
        F.TriggerRegistry("EditMode.Exit")
    end
end
-- Blizzard's close button's click (SharedUIPanelTemplates.lua): its window's onCloseCallback, when it has one, says
-- whether to go on; then HideUIPanel, which a fight refuses an addon's window (above).
function UIPanelCloseButton_OnClick(self)
    local parent = self:GetParent()
    if parent then
        local continueHide = true
        if parent.onCloseCallback then
            continueHide = parent.onCloseCallback(self)
        end
        if continueHide then
            HideUIPanel(parent)
        end
    end
end

-- Blizzard's options window, as far as the addons open and close it. Its Close keeps what was set; while a change
-- waits for « Appliquer » (F.unapplied), it asks first and stays open, as Blizzard's does.
SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent)
SettingsPanel:Hide()
function SettingsPanel:Close(skipTransitionBackToOpeningPanel)
    if F.unapplied then
        F.popup = { which = "GAME_SETTINGS_CONFIRM_DISCARD" }
        return
    end
    self.skippedTransition = skipTransitionBackToOpeningPanel
    self:Hide()
end
-- Its layouts: the presets come first in the active layout's index, and aren't in the list. Their count is with Enum.
F.editLayouts = { activeLayout = 1, layouts = { { layoutName = "Mine" } } }
C_EditMode = {
    GetLayouts = function()
        return F.editLayouts
    end,
}

-- The game's dropdown with a menu (WowStyle1DropdownTemplate): F.MenuRadios lists its radios as a menu would.
function F.MakeDropdown(frame)
    function frame:SetupMenu(generator)
        self.generator = generator
    end
    function frame:GenerateMenu()
        self.generated = (self.generated or 0) + 1
    end
    function frame:SetEnabled(enabled)
        self.enabled = enabled and true or false
    end
end
function F.MenuRadios(dropdown)
    local radios = {}
    local root = {}
    function root:CreateRadio(text, isSelected, setSelected, value)
        radios[#radios + 1] = { text = text, selected = isSelected(value), pick = function()
            setSelected(value)
        end }
    end
    -- a group's title and the rule above it: not radios
    function root:CreateTitle() end
    function root:CreateDivider() end
    dropdown.generator(dropdown, root)
    return radios
end

-- The options page: F.settingsCategory.settings[variable] can be set as the panel would. F.settingsLayout.initializers
-- holds the page's rows in order, a control as { setting = setting }.
local function control(setting)
    F.settingsLayout:AddInitializer({ setting = setting })
end
-- As Blizzard's SettingMixin: the default goes through SetValue, so its callback runs, changed or not.
local function withDefault(setting, default)
    function setting:GetDefaultValue()
        return default
    end
    function setting:SetValueToDefault()
        if default == nil then
            return false
        end
        self:SetValue(default)
        return true
    end
    return setting
end
Settings = {
    VarType = { Boolean = "boolean" },
    Default = { True = true, False = false },
    RegisterVerticalLayoutCategory = function(name)
        local category = { name = name, settings = {} }
        function category:GetID()
            return 77
        end
        F.settingsCategory = category
        F.settingsLayout = { initializers = {} }
        function F.settingsLayout:AddInitializer(initializer)
            self.initializers[#self.initializers + 1] = initializer
        end
        return category, F.settingsLayout
    end,
    RegisterAddOnSetting = function(category, variable, key, tbl, _, name, default)
        local setting = withDefault({ key = key, tbl = tbl, name = name }, default)
        function setting:SetValueChangedCallback(fn)
            self.callback = fn
        end
        function setting:GetValue()
            return self.tbl[self.key]
        end
        function setting:SetValue(value)
            self.tbl[self.key] = value
            if self.callback then
                self.callback(self, value)
            end
        end
        category.settings[variable] = setting
        return setting
    end,
    CreateCheckbox = function(_, setting)
        control(setting)
    end,
    RegisterAddOnCategory = function(category)
        F.settingsRegistered = category
    end,
    -- A page of the addon's own, a "canvas": F.settingsPages lists them in the order registered, their IDs from 77,
    -- a page under another with its parent.
    RegisterCanvasLayoutCategory = function(frame, name)
        return F.CanvasPage(frame, name)
    end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        return F.CanvasPage(frame, name, parent)
    end,
    -- The panel opens as its OnShow has it: its first page picked again, one of the game's, so the canvas page it
    -- showed is taken out and hidden (SelectFirstCategory, ClearCurrentCategoryCanvas), and every canvas page asked to
    -- refresh, shown or not (CallRefreshOnCanvases). Then the page asked for is shown.
    OpenToCategory = function(id)
        F.settingsOpened = id
        if not SettingsPanel:IsShown() then
            SettingsPanel:Show()
            F.PickSettingsPage(nil)
            for _, page in ipairs(F.settingsPages) do
                if page.frame.OnRefresh then
                    page.frame:OnRefresh()
                end
            end
        end
        for _, page in ipairs(F.settingsPages) do
            if page.id == id then
                F.PickSettingsPage(page)
            end
        end
    end,
}
-- Canvas pages as the panel shows them (Blizzard_SettingsPanel.lua's DisplayLayout and ClearCurrentCategoryCanvas): the
-- page picked, by Settings.OpenToCategory or as a click in the panel's list (F.PickSettingsPage), has its frame put in
-- the panel's canvas, shown, and asked to refresh; the one shown before is taken out and hidden. Nothing of a canvas
-- page is in the panel's own lists, which is the point of one: F.settingsLayout stays nil for an addon that has no
-- other.
SettingsPanel.Container = CreateFrame("Frame", nil, SettingsPanel)
SettingsPanel.Container.SettingsCanvas = CreateFrame("Frame", nil, SettingsPanel.Container)
F.settingsPages = {}
function F.CanvasPage(frame, name, parent)
    assert(type(frame) == "table" and frame.GetObjectType, "a canvas page needs its frame")
    local page = { frame = frame, name = name, parent = parent, id = 76 + #F.settingsPages + 1 }
    function page:GetID()
        return self.id
    end
    function page:GetName()
        return self.name
    end
    F.settingsPages[#F.settingsPages + 1] = page
    return page, { frame = frame }
end
function F.PickSettingsPage(page)
    local before = F.settingsPage
    if before and before ~= page then
        before.frame:SetParent(nil)
        before.frame:ClearAllPoints()
        before.frame:Hide()
    end
    F.settingsPage = page
    if not page then
        -- one of the game's own pages
        return
    end
    local canvas = SettingsPanel.Container.SettingsCanvas
    page.frame:SetParent(canvas)
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(canvas)
    page.frame:Show()
    if page.frame.OnRefresh then
        page.frame:OnRefresh()
    end
end
-- A page's row by its name, as the shared page (Shared/Page.lua) keeps its rows in its frame.
function F.PageRow(page, name)
    for _, row in ipairs(page and page.frame.rows or {}) do
        if row.row and row.row.name == name then
            return row
        end
    end
end
function CreateSettingsListSectionHeaderInitializer(text)
    return { header = text }
end
function CreateSettingsButtonInitializer(name, buttonText, buttonClick, tooltip, addSearchTags)
    assert(addSearchTags ~= nil, "CreateSettingsButtonInitializer needs addSearchTags, as Blizzard's asserts")
    return { name = name, buttonText = buttonText, buttonClick = buttonClick, tooltip = tooltip }
end

-- Templates the client knows: all but F.missingTemplates.
F.missingTemplates = {}
C_XMLUtil = {
    GetTemplateInfo = function(name)
        if F.missingTemplates[name] then
            return nil
        elseif name == "MinimalScrollBar" then
            return { type = "EventFrame" }
        elseif name == "ObjectiveTrackerPOIButtonTemplate" or name == "QuestObjectiveFindGroupButtonTemplate" then
            return { type = "Button" }
        end
        return { type = "Frame" }
    end,
}
-- Events the client knows: all but F.invalidEvents.
F.invalidEvents = {}
F.refusedEvents = {}
C_EventUtils = {
    IsEventValid = function(name)
        return not F.invalidEvents[name]
    end,
}

-- Blizzard's two-way link between a ScrollFrame and a MinimalScrollBar, from ScrollUtil.lua and ScrollBar.lua: the
-- bar saturates its percentage and fires OnScroll on every change, which sets the frame's scroll, which sets the
-- bar again. The bar's parts exist so hooks on them can be run.
local function saturate(v)
    return math.max(0, math.min(1, v))
end
ScrollUtil = {
    InitScrollFrameWithScrollBar = function(scrollFrame, bar)
        bar.Track, bar.Back, bar.Forward = CreateFrame("Frame"), CreateFrame("Button"), CreateFrame("Button")
        bar.Track.Thumb = CreateFrame("Button")
        bar.scrollPercentage, bar.panExtentPercentage, bar.allowScroll, bar.callbacks = 0, 0.1, true, {}
        function bar:RegisterCallback(event, fn, owner)
            self.callbacks[event] = function(...)
                fn(owner, ...)
            end
        end
        function bar:GetScrollPercentage()
            return self.scrollPercentage
        end
        function bar:SetScrollPercentage(percentage)
            self.scrollPercentage = saturate(percentage)
            if self.callbacks.OnScroll then
                self.callbacks.OnScroll(self.scrollPercentage)
            end
        end
        function bar:SetPanExtentPercentage(percentage)
            self.panExtentPercentage = saturate(percentage)
        end
        function bar:SetScrollAllowed(allowed)
            self.allowScroll = allowed
        end
        function bar:IsScrollAllowed()
            return self.allowScroll
        end
        function bar:ScrollStepInDirection(direction)
            if self.allowScroll then
                self:SetScrollPercentage(self.scrollPercentage + self.panExtentPercentage * direction)
            end
        end
        local function onVerticalScroll(frame, offset)
            local range = frame:GetVerticalScrollRange()
            bar:SetScrollPercentage(range > 0 and offset / range or 0)
        end
        scrollFrame:SetScript("OnVerticalScroll", onVerticalScroll)
        function scrollFrame:GetPanExtent()
            return self.panExtent
        end
        function scrollFrame:SetPanExtent(extent)
            self.panExtent = extent
        end
        scrollFrame:SetPanExtent(30)
        scrollFrame:SetScript("OnScrollRangeChanged", function(frame)
            onVerticalScroll(frame, frame:GetVerticalScroll())
            local range = frame:GetVerticalScrollRange()
            bar:SetPanExtentPercentage(range > 0 and frame:GetPanExtent() / range or 0)
        end)
        scrollFrame:SetScript("OnMouseWheel", function(_, value)
            bar:ScrollStepInDirection(-value)
        end)
        bar:RegisterCallback("OnScroll", function(_, percentage)
            scrollFrame:SetVerticalScroll(percentage * scrollFrame:GetVerticalScrollRange())
        end, scrollFrame)
    end,
}
NineSliceUtil = {
    ApplyLayoutByName = function(frame, layout)
        frame.nineSliceLayout = layout
    end,
}
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
function PlaySound() end
function IsModifiedClick(name)
    return F.modifier == name
end
-- The key each modified click takes: F.modifiedClicks for a test's own, else this build's default, which the runner
-- reads from Forever's Bindings_Camelot.xml into F.MODIFIED_CLICKS ("SHIFT-BUTTON1" for CHATLINK, "SHIFT" for
-- QUESTWATCHTOGGLE: an invented "SHIFT" for every one hid the API check's false alarm on CHATLINK, 2026-11-11).
F.modifiedClicks, F.MODIFIED_CLICKS, F.MAP_TYPES = {}, {}, {}
function GetModifiedClick(action)
    return F.modifiedClicks[action] or F.MODIFIED_CLICKS[action]
end
function IsControlKeyDown()
    return F.ctrl == true
end
function IsShiftKeyDown()
    return F.shift == true
end
function IsInGroup()
    return F.inGroup == true
end
-- A party: F.partySize members besides the player, F.partyOn[questID] of them on the quest.
function GetNumSubgroupMembers()
    return F.partySize or 0
end
function QuestUtils_GetNumPartyMembersOnQuest(id)
    return F.partyOn and F.partyOn[id] or 0
end
Enum = { CraftingReagentType = { Modifying = 0, Basic = 1 }, ContentTrackingType = { Achievement = 2 }, ContentTrackingStopType = { Manual = 0 } }
-- Forever's three preset layouts: Modern, Classic and Gamepad.
Enum.EditModePresetLayoutsMeta = { NumValues = 3 }
-- The quest enums of this build's API documentation, and its constants as the game has them. The docs name the quest
-- tags' group QuestInfoLuaConsts, which the game doesn't have (Ikar's API check, build 70862); Blizzard's own Forever
-- code reads Constants.QuestConsts (Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua).
Enum.QuestTag = { Group = 1, PvP = 41, Raid = 62, Dungeon = 81, Legendary = 83, Heroic = 85, Raid10 = 88, Raid25 = 89 }
Enum.QuestFrequency = { Default = 0, Daily = 1, Weekly = 2, ResetByScheduler = 3 }
Enum.QuestClassification = { Important = 0, Legendary = 1, Campaign = 2, Calling = 3, Meta = 4, Recurring = 5, Questline = 6,
    Normal = 7, BonusObjective = 8, Threat = 9, WorldQuest = 10 }
Enum.RelativeContentDifficulty = { Trivial = 0, Easy = 1, Fair = 2, Difficult = 3, Impossible = 4 }
Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }
Constants = {
    QuestConsts = { QUEST_INFO_ELITE_ID = 1, QUEST_INFO_DUNGEON_ID = 81, QUEST_INFO_PVP_ID = 41, QUEST_INFO_RAID_ID = 62 },
    QuestWatchConsts = { MAX_QUEST_WATCHES = 25 },
}
-- Recipes: F.recipes[true|false] lists tracked recipe IDs, F.schematics[id] their reagents. Items: F.itemNames, F.itemCounts.
F.recipes, F.schematics, F.itemNames, F.itemCounts, F.itemLoads = { [true] = {}, [false] = {} }, {}, {}, {}, {}
C_TradeSkillUI = {
    GetRecipesTracked = function(recraft)
        return F.recipes[recraft == true]
    end,
    GetRecipeSchematic = function(id)
        return F.schematics[id]
    end,
    SetRecipeTracked = function(id, on, recraft)
        local list = F.recipes[recraft == true]
        for i = #list, 1, -1 do
            if list[i] == id and not on then
                table.remove(list, i)
            end
        end
    end,
    IsRecipeProfessionLearned = function()
        return true
    end,
    OpenRecipe = function(id)
        F.openedRecipe = id
    end,
}
C_Item = {
    GetItemNameByID = function(id)
        return F.itemNames[id]
    end,
    RequestLoadItemDataByID = function(id)
        F.itemLoads[id] = (F.itemLoads[id] or 0) + 1
    end,
    GetItemCount = function(id)
        return F.itemCounts[id] or 0
    end,
}
-- Achievements: F.achievements lists tracked IDs; F.achievementInfo[id] = { name, description, criteria = { {
-- text, done, eligible } } }.
F.achievements, F.achievementInfo = {}, {}
C_ContentTracking = {
    GetTrackedIDs = function()
        return F.achievements
    end,
    StopTracking = function(_, id)
        for i = #F.achievements, 1, -1 do
            if F.achievements[i] == id then
                table.remove(F.achievements, i)
            end
        end
    end,
}
function GetAchievementInfo(id)
    local a = F.achievementInfo[id]
    if a then
        return id, a.name, 10, false, nil, nil, nil, a.description, 0, 0, "", false, a.earned == true
    end
end
function GetAchievementNumCriteria(id)
    return #(F.achievementInfo[id] and F.achievementInfo[id].criteria or {})
end
function GetAchievementCriteriaInfo(id, i)
    local c = F.achievementInfo[id].criteria[i]
    return c.text, 0, c.done == true, 0, 1, c.text, 0, 0, "0 / 1", i, c.eligible ~= false, c.duration, c.elapsed
end
function GetAchievementLink(id)
    return "achievement:" .. id
end
function ShowAchievementFrameForAchievement(id)
    F.shownAchievement = id
end
ChatFrameUtil = {
    TryInsertQuestLinkForQuestID = function()
        return false
    end,
    GetActiveWindow = function()
        return F.chatOpen
    end,
    InsertLink = function(link)
        F.insertedLink = link
        return true
    end,
}
function QuestMapFrame_OpenToQuestDetails(id)
    F.opened = id
end
function ShowQuestComplete(id)
    F.shownComplete = id
end
function QuestMapQuestOptions_AbandonQuest(id)
    F.abandoned = id
end
UIErrorsFrame = {}
function UIErrorsFrame:AddExternalErrorMessage(msg)
    F.uiErrors[#F.uiErrors + 1] = msg
end
F.uiWarnings = {}
function UIErrorsFrame:AddExternalWarningMessage(msg)
    F.uiWarnings[#F.uiWarnings + 1] = msg
end
C_PlayerInfo = {
    GetContentDifficultyQuestForPlayer = function()
        return 2
    end,
}
function GetDifficultyColor()
    return { r = 1, g = 0.82, b = 0 }
end
function GetCVarBool(name)
    return F.cvars[name] == "1"
end
C_SuperTrack = {
    GetSuperTrackedQuestID = function()
        return F.superTracked or 0
    end,
    SetSuperTrackedQuestID = function(id)
        F.superTracked = id
    end,
}
-- Objectives come from each log row's objectives field: { { text = "...", finished = false } }.
function GetNumQuestLeaderBoards(index)
    local row = F.entries[index]
    return row and row.objectives and #row.objectives or 0
end
function GetQuestLogLeaderBoard(i, index)
    local o = F.entries[index].objectives[i]
    return o.text, "item", o.finished
end
function GetQuestLogCompletionText()
    return nil
end
F.money = 0
function GetMoney()
    return F.money
end
function GetMoneyString(money)
    return tostring(money) .. "c"
end

-- Menus record what was built, so tests can find an entry and choose it.
local function menuDescription()
    local d = { items = {} }
    local function add(kind, text, a, b)
        local item = menuDescription()
        item.kind, item.text, item.choose, item.isSelected = kind, text, F.Handed(a), b
        d.items[#d.items + 1] = item
        return item
    end
    function d:SetTag(tag, data)
        self.tag, self.data = tag, data
    end
    function d:CreateTitle(text)
        return add("title", text)
    end
    function d:CreateButton(text, fn)
        return add("button", text, fn)
    end
    function d:CreateRadio(text, isSelected, onSelect)
        return add("radio", text, onSelect, isSelected)
    end
    function d:CreateCheckbox(text, isSelected, onSelect)
        return add("checkbox", text, onSelect, isSelected)
    end
    function d:CreateDivider()
        return add("divider")
    end
    return d
end
MenuUtil = {
    CreateContextMenu = function(owner, generator)
        local d = menuDescription()
        generator(owner, d)
        F.lastMenu = d
        return d
    end,
}
-- A text as a reader compares it: each language's typography (2026-11-21: French's no-break spaces and apostrophe,
-- put in as its strings load) read as plain spaces and apostrophes, so a test can name an entry as it's written in its
-- language's file; whether the typography is right is the language test's (tests/Locales.lua).
function F.Plain(text)
    return type(text) == "string" and (text:gsub("\194\160", " "):gsub("\226\128\153", "'")) or text
end

function F.MenuItem(text, menu)
    for _, item in ipairs((menu or F.lastMenu or { items = {} }).items) do
        if item.text == text or F.Plain(item.text) == F.Plain(text) then
            return item
        end
        local found = F.MenuItem(text, item)
        if found then
            return found
        end
    end
end

-- The installed addons, all loaded, and Blizzard's own, loaded but for F.notLoaded.
F.addonList = { "KaLiQuest", "KaLiQuest_Probe", "Spoken" }
F.notLoaded = {}
C_AddOns = {
    GetAddOnMetadata = function(_, key)
        return key == "Version" and "0.1.0-test" or nil
    end,
    LoadAddOn = function()
        return true
    end,
    IsAddOnLoaded = function(name)
        if name:find("^Blizzard_") then
            return not F.notLoaded[name]
        end
        for _, installed in ipairs(F.addonList) do
            if installed == name then
                return true
            end
        end
        return false
    end,
    GetNumAddOns = function()
        return #F.addonList
    end,
    GetAddOnInfo = function(i)
        return F.addonList[i]
    end,
}
C_Map = {
    GetAreaInfo = function(id)
        return ({ [40] = "Marche de l'Ouest", [148] = "Sombrivage (Darkshore)", [1581] = "Les Mortemines",
            [3277] = "Goulet des Chanteguerres" })[id]
    end,
    -- Westfall's map, unless F.mapID says otherwise.
    GetBestMapForUnit = function()
        return F.mapID or 1436
    end,
    -- Its type is this build's, which the runner reads from UiMap.csv into F.MAP_TYPES (1415, the Eastern Kingdoms, a
    -- continent: 2; 1436, Westfall, a zone: 3).
    GetMapInfo = function(mapID)
        return { mapID = mapID, name = "Marche de l'Ouest", mapType = F.MAP_TYPES[mapID] }
    end,
    -- F.playerPos = { x, y } on map 1436, or nil as in an instance. Every map is 1000 yards across, on continent 0.
    GetPlayerMapPosition = function()
        return F.playerPos and CreateVector2D(F.playerPos[1], F.playerPos[2]) or nil
    end,
    GetWorldPosFromMapPos = function(_, pos)
        return 0, CreateVector2D(pos.x * 1000, pos.y * 1000)
    end,
}
function CreateVector2D(x, y)
    return { x = x, y = y, GetXY = function(self)
        return self.x, self.y
    end }
end
C_CVar = {
    GetCVarInfo = function(name)
        local value = F.cvars[name]
        if value then
            return value, "1", false, true, false, false, false
        end
    end,
}
-- Atlases the client has: all but F.missingAtlases, the lock and the quest log's with their real sizes.
F.missingAtlases = {}
C_Texture = {
    GetAtlasInfo = function(name)
        if F.missingAtlases[name] then
            return nil
        elseif name:find("questlog", 1, true) then
            return { file = 1, width = 16, height = 16 }
        elseif name == "communities-icon-lock" then
            return { file = 2, width = 14, height = 17, leftTexCoord = 0.1, rightTexCoord = 0.2, topTexCoord = 0.3, bottomTexCoord = 0.5 }
        end
        return { file = 3, width = 16, height = 16 }
    end,
}
C_QuestInfoSystem = {
    GetQuestClassification = function()
        return 0
    end,
    -- Rewards: F.rewardCurrencies[questID] = { { name = "..." } }, F.rewardSpells[questID] = { spellID = name }.
    GetQuestRewardCurrencies = function(id)
        return F.rewardCurrencies and F.rewardCurrencies[id] or {}
    end,
    GetQuestRewardSpells = function(id)
        local ids = {}
        for spellID in pairs(F.rewardSpells and F.rewardSpells[id] or {}) do
            ids[#ids + 1] = spellID
        end
        return ids
    end,
    GetQuestRewardSpellInfo = function(id, spellID)
        local name = F.rewardSpells and F.rewardSpells[id] and F.rewardSpells[id][spellID]
        return name and { name = name } or nil
    end,
}
-- F.rewardsPending[questID]: its rewards aren't loaded. F.loadRequests counts asks by quest.
F.loadRequests = {}
function HaveQuestRewardData(id)
    return not (F.rewardsPending and F.rewardsPending[id])
end
C_LFGList = {
    CanCreateQuestGroup = function(id)
        return F.findGroup ~= nil and F.findGroup[id] == true
    end,
}
function IsMouseButtonDown()
    return F.mouseDown ~= false
end
C_Minimap = {}
QuestUtil = {
    CanRemoveQuestWatch = function()
        return not F.npe
    end,
    IsShowingQuestDetails = function(id)
        return F.details == id
    end,
    OpenQuestDetails = function(id)
        F.details = id
    end,
    ShareQuest = function(id)
        F.shared = id
    end,
}

-- The quest log: F.entries holds rows as C_QuestLog.GetInfo returns them.
function F.SetLog(rows)
    F.entries = rows
end

local function indexOf(questID)
    for i, row in ipairs(F.entries) do
        if row.questID == questID and not row.isHeader then
            return i
        end
    end
end

local function watchCount()
    local n = 0
    for _ in pairs(F.watched) do
        n = n + 1
    end
    return n
end

C_QuestLog = {
    GetNumQuestLogEntries = function()
        local quests = 0
        for _, row in ipairs(F.entries) do
            if not row.isHeader then
                quests = quests + 1
            end
        end
        return #F.entries, quests
    end,
    GetInfo = function(index)
        return F.entries[index]
    end,
    GetLogIndexForQuestID = indexOf,
    IsComplete = function(id)
        local index = indexOf(id)
        return index ~= nil and F.entries[index].complete == true
    end,
    IsFailed = function()
        return false
    end,
    GetQuestWatchType = function(id)
        return F.watched[id] and 0 or nil
    end,
    -- A quest already watched isn't added again, and the game answers false for it, as for a full list (Ikar's saved
    -- log, 2026-11-12 to 16: thirteen times, each for a quest tracked seconds before and moved to another group). The
    -- "true" the fake invented there hid KaLi Quest's false alarm on the tracking limit.
    AddQuestWatch = function(id)
        if F.watched[id] or watchCount() >= 25 then
            return false
        end
        F.watched[id] = true
        F.Fire("QUEST_WATCH_LIST_CHANGED", id, true)
        return true
    end,
    RemoveQuestWatch = function(id)
        if F.watched[id] then
            F.watched[id] = nil
            F.Fire("QUEST_WATCH_LIST_CHANGED", id, false)
            return true
        end
        return false
    end,
    GetNumQuestWatches = watchCount,
    GetQuestIDForQuestWatchIndex = function(i)
        local ids = {}
        for id in pairs(F.watched) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        return ids[i]
    end,
    IsQuestFlaggedCompleted = function(id)
        return F.completed[id] == true
    end,
    IsRepeatableQuest = function(id)
        return F.repeatable[id] == true
    end,
    IsPushableQuest = function()
        return true
    end,
    GetQuestTagInfo = function(id)
        return F.tags and F.tags[id]
    end,
    GetQuestObjectives = function()
        return {}
    end,
    IsQuestTask = function()
        return false
    end,
    IsQuestBounty = function()
        return false
    end,
    IsEliteQuest = function()
        return false
    end,
    GetRequiredMoney = function(id)
        local index = indexOf(id)
        return index and F.entries[index].requiredMoney or 0
    end,
    GetTitleForQuestID = function(id)
        local index = indexOf(id)
        return index and F.entries[index].title
    end,
    -- F.pins: the map's quest pins, F.distances[questID]: squared yards to the quest.
    GetQuestsOnMap = function()
        return F.pins or { { questID = 12, x = 0.4, y = 0.6 } }
    end,
    GetDistanceSqToQuest = function(id)
        local d = F.distances and F.distances[id]
        if d then
            return d, true
        end
    end,
}

-- Objectives as the log rows give them, with numFulfilled from count.
C_QuestLog.GetQuestObjectives = function(id)
    local index = indexOf(id)
    local out = {}
    for i, o in ipairs(index and F.entries[index].objectives or {}) do
        out[i] = { text = o.text, finished = o.finished == true, numFulfilled = o.count or 0, type = o.type or "item" }
    end
    return out
end
C_QuestLog.GetNextWaypointText = function(id)
    return F.waypoint and F.waypoint[id]
end
C_QuestLog.IsOnMap = function()
    return false
end
-- F.timed[questID] = { total, elapsed } in seconds.
C_QuestLog.GetTimeAllowed = function(id)
    local t = F.timed and F.timed[id]
    if t then
        return t[1], t[2]
    end
end
C_QuestLog.IsAccountQuest = function()
    return false
end
C_QuestLog.RequestLoadQuestByID = function(id)
    F.loadRequests[id] = (F.loadRequests[id] or 0) + 1
end
function IsQuestSequenced(id)
    return F.sequenced ~= nil and F.sequenced[id] == true
end
function GetQuestProgressBarPercent()
    return 40
end
function GetQuestLogSpecialItemCooldown()
    return 0, 0, 1
end
function IsQuestLogSpecialItemInRange()
    return 1
end
function CooldownFrame_Set() end
C_Minimap.IsInsideQuestBlob = function(id)
    return F.blobs ~= nil and F.blobs[id] == true
end
QuestUtil.CanCreateQuestGroup = function(id)
    F.questUtilFindGroupCalls = (F.questUtilFindGroupCalls or 0) + 1
    return F.findGroup ~= nil and F.findGroup[id] == true
end
QuestUtil.QuestShowsItemByIndex = function(index, complete)
    local row = F.entries[index]
    return row ~= nil and row.item ~= nil and not complete
end
-- Popups: F.popups holds { questID, type } as the game's list.
F.popups = {}
function GetNumAutoQuestPopUps()
    return #F.popups
end
function GetAutoQuestPopUp(i)
    return F.popups[i].questID, F.popups[i].type
end
function RemoveAutoQuestPopUp(id)
    for i = #F.popups, 1, -1 do
        if F.popups[i].questID == id then
            table.remove(F.popups, i)
        end
    end
end
function ShowQuestOffer(id)
    F.shownOffer = id
end
function IsInInstance()
    return F.instanceType ~= nil and F.instanceType ~= "none", F.instanceType or "none"
end
function GetCursorPosition()
    return F.cursorX or 0, F.cursorY or 0
end
-- StaticPopup: records the last one shown, the two texts its own takes in; F.AcceptPopup() clicks its first button.
StaticPopupDialogs = {}
function StaticPopup_Show(which, text, text2, data)
    F.popup = { which = which, text = text, text2 = text2, data = data }
    return {}
end
function F.AcceptPopup()
    local p = F.popup
    F.popup = nil
    StaticPopupDialogs[p.which].OnAccept({}, p.data)
end
-- Font objects: a size of their own, or their parent's. A size of their own stays through a new parent, as in game,
-- where text set to 11 directly no longer grew with the font objects it was pointed at (Ikar, 2026-11-10).
function CreateFont(name)
    local font = CreateFrame("Font", name)
    function font:SetFontObject(parent)
        self.parentFont = parent
        self.sets = (self.sets or 0) + 1
    end
    function font:SetFont(file, size, flags)
        self.own = { file, size, flags }
    end
    function font:GetFont()
        if self.own then
            return unpack(self.own)
        end
        if self.parentFont then
            return self.parentFont:GetFont()
        end
        return "Fonts\\FRIZQT__.TTF", 12, ""
    end
    return font
end
-- The font object the shared options page names for its title (Shared/Page.lua), which every addon's API check looks
-- for; each addon's fake adds the ones its own code names.
CreateFont("GameFontHighlightHuge")
Settings.VarType.Number = "number"
Settings.VarType.String = "string"
-- A dropdown keeps its options' generator, so the smoke test can read the choices.
Settings.CreateDropdown = function(_, setting, options)
    setting.options = options
    control(setting)
end
Settings.CreateControlTextContainer = function()
    local container = { data = {} }
    function container:Add(value, label)
        self.data[#self.data + 1] = { value = value, label = label }
    end
    function container:GetData()
        return self.data
    end
    return container
end
-- A slider keeps its range on its setting, so the smoke test can compare it with what loading allows.
Settings.CreateSliderOptions = function(min, max, step)
    return { min = min, max = max, step = step, SetLabelFormatter = function(self, _, format)
        self.format = format
    end }
end
Settings.CreateSlider = function(_, setting, options)
    setting.sliderOptions = options
    control(setting)
end
Settings.RegisterProxySetting = function(category, variable, _, name, default, get, set)
    local setting = withDefault({ name = name }, default)
    function setting:SetValueChangedCallback(fn)
        self.callback = fn
    end
    function setting:GetValue()
        return get()
    end
    function setting:SetValue(value)
        set(value)
        if self.callback then
            self.callback(self, value)
        end
    end
    category.settings[variable] = setting
    return setting
end
