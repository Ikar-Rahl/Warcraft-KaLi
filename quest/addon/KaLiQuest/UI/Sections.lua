-- The tracker's other sections, below Journal: tracked recipes ("Métier") and achievements ("Hauts faits"), read as
-- Blizzard's ProfessionsRecipeTracker and AchievementObjectiveTracker read them, with their clicks and menus. See
-- tracker-parity.md, Recipes and Achievements. Blizzard's own sections stay parked.
local _, ns = ...

local Sections = {}
ns.Sections = Sections

local MAX_CRITERIA = 5 -- Blizzard's MAX_CRITERIA_PER_ACHIEVEMENT

local call = ns.Call

-- Recipes ---------------------------------------------------------------------------------------------------

local function reagentType(name)
    return Enum and Enum.CraftingReagentType and Enum.CraftingReagentType[name]
end

local waiting = {} -- items whose names were asked for
local recipesTracked = false

-- An item's name, or nil and true while it loads; its ITEM_DATA_LOAD_RESULT then redraws.
local function reagentName(reagent)
    if reagent.itemID and C_Item then
        local name = call(C_Item.GetItemNameByID, reagent.itemID)
        if not name then
            waiting[reagent.itemID] = true
            call(C_Item.RequestLoadItemDataByID, reagent.itemID)
            return nil, true
        end
        return name
    elseif reagent.currencyID and C_CurrencyInfo then
        local info = call(C_CurrencyInfo.GetCurrencyInfo, reagent.currencyID)
        return info and info.name
    end
end

local function owned(reagents)
    local n = 0
    for _, r in ipairs(reagents or {}) do
        if r.itemID then
            local count = ItemUtil and call(ItemUtil.GetCraftingReagentCount, r.itemID)
            n = n + (count or C_Item and call(C_Item.GetItemCount, r.itemID, true, false, true, true) or 0)
        elseif r.currencyID and C_CurrencyInfo then
            local info = call(C_CurrencyInfo.GetCurrencyInfo, r.currencyID)
            n = n + (info and info.quantity or 0)
        end
    end
    return n
end

local function same(a, b)
    return (a.itemID and a.itemID ~= 0 and a.itemID == b.itemID) or (a.currencyID and a.currencyID ~= 0 and a.currencyID == b.currencyID)
end

local function required(slot, reagent)
    for _, v in ipairs(slot.variableQuantities or {}) do
        if v.reagent and same(reagent, v.reagent) then
            return v.quantity
        end
    end
    return slot.quantityRequired or 0
end

-- Required reagents only, modifying ones first, as "have/need name"; one met is checked and grey.
local function recipe(recipeID, recraft)
    local schematic = call(C_TradeSkillUI.GetRecipeSchematic, recipeID, recraft)
    if type(schematic) ~= "table" or not schematic.name then
        return nil
    end
    local title = recraft and ns.G("PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER", "Refaçonner : %s"):format(schematic.name) or schematic.name
    local basic, modifying = reagentType("Basic"), reagentType("Modifying")
    local slots = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.required then
            if slot.reagentType == modifying then
                table.insert(slots, 1, slot)
            else
                slots[#slots + 1] = slot
            end
        end
    end
    local format = ns.G("PROFESSIONS_TRACKER_REAGENT_FORMAT", "%s %s")
    local lines, loading = {}, false
    for i, slot in ipairs(slots) do
        local reagent = slot.reagents and slot.reagents[1]
        local name, pending
        if reagent and slot.reagentType == basic then
            name, pending = reagentName(reagent)
            loading = loading or pending == true
        elseif slot.reagentType == modifying then
            name = slot.slotInfo and slot.slotInfo.slotText
        end
        if name then
            local variable = slot.variableQuantities or {}
            if #variable > 0 then
                -- As Blizzard's: the player's choice isn't kept, so a variable quantity shows its range.
                local min, max = math.huge, 0
                for _, v in ipairs(variable) do
                    min, max = math.min(min, v.quantity), math.max(max, v.quantity)
                end
                local range = ns.G("PROFESSIONS_TRACKER_REAGENT_RANGE_FORMAT", "(%d – %d)"):format(min, max)
                lines[#lines + 1] = { key = i, text = format:format(range, name), style = "normal", dash = true }
            else
                local need, have = required(slot, reagent), owned(slot.reagents)
                local met = have >= need
                local count = ns.G("PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT", "%s / %d"):format(have, need)
                lines[#lines + 1] = { key = i, text = format:format(count, name), style = met and "complete" or "normal", dash = not met,
                    check = met }
            end
        end
    end
    -- As Blizzard's, a recipe shows once all its items' names have loaded, not line by line.
    if loading then
        return nil
    end
    return { kind = "recipe", key = (recraft and "rr" or "r") .. recipeID, id = recipeID, recraft = recraft, title = title, lines = lines }
end

-- Achievements ----------------------------------------------------------------------------------------------

local timedCriteria = {} -- criteriaID -> { achievementID, start, duration }: timers of achievements without criteria
local earned = {} -- entry key -> { entry, index, started }: an achievement just earned, kept while its turn-in plays
local lastAchievements = {} -- the last read's achievement entries, in order

local function timerOf(duration, elapsed)
    if duration and elapsed and elapsed < duration then
        return { duration = duration, start = GetTime() - elapsed }
    end
end

-- Up to five unfinished criteria, then "...". Progress bars read as quests' x/y, and a meta criterion takes the
-- other achievement's name. One the player can't get any more is in the failed colour. A running timer adds a bar.
local function achievement(id)
    local _, name, _, _, _, _, _, description, _, _, _, _, earnedByMe = GetAchievementInfo(id)
    if not name or earnedByMe then
        return nil
    end
    local lines = {}
    local count = GetAchievementNumCriteria(id) or 0
    if count > 0 then
        local shown = 0
        for i = 1, count do
            local text, criteriaType, done, _, _, _, flags, assetID, quantityString, _, eligible, duration, elapsed = GetAchievementCriteriaInfo(id, i)
            if done or shown > MAX_CRITERIA then
                -- Not shown.
            elseif shown == MAX_CRITERIA and count > MAX_CRITERIA + 1 then
                lines[#lines + 1] = { key = "extra", text = "...", style = "normal", dash = false }
                shown = shown + 1
            else
                -- EVALUATION_TREE_FLAG_PROGRESS_BAR is the lowest bit.
                if description and flags and flags % 2 == 1 then
                    if quantityString and quantityString:find("[Mm][Oo][Nn][Ee][Yy][Ff][Rr][Aa][Mm][Ee]") then
                        text = quantityString .. "\n" .. description
                    else
                        text = (tostring(quantityString or ""):gsub(" / ", "/")) .. " " .. description
                    end
                elseif criteriaType == (CRITERIA_TYPE_ACHIEVEMENT or 8) and assetID then
                    text = select(2, GetAchievementInfo(assetID)) or text
                end
                lines[#lines + 1] = { key = i, text = text, style = eligible and "normal" or "failed", dash = true,
                    timer = timerOf(duration, elapsed) }
                shown = shown + 1
            end
        end
    else
        -- As Blizzard's: these timers come only with TRACKED_ACHIEVEMENT_UPDATE, and one run out fails it.
        local timer, failed
        for _, t in pairs(timedCriteria) do
            if t.achievementID == id then
                timer = timerOf(t.duration, GetTime() - t.start)
                failed = timer == nil
                break
            end
        end
        local eligible = not failed and (not IsAchievementEligible or call(IsAchievementEligible, id) ~= false)
        lines[1] = { key = 1, text = description or "", style = eligible and "normal" or "failed", dash = true, timer = timer }
    end
    return { kind = "achievement", key = "a" .. id, id = id, title = name, lines = lines }
end

-- The sections with something tracked, in order: { { id, entries = { { kind, key, id, title, lines } } } }.
function Sections.Read()
    local out = {}
    local recipes = {}
    recipesTracked = false
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked then
        -- Recrafts first, as Blizzard's.
        for _, recraft in ipairs({ true, false }) do
            for _, recipeID in ipairs(call(C_TradeSkillUI.GetRecipesTracked, recraft) or {}) do
                recipesTracked = true
                recipes[#recipes + 1] = recipe(recipeID, recraft)
            end
        end
    end
    if #recipes > 0 then
        out[#out + 1] = { id = "recipes", entries = recipes }
    end
    local achievements = {}
    local kind = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    if kind and C_ContentTracking and C_ContentTracking.GetTrackedIDs and GetAchievementInfo then
        for _, id in ipairs(call(C_ContentTracking.GetTrackedIDs, kind) or {}) do
            achievements[#achievements + 1] = achievement(id)
        end
    end
    lastAchievements = { unpack(achievements) }
    -- One just earned keeps its place while its turn-in plays.
    for key, l in pairs(earned) do
        local listed = false
        for _, e in ipairs(achievements) do
            listed = listed or e.key == key
        end
        if listed then
            earned[key] = nil
        else
            table.insert(achievements, math.min(l.index, #achievements + 1), l.entry)
        end
    end
    if #achievements > 0 then
        out[#out + 1] = { id = "achievements", entries = achievements }
    end
    return out
end

-- Clicks and menus, as Blizzard's ------------------------------------------------------------------------------

local function chatLink(link)
    local chat = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
    if chat and link and ChatFrameUtil.InsertLink then
        ChatFrameUtil.InsertLink(link)
        return true
    end
    return false
end

local function untrack(e)
    if e.kind == "recipe" then
        call(C_TradeSkillUI.SetRecipeTracked, e.id, false, e.recraft)
    else
        local stop = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual
        call(C_ContentTracking.StopTracking, Enum.ContentTrackingType.Achievement, e.id, stop)
        -- As Blizzard's untrack: an open achievement window shows its tracking box unticked.
        if AchievementFrame and AchievementFrame:IsShown() and AchievementFrameAchievements_ForceUpdate then
            AchievementFrameAchievements_ForceUpdate()
        end
    end
    ns.RequestRefresh()
end

-- The game's windows can't open in combat from an addon, so the click says why.
local function openRecipe(e)
    if e.recraft then
        return
    end
    if not ProfessionsFrame and ProfessionsFrame_LoadUI then
        ProfessionsFrame_LoadUI()
    end
    if call(C_TradeSkillUI.IsRecipeProfessionLearned, e.id) then
        C_TradeSkillUI.OpenRecipe(e.id)
    elseif Professions and Professions.InspectRecipe then
        Professions.InspectRecipe(e.id)
    end
end

local function openAchievement(e)
    if not AchievementFrame and AchievementFrame_LoadUI then
        AchievementFrame_LoadUI()
    end
    if not (AchievementFrame and AchievementFrame_ToggleAchievementFrame and AchievementFrame_SelectAchievement) then
        return
    end
    if not AchievementFrame:IsShown() then
        AchievementFrame_ToggleAchievementFrame()
        AchievementFrame_SelectAchievement(e.id)
    elseif AchievementFrameAchievements and AchievementFrameAchievements.selection ~= e.id then
        AchievementFrame_SelectAchievement(e.id)
    else
        AchievementFrame_ToggleAchievementFrame()
    end
end

local function menu(owner, e)
    local s = ns.Tracker.Shared
    s.menu(owner, function(description)
        if e.kind == "recipe" then
            description:SetTag("MENU_PROFESSIONS_RECIPE_TRACKER")
            description:CreateTitle(e.title)
            local inBook = C_SpellBook and Enum and Enum.SpellBookSpellBank
                and call(C_SpellBook.IsSpellInSpellBook, e.id, Enum.SpellBookSpellBank.Player, false)
            if not e.recraft and inBook then
                s.button(description, ns.G("PROFESSIONS_TRACKING_VIEW_RECIPE", "Voir la recette"), function()
                    if InCombatLockdown() then
                        s.refuse("combat")
                    else
                        C_TradeSkillUI.OpenRecipe(e.id)
                    end
                end)
            end
            s.button(description, ns.G("PROFESSIONS_UNTRACK_RECIPE", "Arrêter le suivi"), function()
                untrack(e)
            end)
        else
            description:SetTag("MENU_ACHIEVEMENT_TRACKER", { id = e.id })
            description:CreateTitle(e.title)
            s.button(description, ns.G("OBJECTIVES_VIEW_ACHIEVEMENT", "Ouvrir le haut fait"), function()
                if InCombatLockdown() then
                    s.refuse("combat")
                elseif ShowAchievementFrameForAchievement then
                    ShowAchievementFrameForAchievement(e.id)
                end
            end)
            s.button(description, ns.G("OBJECTIVES_STOP_TRACKING", "Arrêter le suivi"), function()
                untrack(e)
            end)
        end
    end)
end

function Sections.Click(owner, e, button)
    if IsModifiedClick("CHATLINK") then
        local link
        if e.kind == "recipe" then
            link = C_TradeSkillUI.GetRecipeLink and call(C_TradeSkillUI.GetRecipeLink, e.id)
        else
            link = call(GetAchievementLink, e.id)
        end
        if chatLink(link) then
            return
        end
    end
    if button == "RightButton" then
        menu(owner, e)
    elseif IsModifiedClick(e.kind == "recipe" and "RECIPEWATCHTOGGLE" or "QUESTWATCHTOGGLE") then
        untrack(e)
    elseif InCombatLockdown() then
        ns.Tracker.Shared.refuse("combat")
    elseif e.kind == "recipe" then
        openRecipe(e)
    else
        openAchievement(e)
    end
end

-- The events Blizzard's two sections redraw on. Bags, currencies and item data come often, so they redraw only when
-- a recipe is tracked or a name is awaited.
function Sections.Watch()
    for _, event in ipairs({ "CONTENT_TRACKING_UPDATE", "TRACKED_ACHIEVEMENT_UPDATE", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "ACHIEVEMENT_EARNED",
        "TRACKED_RECIPE_UPDATE" }) do
        ns.On(event, ns.RequestRefresh)
    end
    local function forRecipes()
        if recipesTracked then
            ns.RequestRefresh()
        end
    end
    ns.On("BAG_UPDATE_DELAYED", forRecipes)
    ns.On("CURRENCY_DISPLAY_UPDATE", forRecipes)
    ns.On("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
        if waiting[itemID] then
            waiting[itemID] = nil
            if success then
                ns.RequestRefresh()
            end
        end
    end)
    ns.On("TRACKED_ACHIEVEMENT_UPDATE", function(_, achievementID, criteriaID, elapsed, duration)
        if achievementID and criteriaID and elapsed and duration and (GetAchievementNumCriteria(achievementID) or 0) == 0 then
            timedCriteria[criteriaID] = { achievementID = achievementID, start = GetTime() - elapsed, duration = duration }
        end
    end)
    ns.On("ACHIEVEMENT_EARNED", function(_, achievementID)
        for i, e in ipairs(lastAchievements) do
            if e.id == achievementID and not earned[e.key] then
                local copy = {}
                for k, v in pairs(e) do
                    copy[k] = v
                end
                copy.leaving = true
                earned[e.key] = { entry = copy, index = i }
            end
        end
    end)
end

-- An earned achievement's turn-in, as Blizzard's TurnInAnim: the glow sweeps its title, then it fades and goes.
function Sections.PlayEarned(row, e)
    local l = earned[e.key]
    if not l or l.started then
        return
    end
    l.started = true
    ns.Motion.FadeOut(row, 0.66, true, function()
        earned[e.key] = nil
    end)
end

-- An earned achievement not drawn, its bar closed or filtered away, goes at once, and its bar's count with it.
function Sections.DropUndrawn(drawn)
    for key, l in pairs(earned) do
        if not l.started and not drawn[key] then
            earned[key] = nil
            ns.RequestRefresh()
        end
    end
end

-- The tracker coming back on: one earned while Blizzard's tracker showed doesn't play its turn-in again.
function Sections.Reset()
    wipe(earned)
end

-- How many recipes and achievements are tracked, for the debug panel, read without touching what the bars keep.
function Sections.TrackedCounts()
    local recipes = 0
    if C_TradeSkillUI then
        for _, recraft in ipairs({ true, false }) do
            recipes = recipes + #(call(C_TradeSkillUI.GetRecipesTracked, recraft) or {})
        end
    end
    local kind = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    local achievements = kind and C_ContentTracking and #(call(C_ContentTracking.GetTrackedIDs, kind) or {}) or 0
    return recipes, achievements
end

-- Other addons' frames on a parked section's header, as Auctionator's recipe search, sit on that section's bar while
-- it's drawn, left of its count, and go back to the header otherwise. See docs/addon-extensions.md.
local SECTION_OF = { recipes = "ProfessionsRecipeTracker", achievements = "AchievementObjectiveTracker" }
local adopted = {} -- in the order found: { frame, id, parent, points, placed, away }

local function adoptFrom(id)
    local section = _G[SECTION_OF[id]]
    local header = section and section.Header
    if not header then
        return
    end
    for _, child in ipairs({ header:GetChildren() }) do
        local known = child == header.MinimizeButton or child:IsProtected()
        for _, a in ipairs(adopted) do
            known = known or a.frame == child
        end
        if not known then
            local points = {}
            for i = 1, child:GetNumPoints() do
                points[i] = { child:GetPoint(i) }
            end
            adopted[#adopted + 1] = { frame = child, id = id, parent = header, points = points }
        end
    end
end

local function giveBack(a)
    a.frame:SetParent(a.parent)
    a.frame:ClearAllPoints()
    for _, p in ipairs(a.points) do
        a.frame:SetPoint(unpack(p))
    end
    a.away = false
end

function Sections.BeginAdopt()
    for _, a in ipairs(adopted) do
        a.placed = false
    end
end

-- During a bar's layout: its adopted frames, right to left from right. Returns the room they take.
function Sections.Adopt(bar, id, right)
    adoptFrom(id)
    local room = 0
    for _, a in ipairs(adopted) do
        if a.id == id then
            a.frame:SetParent(bar)
            a.frame:ClearAllPoints()
            a.frame:SetPoint("RIGHT", bar, "RIGHT", -(right + room + 4), 0)
            a.placed, a.away = true, true
            if a.frame:IsShown() then
                room = room + 4 + (a.frame:GetWidth() or 0)
            end
        end
    end
    return room
end

-- After a layout: frames whose bar wasn't drawn go home.
function Sections.EndAdopt()
    for _, a in ipairs(adopted) do
        if a.away and not a.placed then
            giveBack(a)
        end
    end
end

-- The tracker off: every frame goes home, to be found again when it's back on.
function Sections.ReleaseAdopted()
    for _, a in ipairs(adopted) do
        if a.away then
            giveBack(a)
        end
    end
    wipe(adopted)
end
