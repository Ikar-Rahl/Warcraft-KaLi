-- Starts KaLi Recipe and its probe on the fake API the way the game does, plays a session (a vendor, a trainer, the
-- auction house, loot, a quest reward, the bags, the professions window), opens every window and runs every slash
-- command. Run by recipe/tools/run_tests.py after the addons' files are loaded. Returns a list of failures.
local F = FakeWoW
local failures = {}
local function expect(ok, what)
    if not ok then
        failures[#failures + 1] = what
    end
end
local function chatHas(text)
    for _, line in ipairs(F.chat) do
        if line.text:find(text, 1, true) then
            return true
        end
    end
    return false
end
local function tooltipHas(text)
    for _, line in ipairs(F.tooltip.lines) do
        if tostring(line):find(text, 1, true) then
            return true
        end
    end
    return false
end
local function run(fn, ...)
    local ok, err = pcall(fn, ...)
    expect(ok, "error: " .. tostring(err))
end
local function slash(text)
    run(SlashCmdList.KALIRECIPE, text)
    F.RunTimers()
end
-- The addon's sounds since the last call, as "kit,kit", a stopped one as "kit/fade", one at a volume asked of the game
-- as "kit@volume", on another channel than the effects' "kit@volume!channel" (the collapse toggles' click left out).
local function heard()
    local out = {}
    for _, s in ipairs(F.sounds) do
        if s.kit ~= SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            local fade = F.stopped[s.handle]
            out[#out + 1] = s.kit .. (s.volume and ("@" .. s.volume) or "") .. (s.volume and s.channel ~= "SFX" and ("!" .. tostring(s.channel)) or "")
                .. (fade and ("/" .. fade) or "")
        end
    end
    F.sounds = {}
    return table.concat(out, ",")
end
-- The quill to its end, the quill stopped early and fading out, a parchment laid down: at the default 200 %, twice
-- each kit's own volume, the parchment's capped at full.
local QUILL, STROKE, PARCHMENT = "3093@0.6", "3093@0.6/200", "1209@1"

local ns = KaLiRecipeDev.ns
local L = ns.L
-- The options window (Ikar, 2026-11-13: "dans une fenêtre séparée"): a row of it, and a value set as its control sets
-- it, the change made in the window.
local options = ns.Options.handle
local function optionRow(key)
    for _, section in ipairs(options:Sections()) do
        for _, row in ipairs(section.rows) do
            if row.key == key then
                return row
            end
        end
    end
end
local function setOption(key, value)
    local row = optionRow(key)
    if not row then
        error("the options window has no row " .. key)
    end
    options:Set(row, value)
end
local function defaultOption(key)
    setOption(key, options:Default(optionRow(key)))
end
-- The frame showing a row, once the window is built.
local function windowRow(key)
    for _, f in ipairs(KaLiRecipeOptions and KaLiRecipeOptions.rows or {}) do
        if f.row.key == key then
            return f
        end
    end
end

-- Names the game would give.
F.itemNames[2889] = "Recette : Côtes de sanglier à la bière"
F.itemNames[728] = "Recette : Ragoût de la marche de l'Ouest"
F.itemNames[2598] = "Patron : Robe rouge en lin"
F.itemNames[6326] = "Recette : Maquereau ombré"
F.itemNames[16110] = "Recette : Rôti de raptor"
F.itemNames[2406] = "Patron : Bottes en cuir fin"
F.itemNames[159] = "Eau douce"
F.itemNames[2886] = "Côtes de sanglier"
F.itemNames[2888] = "Côtes de sanglier à la bière"
F.itemTooltips[2886] = { "Côtes de sanglier", "Composant d’artisanat" }
F.spellNames[2795] = "Côtes de sanglier à la bière"
F.spellNames[2543] = "Ragoût de la marche de l'Ouest"
F.spellNames[2541] = "Steak de coyote"
F.spellNames[2389] = "Robe rouge en lin"
for _, item in ipairs({ 2889, 728, 2598, 6326, 16110, 2406, 21099 }) do
    F.itemClass[item] = 9
end
F.mapID, F.playerPos = 1457, { 0.5, 0.4 }

-- ---------- Login ----------
F.Fire("ADDON_LOADED", "KaLiRecipe")
-- Events the game fires while it loads, before PLAYER_LOGIN makes the model: nothing breaks, nothing is lost.
for _, event in ipairs({ "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "TRADE_SKILL_LIST_UPDATE", "LEARNED_SPELL_IN_SKILL_LINE" }) do
    F.Fire(event)
end
F.RunTimers()
expect(next(KaLiRecipeDevDB.errors or {}) == nil, "events before login: no error, got " .. tostring(next(KaLiRecipeDevDB.errors or {})))
F.Fire("PLAYER_LOGIN")
F.RunTimers()
expect(ns.db ~= nil, "saved data loaded")
expect(KaLiRecipeDB == ns.db, "the saved table is the addon's")
expect(ns.book ~= nil, "the model made")
local me = ns.Game.Key()
local c = ns.db.chars[me]
expect(c ~= nil and c.name == "Ikar", "the character recorded")
expect(c and c.profs[185] == 56 and c.profs[333] == 18, "its professions and ranks")
expect(F.settingsRegistered ~= nil, "the options page registered")
local written = {}
for key in pairs(ns.db.options) do
    written[#written + 1] = key
end
expect(#written == 0, "the options page writes no default into the saved data: " .. table.concat(written, ", "))
expect(ns.tooltipsOn == true, "tooltip post-calls added")
expect(#F.postCalls[0] == 1 and #F.postCalls[1] == 1, "one item and one spell post-call")
expect(type(KaLiRecipeDevDB.apiChecks) == "table" and #KaLiRecipeDevDB.apiChecks == 1, "the API check kept for this build")

-- ---------- A vendor ----------
F.npc, F.npcName = "Creature-0-1-0-1-4223-0001", "Ellandrieth"
F.merchant = { 159, 2889, 728, 2598 }
-- What the vendor asks: money for the ribs, three tokens for the stew.
F.merchantPrices[2889] = 1250
F.merchantCosts[728] = { { 133784, 3, "|cffffffff|Hitem:20558::|h[Marque]|h|r" } }
-- One left of the ribs; the stew without limit (Ikar, 2026-11-13: store it, show a grey clock when limited).
F.merchantStock[2889] = 1
F.chat = {}
heard()
F.Fire("MERCHANT_SHOW")
F.RunTimers()
F.Fire("MERCHANT_CLOSED")
expect(heard() == QUILL, "recipes new to the notebook: the quill, once for the visit")
local s = ns.db.sightings[2795] and ns.db.sightings[2795][1]
expect(s and s.k == "vendor" and s.npc == 4223 and s.map == 1457 and s.x == 0.5, "the vendor's recipe noted with NPC and spot")
expect(ns.db.sightings[2543] and ns.db.sightings[2389], "every recipe item noted")
expect(ns.db.sightings[159] == nil, "water isn't a recipe")
expect(ns.db.sightings[2795][1].cost == 1250, "the vendor's price kept with the sighting")
local tokens = ns.db.sightings[2543] and ns.db.sightings[2543][1].costs
expect(tokens and tokens[1].n == 3 and tokens[1].item == 20558 and tokens[1].tex == 133784, "and its tokens, by item")
expect(ns.db.sightings[2795][1].stock == 1 and ns.db.sightings[2543][1].stock == -1,
    "the vendor's stock as the game gives it: 1 left of the ribs, no limit on the stew")
expect(F.chat[1] and F.chat[1].text:find("[Recette : Côtes de sanglier à la bière]|h|r " .. ns.Text.CLOCK_MARKUP, 1, true)
    and select(2, F.chat[1].text:gsub(ns.Text.CLOCK_MARKUP:gsub("%p", "%%%0"), "")) == 1,
    "the visit's line puts the grey clock after the limited recipe's link only: " .. tostring(F.chat[1] and F.chat[1].text))
expect(#F.chat == 1, "one chat line for the visit, got " .. #F.chat)
expect(chatHas(string.format(L.CHAT_MANY, 3, string.format(L.AT_NPC, "Ellandrieth", "Darnassus"), "")
    :sub(1, 20)), "the line counts three recipes: " .. tostring(F.chat[1] and F.chat[1].text))
expect(F.chat[1] and F.chat[1].b == 1, "in the SKILL colour")
F.chat = {}
F.Advance(3)
F.merchantStock[2889] = 0
F.Fire("MERCHANT_SHOW")
F.RunTimers()
F.Fire("MERCHANT_CLOSED")
expect(#F.chat == 0, "a second visit says nothing new")
expect(ns.db.sightings[2795][1].stock == 1, "sold out at the second visit, the highest seen stays")
F.merchantStock[2889] = nil
expect(heard() == "", "and plays nothing")
-- Its marks.
MerchantFrame:Show()
run(MerchantFrame_UpdateMerchantInfo)
local o = MerchantItem2ItemButton.fakeChildren and MerchantItem2ItemButton.fakeChildren[1]
expect(o and o.badge and o.badge:IsShown(), "the learnable recipe's rank badge on the vendor's slot")
local o3 = MerchantItem3ItemButton.fakeChildren and MerchantItem3ItemButton.fakeChildren[1]
expect(o3 and o3.badge:IsShown() and o3.badge.text:GetText() == "75", "the rank too low, its number")
local o1 = MerchantItem1ItemButton.fakeChildren and MerchantItem1ItemButton.fakeChildren[1]
expect(o1 and not o1.badge:IsShown() and not o1.check:IsShown(), "nothing on water")
MerchantFrame:Hide()

-- ---------- A trainer ----------
F.npc, F.npcName = "Creature-0-1-0-1-5000-0001", "Maître queux"
F.trainer = {
    { "Steak de coyote", "available", "Cuisine", 50, 2541, nil, 450 },
    { "Côtes de sanglier à la bière", "used", "Cuisine", 25, nil, "|Hitem:2888::|h" },
    { "Cuisinier compagnon", "available", "Cuisine", 50, 19887, nil },
}
F.chat = {}
F.Advance(3)
F.Fire("TRAINER_SHOW")
F.RunTimers()
F.Fire("TRAINER_CLOSED")
expect(heard() == QUILL, "the trainer's steak, new to the notebook: the quill")
expect(ns.db.reqs[2541] == 50, "the trainer's required rank kept")
expect(c.known[2795] == true, "« Déjà connu » at the trainer: known")
expect(ns.Scan.trainerStats.tooltip == 1 and ns.Scan.trainerStats.product == 1 and ns.Scan.trainerStats.other == 1,
    "recognised by tooltip and by item; the rank isn't a recipe")
expect(#F.chat == 1 and chatHas("Maître queux"), "one line: the steak, the known ribs left out")
local steak = ns.db.sightings[2541] and ns.db.sightings[2541][1]
expect(steak and steak.cost == 450, "the trainer's price kept")
expect(steak and ns.Text.Price(steak) ~= nil, "and shown")

-- ---------- The auction house ----------
F.chat = {}
F.Advance(3)
-- Opening the house sends nothing, however long it stays open: the addon never searches in the player's place (Ikar,
-- 2026-11-10). Its button does, on a click; it's there from the start, at the bottom right, with the browse list only.
AuctionHouseFrame:Show()
F.ahQuery = nil
F.Fire("AUCTION_HOUSE_SHOW")
F.Advance(120)
F.RunTimers()
expect(F.ahQuery == nil, "the house open two minutes: no search sent")
local ahButton = ns.Markers.AuctionButton()
expect(ahButton and ahButton:IsShown(), "the button, there from the start")
local point, rel, relPoint
if ahButton then
    point, rel, relPoint = ahButton:GetPoint()
end
expect(point == "BOTTOMRIGHT" and rel == AuctionHouseFrame and relPoint == "BOTTOMRIGHT", "at the bottom right, by the money")
expect(ahButton and ahButton:GetParent() == AuctionHouseFrame, "the auction house's, so its dialogs cover it")
AuctionHouseFrame.BrowseResultsFrame:Hide()
expect(not ahButton:IsShown(), "another page: the button goes")
AuctionHouseFrame.BrowseResultsFrame:Show()
expect(ahButton:IsShown(), "back to the list: it's back")
-- The player's own search: the stew, seen at the vendor, at a new place; the known ribs say nothing. Nothing sent after.
F.ahResults = { { itemKey = { itemID = 2889 } }, { itemKey = { itemID = 728 } } }
F.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
F.Advance(120)
F.RunTimers()
expect(heard() == STROKE, "a new place for a recipe in the notebook: a stroke, the quill stopped early")
expect(F.ahQuery == nil, "the player's search answered: still nothing sent")
-- The click, Auctionator busy: the Recipes category all the same, as the game's own search button would send.
-- A recipe never met: the bigger sound may follow the smaller, past the quiet gap.
F.ahBusy = true
ahButton:GetScript("OnClick")(ahButton)
F.ahBusy = nil
expect(F.ahQuery and F.ahQuery.itemClassFilters[1].classID == 9, "clicked, another addon busy: a search on the Recipes category")
expect(ahButton:IsShown(), "and the button stays, for another")
F.Advance(3)
F.ahResults = { { itemKey = { itemID = 2889 } }, { itemKey = { itemID = 728 } }, { itemKey = { itemID = 6326 } } }
F.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
F.RunTimers()
expect(heard() == QUILL, "then a recipe new to the notebook: the whole quill")
expect(ns.Scan.ah.answered ~= nil, "the search's answer noted")
expect(ns.db.sightings[7752] and ns.db.sightings[7752][1].k == "ah", "a recipe listed at the auction house noted")
-- No marks on the list's rows, Blizzard's or Auctionator's (Ikar, 2026-11-13): the recipe's tooltip says it all.
F.AuctionRow(2889, 3)
F.AuctionRow(728, 3)
F.AuctionRow(728, 139)
AuctionHouseFrame.BrowseResultsFrame.ItemList:CallRefreshCallback()
local marked = 0
for _, row in ipairs(F.ahRows) do
    marked = marked + #(row.fakeChildren or {}) - #row.cells
end
expect(marked == 0, "nothing of the addon's on the auction house's rows: " .. marked)
-- A recipe listed again is noted again, at its place's later date.
local function ahSighting()
    for _, s in ipairs(ns.db.sightings[ns.RECIPE_ITEMS[728]] or {}) do
        if s.k == "ah" then
            return s
        end
    end
end
-- Its date put back a minute, rather than the clock moved on: the loot below counts on the last sound being recent.
local before = ahSighting() and ahSighting().t - 60
if before then
    ahSighting().t = before
end
F.ahResults = { { itemKey = { itemID = 728 } } }
F.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
F.RunTimers()
expect(before and ahSighting().t > before, "the recipes listed again are noted again")
expect(ahButton:IsShown(), "the button still there, with no option to take it away")
F.Fire("AUCTION_HOUSE_CLOSED")
AuctionHouseFrame:Hide()
expect(#F.chat == 2 and chatHas(L.AT_AH), "a line for each of the auction house's pages that noted something: " .. #F.chat)
expect(heard() == "", "and no sound more when it closes")

-- ---------- Loot ----------
F.chat = {}
local kobold = "Creature-0-1-0-1-1234-0002"
F.unitGUIDs.target, F.unitNames.target = kobold, "Kobold"
F.loot = { { "|Hitem:16110::|h[Recette]|h", kobold } }
F.Fire("LOOT_READY")
F.RunTimers()
expect(heard() == "", "a recipe looted less than the quiet gap after the last sound: none")
-- The sound is its own option: with the chat line off, it still plays.
ns.db.options.chat = false
F.Advance(3)
F.loot = { { "|Hitem:2697::|h[Recette]|h", kobold } }
F.Fire("LOOT_READY")
F.RunTimers()
expect(heard() == QUILL and #F.chat == 1, "the chat line off: no line, the sound still")
ns.db.options.chat = true
local drop = ns.db.sightings[15933] and ns.db.sightings[15933][1]
expect(drop and drop.k == "drop" and drop.npc == 1234, "the looted recipe noted with its mob")
expect(ns.DB.Name(ns.db, "npc", 1234) == "Kobold", "the mob's name kept")
expect(#F.chat == 1 and chatHas(string.format(L.AT_LOOT, "Kobold", "Darnassus")), "one line, the mob and the place")

-- ---------- A quest reward ----------
F.questID, F.questTitle = 99, "Une quête"
F.questRewards = { "|Hitem:21099::|h" }
F.Fire("QUEST_DETAIL")
F.RunTimers()
expect(ns.db.sightings[25704] and ns.db.sightings[25704][1].q == 99, "the quest's recipe noted")

-- ---------- Bags ----------
F.bags[0] = { 2889, 2406, false, 2697 }
F.itemTooltips[2889] = { "Déjà connu" }
-- The looted recipe, known already, its item's data not loaded yet: read once it has.
F.itemTooltips[2697] = { "Déjà connu" }
F.itemUnloaded[2697] = true
F.Fire("BAG_UPDATE_DELAYED")
F.RunTimers()
expect(c.known[2542] == nil, "a recipe item whose tooltip hasn't loaded: nothing read from it yet")
F.itemUnloaded[2697] = nil
F.Fire("BAG_UPDATE_DELAYED")
F.RunTimers()
expect(c.known[2542] == true, "read once it has: « Déjà connu »")
expect(c.bags[2889] == 1 and c.bags[2406] == 1, "recipe items in the bags counted")
expect(ns.db.sightings[2158] and ns.db.sightings[2158][1].k == "bags", "a recipe arrived in the bags noted")
local b1 = F.BagButton(0, 1)
F.BagButton(0, 2)
ContainerFrame1:Show()
ContainerFrame1:UpdateItems()
local bo = b1.fakeChildren and b1.fakeChildren[1]
expect(bo and bo.check:IsShown(), "the known recipe's check in the bag")
expect(bo and not bo.mine:IsShown(), "no « you hold it » in your own bags")
-- The bank, while it's open.
-- Forever's tab bank: this character's first tab is bag 6 (Enum.BagIndex.CharacterBankTab_1); -1 is the keyring and
-- 15 the account's first tab, neither counted.
F.bags[Enum.BagIndex.CharacterBankTab_1] = { 2598 }
F.bags[Enum.BagIndex.Keyring] = { 2406 }
F.bags[Enum.BagIndex.AccountBankTab_1] = { 728 }
F.Fire("BANKFRAME_OPENED")
F.RunTimers()
expect(c.bank[2598] == 1, "the bank's tab counted while open")
expect(c.bank[2406] == nil and c.bags[2406] == 1 and c.bank[728] == nil, "neither the keyring nor the account's tab")
F.Fire("BANKFRAME_CLOSED")
F.bags[Enum.BagIndex.Keyring], F.bags[Enum.BagIndex.AccountBankTab_1] = nil, nil

-- ---------- The professions window ----------
F.openProfession = 185
F.windowRecipes = { 2795, 2541 }
ProfessionsFrame:Show()
F.Fire("TRADE_SKILL_SHOW")
F.RunTimers()
expect(c.known[2541] == true, "the window's learned recipes")
-- A profession the game lists under a number and a name the addon doesn't know: none is taken as given up, so the
-- cooking it may be keeps its recipes.
local cooking = F.professions[2]
F.professions[2] = { "Cuisine ?", 133971, 56, 75, 99999 }
F.Fire("SKILL_LINES_CHANGED")
F.RunTimers()
expect(c.profs[185] == 56 and c.known[2541] == true, "a misread profession forgets nothing")
F.professions[2] = cooking
F.Fire("SKILL_LINES_CHANGED")
F.RunTimers()
ns.Game.unknownSkillLines[99999] = nil -- made on purpose: not for the API check
-- No profession listed at all while the character has some may be the game not ready: nothing is given up then, and
-- the list is read again later. Back by then, nothing has changed; still empty, it's believed.
local slots, knownBefore = F.profSlots, ns.DeepCopy(c.known)
F.profSlots = {}
F.Fire("SKILL_LINES_CHANGED")
F.RunFrame()
expect(c.profs[185] == 56 and c.known[2541] == true, "an empty list of professions forgets nothing at once")
F.profSlots = slots
F.RunTimers()
expect(c.profs[185] == 56 and c.profs[333] == 18 and c.known[2541] == true, "read again with the list back, nothing has changed")
F.profSlots = {}
F.Fire("SKILL_LINES_CHANGED")
F.RunTimers()
expect(next(c.profs) == nil and c.known[2541] == nil, "still empty when read again, the professions are given up")
F.profSlots = slots
F.Fire("SKILL_LINES_CHANGED")
F.RunTimers()
expect(c.profs[185] == 56 and c.profs[333] == 18, "and taken up again, they're back")
for spell, v in pairs(knownBefore) do
    c.known[spell] = v
end
ns.book:Invalidate()
local line = ProfessionsFrame.CraftingPage.RankBar
local countLine
for _, frame in ipairs(F.frames) do
    if frame.text and frame.skill == 185 and frame:IsShown() then
        countLine = frame
    end
end
expect(countLine ~= nil, "« Carnet : … » under the rank bar")
expect(countLine and countLine.text:GetText():find(L.CARNET_PREFIX, 1, true), "its text: " .. tostring(countLine and countLine.text:GetText()))
if countLine then
    countLine:GetScript("OnEnter")(countLine)
    expect(tooltipHas(L.CLICK_OPEN), "its tooltip")
    countLine:GetScript("OnClick")(countLine)
    expect(ns.Notebook.IsShown(), "a click opens the notebook")
    ns.Notebook.Close()
end
expect(line ~= nil, "the rank bar")
ns.db.options.a1 = false
ns.CountLines.Refresh()
expect(countLine and not countLine:IsShown(), "the option hides the line")
ns.db.options.a1 = true
ns.CountLines.Refresh()
expect(countLine and countLine:IsShown(), "and shows it again")
-- « Suivre »: on, the notebook opens docked; the window's close takes it along.
ns.Follow.Set(true)
F.RunTimers()
expect(ns.Notebook.IsShown() and ns.Follow.IsDocked(), "docked on the professions window")
ns.Notebook.Close()
expect(not ns.Follow.IsDocked(), "closed by hand: let go")
F.Fire("TRADE_SKILL_LIST_UPDATE")
F.RunTimers()
expect(not ns.Notebook.IsShown(), "and it stays closed while the window is open")
ProfessionsFrame:Hide()
F.Fire("TRADE_SKILL_CLOSE")
F.RunTimers()
ProfessionsFrame:Show()
F.Fire("TRADE_SKILL_SHOW")
F.RunTimers()
expect(ns.Notebook.IsShown() and ns.Follow.IsDocked(), "the next opening docks it again")
ProfessionsFrame:Hide()
F.Fire("TRADE_SKILL_CLOSE")
F.RunTimers()
expect(not ns.Notebook.IsShown(), "closes with the window")
ns.Follow.Set(false)
F.openProfession = nil
-- The window shown before it knows its profession answers profession 0, the game's "none": nothing for the API check
-- to note (the assumptions are tried further down).
F.Fire("TRADE_SKILL_SHOW")
F.RunTimers()

-- ---------- The professions book ----------
local content = ProfessionsBookFrame.ProfessionsContentFrame
content.PrimaryProfession1.skillLine = 333
content.SecondaryProfession1.skillLine = 185
ProfessionsBookFrame:Show()
F.RunTimers()
local bookLines = 0
for _, frame in ipairs(F.frames) do
    if frame.text and frame:IsShown() and (frame.skill == 333 or frame.skill == 185 or frame.others) then
        bookLines = bookLines + 1
    end
end
expect(bookLines >= 3, "a line per profession in the book, and one for the others: " .. bookLines)
ProfessionsBookFrame:Hide()

-- ---------- The notebook ----------
slash("")
expect(ns.Notebook.IsShown(), "/kr opens the notebook")
local nb = ns.Notebook.Frame()
expect(#nb.rows.used > 0, "rows drawn")
local first = nb.rows.used[1]
local clicked = first.spell
first:GetScript("OnClick")(first, "LeftButton")
expect(clicked ~= nil and ns.Notebook.View().selected == clicked, "a click selects")
expect(nb.detail:IsShown(), "the detail below the list")
first:GetScript("OnEnter")(first)
expect(#F.tooltip.lines > 0, "the row's tooltip")
first:GetScript("OnClick")(first, "RightButton")
expect(F.MenuItem(L.PLACE_WAYPOINT) ~= nil and F.MenuItem(L.LINK_CHAT) ~= nil, "the row's menu")
F.MenuItem(L.LINK_CHAT).choose()
expect(F.inserted ~= nil, "linked in the chat")
local sel = ns.Notebook.View().selected
for _, r in ipairs(nb.rows.used) do
    if r.spell == sel then
        r:GetScript("OnClick")(r, "LeftButton")
        break
    end
end
expect(ns.Notebook.View().selected == nil, "a second click on the same recipe closes the detail")
expect(not nb.detail:IsShown(), "and the detail goes")
-- Every profession tab, both styles, the smallest and largest sizes.
for _, tab in ipairs(nb.tabs.used) do
    run(tab:GetScript("OnClick"), tab)
end
for _, style in ipairs({ "book", "clean" }) do
    ns.db.options.style = style
    for _, size in ipairs({ { 460, 600 }, { 900, 1080 } }) do
        ns.db.options.width, ns.db.options.height = size[1], size[2]
        run(ns.Notebook.Refresh)
    end
end
ns.db.options.width, ns.db.options.height = 560, 820
-- The corner grip: the notebook follows as it's dragged, within the ranges, and keeps the size in the options.
do
    ns.Notebook.Show(185)
    local grip = nb.grip
    expect(grip and grip:GetFrameLevel() >= 500, "a corner grip, above the window's border")
    if grip then
        local function drag(w, h)
            nb:SetSize(w, h)
            F.RunScript(nb, "OnSizeChanged", w, h)
            F.RunTimers()
        end
        ns.Options.Open()
        F.RunScript(grip, "OnMouseDown")
        drag(700.4, 900.6)
        expect(ns.db.options.width == 700.4 and math.abs(nb.content:GetWidth() - (700.4 - 62)) < 0.01,
            "dragged: the list laid out at the new width")
        drag(2000, 300)
        expect(nb:GetWidth() == 900 and nb:GetHeight() == 600, "held within the ranges: " .. nb:GetWidth() .. " by " .. nb:GetHeight())
        drag(700.4, 900.6)
        F.RunScript(grip, "OnMouseUp")
        expect(ns.db.options.width == 700 and ns.db.options.height == 901, "let go: kept in whole units: "
            .. ns.db.options.width .. " by " .. ns.db.options.height)
        expect(windowRow("width") and windowRow("width"):IsShown() and windowRow("width").Slider:GetValue() == 700,
            "and the options window's slider, open beside it, says so")
        ns.Options.Close()
        -- Docked, it goes back on the professions window.
        ProfessionsFrame:Show()
        ns.Notebook.Dock(ProfessionsFrame, 48)
        F.RunScript(grip, "OnMouseDown")
        nb:ClearAllPoints()
        nb:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 10, 10)
        drag(600, 820)
        F.RunScript(grip, "OnMouseUp")
        local _, rel = nb:GetPoint()
        expect(rel == ProfessionsFrame, "docked: back on the professions window")
        ns.Notebook.Dock(nil)
        ProfessionsFrame:Hide()
    end
    ns.db.options.width, ns.db.options.height = 560, 820
end
-- Each profession its art in both styles (Ikar, 2026-11-10): Book's quest page, Clean's card, each an atlas this
-- build has.
do
    local W, known = ns.Widgets, {}
    for _, name in ipairs(ns.NEEDS.atlases) do
        known[name] = true
    end
    for skill in pairs(ns.PROFESSION_ICONS) do
        expect(known[W.QUEST_BG[skill]], "Book's page for profession " .. skill .. ": " .. tostring(W.QUEST_BG[skill]))
        expect(known[W.CARD[skill]], "Clean's card for profession " .. skill .. ": " .. tostring(W.CARD[skill]))
    end
    -- Clean: the card in the inset, cropped from the top and the left, so the profession drawn bottom right stays.
    local coords
    function nb.card:SetTexCoord(...)
        coords = { ... }
    end
    F.missingAtlases = {}
    ns.db.options.style = "clean"
    ns.Notebook.Show(185)
    expect(nb.card:IsShown() and coords and coords[2] == 1 and coords[4] == 1 and (coords[1] > 0 or coords[3] > 0),
        "Clean's card, its bottom right kept: " .. table.concat(coords or {}, ", "))
    F.missingAtlases[W.CARD[185]] = true
    ns.Notebook.Refresh()
    expect(not nb.card:IsShown(), "a card the build lacks: none, the inset as it is")
    F.missingAtlases = {}
    ns.db.options.style = nil
end
ns.Notebook.Show(185)
-- Sections fold and unfold.
local section = nb.sections.used[1]
section:GetScript("OnClick")(section)
expect(ns.db.ui.open[section.key] == false, "a section folds")
section:GetScript("OnClick")(section)
-- The search and the filter.
nb.search:SetText("zzz")
F.RunScript(nb.search, "OnTextChanged")
F.RunTimers()
expect(nb.empty:IsShown(), "nothing matches")
nb.search:SetText("")
F.RunScript(nb.search, "OnTextChanged")
F.RunTimers()
-- A sighting's line longer than the detail's room: cut with the ellipsis, whole on hover.
local longName = string.rep("Ellandrieth ", 8)
ns.DB.SetName(ns.db, "npc", 4223, longName)
ns.db.options.width = 460
ns.Notebook.Select(2795)
local cutChip
for _, chip in ipairs(nb.detail.chips.used) do
    if (chip.text:GetText() or ""):find(longName, 1, true) then
        cutChip = chip
    end
end
expect(cutChip and cutChip.text:GetWidth() > 0 and cutChip.text:GetWidth() < cutChip.text:GetStringWidth(), "a line too long for the detail is cut")
if cutChip then
    F.tooltip = { lines = {} }
    cutChip:GetScript("OnEnter")(cutChip)
    expect(tooltipHas(longName), "and whole on hover")
end
ns.DB.SetName(ns.db, "npc", 4223, "Ellandrieth")
ns.db.options.width = 560
-- The detail of a recipe with reagents and a vendor's spot.
ns.Notebook.Select(2795)
expect(nb.detail:IsShown() and #nb.detail.chips.used >= 3, "reagents and sightings in the detail")
local pinned
for _, chip in ipairs(nb.detail.chips.used) do
    if chip.pin:IsShown() then
        pinned = chip
    end
end
expect(pinned ~= nil, "a pin on a sighting with a spot")
local priced = false
for _, chip in ipairs(nb.detail.chips.used) do
    priced = priced or (chip.text:GetText() or ""):find(GetMoneyString(1250), 1, true) ~= nil
end
expect(priced, "the vendor's price beside it")
if pinned then
    pinned.pin:GetScript("OnClick")(pinned.pin)
    expect(F.waypoint and F.waypoint.uiMapID == 1457, "the pin places the game's waypoint")
end
F.openedSkill, F.combat = nil, true
local errorsBefore = #F.uiErrors
nb.head.hammer:GetScript("OnClick")()
F.combat = false
expect(F.openedSkill == nil and #F.uiErrors == errorsBefore + 1, "in a fight the hammer opens nothing, and says why")
nb.head.hammer:GetScript("OnClick")()
expect(F.openedSkill == 185, "the hammer opens the professions window on the profession")
-- The shared fake doesn't keep a texture's desaturation: this one records it.
local followTex = nb.head.follow.tex
function followTex:SetDesaturated(on)
    self.desaturated = on
end
nb.head.follow:GetScript("OnClick")()
expect(ns.db.options.follow == true, "the follow button turns « Suivre » on")
-- On, the normal art in colour: the pressed art, its arrow a pixel off, only while the mouse holds it down.
expect(followTex.atlas == ns.Widgets.ATLAS.follow and not followTex.desaturated, "« Suivre » on: the normal art, in colour")
nb.head.follow:GetScript("OnMouseDown")(nb.head.follow)
expect(followTex.atlas == ns.Widgets.ATLAS.followDown, "held down: the pressed art")
nb.head.follow:GetScript("OnMouseUp")(nb.head.follow)
expect(followTex.atlas == ns.Widgets.ATLAS.follow, "let go: the normal art again")
nb.head.follow:GetScript("OnClick")()
expect(followTex.atlas == ns.Widgets.ATLAS.follow and followTex.desaturated, "« Suivre » off: the normal art, gray")
-- A recipe with no rank anywhere yet (a trainer's, met before the addon): the detail says where to read it.
local steakReq = ns.db.reqs[2541]
ns.db.reqs[2541] = nil
ns.book:Invalidate()
ns.Notebook.Select(2541)
local hint = false
for _, chip in ipairs(nb.detail.chips.used) do
    hint = hint or (chip.text:GetText() or ""):find(USED, 1, true) ~= nil
end
expect(hint, "no rank yet: the detail names the trainer filter's « Déjà connu »")
ns.db.reqs[2541] = steakReq
ns.book:Invalidate()
-- The gear, top right, drawn over the window's border as its close button is: straight to the options, no menu (Ikar,
-- 2026-11-13: "Pas besoin de option et signaler un bug, ca peux directement ouvrir les option").
expect(nb.gear:GetFrameLevel() > nb.NineSlice:GetFrameLevel(), "the gear above the window's border, not under it")
do
    local uiWidth, uiHeight, left, top = UIParent.width, UIParent.height, nb.left, nb.top
    UIParent.width, UIParent.height = 1920, 1080
    nb.left, nb.top = 100, 900
    F.settingsOpened, F.lastMenu = nil, nil
    nb.gear:GetScript("OnClick")(nb.gear)
    expect(ns.Options.IsShown() and F.lastMenu == nil and ns.Notebook.IsShown() and F.settingsOpened == nil,
        "the gear opens the options window, no menu, and the notebook stays open")
    local point, rel, relPoint, x, y = KaLiRecipeOptions:GetPoint()
    expect(point == "TOPLEFT" and rel == UIParent and relPoint == "BOTTOMLEFT" and x == 100 + nb:GetWidth() + 10 and y == 900,
        "beside the notebook, on its right: " .. tostring(point) .. " " .. tostring(x) .. " " .. tostring(y))
    nb.gear:GetScript("OnClick")(nb.gear)
    expect(not ns.Options.IsShown(), "a second click closes it")
    nb.left = 1920 - nb:GetWidth() - 5
    nb.gear:GetScript("OnClick")(nb.gear)
    point, rel, relPoint, x, y = KaLiRecipeOptions:GetPoint()
    expect(point == "TOPRIGHT" and x == nb.left - 10 and y == 900, "or on its left when the screen runs out: " .. tostring(point))
    ns.Options.Close()
    UIParent.width, nb.left = 1200, 300
    nb.gear:GetScript("OnClick")(nb.gear)
    point, rel, relPoint = KaLiRecipeOptions:GetPoint()
    expect(point == "CENTER" and rel == UIParent and relPoint == "CENTER", "and in the middle of the screen when neither side has room: "
        .. tostring(point))
    ns.Options.Close()
    UIParent.width, UIParent.height, nb.left, nb.top = uiWidth, uiHeight, left, top
end
-- The bug report, from the options' last section.
ns.Options.Open()
local reportRow
for _, f in ipairs(KaLiRecipeOptions.rows) do
    if f.row.kind == "button" and f.row.name == L.REPORT_TITLE then
        reportRow = f
    end
end
if reportRow then
    F.RunScript(reportRow.Button, "OnClick")
end
local reportWindow = ns.Report.Frame()
expect(reportRow and reportWindow and reportWindow:IsShown()
    and reportWindow.URL:GetText():find("^https://github.com/Ikar%-Rahl/Warcraft%-KaLi/issues/new%?title=KaLi%%20Recipe"),
    "the options' « Signaler un bug » opens the report's window, with the link")
ns.Options.Close()
if reportWindow then
    reportWindow:Hide()
end
F.tooltip = { lines = {} }
nb.gear:GetScript("OnEnter")(nb.gear)
expect(tooltipHas(L.OPEN_OPTIONS), "and says so")
slash("")
expect(not ns.Notebook.IsShown(), "/kr closes it")

-- ---------- Tooltips ----------
GameTooltip:SetOwner(UIParent)
GameTooltip:SetItemByID(728)
expect(tooltipHas(L.UNKNOWN_TO_ALL), "a recipe's tooltip says who knows it")
expect(tooltipHas(string.format(L.WHERE_VENDOR, "Ellandrieth", "Darnassus")) and not tooltipHas(ns.Text.CLOCK_MARKUP),
    "and where, with no clock for a vendor without limit")
GameTooltip:SetOwner(UIParent)
GameTooltip:SetItemByID(2889)
expect(tooltipHas(string.format(L.WHERE_VENDOR, "Ellandrieth " .. ns.Text.CLOCK_MARKUP, "Darnassus")),
    "and the grey clock after the name of a vendor whose stock was limited")
GameTooltip:SetOwner(UIParent)
GameTooltip:SetItemByID(2886)
expect(tooltipHas(L.USED_IN), "a reagent's « Utilisé dans »")
GameTooltip:SetOwner(UIParent)
GameTooltip:SetItemByID(2888)
expect(tooltipHas(L.MADE_BY), "a crafted item's « Fabriqué par »")
GameTooltip:SetOwner(UIParent)
GameTooltip:SetSpellByID(2541)
expect(tooltipHas(L.CARNET), "a trainer's recipe, by its spell")
ShoppingTooltip1 = CreateFrame("GameTooltip", "ShoppingTooltip1")
F.tooltip = { lines = {} }
for _, fn in ipairs(F.postCalls[0]) do
    fn(ShoppingTooltip1, { type = 0, id = 728, lines = {} })
end
expect(#F.tooltip.lines == 0, "no lines on the comparison tooltips")
expect(KaLiRecipeDevDB.reagentColor ~= nil, "the game's « Composant d'artisanat » colour read")

-- ---------- The map ----------
WorldMapFrame:Show()
run(ns.MapPins.Refresh)
expect(#F.pins >= 1, "pins where unknown recipes were seen: " .. #F.pins)
local pin = F.pins[1]
if pin then
    expect(pin.startScale == 1 and pin.endScale == 1.2, "the pin keeps its size at any zoom")
    F.tooltip = { lines = {} }
    F.RunScript(pin, "OnEnter")
    expect(tooltipHas(L.PLACE_WAYPOINT), "hovering a pin: its recipes, through the map's own OnEnter")
    F.waypoint = nil
    F.RunScript(pin, "OnMouseUp", "LeftButton")
    expect(F.waypoint and F.waypoint.uiMapID == 1457, "a click on a pin places the waypoint")
end
ns.db.options.pins = false
ns.MapPins.Refresh()
expect(#F.pins == 0, "none when off")
ns.db.options.pins = true
-- The map refreshes every provider in one loop: an error in the addon's stays there, kept like any other.
local book = ns.book
ns.book = setmetatable({}, { __index = function()
    error("broken on purpose")
end })
local contained = pcall(WorldMapFrame.provider.RefreshAllData, WorldMapFrame.provider)
ns.book = book
expect(contained, "an error in the pins doesn't reach the map's loop")
local keptIt = false
for msg in pairs(KaLiRecipeDevDB.errors) do
    if tostring(msg):find("broken on purpose", 1, true) then
        keptIt = true
        KaLiRecipeDevDB.errors[msg] = nil
    end
end
expect(keptIt, "and is kept for the report")
for i = #F.errors, 1, -1 do
    if tostring(F.errors[i]):find("broken on purpose", 1, true) then
        table.remove(F.errors, i)
    end
end
WorldMapFrame:Hide()

-- ---------- Options and the compartment ----------
-- In a window of their own beside the notebook (Ikar, 2026-11-13), as KaLi Quest's dialog in Edit Mode.
ns.Options.Open()
local window = KaLiRecipeOptions
-- What each row shows on opening, defaults read through.
local held = {}
for _, row in ipairs(options:Rows()) do
    held[row.key] = ns.db.options[row.key]
end
local function shownKeys()
    local list = {}
    for _, f in ipairs(window.rows) do
        if f:IsShown() then
            list[#list + 1] = f.row.key or f.row.text
        end
    end
    return table.concat(list, ",")
end
expect(window and window:IsShown() and window.Title:GetText() == ns.TITLE and #window.sections == 7
    and window.sections[4].Text:GetText() == L.OPT_NOTEBOOK and shownKeys() == "style,follow,width,height,nbOwned,nbAlt",
    "the options window: the addon's name, seven sections, the notebook's open first: " .. shownKeys())
-- In the notebook's « Épuré » look, whatever the notebook's style (Ikar, 2026-11-13): a game window, the notebook's own
-- section headers, a − on the open one.
expect(window.template == "ButtonFrameTemplate" and window.sections[4].Sign:GetText() == "–" and window.sections[1].Sign:GetText() == "+"
    and window.sections[4].Line ~= nil, "a game window, as the notebook « Épuré », with the notebook's section headers")
F.RunScript(window.sections[4], "OnClick")
expect(shownKeys() == "" and window.sections[4].Sign:GetText() == "+", "a click on the open header closes it")
F.RunScript(window.sections[4], "OnClick")
local special = false
for _, name in ipairs(UISpecialFrames) do
    special = special or name == "KaLiRecipeOptions"
end
expect(special, "Escape closes it, as it closes the game's windows")
F.RunScript(window.sections[1], "OnClick")
expect(windowRow("chat"):IsShown() and not windowRow("width"):IsShown(), "a section's bar opens it, and closes the one open")
local chat = windowRow("chat")
chat.Button:SetChecked(false)
F.RunScript(chat.Button, "OnClick")
expect(ns.db.options.chat == false and window.Revert:IsEnabled(), "a check box writes the option, and « Annuler les modifications » lights")
F.RunScript(window.Revert, "OnClick")
expect(ns.db.options.chat == held.chat and not window.Revert:IsEnabled(), "which puts it back as it was when the window opened")
local w = options:Range(optionRow("width"))
expect(w and w[1] == 460 and w[2] == 900, "the width slider's range")
F.RunScript(window.sections[4], "OnClick")
ns.Notebook.Show(185)
windowRow("width").Slider:SetValue(600)
F.RunTimers()
expect(ns.db.options.width == 600 and nb:GetWidth() == 600, "the width slider sizes the notebook, open beside it")
F.RunScript(window.Revert, "OnClick")
F.RunTimers()
expect(ns.db.options.width == held.width, "and back")
ns.Notebook.Close()
-- The sounds: picking one plays it; « Aucun » plays nothing and the visits stay quiet.
F.RunScript(window.sections[1], "OnClick")
expect(optionRow(ns.Sounds.OPTION.recipe) and optionRow(ns.Sounds.OPTION.place), "the two sound lists")
heard()
local radios = F.MenuRadios(windowRow(ns.Sounds.OPTION.recipe).Dropdown)
for _, r in ipairs(radios) do
    if r.text == L.SOUND_parchment then
        r.pick()
    end
end
expect(heard() == PARCHMENT, "picking a sound plays it")
setOption(ns.Sounds.OPTION.place, "note")
F.RunTimers()
expect(heard() == STROKE, "picking a short one plays it short, stopped by its timer")
setOption(ns.Sounds.OPTION.recipe, "none")
expect(heard() == "" and not ns.Sounds.Play("recipe"), "« Aucun »: nothing")
-- « Annuler les modifications » puts them back without playing them.
F.RunScript(window.Revert, "OnClick")
expect(ns.db.options[ns.Sounds.OPTION.recipe] == held[ns.Sounds.OPTION.recipe], "« Annuler les modifications » restores the sound")
expect(heard() == "", "quietly")
-- Under each sound list, « Écouter » plays the chosen sound again.
local plays = {}
for _, f in ipairs(window.rows) do
    if f.row.kind == "button" and f.row.text == L.SOUND_PLAY then
        plays[#plays + 1] = f
    end
end
local function play(i)
    F.RunScript(plays[i].Button, "OnClick")
    F.RunTimers()
end
expect(#plays == 2 and plays[1]:IsShown(), "an « Écouter » row under each sound list: " .. #plays)
if #plays == 2 then
    play(1)
    expect(heard() == QUILL, "the first plays the new recipe's quill")
    play(2)
    expect(heard() == STROKE, "the second the new place's stroke, whatever the quiet gap")
end
-- « Volume des sons » (Ikar, 2026-11-12): a share of each kit's own volume, asked of the game; at 100 % nothing asked.
-- 200 % by default (2026-11-13), so the visits above played at it.
local volume = optionRow(ns.Sounds.VOLUME)
local vo = volume and options:Range(volume)
expect(vo and vo[1] == 0 and vo[2] == 300 and volume.step == 10, "the volume slider, 0 to 300 in steps of 10")
expect(volume and volume.format and volume.format(35) == "35%", "shown as a percentage, as the game's own: "
    .. tostring(volume and volume.format and volume.format(35)))
if volume and #plays == 2 then
    windowRow(ns.Sounds.VOLUME).Slider:SetValue(50)
    expect(ns.db.options[ns.Sounds.VOLUME] == 50 and heard() == "", "dragging it plays nothing")
    play(1)
    expect(heard() == "3093@0.15", "at 50 %, half the quill's own 0.3, on the effects' channel")
    play(2)
    expect(heard() == "3093@0.15/200", "the stroke too, still stopped early")
    setOption(ns.Sounds.VOLUME, 0)
    play(1)
    expect(heard() == "" and not ns.Sounds.Play("recipe", true), "at 0 %: nothing, not even asked")
    setOption(ns.Sounds.VOLUME, 50)
    local setVolume = C_Sound.PlaySoundWithOptions
    C_Sound.PlaySoundWithOptions = nil
    play(1)
    expect(heard() == "3093", "a game without a volume per sound: the game's own level")
    C_Sound.PlaySoundWithOptions = setVolume
    setOption(ns.Sounds.VOLUME, 100)
    play(1)
    expect(heard() == "3093", "at 100 %: no volume asked, the game's own level")
    setOption(ns.Sounds.VOLUME, 300)
    play(1)
    expect(heard() == "3093@0.9", "at 300 %: the quill at 0.9 of full")
    setOption(ns.Sounds.OPTION.recipe, "parchment")
    heard()
    play(1)
    expect(heard() == "1209@1", "the parchment, whose own is 0.5: no more than full")
    F.RunScript(window.Revert, "OnClick")
    expect(ns.db.options[ns.Sounds.VOLUME] == 200 and ns.db.options[ns.Sounds.OPTION.recipe] == ns.Sounds.DEFAULTS.recipe
        and heard() == "", "« Annuler les modifications » puts it back to 200 %, quietly")
    play(1)
    expect(heard() == QUILL, "and the quill at twice its own")
end
-- « Par défaut »: every option back to its default, quietly, which « Annuler les modifications » gives back.
setOption("chat", false)
setOption("usedInMax", 3)
heard()
F.RunScript(window.Defaults, "OnClick")
F.RunTimers()
local off = {}
for _, row in ipairs(options:Rows()) do
    if ns.db.options[row.key] ~= ns.DB.DEFAULTS[row.key] then
        off[#off + 1] = row.key
    end
end
expect(#off == 0 and heard() == "", "« Par défaut » puts every option back to its default, quietly: " .. table.concat(off, ", "))
F.RunScript(window.Revert, "OnClick")
F.RunTimers()
expect(ns.db.options.chat == held.chat and ns.db.options.usedInMax == held.usedInMax and ns.db.options.width == held.width,
    "« Annuler les modifications » gives back what the window opened on")
-- « Suivre » ticked there docks the notebook on the professions window, and unticked lets it go.
do
    ProfessionsFrame:Show()
    ns.Notebook.Show(185)
    local follow = windowRow("follow")
    follow.Button:SetChecked(true)
    F.RunScript(follow.Button, "OnClick")
    expect(ns.db.options.follow == true and ns.Follow.IsDocked(), "« Suivre » ticked in the window docks the notebook")
    follow.Button:SetChecked(false)
    F.RunScript(follow.Button, "OnClick")
    expect(ns.db.options.follow == false and not ns.Follow.IsDocked(), "and unticked lets it go")
    ns.Notebook.Close()
    ProfessionsFrame:Hide()
end
-- The notebook's own « Suivre » shows in the window.
F.RunScript(window.sections[4], "OnClick")
local followed = ns.db.options.follow
nb.head.follow:GetScript("OnClick")(nb.head.follow)
expect(ns.db.options.follow == not followed and windowRow("follow").Button:GetChecked() == not followed,
    "the notebook's « Suivre » ticks the window's box")
nb.head.follow:GetScript("OnClick")(nb.head.follow)
-- The trainer's price has its own option; the vendor's stays.
setOption("priceTrainer", false)
expect(steak and ns.Text.Price(steak) == nil, "the trainer's price hidden by its option")
expect(ns.Text.Price({ k = "vendor", cost = 1250 }) ~= nil, "the vendor's still shown")
defaultOption("priceTrainer")
expect(steak and ns.Text.Price(steak) ~= nil, "and back")
-- The page under AddOns: no setting, a button to the window, as FlareUI's page is to its own, and the bug report's.
local pageOpen
for _, init in ipairs(F.settingsLayout.initializers) do
    if init.name == L.OPTIONS and init.buttonText == L.OPTIONS_OPEN then
        pageOpen = init
    end
end
expect(pageOpen and pageOpen.tooltip == L.OPTIONS_OPEN_TIP and next(F.settingsCategory.settings) == nil,
    "the page under AddOns holds no setting, and a button to the window")
if pageOpen then
    ns.Options.Close()
    Settings.OpenToCategory(F.settingsCategory:GetID())
    pageOpen.buttonClick()
    expect(not SettingsPanel:IsShown() and SettingsPanel.skippedTransition and ns.Options.IsShown(),
        "which closes the game's options, without their game menu, and opens it")
    ns.Options.Close()
    Settings.OpenToCategory(F.settingsCategory:GetID())
    F.unapplied = true
    pageOpen.buttonClick()
    expect(SettingsPanel:IsShown() and F.popup and F.popup.which == "GAME_SETTINGS_CONFIRM_DISCARD" and not ns.Options.IsShown(),
        "with a change waiting for « Appliquer », the game asks first and the window waits")
    F.unapplied, F.popup = nil, nil
    SettingsPanel:Hide()
end
ns.Options.Close()
run(KaLiRecipe_OnAddonCompartmentEnter, "KaLiRecipe", UIParent)
expect(tooltipHas(L.COMPARTMENT_CLICK), "the compartment's tooltip")
run(KaLiRecipe_OnAddonCompartmentClick, "KaLiRecipe", "LeftButton")
expect(ns.Notebook.IsShown(), "the compartment opens the notebook")
run(KaLiRecipe_OnAddonCompartmentClick, "KaLiRecipe", "RightButton")
expect(ns.Options.IsShown(), "a right click opens the options")
ns.Options.Close()
ns.Notebook.Close()

-- ---------- The minimap button and the information bars ----------
local mb = KaLiRecipeMinimapButton
expect(mb and mb:IsShown() and mb:GetParent() == Minimap, "the minimap button, on the minimap, shown by default")
local launcher = F.ldb.objects[ns.TITLE]
expect(launcher and launcher.type == "launcher" and launcher.label == ns.TITLE and launcher.icon, "a launcher for the bars (Titan Panel)")
if mb then
    run(mb:GetScript("OnClick"), mb, "LeftButton")
    expect(ns.Notebook.IsShown(), "the button opens the notebook")
    run(mb:GetScript("OnClick"), mb, "LeftButton")
    expect(not ns.Notebook.IsShown(), "and closes it")
    run(mb:GetScript("OnClick"), mb, "RightButton")
    expect(ns.Options.IsShown(), "a right click: the options")
    ns.Options.Close()
    run(mb:GetScript("OnEnter"), mb)
    expect(tooltipHas(L.COMPARTMENT_CLICK) and tooltipHas(L.DRAG_MOVE), "its tooltip, with the drag hint")
    run(mb:GetScript("OnLeave"), mb)
    run(mb:GetScript("OnDragStart"), mb)
    expect(mb.dragging, "a drag starts")
    run(ns.MinimapButton.DragTo, 90)
    run(mb:GetScript("OnDragStop"), mb)
    local _, rel, _, x, y = mb:GetPoint()
    expect(ns.db.ui.minimap == 90 and rel == Minimap and math.abs(x) < 0.001 and math.abs(y - 104) < 0.001,
        "dragged to the top, on the edge: " .. tostring(x) .. ", " .. tostring(y))
    setOption("minimapLock", true)
    run(mb:GetScript("OnDragStart"), mb)
    expect(not mb.dragging, "locked: a drag doesn't move it")
    run(mb:GetScript("OnEnter"), mb)
    expect(not tooltipHas(L.DRAG_MOVE), "and its tooltip doesn't offer it")
    defaultOption("minimapLock")
    setOption("minimap", false)
    expect(not mb:IsShown(), "the option hides it")
    defaultOption("minimap")
    expect(mb:IsShown(), "and shows it again, where it was")
end
if launcher then
    run(launcher.OnClick, UIParent, "LeftButton")
    expect(ns.Notebook.IsShown(), "the bar's button opens the notebook")
    ns.Notebook.Close()
    GameTooltip:SetOwner(UIParent)
    run(launcher.OnTooltipShow, GameTooltip)
    expect(tooltipHas(L.COMPARTMENT_CLICK) and tooltipHas(L.RIGHT_CLICK_OPTIONS) and not tooltipHas(L.DRAG_MOVE), "the bar's tooltip")
end

-- ---------- Commands, the report, the API check ----------
for _, command in ipairs({ "help", "options", "status", "data", "seen", "char", "forget", "forget 2543", "forget nothing", "report",
    "debug on", "debug events", "debug chat", "log", "errors", "clear", "debug off", "test", "bogus" }) do
    slash(command)
end
expect(ns.db.sightings[2543] == nil, "/kr forget forgets")
expect(type(ns.db.forgotten[2543]) == "number", "and leaves its mark")
expect(ns.Commands.DataText():find("recipes forgotten 1", 1, true), "/kr data counts it")
local report = ns.Report.Text()
expect(report:find("== api check ==", 1, true) and report:find("== notebook ==", 1, true), "the report's parts")
expect(not report:find("Ikar", 1, true) and not report:find("Ellandrieth", 1, true), "no character or NPC name in the report")
local r = ns.SelfCheck.Run()
expect(r.checked > 0, "the API check looks for things")
expect(#r.missing == 0, "nothing missing on the fake: " .. table.concat(r.missing, ", "))
local notAsAssumed = {}
for _, a in ipairs(r.assumed) do
    for _, w in ipairs(a.wrong) do
        notAsAssumed[#notAsAssumed + 1] = a.name .. ": " .. w
    end
end
expect(r.failing == 0, "every assumption holds on the fake: " .. table.concat(notAsAssumed, "; "))

-- ---------- Saved data refused: the model never made ----------
-- The addon then does nothing: a vendor, a loot, the bags and the professions window raise no error.
local bookKept = ns.book
ns.book = nil
F.Fire("MERCHANT_SHOW")
F.Fire("LOOT_READY")
F.Fire("BAG_UPDATE_DELAYED")
F.Fire("TRADE_SKILL_SHOW")
F.Fire("SKILL_LINES_CHANGED")
F.RunTimers()
F.Fire("MERCHANT_CLOSED")
ns.book = bookKept
expect(next(KaLiRecipeDevDB.errors or {}) == nil, "with no model, the events do nothing: " .. tostring(next(KaLiRecipeDevDB.errors or {})))

-- ---------- The probe ----------
if SlashCmdList.KRPROBE then
    for _, command in ipairs({ "", "window", "spellbook", "tooltip 2889", "trainer", "ah", "bank", "sounds", "volume", "show" }) do
        run(SlashCmdList.KRPROBE, command)
        F.RunTimers()
    end
    expect(type(KaLiRecipeProbeDB) == "table", "the probe keeps its report")
    local probed = KaLiRecipeProbeDB.report and KaLiRecipeProbeDB.report.volume
    expect(probed and tostring(probed.verdict):find("replaces", 1, true),
        "the probe's volume verdict, on the fake's game that replaces a kit's volume: " .. tostring(probed and probed.verdict))
end

-- ---------- Logout: the files as the game writes them ----------
-- The runner reads them back for the next sessions (run_tests.py, restart_problems).
F.Fire("PLAYER_LOGOUT")
local copy = KaLiRecipeCopyDB
expect(type(copy) == "table" and copy.owner == me and copy.writer == ns.VERSION, "this character's file gets its copy")
expect(copy and copy.data ~= ns.db and copy.data.sightings ~= ns.db.sightings, "a copy apart from the notebook")
local inNotebook, inCopy = 0, 0
for _ in pairs(ns.db.sightings) do
    inNotebook = inNotebook + 1
end
for _ in pairs(copy and copy.data.sightings or {}) do
    inCopy = inCopy + 1
end
expect(inNotebook > 0 and inCopy == inNotebook, "the copy holds every recipe: " .. inCopy .. " of " .. inNotebook)
expect(ns.db.meta.writer == ns.VERSION and type(ns.db.meta.written) == "number", "the notebook says who wrote it, and when")
local atDefault = {}
for key, v in pairs(ns.db.options) do
    if v == ns.DB.DEFAULTS[key] then
        atDefault[#atDefault + 1] = key
    end
end
expect(#atDefault == 0, "no option at its default stays in the file: " .. table.concat(atDefault, ", "))

-- ---------- Nothing went wrong on the way ----------
expect(#F.errors == 0, "errors reached the game's handler: " .. tostring(F.errors[1]))
expect(#F.templateErrors == 0, "template errors: " .. tostring(F.templateErrors[1]))
local distinct = 0
for msg in pairs(KaLiRecipeDevDB.errors or {}) do
    distinct = distinct + 1
    failures[#failures + 1] = "error kept: " .. tostring(msg)
end
return failures
