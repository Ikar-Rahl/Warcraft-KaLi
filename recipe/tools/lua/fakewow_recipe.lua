-- What KaLi Recipe needs of the WoW API on top of the shared fake (tools/lua/fakewow.lua, KaLi Quest's): the
-- character's professions, vendors, trainers, the auction house, loot, quest rewards, bags and bank, the professions
-- window and book, tooltips' data post-calls, chat frames and the world map. State lives in FakeWoW, so the smoke
-- test sets up a visit and fires its events.
local F = FakeWoW

time = os.time
F.unitGUIDs = { player = "Player-1234-0ABCDEF0" }
F.unitNames = { player = "Ikar" }
function UnitGUID(unit)
    if unit == "npc" or unit == "questnpc" then
        return F.npc
    end
    return F.unitGUIDs[unit]
end
function UnitName(unit)
    if unit == "npc" then
        return F.npcName
    end
    return F.unitNames[unit]
end

-- Mixins, as Blizzard's MixinUtil.lua makes them.
function Mixin(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do
            object[k] = v
        end
    end
    return object
end
function CreateFromMixins(...)
    return Mixin({}, ...)
end

-- ---------- Strings and enums ----------

ITEM_SPELL_KNOWN = "Déjà connu"
ITEM_MIN_SKILL = "%s (%d) requis"
PROFESSIONS_USED_IN_COOKING = "Composant d’artisanat"
MISCELLANEOUS = "Divers"
TRADE_SKILLS_LEARNED_TAB = "Appris"
CANCEL = "Annuler"
NONE = "Aucun"
USED = "Déjà connu"
FILTER = "Filtrer"
RESET = "Réinitialiser"
TRADESKILL_FILTER_HAS_SKILL_UP = "Peut faire progresser"
CRAFT_IS_MAKEABLE = "Comp. disponibles"
VIDEO_OPTIONS_ENABLED = "Activé"
VIDEO_OPTIONS_DISABLED = "Désactivé"
MINIMAP_LABEL = "Minicarte"
ITEM_QUALITY_COLORS = { [0] = { r = 0.6, g = 0.6, b = 0.6 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.1, g = 1, b = 0 } }
-- The Enum tables the addon names (ItemClass, TooltipDataType, BagIndex...) aren't written here: the runner puts in
-- this build's own, from the API docs, before this file loads.
function ButtonFrameTemplate_HidePortrait() end
function IsMetaKeyDown()
    return false
end

-- ---------- The character ----------

-- Indexes as GetProfessions gives them on Forever: prof1, prof2, first aid, fishing, cooking.
F.profSlots = { 1, nil, nil, nil, 2 }
F.professions = {
    [1] = { "Enchantement", 136244, 18, 75, 333 },
    [2] = { "Cuisine", 133971, 56, 75, 185 },
}
function GetProfessions()
    local s = F.profSlots
    return s[1], s[2], s[3], s[4], s[5]
end
function GetProfessionInfo(index)
    local p = F.professions[index]
    if p then
        return p[1], p[2], p[3], p[4], 2, 0, p[5], 0, 0, 0, p[1]
    end
end

F.spellNames, F.knownSpells = {}, {}
C_Spell = {
    GetSpellName = function(id)
        return F.spellNames[id]
    end,
    GetSpellLink = function(id)
        return "|cff71d5ff|Hspell:" .. id .. "|h[" .. tostring(F.spellNames[id]) .. "]|h|r"
    end,
    GetSpellTexture = function()
        return 136243
    end,
}
C_SpellBook = {
    IsSpellKnown = function(id)
        return F.knownSpells[id] == true
    end,
}

-- Items: F.itemNames (the shared fake's), F.itemClass, and tooltip lines F.itemTooltips[id] = { "line", ... }.
F.itemClass, F.itemTooltips = {}, {}
C_Item.GetItemInfo = function(id)
    local name = F.itemNames[id]
    if name then
        return name, "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r"
    end
end
C_Item.GetItemInfoInstant = function(id)
    return id, "", "", "", 134400, F.itemClass[id] or 7, 0
end
C_Item.GetItemIconByID = function()
    return 134400
end
C_Item.GetItemQualityByID = function()
    return 1
end

-- Bags: F.bags[bag] = { item or false, ... }, counts in F.bagCounts[bag][slot].
F.bags, F.bagCounts = { [0] = {} }, {}
C_Container = {
    GetContainerNumSlots = function(bag)
        return F.bags[bag] and #F.bags[bag] or 0
    end,
    GetContainerItemID = function(bag, slot)
        local item = F.bags[bag] and F.bags[bag][slot]
        return item or nil
    end,
    GetContainerItemInfo = function(bag, slot)
        local item = F.bags[bag] and F.bags[bag][slot]
        if item then
            return { itemID = item, stackCount = F.bagCounts[bag] and F.bagCounts[bag][slot] or 1 }
        end
    end,
}

-- As the game's: the item's name first, then its lines. An item whose data hasn't loaded yet (F.itemUnloaded[id]) has
-- no lines.
F.itemUnloaded = {}
local function tooltipData(kind, id)
    local lines = {}
    if not F.itemUnloaded[id] then
        lines[1] = { leftText = F.itemNames[id] or ("item " .. id), leftColor = { r = 1, g = 1, b = 1 } }
        for _, text in ipairs(F.itemTooltips[id] or {}) do
            lines[#lines + 1] = { leftText = text, leftColor = { r = 0.4, g = 0.73, b = 1 } }
        end
    end
    return { type = kind, id = id, lines = lines }
end

-- F.trainer[i] = { name, kind, skillName, rank, tooltipSpell, itemLink }
F.trainer = {}
C_TooltipInfo = {
    GetBagItem = function(bag, slot)
        local item = F.bags[bag] and F.bags[bag][slot]
        return item and tooltipData(0, item) or nil
    end,
    GetItemByID = function(id)
        return tooltipData(0, id)
    end,
    GetTrainerService = function(i)
        local s = F.trainer[i]
        return s and s[5] and { type = 1, id = s[5], lines = {} } or { type = 1, lines = {} }
    end,
}

-- Tooltip data post-calls, run by the tooltip's SetItemByID and SetSpellByID.
F.postCalls = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn)
        F.postCalls[kind] = F.postCalls[kind] or {}
        table.insert(F.postCalls[kind], fn)
    end,
}
local function runPostCalls(tooltip, kind, id)
    for _, fn in ipairs(F.postCalls[kind] or {}) do
        fn(tooltip, tooltipData(kind, id))
    end
end
function GameTooltip:SetItemByID(id)
    F.tooltip.lines[#F.tooltip.lines + 1] = tostring(F.itemNames[id] or id)
    runPostCalls(self, 0, id)
end
function GameTooltip:SetSpellByID(id)
    F.tooltip.lines[#F.tooltip.lines + 1] = tostring(F.spellNames[id] or id)
    runPostCalls(self, 1, id)
end
function GameTooltip:AddDoubleLine(left, right)
    F.tooltip.lines[#F.tooltip.lines + 1] = tostring(left) .. " | " .. tostring(right)
end
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent)

-- ---------- Chat ----------

ChatTypeInfo = { SKILL = { r = 0.33, g = 0.33, b = 1 } }
NUM_CHAT_WINDOWS = 1
F.chat = {}
ChatFrame1 = CreateFrame("Frame", "ChatFrame1", UIParent)
function ChatFrame1:ContainsMessageGroup(group)
    return group == "SKILL"
end
function ChatFrame1:AddMessage(text, r, g, b)
    F.chat[#F.chat + 1] = { text = text, r = r, g = g, b = b }
end
DEFAULT_CHAT_FRAME = ChatFrame1
ChatFrameUtil.InsertLink = function(link)
    F.inserted = link
    return true
end

-- ---------- Vendors, trainers, loot, quests ----------

F.merchant = {}
MERCHANT_ITEMS_PER_PAGE = 10
MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.page, MerchantFrame.selectedTab = 1, 1
for i = 1, MERCHANT_ITEMS_PER_PAGE do
    CreateFrame("Button", "MerchantItem" .. i .. "ItemButton", MerchantFrame)
end
function MerchantFrame_UpdateMerchantInfo() end
function MerchantFrame_UpdateBuybackInfo() end
function GetMerchantNumItems()
    return #F.merchant
end
function GetMerchantItemID(i)
    return F.merchant[i]
end
-- Prices: F.merchantPrices[item] in copper; F.merchantCosts[item] = { { texture, count, link } } for an extended cost.
F.merchantPrices, F.merchantCosts = {}, {}
C_MerchantFrame = C_MerchantFrame or {}
C_MerchantFrame.GetItemInfo = function(i)
    local item = F.merchant[i]
    if not item then
        return nil
    end
    return { name = F.itemNames[item], texture = 0, price = F.merchantPrices[item] or 0, stackCount = 1, numAvailable = -1,
        isPurchasable = true, isUsable = true, hasExtendedCost = F.merchantCosts[item] ~= nil, isQuestStartItem = false }
end
function GetMerchantItemCostInfo(i)
    local costs = F.merchantCosts[F.merchant[i]]
    return costs and #costs or 0
end
function GetMerchantItemCostItem(i, n)
    local c = F.merchantCosts[F.merchant[i]]
    c = c and c[n]
    if c then
        return c[1], c[2], c[3], nil
    end
end

function IsTradeskillTrainer()
    return true
end
function GetNumTrainerServices()
    return #F.trainer
end
function GetTrainerServiceInfo(i)
    local s = F.trainer[i]
    if s then
        return s[1], "", s[2], false
    end
end
function GetTrainerServiceSkillReq(i)
    local s = F.trainer[i]
    if s then
        return s[3], s[4], true
    end
end
function GetTrainerServiceItemLink(i)
    local s = F.trainer[i]
    return s and s[6]
end
function GetTrainerServiceCost(i)
    local s = F.trainer[i]
    return s and s[7] or 0, true
end

-- F.loot[slot] = { link, sourceGUID }
F.loot = {}
function GetNumLootItems()
    return #F.loot
end
function GetLootSlotLink(slot)
    return F.loot[slot] and F.loot[slot][1]
end
function GetLootSourceInfo(slot)
    return F.loot[slot] and F.loot[slot][2], 1
end

F.questRewards, F.questChoices = {}, {}
function GetNumQuestRewards()
    return #F.questRewards
end
function GetNumQuestChoices()
    return #F.questChoices
end
function GetQuestItemLink(kind, i)
    return (kind == "reward" and F.questRewards or F.questChoices)[i]
end
function GetTitleText()
    return F.questTitle
end
C_QuestLog.GetTitleForQuestID = function()
    return nil
end

-- ---------- The auction house ----------

F.ahResults, F.ahRows = {}, {}
C_AuctionHouse = {
    SendBrowseQuery = function(query)
        F.ahQuery = query
    end,
    GetBrowseResults = function()
        return F.ahResults
    end,
    -- F.ahBusy: another addon's query going (Auctionator's scans); the game queues what's sent meanwhile.
    IsThrottledMessageSystemReady = function()
        return not F.ahBusy
    end,
}
AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
AuctionHouseFrame.BrowseResultsFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
local itemList = CreateFrame("Frame", nil, AuctionHouseFrame.BrowseResultsFrame)
AuctionHouseFrame.BrowseResultsFrame.ItemList = itemList
function itemList:CallRefreshCallback() end
itemList.ScrollBox = CreateFrame("Frame", nil, itemList)
function itemList.ScrollBox:ForEachFrame(fn)
    for _, row in ipairs(F.ahRows) do
        fn(row)
    end
end
-- A browse row as Blizzard's table builder makes it (AuctionHouseTableBuilder.GetBrowseListLayout): the price first
-- (a Text and the money), then the item (its icon and name), the quantity, the favourite's star. The cells' widths are
-- the columns' less their padding, with the game's copper prices: 168 - 14, the rest, 60 - 10, 29 - 15.
function F.AuctionRow(item, count)
    local row = CreateFrame("Button", nil, itemList.ScrollBox)
    row.rowData = { itemKey = { itemID = item } }
    local price, name, quantity, favourite = CreateFrame("Frame", nil, row), CreateFrame("Frame", nil, row),
        CreateFrame("Frame", nil, row), CreateFrame("Frame", nil, row)
    price.Text, price.MoneyDisplay = price:CreateFontString(), CreateFrame("Frame", nil, price)
    name.Icon, name.IconBorder, name.Text = name:CreateTexture(), name:CreateTexture(), name:CreateFontString()
    quantity.Text = quantity:CreateFontString()
    quantity.Text:SetText(tostring(count or 1))
    favourite.FavoriteButton = CreateFrame("Button", nil, favourite)
    price:SetWidth(154)
    name:SetWidth(400)
    quantity:SetWidth(50)
    favourite:SetWidth(14)
    row.cells = { price, name, quantity, favourite }
    F.ahRows[#F.ahRows + 1] = row
    return row
end

-- ---------- The professions window and book ----------

F.windowRecipes, F.windowLearned, F.windowCats = {}, {}, {}
C_TradeSkillUI.GetBaseProfessionInfo = function()
    return F.openProfession and { professionID = F.openProfession, professionName = "Cuisine" } or nil
end
C_TradeSkillUI.GetChildProfessionInfo = function()
    return nil
end
C_TradeSkillUI.IsTradeSkillReady = function()
    return F.openProfession ~= nil
end
C_TradeSkillUI.IsTradeSkillLinked = function()
    return false
end
C_TradeSkillUI.IsTradeSkillGuild = function()
    return false
end
C_TradeSkillUI.IsNPCCrafting = function()
    return false
end
C_TradeSkillUI.GetFilteredRecipeIDs = function()
    return F.windowRecipes
end
C_TradeSkillUI.GetRecipeInfo = function(id)
    return { recipeID = id, learned = F.windowLearned[id] ~= false, categoryID = F.windowCats[id] }
end
C_TradeSkillUI.GetCategoryInfo = function()
    return nil
end
C_TradeSkillUI.GetProfessionInfoBySkillLineID = function()
    return nil
end
C_TradeSkillUI.GetTradeSkillDisplayName = function()
    return nil
end
function OpenProfessionUIToSkillLine(skill)
    F.openedSkill = skill
end

local function book(name)
    local f = CreateFrame("Frame", name, UIParent)
    f.ProfessionsContentFrame = CreateFrame("Frame", nil, f)
    for _, key in ipairs({ "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2",
        "SecondaryProfession3" }) do
        local slot = CreateFrame("Frame", nil, f.ProfessionsContentFrame)
        slot.StatusBar = CreateFrame("StatusBar", nil, slot)
        f.ProfessionsContentFrame[key] = slot
    end
    f:Hide()
    return f
end
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
ProfessionsFrame.CraftingPage = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage.RankBar = CreateFrame("Frame", nil, ProfessionsFrame.CraftingPage)
ProfessionsFrame.BookPage = book(nil)
ProfessionsFrame:Hide()
ProfessionsBookFrame = book("ProfessionsBookFrame")

-- ---------- Bags' frames ----------

NUM_CONTAINER_FRAMES = 1
ContainerFrame1 = CreateFrame("Frame", "ContainerFrame1", UIParent)
ContainerFrame1.buttons = {}
function ContainerFrame1:UpdateItems() end
function ContainerFrame1:EnumerateValidItems()
    local i = 0
    return function()
        i = i + 1
        local b = self.buttons[i]
        if b then
            return i, b
        end
    end
end
function F.BagButton(bag, slot)
    local b = CreateFrame("Button", nil, ContainerFrame1)
    function b:GetBagID()
        return bag
    end
    function b:GetID()
        return slot
    end
    table.insert(ContainerFrame1.buttons, b)
    return b
end

-- ---------- The world map ----------

F.mapNames = { [1457] = "Darnassus", [1438] = "Teldrassil", [1436] = "Marche de l'Ouest" }
C_Map.GetMapInfo = function(id)
    return F.mapNames[id] and { mapID = id, name = F.mapNames[id] } or nil
end
C_Map.CanSetUserWaypointOnMap = function()
    return true
end
C_Map.SetUserWaypoint = function(point)
    F.waypoint = point
end
C_SuperTrack.SetSuperTrackedUserWaypoint = function(on)
    F.superTracked = on
end
UiMapPoint = {
    CreateFromCoordinates = function(map, x, y)
        return { uiMapID = map, position = CreateVector2D(x, y) }
    end,
}
-- Blizzard's pin mixin, the parts a pin uses (MapCanvas_DataProviderBase.lua).
MapCanvasPinMixin = {}
function MapCanvasPinMixin:OnLoad() end
function MapCanvasPinMixin:OnAcquired() end
function MapCanvasPinMixin:OnMouseEnter() end
function MapCanvasPinMixin:OnMouseLeave() end
function MapCanvasPinMixin:DisableInheritedMotionScriptsWarning()
    return false
end
function MapCanvasPinMixin:SetPosition(x, y)
    self.x, self.y = x, y
end
function MapCanvasPinMixin:SetScalingLimits(scaleFactor, startScale, endScale)
    self.scaleFactor, self.startScale, self.endScale = scaleFactor, startScale, endScale
end
function MapCanvasPinMixin:OnMouseUp(button)
    if self.OnMouseClickAction then
        self:OnMouseClickAction(button)
    end
end
MapCanvasDataProviderMixin = {}
function MapCanvasDataProviderMixin:GetMap()
    return self.owningMap
end
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
F.pins = {}
function WorldMapFrame:AddDataProvider(provider)
    provider.owningMap = self
    self.provider = provider
end
function WorldMapFrame:GetMapID()
    return F.mapShown or 1457
end
-- As Blizzard_MapCanvas.lua's AcquirePin: a frame from the template (the fake's CreateFrame builds it as the XML says);
-- a new pin with the mouse gets the map's own OnEnter and OnLeave, after the map asserts the template has none, and
-- the map's mouse-up handler; then OnLoad, then OnAcquired. A real error, as in game, if a template breaks the rule.
function WorldMapFrame:AcquirePin(template, ...)
    local pin = CreateFrame("Frame", nil, self, template)
    if pin:IsMouseEnabled() then
        if not pin:DisableInheritedMotionScriptsWarning() then
            assert(pin:GetScript("OnEnter") == nil, template .. ": the map asserts a pin template has no OnEnter of its own")
            assert(pin:GetScript("OnLeave") == nil, template .. ": the map asserts a pin template has no OnLeave of its own")
        end
        pin:SetScript("OnEnter", pin.OnMouseEnter)
        pin:SetScript("OnLeave", pin.OnMouseLeave)
        pin:SetScript("OnMouseUp", pin.OnMouseUp)
    end
    pin:OnLoad()
    pin:OnAcquired(...)
    pin:Show()
    F.pins[#F.pins + 1] = pin
    return pin
end
function WorldMapFrame:RemoveAllPinsByTemplate()
    for _, pin in ipairs(F.pins) do
        pin:Hide()
    end
    F.pins = {}
end

-- Mask textures, which the shared fake doesn't make: frames made from here on can. And the addon's own XML templates,
-- which the runner reads from its XML files into F.xmlTemplates[name] = { kind, mixin, mouse, scripts }: the frame
-- gets the mixin (missing, the game fails to make the frame), the mouse, and each script as the method it names.
F.xmlTemplates = F.xmlTemplates or {}
local baseCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = baseCreateFrame(kind, name, parent, template)
    f.CreateMaskTexture = function()
        return baseCreateFrame("MaskTexture")
    end
    local t = template and F.xmlTemplates[template]
    if t then
        if t.mixin ~= "" then
            local mixin = _G[t.mixin]
            assert(type(mixin) == "table", template .. ": its mixin " .. t.mixin .. " doesn't exist yet")
            Mixin(f, mixin)
        end
        f:EnableMouse(t.mouse)
        for script, method in pairs(t.scripts) do
            f:SetScript(script, f[method] or error(template .. ": no method " .. tostring(method) .. " for " .. script))
        end
    end
    -- Blizzard's corner grip (PanelResizeButtonMixin, SharedUIPanelTemplates.lua): Init takes the window and its
    -- bounds and wraps its OnSizeChanged, which keeps the bounds and calls resizeCallback while the grip is held; the
    -- mouse down starts sizing, the mouse up stops it and calls resizeStoppedCallback.
    if template == "PanelResizeButtonTemplate" then
        function f:Init(target, minW, minH, maxW, maxH)
            self.target, self.minWidth, self.minHeight, self.maxWidth, self.maxHeight = target, minW, minH, maxW, maxH
            local original = target:GetScript("OnSizeChanged") or function() end
            target:SetScript("OnSizeChanged", function(t, w, h)
                original(t, w, h)
                if not self.isActive then
                    return
                end
                w = math.max(self.minWidth, math.min(self.maxWidth or w, w))
                h = math.max(self.minHeight, math.min(self.maxHeight or h, h))
                t:SetSize(w, h)
                if self.resizeCallback then
                    self.resizeCallback(self, w, h, self.isActive)
                end
            end)
        end
        f:SetScript("OnMouseDown", function(self)
            self.isActive = true
            self.target.sizing = "BOTTOMRIGHT"
        end)
        f:SetScript("OnMouseUp", function(self)
            self.isActive = false
            self.target.sizing = nil
            if self.resizeStoppedCallback then
                self.resizeStoppedCallback(self.target)
            end
        end)
    end
    -- Blizzard's ButtonFrameTemplate: its border a child frame at level 500, its title and close button at 510, and
    -- its inset ($parentInset, InsetFrameTemplate) at its own level.
    if template == "ButtonFrameTemplate" then
        f.Inset = baseCreateFrame("Frame", name and (name .. "Inset") or nil, f)
        f.Inset:SetFrameLevel(f:GetFrameLevel())
        f.NineSlice = baseCreateFrame("Frame", nil, f, "NineSlicePanelTemplate")
        f.CloseButton = baseCreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton:SetPoint("TOPRIGHT", 0, 3)
    end
    return f
end

-- Sounds: PlaySound returns whether it will play and a handle, as in game; F.sounds lists the kits played with their
-- handles, F.stopped the handles StopSound was given, with the fade-out in milliseconds.
F.sounds, F.stopped, F.soundHandle = {}, {}, 0
function PlaySound(kit)
    F.soundHandle = F.soundHandle + 1
    F.sounds[#F.sounds + 1] = { kit = kit, handle = F.soundHandle }
    return F.soundRefused ~= kit, F.soundHandle
end
function StopSound(handle, fade)
    F.stopped[handle] = fade or 0
end
F.cvars.Sound_EnableAllSound, F.cvars.Sound_EnableSFX = "1", "1"
C_CVar.GetCVar = function(name)
    return F.cvars[name]
end

-- As the game's AddOnSettingMixin:Init (Blizzard_Setting.lua, SecureSetVariableTblDefaultValue): a setting writes its
-- default into the saved table when the key is nil. The addon's options read their defaults through, so nothing gets
-- written; the smoke test checks it.
do
    local register = Settings.RegisterAddOnSetting
    Settings.RegisterAddOnSetting = function(category, variable, key, tbl, varType, name, default)
        if tbl[key] == nil then
            tbl[key] = default
        end
        return register(category, variable, key, tbl, varType, name, default)
    end
end

-- What the API check looks for that the shared fake lacks: the font objects the addon names, and a few globals.
for _, name in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontDisable", "GameFontDisableSmall" }) do
    _G[name] = _G[name] or CreateFont(name)
end
NUM_BAG_SLOTS = 4
ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", UIParent)
ContainerFrameCombinedBags:Hide()
MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }

-- The minimap, round unless a test sets F.minimapShape (SexyMap and the like define GetMinimapShape), and the pointer.
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(198, 198)
function GetMinimapShape()
    return F.minimapShape or "ROUND"
end
F.cursor = { 0, 0 }
function GetCursorPosition()
    return F.cursor[1], F.cursor[2]
end
WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, 1

-- LibStub and LibDataBroker-1.1 as an information bar such as Titan Panel loads them, reduced to what the addon calls.
-- F.ldb.objects holds what was registered, as the bar would list it.
F.ldb = { objects = {} }
function F.ldb:NewDataObject(name, object)
    if self.objects[name] then
        return nil
    end
    self.objects[name] = object
    return object
end
function F.ldb:GetDataObjectByName(name)
    return self.objects[name]
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
