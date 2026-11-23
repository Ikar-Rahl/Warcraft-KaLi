-- What the character carries (Ikar 2026-11-16: "ammo", "reagent (folder)", "junk", "currencies"): the ammunition in its
-- slot, the reagents its class's spells take, the grey items' worth in its bags, the currencies it chose to show on
-- its backpack in the game's currency window. Counts only: using any is the action bar's, selling the junk the vendor's
-- own « Vendre toute la camelote ».
local _, ns = ...

local Infos, Hub, L, Format = ns.Infos, ns.Hub, ns.L, ns.Format

local SEP = ns.Seeds.SEP
-- The class, read once the game knows it.
local function class()
    local _, c = UnitClass("player")
    return c
end

-- ---------- Ammunition ----------

local AMMO = "KaLiHUD_Ammo"
-- The classes that fire it: bows, guns and crossbows are theirs.
local SHOOTERS = { HUNTER = true, ROGUE = true, WARRIOR = true }
local AMMO_SLOT = INVSLOT_AMMO or 0

Hub.Add(AMMO, {
    type = "data source", text = "", category = "character", home = "reagents", label = ns.G("INVTYPE_AMMO", "Ammo"),
    available = function()
        return SHOOTERS[class()] == true
    end,
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("INVTYPE_AMMO", "Ammo"))
        local link = GetInventoryItemLink("player", AMMO_SLOT)
        Infos.Line(tooltip, link or L.AMMO_NONE, tostring(GetInventoryItemCount("player", AMMO_SLOT) or 0))
        Infos.Hint(tooltip, L.HINT_CHARACTER)
    end,
    OnClick = Infos.Opener(function()
        ToggleCharacter("PaperDollFrame")
    end),
}, "hidden", 300)

local function updateAmmo()
    local count = GetInventoryItemLink("player", AMMO_SLOT) and (GetInventoryItemCount("player", AMMO_SLOT) or 0) or 0
    Hub.Set(AMMO, "icon", GetInventoryItemTexture("player", AMMO_SLOT) or 132382)
    Hub.Set(AMMO, "text", count > 0 and Format.Number(count) or Infos.Color("0", Infos.BAD))
end
Infos.Updates(updateAmmo, { "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED" })

-- ---------- Reagents ----------

-- Each class's reagents in Forever's items (checked in its Item table, 2026-11-16): the spells' that use them.
local REAGENTS = {
    MAGE = { 17020, 17031, 17032, 17056 },
    PRIEST = { 17028, 17029, 17056 },
    PALADIN = { 17033, 21177 },
    SHAMAN = { 17030, 17057, 17058 },
    WARLOCK = { 6265, 5565, 16583 },
    DRUID = { 17021, 17026, 17034, 17035, 17036, 17037, 17038 },
    ROGUE = { 5140, 5530 },
}

local reagents = {}
local contents = { AMMO }
local seen = {}
for class, list in pairs(REAGENTS) do
    for _, id in ipairs(list) do
        local name = "KaLiHUD_Reagent_" .. id
        if not seen[id] then
            seen[id] = {}
            contents[#contents + 1] = name
            reagents[#reagents + 1] = { id = id, item = name }
        end
        seen[id][class] = true
    end
end
table.sort(reagents, function(a, b)
    return a.id < b.id
end)
ns.Seeds.Contents.reagents = contents

for i, r in ipairs(reagents) do
    local classes = seen[r.id]
    Hub.Add(r.item, {
        type = "data source", text = "", category = "character", home = "reagents", label = tostring(r.id),
        available = function()
            return classes[class()] == true
        end,
        OnTooltipShow = function(tooltip)
            -- the game's own tooltip of the item, then how many the bags hold
            tooltip:SetHyperlink("item:" .. r.id)
            Infos.Line(tooltip, L.IN_BAGS, tostring(ns.Call(C_Item.GetItemCount, r.id) or 0))
        end,
    }, "hidden", 310 + i)
end

local function updateReagents()
    for _, r in ipairs(reagents) do
        if seen[r.id][class()] then
            local n = ns.Call(C_Item.GetItemCount, r.id) or 0
            local name = ns.Call(C_Item.GetItemNameByID, r.id)
            if name then
                Hub.Set(r.item, "label", name)
            else
                ns.Call(C_Item.RequestLoadItemDataByID, r.id)
            end
            Hub.Set(r.item, "icon", ns.Call(C_Item.GetItemIconByID, r.id) or 134400)
            Hub.Set(r.item, "text", n > 0 and Format.Number(n) or Infos.Color("0", Infos.BAD))
        end
    end
end
Infos.Updates(updateReagents, { "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" })

-- ---------- Junk ----------

local JUNK = "KaLiHUD_Junk"
local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0

-- The grey items in the bags: how many, and what a vendor gives for them.
local function junk()
    local last = Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or 4
    local count, worth = 0, 0
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = ns.Call(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.quality == POOR and not info.hasNoValue and info.itemID then
                local price = select(11, C_Item.GetItemInfo(info.itemID))
                count = count + (info.stackCount or 1)
                worth = worth + (type(price) == "number" and price or 0) * (info.stackCount or 1)
            end
        end
    end
    return count, worth
end

Hub.Add(JUNK, {
    type = "data source", text = "", atlas = "bags-icon-junk", category = "character", home = "infos", label = L.ITEM_JUNK,
    OnTooltipShow = function(tooltip)
        local count, worth = junk()
        Infos.Title(tooltip, L.ITEM_JUNK)
        Infos.Line(tooltip, L.JUNK_COUNT, tostring(count))
        Infos.Line(tooltip, ns.G("SELL_PRICE", "Sell Price"), worth > 0 and GetMoneyString(worth, true) or "0")
        Infos.Hint(tooltip, string.format(L.HINT_JUNK, ns.G("SELL_ALL_JUNK_ITEMS", "Sell All Junk")))
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            ToggleAllBags()
        end
    end,
}, "hidden", 400)

local function updateJunk()
    local _, worth = junk()
    Hub.Set(JUNK, "text", worth > 0 and GetMoneyString(worth, true) or "0")
end
Infos.Updates(updateJunk, { "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED" })

-- ---------- Currencies ----------

local CURRENCIES = "KaLiHUD_Currencies"
-- The backpack's own count of them, at most.
local MAX_SHOWN = 10

-- Those the player chose to show on the backpack, in the game's order: { name, quantity, icon }.
local function watched()
    local list = {}
    for i = 1, MAX_SHOWN do
        local info = ns.Call(C_CurrencyInfo.GetBackpackCurrencyInfo, i)
        if type(info) ~= "table" then
            break
        end
        list[#list + 1] = { name = info.name, quantity = info.quantity or 0, icon = info.iconFileID }
    end
    return list
end

Hub.Add(CURRENCIES, {
    type = "data source", text = "", category = "character", home = "infos", label = ns.G("CURRENCY", "Currencies"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("CURRENCY", "Currencies"))
        local list = watched()
        for _, c in ipairs(list) do
            Infos.Line(tooltip, (c.icon and ("|T" .. c.icon .. ":0|t ") or "") .. tostring(c.name), Format.Number(c.quantity))
        end
        if #list == 0 then
            Infos.Hint(tooltip, string.format(L.CURRENCY_NONE, ns.G("SHOW_ON_BACKPACK", "Show on Backpack")))
        end
        Infos.Hint(tooltip, L.HINT_CURRENCY)
    end,
    OnClick = Infos.Opener(function()
        ToggleCharacter("TokenFrame")
    end),
}, "hidden", 410)

local function updateCurrencies()
    local parts = {}
    for _, c in ipairs(watched()) do
        parts[#parts + 1] = (c.icon and ("|T" .. c.icon .. ":0|t") or "") .. Format.Number(c.quantity)
    end
    Hub.Set(CURRENCIES, "text", #parts > 0 and table.concat(parts, " ") or ns.G("CURRENCY", "Currencies"))
end
Infos.Updates(updateCurrencies, { "PLAYER_ENTERING_WORLD", "CURRENCY_DISPLAY_UPDATE" })

-- The others' folder: what doesn't belong to any of the rest.
ns.Seeds.Contents.infos = { JUNK, CURRENCIES, SEP, "KaLiHUD_ZonePvP", "KaLiHUD_ZoneLevel", SEP, "KaLiHUD_Today",
    "KaLiHUD_Alarm", "KaLiHUD_Stopwatch" }
