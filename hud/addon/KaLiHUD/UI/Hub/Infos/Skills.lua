-- The character's skills (Ikar 2026-11-16: "weapon skill, yes, with a folder with each"; "profession skills
-- (folder)"): one item for each skill line the game lists for this character, its rank out of its maximum, as the
-- character sheet's skills tab reads them (C_SkillInfo). Weapon skills, defence among them, stand in the weapon
-- skills' folder; professions and secondary skills (cooking, first aid, fishing, riding...) in the professions'. A
-- skill learnt shows at once, one unlearnt goes.
local _, ns = ...

local Infos, Hub, L = ns.Infos, ns.Hub, ns.L

local Skills = {}
ns.Skills = Skills

-- Skill lines' categories, as this build's SkillLine table files them; a skill of one rank only (a racial, dual
-- wield) has none to show.
local WEAPONS, SECONDARY, PROFESSIONS = 6, 9, 11
local HOME = { [WEAPONS] = "weapons", [SECONDARY] = "professions", [PROFESSIONS] = "professions" }
local DEFENSE = 95
local FISHING = 356
local PREFIX = "KaLiHUD_Skill_"
-- Each profession's and secondary skill's icon (this build's SkillLine table, SpellIconFileID), every one of
-- categories 9 and 11 with its own; the weapon skills and the mounts' share the generic one, so they show none.
local ICONS = {
    [171] = 136240, [164] = 136241, [333] = 136244, [202] = 136243, [182] = 136246, [165] = 136247, [186] = 136248,
    [393] = 134366, [197] = 136249, [185] = 133971, [129] = 135966, [356] = 136245, [633] = 136058, [762] = 132164,
    [40] = 136242, [713] = 135997, [3012] = 135933,
}

-- The lines as last read, by skill id: { name, rank, max, modifier, category, description }.
local have = {}
local made = {}
-- How many were made: one learnt later goes after the others in its folder.
local count = 0

local function skillText(s)
    local mod = s.modifier or 0
    local rank = tostring(s.rank) .. (mod > 0 and Infos.Color("+" .. mod, Infos.GOOD) or mod < 0 and Infos.Color(mod, Infos.BAD) or "")
    return string.format("%s %s/%d", s.name, rank, s.max)
end

-- What found(map) gives for the map the player is on, or for the zone a cave's or a building's map stands in (a micro
-- map's parent): nil if neither has one.
local MICRO = Enum.UIMapType and Enum.UIMapType.Micro or 5
local function onMap(found)
    local map = ns.Call(C_Map.GetBestMapForUnit, "player")
    for _ = 1, 4 do
        if type(map) ~= "number" then
            return nil
        end
        local value = found(map)
        if value ~= nil then
            return value
        end
        local info = ns.Call(C_Map.GetMapInfo, map)
        if type(info) ~= "table" or info.mapType ~= MICRO then
            return nil
        end
        map = info.parentMapID
    end
end

-- The zone's level range (Ikar: "fishing, the zone level"), as Forever's own Group Finder suggests it (Data/Zones.lua,
-- hud/tools/make_zones.py; Ikar 2026-11-18: "Add the table, scrap the data", "for forever, be carrefull"): the game
-- gives no zone a range of its own, C_Map.GetMapLevels having none on Forever. nil in a zone the Group Finder doesn't
-- list (a city, Moonglade, Shen'dralas) and in an instance.
function Skills.ZoneLevels()
    local levels = onMap(function(map)
        return ns.ZONE_LEVELS and ns.ZONE_LEVELS[map]
    end)
    if levels then
        return levels[1], levels[2]
    end
end

-- The base fishing skill where the player is (Ikar 2026-11-18: "how to get the fishing areas zones ?", "Go for it, but
-- don't show a line, add a question mark icon"): the original game's for the dungeon, else the sub-zone, else the zone
-- (Data/Fishing.lua, hud/tools/make_fishing.py), the game's client having none; nil where it has none (Forever's own
-- zones). A sub-zone is known by the name the game gives its area, in the player's language.
function Skills.FishingBase()
    local data = ns.FISHING
    if not data then
        return nil
    end
    if type(GetInstanceInfo) == "function" then
        local _, kind, _, _, _, _, _, instance = ns.Plain(GetInstanceInfo())
        if kind ~= nil and kind ~= "none" then
            return data.instances[instance]
        end
    end
    return onMap(function(map)
        local sub = ns.Plain(ns.Call(GetSubZoneText))
        if type(sub) == "string" and sub ~= "" then
            for area, own in pairs(data.areas) do
                if own[2] == map and sub == ns.Plain(ns.Call(C_Map.GetAreaInfo, area)) then
                    return own[1]
                end
            end
        end
        return data.zones[map]
    end)
end

-- Not known: the ready check's « waiting » mark, as the attributes' (UI/Hub/Infos/Stats.lua's UNKNOWN), the font's
-- height (Ikar 2026-11-19, of the one before: "she is ugly, isn't there a betetr one ?")
local QUESTION = "|A:UI-LFG-PendingMark:0:0|a"

-- Where a cast lands at a base: from the base, (skill - base + 5)% of the time, every time from base + 95 (the server's
-- rule); green once every one does, red while none can, as the character sheet's.
local function fishingRange(base, skill)
    local low, high = math.max(base, 1), base + 95
    local text = low .. "-" .. high
    return skill >= high and Infos.Color(text, Infos.GOOD) or skill < low and Infos.Color(text, Infos.BAD) or text
end

-- What the Skills tab says of a weapon skill (Camelot's SkillsFrame.lua, SkillDetailFrameMixin:AddWeaponSkillRows;
-- its WEAPON_SKILL_LINES, a local of it: ranged or not): the chance to hit, and not to be dodged or parried, and to
-- strike critically, against an enemy of the character's level and a raid boss (level 63 whatever the character's),
-- 0.04 % a point of the enemy's defence over the skill, five a level; a raid boss's glancing blows, how often and how
-- much less, by the game's own calls (GetGlancingBlowChance, GetGlancingBlowPenalty). In its words, after the skill's
-- description (the review of 2026-11-21: the folder had none of it).
local WEAPON_LINES = { [43] = false, [44] = false, [45] = true, [46] = true, [54] = false, [55] = false,
    [136] = false, [160] = false, [172] = false, [173] = false, [176] = true, [226] = true, [228] = true,
    [229] = false, [162] = false, [3014] = false }
local RAID_BOSS_LEVEL = 63
local function say(key, ...)
    local text = ns.G(key)
    if type(text) ~= "string" then
        return nil
    end
    local ok, out = pcall(string.format, text, ...)
    return ok and out or nil
end
local function weaponRows(tt, s, ranged)
    local level = ns.Plain(UnitLevel("player"))
    if type(level) ~= "number" or level <= 0 then
        return
    end
    local skill = s.rank + (s.modifier or 0)
    local function chance(at)
        local v = (at * 5 - skill) * -0.04
        return (v > 0.004 and "+" or v < -0.004 and "-" or "") .. ns.Format.PercentOf(math.abs(v), 2)
    end
    local gold = Infos.GOLD
    local function add(header, text)
        if header and text then
            tt:AddLine(" ")
            Infos.Text(tt, header)
            tt:AddLine(text, gold[1], gold[2], gold[3], true)
        end
    end
    local same = chance(level)
    add(ns.G("WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER"),
        say(ranged and "WEAPON_SKILL_DETAIL_SAME_LEVEL_RANGED" or "WEAPON_SKILL_DETAIL_SAME_LEVEL", same, same))
    local boss = chance(RAID_BOSS_LEVEL)
    local glancing = not ranged and ns.Plain(ns.Call(GetGlancingBlowChance, skill, RAID_BOSS_LEVEL * 5))
    local less = not ranged and ns.Plain(ns.Call(GetGlancingBlowPenalty, skill, RAID_BOSS_LEVEL * 5))
    local text
    if type(glancing) == "number" and type(less) == "number" then
        text = say("WEAPON_SKILL_DETAIL_BOSS", boss, boss, ns.Format.Percent(glancing), ns.Format.Percent(less))
    end
    -- (its glancing blows hidden, or none to read: the chances alone, as the tab has them for a ranged weapon)
    add(ns.G("WEAPON_SKILL_DETAIL_BOSS_HEADER"), text or say("WEAPON_SKILL_DETAIL_BOSS_RANGED", boss, boss))
end

local function tooltip(id)
    return function(tt)
        local s = have[id]
        if not s then
            return
        end
        Infos.Title(tt, s.name)
        Infos.Line(tt, L.SKILL_RANK, string.format("%d/%d", s.rank, s.max))
        if (s.modifier or 0) ~= 0 then
            Infos.Line(tt, L.SKILL_BONUS, (s.modifier > 0 and "+" or "") .. s.modifier)
            -- where it comes from, as an attribute's (Ikar 2026-11-18: "for fishing, I see only bonus +5, not the
            -- source"): the rod, a lure, an enchantment, a buff, the race...
            ns.Stats.ShowSkillSources(tt, id, s.rank, s.modifier)
        end
        if id == FISHING then
            local low, high = Skills.ZoneLevels()
            if low then
                Infos.Line(tt, string.format(L.ZONE_LEVELS_OF, GetZoneText() or ""), low == high and tostring(low)
                    or string.format("%d-%d", low, high))
            end
            -- a question mark where it isn't known, never a dash
            local base = Skills.FishingBase()
            Infos.Line(tt, L.FISHING_HERE, base and fishingRange(base, s.rank + (s.modifier or 0)) or QUESTION)
            if not base then
                -- what the mark asks, and what to go by (Ikar 2026-11-19: "the description should give an answer")
                Infos.Hint(tt, QUESTION .. " " .. L.FISHING_WHY)
            end
        end
        if type(s.description) == "string" and s.description ~= "" then
            Infos.Hint(tt, s.description)
        end
        if WEAPON_LINES[id] ~= nil then
            weaponRows(tt, s, WEAPON_LINES[id])
        end
        Infos.Hint(tt, s.category == WEAPONS and L.HINT_SKILLS or L.HINT_PROFESSIONS)
    end
end

local function object(id, category)
    local o = made[id]
    if o then
        return o
    end
    o = {
        type = "data source", text = "", category = "skills", home = HOME[category], icon = ICONS[id],
        available = function()
            return have[id] ~= nil
        end,
        OnTooltipShow = tooltip(id),
        OnClick = Infos.Opener(function()
            -- the professions' own book for a profession, the character's skills tab else
            local s = have[id]
            if s and s.category ~= WEAPONS and type(ToggleProfessionsBook) == "function" then
                ToggleProfessionsBook()
            else
                ToggleCharacter("SkillsFrame")
            end
        end),
    }
    made[id] = o
    return o
end

-- The skill lines read again: one item for each, made the first time; drawn again if one came or went.
local function read()
    local was = {}
    for id in pairs(have) do
        was[id] = true
    end
    wipe(have)
    -- in the game's order: the first made are listed so
    local order = {}
    local n = ns.Call(C_SkillInfo and C_SkillInfo.GetNumSkillLines) or 0
    for i = 1, n do
        local s = ns.Call(C_SkillInfo.GetSkillLineInfo, i)
        if type(s) == "table" and not s.isHeader and s.parentSkillLineID == 0 and HOME[s.skillLineCategoryID]
            and (s.maxRank or 0) > 1 then
            local line = { name = s.name, rank = s.rank or 0, max = s.maxRank, modifier = s.modifier or 0,
                category = s.skillLineCategoryID, description = s.description, index = i }
            if s.skillID == DEFENSE then
                local _, mod = ns.Plain(ns.Call(UnitDefenseSkill, "player"))
                line.modifier = type(mod) == "number" and mod or line.modifier
            end
            have[s.skillID] = line
            order[#order + 1] = s.skillID
        end
    end
    local changed = false
    for _, id in ipairs(order) do
        local s = have[id]
        local name = PREFIX .. id
        if not made[id] then
            count = count + 1
            Hub.Add(name, object(id, s.category), "hidden", 100 + count)
        end
        changed = changed or not was[id]
        was[id] = nil
        Hub.Set(name, "label", s.name)
        Hub.Set(name, "text", skillText(s))
    end
    if changed or next(was) then
        Hub.Changed()
    end
end

Infos.Updates(read, { "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD" })
