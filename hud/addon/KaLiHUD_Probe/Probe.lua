-- KaLi HUD's probe: what this client answers to the questions the plan couldn't settle from Blizzard's source.
-- It changes nothing of the game's unless asked (/khprobe move), and keeps its findings in KaLiHUDProbeDB.
--   /khprobe              the passive checks (also 3 seconds after login, and after each Edit Mode exit)
--   /khprobe move <frame> <dx> <dy>   in Edit Mode only: moves an Edit Mode frame as a drag would; Revert undoes it
--   /khprobe blocked      the blocked actions and Lua warnings seen since login
--   /khprobe talents      every talent of the class's trees: its ranks, the game's tooltip at each, KaLi HUD's values
--   /khprobe show         the report so far
KaLiHUDProbeDB = KaLiHUDProbeDB or {}
local frame = CreateFrame("Frame")
local report

-- Everything KaLi HUD may hold, by global name.
local FRAMES = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar",
    "MultiCastActionBarFrame", "MainMenuBarVehicleLeaveButton", "OverrideActionBar",
    "MicroMenuContainer", "MicroMenu", "BagsBar", "MainMenuBarBackpackButton",
    "ChatFrame1", "GeneralDockManager", "ChatFrame1EditBox", "DamageMeter", "DamageMeterSessionWindow1",
    "MinimapCluster", "Minimap", "MinimapZoneText", "TimeManagerClockButton", "GameTimeFrame",
    "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
    "FlareUI_XPBar", "FlareUI_ThreatMeter", "PlayerFrame", "TargetFrame", "PlayerCastingBarFrame",
}

local function say(msg)
    print("|cffffd200KaLi HUD probe :|r " .. tostring(msg))
end

local function dump(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then
        return type(v) == "string" and string.format("%q", v) or tostring(v)
    end
    if depth > 3 then
        return "{...}"
    end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = tostring(k) .. "=" .. dump(v[k], depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function call(fn, ...)
    if type(fn) ~= "function" then
        return "missing"
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return "error: " .. tostring(a)
    end
    return a, b, c, d
end

local function note(section, key, value)
    report[section] = report[section] or {}
    report[section][key] = type(value) == "table" and dump(value) or tostring(value)
end

local function round(v)
    return type(v) == "number" and math.floor(v * 10 + 0.5) / 10 or v
end

-- A region's rectangle in UIParent's units, whatever its own scale.
local function rect(f)
    local left, bottom, width, height = f:GetRect()
    if not left then
        return "no position"
    end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return string.format("left %s bottom %s width %s height %s (scale %s)", round(left * k), round(bottom * k), round(width * k), round(height * k), round(f:GetScale()))
end

local function anchor(f)
    local point, relativeTo, relativePoint, x, y = f:GetPoint(1)
    if not point then
        return "none"
    end
    local name = relativeTo and (relativeTo.GetName and relativeTo:GetName() or "?") or "nil"
    return string.format("%s %s %s %s %s (%d points)", point, tostring(name), tostring(relativePoint), round(x), round(y), f:GetNumPoints())
end

-- The Edit Mode settings that size an action bar.
local function barSettings(f)
    local S = Enum.EditModeActionBarSetting
    if not (S and f.GetSettingValue) then
        return "no settings"
    end
    local out = {}
    for _, key in ipairs({ "Orientation", "NumRows", "NumIcons", "IconSize", "IconPadding", "VisibleSetting", "HideBarArt" }) do
        if S[key] then
            out[key] = tostring((call(f.GetSettingValue, f, S[key])))
        end
    end
    return out
end

local function frames()
    for _, name in ipairs(FRAMES) do
        local f = _G[name]
        if not f then
            note("frames", name, "missing")
        else
            local ok, err = pcall(function()
                -- Some names are font strings, which have no strata.
                local parts = {
                    type = f:GetObjectType(),
                    shown = tostring(f:IsShown()) .. "/" .. tostring(f:IsVisible()),
                    protected = tostring(f.IsProtected and (f:IsProtected()) or "n/a"),
                    rect = rect(f),
                    anchor = anchor(f),
                    strata = f.GetFrameStrata and (f:GetFrameStrata() .. " " .. f:GetFrameLevel()) or "n/a",
                    parent = f:GetParent() and (f:GetParent():GetName() or "unnamed") or "nil",
                }
                if f.system then
                    parts.editMode = string.format("system %s index %s default %s canMove %s", tostring(f.system), tostring(f.systemIndex), tostring(f.isInDefaultPosition), tostring((call(f.CanBeMoved, f))))
                end
                if name:find("Bar") and f.GetSettingValue then
                    parts.settings = barSettings(f)
                end
                note("frames", name, parts)
            end)
            if not ok then
                note("frames", name, "error: " .. tostring(err))
            end
        end
    end
    -- Titan Panel's bars, whatever their names on this version.
    local titan = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:find("^Titan_Bar__Display_") and type(v) == "table" then
            pcall(function()
                titan[#titan + 1] = k .. " " .. tostring(v:IsShown()) .. " " .. rect(v)
            end)
        end
    end
    table.sort(titan)
    note("frames", "Titan bars", #titan > 0 and table.concat(titan, " | ") or "none")
end

-- A library another addon loaded, or nil.
local function library(name)
    local stub = _G.LibStub
    return type(stub) == "table" and stub.GetLibrary(stub, name, true) or nil
end

local function editMode()
    note("editMode", "manager", tostring(EditModeManagerFrame ~= nil))
    note("editMode", "Enum.EditModeSystem", Enum.EditModeSystem or "missing")
    note("editMode", "Enum.EditModeActionBarSystemIndices", Enum.EditModeActionBarSystemIndices or "missing")
    if EditModeManagerFrame then
        local info = call(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
        if type(info) == "table" then
            note("editMode", "active layout", string.format("%s type %s", tostring(info.layoutName), tostring(info.layoutType)))
        end
        note("editMode", "Enum.EditModeLayoutType", Enum.EditModeLayoutType or "missing")
        note("editMode", "active", tostring((call(EditModeManagerFrame.IsEditModeActive, EditModeManagerFrame))))
        note("editMode", "OnSystemPositionChange", type(EditModeManagerFrame.OnSystemPositionChange))
        note("editMode", "magnetism", type(EditModeMagnetismManager) == "table" and type(EditModeMagnetismManager.RegisterFrame) or "missing")
    end
    note("editMode", "LibEditModeOverride", tostring(library("LibEditModeOverride-1.0") ~= nil))
    note("editMode", "FlareEditMode", tostring(library("FlareEditMode") ~= nil))
end

local function broker()
    local ldb = library("LibDataBroker-1.1")
    if not ldb then
        note("broker", "LibDataBroker", "missing")
        return
    end
    for name, obj in ldb.DataObjectIterator(ldb) do
        note("broker", name, string.format("type %s text %s icon %s label %s OnClick %s OnTooltipShow %s OnEnter %s",
            tostring(obj.type), tostring(obj.text ~= nil), tostring(obj.icon ~= nil), tostring(obj.label ~= nil),
            type(obj.OnClick), type(obj.OnTooltipShow), type(obj.OnEnter)))
    end
end

-- The game calls the info bar and the status bars would make.
local function apis()
    local version, build = GetBuildInfo()
    note("environment", "build", version .. " " .. build)
    note("environment", "locale", GetLocale())
    note("environment", "screen", string.format("%s x %s units, physical %s x %s, UIParent scale %s",
        round(GetScreenWidth()), round(GetScreenHeight()), tostring((call(GetPhysicalScreenSize))), tostring(select(2, call(GetPhysicalScreenSize))), round(UIParent:GetEffectiveScale())))
    note("apis", "UnitXP", string.format("%s / %s rested %s", tostring((call(UnitXP, "player"))), tostring((call(UnitXPMax, "player"))), tostring((call(GetXPExhaustion)))))
    note("apis", "C_Reputation.GetWatchedFactionData", (C_Reputation and C_Reputation.GetWatchedFactionData) and dump((call(C_Reputation.GetWatchedFactionData))) or "missing")
    note("apis", "GetWatchedFactionInfo", GetWatchedFactionInfo and dump({ call(GetWatchedFactionInfo) }) or "missing")
    note("apis", "honor", (UnitHonor and UnitHonorMax) and string.format("%s / %s", tostring((call(UnitHonor, "player"))), tostring((call(UnitHonorMax, "player")))) or "missing")
    note("apis", "GetFramerate", tostring((call(GetFramerate))))
    note("apis", "GetNetStats", dump({ call(GetNetStats) }))
    note("apis", "GetUnitSpeed", dump({ call(GetUnitSpeed, "player") }))
    note("apis", "GetMoney", tostring((call(GetMoney))))
    note("apis", "C_Container", (C_Container and C_Container.GetContainerNumFreeSlots) and tostring((call(C_Container.GetContainerNumFreeSlots, 0))) or "missing")
    note("apis", "GetInventoryItemDurability", dump({ call(GetInventoryItemDurability, 5) }))
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = call(C_TooltipInfo.GetInventoryItem, "player", 5)
        note("apis", "C_TooltipInfo.GetInventoryItem repairCost", type(data) == "table" and tostring(data.repairCost) or tostring(data))
    else
        note("apis", "C_TooltipInfo.GetInventoryItem", "missing")
    end
    note("apis", "UpdateAddOnMemoryUsage", type(UpdateAddOnMemoryUsage))
    note("apis", "position", dump({ call(function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        return map, pos and round(pos.x * 100), pos and round(pos.y * 100)
    end) }))
    note("apis", "zone", string.format("%s / %s / pvp %s", tostring(GetZoneText()), tostring(GetSubZoneText()), tostring((call(GetZonePVPInfo)))))
    note("apis", "clock", string.format("server %s local %s", dump({ call(GetGameTime) }), date("%H:%M")))
    note("apis", "MenuUtil.CreateContextMenu", (MenuUtil and type(MenuUtil.CreateContextMenu)) or "missing")
    note("apis", "mail", tostring((call(HasNewMail))))
    local cluster = MinimapCluster
    if cluster then
        note("minimap", "pieces", string.format("Tracking %s IndicatorFrame %s ZoneTextButton %s BorderTop %s",
            tostring(cluster.Tracking ~= nil), tostring(cluster.IndicatorFrame ~= nil), tostring(cluster.ZoneTextButton ~= nil), tostring(cluster.BorderTop ~= nil)))
        local mail = cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame
        note("minimap", "MailFrame", mail and rect(mail) or "missing")
        note("minimap", "Tracking", cluster.Tracking and rect(cluster.Tracking) or "missing")
    end
end

-- What KaLi HUD's attributes' tooltips name their sources from (Ikar 2026-11-17: "I don't see the effect of my elixirs
-- and buffs"): each aura on the player as the game gives it (its spell, its points), each worn item's stats by their
-- names, the sheet's sums, the ratings.
local function stats()
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local aura = C_UnitAuras and call(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
            if type(aura) ~= "table" then
                if i == 1 then
                    note("stats", filter, tostring(aura))
                end
                break
            end
            note("stats", string.format("%s %02d", filter, i), string.format("%s spell %s points %s stacks %s",
                tostring(aura.name), tostring(aura.spellId), dump(aura.points), tostring(aura.applications)))
        end
    end
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            note("stats", string.format("slot %02d", slot), tostring(link:match("%[(.-)%]")) .. " "
                .. dump((call(C_Item.GetItemStats, link))))
        end
    end
    for i = 1, 5 do
        note("stats", "UnitStat " .. i, dump({ call(UnitStat, "player", i) }))
    end
    for _, name in ipairs({ "UnitArmor", "UnitAttackPower", "UnitRangedAttackPower", "UnitDefenseSkill" }) do
        note("stats", name, dump({ call(_G[name], "player") }))
    end
    for _, kind in ipairs({ "CR_HIT_MELEE", "CR_CRIT_MELEE", "CR_DODGE", "CR_PARRY", "CR_BLOCK" }) do
        note("stats", kind, _G[kind] and string.format("%s rating %s bonus %s", tostring(_G[kind]),
            tostring((call(GetCombatRating, _G[kind]))), tostring((call(GetCombatRatingBonus, _G[kind])))) or "missing")
    end
end

-- What the attributes' tooltips read beside the auras (Ikar 2026-11-17: "Can we extend to include all sources?"), to
-- confirm what KaLi HUD infers: each worn item's item string (its enchantment, second), its tooltip's enchantment line
-- (type 15), its class, subclass and set (C_Item.GetItemInfo's 12th, 13th, 16th) and its armour among its stats; the
-- weapons' enchantments for a while; the form; what the attributes give as the sheet works it out; and the talents as
-- trait nodes, each one bought with its rank, its definition's spell and the effects' points the game gives, which say
-- whether that spell's points are the rank's own or the first rank's.
local function sources()
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local info = { pcall(C_Item.GetItemInfo, link) }
            local data = C_TooltipInfo and call(C_TooltipInfo.GetInventoryItem, "player", slot)
            local lines = {}
            for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
                if type(line) == "table" and line.type == 15 then
                    lines[#lines + 1] = tostring(line.leftText)
                end
            end
            local stats = call(C_Item.GetItemStats, link)
            note("sources", string.format("slot %02d", slot), string.format("%s class %s subclass %s set %s armour %s "
                .. "enchant line %s", tostring(link:match("|H(item:[^|]*)")), tostring(info[13]), tostring(info[14]),
                tostring(info[17]), tostring(type(stats) == "table" and stats.RESISTANCE0_NAME), dump(lines)))
        end
    end
    for name, slot in pairs(Enum.WeaponSlot or {}) do
        note("sources", "weapon enchants " .. name, dump((call(C_Item.GetWeaponEnchantInfo, slot))))
    end
    note("sources", "form", tostring((call(GetShapeshiftFormID))))
    local _, agility = call(UnitStat, "player", 2)
    local _, strength = call(UnitStat, "player", 1)
    local _, intellect = call(UnitStat, "player", 4)
    note("sources", "attributes give", string.format("AP str %s agi %s, ranged agi %s, crit agi %s, spell crit int %s, "
        .. "dodge %s, hp/sta %s, mana regen spirit %s, breaks %s %s %s", tostring((call(GetAttackPowerForStat, 1, strength))),
        tostring((call(GetAttackPowerForStat, 2, agility))), tostring((call(GetRangedAttackPowerForStat, 2, agility))),
        tostring((call(GetCritChanceFromStat, 2, agility))), tostring((call(GetSpellCritChanceFromStat, 4, intellect))),
        tostring((call(GetDodgeChanceFromAttribute))), tostring((call(UnitHPPerStamina, "player"))),
        tostring((call(GetManaRegenFromSpirit))), tostring(STAMINA_BREAK), tostring(INTELLECT_BREAK),
        tostring(MANA_PER_INTELLECT)))
    local config = C_ClassTalents and call(C_ClassTalents.GetActiveConfigID)
    note("sources", "talent config", tostring(config))
    local info = type(config) == "number" and C_Traits and call(C_Traits.GetConfigInfo, config)
    for _, tree in ipairs(type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs or {}) do
        local nodes = call(C_Traits.GetTreeNodes, tree)
        for _, node in ipairs(type(nodes) == "table" and nodes or {}) do
            local n = call(C_Traits.GetNodeInfo, config, node)
            local rank = type(n) == "table" and n.activeRank or 0
            if type(rank) == "number" and rank > 0 then
                local entryID = type(n.activeEntry) == "table" and n.activeEntry.entryID
                local entry = entryID and call(C_Traits.GetEntryInfo, config, entryID)
                local definition = type(entry) == "table" and entry.definitionID
                    and call(C_Traits.GetDefinitionInfo, entry.definitionID)
                note("sources", string.format("talent %d", node), string.format("rank %s/%s ranksPurchased %s entry %s "
                    .. "definition %s spell %s known %s", tostring(rank), tostring(n.maxRanks), tostring(n.ranksPurchased),
                    tostring(entryID), tostring(type(entry) == "table" and entry.definitionID),
                    tostring(type(definition) == "table" and definition.spellID),
                    tostring(type(definition) == "table" and C_SpellBook
                        and (call(C_SpellBook.IsSpellKnown, definition.spellID)))))
            end
        end
    end
end

local function passive()
    report = {}
    for _, section in ipairs({ { "frames", frames }, { "editMode", editMode }, { "broker", broker }, { "apis", apis },
        { "stats", stats }, { "sources", sources } }) do
        local ok, err = pcall(section[2])
        if not ok then
            note("errors", section[1], err)
        end
    end
    report.at = date("%Y-%m-%d %H:%M:%S")
    KaLiHUDProbeDB.report = report
end

-- Moves an Edit Mode frame as a drag would, so Edit Mode's Save or Revert decide: the way "put a bar here" would work.
local function move(name, dx, dy)
    local f = _G[name or ""]
    if not f then
        say("no frame " .. tostring(name))
        return
    end
    if not (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) then
        say("open Edit Mode first")
        return
    end
    if InCombatLockdown() then
        say("not in a fight")
        return
    end
    local before = rect(f)
    local left, bottom = f:GetLeft(), f:GetBottom()
    local ok, err = pcall(function()
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + (tonumber(dx) or 0), bottom + (tonumber(dy) or 0))
        EditModeManagerFrame:OnSystemPositionChange(f)
    end)
    local entry = {
        at = date("%H:%M:%S"),
        frame = name,
        ok = tostring(ok) .. (err and (" " .. tostring(err)) or ""),
        before = before,
        after = rect(f),
        anchor = anchor(f),
        frameChanges = tostring(f.hasActiveChanges),
        managerChanges = tostring((call(EditModeManagerFrame.HasActiveChanges, EditModeManagerFrame))),
    }
    KaLiHUDProbeDB.moves = KaLiHUDProbeDB.moves or {}
    table.insert(KaLiHUDProbeDB.moves, entry)
    say(dump(entry))
end

local function remember(kind, ...)
    KaLiHUDProbeDB.blocked = KaLiHUDProbeDB.blocked or {}
    local list = KaLiHUDProbeDB.blocked
    if #list < 200 then
        list[#list + 1] = date("%m-%d %H:%M:%S") .. " " .. kind .. " " .. dump({ ... })
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Kept across reloads: a block after a move may come in a later session.
        KaLiHUDProbeDB.blocked = KaLiHUDProbeDB.blocked or {}
        KaLiHUDProbeDB.editMode = KaLiHUDProbeDB.editMode or {}
        table.insert(KaLiHUDProbeDB.editMode, date("%m-%d %H:%M:%S") .. " login")
        C_Timer.After(3, passive)
        if EventRegistry then
            for _, name in ipairs({ "EditMode.Enter", "EditMode.Exit" }) do
                EventRegistry:RegisterCallback(name, function()
                    table.insert(KaLiHUDProbeDB.editMode, date("%m-%d %H:%M:%S") .. " " .. name)
                    if name == "EditMode.Exit" then
                        C_Timer.After(0.5, passive)
                    end
                end, frame)
            end
        end
    else
        remember(event, ...)
    end
end)

-- Every talent of the class's trees KaLi HUD has values for (Ikar 2026-11-21: "review all talent, all similar
-- assumption, can't you test them ?"): the node's ranks as the game gives them, the game's own tooltip at each rank
-- (C_TooltipInfo.GetTraitEntry, the talent frame's), the HUD's values by rank, and for one learned its aura's points
-- if the game shows it as an aura. Kept in KaLiHUDProbeDB.talents for the offline check.
local function talentsProbe()
    local ns = KaLiHUDDev and KaLiHUDDev.ns
    local points, effects = ns and ns.TALENT_POINTS or {}, ns and ns.EFFECTS or {}
    local config = C_ClassTalents and call(C_ClassTalents.GetActiveConfigID)
    local info = type(config) == "number" and call(C_Traits.GetConfigInfo, config)
    if type(info) ~= "table" then
        say("talents: no active configuration")
        return
    end
    local function list(v)
        return type(v) == "table" and v or {}
    end
    local out, n, learned = { level = UnitLevel("player"), class = select(2, UnitClass("player")) }, 0, 0
    for _, tree in ipairs(list(info.treeIDs)) do
        for _, node in ipairs(list(call(C_Traits.GetTreeNodes, tree))) do
            local ni = call(C_Traits.GetNodeInfo, config, node)
            for _, entryID in ipairs(type(ni) == "table" and list(ni.entryIDs) or {}) do
                local entry = call(C_Traits.GetEntryInfo, config, entryID)
                local def = type(entry) == "table" and entry.definitionID and call(C_Traits.GetDefinitionInfo, entry.definitionID)
                local spell = type(def) == "table" and def.spellID
                if spell and (points[spell] or effects[spell]) then
                    local t = { spell = spell, name = C_Spell and call(C_Spell.GetSpellName, spell), points = points[spell],
                        effects = effects[spell], activeRank = ni.activeRank, currentRank = ni.currentRank,
                        ranksPurchased = ni.ranksPurchased, ranksIncreased = ni.ranksIncreased, maxRanks = ni.maxRanks,
                        totalMaxRanks = ni.totalMaxRanks, entryMax = entry.maxRanks, ranks = {} }
                    for rank = 1, math.max(ni.maxRanks or 1, entry.maxRanks or 1) do
                        local data = C_TooltipInfo and call(C_TooltipInfo.GetTraitEntry, entryID, rank)
                        local lines = {}
                        for _, line in ipairs(type(data) == "table" and list(data.lines) or {}) do
                            lines[#lines + 1] = tostring(line.leftText or "") .. (line.rightText and (" | " .. tostring(line.rightText)) or "")
                        end
                        t.ranks[rank] = table.concat(lines, " // ")
                    end
                    if (ni.activeRank or 0) > 0 then
                        learned = learned + 1
                        local aura = C_UnitAuras and call(C_UnitAuras.GetPlayerAuraBySpellID, spell)
                        t.aura = type(aura) == "table" and dump(aura.points) or tostring(aura)
                    end
                    out[#out + 1] = t
                    n = n + 1
                end
            end
        end
    end
    KaLiHUDProbeDB.talents = out
    say(string.format("talents: %d with KaLi HUD values, %d learned; /reload to save", n, learned))
end

-- The regenerations as the game gives them, one reading a call, kept in a row (Ikar 2026-11-21: "health regen ?"):
-- read standing, then sitting, it tells whether the game's whole follows the standing (the sheet takes three quarters
-- of the spirit's, « 33 % more sitting »); and what the card's bases are held against: the race, the class, the level,
-- the attributes, the most health and mana, the chances.
local function regenProbe()
    local health, fight = call(GetHealthRegen)
    local spirit, spiritFight = call(GetHealthRegenFromSpirit)
    local t = { health = { health, fight }, healthFromSpirit = { spirit, spiritFight }, mana = { call(GetManaRegen) },
        manaFromSpirit = { call(GetManaRegenFromSpirit) }, race = { call(UnitRace, "player") },
        class = { call(UnitClass, "player") }, level = call(UnitLevel, "player"),
        health_max = call(UnitHealthMax, "player"), power_max = call(UnitPowerMax, "player"),
        crit = { call(GetCritChance), call(GetRangedCritChance), call(GetSpellCritChance) },
        dodge = call(GetDodgeChance), parry = call(GetParryChance), block = call(GetBlockChance), stats = {} }
    for i = 1, 5 do
        t.stats[i] = dump({ call(UnitStat, "player", i) })
    end
    KaLiHUDProbeDB.regen = KaLiHUDProbeDB.regen or {}
    local list = KaLiHUDProbeDB.regen
    list[#list + 1] = t
    local function five(v)
        return type(v) == "number" and string.format("%.1f", v * 5) or tostring(v)
    end
    say(string.format("regen %d: health %s in 5 s (fight %s), the spirit's %s (fight %s); /reload to save", #list,
        five(health), five(fight), five(spirit), five(spiritFight)))
end

SLASH_KALIHUDPROBE1 = "/khprobe"
SlashCmdList.KALIHUDPROBE = function(msg)
    local cmd, a, b, c = strsplit(" ", strtrim(msg or ""))
    if cmd == "move" then
        move(a, b, c)
    elseif cmd == "blocked" then
        local list = KaLiHUDProbeDB.blocked or {}
        say(#list .. " blocked or forbidden")
        for i = 1, math.min(#list, 10) do
            say(list[i])
        end
    elseif cmd == "talents" then
        local ok, err = pcall(talentsProbe)
        if not ok then
            say("talents: " .. tostring(err))
        end
    elseif cmd == "regen" then
        local ok, err = pcall(regenProbe)
        if not ok then
            say("regen: " .. tostring(err))
        end
    elseif cmd == "show" then
        say(dump(KaLiHUDProbeDB.report))
    else
        passive()
        say("checks done, saved at the next /reload or logout")
    end
end
