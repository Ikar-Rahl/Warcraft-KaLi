-- Who the addon is, for the code the KaLi addons share (Shared/, loaded next: events, guarded calls, the debug log),
-- then KaLi HUD's own helpers. Everything else hangs from ns.
local _, ns = ...

ns.TITLE = "KaLi HUD"
-- The debug log's chat prefix, and the slash command the shared code names.
ns.SHORT = "KH"
ns.SLASH = "/kh"

-- Internal and unstable, for KaLiHUD_Tests and debugging. Not an API for other addons.
KaLiHUDDev = { ns = ns }

-- The addon's own textures (hud/tools/make_media.py), white or greyscale so the code colours them.
ns.DISC = "Interface\\AddOns\\KaLiHUD\\Media\\Disc"
ns.FILLET = "Interface\\AddOns\\KaLiHUD\\Media\\Fillet"
ns.BEVEL = "Interface\\AddOns\\KaLiHUD\\Media\\Bevel"
-- the same turned left for right, for masks: a mask in game doesn't take a mirrored SetTexCoord
ns.FILLET_MIRROR = "Interface\\AddOns\\KaLiHUD\\Media\\FilletMirror"
ns.BEVEL_MIRROR = "Interface\\AddOns\\KaLiHUD\\Media\\BevelMirror"
ns.SHADOW = "Interface\\AddOns\\KaLiHUD\\Media\\Shadow"
ns.RING = "Interface\\AddOns\\KaLiHUD\\Media\\Ring"
ns.CHEVRON = "Interface\\AddOns\\KaLiHUD\\Media\\Chevron"
-- The borders across, outside first: the KaLi one (the plate's edge, the map's ring) and the status bars' thin one.
ns.BAND_KALI = "Interface\\AddOns\\KaLiHUD\\Media\\BandKaLi"
ns.BAND_THIN = "Interface\\AddOns\\KaLiHUD\\Media\\BandThin"
ns.BAND_GRAIN = "Interface\\AddOns\\KaLiHUD\\Media\\BandGrain"
-- The background's materials by style, smooth has none: Blizzard's own tiling backgrounds, an atlas that is a whole
-- file or a file 256 units a tile; lum, the mean of the texture desaturated (0..1), so tinted it keeps the colour's light.
ns.MATERIALS = {
    rock = { atlas = "UI-Background-Rock-Brown", lum = 0.185 },
    stone = { atlas = "bank-frame-background", lum = 0.223 },
    darkstone = { atlas = "UI-Frame-Dragonflight-BackgroundTile", lum = 0.064 },
    marble = { file = "Interface\\FrameGeneral\\UI-Background-Marble", lum = 0.052 },
    leather = { atlas = "GarrLanding-MiddleTile", lum = 0.248 },
    wood = { atlas = "gamepad-mapquestlog-bgtile-2k", lum = 0.228 },
    planks = { atlas = "UI-Frame-Neutral-BackgroundTile", lum = 0.072 },
    masonry = { atlas = "UI-Frame-Alliance-BackgroundTile", lum = 0.083 },
    parchment = { atlas = "AdventureMap_TileBg_Parchment", lum = 0.452 },
}
ns.BAR_FOREVER = "Interface\\AddOns\\KaLiHUD\\Media\\Bar"
ns.BAR_STRIPED = "Interface\\AddOns\\KaLiHUD\\Media\\BarStriped"
ns.LOCK = "Interface\\AddOns\\KaLiHUD\\Media\\Lock"
ns.UNLOCK = "Interface\\AddOns\\KaLiHUD\\Media\\Unlock"

-- Sounds, { opening, shutting }: kits of Forever's SoundKit table, by SOUNDKIT's name where the game gives one. A
-- window folded and unfolded (Ikar 2026-11-15 picked the tome drawn and put away), a folder's list (the housing
-- sub-menu's).
ns.FOLD_SOUNDS = {
    tome = { 19971, 19972 },
    parchment = { 1192, 1209 },
    questlog = { "IG_QUEST_LOG_OPEN", "IG_QUEST_LOG_CLOSE" },
    page = { "IG_ABILITY_PAGE_TURN", "IG_ABILITY_PAGE_TURN" },
    book = { 1184, 1201 },
    cloth = { 1185, 1202 },
    paper = { 281255, 281255 },
}
ns.FOLD_SOUND_ORDER = { "tome", "parchment", "questlog", "page", "book", "cloth", "paper" }
ns.FOLDER_SOUNDS = {
    submenu = { "HOUSING_PRIMARY_SUB_MENU_BUTTON_TOGGLE", "HOUSING_PRIMARY_SUB_MENU_BUTTON_TOGGLE" },
    click = { "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_MAINMENU_OPTION_CHECKBOX_OFF" },
    tab = { "IG_CHARACTER_INFO_TAB", "IG_CHARACTER_INFO_TAB" },
    button = { "IG_MAINMENU_OPTION", "IG_MAINMENU_OPTION" },
    waypoint = { "UI_MAP_WAYPOINT_BUTTON_CLICK_ON", "UI_MAP_WAYPOINT_BUTTON_CLICK_OFF" },
    bag = { "GUILD_BANK_OPEN_BAG", "GUILD_BANK_OPEN_BAG" },
}
ns.FOLDER_SOUND_ORDER = { "submenu", "click", "tab", "button", "waypoint", "bag" }

-- This character's key in the saved data: its realm and name.
function ns.CharKey()
    return (GetRealmName() or "?") .. "-" .. (UnitName("player") or "?")
end

-- A question asked before something of the player's is reset, replaced or dropped (Ikar 2026-11-19: "User should
-- never loose it settings. All reset, écrasement and replacement should be deliberate decision (confirmation popup,
-- etc)"): `text`, then the game's yes and no; done() on yes, nothing on no or Escape.
function ns.Ask(text, done)
    StaticPopupDialogs.KALIHUD_ASK = StaticPopupDialogs.KALIHUD_ASK or {
        text = "%s",
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = function(_, data)
            ns.SafeCall(data)
        end,
    }
    StaticPopup_Show("KALIHUD_ASK", text, nil, done)
end

-- One of those, opening or shutting; nothing for "none" or a name the game doesn't know.
function ns.PlaySoundOf(sounds, key, opening)
    local pair = sounds[key]
    local kit = pair and pair[opening and 1 or 2]
    if type(kit) == "string" then
        kit = type(SOUNDKIT) == "table" and SOUNDKIT[kit]
    end
    if type(kit) == "number" then
        PlaySound(kit)
    end
end
