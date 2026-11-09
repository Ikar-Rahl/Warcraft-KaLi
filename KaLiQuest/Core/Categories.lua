-- Which tracker category a quest log header belongs to. The header decides both the category and the group
-- inside it, so most quests sort themselves. See docs/organiser-design.md, "How a header is classified".
local _, ns = ...

local Categories = {}
ns.Categories = Categories

-- Journal's categories, in their default order.
Categories.ORDER = { "world", "classprof", "instances", "events", "pvp", "misc" }

-- Each class's QuestSort ID, by the classFile UnitClass returns. No API links the two.
Categories.CLASS_SORT = {
    WARRIOR = 81,
    PALADIN = 141,
    HUNTER = 261,
    ROGUE = 162,
    PRIEST = 262,
    SHAMAN = 82,
    MAGE = 161,
    WARLOCK = 61,
    DRUID = 263,
}

-- A header's headerSortKey, undocumented, as read in game on 2026-11-09: 0x40000000 plus the AreaTable ID for a zone
-- or an instance, 0x20000000 plus the QuestSort ID for the rest. Returns "area" or "sort" and the ID, or nothing for
-- a key of another shape, which leaves the header to its name.
local AREA_KEY, SORT_KEY = 0x40000000, 0x20000000
function Categories.DecodeKey(key)
    if type(key) ~= "number" then
        return nil
    end
    if key >= AREA_KEY and key < AREA_KEY + SORT_KEY then
        return "area", key - AREA_KEY
    elseif key >= SORT_KEY and key < AREA_KEY then
        return "sort", key - SORT_KEY
    end
end
local decodeKey = Categories.DecodeKey

-- env.locale: the client's language. env.classFile: the player's class, as UnitClass returns it. env.ownClassName:
-- LOCALIZED_CLASS_NAMES_MALE[classFile], because the log's class headers use the masculine form.
-- env.areaName(areaID): the area's name in the client's language.
function Categories.New(env)
    local sortKind = {}
    local names = ns.SORT_NAMES[env.locale] or ns.SORT_NAMES.enUS
    for id, name in pairs(names) do
        local kind = ns.SORT_KIND[id]
        if kind then
            sortKind[name] = kind
        end
    end
    local areaKind, areaKindByID = {}, {}
    local function addAreas(ids, kind)
        for _, id in ipairs(ids) do
            areaKindByID[id] = kind
            local name = env.areaName(id)
            if name and name ~= "" then
                areaKind[name] = kind
            end
        end
    end
    addAreas(ns.INSTANCE_AREAS, "instance")
    addAreas(ns.BATTLEGROUND_AREAS, "battleground")
    local ownSort = env.classFile and Categories.CLASS_SORT[env.classFile]

    local function byArea(kind)
        if kind == "instance" then
            return "instances", "instance"
        elseif kind == "battleground" then
            return "pvp", "battleground"
        end
        return "world", "zone"
    end

    -- A QuestSort header is never a zone, so one this table doesn't know yet goes to Divers.
    local function bySort(id)
        if id == ownSort then
            return "classprof", "ownclass"
        end
        local kind = ns.SORT_KIND[id]
        if kind == "profession" or kind == "class" then
            return "classprof", kind
        elseif kind == "event" then
            return "events", "event"
        end
        return "misc", "misc"
    end

    local c = {}

    -- Returns the category and what kind of header it is. key: the header's headerSortKey, whose ID decides in any
    -- language. Without one, the name decides, the first match winning in the plan's order.
    function c.Classify(header, key)
        if header == nil or header == "" then
            return "misc", "none"
        end
        local what, id = decodeKey(key)
        if what == "area" then
            return byArea(areaKindByID[id])
        elseif what == "sort" then
            return bySort(id)
        end
        if env.ownClassName and header == env.ownClassName then
            return "classprof", "ownclass"
        end
        local kind = sortKind[header]
        if kind == "profession" or kind == "class" then
            return "classprof", kind
        end
        local area = areaKind[header]
        if area then
            return byArea(area)
        end
        if kind == "event" then
            return "events", "event"
        elseif kind == "misc" then
            return "misc", "misc"
        end
        return "world", "zone"
    end

    return c
end
