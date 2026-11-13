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

-- A header's key, as the game gives it: 0x40000000 plus an AreaTable ID, 0x20000000 plus a QuestSort ID.
local AREA, SORT = 0x40000000, 0x20000000

local function checkKey(c, header, key, category, kind)
    local got, gotKind = c.Classify(header, key)
    T.Eq(got, category, header .. " category")
    T.Eq(gotKind, kind, header .. " kind")
end

-- German, which has no name table here, so only the keys can tell.
local function german(classFile)
    return ns.Categories.New({ locale = "deDE", classFile = classFile, areaName = function() end })
end

T.Add("Categories", "a header's key decides by its IDs, in any language", function()
    local c = german("WARRIOR")
    checkKey(c, "Krieger", SORT + 81, "classprof", "ownclass")
    checkKey(c, "Magier", SORT + 161, "classprof", "class")
    checkKey(c, "Schmiedekunst", SORT + 121, "classprof", "profession")
    checkKey(c, "Mondfest", SORT + 366, "events", "event")
    checkKey(c, "Ruf", SORT + 367, "misc", "misc")
    checkKey(c, "Die Todesminen", AREA + 1581, "instances", "instance")
    checkKey(c, "Alteractal", AREA + 2597, "pvp", "battleground")
    checkKey(c, "Westfall", AREA + 40, "world", "zone")
end)

T.Add("Categories", "the player's own class by its file, whatever the header's name or form", function()
    checkKey(german("MAGE"), "Magierin", SORT + 161, "classprof", "ownclass")
    checkKey(german("MAGE"), "Krieger", SORT + 81, "classprof", "class")
    checkKey(german(nil), "Krieger", SORT + 81, "classprof", "class")
end)

T.Add("Categories", "a key wins over a name that says otherwise", function()
    local c = french()
    checkKey(c, "Forgeron", AREA + 40, "world", "zone")
    checkKey(c, "Marche de l'Ouest", SORT + 121, "classprof", "profession")
end)

T.Add("Categories", "a QuestSort ID the data doesn't know goes to Divers, as it's never a zone", function()
    checkKey(german(), "Neu", SORT + 9999, "misc", "misc")
end)

T.Add("Categories", "a key of another shape leaves the header to its name", function()
    local c = french()
    checkKey(c, "Forgeron", 12, "classprof", "profession")
    checkKey(c, "Les Mortemines", AREA + SORT + 1581, "instances", "instance")
    checkKey(c, "Fête lunaire", tostring(SORT + 367), "events", "event")
end)

T.Add("Categories", "each class's QuestSort ID is a class header in the game's table, and every one has its class", function()
    local n, classes = 0, 0
    for classFile, id in pairs(ns.Categories.CLASS_SORT) do
        n = n + 1
        T.Eq(ns.SORT_KIND[id], "class", classFile)
        T.Eq(ns.SORT_NAMES.enUS[id]:upper(), classFile, "Blizzard's QuestSort " .. id .. " names that class")
    end
    for _, kind in pairs(ns.SORT_KIND) do
        if kind == "class" then
            classes = classes + 1
        end
    end
    T.Eq(n, classes, "as many classes as class headers")
end)

T.Add("Categories", "each language the addon speaks names every QuestSort header, as English does", function()
    local missing = {}
    for _, locale in ipairs({ "frFR", "enUS", "deDE", "esES", "esMX" }) do
        local names = ns.SORT_NAMES[locale] or {}
        for id in pairs(ns.SORT_KIND) do
            if type(names[id]) ~= "string" or names[id] == "" then
                missing[#missing + 1] = locale .. " " .. id
            end
        end
    end
    table.sort(missing)
    T.Eq(table.concat(missing, ", "), "", "headers without a name")
end)
