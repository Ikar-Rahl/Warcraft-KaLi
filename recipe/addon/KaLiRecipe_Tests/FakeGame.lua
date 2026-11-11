-- A stand-in for the client as the model sees it: names, the current character's item counts, map names. The
-- recipes are the addon's real data, so the tests use real numbers.
local T = KaLiRecipeTests

-- Real recipes, from Data/Recipes.lua (build 1.60.1.70790):
T.R = {
    ribs = 2795, -- Côtes de sanglier à la bière: cooking, item 2889 requires 25, yellow 60, gray 100, makes 2888 from 2886 and 2894
    stew = 2543, -- Ragoût de la marche de l'Ouest: cooking, item 728 requires 75
    robe = 2389, -- Robe rouge en lin: tailoring, item 2598 requires 25
    bracer = 7418, -- Enchantement de brassards (Endurance médiocre): enchanting, taught by the game at rank 1, no item
    steak = 2541, -- Steak de coyote: cooking, a trainer's, no item
}
T.ITEM = { ribs = 2889, stew = 728, robe = 2598, boarRibs = 2888, boarMeat = 2886, beer = 2894 }

function T.FakeGame()
    local g = { spells = {}, items = {}, counts = {}, maps = {}, cats = {} }
    function g:SpellName(id)
        return self.spells[id]
    end
    function g:ItemName(id)
        return self.items[id]
    end
    function g:ItemCount(id)
        return self.counts[id] or 0
    end
    function g:MapName(id)
        return self.maps[id]
    end
    function g:NPCName()
        return nil
    end
    function g:QuestName()
        return nil
    end
    function g:CategoryName(id)
        return self.cats[id]
    end
    g.spells[T.R.ribs] = "Côtes de sanglier à la bière"
    g.spells[T.R.stew] = "Ragoût de la marche de l'Ouest"
    g.spells[T.R.robe] = "Robe rouge en lin"
    g.spells[T.R.bracer] = "Enchantement de brassards (Endurance médiocre)"
    g.spells[T.R.steak] = "Steak de coyote"
    g.items[T.ITEM.boarMeat] = "Côtes de sanglier"
    g.items[T.ITEM.beer] = "Bière de Rhapsody"
    g.items[T.ITEM.boarRibs] = "Côtes de sanglier à la bière"
    g.maps[1438] = "Teldrassil"
    g.maps[1457] = "Darnassus"
    return g
end

local function char(name, profs)
    local c = { name = name, known = {}, bags = {}, bank = {}, profs = {}, maxRanks = {} }
    for skill, rank in pairs(profs) do
        c.profs[skill], c.maxRanks[skill] = rank, 75
    end
    return c
end

-- A model on fresh saved data with two characters: "me", a cook (56) and enchanter (18), and "alt", Elorah, a
-- tailor (70).
function T.NewBook()
    local ns = KaLiRecipeDev.ns
    local db = ns.DB.Load(nil)
    db.chars.me = char("Ikar", { [185] = 56, [333] = 18 })
    db.chars.alt = char("Elorah", { [197] = 70 })
    local game = T.FakeGame()
    local m = ns.Model.New(db, { recipes = ns.RECIPES, items = ns.RECIPE_ITEMS, categories = ns.CATEGORIES,
        categoryNames = ns.CATEGORY_NAMES.frFR }, game, "me")
    return m, db, game
end

-- A sighting at a vendor of Darnassus.
function T.Vendor(npc)
    return { k = "vendor", npc = npc or 4223, map = 1457, x = 0.5, y = 0.4 }
end
