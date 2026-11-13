-- KaLi Recipe's probe: what this client answers to the questions the plan couldn't settle from Blizzard's source.
-- It changes nothing of the game's, and keeps its findings in KaLiRecipeProbeDB for read_saved.py.
--   /krprobe            the passive checks (also 3 seconds after login)
--   /krprobe window     with the professions window open: its profession, recipes, categories, schematics
--   /krprobe spellbook  the spellbook's answer for the window's learned recipes
--   /krprobe tooltip <item>  a tooltip's data, every line and field (a recipe item: is its spell in there?)
--   /krprobe trainer    at a trainer: each service, its tooltip's spell, its item, its rank
--   /krprobe ah         at the auction house: one query on Recipes without a click, and what comes back
--   /krprobe sounds     every sound the options offer, one after the other
--   /krprobe volume     how the game takes a volume asked with a sound: three short quills, read back
--   /krprobe show       the report so far
local ADDON = ...

KaLiRecipeProbeDB = KaLiRecipeProbeDB or {}
local frame = CreateFrame("Frame", nil, nil)
local report

local function say(msg)
    print("|cffffd200KaLi Recipe probe :|r " .. tostring(msg))
end

local function dump(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then
        return type(v) == "string" and string.format("%q", v) or tostring(v)
    end
    if depth > 3 then
        return "{…}"
    end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
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
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        return "error: " .. tostring(a)
    end
    return a, b, c
end

local function note(section, key, value)
    report[section] = report[section] or {}
    report[section][key] = type(value) == "table" and dump(value) or tostring(value)
end

-- Recipes the addon saw, for the probes on recipes this character doesn't know.
local function seen()
    local out = {}
    local db = KaLiRecipeDB
    for spell in pairs(db and db.sightings or {}) do
        out[#out + 1] = spell
    end
    table.sort(out)
    return out
end

local function passive()
    local version, build = GetBuildInfo()
    note("environment", "build", version .. " " .. build)
    note("environment", "locale", GetLocale())
    local list = { GetProfessions() }
    for i = 1, 6 do
        if list[i] then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(list[i])
            note("professions", "slot " .. i, string.format("%s %s/%s skill line %s", tostring(name), tostring(rank), tostring(maxRank), tostring(skillLine)))
        end
    end
    for _, name in ipairs({ "OpenProfessionUIToSkillLine", "IsTradeskillTrainer", "GetTrainerServiceSkillReq" }) do
        note("functions", name, type(_G[name]))
    end
    note("functions", "C_SpellBook.IsSpellKnown", type(C_SpellBook and C_SpellBook.IsSpellKnown))
    note("functions", "C_TooltipInfo.GetTrainerService", type(C_TooltipInfo and C_TooltipInfo.GetTrainerService))
    note("functions", "C_AuctionHouse.SendBrowseQuery", type(C_AuctionHouse and C_AuctionHouse.SendBrowseQuery))
    note("functions", "TooltipDataProcessor", type(TooltipDataProcessor))
    -- Schematics and recipe info for recipes seen, known or not, with the professions window closed.
    for i, spell in ipairs(seen()) do
        if i > 8 then
            break
        end
        local s = call(C_TradeSkillUI.GetRecipeSchematic, spell, false)
        note("closed window", "schematic " .. spell, type(s) == "table" and string.format("output %s, %d reagent slots",
            tostring(s.outputItemID), #(s.reagentSlotSchematics or {})) or s)
        local r = call(C_TradeSkillUI.GetRecipeInfo, spell)
        note("closed window", "info " .. spell, type(r) == "table" and string.format("learned %s, category %s", tostring(r.learned),
            tostring(r.categoryID)) or r)
        note("closed window", "spellbook " .. spell, call(C_SpellBook and C_SpellBook.IsSpellKnown, spell))
    end
    report.when = date("%Y-%m-%d %H:%M:%S")
end

local COMMANDS = {}
COMMANDS[""] = passive

COMMANDS.window = function()
    note("window", "base", call(C_TradeSkillUI.GetBaseProfessionInfo))
    note("window", "child", call(C_TradeSkillUI.GetChildProfessionInfo))
    local ids = call(C_TradeSkillUI.GetFilteredRecipeIDs)
    if type(ids) ~= "table" then
        note("window", "recipes", ids)
        return
    end
    local learned, cats = 0, {}
    for i, id in ipairs(ids) do
        local info = call(C_TradeSkillUI.GetRecipeInfo, id)
        if type(info) == "table" then
            learned = learned + (info.learned and 1 or 0)
            if info.categoryID then
                cats[info.categoryID] = (cats[info.categoryID] or 0) + 1
            end
            if i <= 3 then
                note("window", "recipe " .. id, info)
            end
        end
    end
    note("window", "recipes", string.format("%d listed, %d learned", #ids, learned))
    for cat, n in pairs(cats) do
        note("window", "category " .. cat, string.format("%d recipes, info %s", n, dump(call(C_TradeSkillUI.GetCategoryInfo, cat))))
    end
    for i, spell in ipairs(seen()) do
        if i > 8 then
            break
        end
        local s = call(C_TradeSkillUI.GetRecipeSchematic, spell, false)
        note("window", "schematic " .. spell, type(s) == "table" and string.format("output %s, %d reagent slots",
            tostring(s.outputItemID), #(s.reagentSlotSchematics or {})) or s)
        note("window", "info " .. spell, call(C_TradeSkillUI.GetRecipeInfo, spell))
    end
    say("window: " .. #ids .. " recipes")
end

COMMANDS.spellbook = function()
    local ids = call(C_TradeSkillUI.GetFilteredRecipeIDs)
    local yes, no = 0, 0
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local known = call(C_SpellBook and C_SpellBook.IsSpellKnown, id)
        if known == true then
            yes = yes + 1
        else
            no = no + 1
        end
    end
    note("spellbook", "window's recipes", string.format("%d known to the spellbook, %d not", yes, no))
    say("spellbook: " .. yes .. " / " .. (yes + no))
end

COMMANDS.tooltip = function(rest)
    local item = tonumber(rest)
    if not item then
        say("/krprobe tooltip <item>")
        return
    end
    local data = call(C_TooltipInfo and C_TooltipInfo.GetItemByID, item)
    note("tooltip " .. item, "type/id", type(data) == "table" and (tostring(data.type) .. "/" .. tostring(data.id)) or data)
    for i, line in ipairs(type(data) == "table" and data.lines or {}) do
        note("tooltip " .. item, string.format("line %02d", i), line)
    end
    note("tooltip " .. item, "GetItemSpell", { call(C_Item.GetItemSpell, item) })
    say("tooltip " .. item .. " kept")
end

COMMANDS.trainer = function()
    note("trainer", "tradeskill", call(IsTradeskillTrainer))
    note("trainer", "npc", UnitGUID("npc"))
    for i = 1, call(GetNumTrainerServices) or 0 do
        local name, rank, kind = call(GetTrainerServiceInfo, i)
        local data = call(C_TooltipInfo and C_TooltipInfo.GetTrainerService, i)
        local skill, req = call(GetTrainerServiceSkillReq, i)
        note("trainer", string.format("service %02d", i), string.format("%s [%s] %s · tooltip %s/%s · item %s · requires %s %s",
            tostring(name), tostring(rank), tostring(kind), type(data) == "table" and tostring(data.type) or "-",
            type(data) == "table" and tostring(data.id) or "-", tostring(call(GetTrainerServiceItemLink, i)), tostring(skill), tostring(req)))
    end
    say("trainer kept")
end

local ahSent
COMMANDS.ah = function()
    if not (C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) then
        note("auction house", "query", "missing")
        return
    end
    note("auction house", "ready", call(C_AuctionHouse.IsThrottledMessageSystemReady))
    local ok, err = pcall(C_AuctionHouse.SendBrowseQuery, { searchString = "", sorts = {}, filters = {},
        itemClassFilters = { { classID = Enum.ItemClass and Enum.ItemClass.Recipe or 9 } } })
    ahSent = GetTime()
    note("auction house", "query", ok and "sent" or ("error: " .. tostring(err)))
    say("auction house query " .. (ok and "sent" or "refused"))
end

COMMANDS.show = function()
    local lines = {}
    for section, entries in pairs(report) do
        if type(entries) == "table" then
            lines[#lines + 1] = "[" .. section .. "]"
            local keys = {}
            for k in pairs(entries) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                lines[#lines + 1] = "  " .. k .. ": " .. entries[k]
            end
        end
    end
    for _, line in ipairs(lines) do
        print(line)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "ADDON_LOADED" and a == ADDON then
        KaLiRecipeProbeDB = type(KaLiRecipeProbeDB) == "table" and KaLiRecipeProbeDB or {}
        report = {}
        KaLiRecipeProbeDB.report = report
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, function()
            pcall(passive)
        end)
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" and ahSent and report then
        local results = call(C_AuctionHouse.GetBrowseResults)
        note("auction house", "answer", string.format("%.1f s after, %s results", GetTime() - ahSent,
            type(results) == "table" and #results or tostring(results)))
    elseif event == "ADDON_ACTION_BLOCKED" and report then
        note("blocked", tostring(a), tostring(b))
    end
end)

-- The bank, while it's open: the tab bank's containers as the game numbers them, and what KaLi Recipe reads.
COMMANDS.bank = function()
    local E = Enum and Enum.BagIndex or {}
    local names = {}
    for name, id in pairs(E) do
        names[#names + 1] = string.format("%s=%d", name, id)
    end
    table.sort(names)
    note("bank", "BagIndex", table.concat(names, " "))
    if C_Bank and Enum.BankType then
        for _, kind in ipairs({ "Character", "Account" }) do
            local tabs = call(C_Bank.FetchPurchasedBankTabData, Enum.BankType[kind])
            local ids = {}
            for _, t in ipairs(type(tabs) == "table" and tabs or {}) do
                ids[#ids + 1] = string.format("%s (%s slots)", tostring(t.ID), tostring(call(C_Container.GetContainerNumSlots, t.ID)))
            end
            note("bank", kind .. " tabs", #ids > 0 and table.concat(ids, ", ") or tabs)
        end
    end
    local ns = KaLiRecipeDev and KaLiRecipeDev.ns
    if ns then
        note("bank", "read by KaLi Recipe", table.concat(ns.Game.BagIDs(true), ", "))
        local c = ns.db and ns.db.chars[ns.Game.Key()]
        local n = 0
        for _ in pairs(c and c.bank or {}) do
            n = n + 1
        end
        note("bank", "recipe items noted in the bank", n)
    end
    say("bank noted")
end

-- Every sound the options offer, one every 3.5 seconds, its name in the chat first, whether the game played it, and for
-- the quill's shorter strokes, whether it stopped.
COMMANDS.sounds = function()
    local ns = KaLiRecipeDev and KaLiRecipeDev.ns
    if not ns then
        say("KaLi Recipe isn't loaded")
        return
    end
    local list, listed = {}, {}
    for _, kind in ipairs({ "recipe", "place" }) do
        for _, c in ipairs(ns.Sounds.CHOICES[kind]) do
            if not listed[c[1]] then
                listed[c[1]] = true
                list[#list + 1] = c
            end
        end
    end
    for i, c in ipairs(list) do
        C_Timer.After((i - 1) * 3.5, function()
            say(string.format("%d/%d %s: %s (kit %d%s)", i, #list, c[1], ns.L["SOUND_" .. c[1]], c[2],
                c[4] and string.format(", stopped after %.1f s", c[4]) or ""))
            local ok, willPlay, handle = pcall(PlaySound, c[2])
            note("sounds", c[1], ok and (tostring(willPlay) .. ", handle " .. tostring(handle)) or ("error " .. tostring(willPlay)))
            if ok and c[4] and handle then
                C_Timer.After(c[4], function()
                    local stopped, err = pcall(StopSound, handle, ns.Sounds.FADE * 1000)
                    note("sounds", c[1] .. " stop", stopped and "ok" or ("error " .. tostring(err)))
                end)
            end
        end)
    end
end

-- How the game takes a volume asked with a sound (volumeOverride, which « Volume des sons » uses; its documentation
-- doesn't say): the quill as the game plays it, then asked at its kit's own volume and at half of it, each read back
-- with GetSoundScaledVolume and stopped early. The first two the same says the asked volume replaces the kit's own,
-- what Core/Sounds.lua assumes; the second the first times the kit's own says it multiplies it.
COMMANDS.volume = function()
    local ns = KaLiRecipeDev and KaLiRecipeDev.ns
    if not ns then
        say("KaLi Recipe isn't loaded")
        return
    end
    if not (C_Sound and C_Sound.PlaySoundWithOptions and C_Sound.GetSoundScaledVolume) then
        note("volume", "api", "no C_Sound.PlaySoundWithOptions or GetSoundScaledVolume")
        say("this game takes no volume with a sound")
        return
    end
    local kit = 3093
    local own = ns.Sounds.KIT_VOLUME[kit]
    local tries = { { "1 as the game plays it" }, { "2 asked its own " .. own, own }, { "3 asked half of it", own / 2 } }
    local got = {}
    local function verdict()
        local a, b, c = got[1], got[2], got[3]
        local text
        if not (a and b and c) or a <= 0 then
            text = "no verdict: a sound wasn't read (the game's sound off?)"
        elseif math.abs(b - a) <= a * 0.02 and math.abs(c - a / 2) <= a * 0.02 then
            text = "replaces the kit's own: Core/Sounds.lua's assumption holds"
        elseif math.abs(b - a * own) <= a * 0.02 then
            text = "multiplies the kit's own: Core/Sounds.lua must ask the share alone"
        else
            text = "neither: see the numbers"
        end
        note("volume", "verdict", text)
        say("volume: " .. text)
    end
    for i, t in ipairs(tries) do
        C_Timer.After((i - 1) * 0.8, function()
            local ok, success, handle
            if t[2] then
                ok, success, handle = pcall(C_Sound.PlaySoundWithOptions, { soundKitID = kit, uiSoundSubType = "SFX", volumeOverride = t[2] })
            else
                ok, success, handle = pcall(PlaySound, kit)
            end
            if not ok or not handle then
                note("volume", t[1], ok and ("not played: " .. tostring(success)) or ("error " .. tostring(success)))
                if i == #tries then
                    verdict()
                end
                return
            end
            C_Timer.After(0.1, function()
                local read, v = pcall(C_Sound.GetSoundScaledVolume, handle)
                got[i] = read and type(v) == "number" and v or nil
                note("volume", t[1], read and tostring(v) or ("error " .. tostring(v)))
                say(t[1] .. ": " .. (read and tostring(v) or tostring(v)))
                pcall(StopSound, handle, 100)
                if i == #tries then
                    verdict()
                end
            end)
        end)
    end
end

SLASH_KRPROBE1 = "/krprobe"
SLASH_KRPROBE2 = "/kaliprobe"
SlashCmdList.KRPROBE = function(input)
    local cmd, rest = (input or ""):match("^[ \t]*([^ \t]*)[ \t]*(.-)[ \t]*$")
    local fn = COMMANDS[cmd:lower()]
    if not fn then
        say("/krprobe [window|spellbook|tooltip <item>|trainer|ah|bank|sounds|volume|show]")
        return
    end
    if not report then
        report = {}
        KaLiRecipeProbeDB.report = report
    end
    local ok, err = pcall(fn, rest)
    if not ok then
        say("error: " .. tostring(err))
    end
end
