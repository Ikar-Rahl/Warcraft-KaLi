-- Small pieces every window shares: colours, the level badge, the markers' art, frames made safely, tooltips and
-- menus through Blizzard's own functions.
local _, ns = ...

local W = {}
ns.Widgets = W

-- Frames start without a parent, then get one: SmartNavigationMixin hooks CreateFrame (KaLi Quest's rule).
function W.Frame(kind, parent, template, name)
    local f = CreateFrame(kind, name, nil, template)
    if parent then
        f:SetParent(parent)
    end
    return f
end

-- The addon's tooltip lines are blue, the crafting colour (Ikar's ruling of 2026-11-09): the light blue the game
-- itself gives « Composant d'artisanat ». The tooltips read that line's own colour the first time one shows it; until
-- then, a light blue close to it.
local DEFAULT_BLUE = { 0.4, 0.733, 1 }
function W.AddonColor()
    local c = KaLiRecipeDevDB and KaLiRecipeDevDB.reagentColor
    if type(c) == "table" and type(c[1]) == "number" then
        return c[1], c[2], c[3]
    end
    return DEFAULT_BLUE[1], DEFAULT_BLUE[2], DEFAULT_BLUE[3]
end

function W.NoteReagentColor(color)
    if type(color) == "table" and type(color.r) == "number" and KaLiRecipeDevDB then
        KaLiRecipeDevDB.reagentColor = { color.r, color.g, color.b }
    end
end

-- The professions window's difficulty colours, and red for a rank too low.
W.DIFFICULTY = {
    red = { 1, 0.1, 0.1 },
    optimal = { 1, 0.5, 0.25 },
    medium = { 1, 1, 0 },
    easy = { 0.25, 0.75, 0.25 },
    trivial = { 0.5, 0.5, 0.5 },
    other = { 0.6, 0.6, 0.6 },
}
W.GOLD = { 1, 0.82, 0 }
W.GRAY = { 0.6, 0.6, 0.6 }
W.WHITE = { 1, 1, 1 }
-- Book's ink, the game's parchment text (PARCHMENT_MATERIAL_TEXT_COLOR).
W.INK = { 0.18, 0.12, 0.06 }

function W.Hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function W.AddonHex()
    local r, g, b = W.AddonColor()
    return W.Hex({ r, g, b })
end

-- The markers' art, all the game's own (decided on the bench, 2026-11-09).
W.ATLAS = {
    known = "Tracker-Check",
    badge = "UI-HUD-Nameplates-LevelIndicator",
    banker = "Banker",
    friend = "groupfinder-icon-friend",
    follow = "Profession-button-arrow-right",
    followDown = "Profession-button-arrow-right-pressed",
    pin = "Waypoint-MapPin-Tracked",
    tab = "spellbook-skilllinetab",
    hammer = "UI-HUD-MicroMenu-Professions-Up",
    gear = "questlog-icon-setting",
}
-- The world quest pins' small profession icons, for crafted items.
W.PROF_ATLAS = {
    [171] = "worldquest-icon-alchemy", [164] = "worldquest-icon-blacksmithing", [185] = "worldquest-icon-cooking",
    [333] = "worldquest-icon-enchanting", [202] = "worldquest-icon-engineering", [129] = "worldquest-icon-firstaid",
    [356] = "worldquest-icon-fishing", [182] = "worldquest-icon-herbalism", [165] = "worldquest-icon-leatherworking",
    [186] = "worldquest-icon-mining", [393] = "worldquest-icon-skinning", [197] = "worldquest-icon-tailoring",
}
-- Book's parchment per profession: its quest page. All twelve (Ikar, 2026-11-10: first aid, herbalism, mining and
-- skinning had the plain page); first aid's is Forever's own (questbg-firstaid-c60, which the game names without -c60).
W.QUEST_BG = {
    [185] = "QuestBG-cooking", [333] = "QuestBG-enchanting", [197] = "QuestBG-tailoring", [171] = "QuestBG-alchemy",
    [165] = "QuestBG-leatherworking", [164] = "QuestBG-blacksmithing", [202] = "QuestBG-engineering",
    [356] = "QuestBG-fishing", [129] = "QuestBG-FirstAid", [182] = "QuestBG-herbalism", [186] = "QuestBG-mining",
    [393] = "QuestBG-skinning",
}
-- Clean's art per profession (Ikar, 2026-11-10: "add them to the minimalist design"): the card Forever's professions
-- window puts behind a recipe (Professions.GetProfessionBackgroundFormat, Camelot's), dark, the profession sketched in
-- its bottom right.
W.CARD = {
    [171] = "Profession-background-card-Alchemy", [164] = "Profession-background-card-Blacksmithing",
    [185] = "Profession-background-card-Cooking", [333] = "Profession-background-card-Enchanting",
    [202] = "Profession-background-card-Engineering", [129] = "Profession-background-card-FirstAid",
    [356] = "Profession-background-card-Fishing", [182] = "Profession-background-card-Herbalism",
    [165] = "Profession-background-card-leatherworking", [186] = "Profession-background-card-Mining",
    [393] = "Profession-background-card-skinning", [197] = "Profession-background-card-Tailoring",
}
W.PARCHMENT = "QuestBG-Parchment"

-- Some atlases may be missing from a build; a texture without one stays empty rather than green.
function W.SetAtlas(texture, name, useSize)
    if ns.Call(C_Texture.GetAtlasInfo, name) then
        texture:SetAtlas(name, useSize)
        return true
    end
    texture:SetTexture(nil)
    return false
end

-- The required rank as KaLi Quest shows quest levels: a coloured number on Forever's nameplate level art.
function W.Badge(parent, width, height)
    local b = W.Frame("Frame", parent)
    b:SetSize(width or 26, height or 16)
    b.bg = b:CreateTexture(nil, "ARTWORK")
    b.bg:SetAllPoints()
    W.SetAtlas(b.bg, W.ATLAS.badge)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, 0)
    return b
end

-- Shows a recipe's level in its colour for a character: red if out of reach, the difficulty colour otherwise, gray for
-- a profession the character doesn't have. "?" when no rank is known yet.
function W.SetBadge(b, spell, key)
    local m = ns.book
    key = key or m.me
    local info = m:Info(spell)
    local state = m:State(spell, key)
    local colour
    if state == "other" then
        colour = W.DIFFICULTY.other
    else
        colour = W.DIFFICULTY[m:Difficulty(spell, m:Rank(key, info.skill), state == "known")]
    end
    b.text:SetText(info.req and tostring(info.req) or "?")
    b.text:SetTextColor(colour[1], colour[2], colour[3])
end

-- Simple pools: frames are never destroyed in WoW, so they're kept and reused.
function W.Pool(make)
    local pool = { free = {}, used = {} }
    function pool:Acquire()
        local f = table.remove(self.free) or make()
        self.used[#self.used + 1] = f
        f:Show()
        return f
    end
    function pool:ReleaseAll()
        for _, f in ipairs(self.used) do
            f:Hide()
            f:ClearAllPoints()
            self.free[#self.free + 1] = f
        end
        self.used = {}
    end
    return pool
end

-- A recipe's real tooltip: its item's, so Auctionator and the like add their lines; a trainer's recipe, its spell's.
-- The addon's own lines come from the tooltip post-calls, as anywhere else.
function W.RecipeTooltip(owner, spell, anchor)
    local info = ns.book:Info(spell)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if info and info.item then
        GameTooltip:SetItemByID(info.item)
    else
        GameTooltip:SetSpellByID(spell)
    end
    GameTooltip:Show()
end

function W.ItemTooltip(owner, item, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(item)
    GameTooltip:Show()
end

-- A short tooltip of the addon's own: a white title, then lines { text, colour }.
function W.TextTooltip(owner, title, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    for _, line in ipairs(lines or {}) do
        local c = line[2] or W.GRAY
        GameTooltip:AddLine(line[1], c[1], c[2], c[3], true)
    end
    GameTooltip:Show()
end

function W.HideTooltip(owner)
    if GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

-- A recipe's link for chat: its item's, or its spell's for a trainer's recipe; the name in brackets while the item
-- hasn't loaded.
function W.RecipeLink(spell)
    local info = ns.book:Info(spell)
    if info and info.item then
        local _, link = ns.Call(C_Item.GetItemInfo, info.item)
        if link then
            return link
        end
    end
    local link = ns.Call(C_Spell and C_Spell.GetSpellLink, spell)
    if link then
        return link
    end
    return W.Hex(W.GOLD) .. "[" .. ns.book:Name(spell) .. "]|r"
end

-- Into the chat's input line, as a shift-click on a link does.
function W.InsertLink(link)
    if not link then
        return false
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        return ChatFrameUtil.InsertLink(link)
    end
    return false
end

-- The game's waypoint on a sighting's spot, and the map's arrow to it.
function W.Waypoint(s)
    if not (s and s.map and s.x and s.y and UiMapPoint and C_Map.SetUserWaypoint) then
        ns.Say(ns.L.NO_SPOT)
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(s.map) then
        ns.Say(ns.L.WAYPOINT_REFUSED)
        return false
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.map, s.x, s.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    ns.Say(string.format(ns.L.WAYPOINT_SET, ns.Text.Where(ns.book, s)))
    return true
end

-- The first sighting with a spot on the map.
function W.SpotOf(spell)
    for _, s in ipairs(ns.book:Sightings(spell)) do
        if s.map and s.x and s.y then
            return s
        end
    end
end
