-- The others (Ikar 2026-11-16: "guilds, all in a folder", "group and raid tool, all in a folder"): the guild's members
-- online and its message of the day, the friends online, the group's loot rules and difficulty, with the raid's tools
-- as macros of the game's own commands (UI/Hub/Seeds.lua makes them: the ready check, the countdown, the world
-- markers). A list of people is a tooltip's and a menu's, never items that come and go in a folder.
local _, ns = ...

local Infos, Hub, L, Format = ns.Infos, ns.Hub, ns.L, ns.Format

local SEP = ns.Seeds.SEP
-- At most this many people in a tooltip or a menu.
local MOST = 30
-- A message of the day on its button, at most this many letters.
local MOTD_LETTERS = 28

-- The first n letters of a text, whole letters (UTF-8), "…" after when it's longer.
local function letters(text, n)
    local out, count = {}, 0
    for ch in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then
            return table.concat(out) .. "…"
        end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function classColored(name, classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    return c and c:WrapTextInColorCode(name) or name
end

-- Whisper and invite, from a menu of people { name, label }.
local function peopleMenu(list)
    local whisper, invite = {}, {}
    for _, p in ipairs(list) do
        whisper[#whisper + 1] = { text = p.label, func = function()
            ns.Call(ChatFrameUtil and ChatFrameUtil.SendTell, p.name)
        end }
        invite[#invite + 1] = { text = p.label, func = function()
            ns.Call(C_PartyInfo.InviteUnit, p.name)
        end }
    end
    if #list == 0 then
        return {}
    end
    return { { text = ns.G("WHISPER", "Whisper"), items = whisper }, { text = ns.G("INVITE", "Invite"), items = invite } }
end

-- ---------- The guild ----------

local GUILD, MOTD = "KaLiHUD_Guild", "KaLiHUD_GuildMotd"

-- Its message of the day, as the guild's window reads it.
local function guildMotd()
    local motd = ns.Plain(ns.Call(C_GuildInfo.GetMOTD))
    return type(motd) == "string" and motd or ""
end

-- Its members online: { name, label, level, zone, class }, and how many in all.
local function guildOnline()
    local list = {}
    if not IsInGuild() then
        return list, 0
    end
    local total = GetNumGuildMembers() or 0
    for i = 1, total do
        local name, _, _, level, _, zone, _, _, online, _, class = ns.Plain(GetGuildRosterInfo(i))
        if online and type(name) == "string" then
            local short = Ambiguate and Ambiguate(name, "guild") or name
            list[#list + 1] = { name = name, label = classColored(short, class), level = level, zone = zone }
        end
    end
    table.sort(list, function(a, b)
        return ns.TextLess(a.name, b.name)
    end)
    return list, total
end

Hub.Add(GUILD, {
    type = "data source", text = "", atlas = "friends-icon-tab-guildmates", category = "social", home = "guild",
    label = ns.G("GUILD", "Guild"),
    OnTooltipShow = function(tooltip)
        if not IsInGuild() then
            Infos.Title(tooltip, ns.G("GUILD", "Guild"))
            Infos.Text(tooltip, L.GUILD_NONE)
            return
        end
        local guildName = GetGuildInfo("player")
        Infos.Title(tooltip, guildName or ns.G("GUILD", "Guild"))
        local list, total = guildOnline()
        Infos.Line(tooltip, ns.G("GUILD_ONLINE_LABEL", "Online"), string.format("%d/%d", #list, total))
        for i, p in ipairs(list) do
            if i > MOST then
                Infos.Hint(tooltip, string.format(L.AND_MORE, #list - MOST))
                break
            end
            tooltip:AddDoubleLine(p.label .. " " .. tostring(p.level or ""), tostring(p.zone or ""), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        Infos.Hint(tooltip, L.HINT_GUILD)
    end,
    OnClick = Infos.Opener(function()
        ToggleGuildFrame()
    end),
    menu = function()
        return peopleMenu((guildOnline()))
    end,
}, "hidden", 600)

Hub.Add(MOTD, {
    -- an announcement's mark (the library's « Point d'exclamation »)
    type = "data source", text = "", atlas = "map-icon-ignored-blueexclaimation", category = "social", home = "guild",
    label = ns.G("GUILD_MOTD_LABEL", "Message of the Day"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("GUILD_MOTD_LABEL", "Message of the Day"))
        local motd = IsInGuild() and guildMotd() or ""
        Infos.Text(tooltip, motd ~= "" and motd or L.MOTD_NONE)
        Infos.Hint(tooltip, L.HINT_GUILD)
    end,
    OnClick = Infos.Opener(function()
        ToggleGuildFrame()
    end),
}, "hidden", 610)

local function updateGuild()
    local list = guildOnline()
    Hub.Set(GUILD, "text", IsInGuild() and tostring(#list) or "—")
    local motd = IsInGuild() and guildMotd() or ""
    Hub.Set(MOTD, "text", motd ~= "" and letters(motd, MOTD_LETTERS) or "—")
end

-- The roster asked of the server at login and every minute or so (the game answers at its own pace).
local function askRoster()
    if IsInGuild() then
        ns.Call(C_GuildInfo.GuildRoster)
    end
end
Infos.OnStart(askRoster)
Infos.Updates(askRoster, nil, 60)
Infos.Updates(updateGuild, { "PLAYER_ENTERING_WORLD", "GUILD_ROSTER_UPDATE", "GUILD_MOTD", "PLAYER_GUILD_UPDATE" })

-- ---------- The friends ----------

local FRIENDS = "KaLiHUD_Friends"

-- The friends online in the game: { name, label, level, zone }; and those of Battle.net, how many.
local function friendsOnline()
    local list = {}
    for i = 1, ns.Call(C_FriendList.GetNumFriends) or 0 do
        local f = ns.Plain(ns.Call(C_FriendList.GetFriendInfoByIndex, i))
        if type(f) == "table" and f.connected and type(f.name) == "string" then
            list[#list + 1] = { name = f.name, label = f.name, level = f.level, zone = f.area }
        end
    end
    local _, bnet = ns.Call(BNGetNumFriends)
    return list, type(bnet) == "number" and bnet or 0
end

Hub.Add(FRIENDS, {
    type = "data source", text = "", atlas = "friends-icon-tab-friends", category = "social", home = "guild",
    label = ns.G("FRIENDS", "Friends"),
    OnTooltipShow = function(tooltip)
        local list, bnet = friendsOnline()
        Infos.Title(tooltip, ns.G("FRIENDS", "Friends"))
        for i, p in ipairs(list) do
            if i > MOST then
                break
            end
            tooltip:AddDoubleLine(p.label .. " " .. tostring(p.level or ""), tostring(p.zone or ""), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        if #list == 0 then
            Infos.Text(tooltip, L.FRIENDS_NONE)
        end
        if bnet > 0 then
            Infos.Line(tooltip, L.FRIENDS_BNET, tostring(bnet))
        end
        Infos.Hint(tooltip, L.HINT_FRIENDS)
    end,
    OnClick = Infos.Opener(function()
        ToggleFriendsFrame(1)
    end),
    menu = function()
        return peopleMenu((friendsOnline()))
    end,
}, "hidden", 620)

local function updateFriends()
    local list, bnet = friendsOnline()
    Hub.Set(FRIENDS, "text", tostring(#list + bnet))
end
Infos.Updates(updateFriends, { "PLAYER_ENTERING_WORLD", "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE" })

ns.Seeds.Contents.guild = { GUILD, MOTD, SEP, FRIENDS }

-- ---------- The group ----------

local LOOT, DIFFICULTY = "KaLiHUD_Loot", "KaLiHUD_Difficulty"
-- The game's names of its loot rules (Enum.LootMethod's order).
local METHODS = { [0] = "LOOT_FREE_FOR_ALL", "LOOT_ROUND_ROBIN", "LOOT_MASTER_LOOTER", "LOOT_GROUP_LOOT",
    "LOOT_NEED_BEFORE_GREED", "LOOT_PERSONAL_LOOT" }
local DIM = { 0.5, 0.5, 0.5 }

local function lootRule()
    local method = ns.Call(C_PartyInfo.GetLootMethod)
    local words = type(method) == "number" and METHODS[method] and _G[METHODS[method]] or nil
    local threshold = ns.Call(GetLootThreshold)
    local quality = type(threshold) == "number" and _G["ITEM_QUALITY" .. threshold .. "_DESC"] or nil
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[threshold]
    return words, quality and (color and color.hex and (color.hex .. quality .. "|r") or quality) or nil
end

-- The rule's own words after the game's « Butin : ».
local function short(words)
    return (tostring(words):gsub("^[^:]+:%s*", ""))
end

-- Whether the player sets the group's rules: its leader, as the game's own portrait menu allows.
local function leads()
    return IsInGroup() and UnitIsGroupLeader("player") and true or false
end

-- The rules, set from the item by the group's leader (Ikar 2026-11-20: "the group loot shoudl also allow to change it
-- when clicked"), as the game's portrait menu sets them (Blizzard_UnitPopup's loot buttons): each method the game
-- offers here, the master looter the leader himself; the threshold, but under personal loot, from the unusual to the
-- epic, in their colours.
local MASTER, PERSONAL = 2, 5
local function lootMenu(_, root)
    root:CreateTitle(ns.G("LOOT_METHOD", "Loot Method"))
    for method = 0, PERSONAL do
        local name = METHODS[method] and ns.G(METHODS[method])
        if name and ns.Call(C_PartyInfo.IsLootMethodAvailable, method) ~= false then
            root:CreateRadio(name, function()
                return ns.Call(C_PartyInfo.GetLootMethod) == method
            end, ns.Guarded(function()
                ns.Call(C_PartyInfo.SetLootMethod, method, method == MASTER and UnitName("player") or nil)
            end))
        end
    end
    if ns.Call(C_PartyInfo.GetLootMethod) ~= PERSONAL then
        root:CreateDivider()
        root:CreateTitle(ns.G("LOOT_THRESHOLD", "Loot Threshold"))
        for quality = 2, 4 do
            local words = ns.G("ITEM_QUALITY" .. quality .. "_DESC")
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if words then
                root:CreateRadio(color and color.hex and (color.hex .. words .. "|r") or words, function()
                    return ns.Call(GetLootThreshold) == quality
                end, ns.Guarded(function()
                    ns.Call(SetLootThreshold, quality)
                end))
            end
        end
    end
end

Hub.Add(LOOT, {
    type = "data source", text = "", atlas = "VignetteLoot", category = "group", home = "group",
    label = ns.G("LOOT_METHOD", "Loot Method"),
    OnTooltipShow = function(tooltip)
        local words, quality = lootRule()
        Infos.Title(tooltip, ns.G("LOOT_METHOD", "Loot Method"))
        if not IsInGroup() then
            Infos.Text(tooltip, L.GROUP_NONE)
        end
        Infos.Text(tooltip, words or "—")
        Infos.Line(tooltip, ns.G("LOOT_THRESHOLD", "Loot Threshold"), quality or "—")
        Infos.Hint(tooltip, leads() and L.HINT_LOOT or L.LOOT_TIP)
    end,
    -- the leader's click opens the rules; anyone else's, nothing (the tooltip says who sets them)
    OnClick = function(self, button)
        if button == "LeftButton" and leads() then
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, ns.Guarded(lootMenu))
        end
    end,
}, "hidden", 700)

local function difficulty()
    local id = ns.Call(GetDungeonDifficultyID)
    local name = type(id) == "number" and ns.Plain(ns.Call(GetDifficultyInfo, id)) or nil
    return name
end

Hub.Add(DIFFICULTY, {
    type = "data source", text = "", atlas = "GM-icon-difficulty-normal", category = "group", home = "group",
    label = ns.G("DUNGEON_DIFFICULTY", "Dungeon Difficulty"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("DUNGEON_DIFFICULTY", "Dungeon Difficulty"))
        Infos.Text(tooltip, difficulty() or "—")
        Infos.Hint(tooltip, string.format(L.HINT_RESET, ns.G("RESET_INSTANCES", "Reset all instances")))
    end,
    menu = {
        { text = ns.G("RESET_INSTANCES", "Reset all instances"), held = true, func = function()
            if not ns.CombatRefused() then
                ns.Call(ResetInstances)
            end
        end },
    },
}, "hidden", 710)

local function updateGroup()
    local words, quality = lootRule()
    local grouped = IsInGroup()
    Hub.Set(LOOT, "textColor", grouped and nil or DIM)
    Hub.Set(LOOT, "text", grouped and words and (short(words) .. (quality and (" · " .. quality) or "")) or "—")
    Hub.Set(DIFFICULTY, "text", difficulty() or "—")
end
Infos.Updates(updateGroup, { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED",
    "PLAYER_DIFFICULTY_CHANGED", "UPDATE_INSTANCE_INFO" })

-- The raid's tools: the game's own commands, run by the player's click (secure macros: placing a world marker is
-- the game's to allow, Blizzard's slash commands its own way to). World markers in the order the raid's menu lists
-- them (Blizzard_CompactRaidFrameManager's WORLD_RAID_MARKER_ORDER: the skull first), each named and drawn as the
-- raid target of the same sign (WORLD_MARKERn's: /wm 1 the blue square...), its icon as the raid frame's
-- (GM-raidMarker of 9 less the sign).
local function command(name, fallback)
    return ns.G(name, fallback)
end
local group = { LOOT, DIFFICULTY, SEP,
    { seed = "readycheck", name = ns.G("READY_CHECK", "Ready Check"), icon = "GM-icon-readyCheck",
        text = command("SLASH_READYCHECK1", "/readycheck") },
    { seed = "countdown", name = ns.G("COUNTDOWN", "Countdown"), icon = "GM-icon-countdown",
        text = command("SLASH_COUNTDOWN1", "/countdown") .. " 10" },
    -- the markers under their title, from a column of their own: nine to it, none cut in two (Ikar 2026-11-20: "fais
    -- un tour sur tous nos menus")
    ns.Seeds.Title(function() return L.GROUP_MARKERS end, true) }
local MARKERS, SIGNS = { 8, 4, 1, 7, 2, 3, 6, 5 }, { 6, 4, 3, 7, 1, 2, 5, 8 }
for _, marker in ipairs(MARKERS) do
    local sign = SIGNS[marker]
    group[#group + 1] = { seed = "marker" .. marker,
        name = string.format(L.WORLD_MARKER, ns.G("RAID_TARGET_" .. sign, tostring(sign))),
        icon = "GM-raidMarker" .. (9 - sign),
        -- its left click the sign on the target, its right click the marker on the ground (Ikar 2026-11-20: "they
        -- shoudl be left click on target right click spell on ground"), with no [@cursor]: on a button the pointer is
        -- on the button, never on the ground ("the cursor will be by definition at the button"); without it the
        -- game's targeting circle comes, and a click on the ground sets the marker there
        text = command("SLASH_TARGET_MARKER1", "/tm") .. " " .. sign,
        right = command("SLASH_WORLD_MARKER1", "/wm") .. " " .. marker,
        leftDesc = L.MARKER_TARGET, rightDesc = L.MARKER_GROUND }
end
-- « Tout effacer » clears both (Ikar 2026-11-20: "tout effacer remove only the one on the ground"): the ground's by
-- /cwm all, the targets' signs by the game's own secure action for it (SECURE_ACTIONS.raidtarget's "clear-all", the
-- raid frame's reset: RemoveRaidTargets, restricted, so run from a secure button), which no slash command has. A button
-- of the addon's, sizeless and never seen, clicked by the same macro (/click, its release).
local CLEAR_SIGNS = "KaLiHUD_ClearSigns"
local clearSigns = CreateFrame("Button", CLEAR_SIGNS, nil, "SecureActionButtonTemplate")
local function armClearSigns()
    if InCombatLockdown() then
        return
    end
    ns.Off("PLAYER_REGEN_ENABLED", armClearSigns)
    clearSigns:RegisterForClicks("AnyUp")
    clearSigns:SetAttribute("useOnKeyDown", false)
    clearSigns:SetAttribute("type", "raidtarget")
    clearSigns:SetAttribute("action", "clear-all")
end
ns.On("PLAYER_REGEN_ENABLED", armClearSigns)
armClearSigns()
group[#group + 1] = { seed = "clearmarkers", name = ns.G("REMOVE_WORLD_MARKERS", "Clear All"), icon = "uitools-icon-close",
    text = command("SLASH_CLEAR_WORLD_MARKER1", "/cwm") .. " " .. string.lower(ns.G("ALL", "all")) .. "\n"
        .. command("SLASH_CLICK1", "/click") .. " " .. CLEAR_SIGNS,
    leftDesc = L.MARKERS_CLEAR }
ns.Seeds.Contents.group = group

-- For the tests.
ns.Social = { GuildOnline = guildOnline, FriendsOnline = friendsOnline, Letters = letters, CLEAR_SIGNS = CLEAR_SIGNS }
