-- D4: pins on the world map where a recipe this character doesn't know was seen, in the game's own pin art, through
-- the world map's own data providers. A click places the game's waypoint there. An option, on by default.
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local MapPins = {}
ns.MapPins = MapPins

local TEMPLATE = "KaLiRecipeMapPinTemplate"
local provider

-- The spots of a map with recipes this character doesn't know: { { x, y, sighting, spells } }, one per place.
function MapPins.Spots(m, map)
    local spots, byKey = {}, {}
    for spell in pairs(m.db.sightings) do
        if not m:Knows(m.me, spell) then
            for _, s in ipairs(m:Sightings(spell)) do
                if s.map == map and s.x and s.y then
                    local key = s.k .. ":" .. tostring(s.npc or "") .. ":" .. math.floor(s.x * 200) .. ":" .. math.floor(s.y * 200)
                    local spot = byKey[key]
                    if not spot then
                        spot = { x = s.x, y = s.y, s = s, spells = {} }
                        byKey[key] = spot
                        spots[#spots + 1] = spot
                    end
                    spot.spells[#spot.spells + 1] = spell
                end
            end
        end
    end
    for _, spot in ipairs(spots) do
        table.sort(spot.spells, function(a, b)
            return ns.TextLess(m:Name(a), m:Name(b))
        end)
    end
    return spots
end

local function defineMixins()
    if KaLiRecipeMapPinMixin or not (MapCanvasPinMixin and MapCanvasDataProviderMixin and CreateFromMixins) then
        return KaLiRecipeMapPinMixin ~= nil
    end
    KaLiRecipeMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
    -- The same size on screen at any zoom, as the quest offer pins (QuestOfferDataProvider.lua): otherwise a pin
    -- grows with the map canvas.
    function KaLiRecipeMapPinMixin:OnLoad()
        self:SetScalingLimits(1, 1.0, 1.2)
    end
    function KaLiRecipeMapPinMixin:OnAcquired(spot)
        self.spot = spot
        self:SetPosition(spot.x, spot.y)
    end
    function KaLiRecipeMapPinMixin:OnMouseEnter()
        ns.SafeCall(function()
            local m, spot = ns.book, self.spot
            local lines = {}
            for i, spell in ipairs(spot.spells) do
                if i > 8 then
                    lines[#lines + 1] = { string.format(L.MORE, #spot.spells - 8), W.GRAY }
                    break
                end
                lines[#lines + 1] = { m:Name(spell), W.WHITE }
            end
            lines[#lines + 1] = { L.PLACE_WAYPOINT, { 0.1, 1, 0.1 } }
            W.TextTooltip(self, ns.Text.Where(m, spot.s), lines)
        end)
    end
    function KaLiRecipeMapPinMixin:OnMouseEnterHandle()
    end
    function KaLiRecipeMapPinMixin:OnMouseLeave()
        W.HideTooltip(self)
    end
    function KaLiRecipeMapPinMixin:OnMouseClickAction(button)
        if button == "LeftButton" then
            ns.SafeCall(W.Waypoint, self.spot.s)
        end
    end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    -- The map calls these in a loop over every provider, its own included: an error here must stay here, or the
    -- providers after this one would not refresh.
    function provider:RemoveAllData()
        ns.SafeCall(function()
            self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
        end)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        ns.SafeCall(function()
            if not (ns.book and ns.db.options.pins) then
                return
            end
            local map = self:GetMap():GetMapID()
            for _, spot in ipairs(MapPins.Spots(ns.book, map)) do
                self:GetMap():AcquirePin(TEMPLATE, spot)
            end
        end)
    end
    return true
end

local added = false
local function attach()
    if added or not (WorldMapFrame and WorldMapFrame.AddDataProvider) or not defineMixins() then
        return
    end
    added = true
    WorldMapFrame:AddDataProvider(provider)
end

function MapPins.Refresh()
    if provider and added and WorldMapFrame:IsShown() then
        provider:RefreshAllData()
    end
end

function MapPins.Start()
    attach()
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_WorldMap" or name == "Blizzard_MapCanvas" then
            attach()
        end
    end)
    ns.OnChange(MapPins.Refresh)
end
