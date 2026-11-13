-- Spotting goes to the chat (Ikar's ruling of 2026-11-09): one line per visit, in the colour of the game's SKILL
-- messages, so the player's own chat colour setting, and in the chat windows that show them. Since 2026-11-10 the
-- line comes with a sound (Core/Sounds.lua): one per visit, the bigger one for a recipe new to the notebook.
local _, ns = ...
local L = ns.L

local Chat = {}
ns.Chat = Chat

local SHOWN = 3

-- The line for recipes noted in one place: "Carnet : 3 recettes notées chez Ellandrieth (Darnassus) : [A], [B],
-- [C] et 2 autres." One looted recipe: "Carnet : [A] notée, butin de Kobold (Elwynn)." link(spell) gives each link.
-- seen[spell], the sighting noted: one at a vendor with a limited stock gets the grey clock after its link, the one
-- name there standing for several recipes, each with its own stock.
function Chat.Line(m, where, spells, link, seen)
    local function linked(spell)
        local s = seen and seen[spell]
        return ns.Text.Limited(s) and link(spell) .. " " .. ns.Text.CLOCK_MARKUP or link(spell)
    end
    local n = #spells
    if n == 0 then
        return nil
    end
    if n == 1 and where.k == "drop" then
        return L.CARNET_PREFIX .. string.format(L.CHAT_SINGLE, linked(spells[1]), ns.Text.At(m, where))
    end
    local links = {}
    for i = 1, math.min(n, SHOWN) do
        links[i] = linked(spells[i])
    end
    local list = table.concat(links, ", ")
    if n > SHOWN then
        list = list .. ns.Plural(n - SHOWN, L.MORE_ONE, L.MORE_MANY)
    end
    return L.CARNET_PREFIX .. string.format(ns.One(n) and L.CHAT_ONE or L.CHAT_MANY, n, ns.Text.At(m, where), list)
end

function Chat.Print(text)
    if not (text and ns.db and ns.db.options.chat) then
        return
    end
    local info = ChatTypeInfo and ChatTypeInfo.SKILL
    local r, g, b = 0.33, 0.33, 1
    if info then
        r, g, b = info.r, info.g, info.b
    end
    local printed = false
    for i = 1, NUM_CHAT_WINDOWS or 0 do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.ContainsMessageGroup and frame:ContainsMessageGroup("SKILL") then
            frame:AddMessage(text, r, g, b)
            printed = true
        end
    end
    if not printed and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b)
    end
end

-- The sound a visit's line brings (Ikar, 2026-11-10): found is what this line noted ("recipe" if one wasn't in the
-- notebook, else "place"), heard what the visit played before. One sound a visit: the bigger one may still follow the
-- smaller, as an auction house's later pages can bring a recipe never met.
function Chat.SoundFor(found, heard)
    if found == "recipe" and heard ~= "recipe" then
        return "recipe"
    elseif found == "place" and not heard then
        return "place"
    end
end

-- A visit gathers what it noted and says it once, a moment after the last, or when the window closes.
local Visit = {}
Visit.__index = Visit

function Chat.Visit(where)
    return setmetatable({ where = where, spells = {}, set = {}, seen = {} }, Visit)
end

-- what: "recipe" or "place", from the model's Note; s, the sighting noted.
function Visit:Add(spell, what, s)
    if self.set[spell] then
        return
    end
    self.set[spell] = true
    self.seen[spell] = s
    self.spells[#self.spells + 1] = spell
    if what == "recipe" or not self.found then
        self.found = what or "place"
    end
    if not self.waiting then
        self.waiting = true
        C_Timer.After(0.6, function()
            self.waiting = nil
            ns.SafeCall(self.Flush, self)
        end)
    end
end

function Visit:Flush()
    if #self.spells == 0 then
        return
    end
    local spells = self.spells
    self.spells = {}
    -- The sound plays whether the chat line is on or not: each is its own option.
    local sound = Chat.SoundFor(self.found, self.heard)
    self.found = nil
    if sound then
        self.heard = sound
        ns.Sounds.Play(sound)
    end
    Chat.Print(Chat.Line(ns.book, self.where, spells, ns.Widgets.RecipeLink, self.seen))
end
