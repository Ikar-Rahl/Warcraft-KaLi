-- KaLi HUD's part of the fake game, after tools/lua/fakewow.lua: the frames the plate takes, as Edit Mode's systems
-- with a place on screen, Edit Mode's calls, the info bar's sources, and LibDataBroker as another addon loads it.
local F = FakeWoW

time = os.time

function CreateColor(r, g, b, a)
    local col = { r = r, g = g, b = b, a = a or 1 }
    function col:SetRGBA(nr, ng, nb, na)
        self.r, self.g, self.b, self.a = nr, ng, nb, na or 1
    end
    return col
end
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
function NORMAL_FONT_COLOR:WrapTextInColorCode(text)
    return "|cffffd100" .. text .. "|r"
end
function strtrim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end
function strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
        out[#out + 1] = part
    end
    return unpack(out)
end
function IsMetaKeyDown()
    return false
end
ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait or function() end
for _, name in ipairs({ "GameFontDisable", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormal", "GameFontNormalSmall",
    "GameFontDisableMed2", "GameFontHighlightLarge", "GameFontHighlightMedium", "GameFontDisableSmall",
    "GameFontNormalLarge" }) do
    if not _G[name] then
        CreateFont(name)
    end
end
-- The French client's own (BlizzardInterfaceResources' frFR.lua).
MASTER_VOLUME, MUSIC_VOLUME, FX_VOLUME, AMBIENCE_VOLUME, DIALOG_VOLUME = "Principal", "Musique", "Effets", "Ambiance", "Discussion"
TIMEMANAGER_AM, TIMEMANAGER_PM = "AM", "PM"
DEFAULTS = DEFAULTS or "Par défaut"
OPACITY = OPACITY or "Opacité"
RESET = RESET or "Réinitialiser"
ERROR_SLASH_EDITMODE_CANNOT_ENTER = ERROR_SLASH_EDITMODE_CANNOT_ENTER or "Impossible de passer en mode édition pour le moment"
-- Sounds played, their kits in order (F.sounds); SOUNDKIT's names the addon plays, as Blizzard's SoundKitConstants.lua.
F.sounds = {}
function PlaySound(kit)
    assert(type(kit) == "number", "PlaySound without a kit")
    F.sounds[#F.sounds + 1] = kit
    return true, #F.sounds
end
for name, kit in pairs({ IG_MAINMENU_OPTION_CHECKBOX_OFF = 857, IG_QUEST_LOG_OPEN = 844, IG_QUEST_LOG_CLOSE = 845,
    IG_ABILITY_PAGE_TURN = 836, HOUSING_PRIMARY_SUB_MENU_BUTTON_TOGGLE = 304888, IG_CHARACTER_INFO_TAB = 841,
    IG_MAINMENU_OPTION = 852, UI_MAP_WAYPOINT_BUTTON_CLICK_ON = 170266, UI_MAP_WAYPOINT_BUTTON_CLICK_OFF = 171360,
    GUILD_BANK_OPEN_BAG = 12206 }) do
    SOUNDKIT[name] = kit
end

-- A frame's place, in its own units as GetRect gives it; a point to UIParent's bottom left moves it, and what is
-- attached to it, as in game.
local function geometry(frame, left, bottom, width, height)
    frame.left, frame.top, frame.width, frame.height = left, bottom + height, width, height
    function frame:GetRect()
        if self.shown == false then
            return nil
        end
        return self.left, self.top - self.height, self.width, self.height
    end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point = { point, relativeTo, relativePoint, x, y }
        if point == "BOTTOMLEFT" and relativeTo == UIParent and relativePoint == "BOTTOMLEFT" then
            local dx, dy = x - self.left, y + self.height - self.top
            self.left, self.top = x, y + self.height
            for _, part in ipairs(self.attached or {}) do
                part.left, part.top = part.left + dx, part.top + dy
            end
        end
    end
    return frame
end
F.Geometry = geometry

-- Edit Mode's systems: each tells the manager when it moves, as EditModeSystemMixin does. F.positionChanges lists the
-- frames Edit Mode was told about, in order.
F.positionChanges, F.editMode, F.layoutType = {}, false, 1
local function system(name, id, label, left, bottom, width, height)
    local f = _G[name] or CreateFrame("Frame", name, UIParent)
    geometry(f, left, bottom, width, height)
    f.system, f.systemIndex = id, 1
    f.isManagedFrame = true
    function f:OnSystemPositionChange()
        EditModeManagerFrame:OnSystemPositionChange(self)
    end
    function f:GetSystemName()
        return label
    end
    function f:IsInDefaultPosition()
        return not self.broken
    end
    function f:BreakFromFrameManager()
        self.broken = true
    end
    function f:ClearFrameSnap() end
    return f
end
F.System = system
-- A real screen and layout, as the probe found them in game (2026-11-13, build 70938), a shaman's: the stance bar
-- hidden, no pet out, the totem bar shown, the bags upright, the chat up in the top right corner.
UIParent:SetSize(2100.5, 1181.5)
system("MainActionBar", 0, "Barre d'action 1", 544.6, 49, 393.4, 31.5)
MainActionBar.ActionBarPageNumber = geometry(CreateFrame("Frame", nil, MainActionBar), 523.6, 54, 17, 24)
MainActionBar.attached = { MainActionBar.ActionBarPageNumber }
system("MultiBarBottomLeft", 0, "Barre d'action 2", 544.6, 94.5, 393.4, 31.5)
system("MultiBarBottomRight", 0, "Barre d'action 3", 1156.6, 136.5, 393.4, 31.5)
system("MultiBarRight", 0, "Barre d'action 4", 1162.6, 49, 393.4, 31.5)
system("MultiBarLeft", 0, "Barre d'action 5", 1582, 32, 45, 562).shown = false
system("StanceBar", 0, "Barre de postures", 753.2, 140, 190.8, 18).shown = false
system("PetActionBar", 0, "Barre du familier", 0, 1151.5, 318, 30).shown = false
system("MultiCastActionBarFrame", 25, "Barre de totems", 555.2, 140, 184, 30.4)
system("MicroMenuContainer", 13, "Menu", 1162.6, 94.5, 211.4, 28)
system("BagsBar", 14, "Sacs", 1391.3, 98.3, 33.8, 236.2)
-- BagsBar's buttons: backpack at the bottom, 4 extra slots stacked above it, managed by MainMenuBarBagManager.
MainMenuBarBackpackButton = geometry(CreateFrame("Button", "MainMenuBarBackpackButton", BagsBar), 1391.3, 98.3, 33.8, 33.8)
F.bagSlots = { MainMenuBarBackpackButton }
for i = 1, 4 do
    F.bagSlots[#F.bagSlots + 1] = geometry(CreateFrame("Button", "CharacterBag" .. (i - 1) .. "Slot", BagsBar),
        1391.3, 98.3 + i * 35.8, 33.8, 33.8)
end
BagsBar.attached = { unpack(F.bagSlots) }
function BagsBar:IsHorizontal() return false end
function BagsBar:IsDirectionUp() return true end
function BagsBar:GetBagButtonAnchorPoints() return "BOTTOM", "TOP", 0, 2 end
function BagsBar:Layout() end
F.bagBarExpanded = false
MainMenuBarBagManager = {
    ShouldBarExpand = function() return F.bagBarExpanded end,
    ToggleExpandBar = function()
        F.bagBarExpanded = not F.bagBarExpanded
        F.TriggerRegistry("MainMenuBarManager.OnExpandChanged")
    end,
    EnumerateBagButtons = function()
        return ipairs(F.bagSlots)
    end,
}

system("ChatFrame1", 8, "Discussion", 1671.5, 958.5, 419, 189)
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox", UIParent)
-- the game's count of chat windows (Blizzard_ChatFrameBase): each may have an edit box of its own
NUM_CHAT_WINDOWS = 10
system("DamageMeter", 23, "Compteur de dégâts", 1715.5, 32, 376, 146)
system("MinimapCluster", 2, "Minicarte", 936.3, 21.5, 208, 207.1)
MinimapCluster.MinimapContainer = CreateFrame("Frame", nil, MinimapCluster)
Minimap = geometry(CreateFrame("Frame", "Minimap", MinimapCluster.MinimapContainer), 981, 40.8, 138.6, 138.6)
-- MinimapCluster's strata (Minimap.xml), its map's too
for _, f in ipairs({ MinimapCluster, MinimapCluster.MinimapContainer, Minimap }) do
    function f:GetFrameStrata()
        return "LOW"
    end
end
function Minimap:GetRect()
    if self.shown == false then
        return nil
    end
    local s = self:GetEffectiveScale()
    local cx, cy = self.left + self.width / 2, self.top - self.height / 2
    local w, h = self.width * s, self.height * s
    return (cx - w / 2) / s, (cy - h / 2) / s, self.width, self.height
end
Minimap.zoom = 0
function Minimap:GetZoom() return self.zoom end
function Minimap:SetZoom(z) self.zoom = z end
function Minimap:SetMaskTexture(m) self.mask = m end
Minimap.ZoomIn = CreateFrame("Button", nil, Minimap)
Minimap.ZoomIn:Hide()
Minimap.ZoomOut = CreateFrame("Button", nil, Minimap)
Minimap.ZoomOut:Hide()
Minimap.ZoomHitArea = CreateFrame("Frame", nil, Minimap)
MinimapCompassTexture = CreateFrame("Texture", "MinimapCompassTexture")
MinimapCompassTextureUnderlay = CreateFrame("Texture", "MinimapCompassTextureUnderlay")
MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
MinimapCluster.Tracking = CreateFrame("Frame", nil, MinimapCluster)
MinimapCluster.Tracking.Background = MinimapCluster.Tracking:CreateTexture()
MinimapCluster.Tracking.Button = CreateFrame("Button", nil, MinimapCluster.Tracking)
MinimapCluster.IndicatorFrame = CreateFrame("Frame", nil, MinimapCluster)
MinimapCluster.IndicatorFrame.MailFrame = CreateFrame("Frame", nil, MinimapCluster.IndicatorFrame)
MinimapCluster.IndicatorFrame.MailFrame:Show()
MinimapCluster.DielFrame = CreateFrame("Frame", nil, MinimapCluster)
GameTimeFrame = CreateFrame("Button", "GameTimeFrame", MinimapCluster)
AddonCompartmentFrame = CreateFrame("Button", "AddonCompartmentFrame", MinimapCluster)
TimeManagerClockButton = CreateFrame("Button", "TimeManagerClockButton", MinimapCluster)
-- Where and how big Blizzard_Minimap's XML has them (the tracking frame a size of its own, to see it given back).
MinimapCluster.Tracking:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 9, -24)
MinimapCluster.Tracking:SetSize(26, 26)
MinimapCluster.Tracking.Button:SetPoint("CENTER", MinimapCluster.Tracking, "CENTER", 0, 0)
MinimapCluster.IndicatorFrame:SetPoint("BOTTOMLEFT", MinimapCluster.ZoneTextButton, "TOPLEFT", 0, 0)
MinimapCluster.DielFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
GameTimeFrame:SetPoint("TOPLEFT", MinimapCluster.ZoneTextButton, "TOPRIGHT", -4, 0)
GameTimeFrame:SetSize(23, 23)
AddonCompartmentFrame:SetPoint("TOPLEFT", GameTimeFrame, "BOTTOMLEFT", -1, 1)
AddonCompartmentFrame:SetSize(23, 22)
-- The widgets' own scripts as Blizzard_Minimap has them. The tracking button and the compartment are DropdownButtons:
-- OnLoad_Intrinsic registers the left button's press and release only, and a press opens or closes the menu.
local function dropdown(button, title)
    button.mouseButtons = { "LeftButtonDown", "LeftButtonUp" }
    function button:RegisterForMouse(...)
        self.mouseButtons = { ... }
    end
    function button:IsMenuOpen()
        return self.menuOpen == true
    end
    function button:SetMenuOpen(open)
        self.menuOpen = open == true
    end
    button:SetScript("OnMouseDown", function(self)
        self:SetMenuOpen(not self:IsMenuOpen())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(title)
        GameTooltip:Show()
    end)
end
dropdown(MinimapCluster.Tracking.Button, "Suivi")
dropdown(AddonCompartmentFrame, "Addons")
-- The calendar button: any button's release toggles the calendar; its tooltip is rebuilt every frame while it owns it.
GameTimeFrame:RegisterForClicks("AnyUp")
GameTimeFrame:SetScript("OnClick", function()
    ToggleCalendar()
end)
function GameTimeFrame:Click(button)
    F.RunScript(self, "OnClick", button)
end
GameTimeFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
end)
GameTimeFrame:SetScript("OnUpdate", function(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Cliquez pour afficher le calendrier.")
        GameTooltip:Show()
    end
end)
function GameTooltip:IsOwned(frame)
    return self.owner == frame
end
-- Both sides of a double line, as two lines.
function GameTooltip:AddDoubleLine(left, right)
    F.tooltip.lines[#F.tooltip.lines + 1] = left
    F.tooltip.lines[#F.tooltip.lines + 1] = right
end
function GameTooltip:ClearLines()
    F.tooltip.lines = {}
end
-- The game's own tooltips a stat card's row shows on hover (UI/Hub/Infos/StatCard.lua), each recorded as a line
-- "<kind>:<what>"; nothing for an empty slot or an aura instance not a number, as the game shows nothing then.
function GameTooltip:SetInventoryItem(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        F.tooltip.lines[#F.tooltip.lines + 1] = "item:" .. tostring(slot)
    end
    return link ~= nil
end
function GameTooltip:SetUnitAuraByAuraInstanceID(_, instance)
    if type(instance) == "number" then
        F.tooltip.lines[#F.tooltip.lines + 1] = "aura:" .. instance
    end
end
function GameTooltip:SetTraitEntry(entry, rank)
    if type(entry) == "number" then
        F.tooltip.lines[#F.tooltip.lines + 1] = "trait:" .. entry .. ":" .. tostring(rank)
    end
end
function GameTooltip:SetSpellByID(spell)
    F.tooltip.lines[#F.tooltip.lines + 1] = "spell:" .. tostring(spell)
end
function GameTooltip:NumLines()
    return #F.tooltip.lines
end
-- Blizzard_SharedXML's GameTooltip.lua helpers.
function GameTooltip_SetTitle(tooltip, text)
    tooltip:SetText(text, 1, 1, 1, 1, true)
end
function GameTooltip_AddInstructionLine(tooltip, text)
    tooltip:AddLine(text, 0.1, 1, 0.1, true)
end

-- A mouse click as the game sends it: the press and the release to OnMouseDown and OnMouseUp, for a Button that called
-- RegisterForMouse only the ones it took, then OnClick if RegisterForClicks took the release; then a frame passes.
local function takes(list, button, suffix)
    for _, kind in ipairs(list) do
        if kind == button .. suffix or kind == "Any" .. suffix then
            return true
        end
    end
    return false
end
function F.Press(frame, button)
    local mouse = frame.mouseButtons or { "AnyDown", "AnyUp" }
    if takes(mouse, button, "Down") then
        F.RunScript(frame, "OnMouseDown", button)
    end
    if takes(mouse, button, "Up") then
        F.RunScript(frame, "OnMouseUp", button)
    end
    if frame.clicks and takes(frame.clicks, button, "Up") then
        F.RunScript(frame, "OnClick", button)
    end
    F.RunTimers()
end
function MinimapCluster:UpdateMinimapConfig() end
-- Edit Mode's "header underneath" setting, F.headerUnderneath; F.header is what the cluster was last told.
F.headerUnderneath, F.headerUpdates = false, 0
function MinimapCluster:SetHeaderUnderneath(underneath)
    F.header = underneath
end
function MinimapCluster:UpdateSystemSettingHeaderUnderneath()
    F.headerUpdates = F.headerUpdates + 1
    self:SetHeaderUnderneath(F.headerUnderneath)
end
function MinimapCluster:SetEditModeScale(scale)
    self.MinimapContainer:SetScale(scale)
end
MinimapCluster.attached = { Minimap }
-- The frames under the pointer, topmost first: the game's world unless a test says otherwise.
WorldFrame = CreateFrame("Frame", "WorldFrame")
F.mouseFoci = { WorldFrame }
function GetMouseFoci()
    return F.mouseFoci
end

StatusTrackingBarManager = CreateFrame("Frame", "StatusTrackingBarManager", UIParent)
-- Its first bar's holder as StatusTrackingBar.xml and ExpBar.xml make it: the bar taking the mouse, its rested tick a
-- button with a tooltip of its own, and Edit Mode's box, which ignores its parent's alpha (ignoreParentAlpha).
MainStatusTrackingBarContainer = CreateFrame("Frame", "MainStatusTrackingBarContainer", StatusTrackingBarManager)
local trackingBar = CreateFrame("StatusBar", nil, MainStatusTrackingBarContainer)
trackingBar:EnableMouse(true)
trackingBar.ExhaustionTick = CreateFrame("Button", nil, trackingBar)
MainStatusTrackingBarContainer.bars = { trackingBar }
MainStatusTrackingBarContainer.Selection = CreateFrame("Frame", nil, MainStatusTrackingBarContainer)
MainStatusTrackingBarContainer.Selection:EnableMouse(true)
function MainStatusTrackingBarContainer.Selection:IsIgnoringParentAlpha()
    return true
end
FlareUI_XPBar = CreateFrame("Frame", "FlareUI_XPBar", UIParent)
-- The chat as FlareUI shows it (Modules/Chat.lua): its own skin around the text, 24 more above for the tabs; Blizzard's
-- side buttons hidden and the tab dock parked at -10000, as Ikar's probe found it (2026-11-13).
GeneralDockManager = geometry(CreateFrame("Frame", "GeneralDockManager", UIParent), -10000, -10000, 1, 1)
ChatFrame1.buttonFrame = geometry(CreateFrame("Frame", nil, ChatFrame1), 1641.5, 958.5, 28, 189)
ChatFrame1.buttonFrame.shown = false
ChatFrame1.FlareUI_Skin = geometry(CreateFrame("Frame", nil, ChatFrame1), 1664.5, 951.5, 433, 227)
-- A second tab docked with the chat, where it is: Blizzard's dock shows the window whose tab is picked, hides the rest.
ChatFrame2 = geometry(CreateFrame("Frame", "ChatFrame2", UIParent), 1671.5, 958.5, 419, 189)
ChatFrame2.FlareUI_Skin = geometry(CreateFrame("Frame", nil, ChatFrame2), 1664.5, 951.5, 433, 227)
ChatFrame2:Hide()
ChatFrame1.attached = { ChatFrame1.FlareUI_Skin, ChatFrame1.buttonFrame, ChatFrame2, ChatFrame2.FlareUI_Skin }
GENERAL_CHAT_DOCK = GeneralDockManager
GENERAL_CHAT_DOCK.primary, GENERAL_CHAT_DOCK.selected = ChatFrame1, ChatFrame1
GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { ChatFrame1, ChatFrame2 }
function F.PickChatTab(frame)
    GENERAL_CHAT_DOCK.selected = frame
    for _, f in ipairs(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) do
        f:SetShown(f == frame)
    end
end
-- The damage meter's window, with FlareUI's skin a little outside it (Modules/DamageMeter.lua).
DamageMeterSessionWindow1 = geometry(CreateFrame("Frame", "DamageMeterSessionWindow1", DamageMeter), 1715.5, 32, 376, 146)
DamageMeterSessionWindow1.FlareUI_DMSkin = geometry(CreateFrame("Frame", nil, DamageMeterSessionWindow1), 1711.5, 28, 384, 154)
DamageMeter.attached = { DamageMeterSessionWindow1, DamageMeterSessionWindow1.FlareUI_DMSkin }
-- FlareUI's skins are BackdropTemplate frames: their frame and background in Backdrop.lua's pieces, its tabs on them.
for _, skin in ipairs({ ChatFrame1.FlareUI_Skin, DamageMeterSessionWindow1.FlareUI_DMSkin }) do
    skin.Center, skin.TopEdge = skin:CreateTexture(), skin:CreateTexture()
end
-- FlareUI's chat (Modules/Chat.lua, StyleChatFrame) puts its own alpha back after anyone else's SetAlpha; the game's
-- SetAlphaFromBoolean, which no Lua hook sees, sets it all the same.
local function setAlphaFromBoolean(self, value, ifTrue, ifFalse)
    self.alpha = value and ifTrue or ifFalse
end
for _, f in ipairs({ ChatFrame1, ChatFrame2, DamageMeter, DamageMeterSessionWindow1 }) do
    f.SetAlphaFromBoolean = setAlphaFromBoolean
end
hooksecurefunc(ChatFrame1, "SetAlpha", function(self, alpha)
    if not self.FlareUI_IgnoreAlpha and alpha ~= 1 then
        self.FlareUI_IgnoreAlpha = true
        self:SetAlpha(1)
        self.FlareUI_IgnoreAlpha = false
    end
end)

Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Override = 3 }
function EditModeManagerFrame:IsEditModeActive()
    return F.editMode
end
function EditModeManagerFrame:OnSystemPositionChange(frame)
    F.positionChanges[#F.positionChanges + 1] = frame:GetName()
end
function EditModeManagerFrame:OnSystemSettingChange()
    F.settingChanges = (F.settingChanges or 0) + 1
end
function EditModeManagerFrame:GetActiveLayoutInfo()
    return { layoutName = "Principale", layoutType = F.layoutType }
end
function F.EnterEditMode()
    F.editMode = true
    F.TriggerRegistry("EditMode.Enter")
end
function F.ExitEditMode()
    F.editMode = false
    F.TriggerRegistry("EditMode.Exit")
end

-- The info bar's and the status bars' sources.
F.xp = { cur = 4120, max = 9800, rested = 2350 }
function UnitXP()
    return F.xp.cur
end
function UnitXPMax()
    return F.xp.max
end
function GetXPExhaustion()
    return F.xp.rested
end
-- The rest's state as the game names it: rested while there is rest left, twice the creatures' experience then.
function GetRestState()
    if (F.xp.rested or 0) > 0 then
        return 1, "Reposé", 2
    end
    return 2, "Normal", 1
end
function GetMaxLevelForPlayerExpansion()
    return F.maxLevel or 60
end
F.faction = { name = "Darnassus", reaction = 6, currentReactionThreshold = 9000, nextReactionThreshold = 21000, currentStanding = 15480, factionID = 69 }
C_Reputation = {
    GetWatchedFactionData = function()
        return F.faction
    end,
}
FACTION_BAR_COLORS = { [4] = { r = 0.9, g = 0.7, b = 0 }, [6] = { r = 0, g = 0.6, b = 0.1 }, [8] = { r = 0, g = 0.6, b = 0.6 } }
FACTION_STANDING_LABEL4, FACTION_STANDING_LABEL6, FACTION_STANDING_LABEL8 = "Neutre", "Honoré", "Exalté"
MAX_REPUTATION_REACTION = 8
-- The reputation pane's list, as C_Reputation gives it by index: a header with no standing of its own, the watched
-- faction, one at the last standing, one barely met; a faction under a header folded in the pane isn't listed
-- (F.factions is what the pane lists now).
F.faction.description, F.faction.isHeader, F.faction.isWatched = "Les elfes de la nuit de Teldrassil.", false, true
F.factions = {
    { factionID = 469, name = "Alliance", description = "", reaction = 4, currentReactionThreshold = 0, nextReactionThreshold = 3000,
        currentStanding = 0, isHeader = true, isHeaderWithRep = false, isWatched = false },
    F.faction,
    { factionID = 72, name = "Hurlevent", description = "La capitale des humains.", reaction = 8, currentReactionThreshold = 42000,
        nextReactionThreshold = 42000, currentStanding = 42999, isHeader = false, isWatched = false },
    { factionID = 529, name = "Aube d'argent", description = "", reaction = 4, currentReactionThreshold = 0,
        nextReactionThreshold = 3000, currentStanding = 750, isHeader = false, isWatched = false },
}
C_Reputation.GetNumFactions = function()
    return #F.factions
end
C_Reputation.GetFactionDataByIndex = function(index)
    return F.factions[index]
end
-- The watched faction: the one of that id, none for 0; GetWatchedFactionData follows.
F.watched = {}
C_Reputation.SetWatchedFactionByID = function(id)
    F.watched[#F.watched + 1] = id
    local now
    for _, f in ipairs(F.factions) do
        f.isWatched = f.factionID == id
        now = f.isWatched and f or now
    end
    F.faction = now or { name = "" }
end
-- No paragon, renown nor friendship faction watched; honour counts while F.watchHonor says so.
C_Reputation.IsFactionParagonForCurrentPlayer = function()
    return false
end
C_Reputation.GetFactionParagonInfo = function() end
C_Reputation.IsMajorFaction = function()
    return false
end
C_MajorFactions = { GetMajorFactionData = function() end }
C_GossipInfo = C_GossipInfo or {}
C_GossipInfo.GetFriendshipReputation = function()
    return { friendshipFactionID = 0 }
end
GameRulesUtil = {
    CanShowExperienceBar = function()
        return UnitLevel("player") < GetMaxLevelForPlayerExpansion()
    end,
}
function GetText(key)
    return _G[key]
end
function UnitSex()
    return 2
end
function IsWatchingHonorAsXP()
    return F.watchHonor == true
end
function IsInActiveWorldPVP()
    return false
end
function UnitHonorLevel()
    return 12
end
PLAYER_FACTION_COLORS = { [0] = { r = 0.9, g = 0.05, b = 0.07 }, [1] = { r = 0.29, g = 0.33, b = 0.91 } }
HONOR, REPUTATION, HONOR_LEVEL_LABEL = "Honneur", "Réputation", "Niveau d'honneur %d"
function UnitHonor()
    return 1420
end
function UnitHonorMax()
    return 4750
end
function GetMinimapZoneText()
    return F.subZone or GetZoneText()
end
function GetSubZoneText()
    return F.subZone or ""
end
-- The instance the player is in, F.instance = { name, type, the instance's map }; else the open world's continent.
function GetInstanceInfo()
    local i = F.instance
    if i then
        return i[1], i[2], 1, "Normal", 5, 0, false, i[3], 5, nil
    end
    return "Royaumes de l'Est", "none", 0, "", 0, 0, false, 0, 0, nil
end
function GetGameTime()
    return 21, 7
end
-- Bags: { slots, free, family }; the third is a profession bag, which the count leaves out.
F.bags = { [0] = { 16, 4 }, [1] = { 12, 2 }, [2] = { 12, 0, 8 } }
C_Container = {
    GetContainerNumSlots = function(bag)
        return F.bags[bag] and F.bags[bag][1] or 0
    end,
    GetContainerNumFreeSlots = function(bag)
        local b = F.bags[bag]
        if b then
            return b[2], b[3] or 0
        end
        return 0, 0
    end,
}
F.durability = { [1] = { 50, 60 }, [5] = { 30, 100 } }
function GetInventoryItemDurability(slot)
    local d = F.durability[slot]
    if d then
        return d[1], d[2]
    end
end
-- Each slot's item link as the game writes one: its item string, "item:<id>:<enchantment>:..." (F.itemIDs and
-- F.enchants by slot; 1000 and the slot, and none, by default), and its name, "[Objet <slot>]".
F.itemIDs, F.enchants = {}, {}
function GetInventoryItemLink(_, slot)
    return "|cffffffff|Hitem:" .. (F.itemIDs[slot] or 1000 + slot) .. ":" .. (F.enchants[slot] or "")
        .. "::::::::60:::::|h[Objet " .. slot .. "]|h|r"
end
-- An item's tooltip data: its repair cost, its permanent enchantment's line as the game words it (F.enchantLines by
-- slot, type 15: Enum.TooltipDataLineType.ItemEnchantmentPermanent).
F.enchantLines = {}
-- Its other lines, as the game words them (F.itemLines by slot, a list of texts, type 0: a fishing rod's skill, a
-- shield's block); an item's not worn by its link (F.linkLines: one tried on a card kept open).
F.itemLines, F.linkLines = {}, {}
C_TooltipInfo = {
    GetHyperlink = function(link)
        local lines = {}
        for _, text in ipairs(F.linkLines[link] or {}) do
            lines[#lines + 1] = { type = 0, leftText = text }
        end
        return { lines = lines }
    end,
    GetInventoryItem = function(_, slot)
        local lines = {}
        if F.enchantLines[slot] then
            lines[1] = { type = 15, leftText = F.enchantLines[slot] }
        end
        for _, text in ipairs(F.itemLines[slot] or {}) do
            lines[#lines + 1] = { type = 0, leftText = text }
        end
        return { repairCost = F.durability[slot] and 120 or 0, lines = lines }
    end,
    -- A talent's tooltip at a rank, as the game words it (F.talents' says: its text, or its texts by rank), after its
    -- name and its « Rang 3/3 »; nothing for one without.
    GetTraitEntry = function(entry, rank)
        local t = F.talents[entry - 100]
        local says = t and (type(t.says) == "table" and t.says[rank] or t.says)
        return says and { lines = { { leftText = "Talent" }, { leftText = "Rang " .. rank .. "/" .. t.ranks },
            { leftText = says } } } or nil
    end,
    -- A buff's tooltip, found by its auraInstanceID among F.auras' HELPFUL: its name, then its text as the game words
    -- it (its says, its own lines in one, as « Avantages du camp »'s in game, 2026-11-22), then its time left; nothing
    -- for one without.
    GetUnitBuffByAuraInstanceID = function(_, instance)
        for _, aura in ipairs(F.auras.HELPFUL) do
            if aura.auraInstanceID == instance and aura.says then
                return { lines = { { leftText = aura.name }, { leftText = aura.says },
                    { leftText = "60 |4minute restante:minutes restantes;" } } }
            end
        end
    end,
}
-- An item's skill line as Forever's French client words it (GlobalStrings: a no-break space before the colon).
TOOLTIP_ITEM_STAT_SKILL_FISHING_INCREASE = "Équiper\194\160: pêche augmentée de %1$d."
TOOLTIP_ITEM_STAT_SKILL_FISHING_DECREASE = "Équiper\194\160: pêche réduite de %1$d."
-- A shield's block, as its tooltip writes it.
SHIELD_BLOCK_TEMPLATE = "Bloquer\194\160: %s"
function GetNetStats()
    return 0, 0, 42, 54
end
function GetFramerate()
    return 117.6
end
function GetUnitSpeed()
    if F.speedSecret then
        return F.SECRET, F.SECRET, F.SECRET, F.SECRET
    end
    return F.speed or 7, 7, 0, 4.72
end
function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage(i)
    return i * 1024
end
function UnitName()
    return "Ikar"
end
function GetRealmName()
    return "Forever"
end
RAID_CLASS_COLORS = { WARRIOR = {} }
function RAID_CLASS_COLORS.WARRIOR:WrapTextInColorCode(text)
    return "|cffc79c6e" .. text .. "|r"
end
F.cvars.Sound_MasterVolume, F.cvars.Sound_MusicVolume, F.cvars.Sound_SFXVolume = "0.8", "0.5", "1"
F.cvars.Sound_AmbienceVolume, F.cvars.Sound_DialogVolume, F.cvars.Sound_EnableAllSound = "0.6", "1", "1"
F.cvars.rotateMinimap = "0"
-- Forever's coordinates under the map, on as the game sets them first
F.cvars.minimapShowPlayerCoords = "1"
-- The game's clock: twelve hours, the realm's time, until its own window's boxes say otherwise.
F.cvars.timeMgrUseMilitaryTime, F.cvars.timeMgrUseLocalTime = "0", "0"
F.toggled = {}
function ToggleAllBags()
    F.toggled.bags = (F.toggled.bags or 0) + 1
end
function ToggleWorldMap()
    F.toggled.map = (F.toggled.map or 0) + 1
end
function ToggleCharacter(tab)
    F.toggled.character = tab
end
function ToggleCalendar()
    F.toggled.calendar = (F.toggled.calendar or 0) + 1
end
function HasNewMail()
    return true
end
C_PvP = C_PvP or {
    GetZonePVPInfo = function()
        return "friendly"
    end,
}
FACTION_CONTROLLED_TERRITORY, CONTESTED_TERRITORY = "(Territoire %s)", "(Territoire contesté)"
FACTION_ALLIANCE, FACTION_HORDE = "Alliance", "Horde"
-- The key bindings: F.bindings[action] = key; F.overrides[key] = an addon's override's action on it.
F.bindings, F.overrides = { TOGGLEWORLDMAP = "M" }, {}
function GetBindingKey(action)
    return F.bindings[action]
end
function GetBindingAction(key, checkOverride)
    if checkOverride and F.overrides[key] then
        return F.overrides[key]
    end
    for action, k in pairs(F.bindings) do
        if k == key then
            return action
        end
    end
    return ""
end
C_PvP.IsActiveBattlefield = function()
    return false
end
PixelUtil = PixelUtil or {
    GetPixelToUIUnitFactor = function()
        return 0.6
    end,
    -- the size asked, which the game rounds to whole pixels
    SetWidth = function(region, width)
        region:SetWidth(width)
    end,
    SetHeight = function(region, height)
        region:SetHeight(height)
    end,
}
-- The colour picker as Blizzard_ColorPicker sets it up; F.PickColor turns its wheel, the info's cancelFunc closes it
-- cancelled.
ColorPickerFrame = ColorPickerFrame or CreateFrame("Frame", "ColorPickerFrame")
-- Mask textures, which the family's fake doesn't make: a texture of their own kind, recorded with what they mask.
-- Textures are the frame's regions, with their draw layer and file; a fixed strata or level ignores being set, as in game.
local createFrame = CreateFrame
function CreateFrame(...)
    local frame = createFrame(...)
    function frame:SetFrameStrata(strata)
        if not self.fixedStrata then
            self.strata = strata
        end
    end
    function frame:GetFrameStrata()
        return self.strata or "MEDIUM"
    end
    local setLevel = frame.SetFrameLevel
    function frame:SetFrameLevel(level)
        if not self.fixedLevel then
            setLevel(self, level)
        end
    end
    function frame:SetFixedFrameStrata(fixed)
        self.fixedStrata = fixed and true or nil
    end
    function frame:HasFixedFrameStrata()
        return self.fixedStrata == true
    end
    function frame:SetFixedFrameLevel(fixed)
        self.fixedLevel = fixed and true or nil
    end
    function frame:HasFixedFrameLevel()
        return self.fixedLevel == true
    end
    -- a frame ignoring its parent's scale is drawn at its own alone, as in game
    function frame:SetIgnoreParentScale(ignore)
        self.ignoreParentScale = ignore and true or nil
    end
    function frame:IsIgnoringParentScale()
        return self.ignoreParentScale == true
    end
    local effectiveScale = frame.GetEffectiveScale
    function frame:GetEffectiveScale()
        if self.ignoreParentScale then
            return self.scale or 1
        end
        return effectiveScale(self)
    end
    function frame:RegisterForDrag(...)
        self.drags = { ... }
    end
    function frame:SetStatusBarColor(r, g, b, a)
        self.statusBarColor = { r, g, b, a }
    end
    function frame:SetReverseFill(reverse)
        self.reverseFill = reverse and true or false
    end
    function frame:GetRegions()
        return unpack(self.fakeRegions or {})
    end
    function frame:CreateMaskTexture()
        return createFrame("MaskTexture")
    end
    function frame:CreateTexture(_, layer)
        local t = createFrame("Texture")
        t.layer = layer or "ARTWORK"
        self.fakeRegions = self.fakeRegions or {}
        self.fakeRegions[#self.fakeRegions + 1] = t
        function t:GetDrawLayer()
            return self.layer
        end
        function t:SetTexture(file, _, _, filter)
            self.file, self.filter = file, filter
        end
        function t:GetTextureFilePath()
            return self.file
        end
        function t:AddMaskTexture(mask)
            self.masks = self.masks or {}
            self.masks[mask] = true
        end
        function t:RemoveMaskTexture(mask)
            if self.masks then
                self.masks[mask] = nil
            end
        end
        function t:SetVertexOffset(index, x, y)
            self.vertexOffsets = self.vertexOffsets or {}
            self.vertexOffsets[index] = { x, y }
        end
        function t:SetVertexColor(r, g, b, a)
            self.vertexColor = { r, g, b, a }
        end
        function t:SetGradient(orientation, minColor, maxColor)
            self.gradient = { orientation, minColor, maxColor }
        end
        return t
    end
    return frame
end
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self.info, self.rgb = info, { info.r, info.g, info.b }
    self:Show()
end
function ColorPickerFrame:GetColorRGB()
    return unpack(self.rgb)
end
function F.PickColor(r, g, b)
    ColorPickerFrame.rgb = { r, g, b }
    ColorPickerFrame.info.swatchFunc()
end

-- LibStub and LibDataBroker-1.1 as another addon loads them: an object's fields moved into the library's storage, the
-- object a proxy whose every change fires LibDataBroker_AttributeChanged; callbacks keyed by who registered, as
-- CallbackHandler's. Two other addons' objects: a launcher with an icon, a data source without.
F.ldb = { objects = {}, callbacks = {}, storage = {}, names = {} }
local proxy = {
    __index = function(self, key)
        return F.ldb.storage[self][key]
    end,
    __newindex = function(self, key, value)
        local storage = F.ldb.storage[self]
        if storage[key] ~= value then
            storage[key] = value
            F.ldb:Fire("LibDataBroker_AttributeChanged", F.ldb.names[self], key, value, self)
        end
    end,
}
function F.ldb:NewDataObject(name, object)
    if self.objects[name] then
        return nil
    end
    object = object or {}
    local storage = {}
    for key, value in pairs(object) do
        storage[key] = value
    end
    for key in pairs(storage) do
        object[key] = nil
    end
    self.storage[object], self.names[object] = storage, name
    setmetatable(object, proxy)
    self.objects[name] = object
    self:Fire("LibDataBroker_DataObjectCreated", name, object)
    return object
end
function F.ldb:GetDataObjectByName(name)
    return self.objects[name]
end
function F.ldb:DataObjectIterator()
    return pairs(self.objects)
end
function F.ldb.RegisterCallback(target, event, fn)
    F.Handed(fn)
    F.ldb.callbacks[event] = F.ldb.callbacks[event] or {}
    F.ldb.callbacks[event][target] = fn
end
function F.ldb:Fire(event, ...)
    for _, fn in pairs(self.callbacks[event] or {}) do
        fn(event, ...)
    end
end
LibStub = setmetatable({ libs = { ["LibDataBroker-1.1"] = F.ldb } }, {
    __call = function(self, major, silent)
        return self:GetLibrary(major, silent)
    end,
})
function LibStub:GetLibrary(major, silent)
    local lib = self.libs[major]
    if not lib and not silent then
        error("Cannot find a library instance of " .. tostring(major))
    end
    return lib, lib and 4 or nil
end
F.spokenClicks = {}
F.ldb:NewDataObject("Spoken", { type = "launcher", label = "Spoken", icon = 134400, OnClick = function(_, button)
    F.spokenClicks[#F.spokenClicks + 1] = button
end })
F.ldb:NewDataObject("Libs Error Display", { type = "data source", label = "Erreurs", text = "0", OnTooltipShow = function(tooltip)
    tooltip:AddLine("Aucune erreur")
end })

-- Other addons' buttons on the map: Spoken's through LibDBIcon-1.0, AutoBiographer's its own, 31 across with its icon
-- 21 in the tracking ring as the old minimap buttons are, its strata and level fixed as KaLi Recipe's are, KaLi
-- Recipe's, whose LDB object of the same name is an item already, and a numbered pin. Addons' globals aren't secure,
-- the game's are: F.insecure names theirs.
F.insecure = {}
local secure = issecurevariable
function issecurevariable(t, name)
    if F.insecure[name or t] then
        return false, "AddOn"
    end
    return secure(t, name)
end
local function mapButton(name, size, parent)
    local b = CreateFrame("Button", name, parent or Minimap)
    _G[name] = b
    F.insecure[name] = true
    b:SetSize(size, size)
    b:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
    return b
end
F.dbiButton = mapButton("LibDBIcon10_Spoken", 31)
F.rawButton = mapButton("AutoBiographerMinimapButton", 31)
F.rawIcon = F.rawButton:CreateTexture(nil, "BACKGROUND")
F.rawIcon:SetTexture("Interface\\Icons\\inv_misc_note_05")
F.rawIcon:SetSize(21, 21)
F.rawRing = F.rawButton:CreateTexture(nil, "OVERLAY")
F.rawRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
F.rawRing:SetSize(56, 56)
F.rawButton:SetFixedFrameStrata(true)
F.rawButton:SetFixedFrameLevel(true)
F.rawClicks = {}
-- both buttons, as an old minimap button registers them (its right one its addon's own)
F.rawButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
F.rawButton:SetScript("OnClick", function(_, button)
    F.rawClicks[#F.rawClicks + 1] = button
end)
F.ldb:NewDataObject("KaLi Recipe", { type = "launcher", label = "KaLi Recipe", icon = 134939 })
F.recipeButton = mapButton("KaLiRecipeMinimapButton", 31)
F.pin = mapButton("HandyNotesPin12", 16)
F.dbi = { buttons = { Spoken = F.dbiButton } }
function F.dbi:GetButtonList()
    local list = {}
    for name in pairs(self.buttons) do
        list[#list + 1] = name
    end
    return list
end
function F.dbi:GetMinimapButton(name)
    return self.buttons[name]
end
F.dbi.RegisterCallback = F.ldb.RegisterCallback
LibStub.libs["LibDBIcon-1.0"] = F.dbi

-- A popup taken away by the addon, unanswered.
function StaticPopup_Hide(which)
    if F.popup and F.popup.which == which then
        F.popup = nil
    end
end

-- A popup with an edit box: F.popupText is what was typed in it.
function F.AcceptPopup()
    local p = F.popup
    F.popup = nil
    local box = CreateFrame("EditBox")
    box:SetText(F.popupText)
    StaticPopupDialogs[p.which].OnAccept({ GetEditBox = function()
        return box
    end }, p.data)
end

-- ---------- Secure frames, as Forever has them ----------
-- A frame made from one of Blizzard's secure templates is protected (Blizzard_FrameXML/SecureTemplates.xml,
-- Blizzard_RestrictedAddOnEnvironment); so is a frame with a protected child, or one a protected frame is anchored to.
-- In a fight, an addon calling on a protected frame one of the methods the API docs mark protected
-- (IsProtectedFunction; SetAttribute too) is blocked: nothing happens but F.Blocked's record and event. The game's own
-- restricted code (a handler's snippets, the auto-hide driver) isn't: F.restricted counts it running.
F.restricted = 0
local SECURE_TEMPLATES = { SecureFrameTemplate = true, SecureActionButtonTemplate = true, SecureHandlerBaseTemplate = true,
    SecureHandlerClickTemplate = true, SecureHandlerEnterLeaveTemplate = true, SecureHandlerShowHideTemplate = true }
local PROTECTED_METHODS = { "Show", "Hide", "SetShown", "SetPoint", "SetAllPoints", "ClearAllPoints", "ClearPoint",
    "AdjustPointsOffset", "SetSize", "SetWidth", "SetHeight", "SetParent", "SetScale", "SetFrameStrata", "SetFrameLevel",
    "SetFixedFrameStrata", "SetFixedFrameLevel", "SetToplevel", "Raise", "Lower", "EnableMouse", "EnableMouseWheel",
    "EnableKeyboard", "SetHitRectInsets", "SetClampedToScreen", "RegisterForClicks", "SetEnabled", "Enable", "Disable",
    "SetID", "StartMoving", "StopMovingOrSizing", "SetAttribute" }

local function isProtected(frame, seen)
    if type(frame) ~= "table" then
        return false
    end
    if frame.fakeSecure then
        return true
    end
    seen = seen or {}
    if seen[frame] then
        return false
    end
    seen[frame] = true
    for _, child in ipairs(frame.fakeChildren or {}) do
        if isProtected(child, seen) then
            return true
        end
    end
    for anchored in pairs(frame.fakeAnchoredBy or {}) do
        if isProtected(anchored, seen) then
            return true
        end
    end
    return false
end
F.IsProtected = isProtected

-- The pointer's buttons as SecureButton_GetButtonSuffix names them, and an attribute looked up as
-- SecureButton_GetModifiedAttribute does: with the modifiers' prefix and the button's suffix, then without them.
local SUFFIX = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }
-- The first one found stands, ATTRIBUTE_NOOP ("") ruling the attribute out for that click, as Blizzard's
-- SecureButton_GetModifiedAttribute has it (SecureTemplates.lua).
ATTRIBUTE_NOOP = ATTRIBUTE_NOOP or ""
local function modified(frame, name, button)
    local prefix = (F.alt and "alt-" or "") .. (F.ctrl and "ctrl-" or "") .. (F.shift and "shift-" or "")
    local suffix = SUFFIX[button] or ""
    local a = frame.attributes
    for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix, prefix .. name .. "*", "*" .. name .. "*",
        name }) do
        if a[key] ~= nil then
            if a[key] == ATTRIBUTE_NOOP then
                return nil
            end
            return a[key]
        end
    end
end

-- A secure action button's click, as SecureActionButton_OnClick has it for an addon's: its "useOnKeyDown" attribute,
-- else the ActionButtonUseKeyDown CVar, says whether the press or the release acts (a test's click is the release); a
-- macro run is recorded in F.ranMacros, { macro = name } or { text = commands }.
F.ranMacros = {}
local function secureAction(self, button, down)
    local onDown = self.attributes.useOnKeyDown
    if onDown == nil then
        onDown = F.cvars.ActionButtonUseKeyDown == "1"
    end
    if (down and true or false) ~= (onDown and true or false) then
        return
    end
    if modified(self, "type", button) == "raidtarget" and modified(self, "action", button) == "clear-all" then
        F.raidTargetsRemoved = (F.raidTargetsRemoved or 0) + 1
    end
    if modified(self, "type", button) == "macro" then
        local macro = modified(self, "macro", button)
        local text = not macro and modified(self, "macrotext", button)
        if macro or text then
            F.ranMacros[#F.ranMacros + 1] = { macro = macro, text = text }
        end
    end
end

-- The game's auto-hide (SecureHoverDriver.lua): F.autoHide[frame] = { state, ttl, parts, at }, one pass a call of
-- F.AutoHide(elapsed). A frame that moved or hid is dropped; one the pointer has never been on waits for it.
F.autoHide = {}
local function rectOf(frame)
    local p = frame.point or {}
    return table.concat({ tostring(p[1]), tostring(p[4]), tostring(p[5]), tostring(frame.width), tostring(frame.height) }, " ")
end
local function insecureCall(what)
    if F.combat and F.restricted == 0 then
        F.Blocked(what)
        return true
    end
end
function RegisterAutoHide(frame, ttl)
    if insecureCall("RegisterAutoHide()") then
        return
    end
    F.autoHide[frame] = { state = "new", ttl = tonumber(ttl) or 0, parts = { frame }, at = rectOf(frame) }
end
function AddToAutoHide(frame, child)
    local s = F.autoHide[frame]
    if not s then
        error("Parent frame is not registered for auto-hide")
    end
    if s.state ~= "new" then
        error("Parent frame is not freshly registered")
    end
    if insecureCall("AddToAutoHide()") then
        return
    end
    s.parts[#s.parts + 1] = child
end
function UnregisterAutoHide(frame)
    if insecureCall("UnregisterAutoHide()") then
        return
    end
    F.autoHide[frame] = nil
end
function F.AutoHide(elapsed)
    local hides = {}
    for frame, s in pairs(F.autoHide) do
        if not frame:IsVisible() then
            F.autoHide[frame] = nil
        else
            local over = false
            for _, part in ipairs(s.parts) do
                over = over or part:IsMouseOver()
            end
            local cur = s.state
            if over then
                s.state = true
            else
                if cur == true then
                    if rectOf(frame) == s.at then
                        cur = s.ttl
                    else
                        cur = nil
                        F.autoHide[frame] = nil
                    end
                elseif cur == "new" then
                    cur = false
                    s.state = false
                elseif cur then
                    cur = cur - (elapsed or 0)
                end
                if cur then
                    if cur > 0 then
                        s.state = cur
                    else
                        F.autoHide[frame] = nil
                        hides[#hides + 1] = frame
                    end
                end
            end
        end
    end
    F.restricted = F.restricted + 1
    for _, frame in ipairs(hides) do
        frame:Hide()
        frame.attributes.statehidden = true
    end
    F.restricted = F.restricted - 1
end

-- Frame handles, as restricted code sees frames: a protected one's in a fight, any out of one (GetHandleFrame).
local handles = setmetatable({}, { __mode = "k" })
local HANDLE = {}
local function frameOf(h)
    local f = h.frame
    if F.combat and not isProtected(f) then
        error("Invalid frame handle")
    end
    return f
end
local function handleOf(frame)
    if not frame then
        return nil
    end
    local h = handles[frame]
    if not h then
        h = setmetatable({ frame = frame }, { __index = HANDLE })
        handles[frame] = h
    end
    return h
end
function HANDLE:Show()
    frameOf(self):Show()
end
function HANDLE:Hide()
    frameOf(self):Hide()
end
function HANDLE:IsShown()
    return self.frame:IsShown()
end
function HANDLE:IsVisible()
    return self.frame:IsVisible()
end
function HANDLE:GetAttribute(key)
    return self.frame.attributes[key]
end
function HANDLE:SetAttribute(key, value)
    frameOf(self).attributes[key] = value
end
function HANDLE:GetFrameRef(label)
    return handleOf(self.frame.attributes["frameref-" .. label])
end
function HANDLE:RegisterAutoHide(duration)
    RegisterAutoHide(frameOf(self), duration)
end
function HANDLE:UnregisterAutoHide()
    UnregisterAutoHide(frameOf(self))
end
function HANDLE:AddToAutoHide(child)
    if type(child) ~= "table" or getmetatable(child) == nil or not child.frame then
        error("Invalid frame handle for AddToAutoHide")
    end
    AddToAutoHide(frameOf(self), child.frame)
end
-- As HANDLE:CallMethod: the method runs insecurely, apart, its error reported and the snippet going on.
function HANDLE:CallMethod(name, ...)
    local frame = self.frame
    local saved = F.restricted
    F.restricted = 0
    local ok, err = pcall(function(...)
        local method = frame[name]
        if type(method) ~= "function" then
            error("Invalid method '" .. tostring(name) .. "'")
        end
        method(frame, ...)
    end, ...)
    F.restricted = saved
    if not ok then
        geterrorhandler()(err)
    end
end

-- A handler's snippet run as SecureHandler_Self_Execute runs it: its arguments named by `signature`, in an environment
-- of its own holding nothing of the addon's.
-- PlayerInCombat as RestrictedEnvironment.lua's (UnitAffectingCombat): a test's fight.
local RESTRICTED_ENV = { math = math, string = string, table = table, tostring = tostring, tonumber = tonumber, type = type,
    pairs = pairs, ipairs = ipairs, select = select, format = string.format,
    PlayerInCombat = function()
        return F.combat == true
    end }
F.snippetErrors = {}
local function runSnippet(frame, attribute, signature, ...)
    local body = frame.attributes[attribute]
    if type(body) ~= "string" then
        return
    end
    local fn, err = loadstring("local " .. signature .. " = ...\n" .. body, "=" .. attribute)
    if not fn then
        F.snippetErrors[#F.snippetErrors + 1] = err
        geterrorhandler()(err)
        return
    end
    setfenv(fn, RESTRICTED_ENV)
    F.restricted = F.restricted + 1
    local ok, runErr = pcall(fn, handleOf(frame), ...)
    F.restricted = F.restricted - 1
    if not ok then
        F.snippetErrors[#F.snippetErrors + 1] = runErr
        geterrorhandler()(runErr)
    end
end
F.RunSnippet = runSnippet

-- SecureHandlerSetFrameRef: the handle stored on the frame (as "frameref-<label>"), through Blizzard's own protected
-- frame, so not in a fight.
function SecureHandlerSetFrameRef(frame, label, ref)
    if insecureCall("SecureHandlerSetFrameRef()") then
        return
    end
    frame.attributes["frameref-" .. label] = ref
end

-- Each secure template's own scripts, as its XML has them.
local TEMPLATE_SCRIPTS = {
    SecureActionButtonTemplate = { OnClick = secureAction },
    SecureHandlerClickTemplate = { OnClick = function(self, button, down)
        runSnippet(self, "_onclick", "self, button, down", button, down)
    end },
    -- a test's OnEnter and OnLeave come from the pointer moving
    SecureHandlerEnterLeaveTemplate = {
        OnEnter = function(self, motion)
            if motion ~= false then
                self.attributes._entered = true
                runSnippet(self, "_onenter", "self")
            end
        end,
        OnLeave = function(self, motion)
            if motion ~= false and self.attributes._entered then
                self.attributes._entered = nil
                runSnippet(self, "_onleave", "self")
            end
        end,
    },
    SecureHandlerShowHideTemplate = {
        OnShow = function(self)
            runSnippet(self, "_onshow", "self")
        end,
        OnHide = function(self)
            runSnippet(self, "_onhide", "self")
        end,
    },
}

-- InputScrollFrameTemplate's parts (Blizzard_SharedXML/Shared/InputBox): its edit box, the box's instructions, the
-- count of letters left. The box fires OnTextChanged as the game does, userInput false for SetText; F.Type types.
local function editBox(box)
    function box:SetMaxLetters(n)
        self.maxLetters = n
    end
    function box:GetMaxLetters()
        return self.maxLetters or 0
    end
    function box:GetNumLetters()
        local _, n = tostring(self.text or ""):gsub("[^\128-\191]", "")
        return n
    end
    local set = box.SetText
    function box:SetText(text)
        set(self, text)
        F.RunScript(self, "OnTextChanged", false)
    end
end
function F.Type(box, text)
    box.text = text
    F.RunScript(box, "OnTextChanged", true)
end

local createSecure = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = createSecure(kind, name, parent, template)
    for t in tostring(template or ""):gmatch("[%w_]+") do
        if SECURE_TEMPLATES[t] then
            frame.fakeSecure = true
        end
        for script, fn in pairs(TEMPLATE_SCRIPTS[t] or {}) do
            local before = frame.scripts[script]
            frame.scripts[script] = before and function(...)
                before(...)
                fn(...)
            end or fn
        end
    end
    -- any edit box keeps the letters it's held to, as the game's (a line's too: the macro editor's descriptions)
    if kind == "EditBox" then
        function frame:SetMaxLetters(n)
            self.maxLetters = n
        end
        function frame:GetMaxLetters()
            return self.maxLetters or 0
        end
    end
    -- InputBoxInstructionsTemplate's grey line while empty (InputBoxTemplates.xml)
    if template == "InputBoxInstructionsTemplate" then
        frame.Instructions = frame:CreateFontString()
    end
    if template == "InputScrollFrameTemplate" then
        frame.EditBox = CreateFrame("EditBox", nil, frame)
        editBox(frame.EditBox)
        frame.EditBox.Instructions = frame.EditBox:CreateFontString()
        frame.CharCount = frame:CreateFontString()
    end
    function frame:IsProtected()
        return isProtected(self), self.fakeSecure == true
    end
    -- the frames a protected one anchors to are protected with it
    local setPoint, clearPoints = frame.SetPoint, frame.ClearAllPoints
    function frame:SetPoint(point, relativeTo, ...)
        if type(relativeTo) == "table" and relativeTo ~= self then
            relativeTo.fakeAnchoredBy = relativeTo.fakeAnchoredBy or setmetatable({}, { __mode = "k" })
            relativeTo.fakeAnchoredBy[self] = true
            self.fakeAnchors = self.fakeAnchors or {}
            self.fakeAnchors[#self.fakeAnchors + 1] = relativeTo
        end
        return setPoint(self, point, relativeTo, ...)
    end
    function frame:ClearAllPoints()
        for _, target in ipairs(self.fakeAnchors or {}) do
            if target.fakeAnchoredBy then
                target.fakeAnchoredBy[self] = nil
            end
        end
        self.fakeAnchors = nil
        return clearPoints(self)
    end
    for _, method in ipairs(PROTECTED_METHODS) do
        local inner = frame[method]
        frame[method] = function(self, ...)
            if F.combat and F.restricted == 0 and isProtected(self) then
                F.Blocked(tostring(self:GetObjectType()) .. ":" .. method .. "()")
                return
            end
            return inner(self, ...)
        end
    end
    return frame
end

-- A fight beginning and ending, as the game sends them: PLAYER_REGEN_DISABLED just before the lockdown, ENABLED just
-- after it.
function F.EnterCombat()
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
end
function F.LeaveCombat()
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
end

-- The game's macros, the account's and this character's, as GetMacroInfo gives them (indices past
-- Constants.MacroConsts.MAX_ACCOUNT_MACROS for the character's).
Constants.MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 }
F.macros = { { name = "Monture", icon = 132261, body = "/cast [nomounted] Monture\n/dismount" } }
F.characterMacros = { { name = "Soin", icon = 135907, body = "/cast [@mouseover] Soin" } }
function GetNumMacros()
    return #F.macros, #F.characterMacros
end
function GetMacroInfo(i)
    local m = i > 120 and F.characterMacros[i - 120] or F.macros[i]
    if m then
        return m.name, m.icon, m.body
    end
end
function GetMacroIndexByName(name)
    for i, m in ipairs(F.macros) do
        if m.name == name then
            return i
        end
    end
    for i, m in ipairs(F.characterMacros) do
        if m.name == name then
            return 120 + i
        end
    end
    return 0
end

-- Blizzard_SharedXML's tooltip lines, as text.
function GameTooltip_AddErrorLine(tooltip, text)
    tooltip:AddLine(text, 1, 0.13, 0.13, true)
end
function GameTooltip_AddNormalLine(tooltip, text)
    tooltip:AddLine(text, 1, 0.82, 0, true)
end

-- Menus as Blizzard_Menu builds them, recording what was built so tests can find an entry and choose it: an entry
-- greyed (SetEnabled, a value or a function the menu polls) and its tooltip (SetTooltip) kept.
local function menuDescription()
    local d = { items = {} }
    local function add(kind, text, a, b)
        local item = menuDescription()
        item.kind, item.text, item.choose, item.isSelected = kind, text, a, b
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
    function d:CreateRadio(text, isSelected, onSelect, data)
        local item = add("radio", text, onSelect, isSelected)
        item.data = data
        return item
    end
    function d:CreateCheckbox(text, isSelected, onSelect)
        return add("checkbox", text, onSelect, isSelected)
    end
    function d:CreateDivider()
        return add("divider")
    end
    -- a frame of the addon's own (a slider): its initializers and resetters kept, F.MenuFrame runs them
    function d:CreateTemplate(template)
        local item = add("template", nil)
        item.template, item.initializers, item.resetters = template, {}, {}
        return item
    end
    function d:AddInitializer(fn)
        self.initializers = self.initializers or {}
        self.initializers[#self.initializers + 1] = fn
    end
    function d:AddResetter(fn)
        self.resetters = self.resetters or {}
        self.resetters[#self.resetters + 1] = fn
    end
    function d:SetEnabled(enabled)
        self.enabled = enabled
    end
    function d:IsEnabled()
        if type(self.enabled) == "function" then
            return self.enabled(self) and true or false
        end
        return self.enabled ~= false
    end
    function d:SetTooltip(fn)
        self.tooltip = fn
    end
    return d
end
F.MenuDescription = menuDescription
MenuUtil.CreateContextMenu = function(owner, generator)
    local d = menuDescription()
    generator(owner, d)
    F.lastMenu = d
    return d
end
MenuUtil.GetElementText = function(desc)
    return desc.text
end
-- A dropdown's menu, as it would open: its generator run on a fresh description.
function F.DropdownMenu(dropdown)
    local d = menuDescription()
    dropdown.generator(dropdown, d)
    return d
end
-- A template entry's frame as the menu makes it: one frame of the menu's pool (`frame`, else a new one) run through its
-- initializers; its size as they give it. F.MenuRelease hands it back, its resetters run.
function F.MenuFrame(item, frame)
    frame = frame or CreateFrame("Frame", nil, UIParent)
    for _, fn in ipairs(item.initializers or {}) do
        local w, h = fn(frame, item, {})
        if w and h then
            frame:SetSize(w, h)
        end
    end
    return frame
end
function F.MenuRelease(item, frame)
    for _, fn in ipairs(item.resetters or {}) do
        fn(frame)
    end
end

-- What one of the hub's buttons shows: its text, then its value where its list sets values apart (UI/Hub/Buttons.lua).
function F.Shows(b)
    local t = tostring(b.Text:GetText() or "")
    if b.Value and b.Value:IsShown() then
        t = t .. " " .. tostring(b.Value:GetText() or "")
    end
    return t
end

-- An entry's tooltip, as the menu shows it: its lines.
function F.MenuTooltip(item)
    if not item.tooltip then
        return nil
    end
    GameTooltip:SetOwner(UIParent)
    item.tooltip(GameTooltip, item)
    return F.tooltip.lines
end

-- ---------- What the info bar reads, beyond the Titan bar's (2026-11-16) ----------

-- An item link's tooltip: its name, as the game's own.
function GameTooltip:SetHyperlink(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    F.tooltip.lines[#F.tooltip.lines + 1] = id and F.itemNames[id] or link
end
Enum.PowerType = Enum.PowerType or { Mana = 0, Rage = 1, Energy = 3 }
Enum.ItemQuality = Enum.ItemQuality or { Poor = 0, Common = 1 }

-- The chat menu's emotes (Blizzard_ChatFrameBase's ChatEmoteConstants.lua), a few of them, French: each token's
-- index n names EMOTEn_TOKEN and its slash command EMOTEn_CMD1; the voice emote of the faction among them.
F.emotes = { { 102, "WAVE", "/signe" }, { 1, "BOW", "/salut" }, { 3, "DANCE", "/danse" }, { 56, "HELLO", "/bonjour" },
    { 7, "HELPME", "/aide" }, { 9, "CHEER", "/acclame" }, { 454, "FORTHEALLIANCE", "/pourlalliance" } }
for _, e in ipairs(F.emotes) do
    _G["EMOTE" .. e[1] .. "_TOKEN"], _G["EMOTE" .. e[1] .. "_CMD1"] = e[2], e[3]
end
MAXEMOTEINDEX = 628
EmoteList = { "DANCE", "BOW", "WAVE" }
TextEmoteSpeechList = { "HELPME", "HELLO", "CHEER", "FORTHEALLIANCE" }

-- The character's skill lines as the skills tab lists them: a header's skillID is its category's.
F.skills = {
    { skillID = 6, name = "Compétences d'armes", isHeader = true },
    { skillID = 43, name = "Épées", rank = 120, maxRank = 150, modifier = 5, cat = 6 },
    { skillID = 95, name = "Défense", rank = 140, maxRank = 150, cat = 6 },
    { skillID = 118, name = "Ambidextrie", rank = 1, maxRank = 1, cat = 6 },
    { skillID = 11, name = "Métiers", isHeader = true },
    { skillID = 186, name = "Minage", rank = 75, maxRank = 150, cat = 11 },
    { skillID = 9, name = "Compétences secondaires", isHeader = true },
    { skillID = 356, name = "Pêche", rank = 30, maxRank = 75, cat = 9 },
    { skillID = 125, name = "Raciale orc", rank = 1, maxRank = 1, cat = 9 },
}
C_SkillInfo = {
    GetNumSkillLines = function()
        return #F.skills
    end,
    GetSkillLineInfo = function(i)
        local s = F.skills[i]
        if not s then
            return nil
        end
        return { skillID = s.skillID, name = s.name, isHeader = s.isHeader == true, isCollapsed = false, rank = s.rank or 0,
            tempPoints = 0, modifier = s.modifier or 0, maxRank = s.maxRank or 0, isAbandonable = false, stepCost = 0,
            rankCost = 0, minLevel = 0, costType = 0, parentSkillLineID = 0, skillLineCategoryID = s.cat or 0,
            description = "" }
    end,
}
-- A skill line by its id, as the Skills tab's detail reads it.
C_SkillInfo.GetSkillLineInfoByID = function(id)
    for i, s in ipairs(F.skills) do
        if s.skillID == id and not s.isHeader then
            return C_SkillInfo.GetSkillLineInfo(i)
        end
    end
end
-- The kinds of item and of weapon (ItemConstantsDocumentation's), and the main hand's weapon when F.items has no other:
-- a sword, the skill line « Épées » above.
Enum.ItemClass = Enum.ItemClass or { Weapon = 2, Armor = 4 }
Enum.ItemWeaponSubclass = Enum.ItemWeaponSubclass or { Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5,
    Polearm = 6, Sword1H = 7, Sword2H = 8, Staff = 10, Unarmed = 13, Dagger = 15, Thrown = 16, Crossbow = 18, Wand = 19 }
F.mainHand = { class = 2, subclass = 7 }

-- The character sheet's attributes; all hidden while F.statsSecret, as unit stats are in a fight.
local function stat(...)
    if F.statsSecret then
        local n = select("#", ...)
        local out = {}
        for i = 1, n do
            out[i] = F.SECRET
        end
        return unpack(out, 1, n)
    end
    return ...
end
-- current, effective, raised, lowered (UnitDocumentation's names): the current with its changes, as the sheet takes it
-- (its base the current less them); strength raised by 5.
F.attributes = { 110, 80, 95, 30, 40 }
function UnitStat(_, i)
    local v = F.attributes[i] or 0
    return stat(v, v, i == 1 and 5 or 0, 0)
end
-- a level 23 warrior's: the original table's 243 and its stamina's 770 (it had been 1520, its base a made-up 750, until
-- the card read the table, 2026-11-24)
function UnitHealthMax()
    return stat(1013)
end
function UnitPowerMax(_, kind)
    return stat(kind == Enum.PowerType.Mana and 0 or 100)
end
function UnitPowerType()
    return 1, "RAGE"
end
RAGE, MANA = "Rage", "Mana"
function UnitDamage()
    return stat(41.2, 63.8, 0, 0, 0, 0, 1)
end
function UnitRangedDamage()
    return stat(0, 0, 0, 0, 0, 1)
end
-- (a warrior at 23, its level's part the original server's: 3 x 23 - 20, 49, and 2 a point of its 110 strength; ranged
-- 23 - 10, 13, and its agility's 40)
function UnitAttackPower()
    return stat(269, 20, 0)
end
function UnitRangedAttackPower()
    return stat(53, 0, 0)
end
function GetCombatRatingBonus()
    return stat(1)
end
function GetHitModifier()
    return stat(2)
end
function GetCritChance()
    return stat(6.25)
end
function GetRangedCritChance()
    return stat(4)
end
function GetSpellCritChance()
    return stat(1.5)
end
function GetMeleeHaste()
    return stat(0)
end
function GetRangedHaste()
    return stat(0, 0)
end
function UnitSpellHaste()
    return stat(0)
end
function GetExpertise()
    return stat(0, 0, 0)
end
function GetArmorPenetration()
    return stat(0)
end
function GetSpellBonusDamage()
    return stat(0)
end
function GetSpellBonusHealing()
    return stat(0)
end
function GetSpellPenetration()
    return stat(0)
end
function GetManaRegen()
    return stat(0, 0)
end
function GetPowerRegen()
    return stat(0, 0)
end
function UnitDefenseSkill()
    return stat(140, 3)
end
function GetDodgeChance()
    return stat(5.1)
end
function GetBlockChance()
    return stat(0)
end
function GetParryChance()
    return stat(5)
end
function UnitArmor()
    return stat(1200, 1340, 1340, 140)
end
CR_HIT_MELEE = 6
-- The sheet's hit chance is the best of melee, off hand, ranged and spells: here the spells' (1 + 3.5).
CR_HIT_RANGED, CR_HIT_SPELL = 7, 8
function GetOffhandHitModifier()
    return stat(2)
end
function GetRangedHitModifier()
    return stat(0)
end
function GetSpellHitModifier()
    return stat(3.5)
end
-- One weapon: no off hand's speed.
function UnitAttackSpeed()
    return stat(2.6, nil)
end
-- The sheet's resistances (base, real, effective, bonus by damage class): fire raised by gear. The water and the air,
-- the PvP gear rules off, no attack power taken from spell power.
Enum.Damageclass = Enum.Damageclass or { Physical = 0, Holy = 1, Fire = 2, Nature = 3, Frost = 4, Shadow = 5, Arcane = 6 }
F.resistances = { [2] = { 10, 10, 25, 15 } }
function UnitResistance(_, class)
    local r = F.resistances[class] or { 0, 0, 0, 0 }
    return stat(r[1], r[2], r[3], r[4])
end
F.swimming = false
function IsSwimming()
    return F.swimming
end
function IsFlying()
    return false
end
function IsFalling()
    return false
end
function GetPVPGearStatRules()
    return false
end
function GetOverrideAPBySpellPower()
    return stat(0)
end
-- What the sheet's own tooltips work their figures out with (PaperDollFrame.lua, PaperDollFrameStats.lua), and a few
-- of their texts as the French client has them: effects with their figures, what a value is, notes in grey.
function GetHealthRegenFromSpirit()
    return stat(0)
end
function GetHealthRegen()
    return stat(0)
end
function GetShieldBlock()
    return stat(0)
end
function UnitEffectiveLevel()
    return 23
end
-- The game's tooltips read by an addon: each post call kept by its kind, run by F.Hover as a tooltip showing that
-- kind of thing does ("Item" with { id, hyperlink }, "Spell" with { id }).
Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1 }
F.tooltipPosts = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn)
        F.tooltipPosts[kind] = F.tooltipPosts[kind] or {}
        table.insert(F.tooltipPosts[kind], fn)
    end,
}
TooltipUtil = TooltipUtil or {}
function TooltipUtil.GetDisplayedItem()
end
function F.Hover(kind, data)
    for _, fn in ipairs(F.tooltipPosts[Enum.TooltipDataType[kind]] or {}) do
        fn(GameTooltip, data)
    end
end
-- C_EncodingUtil, as far as a set of settings goes there and back (Core/Sets.lua): a value written as Lua, "deflated"
-- behind a mark, in hexadecimal for base 64; each raises an error on what it didn't write, as the game's.
do
    local function written(v)
        local kind = type(v)
        if kind == "table" then
            local parts = {}
            for k, x in pairs(v) do
                parts[#parts + 1] = "[" .. written(k) .. "]=" .. written(x)
            end
            table.sort(parts)
            return "{" .. table.concat(parts, ",") .. "}"
        elseif kind == "string" then
            return string.format("%q", v)
        end
        return tostring(v)
    end
    C_EncodingUtil = {
        SerializeCBOR = function(value)
            return "return " .. written(value)
        end,
        DeserializeCBOR = function(source)
            local chunk = assert(loadstring(source))
            return chunk()
        end,
        CompressString = function(source)
            return "Z" .. source
        end,
        DecompressString = function(source)
            assert(source:sub(1, 1) == "Z", "not deflated")
            return source:sub(2)
        end,
        EncodeBase64 = function(source)
            return (source:gsub(".", function(c)
                return string.format("%02x", c:byte())
            end))
        end,
        DecodeBase64 = function(source)
            assert(#source % 2 == 0 and not source:find("[^0-9a-f]"), "not base 64")
            return (source:gsub("..", function(pair)
                return string.char(tonumber(pair, 16))
            end))
        end,
    }
end
-- The target: none, or an enemy of F.target's level.
function UnitExists(unit)
    return unit == "player" or (unit == "target" and F.target ~= nil)
end
function UnitCanAttack(_, unit)
    return unit == "target" and F.target ~= nil
end
function UnitRace()
    return "Humaine", "Human", 1
end
local unitLevel = UnitLevel
function UnitLevel(unit)
    if unit == "target" then
        return F.target
    end
    return unitLevel(unit)
end
function IsDualWielding()
    return false
end
CR_HASTE_MELEE = 18
C_PaperDollInfo = {
    GetArmorEffectiveness = function(armor, level)
        return armor / (armor + 400 + 85 * level)
    end,
    GetArmorEffectivenessAgainstTarget = function()
        return nil
    end,
}
WARRIOR_STRENGTH_TOOLTIP = "Augmente la |cFFFFFFFFpuissance d’attaque|r de %d.\nAugmente la |cFFFFFFFFvaleur de blocage|r de %d."
STAT_ARMOR_TOOLTIP = "Réduit les |cFFFFFFFFdégâts physiques|r subis de %0.2f %%.\n\nAugmenté par l’|cFFFFFFFFAgilité|r."
ARMOR_MAX_EFFECTIVENESS_TOOLTIP = "|cffBCBCBCLa réduction des dégâts liée à l’Armure ne peut pas dépasser 75 %%.|r"
STAT_HEALTH_TOOLTIP = "Utilisés pour suivre les |cFFFFFFFFdégâts subis|r.\nLe personnage meurt s’ils tombent à zéro.\n\n"
    .. "|cFFBCBCBCSe régénère automatiquement hors combat.\n\nChaque point d’Endurance ajoute 10 points de vie.|r"
MELEE_ATTACK_POWER_TOOLTIP = "Augmente les dégâts par seconde des |cFFFFFFFFarmes de mêlée|r de %s.\n\nAugmenté par la "
    .. "|cFFFFFFFFForce|r.\n\n|cffBCBCBCChaque tranche de 14 points de puissance d’attaque ajoute 1 point de dégâts par seconde.|r"
RESISTANCE_TOOLTIP_SUBTEXT = "Améliore la résistance aux attaques, sorts et techniques |2%s.\n\nRésistance moyenne contre "
    .. "une cible adverse de niveau %d : |cffffffff%s %%|r"
RESISTANCE_TYPE2 = "feu"
CR_HASTE_MELEE_TOOLTIP = "Augmente la vitesse d’attaque en |cFFFFFFFFmêlée|r de %.2f%%."
CR_HASTE_RANGED_TOOLTIP = "Augmente la vitesse des attaques |cFFFFFFFFà distance|r de %.2f%%."
CR_HASTE_SPELL_TOOLTIP = "Augmente la vitesse d’incantation des |cFFFFFFFFsorts|r de %.2f%%."
STAT_HASTE_TOOLTIP = "Augmente la vitesse d’attaque et la vitesse d’incantation des sorts."
STAT_HASTE_MELEE_TOOLTIP = "Augmente la vitesse d'attaque."
ARMOR_PENETRATION_TOOLTIP = "Vos |cFFFFFFFFattaques|r ignorent %d de l’|cFFFFFFFFArmure|r de vos adversaires lorsque vous "
    .. "attaquez. Vous leur infligerez davantage de dégâts si elle tombe sous 0."
-- The Skills tab's weapon skill rows, the damage tooltip's skill line, a warlock's pet's share of its spell power
WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER = "|cFFFFFFFFAdversaire de niveau égal|r"
WEAPON_SKILL_DETAIL_SAME_LEVEL = "Chances de |cFFFFFFFFtoucher|r et d’éviter que vos attaques soient |cFFFFFFFFesquivées|r ou |cFFFFFFFFparées|r : %s\n\nChances de |cFFFFFFFFcoup critique|r : %s"
WEAPON_SKILL_DETAIL_SAME_LEVEL_RANGED = "Chances de |cFFFFFFFFtoucher|r : %s\n\nChances de |cFFFFFFFFcoup critique|r : %s"
WEAPON_SKILL_DETAIL_BOSS_HEADER = "|cFFFFFFFFContre les boss de raid|r"
WEAPON_SKILL_DETAIL_BOSS = "Chances de |cFFFFFFFFtoucher|r et d’éviter que vos attaques soient |cFFFFFFFFesquivées|r ou |cFFFFFFFFparées|r : %s\n\nChances de |cFFFFFFFFcoup critique|r : %s\n\nLes |cFFFFFFFFcoups déviés|r surviennent %s du temps et leurs dégâts sont réduits de %s."
WEAPON_SKILL_DETAIL_BOSS_RANGED = "Chances de |cFFFFFFFFtoucher|r : %s\n\nChances de |cFFFFFFFFcoup critique|r : %s"
WEAPON_SKILL_PAPERDOLLFRAME_FORMAT = "%s :"
PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG = "|cFFBCBCBC\nAugmente la puissance d’attaque de votre familier de %d et ses dégâts des sorts de %d.|r"
PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG_FIRE = "|cFFBCBCBC\nAugmente la puissance d’attaque de votre familier de %d et ses dégâts des sorts de %d.|r"
PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG_SHADOW = "|cFFBCBCBC\nAugmente la puissance d’attaque de votre familier de %d et ses dégâts des sorts de %d.|r"
-- A warlock's pet's share of its spell power (Camelot's PaperDollFrame.lua, its spell power's two)
WARLOCK_PET_BONUS = { PET_BONUS_SPELLDMG_TO_SPELLDMG = 0.1, PET_BONUS_SPELLDMG_TO_AP = 0.17 }
-- Forever's glancing blows against a defence, by a weapon skill (PlayerScriptDocumentation): a raid boss's
function GetGlancingBlowChance()
    return stat(0.4)
end
function GetGlancingBlowPenalty()
    return stat(0.35)
end

-- The clock's alarm, as its window keeps it (Blizzard_TimeManager's CVars: minutes past midnight).
F.cvars.timeMgrAlarmEnabled, F.cvars.timeMgrAlarmTime, F.cvars.timeMgrAlarmMessage = "0", "480", ""
-- The ammunition slot (Blizzard_FrameXMLBase's Constants.lua) and the bags' grey items: F.ammo { count, texture },
-- F.junk { bag, slot, itemID, count, price }.
INVSLOT_AMMO = 0
F.ammo = { count = 412, texture = 132382 }
function GetInventoryItemCount(_, slot)
    return slot == 0 and F.ammo and F.ammo.count or 0
end
function GetInventoryItemTexture(_, slot)
    return slot == 0 and F.ammo and F.ammo.texture or nil
end
F.junk = { { bag = 0, slot = 1, itemID = 3300, count = 3, price = 25 }, { bag = 1, slot = 2, itemID = 3301, count = 1, price = 120 } }
C_Container.GetContainerItemInfo = function(bag, slot)
    for _, j in ipairs(F.junk) do
        if j.bag == bag and j.slot == slot then
            return { itemID = j.itemID, stackCount = j.count, quality = 0, hasNoValue = false }
        end
    end
end
C_Item.GetItemIconByID = function()
    return 134400
end
-- An item's kind and its icon from its id or its link alone (F.items, as GetItemInfo's): its id, type, subtype,
-- slot, icon, class and subclass.
C_Item.GetItemInfoInstant = function(item)
    local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
    if not id then
        return nil
    end
    local i = F.items[id] or (id == 1016 and F.mainHand) or {}
    return id, "Armor", "Cloth", i.equip or "", 134400, i.class or 4, i.subclass or 1
end
-- An item by its id (the bags' grey ones) or a worn one by its link: its kind and its set (F.items by item id:
-- { class, subclass, set, equip, quality }; armour, cloth, no set, no slot, uncommon by default), its returns in the
-- documentation's order.
F.items = {}
C_Item.GetItemInfo = function(id)
    if type(id) == "string" then
        local item, slot = tonumber(id:match("item:(%d+)")), id:match("%[Objet (%d+)%]")
        if not item then
            return nil
        end
        local kind = F.items[item] or {}
        return "Objet " .. tostring(slot), id, kind.quality or 2, 60, 60, "", "", 1, kind.equip or "", 134400, 0,
            kind.class or 4, kind.subclass or 1, 1, 0, kind.set, false, ""
    end
    for _, j in ipairs(F.junk) do
        if j.itemID == id then
            return "Junk", "item:" .. id, 0, 1, 1, "", "", 20, "", 134400, j.price
        end
    end
end
-- Each slot's item: its stats by the game's names for them (C_Item.GetItemStats, by its link's "[Objet <slot>]"), its
-- quality; none carries any at first.
F.itemStats, F.itemQuality = {}, {}
C_Item.GetItemStats = function(link)
    local slot = tonumber(tostring(link):match("%[Objet (%d+)%]"))
    return slot and F.itemStats[slot] or {}
end
-- A set's name (F.setNames by set); a weapon's enchantments for a while, by Enum.WeaponSlot (F.weaponEnchants: a list
-- of WeaponEnchantInfo, the documentation's fields).
F.setNames, F.weaponEnchants = {}, {}
C_Item.GetItemSetInfo = function(set)
    return F.setNames[set] or ("Ensemble " .. tostring(set))
end
C_Item.GetWeaponEnchantInfo = function(slot)
    return F.weaponEnchants[slot] or {}
end
Enum.WeaponSlot = Enum.WeaponSlot or { MainHand = 0, OffHand = 1, Ranged = 2 }
-- The game's menu manager (Blizzard_Menu's proxy): whether one of its menus is open, F.menuOpen.
Menu.GetManager = Menu.GetManager or function()
    return { IsAnyMenuOpen = function()
        return F.menuOpen == true
    end }
end
Enum.ItemEnchantType = Enum.ItemEnchantType or { None = 0, Permanent = 1, Temporary = 2, Imbue = 3 }

-- The talents, as Forever's trait nodes (Blizzard_PlayerSpells' Camelot ClassTalents, SharedTraitsDocumentation's
-- calls): F.talents { spell, rank, ranks }, a node each, in one tree of the active configuration (none without a
-- talent); the node 100 and its place, its entry and definition the same number.
F.talents = {}
C_ClassTalents = C_ClassTalents or {}
C_ClassTalents.GetActiveConfigID = function()
    return #F.talents > 0 and 1 or nil
end
-- the same configuration by the active talent group, as Camelot's talent frame also reads it
C_SpecializationInfo = C_SpecializationInfo or {}
C_SpecializationInfo.GetActiveSpecGroup = function()
    return 1
end
C_SpecializationInfo.GetCombatConfigIDForSpecGroup = function(group)
    return group == 1 and C_ClassTalents.GetActiveConfigID() or nil
end
C_Traits = C_Traits or {}
C_Traits.GetConfigInfo = function(config)
    return config == 1 and { ID = 1, type = 1, name = "", treeIDs = { 7 }, usesSharedActionBars = false } or nil
end
C_Traits.GetTreeNodes = function(tree)
    local nodes = {}
    for i in ipairs(tree == 7 and F.talents or {}) do
        nodes[i] = 100 + i
    end
    return nodes
end
C_Traits.GetNodeInfo = function(_, node)
    local t = F.talents[node - 100]
    if not t then
        return { ID = node, entryIDs = {}, ranksPurchased = 0, activeRank = 0, currentRank = 0, maxRanks = 0 }
    end
    return { ID = node, entryIDs = { node }, ranksPurchased = t.rank, activeRank = t.rank, currentRank = t.rank,
        maxRanks = t.ranks, activeEntry = t.rank > 0 and { entryID = node, rank = t.rank } or nil }
end
C_Traits.GetEntryInfo = function(_, entry)
    local t = F.talents[entry - 100]
    return t and { definitionID = entry, maxRanks = t.ranks, isAvailable = true } or nil
end
C_Traits.GetDefinitionInfo = function(definition)
    local t = F.talents[definition - 100]
    return t and { spellID = t.spell } or {}
end
-- The spells the character knows (F.known by spell), their names (F.spellNames, else « Sort <id> »), its form
-- (F.form, GetShapeshiftFormID's: none by default).
F.known, F.spellNames = {}, {}
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnown = function(spell)
    return F.known[spell] == true
end
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(spell)
    return F.spellNames[spell] or ("Sort " .. tostring(spell))
end
-- A spell's icon: none here, the rows named without one (a buff's, a talent's)
C_Spell.GetSpellTexture = function()
    return nil
end
function GetShapeshiftFormID()
    return F.form
end
-- the form's index on the stance bar: 0 out of a form, 1 in one (one form here)
function GetShapeshiftForm()
    return F.form and 1 or 0
end
-- What the attributes give, as Forever's sheet works it out (Camelot's PaperDollFrameStats.lua's calls), a warrior's:
-- 2 attack power a point of strength, half a ranged one a point of agility, a critical strike's percent for 20 of
-- agility and a spell's for 60 of intellect, the dodge's 4 % from the agility, 10 health a point of stamina past the
-- first 20, no mana from the spirit; Camelot's PaperDollFrameConstants. Hidden in a fight, as the unit's stats are.
STAMINA_BREAK, INTELLECT_BREAK, MANA_PER_INTELLECT = 20, 20, 15
function UnitHPPerStamina()
    return stat(10)
end
function GetAttackPowerForStat(i, v)
    return stat(i == 1 and v * 2 or 0)
end
function GetRangedAttackPowerForStat(i, v)
    return stat(i == 2 and v / 2 or 0)
end
function GetCritChanceFromStat(i, v)
    return stat(i == 2 and v / 20 / 100 or 0)
end
function GetSpellCritChanceFromStat(i, v)
    return stat(i == 4 and v / 60 / 100 or 0)
end
function GetDodgeChanceFromAttribute()
    return stat(0.04)
end
function GetManaRegenFromSpirit()
    return stat(0)
end
function GetInventoryItemQuality(_, slot)
    return F.itemQuality[slot]
end
-- The auras on the player by filter, each an AuraData as the game gives it (its name, its spell, its points); none at
-- first.
F.auras = { HELPFUL = {}, HARMFUL = {} }
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(_, i, filter)
    return (F.auras[filter or "HELPFUL"] or {})[i]
end
-- The ratings the character has, by the sheet's kind: none at first. The sheet's kinds of them (PaperDollFrame.lua's).
F.ratings = {}
function GetCombatRating(kind)
    return F.ratings[kind] or 0
end
CR_DODGE, CR_PARRY, CR_BLOCK, CR_CRIT_MELEE, CR_EXPERTISE = 3, 4, 5, 9, 24
-- What the game makes of so many points of a rating at the character's level (PlayerScriptDocumentation's): here
-- 14 points of a percent, F.ratingValue's own per kind.
F.ratingValue = {}
function GetCombatRatingBonusForCombatRatingValue(kind, value)
    return value / (F.ratingValue[kind] or 14)
end
-- Whether the character is on a mount (PlayerScriptDocumentation's): F.mounted.
F.mounted = false
function IsMounted()
    return F.mounted
end

-- A state a stat card read in game (KaLi HUD's Stats.ReadState, kept by its check of its cards, UI/Hub/Infos/
-- StatCheck.lua), put in the fake's place so that the card is read again from it alone (hud/tools/lua/scenarios/
-- cards.lua): the character's level, race, class, form and power, its attributes, its auras with their tooltip's
-- text, its gear (in a slot an item by its item string, with its name, quality, stats, kind and set; none in the
-- others), the weapons' enchantments, its talents with their words' figures and its passive spells, its ratings, how
-- it moves. Returns what puts the fake back as it was. (The addon's own caches of the talents and spells known are
-- the caller's: the game's events for them.)
function F.Replay(state)
    local globals, fields = {}, {}
    local function set(name, value)
        if not globals[name] then
            globals[name] = { _G[name] }
        end
        _G[name] = value
    end
    local function field(t, k, v)
        fields[#fields + 1] = { t, k, t[k] }
        t[k] = v
    end
    local function copy(t)
        local out = {}
        for k, v in pairs(type(t) == "table" and t or {}) do
            out[k] = type(v) == "table" and copy(v) or v
        end
        return out
    end
    local unitLevel, powerMax = UnitLevel, UnitPowerMax
    set("UnitLevel", function(unit)
        if unit == "player" then
            return state.level
        end
        return unitLevel(unit)
    end)
    set("UnitRace", function()
        return unpack(state.race or {})
    end)
    set("UnitClass", function()
        return unpack(state.class or {})
    end)
    set("UnitStat", function(_, i)
        return unpack(state.stats and state.stats[i] or {})
    end)
    set("UnitPowerType", function()
        return unpack(state.power or {})
    end)
    set("UnitPowerMax", function(unit, kind)
        if kind == Enum.PowerType.Mana then
            return state.mana or 0
        end
        return powerMax(unit, kind)
    end)
    set("GetCombatRating", function(kind)
        local r = state.ratings and state.ratings[kind]
        return r and r[1] or 0
    end)
    set("GetCombatRatingBonus", function(kind)
        local r = state.ratings and state.ratings[kind]
        return r and r[2] or 0
    end)
    set("GetUnitSpeed", function()
        return unpack(state.move or {})
    end)
    local moving = state.moving or {}
    set("IsSwimming", function()
        return moving.swimming == true
    end)
    set("IsFlying", function()
        return moving.flying == true
    end)
    set("IsFalling", function()
        return moving.falling == true
    end)
    field(F, "mounted", moving.mounted == true)
    field(F, "form", state.form)
    local auras = state.auras or {}
    field(F, "auras", { HELPFUL = copy(auras.HELPFUL), HARMFUL = copy(auras.HARMFUL) })
    local items, kinds = state.items or {}, {}
    for _, i in pairs(items) do
        local id = tonumber(tostring(i.item):match("item:(%-?%d+)"))
        if id then
            kinds[id] = { class = i.class, subclass = i.subclass, set = i.set, quality = i.quality }
        end
    end
    field(F, "items", kinds)
    set("GetInventoryItemLink", function(_, slot)
        local i = items[slot]
        return i and ("|cffffffff|H" .. tostring(i.item) .. "|h[" .. tostring(i.name or ("Objet " .. slot)) .. "]|h|r")
            or nil
    end)
    set("GetInventoryItemQuality", function(_, slot)
        return items[slot] and items[slot].quality
    end)
    field(C_Item, "GetItemStats", function(link)
        local item = tostring(link):match("|H(item:[^|]+)|h")
        for _, i in pairs(items) do
            if i.item == item then
                return copy(i.stats)
            end
        end
        return {}
    end)
    field(F, "weaponEnchants", copy(state.enchants))
    local talents, names = {}, copy(F.spellNames)
    for i, t in ipairs(state.talents or {}) do
        talents[i] = { spell = t.spell, rank = t.rank, ranks = t.ranks, says = t.says and table.concat(t.says, " ") }
        names[t.spell] = t.name or names[t.spell]
    end
    field(F, "talents", talents)
    field(F, "spellNames", names)
    local known = {}
    for _, spell in ipairs(state.known or {}) do
        known[spell] = true
    end
    field(F, "known", known)
    return function()
        for name, v in pairs(globals) do
            _G[name] = v[1]
        end
        for i = #fields, 1, -1 do
            local f = fields[i]
            f[1][f[2]] = f[3]
        end
    end
end

-- The currencies shown on the backpack: F.currencies { name, quantity, iconFileID }.
F.currencies = { { name = "Points d'honneur", quantity = 1250, iconFileID = 136031 } }
C_CurrencyInfo = C_CurrencyInfo or {}
C_CurrencyInfo.GetBackpackCurrencyInfo = function(i)
    return F.currencies[i]
end

-- The zone's levels' colour; the calendar's day: F.dayEvents { title, calendarType, startTime }.
function GetCreatureDifficultyColor()
    return { r = 1, g = 1, b = 0 }
end
F.today = { year = 2026, month = 11, monthDay = 16, hour = 15, minute = 0 }
F.calendarMonth = { year = 2026, month = 11 }
F.dayEvents = { { title = "Foire de Sombrelune", calendarType = "HOLIDAY", startTime = { hour = 0, minute = 0 } } }
F.pendingInvites = 1
C_DateAndTime = C_DateAndTime or {}
C_DateAndTime.GetCurrentCalendarTime = function()
    return F.today
end
C_Calendar = {
    OpenCalendar = function()
        F.calendarOpened = (F.calendarOpened or 0) + 1
    end,
    GetMonthInfo = function(offset)
        return { year = F.calendarMonth.year, month = F.calendarMonth.month + (offset or 0) }
    end,
    -- today only: an offset that doesn't reach this month, or another day, has none
    GetNumDayEvents = function(offset, day)
        local month = F.calendarMonth.month + offset
        return (month == F.today.month and day == F.today.monthDay) and #F.dayEvents or 0
    end,
    GetDayEvent = function(_, _, i)
        return F.dayEvents[i]
    end,
    GetNumPendingInvites = function()
        return F.pendingInvites or 0
    end,
}

-- The guild: F.guild { name, motd, members = { { name, level, zone, online, class } } } or nil out of one.
F.guild = { name = "Les Veilleurs", motd = "Raid ce soir à 21 h, venez nombreux avec potions et nourriture",
    members = { { name = "Ikar-Forever", level = 32, zone = "Marche de l'Ouest", online = true, class = "WARRIOR" },
        { name = "Lysa-Forever", level = 30, zone = "Hurlevent", online = true, class = "MAGE" },
        { name = "Brom-Forever", level = 12, zone = "Dun Morogh", online = false, class = "PALADIN" } } }
function IsInGuild()
    return F.guild ~= nil
end
function GetGuildInfo()
    return F.guild and F.guild.name
end
function GetNumGuildMembers()
    return F.guild and #F.guild.members or 0, 0
end
function GetGuildRosterInfo(i)
    local m = F.guild and F.guild.members[i]
    if m then
        return m.name, "Membre", 1, m.level, m.class, m.zone, "", "", m.online, 0, m.class
    end
end
function Ambiguate(name)
    return (name:gsub("%-.*$", ""))
end
C_GuildInfo = C_GuildInfo or {}
C_GuildInfo.GuildRoster = function()
    F.rosterAsked = (F.rosterAsked or 0) + 1
end
C_GuildInfo.GetMOTD = function()
    return F.guild and F.guild.motd or ""
end
function ToggleGuildFrame()
    F.toggled.guild = (F.toggled.guild or 0) + 1
end

-- Friends: F.friends { name, level, area, connected }, F.bnetOnline.
F.friends = { { name = "Tella", level = 25, area = "Les Paluns", connected = true }, { name = "Orm", level = 9, connected = false } }
F.bnetOnline = 2
C_FriendList = C_FriendList or {}
C_FriendList.GetNumFriends = function()
    return #F.friends
end
C_FriendList.GetFriendInfoByIndex = function(i)
    return F.friends[i]
end
function BNGetNumFriends()
    return 5, F.bnetOnline
end
function ToggleFriendsFrame(tab)
    F.toggled.friends = tab
end
ChatFrameUtil.SendTell = function(name)
    F.toldTo = name
end

-- The group's rules: F.lootMethod (Enum.LootMethod's), F.lootThreshold, F.difficulty; the party asked.
F.lootMethod, F.lootThreshold, F.difficulty = 3, 2, 1
C_PartyInfo = C_PartyInfo or {}
C_PartyInfo.GetLootMethod = function()
    return F.lootMethod
end
-- set as the game sets them, the player the group's leader while F.leader (F.lootMaster: the master looter named)
C_PartyInfo.SetLootMethod = function(method, master)
    F.lootMethod, F.lootMaster = method, master
    return true
end
C_PartyInfo.IsLootMethodAvailable = function(method)
    return method ~= 0 and method ~= 1
end
function SetLootThreshold(quality)
    F.lootThreshold = quality
end
function UnitIsGroupLeader(unit)
    return unit == "player" and F.leader == true
end
C_PartyInfo.InviteUnit = function(name)
    F.invited = name
end
function GetLootThreshold()
    return F.lootThreshold
end
function GetDungeonDifficultyID()
    return F.difficulty
end
function GetDifficultyInfo(id)
    return id == 1 and "Normal" or nil
end
function ResetInstances()
    F.instancesReset = (F.instancesReset or 0) + 1
end
LOOT_GROUP_LOOT, ITEM_QUALITY2_DESC = "Butin : Butin de groupe", "Inhabituel"
LOOT_MASTER_LOOTER, LOOT_NEED_BEFORE_GREED = "Butin : Responsable du butin", "Butin : Le besoin avant la cupidité"
LOOT_FREE_FOR_ALL = "Butin : Accès libre"
ITEM_QUALITY3_DESC, ITEM_QUALITY4_DESC = "Rare", "Épique"
ITEM_QUALITY_COLORS = { [2] = { hex = "|cff1eff00" }, [3] = { hex = "|cff0070dd" }, [4] = { hex = "|cffa335ee" } }

-- The session, away, the achievements and the game's statistics: F.statistics[id] = { name, value }.
F.sessionTime = 4000
function GetSessionTime()
    return F.sessionTime
end
function UnitIsAFK()
    return F.afk == true
end
function GetTotalAchievementPoints()
    return 1230
end
F.statistics = { [60] = { "Morts au total", "17" }, [98] = { "Quêtes terminées", "212" } }
local achievementInfo = GetAchievementInfo
function GetAchievementInfo(id)
    local s = F.statistics[id]
    if s then
        return id, s[1]
    end
    return achievementInfo(id)
end
function GetStatistic(id)
    return F.statistics[id] and F.statistics[id][2] or "--"
end
function ToggleAchievementFrame(stats)
    F.toggled.achievements = stats and "statistics" or "achievements"
end
function ToggleProfessionsBook()
    F.toggled.professions = (F.toggled.professions or 0) + 1
end

-- BugGrabber, as LibsAddonTools carries it: F.luaErrors { message, session, counter }.
F.luaErrors = {}
BugGrabber = {}
function BugGrabber:GetDB()
    return F.luaErrors
end
function BugGrabber:GetSessionId()
    return 7
end
