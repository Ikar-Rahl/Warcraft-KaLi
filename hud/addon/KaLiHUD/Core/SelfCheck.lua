-- KaLi HUD's assumptions about the game, tried on the player's own (Shared/SelfCheck.lua runs them at login and in
-- each report, and says once in chat when one fails): the frames the plate takes are Edit Mode's, Edit Mode says when
-- one moves, textures take a gradient, the info bar's sources answer, and the folders' icons and their names are the
-- game's.
local _, ns = ...

local SelfCheck = ns.SelfCheck

-- Frames every Forever client has, by global name; a main bar under either of its names.
local EXPECTED = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar",
    "MicroMenuContainer", "BagsBar", "ChatFrame1", "MinimapCluster" }

SelfCheck.Add("frames", function()
    local wrong, looked = {}, 0
    local names = { ns.Frames.Get("MainActionBar") and "MainActionBar" or "MainMenuBar" }
    for _, name in ipairs(EXPECTED) do
        names[#names + 1] = name
    end
    for _, name in ipairs(names) do
        looked = looked + 1
        if not ns.Frames.Get(name) then
            wrong[#wrong + 1] = name .. " isn't an Edit Mode frame here"
        end
    end
    return looked, wrong
end)

SelfCheck.Add("edit mode", function()
    local wrong = {}
    local m = EditModeManagerFrame
    for _, method in ipairs({ "IsEditModeActive", "OnSystemPositionChange" }) do
        if type(m) ~= "table" or type(m[method]) ~= "function" then
            wrong[#wrong + 1] = "EditModeManagerFrame:" .. method .. " missing"
        end
    end
    return 2, wrong
end)

local probe
SelfCheck.Add("textures", function()
    local wrong = {}
    probe = probe or ns.Plate.frame and ns.Plate.frame:CreateTexture()
    local t = probe
    if not t then
        return 0, wrong, "plate not built"
    end
    local ok, err = pcall(t.SetGradient, t, "VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(1, 1, 1, 1))
    if not ok then
        wrong[#wrong + 1] = "SetGradient with colours: " .. tostring(err)
    end
    t:Hide()
    return 1, wrong
end)

SelfCheck.Add("info sources", function()
    local wrong = {}
    if type(C_Reputation) ~= "table" or type(C_Reputation.GetWatchedFactionData) ~= "function" then
        wrong[#wrong + 1] = "C_Reputation.GetWatchedFactionData missing"
    end
    if type(C_TooltipInfo) ~= "table" or type(C_TooltipInfo.GetInventoryItem) ~= "function" then
        wrong[#wrong + 1] = "C_TooltipInfo.GetInventoryItem missing"
    end
    for _, c in ipairs(ns.Items.CHANNELS) do
        if GetCVar(c.cvar) == nil then
            wrong[#wrong + 1] = "CVar " .. c.cvar .. " missing"
        end
    end
    return 2 + #ns.Items.CHANNELS, wrong
end)

-- The folders' icon library (Data/Icons.lua), made from this build's data: each atlas (one the game lacks takes no place
-- in the picker, and a folder wearing it shows the question mark), each name the game gives (one it lacks shows ours,
-- in French or English). What's gone says to make the library again (hud/tools/make_icons.py).
SelfCheck.Add("icons", function()
    local wrong, looked = {}, 0
    for _, icon in ipairs(ns.ICONS) do
        looked = looked + 1
        if not C_Texture.GetAtlasInfo(icon[1]) then
            wrong[#wrong + 1] = "atlas " .. icon[1] .. " missing"
        end
        if icon.game then
            looked = looked + 1
            if type(SelfCheck.Resolve(icon.game)) ~= "string" then
                wrong[#wrong + 1] = "name " .. icon.game .. " missing"
            end
        end
    end
    return looked, wrong
end)
