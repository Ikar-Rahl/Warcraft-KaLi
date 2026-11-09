-- Which tracker category a quest log header belongs to. The header decides both the category and the group
-- inside it, so most quests sort themselves. See docs/organiser-design.md, "How a header is classified".
local _, ns = ...

local Categories = {}
ns.Categories = Categories

-- Journal's categories, in their default order.
Categories.ORDER = { "world", "classprof", "instances", "events", "pvp", "misc" }

-- env.locale: the client's language. env.ownClassName: LOCALIZED_CLASS_NAMES_MALE[classFile], because the log's
-- class headers use the masculine form. env.areaName(areaID): the area's name in the client's language.
function Categories.New(env)
    local sortKind = {}
    local names = ns.SORT_NAMES[env.locale] or ns.SORT_NAMES.enUS
    for id, name in pairs(names) do
        local kind = ns.SORT_KIND[id]
        if kind then
            sortKind[name] = kind
        end
    end
    local areaKind = {}
    for _, id in ipairs(ns.INSTANCE_AREAS) do
        local name = env.areaName(id)
        if name and name ~= "" then
            areaKind[name] = "instance"
        end
    end
    for _, id in ipairs(ns.BATTLEGROUND_AREAS) do
        local name = env.areaName(id)
        if name and name ~= "" then
            areaKind[name] = "battleground"
        end
    end

    local c = {}

    -- Returns the category and what kind of header it is. The first match wins, in the plan's order.
    function c.Classify(header)
        if header == nil or header == "" then
            return "misc", "none"
        end
        if env.ownClassName and header == env.ownClassName then
            return "classprof", "ownclass"
        end
        local kind = sortKind[header]
        if kind == "profession" then
            return "classprof", "profession"
        elseif kind == "class" then
            return "classprof", "class"
        end
        local area = areaKind[header]
        if area == "instance" then
            return "instances", "instance"
        elseif area == "battleground" then
            return "pvp", "battleground"
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
