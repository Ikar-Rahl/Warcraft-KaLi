-- KaLi HUD's check of its stat cards (UI/Hub/Infos/StatCheck.lua): what a card reads of the game, read here from the
-- game itself in game (offline, from the fake): whatever the character, a level, a race and a class, five attributes,
-- the auras and the gear, each item by its item string with its stats; every value's own calls read; the whole written
-- as Lua that reads back the same, as the bug report gives it. Writes nothing. Not in a fight, the game hiding the
-- values then.
local T = KaLiHUDTests
local ns = KaLiHUDDev.ns

T.Add("cards", "what a card reads of the game, written as the bug report gives it", function()
    if ns.InCombat() then
        T.True(true, "in a fight: nothing read")
        return
    end
    local state = ns.Stats.ReadState()
    T.True(type(state.level) == "number" and state.level > 0, "a level")
    T.True(type(state.race[2]) == "string" and type(state.class[2]) == "string", "a race and a class")
    local five = 0
    for i = 1, 5 do
        five = five + (type(state.stats[i] and state.stats[i][2]) == "number" and 1 or 0)
    end
    T.Eq(five, 5, "five attributes")
    T.True(type(state.auras.HELPFUL) == "table" and type(state.auras.HARMFUL) == "table", "the auras")
    local items = true
    for _, item in pairs(state.items) do
        items = items and tostring(item.item):find("^item:") ~= nil and type(item.stats) == "table"
    end
    T.True(items, "each item by its item string, with its stats")
    local values, read = 0, 0
    for _, s in ipairs(ns.Stats.LIST) do
        if s.sources then
            values = values + 1
            local channel = s.sources.channel and s.sources.channel() or nil
            read = read + (pcall(ns.Stats.ReadValue, s, channel) and 1 or 0)
        end
    end
    T.Eq(read, values, "every value's own calls")
    local text = ns.StatCheck.Literal(state)
    local back = loadstring("return " .. text)
    T.True(back ~= nil and ns.StatCheck.Literal(back()) == text, "the state written as Lua reads back the same")
end)
