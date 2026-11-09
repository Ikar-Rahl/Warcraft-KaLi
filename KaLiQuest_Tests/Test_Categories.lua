local T = KaLiQuestTests
local ns = KaLiQuestDev.ns

local AREAS = { [1581] = "Les Mortemines", [3277] = "Goulet des Chanteguerres", [2597] = "Vallée d'Alterac" }

local function french(ownClass)
    return ns.Categories.New({
        locale = "frFR",
        ownClassName = ownClass or "Guerrier",
        areaName = function(id)
            return AREAS[id]
        end,
    })
end

local function check(c, header, category, kind)
    local got, gotKind = c.Classify(header)
    T.Eq(got, category, tostring(header) .. " category")
    if kind then
        T.Eq(gotKind, kind, tostring(header) .. " kind")
    end
end

T.Add("Categories", "the player's class header, in its masculine form", function()
    local c = french("Guerrier")
    check(c, "Guerrier", "classprof", "ownclass")
end)

T.Add("Categories", "a female character's class name isn't the header", function()
    -- QuestSort uses the masculine form, so comparing with UnitClass would miss this header.
    local c = french("Guerrier")
    check(c, "Guerrière", "world", "zone")
end)

T.Add("Categories", "professions and other classes go to Classe et métiers", function()
    local c = french()
    check(c, "Forgeron", "classprof", "profession")
    check(c, "Premiers soins", "classprof", "profession")
    check(c, "Voleur", "classprof", "class")
end)

T.Add("Categories", "instances by their area's name", function()
    check(french(), "Les Mortemines", "instances", "instance")
end)

T.Add("Categories", "Forever's own dungeons are instances too, such as La salle des Thanes", function()
    local listed = false
    for _, id in ipairs(ns.INSTANCE_AREAS) do
        listed = listed or id == 16919
    end
    T.True(listed, "area 16919 is in the list")
    local c = ns.Categories.New({
        locale = "frFR",
        areaName = function(id)
            return id == 16919 and "La salle des Thanes" or nil
        end,
    })
    check(c, "La salle des Thanes", "instances", "instance")
end)

T.Add("Categories", "battlegrounds by their area's name", function()
    local c = french()
    check(c, "Goulet des Chanteguerres", "pvp", "battleground")
    check(c, "Vallée d'Alterac", "pvp", "battleground")
end)

T.Add("Categories", "events and the rest", function()
    local c = french()
    check(c, "Fête lunaire", "events", "event")
    check(c, "Foire de Sombrelune", "events", "event")
    check(c, "Réputation", "misc", "misc")
    check(c, "Carte au trésor", "misc", "misc")
end)

T.Add("Categories", "anything else is a zone, under Monde", function()
    local c = french()
    check(c, "Marche de l'Ouest", "world", "zone")
    check(c, "Une zone de Forever inconnue", "world", "zone")
end)

T.Add("Categories", "no header goes to Divers", function()
    check(french(), nil, "misc", "none")
end)

T.Add("Categories", "English names on an English client", function()
    local c = ns.Categories.New({ locale = "enUS", ownClassName = "Warrior", areaName = function() end })
    check(c, "Blacksmithing", "classprof", "profession")
    check(c, "Darkmoon Faire", "events", "event")
    check(c, "Forgeron", "world", "zone")
end)

T.Add("Categories", "a language with no table falls back to English", function()
    local c = ns.Categories.New({ locale = "ptBR", areaName = function() end })
    check(c, "Cooking", "classprof", "profession")
end)

T.Add("Categories", "an area the game can't name is skipped", function()
    local c = ns.Categories.New({ locale = "frFR", areaName = function() return nil end })
    check(c, "Les Mortemines", "world", "zone")
end)
