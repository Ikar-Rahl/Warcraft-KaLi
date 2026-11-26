-- Starts KaLi HUD and its probe on the fake game the way the game does, plays a session (the plate taking Ikar's
-- layout, following bars in Edit Mode and static outside it, its reach; the info bar's items and other addons'
-- objects; the status bars) and runs every slash command. Run by hud/tools/run_tests.py after the addons' files are
-- loaded. Returns a list of failures.
-- Its blocks (a line `do` alone, to its `end`) are scopes of their own: a deliberate break runs the one that catches it
-- (tools/breaks.py), with what stands between them, which every such run plays. A new check goes into a block.
local F = FakeWoW
local failures = {}
local function expect(ok, what)
    if not ok then
        failures[#failures + 1] = what
    end
end
local function run(fn, ...)
    local ok, err = pcall(fn, ...)
    expect(ok, "error: " .. tostring(err))
end
local function slash(text)
    run(SlashCmdList.KALIHUD, text)
    F.RunTimers()
end
local function printed(text)
    for _, line in ipairs(F.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end
local function near(a, b)
    return a and b and math.abs(a - b) < 0.05
end

local ns = KaLiHUDDev.ns
local L = ns.L
local Frames, InfoBar, Plate, Geometry = ns.Frames, ns.InfoBar, ns.Plate, ns.Geometry
local Hub, Buttons, Drag = ns.Hub, ns.HubButtons, ns.HubDrag

-- What the last drawing took, by name, and where the outline stands at x.
local function taken(name)
    for _, f in ipairs(Plate.last and Plate.last.taken or {}) do
        if f.key == name then
            return f
        end
    end
end
local function heightAt(x)
    for _, s in ipairs(Plate.last.segs) do
        if s.x0 <= x and s.x1 >= x then
            return s.top
        end
    end
end
local function hasSlot(key)
    for _, s in ipairs(Plate.last.slots) do
        if s.key == key then
            return true
        end
    end
    return false
end
-- A frame moved as Edit Mode or another addon would, what's attached to it along.
local function move(f, x, y)
    local dx, dy = x - f.left, y - (f.top - f.height)
    for _, part in ipairs({ f, unpack(f.attached or {}) }) do
        part.left, part.top = part.left + dx, part.top + dy
    end
end
-- A frame placed by the player in Edit Mode: followed live, frozen once Edit Mode closes.
local function place(f, x, y)
    F.EnterEditMode()
    move(f, x, y)
    F.RunScript(Plate.frame, "OnUpdate")
    F.ExitEditMode()
    F.RunTimers()
end
-- The plate's top every 25 units across, to tell whether it changed.
local function tops()
    local out = {}
    for x = 5, Plate.last.W, 25 do
        out[x] = heightAt(x)
    end
    return out
end
-- Where the plate stands otherwise than `was`: the first x, or nil.
local function changedAt(was)
    for x, top in pairs(was) do
        if math.abs(heightAt(x) - top) > 0.01 then
            return x
        end
    end
    return nil
end

-- ---------- Login ----------
F.Fire("ADDON_LOADED", "KaLiHUD")
F.Fire("ADDON_LOADED", "KaLiHUD_Probe")
expect(ns.db ~= nil and ns.firstRun, "no saved data at the first run")
-- The hub's start, each of its steps on its own (the review of 2026-11-17): the folders' setup failing, here once it has
-- done its work, leaves the macros' start and what's made once theirs. It took both with it.
do -- of the session's start, never left out (run_tests.py's smoke_session), as the next
    local setup = ns.Folders.Setup
    ns.Folders.Setup = function(...)
        ns.Folders.Setup = setup
        setup(...)
        F.setupFailed = true
        error("broken on purpose: the folders' setup")
    end
end
F.Fire("PLAYER_LOGIN")
F.Fire("PLAYER_ENTERING_WORLD")
F.RunTimers()
do -- of the session's start
    local kept
    for msg, e in pairs(KaLiHUDDevDB.errors or {}) do
        if msg:find("broken on purpose: the folders' setup", 1, true) then
            kept = e
            KaLiHUDDevDB.errors[msg] = nil
        end
    end
    for i = #F.errors, 1, -1 do
        if tostring(F.errors[i]):find("broken on purpose: the folders' setup", 1, true) then
            table.remove(F.errors, i)
        end
    end
    F.Fire("UPDATE_MACROS")
    F.RunTimers()
    expect(F.setupFailed and kept and kept.count == 1 and (ns.EventCounts().UPDATE_MACROS or 0) >= 1
        and ns.Folders.ByRole("stats") ~= nil,
        "the folders' setup failing at login isn't kept as an error once, or stops the macros' start or the locked folders")
end
expect(not printed(L.API_NOT_AS_ASSUMED), "the API check at login finds the fake game not as assumed")
-- No freeze saved yet: once the world has settled, the frames are frozen as they stand, saved for the character.
local firstFreeze = Plate.Frozen()
expect(firstFreeze and ns.db.plates[ns.CharKey()] == firstFreeze and #firstFreeze.frames == 10,
    "the plate isn't frozen once the world has settled, or not saved for the character: "
        .. tostring(firstFreeze and #firstFreeze.frames))

-- Ikar's layout: the bars, the totem bar, the bags, the damage meter and the minimap are taken; the chat in the top
-- right corner is too far, the stance and pet bars don't show.
local art = Plate.last
expect(art and #art.segs >= 1 and Plate.textures > 0, "no plate drawn at login")
for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiCastActionBarFrame",
    "MicroMenuContainer", "BagsBar", "DamageMeter", "MinimapCluster" }) do
    expect(taken(name), "the plate doesn't take " .. name)
end
expect(art and #art.taken == 9, "the plate takes more than Ikar's frames: " .. tostring(art and #art.taken))
expect(art and art.far.ChatFrame1 and art.far.ChatFrame1 > 700, "the chat up in the corner isn't said out of reach")
expect(not taken("StanceBar") and not taken("PetActionBar"), "a bar that doesn't show is taken")
expect(art and art.dome and near(art.dome.cx, 981 + 69.3) and near(art.dome.cy, 40.8 + 69.3), "the dome isn't around the minimap")
expect(art and #art.slots == 10, "the slots aren't the 8 frames and the 2 status bars: " .. tostring(art and #art.slots))
expect(art and heightAt(957) > 100, "the narrow gap between the left bars and the dome isn't filled: " .. tostring(heightAt(957)))
expect(art and heightAt(1630) < 30, "the wide gap between the right bars and the damage meter is filled")
expect(art and near(heightAt(1630), art.T + ns.Border.Hug()),
    "in a gap the edge's metal isn't flush on the info bar's top: " .. tostring(heightAt(1630)) .. " vs " .. tostring(art and art.T))
local meter = taken("DamageMeter")
expect(meter and near(meter.w, 384), "the damage meter isn't taken with FlareUI's skin")

-- Collapsed BagsBar: no tall 236-unit chimney, and extending the bags does NOT grow the HUD!
local bagTaken = taken("BagsBar")
expect(bagTaken and bagTaken.h < 60, "collapsed BagsBar still creates a tall chimney: " .. tostring(bagTaken and bagTaken.h))
local bagTopCollapsed = heightAt(1400)
expect(KaLiHUD_BagBarToggle and KaLiHUD_BagBarToggle:IsShown(), "standalone bag toggle arrow isn't shown")
F.RunScript(KaLiHUD_BagBarToggle, "OnClick")
F.RunTimers()
expect(F.bagBarExpanded == true, "clicking bag toggle didn't expand the bag bar")
expect(near(heightAt(1400), bagTopCollapsed), "extending the bag bar changed the HUD's height: "
    .. tostring(heightAt(1400)) .. " vs " .. tostring(bagTopCollapsed))
F.RunScript(KaLiHUD_BagBarToggle, "OnClick")
F.RunTimers()

-- MainActionBar's page switch stays shown and is not counted in MainActionBar's width.
expect(MainActionBar.ActionBarPageNumber:IsShown(), "the action bar page switch was hidden")
expect(near(taken("MainActionBar").x, 544.6) and near(taken("MainActionBar").w, 393.4),
    "MainActionBar's box counted the page switch and broke alignment")

-- Full Minimap ownership: Blizzard's ring by default, the plate's dome round it, or our border round the map in its
-- place; round mask, header hidden, hover buttons hidden at rest.
expect(GetMinimapShape() == "ROUND" and Minimap.mask == "ui-hud-minimap-frame-generic-mask", "minimap isn't masked round")
expect(ns.db.options.minimapRing == "blizzard" and MinimapCompassTexture.alpha ~= 0 and art.dome.r > art.dome.ring,
    "the minimap doesn't keep Blizzard's ring by default")
-- Blizzard's widgets we move leave MinimapCluster: its Layout() would stretch it round them, up the screen.
expect(MinimapCluster.Tracking:GetParent() == UIParent and GameTimeFrame:GetParent() == UIParent,
    "a widget moved off the map stays in MinimapCluster")
-- Blizzard's map widgets drawn at the info bar's icon size, as ours: their art's longer side (the framed buttons' 22,
-- the compartment's 18.5, the envelope's 28, the day/night ring's 38.5) at the size.
local function drawnAt(size)
    return near(MinimapCluster.Tracking:GetScale() * 22, size) and near(GameTimeFrame:GetScale() * 22, size)
        and near(AddonCompartmentFrame:GetScale() * 18.5, size)
        and near(MinimapCluster.IndicatorFrame:GetScale() * 28, size) and near(MinimapCluster.DielFrame:GetScale() * 38.5, size)
end
expect(drawnAt(14), "the map's widgets aren't drawn at the icons' size: " .. tostring(MinimapCluster.Tracking:GetScale()))
-- One size for the info bar (Ikar 2026-11-15), its text's: at 14 the bar 25 tall, the icons 20, the spacing 14 (between
-- the items at its left end too); at the smallest, 6, the bar about 10 tall.
local function leftGap()
    local xs = {}
    for _, e in ipairs(Hub.Entries()) do
        local p = e.side == "left" and InfoBar.Placed(e.name)
        if p then
            xs[#xs + 1] = p
        end
    end
    table.sort(xs, function(a, b)
        return a.x < b.x
    end)
    return xs[2] and xs[2].x - xs[2].w / 2 - xs[1].x - xs[1].w / 2
end
ns.db.options.infoSize = 14
ns.ApplyAll()
F.RunTimers()
expect(drawnAt(20) and near(select(2, Hub.Pockets(art.dome, 22)), 22) and InfoBar.Top() == 25
    and near(Hub.Spacing(), 14) and near(leftGap(), 14), "the map's widgets, the pockets' places, the bar's height or "
        .. "its spacing don't follow the size: " .. tostring(leftGap()))
ns.db.options.infoSize = 6
expect(Hub.BarHeight() == 11 and Hub.IconSize() == 8 and near(Hub.Spacing(), 6),
    "the smallest size isn't about 10 tall")
ns.db.options.infoSize = nil
ns.ApplyAll()
F.RunTimers()
expect(InfoBar.Top() == 18 and Hub.IconSize() == 14 and Hub.TextSize() == 10 and near(Hub.Spacing(), 10),
    "the default size isn't 18 tall, text 10, icons 14, spacing 10")
-- Whatever the ring, the plate's rim round the map is the one made for Blizzard's (Ikar 2026-11-16: "no matter the
-- skin, the outer border must be preserved").
local blizzardDome = Plate.last.dome
local function blizzardRim(d)
    return d and near(d.ring, blizzardDome.ring) and near(d.r, blizzardDome.r)
end
-- A click on the map raises Blizzard's cluster over all else in its strata (it's toplevel): our ring rises with it,
-- still over the map (Ikar 2026-11-16: "when clicking on a map, it draws on top of the border"), drawn in UIParent's
-- units whatever the map's own scale (Edit Mode's size).
local function overMapOnceClicked(f)
    local scale = MinimapCluster:GetScale()
    MinimapCluster:SetScale(1.25)
    MinimapCluster:SetFrameLevel(MinimapCluster:GetFrameLevel() + 50)
    local over = f and f:GetParent() == Minimap and f:GetFrameStrata() == Minimap:GetFrameStrata()
        and f:GetFrameLevel() > Minimap:GetFrameLevel() and near(f:GetEffectiveScale(), UIParent:GetEffectiveScale())
    local seen = f and table.concat({ tostring(f:GetParent() == Minimap), f:GetFrameStrata(), Minimap:GetFrameStrata(),
        f:GetFrameLevel(), Minimap:GetFrameLevel(), f:GetEffectiveScale(), UIParent:GetEffectiveScale() }, " ") or "none"
    MinimapCluster:SetScale(scale)
    return over, seen
end
ns.db.options.minimapRing = "kali"
ns.ApplyAll()
F.RunTimers()
expect(MinimapCompassTexture.alpha == 0 and (ns.Minimap.ringDrawn or 0) > 0 and blizzardRim(Plate.last.dome),
    "the minimap doesn't wear our border in place of its ring, inside the rim made for Blizzard's")
local ringOver, ringSeen = overMapOnceClicked(ns.Minimap.ringBand)
expect(ringOver, "our border round the map goes under it once the map is clicked, or is drawn in the map's scale: "
    .. ringSeen)
-- One of the rings Ikar picked from his art (2026-11-16): its texture round the map, Blizzard's ring and our border
-- gone, the rim Blizzard's; one no wider than Blizzard's ring with its inner edge a hair inside the map's, a wider one
-- shrunk till its band ends where Blizzard's ring does (Ikar 2026-11-16: "Blizzard's rim, rings shrunk"); gone itself
-- for another ring.
ns.db.options.minimapRing = "frostcrystal"
ns.ApplyAll()
F.RunTimers()
local narrowDome, narrow = Plate.last.dome, ns.MINIMAP_RINGS.frostcrystal
expect(ns.Minimap.ringArt and narrow and blizzardRim(narrowDome)
    and near(ns.Minimap.ringArt:GetWidth() / 2 * narrow.inner, narrowDome.mapR - 1.5)
    and ns.Minimap.ringArt:GetWidth() / 2 * narrow.band < narrowDome.mapR * 215 / 198,
    "a ring of Ikar's no wider than Blizzard's isn't drawn at its own size, its inner edge under the map's, in the rim")
ns.db.options.minimapRing = "northstar"
ns.ApplyAll()
F.RunTimers()
local starDome, starRing, star = Plate.last.dome, ns.Minimap.ringArt, ns.MINIMAP_RINGS.northstar
expect(star and starRing and starRing:IsShown() and starRing.Ring:GetTextureFilePath() == star.file
    and MinimapCompassTexture.alpha == 0 and near(starRing:GetWidth() / 2 * star.band, starDome.mapR * 215 / 198)
    and starRing:GetWidth() / 2 * star.inner < starDome.mapR - 1.5 and blizzardRim(starDome),
    "a ring of Ikar's wider than Blizzard's isn't shrunk to it round the map, in the rim made for Blizzard's")
local starOver, starSeen = overMapOnceClicked(starRing)
expect(starOver, "one of Ikar's rings goes under the map once the map is clicked, or is drawn in the map's scale: "
    .. starSeen)
ns.db.options.minimapRing = nil
ns.ApplyAll()
F.RunTimers()
expect(not (starRing and starRing:IsShown()) and MinimapCompassTexture.alpha ~= 0,
    "a ring of Ikar's stays round the map once another is picked")
art = Plate.last
-- The minimap option off: Blizzard's widgets back as Blizzard had them (anchors, size, scale, parent), its dropdown
-- buttons on the left button alone again, the header where Edit Mode's setting has it; on again, ours.
do
    local track = MinimapCluster.Tracking
    -- Forever's own coordinates under the map (Ikar 2026-11-19: "when taking over, we should hide them"): the game's
    -- setting off while the HUD has the map, the player's value kept, and given back with the map
    expect(F.cvars.minimapShowPlayerCoords == "0" and ns.db.cvars.minimapShowPlayerCoords == "1",
        "the map taken, Forever's coordinates under it still show, or the player's setting isn't kept")
    F.headerUnderneath, F.header = true, nil
    ns.db.options.minimap = false
    ns.ApplyAll()
    F.RunTimers()
    expect(F.cvars.minimapShowPlayerCoords == "1" and ns.db.cvars.minimapShowPlayerCoords == nil,
        "the map given back, Forever's coordinates aren't as the player had them")
    local point, to = GameTimeFrame:GetPoint()
    expect(point == "TOPLEFT" and to == MinimapCluster.ZoneTextButton and GameTimeFrame:GetScale() == 1
        and GameTimeFrame:GetParent() == MinimapCluster and track:GetParent() == MinimapCluster and track:GetWidth() == 26
        and select(2, track:GetPoint()) == MinimapCluster and select(2, track.Button:GetPoint()) == track
        and select(2, MinimapCluster.DielFrame:GetPoint()) == Minimap and MinimapCluster.DielFrame:GetParent() == MinimapCluster,
        "the minimap option off leaves Blizzard's widgets where KaLi HUD put them")
    expect(table.concat(track.Button.mouseButtons, ",") == "LeftButtonDown,LeftButtonUp"
        and table.concat(AddonCompartmentFrame.mouseButtons, ",") == "LeftButtonDown,LeftButtonUp",
        "the minimap option off leaves the dropdown buttons hearing the right button")
    expect(F.header == true and F.headerUpdates == 1, "the minimap option off forces the header against Edit Mode's setting")
    ns.db.options.minimap = nil
    F.headerUnderneath = false
    ns.ApplyAll()
    F.RunTimers()
    expect(track:GetParent() == UIParent and GameTimeFrame:GetParent() == UIParent and drawnAt(14)
        and table.concat(track.Button.mouseButtons, ",") == "LeftButtonDown,LeftButtonUp,RightButtonUp",
        "the minimap option on again doesn't take Blizzard's widgets back")
end
expect(MinimapCluster.ZoneTextButton.alpha == 0 or not MinimapCluster.ZoneTextButton:IsMouseEnabled(),
    "minimap top header bar wasn't hidden")
expect(GameTimeFrame:IsMouseEnabled() == true, "the calendar button, shown always by default, isn't clickable at rest")
ns.db.items[ns.Natives.NAME.CALENDAR] = { side = "ring", order = 53, angle = 138, show = "hover" }
Hub.Changed()
F.RunTimers()
expect(GameTimeFrame:IsMouseEnabled() == false, "hover-only calendar button is clickable at rest")
Minimap.mouseOver = true
ns.Minimap.UpdateHover()
expect(GameTimeFrame:IsMouseEnabled() == true, "hovering the minimap doesn't reveal hover buttons")
Minimap.mouseOver = false
ns.db.items[ns.Natives.NAME.CALENDAR] = nil
Hub.Changed()
F.RunTimers()
-- Speeds the game keeps secret (unit stats restricted): the last one stays, no error.
do
    local function errorCount()
        local n = 0
        for _ in pairs(KaLiHUDDevDB.errors or {}) do
            n = n + 1
        end
        return n
    end
    local errs, shown = errorCount(), Hub.Object("KaLiHUD_Speed").text
    F.speedSecret = true
    run(ns.Items.Update)
    run(Hub.Object("KaLiHUD_Speed").OnTooltipShow, GameTooltip)
    F.speedSecret = nil
    expect(errorCount() == errs and Hub.Object("KaLiHUD_Speed").text == shown, "a secret speed errors or changes the speed shown")
end

-- The info bar off: the bars standing on the status bars stay taken (Ikar 2026-11-13: they were let go).
ns.db.options.infoBar = false
ns.ApplyAll()
F.RunTimers()
expect(taken("MainActionBar") and taken("MultiBarBottomLeft") and taken("MultiCastActionBarFrame"),
    "with the info bar off, the bars on the status bars are out of reach")
ns.db.options.infoBar = true
ns.ApplyAll()
F.RunTimers()

-- The dome follows the map at the size Edit Mode gives it; the addon never scales it.
local defaultDomeR = art.dome.r
F.EnterEditMode()
MinimapCluster:SetEditModeScale(1.3)
F.RunTimers()
expect(Plate.last.dome.r > defaultDomeR + 15, "the dome doesn't grow with the map: " .. tostring(Plate.last.dome.r))
expect(rawget(ns.db.options, "minimapSize") == nil, "Edit Mode's map size went into the options")
-- Round Blizzard's ring, Ikar's widths for a map 158.4 wide: the dome's edge 8 past the map, clear of the ring's top; 3
-- at the foot.
ns.db.options.minimapRing = "blizzard"
MinimapCluster:SetEditModeScale(158.4 / 138.6)
ns.ApplyAll()
F.RunTimers()
local blizzDome = Plate.last.dome
expect(near(blizzDome.r - blizzDome.mapR, 8) and near(blizzDome.ring - blizzDome.mapR, 3),
    "Blizzard's ring round a map 158.4 wide: the dome's edge isn't 8 past the map and the foot 3: "
    .. tostring(blizzDome.r - blizzDome.mapR) .. " " .. tostring(blizzDome.ring - blizzDome.mapR))
ns.db.options.minimapRing = nil
MinimapCluster:SetEditModeScale(1)
ns.ApplyAll()
F.ExitEditMode()
F.RunTimers()
art = Plate.last

local bars = ns.StatusBars.bars
expect(bars[-1]:IsShown() and bars[-1].Text:GetText():find("XP", 1, true), "the left status bar doesn't show the experience")
expect(bars[1]:IsShown() and bars[1].Text:GetText():find("Darnassus", 1, true), "the right status bar doesn't show the watched reputation")
expect(bars[-1].Ticks and bars[-1].Ticks[1]:IsShown(), "status bar 5% bubble dividers aren't shown")
expect(not FlareUI_XPBar:IsMouseEnabled(), "external XP bar wasn't silenced while KaLi HUD status bars are active")
-- Alpha 0 leaves the mouse on: Blizzard's bar under the manager, and its rested tick, go deaf too; Edit Mode's box,
-- seen whatever its parent's alpha, is left to Blizzard. The setting off, they hear again.
local blizzBar = MainStatusTrackingBarContainer.bars[1]
local blizzBox = MainStatusTrackingBarContainer.Selection
expect(not blizzBar:IsMouseEnabled() and not blizzBar.ExhaustionTick:IsMouseEnabled(),
    "Blizzard's hidden XP bar or its rested tick still takes the mouse")
expect(blizzBox:IsMouseEnabled(), "Edit Mode's box over Blizzard's XP bar was made deaf")
ns.db.options.hideExternalXP = false
ns.StatusBars.Refresh()
expect(blizzBar:IsMouseEnabled() and blizzBar.ExhaustionTick:IsMouseEnabled() and blizzBox:IsMouseEnabled(),
    "Blizzard's XP bar doesn't take the mouse again once shown")
ns.db.options.hideExternalXP = nil
ns.StatusBars.Refresh()
expect(not blizzBar:IsMouseEnabled(), "Blizzard's XP bar takes the mouse once hidden again")
expect(bars[-1].slot and near(bars[-1].slot.x, 544.6 - ns.db.options.padBars), "the left status bar isn't under the left bars")
expect(bars[1].slot and bars[1].slot.x >= art.dome.cx + art.dome.ring - 0.01,
    "the right status bar runs under the map's ring")

-- Nothing lands on the bar unasked (the review of 2026-11-17, second round; Ikar: "Agreed"): at a first run another
-- addon's data source lands in the folder where new addons land, as its launcher does, not on the bar's right end.
-- Then put on the bar where it used to land, for what follows.
do -- of the session's start, never left out: what follows stands on the place it saves (run_tests.py's smoke_session)
    local e = Hub.Entry("Libs Error Display")
    expect(e and e.side == "folder" and e.folder == ns.Folders.Default() and InfoBar.Placed("Libs Error Display") == nil,
        "at a first run another addon's data source lands on the bar, not in the folder where new addons land: "
        .. tostring(e and e.side) .. ", " .. tostring(e and e.folder) .. ", " .. tostring((ns.Folders.Default())))
    ns.db.items["Libs Error Display"] = { side = "right", order = 102 }
    Hub.Changed()
    F.RunTimers()
end
-- The info bar & lock button: our default-shown items, the other addon's data source the player put there (its
-- launcher is in the Add-ons folder), and Speed hidden by default (toggleable).
for _, name in ipairs({ "KaLiHUD_Location", "KaLiHUD_Coords", "KaLiHUD_Clock", "KaLiHUD_Bags", "KaLiHUD_Gold", "KaLiHUD_Repair",
    "KaLiHUD_XP", "KaLiHUD_Performance", "KaLiHUD_Volume", "Libs Error Display" }) do
    local b = Buttons.Get(name)
    expect(b and b:IsShown(), "the info bar doesn't show " .. name)
end
expect(InfoBar.lockButton and InfoBar.lockButton:IsShown(), "the info bar's far-right lock button isn't shown")
expect(F.ldb.objects.KaLiHUD_Bags ~= nil, "our items aren't published for other displays")
expect(Buttons.Get("KaLiHUD_Bags").Text:GetText() == "22/28", "bags: " .. tostring(Buttons.Get("KaLiHUD_Bags").Text:GetText()))
expect(Buttons.Get("KaLiHUD_Repair").Text:GetText():find(string.format(L.PERCENT, 30), 1, true), "repair doesn't show the most worn item")
expect(Buttons.Get("KaLiHUD_Performance").Text:GetText() == string.format(L.PERF_TEXT, 118, 54), "performance")
expect(Buttons.Get("KaLiHUD_Location").Text:GetText():find("Marche de l'Ouest", 1, true), "location")
-- The zone right under the map, the coordinates and the clock either side of it.
local zone = Buttons.Get("KaLiHUD_Location")
expect(near(zone.ux, art.dome.cx), "the zone isn't right under the map: " .. tostring(zone.ux) .. " for " .. tostring(art.dome.cx))
expect(Buttons.Get("KaLiHUD_Coords").ux < zone.ux and Buttons.Get("KaLiHUD_Clock").ux > zone.ux,
    "the coordinates and the clock aren't either side of the zone")
expect(Buttons.Get("Spoken").Text:GetText() == "" and Buttons.Get("Spoken").Icon:IsShown(), "a launcher with an icon shows its icon only")
expect(Buttons.Get("Libs Error Display").Text:GetText():find("Erreurs", 1, true), "a data source without an icon shows its label")

-- ---------- The plate follows in Edit Mode, static outside it ----------
-- Outside Edit Mode (Ikar 2026-11-15: "people do not expect their UI to change with dynamic events"): a bar moved,
-- shown or hidden, the bags unfolded, change nothing; the freeze stays the character's.
do
    local was = tops()
    move(MultiBarBottomLeft, 544.6, 600)
    StanceBar:Show()
    F.RunScript(KaLiHUD_BagBarToggle, "OnClick")
    F.RunTimers()
    ns.ApplyAll()
    expect(not changedAt(was) and taken("MultiBarBottomLeft") and not taken("StanceBar"),
        "outside Edit Mode, the plate follows a bar moved or shown, at " .. tostring(changedAt(was)))
    expect(Plate.frame:GetScript("OnUpdate") == nil, "outside Edit Mode, the plate looks every frame")
    move(MultiBarBottomLeft, 544.6, 94.5)
    StanceBar:Hide()
    F.RunScript(KaLiHUD_BagBarToggle, "OnClick")
    F.RunTimers()
    expect(Plate.Frozen() == ns.db.plates[ns.CharKey()] and not changedAt(was), "the freeze isn't the character's")
end
-- What the player moves himself outside Edit Mode is followed once he lets go (Ikar 2026-11-16: "add support for the
-- user actions"), that frame alone: the chat dragged by its tab (Blizzard's FCF_StopDragging ends with
-- StopMovingOrSizing), and back.
do
    local was = tops()
    local function chatRecord()
        for _, f in ipairs(Plate.Frozen().frames) do
            if f.key == "ChatFrame1" then
                return f
            end
        end
    end
    local x0, y0 = ChatFrame1.left, ChatFrame1.top - ChatFrame1.height
    expect(not taken("ChatFrame1") and chatRecord(), "the chat up in its corner isn't frozen off the plate")
    local before = chatRecord().x
    -- let go down in the bottom left corner, on the plate: taken, the plate changed there alone
    move(ChatFrame1, 40, 40)
    F.RunTimers()
    expect(not changedAt(was) and not taken("ChatFrame1"), "the chat moved by the game, not let go by the player, moves the plate")
    ChatFrame1:StopMovingOrSizing()
    F.RunTimers()
    local changed, outside = 0, nil
    for x, top in pairs(was) do
        if math.abs(heightAt(x) - top) > 0.01 then
            changed = changed + 1
            if x > 40 + ChatFrame1.width + 80 then
                outside = x
            end
        end
    end
    expect(taken("ChatFrame1") and chatRecord().x < 100 and changed > 0 and not outside
        and Plate.Frozen() == ns.db.plates[ns.CharKey()],
        "the chat let go on the plate by the player outside Edit Mode isn't taken, or more than its place changed: "
            .. changed .. " " .. tostring(outside))
    -- and back up in its corner
    move(ChatFrame1, x0, y0)
    ChatFrame1:StopMovingOrSizing()
    F.RunTimers()
    expect(not changedAt(was) and not taken("ChatFrame1") and near(chatRecord().x, before),
        "the chat let go back where it was, the plate isn't as it was")
end
-- Edit Mode shows the stance bar: taken while it shows, let go when it hides again.
F.EnterEditMode()
StanceBar:Show()
F.RunTimers()
expect(taken("StanceBar"), "the stance bar Edit Mode shows isn't taken")
StanceBar:Hide()
F.ExitEditMode()
F.RunTimers()
expect(not taken("StanceBar") and #Plate.last.taken == 9, "the stance bar hidden again is still taken")

-- A bar dragged in Edit Mode updates live on every frame via OnUpdate (zero 0.5s lag!), and leaves the plate when dragged high.
F.EnterEditMode()
expect(Plate.frame:GetScript("OnUpdate") ~= nil, "live frame-by-frame tracking isn't active in Edit Mode")
move(MultiBarBottomLeft, 544.6, 600)
F.RunScript(Plate.frame, "OnUpdate")
expect(not taken("MultiBarBottomLeft") and Plate.last.far.MultiBarBottomLeft, "a bar dragged far up is still taken during live drag")
local bar1Top = 49 + 31.5 + ns.db.options.padBars + ns.db.options.marginBars
expect(not taken("MultiCastActionBarFrame") and near(Plate.last.far.MultiCastActionBarFrame, 140 - bar1Top),
    "the totem bar left standing in the air is still taken: " .. tostring(Plate.last.far.MultiCastActionBarFrame))
move(MultiBarBottomLeft, 544.6, 94.5)
F.RunScript(Plate.frame, "OnUpdate")
expect(taken("MultiBarBottomLeft") and taken("MultiCastActionBarFrame"), "the bars put back aren't taken again live")

-- KaLi HUD's dialog opens beside Blizzard's Edit Mode window, never over it, its top level with it: right of it at the
-- screen's top middle (where the game's panels put it), left of it once moved right; without it, where it always
-- opened.
do
    local W = UIParent:GetWidth()
    local manager = F.Geometry(EditModeManagerFrame, W / 2 - 255, 400, 510, 680)
    manager:Show()
    local function opened()
        ns.EditFrame.Select()
        local point, _, _, x, y = KaLiHUDEditModeDialog:GetPoint()
        ns.EditFrame.Deselect()
        return point, x, y
    end
    local point, x, y = opened()
    expect(point == "TOPLEFT" and x >= W / 2 + 255 and near(y, 1080),
        "the dialog doesn't open right of Blizzard's Edit Mode window: " .. tostring(point) .. " " .. tostring(x))
    manager.left = W - 600
    point, x, y = opened()
    expect(point == "TOPRIGHT" and x <= W - 600 and near(y, 1080),
        "the dialog doesn't open left of Blizzard's window moved right: " .. tostring(point) .. " " .. tostring(x))
    manager:Hide()
    expect(opened() == "BOTTOM", "without Blizzard's window the dialog doesn't open where it always did")
end
-- Selecting KaLi HUD in Edit Mode opens KaLiHUDEditModeDialog; changing a margin updates the plate live and Revert undoes it.
ns.EditFrame.Select()
expect(ns.EditFrame.IsSelected() and ns.EditPanel.IsShown(), "selecting KaLi HUD in Edit Mode doesn't open its dialog")
local beforeBarTop = heightAt(600)
ns.db.options.marginBars = 18
ns.ApplyAll()
expect(heightAt(600) > beforeBarTop + 5, "raising marginBars didn't grow the bar margin")
ns.EditPanel.Revert()
expect(near(heightAt(600), beforeBarTop), "reverting Edit Mode changes didn't restore marginBars")
-- A corner limit fills the plate up, never down; unlimited again, the plate is as it was.
local freeCorners, freeTops = Geometry.Corners(Plate.last.segs), {}
for x = 5, Plate.last.W, 25 do
    freeTops[x] = heightAt(x)
end
expect(freeCorners > 6, "Ikar's layout has too few corners to test a limit: " .. freeCorners)
ns.db.options.maxCorners = 6
ns.ApplyAll()
expect(Geometry.Corners(Plate.last.segs) <= 6, "the plate has more corners than its limit: " .. Geometry.Corners(Plate.last.segs))
local cameDown
for x, top in pairs(freeTops) do
    if heightAt(x) < top - 0.01 then
        cameDown = x
    end
end
expect(not cameDown, "limiting the corners lowered the plate at " .. tostring(cameDown))
ns.db.options.maxCorners = 0
ns.ApplyAll()
expect(Geometry.Corners(Plate.last.segs) == 0 and #Plate.last.segs == 1, "0 corners isn't one straight line: "
    .. Geometry.Corners(Plate.last.segs) .. " corners, " .. #Plate.last.segs .. " stretches")
expect(ns.DB.DEFAULTS.maxCorners == ns.DB.UNLIMITED_CORNERS, "the corners aren't unlimited by default")
ns.db.options.maxCorners = ns.DB.UNLIMITED_CORNERS
ns.ApplyAll()
expect(Geometry.Corners(Plate.last.segs) == freeCorners, "unlimited again, the plate didn't get its corners back")
F.ExitEditMode()
F.RunTimers()
expect(Plate.frame:GetScript("OnUpdate") == nil, "live OnUpdate stayed active after leaving Edit Mode")

-- The folds snap here (foldAnim off); animated, they have their own block further down.
ns.db.options.foldAnim = false
-- The chat moved down to the left: folding it lets the plate down and counts unread messages.
place(ChatFrame1, 40, 40)
local chat = taken("ChatFrame1")
expect(chat and near(chat.x, 33) and near(chat.w, 433), "the chat moved down isn't taken with FlareUI's skin: "
    .. tostring(chat and chat.x) .. " " .. tostring(chat and chat.w))
local openChatTop = heightAt(100)
ns.Windows.Toggle("ChatFrame1")
expect(ns.db.options.chatFolded and heightAt(100) < openChatTop - 100, "folding ChatFrame1 didn't shrink the plate")
expect(ChatFrame1:GetAlpha() == 0, "the folded chat still shows: FlareUI put its alpha back")
ChatFrame1:SetAlpha(1)
expect(ChatFrame1:GetAlpha() == 0, "the folded chat shows again once FlareUI fades it in")
F.Fire("CHAT_MSG_SAY", "Salut !")
ns.Windows.Toggle("ChatFrame1")
expect(not ns.db.options.chatFolded and near(heightAt(100), openChatTop), "unfolding ChatFrame1 didn't restore the plate")
expect(ChatFrame1:GetAlpha() == 1, "the unfolded chat doesn't show")
-- The fold arrow in Ikar's cartouche on top of the chat, its ring RING across: over the chat's middle, its flat line
-- its own rise over the middle of the plate's metal on the chat's top, at any size, following the border at half its
-- width; lifted as set; folded, alone on the plate, above the window's rows; in Edit Mode, on the chat again.
local cart, look = ns.Windows.Cartouche("ChatFrame1"), ns.CARTOUCHES[ns.db.options.foldArt]
local function cartLine()
    local _, _, _, x, y = cart:GetPoint()
    local s = cart:GetWidth() / look.w
    return x + look.ringX * s, y + look.base * s
end
-- where the cartouche stands: the line under its flat line, which a lift of 0 sets on the window's top
local function cartFoot()
    local x, line = cartLine()
    return x, line - ns.Border.Hug() / 2 - look.rise
end
chat = taken("ChatFrame1")
local ringX, foot = cartFoot()
expect(look and cart:IsShown() and near(ringX, chat.x + chat.w / 2) and near(foot, chat.y + chat.h),
    "the chat's cartouche isn't centred on its top: " .. tostring(ringX) .. " " .. tostring(foot))
-- half the chat's width by default (Ikar 2026-11-20: "keep the slider, but it shoudl show relative size, default to
-- 50%")
expect(ns.DB.DEFAULTS.foldArtWidth == 50 and near(cart:GetWidth(), chat.w / 2),
    "the chat's cartouche isn't half the chat's width: " .. cart:GetWidth() .. " of " .. chat.w)
expect(cart.Art.filter == "TRILINEAR", "the cartouche's art, drawn under its size, isn't filtered: " .. tostring(cart.Art.filter))
do
    local s = cart:GetWidth() / look.w
    local _, _, _, ix, iy = cart.Icon:GetPoint()
    expect(near(ix, look.ringX * s) and near(iy, -look.ringY * s) and near(cart.Icon:GetWidth(), 1.5 * look.ringR * s)
        and cart.Icon.rotation == 0, "the fold arrow isn't in the cartouche's ring, pointing down")
end
expect(near(cart.Clip:GetHeight(), cart:GetHeight()) and near(cart.Clip:GetWidth(), cart:GetWidth()),
    "the open chat's cartouche isn't drawn whole")
ns.db.options.foldArtWidth = 75
ns.ApplyAll()
expect(near(cart:GetWidth(), chat.w * 0.75) and near(select(2, cartFoot()), chat.y + chat.h),
    "the cartouche grown leaves its flat line, or isn't the share of its window set: " .. tostring(select(2, cartFoot())))
-- Every cartouche the share of its window set, on the chat and on the damage meter, its ring as its art has it there
-- (its ring the same on every one from 2026-11-18 until 2026-11-20): the styles' own.
do
    -- each style wearing its own (Ikar 2026-11-18: "Two new cartouche, the first for steampunk, second for the
    -- silver"; then "I added arts for the gold and the astronomy version"; then "For the steampunk, the last, replace
    -- the existing", "4th for the gem"), a choice saved and named; the Silver's well painted into its art, the round
    -- ones' a disc the addon draws (the Steampunk's too since its ring is round); the fire one ("Last for fire") worn
    -- by no style, chosen and named all the same; the Astronomy's painted too since 2026-11-20, its opening a little
    -- taller than wide ("and new astronomy in"); the Steampunk's painted again the same day, an octagon ("use the
    -- last"), then another ("new cartouche for steam punk, number 2 and 5", "keep steampunk 1 [...] remove the 2")
    local painted = { silver = true, astronomy = true, steampunk = true }
    for id, style in pairs({ steampunk = "steampunk", silver = "steel", golden = "golden", astronomy = "astronomy",
                             gem = "gem", fire = false }) do
        local c = ns.CARTOUCHES[id]
        expect(c and (not style or ns.PRESET_BY_ID[style].foldArt == id) and ns.DB.CHOICES.foldArt[id]
            and (c.well[4] == 0) == (painted[id] == true)
            and ns.STRINGS.frFR["FOLD_ART_" .. id] and ns.STRINGS.enUS["FOLD_ART_" .. id]
            and ns.STRINGS.deDE["FOLD_ART_" .. id] and ns.STRINGS.esES["FOLD_ART_" .. id],
            "the " .. tostring(style) .. " style doesn't wear its own cartouche, or it can't be chosen or named: " .. id)
    end
    local meter = taken("DamageMeter")
    expect(meter and not near(meter.w, chat.w), "the damage meter is as wide as the chat: the test can't tell them apart")
    for _, id in ipairs({ "steampunk", "silver", "golden", "astronomy", "fire", "gem" }) do
        ns.db.options.foldArt = id
        ns.ApplyAll()
        local c = ns.CARTOUCHES[id]
        for _, w in ipairs({ { "ChatFrame1", chat }, { "DamageMeter", meter } }) do
            local f = ns.Windows.Cartouche(w[1])
            expect(f and f:IsShown() and near(f:GetWidth(), w[2].w * 0.75) and near(f:GetHeight() / f:GetWidth(), c.h / c.w),
                id .. " on " .. w[1] .. " isn't the share of its window set, as tall as its art: "
                .. tostring(f and f:GetWidth()) .. " of " .. tostring(w[2].w))
        end
    end
    ns.db.options.foldArt = nil
    ns.ApplyAll()
end
ns.db.options.foldArtWidth = nil
ns.db.options.borderSize = 100
ns.ApplyAll()
local lineAt100 = select(2, cartLine())
ns.db.options.borderSize = 50
ns.ApplyAll()
expect(near(lineAt100 - select(2, cartLine()), (ns.Border.Hug() * 2 - ns.Border.Hug()) / 2),
    "the cartouche doesn't follow the border at half its width: " .. tostring(lineAt100 - select(2, cartLine())))
ns.db.options.borderSize = nil
ns.db.options.foldArtLift = 5
ns.ApplyAll()
expect(near(select(2, cartFoot()), chat.y + chat.h + 5), "the cartouche's height doesn't lift it")
ns.db.options.foldArtLift = nil
ns.Windows.Toggle("ChatFrame1")
ringX, foot = cartFoot()
expect(not taken("ChatFrame1") and cart:IsShown()
    and near(ringX, chat.x + chat.w / 2) and near(foot, math.max(heightAt(ringX) - ns.Border.Hug(), Plate.last.T))
    and cart.tip == L.WIN_UNFOLD and cart.title == L.WIN_CHAT and cart.Icon.rotation == math.pi,
    "the folded chat's cartouche isn't alone on the plate, its arrow up: " .. tostring(foot))
-- Folded, behind the info bar (Ikar 2026-11-18: "when collapsed, can we put the cartouche behind the info bar ?"):
-- drawn over the plate, under the bar; its clicks taken by its Catch, on top, over the part of it the bar leaves.
expect(cart:GetFrameStrata() == "BACKGROUND" and not cart:IsMouseEnabled() and cart.Catch:IsShown()
    and cart.Catch:GetFrameStrata() == "HIGH" and near(cart.Catch:GetWidth(), cart:GetWidth())
    and cart.Catch:GetHeight() <= cart:GetHeight() + 0.01,
    "the folded chat's cartouche isn't behind the info bar, or nothing over it takes its click")
-- and under the bar's top faded out down to the bar's middle, under its buttons, nothing drawn lower (Ikar
-- 2026-11-19: "the cartouche not hidden, just drawn bellow icon"; 2026-11-20: "instead of hiding the bottom, make a
-- transparency gradient, till half the info bar"); Catch still stops at the bar's top, the bar's buttons under the rest
do
    local _, _, _, _, y = cart:GetPoint()
    local bar, top = ns.InfoBar.Top(), y + cart:GetHeight()
    local g = cart.ArtFade.gradient
    expect(y < bar and near(cart.Clip:GetHeight(), top - math.max(y, bar / 2))
        and near(cart.Catch:GetHeight(), top - math.max(y, bar)) and cart.ArtFade:IsShown() and g
        and near(g[3].a, 1) and near(g[2].a, (math.max(y, bar / 2) - bar / 2) / (bar / 2)),
        "the folded chat's cartouche isn't faded out from the info bar's top to its middle: "
        .. tostring(cart.Clip:GetHeight()))
end
F.EnterEditMode()
F.RunTimers()
expect(cart:IsShown() and near(select(2, cartFoot()), chat.y + chat.h) and cart.tip == L.WIN_UNFOLD,
    "the cartouche leaves the chat in Edit Mode")
F.ExitEditMode()
F.RunTimers()
F.RunScript(cart, "OnClick", "LeftButton")
expect(not ns.db.options.chatFolded and cart.tip == L.WIN_FOLD, "clicking the cartouche doesn't unfold the chat")
-- Another tab picked: the dock hides ChatFrame1 and shows that window, which the plate holds as the chat; folding
-- hides it too, and unfolding gives every docked window back.
F.PickChatTab(ChatFrame2)
F.RunTimers()
local tab = taken("ChatFrame1")
expect(tab and near(tab.x, chat.x) and near(tab.w, chat.w), "with another tab picked, the chat leaves the plate")
ns.Windows.Toggle("ChatFrame1")
expect(not taken("ChatFrame1") and ChatFrame2:GetAlpha() == 0 and ChatFrame1:GetAlpha() == 0 and cart:IsShown(),
    "folded from another tab, its window still shows")
ns.Windows.Toggle("ChatFrame1")
expect(ChatFrame2:GetAlpha() == 1 and ChatFrame1:GetAlpha() == 1 and taken("ChatFrame1"),
    "unfolded from another tab, the docked windows don't come back")
F.PickChatTab(ChatFrame1)
F.RunTimers()
-- The arrow alone in place of a cartouche: 24 across at 100 %, over the chat's middle, its V's foot on the metal's middle.
ns.db.options.foldArt = "arrow"
ns.ApplyAll()
local _, _, _, ax, ay = cart:GetPoint()
expect(cart:IsShown() and not cart.Art:IsShown() and not cart.Well:IsShown() and near(cart:GetWidth(), 24)
    and near(cart.Icon:GetWidth(), 24) and near(ax + 12, chat.x + chat.w / 2)
    and near(ay + 7, chat.y + chat.h + ns.Border.Hug() / 2), "the arrow alone isn't on the chat's middle: " .. tostring(ay))
ns.db.options.foldArt = nil
ns.ApplyAll()
expect(cart.Art:IsShown() and cart.Well:IsShown(), "a cartouche picked again, its art stays hidden")
-- The Ornates as drawn, with their blue, no longer made (Ikar 2026-11-16): a window folded by one keeps its piece, in
-- silver, as nothing put right.
do
    local function opened(art)
        local saved = { version = 1, items = {}, folders = {}, buttonsLeft = {}, statusPlaces = {}, gold = {},
            options = { foldArt = art } }
        local _, info = ns.DB.Open(saved)
        return saved.options.foldArt, info and info.fixed
    end
    local one, fixedOne = opened("complex1")
    local two, fixedTwo = opened("complex2")
    expect(not ns.CARTOUCHES.complex1 and not ns.CARTOUCHES.complex2 and one == "complex1darkgold" and fixedOne == 0
        and two == "complex2silver" and fixedTwo == 0,
        "a window folded by an Ornate no longer made loses its piece: " .. tostring(one) .. " " .. tostring(two))
    -- a size saved when it was the ring's (until 2026-11-20): gone, the width's default taken
    do
        local saved = { version = 1, items = {}, folders = {}, buttonsLeft = {}, statusPlaces = {}, gold = {},
            options = { foldArtSize = 150 } }
        ns.DB.Open(saved)
        expect(rawget(saved.options, "foldArtSize") == nil and rawget(saved.options, "foldArtWidth") == nil,
            "a cartouche size saved as the ring's stays, or becomes a width: " .. tostring(saved.options.foldArtSize))
    end
    -- the Steampunk 2, made for an evening (Ikar 2026-11-20: "remove the 2"): the Steampunk's
    local sp, fixedSp = opened("steampunk2")
    expect(not ns.CARTOUCHES.steampunk2 and sp == "steampunk" and fixedSp == 0,
        "a window folded by the Steampunk 2 loses its piece: " .. tostring(sp))
    -- both Steampunk rings, one in their place (Ikar 2026-11-20: "a new steampunk minimap art that will replace the 2
    -- currently in the plugin"): either picked wears it
    local rings = {}
    for _, old in ipairs({ "steampunk1", "steampunk2" }) do
        local saved = { version = 1, items = {}, folders = {}, buttonsLeft = {}, statusPlaces = {}, gold = {},
            options = { minimapRing = old } }
        local _, info = ns.DB.Open(saved)
        rings[#rings + 1] = tostring(saved.options.minimapRing) .. (info and info.fixed == 0 and "" or " (fixed)")
    end
    expect(not ns.MINIMAP_RINGS.steampunk1 and not ns.MINIMAP_RINGS.steampunk2 and ns.MINIMAP_RINGS.steampunk
        and rings[1] == "steampunk" and rings[2] == "steampunk" and ns.PRESET_BY_ID.steampunk.minimapRing == "steampunk",
        "a Steampunk ring no longer made isn't the new one: " .. table.concat(rings, ", "))
end
-- The damage meter folded: its cartouche, or its header, over the meter's see-through rows, which still take the
-- mouse; a click unfolds it.
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
ns.Windows.Toggle("DamageMeter")
local meterCart = ns.Windows.Cartouche("DamageMeter")
expect(meterCart:IsShown() and STRATA[meterCart:GetFrameStrata()] < STRATA.LOW and meterCart.Catch:IsShown()
    and STRATA[meterCart.Catch:GetFrameStrata()] > STRATA.MEDIUM
    and DamageMeterSessionWindow1:GetAlpha() == 0, "the folded damage meter's cartouche lies under its see-through rows")
F.RunScript(meterCart.Catch, "OnClick", "LeftButton")
expect(not ns.db.options.meterFolded and DamageMeterSessionWindow1:GetAlpha() == 1, "clicking the damage meter's cartouche doesn't unfold it")
ns.db.options.foldArt = "arrow"
ns.Windows.Toggle("DamageMeter")
expect(meterCart:IsShown() and not meterCart.Art:IsShown() and meterCart.Catch:IsShown()
    and STRATA[meterCart.Catch:GetFrameStrata()] > STRATA.MEDIUM and meterCart.title == L.WIN_METER and DamageMeterSessionWindow1:GetAlpha() == 0,
    "the folded damage meter's arrow lies under its see-through rows")
F.RunScript(meterCart, "OnClick", "LeftButton")
expect(not ns.db.options.meterFolded and DamageMeterSessionWindow1:GetAlpha() == 1, "clicking the folded damage meter's arrow doesn't unfold it")
ns.db.options.foldArt = nil
ns.ApplyAll()

-- Folding animated (Ikar 2026-11-15: "no fading, I want folding"), here as a blind: the chat goes at once, then its
-- place comes down into the plate, the cartouche on its top; unfolding, the place rises first and the chat shows only
-- as it comes to rest (Ikar 2026-11-16: "a bit earlier, at the end of the transition"). Not linear (Ikar 2026-11-15),
-- eased out both ways (2026-11-16: "it should end the motion more slowly"): off at once, slowing into place. The
-- tome's sounds as clicked: put away folding, drawn unfolding.
expect(ns.DB.DEFAULTS.foldAnim == true and ns.DB.DEFAULTS.foldSound == "tome"
    and ns.DB.DEFAULTS.folderSound == "submenu", "the folds' animation and sounds aren't Ikar's by default")
do
    local FT, UT, ease = ns.Windows.FOLD_TIME, ns.Windows.UNFOLD_TIME, ns.Windows.Ease
    local function seen(u)
        return ease(u)
    end
    local function risen(u)
        return 1 - ease(u)
    end
    expect(near(ease(1 / 3), 0.88) and near(ease(0.5), 0.955) and ease(0) == 0 and ease(1) == 1 and FT == 0.5
        and UT == 0.5, "the fold isn't a sheet's (iOS's curve, 0.5 s both ways): " .. ease(0.5))
    ns.db.options.foldAnim = true
    F.sounds = {}
    F.RunScript(cart, "OnClick", "LeftButton")
    expect(ns.db.options.chatFolded and ns.Windows.Animating() and ChatFrame1:GetAlpha() == 0
        and near(heightAt(100), openChatTop) and F.sounds[1] == 19972 and #F.sounds == 1,
        "folding, the chat doesn't go at once, its place left, the tome put away")
    run(ns.Windows.Step, nil, FT * 0.6)
    local halfway = heightAt(100)
    ringX, foot = cartFoot()
    expect(halfway and halfway < openChatTop - 20 and taken("ChatFrame1") and ChatFrame1:GetAlpha() == 0
        and near(foot, math.max(heightAt(ringX) - ns.Border.Hug(), Plate.last.T)) and cart.Icon.rotation == math.pi,
        "halfway, the chat's place doesn't come down with the cartouche on its top: " .. tostring(halfway))
    run(ns.Windows.Step, nil, FT * 0.4)
    local foldedTop = heightAt(100)
    expect(not ns.Windows.Animating() and not taken("ChatFrame1") and foldedTop < halfway,
        "the blind doesn't end with the chat off the plate")
    F.RunScript(cart, "OnClick", "LeftButton")
    expect(not ns.db.options.chatFolded and ns.Windows.Animating() and ChatFrame1:GetAlpha() == 0
        and near(heightAt(100), foldedTop) and cart.Icon.rotation == 0 and F.sounds[2] == 19971,
        "unfolding, the chat shows before its place rose, or the tome isn't drawn")
    run(ns.Windows.Step, nil, UT * 0.2)
    expect(heightAt(100) > foldedTop + 20 and heightAt(100) < openChatTop - 20 and ChatFrame1:GetAlpha() == 0,
        "unfolding, the chat's place doesn't rise first")
    run(ns.Windows.Step, nil, UT * 0.8)
    expect(not ns.Windows.Animating() and ChatFrame1:GetAlpha() == 1 and near(heightAt(100), openChatTop)
        and taken("ChatFrame1"), "unfolded, the chat doesn't show on its place")
    -- Clicked again halfway, it turns back from where it stands.
    F.RunScript(cart, "OnClick", "LeftButton")
    run(ns.Windows.Step, nil, FT * 0.6)
    local turned = heightAt(100)
    F.RunScript(cart, "OnClick", "LeftButton")
    expect(ns.Windows.Animating() and near(heightAt(100), turned), "clicked halfway, the fold jumps")
    run(ns.Windows.Step, nil, UT)
    expect(not ns.Windows.Animating() and ChatFrame1:GetAlpha() == 1 and near(heightAt(100), openChatTop),
        "turned back halfway, the chat isn't open again")
    -- The darkening blind (Ikar 2026-11-15, the accordion gone; the only one since 2026-11-18, the plain blind gone):
    -- its place a shade darker as it comes down, lighter as it rises, none at rest; from the plate's foot up, half dark
    -- at most (Ikar: "the bottom stays clear, and the inside darkens too much"). Its top sinks from the chat's top to
    -- under the plate's foot; nothing's left by the end.
    F.RunScript(cart, "OnClick", "LeftButton")
    run(ns.Windows.Step, nil, FT * 0.6)
    local half = Plate.last.shade
    run(ns.Windows.Step, nil, FT * 0.25)
    local top, margin = chat.y + chat.h, openChatTop - chat.y - chat.h
    local function placeAt(p)
        return math.max(top + (Plate.last.T - ns.Border.Hug() - top) * seen(p) + margin, foldedTop)
    end
    local sinking, darker = heightAt(100), Plate.last.shade
    run(ns.Windows.Step, nil, FT * 0.1)
    local ending = heightAt(100)
    run(ns.Windows.Step, nil, FT * 0.1)
    expect(Plate.FOLD_DARK == 0.5, "the blind's darkest isn't half dark (Ikar 2026-11-16: 50 %)")
    expect(near(half, seen(0.6)) and near(darker, seen(0.85))
        and Plate.last.shade == 0 and not taken("ChatFrame1"),
        "the darkening blind doesn't darken the chat's place as it comes down: " .. tostring(half) .. " " .. tostring(darker))
    expect(near(sinking, placeAt(0.85)) and near(ending, placeAt(0.95)),
        "the chat's place doesn't sink under the plate's foot as eased: " .. tostring(sinking) .. " " .. tostring(placeAt(0.85)))
    F.RunScript(cart, "OnClick", "LeftButton")
    run(ns.Windows.Step, nil, UT * 0.3)
    local rising, hiddenRising = Plate.last.shade, ChatFrame1:GetAlpha() == 0
    run(ns.Windows.Step, nil, UT * 0.4)
    expect(near(rising, risen(0.3)) and Plate.last.shade < rising and Plate.last.shade > 0,
        "unfolding, the chat's place doesn't grow lighter as it rises")
    -- risen 99 %, still slowing into place: the chat shows already
    expect(hiddenRising and ns.Windows.Animating() and risen(0.7) < ns.Windows.SHOW_AT and ChatFrame1:GetAlpha() == 1,
        "unfolding, the chat waits for the slow end of its place's rise")
    run(ns.Windows.Step, nil, UT * 0.3)
    -- Frame by frame, folding and unfolding near the plate's foot: the plate beside the chat's place never lifted up to
    -- it (Ikar 2026-11-16: the border next to it "snaps for a couple of frames"), its small steps drawn as they come.
    do
        local open = tops()
        F.RunScript(cart, "OnClick", "LeftButton")
        run(ns.Windows.Step, nil, FT)
        local folded = tops()
        local reach = ns.db.options.bridge + ns.Border.Hug() + 5
        local x0, x1 = chat.x - reach, chat.x + chat.w + reach
        local lifted
        local function watch()
            for x, top in pairs(open) do
                if (x < x0 or x > x1) and heightAt(x) > math.max(top, folded[x]) + 0.01 then
                    lifted = lifted or x
                end
            end
        end
        F.RunScript(cart, "OnClick", "LeftButton")
        for _ = 1, 40 do
            run(ns.Windows.Step, nil, UT / 40)
            watch()
        end
        F.RunScript(cart, "OnClick", "LeftButton")
        for _ = 1, 40 do
            run(ns.Windows.Step, nil, FT / 40)
            watch()
        end
        expect(not lifted and not ns.Windows.Animating(),
            "folding or unfolding near the foot, the plate beside the chat's place jumps up: at " .. tostring(lifted))
        F.RunScript(cart, "OnClick", "LeftButton")
        run(ns.Windows.Step, nil, UT)
    end
    F.RunScript(cart, "OnClick", "LeftButton")
    run(ns.Windows.Step, nil, FT)
    -- Edit Mode shows the folded chat at once; leaving it folds the chat again, animated.
    F.EnterEditMode()
    F.RunTimers()
    expect(not ns.Windows.Animating() and ChatFrame1:GetAlpha() == 1 and taken("ChatFrame1"),
        "in Edit Mode the folded chat isn't shown at once")
    F.ExitEditMode()
    F.RunTimers()
    expect(ns.Windows.Animating() and ChatFrame1:GetAlpha() == 0, "leaving Edit Mode, the chat doesn't fold animated")
    run(ns.Windows.Step, nil, UT)
    -- Typing unfolds it animated and silent: the tome only as clicked. With no animation, at once.
    local played = #F.sounds
    F.RunScript(ChatFrame1EditBox, "OnEditFocusGained")
    F.RunTimers()
    expect(ns.Windows.Animating() and #F.sounds == played, "typing, the folded chat doesn't unfold animated, silently")
    run(ns.Windows.Step, nil, UT)
    F.RunScript(ChatFrame1EditBox, "OnEditFocusLost")
    F.RunTimers()
    run(ns.Windows.Step, nil, UT)
    ns.db.options.foldAnim, ns.db.options.foldSound = false, "none"
    F.RunScript(cart, "OnClick", "LeftButton")
    expect(not ns.Windows.Animating() and not ns.db.options.chatFolded and ChatFrame1:GetAlpha() == 1
        and near(heightAt(100), openChatTop) and #F.sounds == played,
        "with no animation and no sound, the chat doesn't unfold at once, silently")
    ns.db.options.foldAnim, ns.db.options.foldSound = nil, nil
    ns.ApplyAll()
    expect(Plate.last.shade == 0 and taken("ChatFrame1"), "the open chat's place is darkened")
    -- What the HUD does by itself and what it sounds like isn't in the dialog any more, which keeps what is set while
    -- looking at it (Ikar 2026-11-19: "see options in the edit mode, should some go to the settings instead ?"): it is
    -- on the options' page under KaLi HUD's (its own block, far below). Which of the HUD's parts are on stays here, and
    -- is there too ("keep 4, but duplicate in the settings too"); the row that turned the minimap, the game's own
    -- setting, is nowhere ("drop the minimap"); the looks' row is « Style » ("yo ucan rename to style")
    local rowOf = {}
    for _, f in ipairs(KaLiHUDEditModeDialog.rows or {}) do
        if f.row.key then
            rowOf[f.row.key] = f
        end
    end
    local moved = 0
    for _, key in ipairs({ "foldAnim", "foldSound", "folderSound", "minimapAutoZoom", "rotateMinimap", "chatPeekOnType",
        "meterUnfoldCombat", "folderCombatClose", "hideExternalXP", "slotsLocked" }) do
        moved = moved + (rowOf[key] and 1 or 0)
    end
    expect(moved == 0 and rowOf.plate and rowOf.minimap and rowOf.windowFold and rowOf.infoBar,
        "a row of what the HUD does or sounds like is still in the dialog, or one of its parts' switches left it")
    expect(rowOf.preset and rowOf.preset.row.name == "Style", "the looks' row isn't named « Style »")
    -- Ikar 2026-11-15: the ring's none is « Blizzard classique », no automatic bar, the bars' and the info bar's size
    -- « Taille », the recess's shadow and light, the bags' folding and the info bar's three sizes no longer options.
    local ring = rowOf.minimapRing and rowOf.minimapRing.row.values or {}
    local kinds = rowOf.statusLeft and rowOf.statusLeft.row.values or {}
    expect(ring[3] and ring[3][1] == "none" and ring[3][2] == "Blizzard classique" and #kinds == 4
        and kinds[1][1] == "xp"
        and rowOf.statusLeftFontSize and rowOf.statusLeftFontSize.row.name == "Taille" and rowOf.infoSize
        and rowOf.infoSize.row.name == "Taille" and rowOf.infoSpacing and not (rowOf.recessShadow or rowOf.recessLight
            or rowOf.collapsibleBags or rowOf.infoHeight or rowOf.infoFontSize or rowOf.infoIconSize),
        "the dialog's rows aren't as Ikar asked on 2026-11-15")
    -- Ikar 2026-11-16: what was tried baked in or dropped, no DEV section left; the recesses' section gone, the
    -- pockets' marks with the map's.
    local ids = {}
    for _, s in ipairs(ns.EditPanel.Sections and ns.EditPanel.Sections() or {}) do
        ids[s.id] = true
    end
    expect(rowOf.pocketMarks and rowOf.pocketMarks.section.id == "minimap" and next(ids) and not (ids.dev or ids.recess
        or rowOf.slotRecess or rowOf.borderProfile or rowOf.borderPolish or rowOf.light or rowOf.innerShade
        or rowOf.innerLine or rowOf.emptySlotAlpha), "what was tried is still in the dialog, or the pockets' marks "
            .. "aren't with the map's rows")
    -- Ikar 2026-11-16: his rings after the plain three, under their themes' titles, each with its name.
    local rings, titled = 0, 0
    for i = 4, #ring do
        if ring[i].title then
            titled = titled + (ring[i].title == L["RING_THEME_" .. ns.MINIMAP_RING_THEMES[titled + 1][1]] and 1 or 0)
        elseif ns.MINIMAP_RINGS[ring[i][1]] and ring[i][2] == L["RING_" .. ring[i][1]] then
            rings = rings + 1
        end
    end
    expect(ring[4] and ring[4].title and titled == #ns.MINIMAP_RING_THEMES and rings == ns.Count(ns.MINIMAP_RINGS)
        and #ring == 3 + titled + rings, "the map's rings aren't listed under their themes: " .. #ring .. " values")
end

-- A corner limit holds outside Edit Mode (Ikar 2026-11-15): folding the chat sinks its own place, where the plate
-- changes for it alone, and the rest stands as it was, the stretches the limit merged included; unfolded, the plate is
-- as it was.
do
    ns.db.options.foldAnim = false
    F.EnterEditMode()
    ns.db.options.maxCorners = 6
    ns.ApplyAll()
    F.ExitEditMode()
    F.RunTimers()
    local limited = tops()
    ns.Windows.Toggle("ChatFrame1")
    local zone = chat.x + chat.w + ns.db.options.bridge + ns.Border.Hug()
    local outside, sank
    for x, top in pairs(limited) do
        if math.abs(heightAt(x) - top) > 0.01 then
            if x > zone then
                outside = x
            elseif heightAt(x) < top then
                sank = true
            end
        end
    end
    expect(sank and not outside, "folding the chat under a corner limit changes the plate away from it, at "
        .. tostring(outside))
    ns.Windows.Toggle("ChatFrame1")
    expect(not changedAt(limited), "unfolded under a corner limit, the plate isn't as it was")
    F.EnterEditMode()
    ns.db.options.maxCorners, ns.db.options.foldAnim = nil, nil
    ns.ApplyAll()
    F.ExitEditMode()
    F.RunTimers()
end

-- A pet called outside Edit Mode: the plate stands as frozen. Placed over the totem bar in Edit Mode, it's taken;
-- dismissed outside Edit Mode, its place stays, until Edit Mode reads the frames again.
do
    local was = tops()
    PetActionBar:Show()
    F.RunTimers()
    ns.ApplyAll()
    expect(not taken("PetActionBar") and not changedAt(was), "a pet bar shown outside Edit Mode changes the plate")
    place(PetActionBar, 560, 190)
    expect(taken("PetActionBar"), "a pet bar placed over the totem bar in Edit Mode isn't taken")
    PetActionBar:Hide()
    F.RunTimers()
    ns.ApplyAll()
    expect(taken("PetActionBar"), "a pet dismissed outside Edit Mode, its bar's place leaves the plate")
    F.EnterEditMode()
    F.RunTimers()
    expect(not taken("PetActionBar"), "in Edit Mode, a pet bar that doesn't show is still taken")
    F.ExitEditMode()
    F.RunTimers()
    expect(not taken("PetActionBar") and not changedAt(was), "frozen again, the plate isn't as it was")
end

-- The screen grows: the plate stays round the frames where they are.
UIParent:SetSize(2400, 1200)
F.Fire("DISPLAY_SIZE_CHANGED")
F.RunTimers()
expect(Plate.last.dome and near(Plate.last.dome.cx, 981 + 69.3), "the dome leaves the minimap when the screen changes")
expect(near(bars[-1].slot.x, 544.6 - ns.db.options.padBars), "the left status bar leaves the bars when the screen changes")
UIParent:SetSize(2100.5, 1181.5)
F.Fire("DISPLAY_SIZE_CHANGED")
F.RunTimers()

-- The plate never moves a frame.
for _, entry in ipairs(Frames.ACCEPTED) do
    local f = _G[entry[1]]
    expect(not f or f.point == nil, "the plate anchored " .. entry[1])
end

-- ---------- The unified slot hub & info bar ----------
local function click(name, button)
    F.RunScript(Buttons.Get(name), "OnClick", button)
    F.RunTimers()
end
click("KaLiHUD_Bags", "LeftButton")
expect(F.toggled.bags == 1, "clicking the bags doesn't open them")
-- One right-click (Ikar 2026-11-17: "Let's focus on having a consistent right click", the Ctrl+right-click gone): on
-- one of ours, its one menu, its own settings then where it goes, never KaLi HUD's options panel.
click("KaLiHUD_Clock", "RightButton")
expect(F.MenuItem(L.OPEN_CALENDAR) ~= nil and F.MenuItem(L.HUB_POSITION) ~= nil,
    "right-clicking the clock doesn't open its one menu, its settings and where it goes")
local item
-- The clock has no setting of its own for its hours nor for whose time it tells: the game's two, those of its clock's
-- window (the review of 2026-11-17, second round; Ikar: "Agreed"). Twelve hours and the realm's time while the game
-- says so, then twenty-four, then the local time.
do
    local function clock()
        ns.Items.Update()
        F.RunTimers()
        return tostring(Buttons.Get("KaLiHUD_Clock").Text:GetText())
    end
    local h, m = GetGameTime()
    F.cvars.timeMgrUseMilitaryTime, F.cvars.timeMgrUseLocalTime = "0", "0"
    local twelve = clock()
    F.cvars.timeMgrUseMilitaryTime = "1"
    local realm = clock()
    F.cvars.timeMgrUseLocalTime = "1"
    local before = date("%H:%M")
    local mine = clock()
    expect(twelve:find("[AP]M") and realm == string.format("%02d:%02d", h, m),
        "the clock doesn't follow the game's own hours, twelve or twenty-four: " .. twelve .. ", " .. realm)
    expect(mine == before or mine == date("%H:%M"),
        "the clock doesn't tell the local time when the game's own setting says so: " .. mine)
    expect(ns.DB.DEFAULTS.clock24 == nil and ns.DB.DEFAULTS.clockServer == nil and F.MenuItem(L.OPEN_CALENDAR) ~= nil,
        "the clock still has settings of its own for its hours")
    -- as the game comes for what follows: twelve hours, the realm's time
    F.cvars.timeMgrUseMilitaryTime, F.cvars.timeMgrUseLocalTime = "0", "0"
    clock()
end
-- Another addon's object keeps its own right-click while the padlock is shut, Ctrl or not: no menu of ours over it.
F.lastMenu = nil
click("Spoken", "RightButton")
F.ctrl = true
click("Spoken", "RightButton")
F.ctrl = false
expect(F.spokenClicks[1] == "RightButton" and #F.spokenClicks == 2 and F.lastMenu == nil,
    "right-clicking Spoken, the padlock shut, doesn't reach its own right-click, or opens a menu of ours")
-- Another addon's map button too: its frame's own scripts, nothing of ours hooked on them.
do
    F.lastMenu = nil
    local rawRight = #F.rawClicks
    F.Press(F.rawButton, "RightButton")
    expect(F.lastMenu == nil and #F.rawClicks == rawRight + 1 and F.rawClicks[#F.rawClicks] == "RightButton",
        "right-clicking another addon's map button, the padlock shut, doesn't reach its own right-click, or opens ours")
end

-- A Blizzard minimap widget has no right-click of its own (the tracking button and the compartment take the left
-- button alone, the calendar's right does what its left does): its right-click opens its hub menu, alone, the calendar
-- not opened, its left click still the calendar's; the tracking button, a DropdownButton, hears the right release too.
local calendars = F.toggled.calendar or 0
F.Press(GameTimeFrame, "RightButton")
F.RunTimers()
expect(F.MenuItem(L.HUB_POSITION) ~= nil and F.MenuItem(L.HUB_VISIBILITY) ~= nil,
    "right-clicking the minimap calendar button doesn't open its hub menu")
expect((F.toggled.calendar or 0) == calendars, "right-clicking the calendar button opens the calendar too")
F.Press(GameTimeFrame, "LeftButton")
expect((F.toggled.calendar or 0) == calendars + 1, "after a right-click, a left click no longer opens the calendar")
local tracking = MinimapCluster.Tracking.Button
F.lastMenu = nil
F.Press(tracking, "RightButton")
expect(F.MenuItem(L.HUB_POSITION) ~= nil and not tracking:IsMenuOpen(),
    "right-clicking the tracking button doesn't open its hub menu, or opens the tracking menu too")
F.Press(tracking, "LeftButton")
expect(tracking:IsMenuOpen(), "a left click no longer opens the tracking menu")
tracking:SetMenuOpen(false)
-- An element's tooltip ends with the hints, under its own: what its right-click opens when it's the hub menu (a
-- Blizzard widget's, a folder's, one of ours whose tooltip says nothing of its right-click; another addon's while
-- the padlock is open), and while open, that it drags.
-- What a hover shows: the game's tooltip's lines, or the attributes' card's, its foot's hints with them, while that's
-- what stands over the element (a field of the fake's, the session's own names being all taken: Lua's 200).
function F.hovered()
    if ns.StatCard.Owner() and ns.StatCard.Owner() == F.entered then
        return (ns.StatCard.Lines(true)), true
    end
    return F.tooltip.lines, F.tooltip.shown == true
end
local function hinted(unlocked)
    local hub, drag = false, false
    local lines, shown = F.hovered()
    for _, line in ipairs(lines) do
        hub = hub or line == L.HINT_HUB_MENU
        drag = drag or line == L.HINT_DRAG_SLOT
    end
    return shown and hub and drag == unlocked
end
local function has(text)
    for _, line in ipairs((F.hovered())) do
        if line == text then
            return true
        end
    end
    return false
end
F.RunScript(tracking, "OnEnter")
expect(hinted(false) and has("Suivi"), "the tracking button's tooltip hasn't the hints under its own")
F.RunScript(GameTimeFrame, "OnEnter")
F.RunScript(GameTimeFrame, "OnUpdate")
expect(hinted(false) and has("Cliquez pour afficher le calendrier."), "the calendar's tooltip loses the hints when it rebuilds")
F.RunScript(MinimapCluster.DielFrame, "OnEnter")
expect(hinted(false) and has(L.OPT_MM_DIEL), "the day/night cycle's tooltip hasn't its name and the hints")
F.RunScript(Buttons.Get("Spoken"), "OnEnter")
expect(has("Spoken") and not has(L.HINT_HUB_MENU), "an addon's launcher without a tooltip gets no name, or, the padlock "
    .. "shut, a hint of a right-click that is its own")
F.RunScript(Buttons.Get("KaLiHUD_Clock"), "OnEnter")
expect(has(L.HINT_CLOCK) and not has(L.HINT_HUB_MENU), "the clock's tooltip names its right-click twice")
F.RunScript(Buttons.Get("KaLiHUD_Attr_STRENGTH"), "OnEnter")
expect(hinted(false), "an attribute's tooltip doesn't say what its right-click opens")
F.RunScript(Buttons.Get("KaLiHUD_Attr_STRENGTH"), "OnLeave")
-- The zone is no element: no hub menu, no hints, never dragged.
F.lastMenu = nil
click("KaLiHUD_Location", "RightButton")
F.RunScript(Buttons.Get("KaLiHUD_Location"), "OnEnter")
expect(F.lastMenu == nil and not has(L.HINT_HUB_MENU), "the zone offers a hub menu")
-- Each tooltip says what kind of element it is (Ikar 2026-11-17: "add a type field, can you propose names for each?"):
-- ours an information, the zone too; another addon's object its launcher or its information; Blizzard's widget; a
-- folder, one KaLi HUD brought too, with no « (KaLi HUD) » (Ikar 2026-11-17: "remove the (kali hud) from type").
do
    local function typed(name, kind)
        F.RunScript(Buttons.Get(name), "OnEnter")
        local found = has(string.format(L.TYPE_LINE, kind))
        F.RunScript(Buttons.Get(name), "OnLeave")
        return found
    end
    expect(typed("KaLiHUD_Attr_STRENGTH", L.TYPE_OURS) and typed("KaLiHUD_Location", L.TYPE_OURS)
        and typed("Spoken", L.TYPE_LAUNCHER) and typed("Libs Error Display", L.TYPE_ADDON_INFO)
        and typed(ns.Folders.ByRole("stats"), L.TYPE_LOCKED_FOLDER) and typed(ns.Folders.Default(), L.TYPE_FOLDER),
        "an element's tooltip doesn't say what kind it is")
    F.RunScript(tracking, "OnEnter")
    expect(has(string.format(L.TYPE_LINE, L.TYPE_NATIVE)), "a Blizzard widget's tooltip doesn't say what kind it is")
end
-- Every element deletable (Ikar 2026-11-17: "make all components deletable"): one that isn't ours to destroy, ours,
-- another addon's or Blizzard's, taken off the HUD from its menu, the bar's menu putting it back where it was; undone
-- too. A folder's and a macro's deletion stay their own (it asks first, what they hold goes with them).
do
    local perf = "KaLiHUD_Performance"
    local was = Hub.Entry(perf).side
    click(perf, "RightButton")
    item = F.MenuItem(L.ITEM_REMOVE)
    if item then
        run(item.choose)
        F.RunTimers()
    end
    expect(item and Hub.Entry(perf).side == "hidden" and not Buttons.Get(perf):IsShown(),
        "one of ours isn't taken off the HUD from its menu")
    ns.History.Undo()
    F.RunTimers()
    expect(Hub.Entry(perf).side == was and Buttons.Get(perf):IsShown(), "a deletion undone doesn't put it back")
    F.lastMenu = nil
    F.Press(GameTimeFrame, "RightButton")
    F.RunTimers()
    expect(F.MenuItem(L.ITEM_REMOVE) ~= nil and F.MenuItem(ns.G("DELETE", "Supprimer")) == nil,
        "a Blizzard widget's menu doesn't take it off the HUD, or says it deletes it")
    -- A folder KaLi HUD made only taken off the HUD, what it holds with it, the bar's menu showing it again where it
    -- was (Ikar 2026-11-20: "built in folder, when deleted, shoudl only be deselected, otherwise, they are
    -- unrecoverable"); one of the player's still deleted, asked first (below).
    do
        local stats = ns.Folders.ByRole("stats")
        local where, held = Hub.Entry(stats).side, #Hub.InFolder(stats)
        F.lastMenu = nil
        click(stats, "RightButton")
        local remove = F.MenuItem(L.ITEM_REMOVE)
        expect(F.lastMenu and remove and F.MenuItem(L.FOLDER_DELETE) == nil,
            "a folder KaLi HUD made is deleted from its menu rather than taken off the HUD")
        if remove then
            run(remove.choose)
            F.RunTimers()
        end
        expect(ns.Folders.Get(stats) and Hub.Entry(stats).side == "hidden" and #Hub.InFolder(stats) == held and held > 0
            and not Buttons.Get(stats):IsShown(), "a folder KaLi HUD made, taken off the HUD, is gone or emptied")
        F.lastMenu = nil
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        local back = F.MenuItem(Hub.Label(stats, Hub.Entry(stats).obj), F.MenuItem(L.CAT_folders))
        if back then
            run(back.choose)
            F.RunTimers()
        end
        expect(back and Hub.Entry(stats).side == where and #Hub.InFolder(stats) == held and Buttons.Get(stats):IsShown(),
            "a folder KaLi HUD made isn't shown again from the bar's menu where it was, with what it held")
    end
    -- A locked one not there (deleted as an earlier build let it be; Ikar 2026-11-20: "and I still don't see how to
    -- bring back my emote folder"): made again as made at the next login (UI/Hub/Seeds.lua's Sync), its emotes in it,
    -- once, its box in the bar's menu ticked
    do
        local emotes = ns.Folders.ByRole("emotes")
        local name, held = ns.Folders.Get(emotes).name, #Hub.InFolder(emotes)
        ns.Folders.Delete(emotes)
        F.RunTimers()
        ns.Seeds.Run()
        F.RunTimers()
        local again = ns.Folders.ByRole("emotes")
        F.lastMenu = nil
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        local listed = 0
        for _, e in ipairs((F.MenuItem(L.CAT_folders) or { items = {} }).items) do
            listed = listed + (e.text == name and 1 or 0)
        end
        -- (« Suite » not offered before it was ever made)
        local suite = F.MenuItem(L.FOLDER_OVERFLOW, F.MenuItem(L.CAT_folders))
        expect(not suite == not (ns.db.seeds.overflow and not ns.Folders.ByRole("overflow")),
            "« Suite » is offered to make again though it was never made, or not though it was")
        expect(again and #Hub.InFolder(again) == held
            and held > 0 and Buttons.Get(again):IsShown() and listed == 1,
            "a locked folder not there isn't made again as made at the next login")
        -- « Add-ons » renamed, the player's (its role gone): unticked among the folders, by its name; ticked, made
        -- again as made, one action to undo
        local old = ns.Folders.ByRole("addons")
        local of = old and ns.Folders.Get(old)
        local oldName = of and of.name
        if of then
            of.role, of.name = nil, "Essai add-ons"
            Hub.Changed()
            F.RunTimers()
        end
        F.lastMenu = nil
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        local box = F.MenuItem(L.FOLDER_ADDONS, F.MenuItem(L.CAT_folders))
        local unticked = box and box.kind == "checkbox" and not box.isSelected()
        if box then
            run(box.choose)
            F.RunTimers()
        end
        local made = ns.Folders.ByRole("addons")
        expect(of and unticked and made and made ~= old, "« Add-ons » renamed isn't offered to make again, or isn't made")
        if made and made ~= old then
            ns.History.Undo()
            F.RunTimers()
        end
        if of then
            of.role, of.name = "addons", oldName
            Hub.Changed()
            F.RunTimers()
        end
        expect(ns.Folders.ByRole("addons") == old and not ns.Folders.Get(made or ""), "setup: « Add-ons » as it was")
    end
end
local NATIVE = ns.Natives.NAME
expect(Hub.IsLocked() == true and not Drag.Begin("KaLiHUD_Gold"), "slots drag while locked")
expect(not (Buttons.Handle(NATIVE.MAIL) and Buttons.Handle(NATIVE.MAIL):IsShown()), "a widget's handle shows while locked")
-- The padlock's block (Ikar 2026-11-20: "go for bloc"): the border's metal shut, lit from the top (its middle a darker
-- shade of it), with no aura.
do
    -- in a block: the main chunk is at Lua 5.1's 200 locals
    local lock = InfoBar.lockButton
    local t, c = lock.tint, lock.Lower.gradient and lock.Lower.gradient[3]
    local r, g, b = ns.Border.Color()
    expect(near(t[1], r) and near(t[2], g) and near(t[3], b) and c and c.r < r and near(c.r / r, c.g / g)
        and near(c.g / g, c.b / b) and not lock.Aura:IsShown(), "shut, the padlock's block isn't the border's metal lit from the top, or has an aura")
    -- its tooltip: its state, what it allows, its clicks at its foot (the review of 2026-11-20: shut, it read
    -- « Verrouiller les emplacements », and open still said to unlock)
    F.RunScript(lock, "OnEnter")
    expect(F.tooltip.lines[1] == L.SLOTS_LOCKED_STATE and has(L.SLOTS_SHUT_TIP) and has(L.HINT_UNLOCK)
        and not has(L.SLOTS_OPEN_TIP), "shut, the padlock's tooltip doesn't say it's locked and how to unlock it")
    F.RunScript(lock, "OnLeave")
end
F.RunScript(InfoBar.lockButton, "OnClick", "LeftButton")
F.RunTimers()
expect(Hub.IsLocked() == false, "clicking the far-right lock icon didn't unlock the slots")
-- Open, the padlock says so (Ikar 2026-11-17: "when unlocked, it should be gold background, clearly visible. Maybe with
-- a small aura around?"): its block in the game's gold, an aura round it come once, still while hovered.
do
    local r, g, b = 1, 0.82, 0
    if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.GetRGB then
        r, g, b = NORMAL_FONT_COLOR:GetRGB()
    end
    F.RunScript(InfoBar.lockButton, "OnEnter")
    expect(F.tooltip.lines[1] == L.SLOTS_UNLOCKED and has(L.SLOTS_OPEN_TIP) and has(L.HINT_LOCK)
        and not has(L.SLOTS_SHUT_TIP), "open, the padlock's tooltip doesn't say it's unlocked and how to lock it")
    F.RunScript(InfoBar.lockButton, "OnLeave")
    local t, c = InfoBar.lockButton.tint, (InfoBar.lockButton.Lower.gradient or {})[3] or {}
    expect(near(t[1], r) and near(t[2], g) and near(t[3], b) and near(c.r, r) and near(c.g, g) and near(c.b, b)
        and InfoBar.lockButton.Aura:IsShown() and InfoBar.lockButton.AuraIn.plays == 1,
        "unlocked, the padlock's block isn't gold, or its aura isn't there, come once")
end
for _, key in ipairs({ "TRACKING", "MAIL", "CALENDAR", "COMPARTMENT", "DIEL" }) do
    local h = Buttons.Handle(NATIVE[key])
    expect(h and h:IsShown(), "unlocked, the " .. key .. " widget has no handle to drag it by")
end
F.RunScript(Buttons.Get("KaLiHUD_Gold"), "OnEnter")
expect(has(L.HINT_DRAG_SLOT) and has(L.HINT_GOLD), "unlocked, the gold's tooltip doesn't say it drags")
-- The type the tooltip's last line, alone; the buttons' hints before it one after another, the left's before the
-- right's (Ikar 2026-11-17: "make type last, currently they are randomly between button, make sure bouttons always
-- come one after another, same order, left then right"); padlock open, then shut, then open again. No type
-- says « (KaLi HUD) ».
run(function()
    local TYPE = L.TYPE_LINE:gsub("%%s.*$", "")
    local ICON = "|A:housing-hotkey-icon-"
    local function ordered(what, buttons)
        -- (an attribute's are its card's, its foot's hints after its texts)
        local lines, shown = F.hovered()
        local first, last, types = nil, nil, 0
        for i, line in ipairs(lines) do
            if line:find(ICON, 1, true) then
                first, last = first or i, i
            end
            types = types + (line:sub(1, #TYPE) == TYPE and 1 or 0)
        end
        local together = true
        for i = first or 1, last or 0 do
            together = together and lines[i]:find(ICON, 1, true) ~= nil
        end
        local text = table.concat(lines, "\n")
        expect(shown and types == 1 and lines[#lines]:sub(1, #TYPE) == TYPE and together
            and (buttons == nil or (first ~= nil) == buttons) and not text:find("rightclick.-leftclick"),
            what .. "'s tooltip: its type isn't its last line, or its buttons' hints aren't together, left then right: "
            .. text:gsub("|A:housing%-hotkey%-icon%-(%a+):16:16|a", "[%1]"))
    end
    for _, locked in ipairs({ false, true }) do
        Hub.SetLocked(locked)
        for _, name in ipairs({ "KaLiHUD_Clock", "KaLiHUD_Bags", "KaLiHUD_Attr_STRENGTH", "KaLiHUD_Gold" }) do
            F.RunScript(Buttons.Get(name), "OnEnter")
            ordered(name, true)
        end
        -- another addon's launcher: its right-click its own while shut, no hint of ours then
        F.RunScript(Buttons.Get("Spoken"), "OnEnter")
        ordered("Spoken", not locked)
        F.RunScript(tracking, "OnEnter")
        ordered("the tracking button", true)
        F.RunScript(GameTimeFrame, "OnEnter")
        F.RunScript(GameTimeFrame, "OnUpdate")
        ordered("the calendar button", true)
        F.RunScript(Buttons.Get(ns.Folders.ByRole("stats")), "OnEnter")
        ordered("a folder", nil)
    end
    Hub.SetLocked(false)
    GameTooltip:Hide()
    for _, locale in ipairs({ "frFR", "enUS", "deDE", "esES", "esMX" }) do
        for key, text in pairs(ns.StringsFor(locale)) do
            expect(not (key:find("^TYPE_") and tostring(text):find("KaLi HUD", 1, true)),
                locale .. " " .. key .. " says « KaLi HUD »: " .. tostring(text))
        end
    end
end)
-- Open, the HUD arranged as in Edit Mode: another addon's object's right-click is the hub menu, its own not reached;
-- its tooltip says so. Shut again, its own again.
F.RunScript(Buttons.Get("Spoken"), "OnEnter")
expect(hinted(true), "unlocked, another addon's launcher's tooltip doesn't say its right-click opens the hub menu")
do
    local spokenAt = #F.spokenClicks
    F.lastMenu = nil
    click("Spoken", "RightButton")
    expect(F.MenuItem(L.HUB_POSITION) ~= nil and #F.spokenClicks == spokenAt,
        "unlocked, right-clicking another addon's launcher doesn't open its hub menu, or reaches its own right-click")
end
expect(not Drag.Begin("KaLiHUD_Location"), "the zone is dragged")
local trackHandle = Buttons.Handle(NATIVE.TRACKING)
F.RunScript(trackHandle, "OnEnter")
expect(hinted(true) and has(L.OPT_MM_TRACKING), "the tracking button's handle hasn't the same hints")
-- A left click on a DropdownButton's handle toggles its menu, as Blizzard's own proxy button does; the calendar's
-- handle clicks the calendar.
expect(trackHandle:HandlesGlobalMouseEvent("LeftButton", "GLOBAL_MOUSE_DOWN")
    and not Buttons.Handle(NATIVE.MAIL):HandlesGlobalMouseEvent("LeftButton", "GLOBAL_MOUSE_DOWN"),
    "a press on the tracking handle would close the tracking menu before its click toggles it")
F.RunScript(trackHandle, "OnClick", "LeftButton")
expect(tracking:IsMenuOpen(), "clicking the tracking button's handle doesn't open the tracking menu")
F.RunScript(trackHandle, "OnClick", "LeftButton")
expect(not tracking:IsMenuOpen(), "clicking the tracking button's handle again doesn't close the tracking menu")
calendars = F.toggled.calendar or 0
F.RunScript(Buttons.Handle(NATIVE.CALENDAR), "OnClick", "LeftButton")
expect((F.toggled.calendar or 0) == calendars + 1, "clicking the calendar's handle doesn't open the calendar")
-- Gold follows the pointer while dragged, the marker on the ring where it would land, and drops there.
F.cursorX, F.cursorY = 1050, 195
expect(Drag.Begin("KaLiHUD_Gold") == true, "unlocked slot didn't start dragging")
local goldAt = { Buttons.Get("KaLiHUD_Gold"):GetPoint() }
expect(goldAt[1] == "CENTER" and near(goldAt[4], 1050) and near(goldAt[5], 195), "the item dragged doesn't follow the pointer")
local target = Drag.Target(1050, 195)
expect(target and target.side == "ring" and target.kind == "slot", "the ring isn't marked where the item would land")
-- The ring lit but its bottom arc, which takes nothing: it stops half a slot above the info bar.
do
    local lit
    for _, f in ipairs(F.frames) do
        if f.Ring and f.Pockets and f.Ends then
            lit = f.Ring
        end
    end
    local top = lit and select(5, lit:GetPoint())
    expect(top and lit:IsShown() and near(top - lit:GetHeight(), InfoBar.Top() + 13),
        "the ring's bottom arc lights up while dragging: " .. tostring(top and top - lit:GetHeight()))
end
-- no button's light under the pointer meanwhile, the marker alone (Ikar 2026-11-19: "the position hight only when you
-- hover on top of a texte, not the whole line"); after, as before
do -- never left out: the drop the checks after it stand on (run_tests.py's smoke_session)
    local lightOf = Buttons.Get("KaLiHUD_Clock").Highlight
    expect(lightOf:GetAlpha() == 0, "a button lights up under the pointer while something is dragged")
    Drag.Finish()
    F.RunTimers()
    expect(lightOf:GetAlpha() == 1, "the buttons don't light up again after a drag")
end
expect(ns.db.items.KaLiHUD_Gold and ns.db.items.KaLiHUD_Gold.side == "ring",
    "dropping Gold onto the minimap ring didn't place it on the ring: " .. tostring(ns.db.items.KaLiHUD_Gold and ns.db.items.KaLiHUD_Gold.side))
-- The ring's bottom arc is the zone's: nothing lands there.
do
    local d = Plate.last.dome
    local below = Drag.Target(d.cx, d.cy - d.ring - 8)
    expect(not (below and below.side == "ring"), "an item lands on the ring's bottom arc, over the zone")
end
-- Dropped on any of the left pocket's places it stands there, free places before it or not (Ikar 2026-11-16: "you
-- cannot choose freely one of the 3 spots, you have to fill them one by one"); dropped on the tracking button's, they
-- change places; « Aller à droite » takes it to the next place right, the tracking button to its own.
local dome = Plate.last.dome
local spots = Hub.PocketSpots(dome, InfoBar.Top()).pocketLeft
local function pocketHolds()
    local _, _, t = Hub.Pockets(dome, InfoBar.Top())
    return t.pocketLeft
end
local function dropGold(i)
    local x, y = Hub.PocketPoint(dome, spots, "pocketLeft", i)
    F.cursorX, F.cursorY = x, y
    Drag.Begin("KaLiHUD_Gold")
    Drag.Finish()
    F.RunTimers()
    local at = { Buttons.Get("KaLiHUD_Gold"):GetPoint() }
    return near(at[4], x) and near(at[5], y)
end
expect(#spots == 3 or #spots == 6, "a pocket has " .. #spots .. " places")
expect(pocketHolds()[1] == NATIVE.TRACKING, "the tracking button isn't in the left pocket's first place")
if spots[3] then
    local there = dropGold(3)
    local holds = pocketHolds()
    expect(there and ns.db.items.KaLiHUD_Gold.side == "pocketLeft" and holds[3] == "KaLiHUD_Gold" and holds[2] == nil
        and holds[1] == NATIVE.TRACKING, "Gold dropped on the left pocket's third place, the second free, isn't there")
    there = dropGold(1)
    holds = pocketHolds()
    expect(there and holds[1] == "KaLiHUD_Gold" and holds[3] == NATIVE.TRACKING,
        "Gold dropped on the tracking button's place doesn't change places with it")
    -- the corner is the left pocket's leftmost: right of it on the floor, the third place
    run(Hub.Step, "KaLiHUD_Gold", 1)
    F.RunTimers()
    holds = pocketHolds()
    expect(holds[3] == "KaLiHUD_Gold" and holds[1] == NATIVE.TRACKING,
        "going right in the pocket doesn't take Gold to the next place right")
    Hub.Reset(NATIVE.TRACKING)
    F.RunTimers()
end
-- Nothing lands on the zone's block under the map: it's reserved.
expect(Drag.Target(dome.cx, 10) == nil, "an item lands on the zone's block")
-- Dropped at the bar's far right, it's the rightmost item.
F.cursorX, F.cursorY = UIParent:GetWidth() - 33, 10
Drag.Begin("KaLiHUD_Gold")
Drag.Finish()
F.RunTimers()
local function sideList(side)
    local list = {}
    for _, e in ipairs(Hub.Entries()) do
        if e.side == side then
            list[#list + 1] = e.name
        end
    end
    return list
end
expect(sideList("right")[1] == "KaLiHUD_Gold", "Gold dropped at the far right isn't the rightmost item: " .. table.concat(sideList("right"), ","))
-- « Aller à gauche » from its menu: past its left neighbour.
click("KaLiHUD_Gold", "RightButton")
item = F.MenuItem(L.GO_LEFT)
if item then
    run(item.choose)
    F.RunTimers()
end
expect(sideList("right")[2] == "KaLiHUD_Gold", "going left doesn't take Gold past its neighbour: " .. table.concat(sideList("right"), ","))
-- The first item below the minimap, going left, goes past the last on the bar's left, to its left.
local firstCentre, lastLeft = sideList("centre")[1], sideList("left")[#sideList("left")]
run(Hub.Step, firstCentre, -1)
F.RunTimers()
local lefts = sideList("left")
expect(lefts[#lefts] == lastLeft and lefts[#lefts - 1] == firstCentre,
    "going left from below the minimap doesn't cross to the bar's left: " .. table.concat(lefts, ","))
ns.db.items[firstCentre] = nil
Hub.Changed()
F.RunTimers()
-- A pocket's elements past the places that fit at this size (Ikar 2026-11-16: "when there is 3 and the size becomes
-- too big ... they should be put into the bottom bar, or if no space, removed altogether"): on the bar beside the block
-- below the map, on their pocket's side; with the bar off, or no room left on it, nowhere. Dropped on a full pocket's
-- place, an element takes it and the last goes down.
do
    Hub.Insert("KaLiHUD_Gold", "pocketRight")
    Hub.Insert(NATIVE.CALENDAR, "pocketRight")
    F.RunTimers()
    local list = sideList("pocketRight")
    local function placesNow()
        return #Hub.PocketSpots(ns.Minimap.Dome(), InfoBar.Top()).pocketRight
    end
    expect(#list >= 3 and placesNow() >= #list and not InfoBar.Placed("KaLiHUD_Gold")
        and Buttons.Get("KaLiHUD_Gold"):GetParent() == UIParent, "the right pocket doesn't hold three at the default size")
    ns.db.options.infoSize = 20
    run(ns.ApplyAll)
    F.RunTimers()
    local d, fit = ns.Minimap.Dome(), placesNow()
    local zone
    for _, e in ipairs(Hub.Entries()) do
        if Hub.IsFixed(e.name) then
            zone = InfoBar.Placed(e.name)
        end
    end
    expect(fit < #list and zone, "at size 20 the right pocket still holds " .. fit .. " of " .. #list)
    local x = zone and zone.x or 0
    for i, name in ipairs(list) do
        local p = InfoBar.Placed(name)
        if i <= fit then
            expect(not p, name .. " fits in its pocket but stands on the bar")
        else
            expect(p and p.x > x and p.x - p.w / 2 >= x + 0.01, name .. " past its pocket's places isn't on the bar right of the zone")
            x = p and p.x or x
        end
    end
    local cal = InfoBar.Placed(NATIVE.CALENDAR)
    local calX = cal and select(4, GameTimeFrame:GetPoint()) * GameTimeFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    expect(cal and GameTimeFrame:GetAlpha() > 0 and near(calX, cal.x), "the calendar past its pocket's places isn't drawn on the bar")
    -- no room left on the bar: they go
    local spacing = Hub.Spacing
    Hub.Spacing = function()
        return 400
    end
    run(ns.ApplyAll)
    F.RunTimers()
    local gone = GameTimeFrame:GetAlpha() == 0 and zone ~= nil
    for i = fit + 1, #list do
        gone = gone and not InfoBar.Placed(list[i])
    end
    expect(gone, "with no room left on the bar, what didn't fit in the pocket still stands on it")
    -- So little room that the bar's own items don't fit either: the folder for what doesn't fit is made then, the first
    -- time (the review of 2026-11-17; Ikar: "Maybe a special folder ?"), at the bar's right end by the padlock, one of
    -- those KaLi HUD brings; the bar's folders stay on it.
    do
        local over = ns.Folders.Overflow()
        local f = over and ns.Folders.Get(over)
        local kept = true
        for _, e in ipairs(Hub.Side("left")) do
            kept = kept and (not e.isFolder or InfoBar.Placed(e.name) ~= nil)
        end
        -- the zone too, which is no element to put away
        for _, e in ipairs(Hub.Entries()) do
            if Hub.IsFixed(e.name) then
                kept = kept and InfoBar.Placed(e.name) ~= nil
            end
        end
        expect(over and f.role == "overflow" and f.name == L.FOLDER_OVERFLOW and f.overflow == true
            and ns.db.seeds.overflow == true and Hub.Side("right")[1].name == over
            and ns.HubMenus.TypeOf(over) == L.TYPE_FOLDER and InfoBar.Placed(over) ~= nil,
            "the first time something doesn't fit on the bar, the folder for it isn't made at its right end: " .. tostring(over))
        expect(ns.Count(InfoBar.Unfitted()) > 0 and InfoBar.Unfitted().KaLiHUD_Bags == over and kept,
            "with no room on the bar, its own items stay on it, or a folder or the zone leaves it")
    end
    Hub.Spacing = spacing
    -- the bar off: the pocket comes down to the screen's foot, what still doesn't fit shows nowhere
    ns.db.options.infoBar = false
    run(ns.ApplyAll)
    F.RunTimers()
    local fitOff, nowhere = placesNow(), true
    for i = fitOff + 1, #list do
        local name = list[i]
        if name == "KaLiHUD_Gold" then
            nowhere = nowhere and not Buttons.Get(name):IsShown()
        elseif name == NATIVE.CALENDAR then
            nowhere = nowhere and GameTimeFrame:GetAlpha() == 0
        end
        nowhere = nowhere and not InfoBar.Placed(name)
    end
    expect(fitOff < #list and nowhere, "with the bar off, what didn't fit in the pocket still shows: " .. fitOff)
    ns.db.options.infoBar, ns.db.options.infoSize = nil, nil
    run(ns.ApplyAll)
    F.RunTimers()
    expect(not InfoBar.Placed("KaLiHUD_Gold") and Buttons.Get("KaLiHUD_Gold"):IsShown()
        and Buttons.Get("KaLiHUD_Gold"):GetParent() == UIParent and not InfoBar.Placed(NATIVE.CALENDAR),
        "back at the default size, the pocket's elements aren't back in it")
    Hub.Reset("KaLiHUD_Gold")
    Hub.Reset(NATIVE.CALENDAR)
    F.RunTimers()
end
-- A Blizzard widget goes by its handle: its right-click opens its menu, dragged it goes with the handle to the bar's
-- left end, which keeps it there.
local mailHandle = Buttons.Handle(NATIVE.MAIL)
-- the menu its click opens, not one left from before
F.lastMenu = nil
F.RunScript(mailHandle, "OnClick", "RightButton")
expect(F.MenuItem(L.HUB_POSITION) ~= nil, "right-clicking the mail's handle doesn't open its hub menu")
F.cursorX, F.cursorY = 20, 10
F.RunScript(mailHandle, "OnDragStart")
expect(near(select(4, mailHandle:GetPoint()), 20), "the mail's handle doesn't follow the pointer")
F.RunScript(mailHandle, "OnDragStop")
F.RunTimers()
expect(ns.db.items[NATIVE.MAIL] and ns.db.items[NATIVE.MAIL].side == "left", "dragging the mail's handle to the bar didn't move the mail")
-- Gold dropped in the middle of the bar stays where it was dropped; at its left end, it goes first on the left.
F.cursorX, F.cursorY = 1300, 10
Drag.Begin("KaLiHUD_Gold")
Drag.Finish()
F.RunTimers()
expect(ns.db.items.KaLiHUD_Gold.side == "free" and near(Buttons.Get("KaLiHUD_Gold").ux, 1300),
    "Gold dropped mid-bar isn't where it was dropped: " .. tostring(Buttons.Get("KaLiHUD_Gold").ux))
F.cursorX, F.cursorY = 15, 10
Drag.Begin("KaLiHUD_Gold")
Drag.Finish()
F.RunTimers()
expect(ns.db.items.KaLiHUD_Gold and ns.db.items.KaLiHUD_Gold.side == "left" and sideList("left")[1] == "KaLiHUD_Gold",
    "dropping Gold at the bar's left end didn't put it first on the left")
-- The mail dropped mid-bar by its handle stays where it was dropped, as ours do (its point in its own, scaled units).
F.cursorX, F.cursorY = 1300, 10
F.RunScript(mailHandle, "OnDragStart")
F.RunScript(mailHandle, "OnDragStop")
F.RunTimers()
local mailX = select(4, MinimapCluster.IndicatorFrame:GetPoint()) * MinimapCluster.IndicatorFrame:GetEffectiveScale()
    / UIParent:GetEffectiveScale()
expect(ns.db.items[NATIVE.MAIL] and ns.db.items[NATIVE.MAIL].side == "free"
    and near(mailX, 1300) and near(select(4, mailHandle:GetPoint()), 1300),
    "the mail dropped mid-bar isn't where it was dropped: " .. tostring(mailX))
-- On the bar, Blizzard's widgets keep their own size, as round the map: their art at the icons' size.
Hub.Insert(NATIVE.TRACKING, "left")
F.RunTimers()
expect(Hub.Entry(NATIVE.TRACKING).side == "left" and MinimapCluster.Tracking:GetWidth() == 23
    and near(MinimapCluster.Tracking:GetScale() * 22, Hub.IconSize()),
    "on the bar, the tracking button isn't at its own size: " .. MinimapCluster.Tracking:GetWidth())
Hub.Reset(NATIVE.TRACKING)
F.RunTimers()
ns.db.items[NATIVE.MAIL] = nil
-- Dropped a little past the bar's left items, Gold joins them, last.
Hub.Changed()
F.RunTimers()
do
    local lefts = sideList("left")
    local last = Buttons.Get(lefts[#lefts])
    F.cursorX, F.cursorY = last.ux + last:GetWidth() / 2 + 30, 10
    Drag.Begin("KaLiHUD_Gold")
    Drag.Finish()
    F.RunTimers()
    lefts = sideList("left")
    expect(lefts[#lefts] == "KaLiHUD_Gold", "Gold dropped just past the bar's left items doesn't join them: " .. table.concat(lefts, ","))
end
for _, key in ipairs({ "TRACKING", "MAIL", "CALENDAR", "COMPARTMENT", "DIEL" }) do
    expect(Hub.Native(NATIVE[key]).show == "always", "the " .. key .. " widget isn't always shown by default")
end
F.RunScript(InfoBar.lockButton, "OnClick", "LeftButton")
F.RunTimers()
expect(Hub.IsLocked() == true, "clicking the lock icon again didn't re-lock the slots")
expect(not mailHandle:IsShown(), "the handles stay once locked")
do
    -- in a block: the main chunk is at Lua 5.1's 200 locals
    local lock = InfoBar.lockButton
    local t, c = lock.tint, lock.Lower.gradient and lock.Lower.gradient[3]
    local r, g, b = ns.Border.Color()
    expect(near(t[1], r) and near(t[2], g) and near(t[3], b) and c and c.r < r and near(c.r / r, c.g / g)
        and near(c.g / g, c.b / b) and not lock.Aura:IsShown(), "locked again, the padlock's block stays gold, or its aura stays")
end
-- Shut again, another addon's object's right-click is its own again.
do
    local spokenNow = #F.spokenClicks
    F.lastMenu = nil
    click("Spoken", "RightButton")
    expect(#F.spokenClicks == spokenNow + 1 and F.lastMenu == nil,
        "locked again, right-clicking another addon's launcher doesn't reach its own right-click")
end

-- ---------- Folders ----------
-- One made at the first run, "Add-ons", at the bar's right end: other addons' launchers land in it (their data sources
-- too since 2026-11-17: the one put on the bar above stays there); LibDBIcon's copy of a launcher is put away; another addon's own map button is taken in, a
-- numbered pin isn't.
do
    local Folders = ns.Folders
    local addons = Folders.Default()
    local function inFolder(name, id)
        local e = Hub.Entry(name)
        return e ~= nil and e.side == "folder" and e.folder == id
    end
    expect(addons and Folders.Get(addons).name == L.FOLDER_ADDONS and Hub.Entry(addons).side == "right"
        and Buttons.Get(addons):IsShown(), "no Add-ons folder on the bar at the first run")
    local list = Folders.Panel(addons)
    expect(inFolder("Spoken", addons) and list and Buttons.Get("Spoken"):GetParent() == list and not list:IsShown(),
        "another addon's launcher isn't in the Add-ons folder, shut")
    expect(Hub.Entry("Libs Error Display").side == "right", "another addon's data source left the bar")
    expect(F.dbiButton:GetParent() ~= Minimap and not F.dbiButton:GetParent():IsShown(),
        "LibDBIcon's copy of a launcher stays on the map")
    local raw, rawName = F.rawButton, "AutoBiographerMinimapButton"
    expect(inFolder(rawName, addons) and Hub.Entry("HandyNotesPin12") == nil,
        "another addon's map button isn't taken into the folder, or a pin is")
    expect(Hub.Label(rawName) == "AutoBiographer", "a map button's name isn't readable")
    expect(inFolder("KaLi Recipe", addons) and Hub.Entry("KaLiRecipeMinimapButton") == nil
        and F.recipeButton:GetParent() ~= Minimap and not F.recipeButton:GetParent():IsShown(),
        "an addon's map button shows besides its LDB object of the same name")
    -- A click opens its list above it, flush with its right side: the launcher in it, the map button's icon at the icon
    -- size, on nothing, over the list though its strata is fixed, taking the clicks on its icon only.
    F.sounds = {}
    click(addons, "LeftButton")
    local fb = Buttons.Get(addons)
    expect(Folders.IsOpen(addons) and list and list:IsShown() and Buttons.Get("Spoken"):IsShown()
        and Buttons.Get("Spoken"):GetParent() == list, "clicking the folder doesn't open its list with the launcher in it")
    expect(list and list.rect.y0 > fb.uy and near(list.rect.x0 + list.rect.w, fb.ux + fb:GetWidth() / 2),
        "the list doesn't open up and to the left of its folder")
    local function pressed()
        return fb.pressed == true and fb.kaliWell ~= nil and fb.kaliWell.floor:IsShown()
    end
    expect(pressed(), "an open folder isn't pressed in")
    expect(raw:GetParent() == list and near(raw:GetScale() * 21, 14), "another addon's map button's icon isn't at the icon size")
    expect(F.rawRing:GetAlpha() == 0 and F.rawIcon:GetAlpha() == 1, "a map button's ring still shows in the list")
    expect(raw:GetFrameStrata() == list:GetFrameStrata() and raw:GetFrameLevel() > list:GetFrameLevel()
        and raw:HasFixedFrameStrata(), "a map button with its strata fixed stands under the list")
    expect(select(1, raw:GetHitRectInsets()) == 5, "a map button takes clicks off its icon")
    -- Its addon hiding it, a map button gives up its place in the list; shown again, it takes it back.
    local cells = #list.cells
    raw:Hide()
    F.RunTimers()
    expect(#list.cells == cells - 1, "a map button its addon hides still takes a place in the list")
    raw:Show()
    F.RunTimers()
    expect(#list.cells == cells, "a map button its addon shows again doesn't take its place back")
    -- Its addon moving it round the map doesn't take it out.
    raw:ClearAllPoints()
    raw:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    expect(raw:GetPoint() == "CENTER", "another addon moving its button takes it out of the list")
    -- Icons and text, one under the other, read downwards though the list opens up (Ikar 2026-11-20: "somethings off",
    -- the attributes' titles under their groups); a grid of icons, one a line, a column with the first next to the folder.
    local f = Folders.Get(addons)
    f.style, f.flow = "text", "vertical"
    InfoBar.Refresh()
    expect(Buttons.Get("Spoken").Text:GetText() == "Spoken" and list.labels[1] and list.labels[1]:GetText() == "AutoBiographer",
        "a list with text doesn't name its items")
    expect(list.cells[2] and list.cells[2].y < list.cells[1].y, "a column of texts opening up doesn't read downwards")
    -- texts alone, no icon by them (Ikar 2026-11-20: "you also have 2 affichage in folder option, and the second has
    -- none for name only"), its submenu named apart from the button's « Affichage »
    f.style = "names"
    InfoBar.Refresh()
    expect(not Buttons.Get("Spoken").Icon:IsShown() and Buttons.Get("Spoken").Text:GetText() == "Spoken"
        and L.FOLDER_SHOW ~= L.LOOK and L.FOLDER_STYLE_names ~= nil,
        "a list of texts alone shows its items' icons, or its submenu is named as the button's look")
    f.style = "text"
    InfoBar.Refresh()
    expect(Buttons.Get("Spoken").Icon:IsShown(), "back to icons and text, a list's items have no icon")
    -- opening to the left, its columns still from the left (Ikar 2026-11-20: "emote ordered weirdly")
    f.dir, f.perLine = "upleft", 1
    InfoBar.Refresh()
    expect(list.cells[2] and list.cells[2].x > list.cells[1].x and near(list.cells[2].y, list.cells[1].y),
        "a list of texts opening to the left doesn't read from the left")
    f.dir = nil
    f.style, f.flow, f.perLine = nil, nil, 1
    InfoBar.Refresh()
    expect(list.cells[2] and near(list.cells[2].x, list.cells[1].x) and list.cells[2].y > list.cells[1].y,
        "a grid of one a line isn't a column")
    f.perLine = nil
    click(addons, "LeftButton")
    expect(not Folders.IsOpen(addons) and not list:IsShown(), "clicking the folder again doesn't close it")
    expect(not pressed() and not fb.kaliWell.floor:IsShown(), "a shut folder stays pressed in")
    expect(#F.sounds == 2 and F.sounds[1] == 304888 and F.sounds[2] == 304888,
        "a folder opened and shut by clicks doesn't sound as the housing sub-menu")
    -- It has no tooltip.
    GameTooltip:Hide()
    fb.mouseOver = true
    F.RunScript(fb, "OnEnter")
    F.RunTimers()
    fb.mouseOver = nil
    F.RunScript(fb, "OnLeave")
    expect(not F.tooltip.shown and not GameTooltip:IsOwned(fb), "the folder shows a tooltip")
    -- One that closes on leaving does, once the pointer has been off it and its list a moment: the game's own
    -- auto-hide, which its secure handler registers on the click.
    f.open = "leave"
    InfoBar.Refresh()
    fb.mouseOver = true
    click(addons, "LeftButton")
    F.AutoHide(0.05)
    fb.mouseOver = nil
    F.AutoHide(0.05)
    F.AutoHide(0.2)
    expect(Folders.IsOpen(addons) and list:IsShown(), "a folder closing on leaving closes at once")
    F.AutoHide(0.3)
    F.RunTimers()
    expect(not Folders.IsOpen(addons) and not list:IsShown(), "a folder closing on leaving stays open")
    expect(#F.sounds == 3, "a folder opened by a click is silent, or one closing on leaving isn't")
    f.open = nil
    -- Renamed from its menu, its button says so at once.
    click(addons, "RightButton")
    item = F.MenuItem(L.FOLDER_RENAME)
    if item then
        run(item.choose)
    end
    F.popupText = "Mes add-ons"
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    expect(f.name == "Mes add-ons" and fb.Text:GetText() == "Mes add-ons", "a folder renamed doesn't say so")
    Folders.Rename(addons, L.FOLDER_ADDONS)
    F.RunTimers()
    -- Under Renommer… in its menu: the icon library, then how it shows (« Affichage »: its icon and its name, its
    -- icon alone, its name alone; Ikar 2026-11-16: "should be able to show name, icon, or both").
    click(addons, "RightButton")
    local entries = F.lastMenu and F.lastMenu.items or {}
    item = F.MenuItem(L.LOOK)
    expect(entries[2] and entries[2].text == L.FOLDER_RENAME and entries[3] and entries[3].text == L.FOLDER_ICON
        and item and entries[4] == item and F.MenuItem(L.LOOK_both, item) and F.MenuItem(L.LOOK_both, item).isSelected(),
        "the folder's menu has no icon library and look under Renommer…")
    local namedWidth = fb:GetWidth()
    -- in a function of its own: the main chunk is at Lua 5.1's 200 locals
    run(function()
        local function lookOf(name, look)
            click(name, "RightButton")
            local choice = F.MenuItem(L.LOOK) and F.MenuItem(L["LOOK_" .. look], F.MenuItem(L.LOOK))
            if choice then
                run(choice.choose)
                F.RunTimers()
            end
            return choice ~= nil
        end
        expect(lookOf(addons, "icon") and f.iconOnly == true and fb.Text:GetText() == "" and fb:GetWidth() < namedWidth,
            "a folder showing its icon alone still shows its name")
        expect(lookOf(addons, "name") and f.nameOnly == true and f.iconOnly == nil and not fb.Icon:IsShown()
            and fb.Text:GetText() == f.name, "a folder showing its name alone shows its icon")
        expect(lookOf(addons, "both") and f.iconOnly == nil and f.nameOnly == nil and fb.Icon:IsShown()
            and fb.Text:GetText() == f.name and near(fb:GetWidth(), namedWidth), "a folder doesn't show its icon and name again")
        -- a macro on the bar: its name by its icon (Ikar 2026-11-16: "macro should display their name when they have
        -- one"), its icon alone or its name alone as a folder's
        local hello = ns.Macros.Create({ name = "Salut", text = "/wave" })
        Hub.Insert(hello, "right", 1)
        InfoBar.Refresh()
        local hb = Buttons.Get(hello)
        expect(hb and hb:IsShown() and hb.Text:GetText() == "Salut" and hb.Icon:IsShown(),
            "a macro on the bar doesn't show its name by its icon")
        expect(lookOf(hello, "icon") and hb.Text:GetText() == "" and hb.Icon:IsShown(), "a macro showing its icon alone shows its name")
        expect(lookOf(hello, "name") and hb.Text:GetText() == "Salut" and not hb.Icon:IsShown(),
            "a macro showing its name alone shows its icon")
        ns.Macros.Delete(hello)
        Hub.Changed()
        InfoBar.Refresh()
    end)
    -- The library: above the folder's button, flush with its right side, the folder's list shut; every icon the game
    -- has at a glance, by category (Ikar 2026-11-16: "all in one panel... by category without switching"), the icon
    -- the folder wears pressed in; a category with no icon the game has takes no heading. A click gives the folder that
    -- icon at once and shuts the library; the folders' own goes back unsaved, in their colour; Escape shuts it.
    local IconPicker = ns.IconPicker
    local classIcons = 0
    F.missingAtlases["fruit-minimap-icon"] = true
    for _, icon in ipairs(ns.ICONS) do
        if icon.group == "classes" then
            F.missingAtlases[icon[1]] = true
            classIcons = classIcons + 1
        end
    end
    click(addons, "LeftButton")
    click(addons, "RightButton")
    item = F.MenuItem(L.FOLDER_ICON)
    if item then
        run(item.choose)
        F.RunTimers()
    end
    F.missingAtlases["fruit-minimap-icon"] = nil
    for _, icon in ipairs(ns.ICONS) do
        if icon.group == "classes" then
            F.missingAtlases[icon[1]] = nil
        end
    end
    local picker = KaLiHUDIconPicker
    expect(picker and picker:IsShown() and not Folders.IsOpen(addons),
        "the icon library doesn't open, or the folder's list stays open under it")
    local pcells = picker and picker.cells or {}
    expect(classIcons > 0 and #pcells == #ns.ICONS - 1 - classIcons and pcells[1].atlas == ns.ICONS[1][1]
        and picker.current == pcells[1] and picker.Worn:IsShown() and select(2, picker.Worn:GetPoint()) == pcells[1],
        "the library doesn't show the game's icons, the folder's own on its lighter square")
    local G = IconPicker.GROUND
    expect(picker.KaLiBorder == nil and G[1] == G[2] and G[2] == G[3] and #picker.edges == 4,
        "the library isn't a plain window: a neutral ground in a line, no HUD border")
    local named = true
    for _, group in ipairs(ns.ICON_GROUPS) do
        named = named and L["ICON_GROUP_" .. group] ~= "ICON_GROUP_" .. group
    end
    for _, icon in ipairs(ns.ICONS) do
        -- the game's word, with this build's French and English for a client without it, or ours in each language
        named = named and (icon.game and type(icon.fr) == "string" and type(icon.en) == "string"
            or not icon.game and type(ns.STRINGS.enUS.ICON_NAMES[icon[1]]) == "string")
            and L["ICON_GROUP_" .. tostring(icon.group)] ~= "ICON_GROUP_" .. tostring(icon.group)
    end
    expect(named, "a category of the library, or one of its icons, has no name")
    -- every category but the one with no icon, its name over its icons, in the library's order down the columns, all
    -- shown at once, within the picker's share of the screen; the names and the title in the HUD's bronze, not gold
    local sections, order = picker and picker.sections or {}, {}
    for i, group in ipairs(ns.ICON_GROUPS) do
        order[group] = i
    end
    local listsClasses, inOrder, placed = false, true, true
    for i, s in ipairs(sections) do
        local before = sections[i - 1]
        listsClasses = listsClasses or s.group == "classes"
        inOrder = inOrder and (not before or order[s.group] > order[before.group] and s.column >= before.column)
        local _, _, _, hx, hy = s.Head:GetPoint()
        local _, _, _, cx, cy = s.cells[1]:GetPoint()
        placed = placed and s.Head:IsShown() and s.Head:GetText() == L["ICON_GROUP_" .. s.group]
            and s.Head.textColor[1] == IconPicker.LABEL[1] and s.Head.textColor[3] > 0.3 and cx == hx and cy < hy
        for _, c in ipairs(s.cells) do
            placed = placed and c:IsShown() and c.group == s.group
        end
    end
    expect(#sections == #ns.ICON_GROUPS - 1 and not listsClasses and inOrder and placed and picker.columns >= 3
        and sections[#sections].column == picker.columns and picker.Title.textColor[3] > 0.3
        and picker:GetHeight() <= UIParent:GetHeight() * 0.85,
        "the library doesn't show every category at once, in order down its columns, named in bronze, on the screen")
    local _, _, _, px, py = picker:GetPoint()
    expect(py and py > fb.uy and near(px + picker:GetWidth(), fb.ux + fb:GetWidth() / 2),
        "the library isn't above the folder's button, flush with its right side")
    local banker
    for _, c in ipairs(pcells) do
        if c.atlas == "Banker" then
            banker = c
        end
    end
    expect(banker and banker.Icon.vertexColor == nil and pcells[1].Icon.vertexColor
        and near(pcells[1].Icon.vertexColor[3], Folders.TINT[3]),
        "the library doesn't draw white glyphs in the folders' colour, painted icons as they are")
    -- Each icon named on hover: the game's own word when it has it, else ours, French here, English in other languages;
    -- a class's from the game's own table.
    F.RunScript(pcells[1], "OnEnter")
    expect(GameTooltip:IsOwned(pcells[1]) and F.tooltip.shown and F.tooltip.lines[1] == "Dossier",
        "an icon of the library has no name on hover")
    F.RunScript(pcells[1], "OnLeave")
    expect(not F.tooltip.shown, "an icon's name stays when the pointer leaves it")
    local warrior, hunter
    for _, icon in ipairs(ns.ICONS) do
        if icon[1] == "classicon-warrior" then
            warrior = icon
        elseif icon[1] == "classicon-hunter" then
            hunter = icon
        end
    end
    local classNames = LOCALIZED_CLASS_NAMES_MALE
    local warriorWord, hunterWord = classNames.WARRIOR, classNames.HUNTER
    classNames.WARRIOR, classNames.HUNTER = "Guerrier (jeu)", nil
    local locale = ns.LOCALE
    local warriorName, hunterName = warrior and IconPicker.Name(warrior), hunter and IconPicker.Name(hunter)
    ns.LOCALE = "deDE"
    local hunterOther = hunter and IconPicker.Name(hunter)
    ns.LOCALE, classNames.WARRIOR, classNames.HUNTER = locale, warriorWord, hunterWord
    expect(warriorName == "Guerrier (jeu)" and hunterName == "Chasseur" and hunterOther == "Hunter",
        "a class isn't named by the game's own table, or by ours in French, else English, without it")
    -- an icon the game has no word for, in the player's language: each language's own, Mexican Spanish's where its game's
    -- words differ (Ikar 2026-11-21: "About icons, yes. As much as possible.")
    local flight, skull
    for _, icon in ipairs(ns.ICONS) do
        flight = icon[1] == "TaxiNode_Neutral" and icon or flight
        skull = icon[1] == "DungeonSkull" and icon or skull
    end
    local seen = {}
    for _, l in ipairs({ "frFR", "deDE", "esES", "esMX" }) do
        ns.LOCALE = l
        seen[l] = (flight and IconPicker.Name(flight) or "?") .. " / " .. (skull and IconPicker.Name(skull) or "?")
    end
    ns.LOCALE = locale
    expect(seen.frFR == "Trajet aérien / Crâne de donjon" and seen.deDE == "Flugroute / Dungeonschädel"
        and seen.esES == "Ruta de vuelo / Calavera de mazmorra" and seen.esMX == "Ruta de vuelo / Calavera de calabozo",
        "an icon the game has no word for isn't named in the player's language: " .. table.concat({ seen.frFR, seen.deDE,
            seen.esES, seen.esMX }, " | "))
    local bankerWord = _G.MINIMAP_TRACKING_BANKER
    _G.MINIMAP_TRACKING_BANKER = "Banquier (jeu)"
    if banker then
        F.RunScript(banker, "OnEnter")
    end
    local gameName = F.tooltip.lines[1]
    _G.MINIMAP_TRACKING_BANKER = nil
    if banker then
        F.RunScript(banker, "OnEnter")
    end
    _G.MINIMAP_TRACKING_BANKER = bankerWord
    expect(bankerWord == "Banquier" and gameName == "Banquier (jeu)" and F.tooltip.lines[1] == "Banquier",
        "an icon isn't named by the game's own word, or by this build's when the game lacks it")
    if banker then
        F.RunScript(banker, "OnLeave")
        F.RunScript(banker, "OnClick", "LeftButton")
        F.RunTimers()
    end
    -- the pick shuts the library (Ikar 2026-11-17: "when an icon is selected, close the icon page"); opened again, the
    -- icon picked is on its lighter square
    expect(f.icon == "Banker" and fb.Icon._atlas == "Banker" and fb.Icon.vertexColor[3] == 1 and not picker:IsShown(),
        "a picked icon isn't the folder's at once, as it's painted, or the library stays open")
    Folders.PickIcon(addons)
    expect(picker:IsShown() and picker.current == banker and picker.Worn:IsShown()
        and select(2, picker.Worn:GetPoint()) == banker, "the library opened again doesn't show the folder's icon worn")
    F.RunScript(pcells[1], "OnClick", "LeftButton")
    F.RunTimers()
    expect(f.icon == nil and fb.Icon._atlas == ns.ICONS[1][1] and near(fb.Icon.vertexColor[3], Folders.TINT[3])
        and not picker:IsShown(), "the folders' own icon back is saved, or not in their colour")
    expect(fb.Icon:GetHeight() < fb.Icon:GetWidth(), "the folders' own icon isn't cropped to its art")
    -- An icon the game no longer has (Ikar 2026-11-16: "in case Blizzard changes them"): Blizzard's question mark in
    -- its place, as it is, a white glyph's too; the self-check says which atlas and which name the game lacks.
    local QUESTION = QUESTION_MARK_ICON or 134400
    F.missingAtlases.Banker = true
    Folders.SetIcon(addons, "Banker")
    F.RunTimers()
    expect(f.icon == "Banker" and fb.Icon:IsShown() and fb.Icon.file == QUESTION and fb.Icon._missing
        and fb.Icon.vertexColor[3] == 1 and near(fb.Icon:GetWidth(), Hub.IconSize()),
        "a folder whose icon the game lacks doesn't show the question mark")
    F.missingAtlases[ns.ICONS[1][1]] = true
    Folders.SetIcon(addons, ns.ICONS[1][1])
    F.RunTimers()
    expect(f.icon == nil and fb.Icon.file == QUESTION and fb.Icon.vertexColor[3] == 1,
        "the question mark in place of a white glyph takes the folders' colour")
    _G.MINIMAP_TRACKING_BANKER, classNames.HUNTER = nil, nil
    local iconCheck
    for _, a in ipairs((ns.SelfCheck.Assumptions())) do
        if a.name == "icons" then
            iconCheck = a
        end
    end
    _G.MINIMAP_TRACKING_BANKER, classNames.HUNTER = bankerWord, hunterWord
    F.missingAtlases.Banker, F.missingAtlases[ns.ICONS[1][1]] = nil, nil
    local said = {}
    for _, w in ipairs(iconCheck and iconCheck.wrong or {}) do
        said[w] = true
    end
    expect(iconCheck and #iconCheck.wrong == 4 and said["atlas Banker missing"] and said["atlas " .. ns.ICONS[1][1] .. " missing"]
        and said["name MINIMAP_TRACKING_BANKER missing"] and said["name LOCALIZED_CLASS_NAMES_MALE.HUNTER missing"]
        and iconCheck.looked > #ns.ICONS,
        "the self-check doesn't say which of the library's icons and names the game lacks, and only those")
    Folders.SetIcon(addons, "Banker")
    Folders.SetIcon(addons, ns.ICONS[1][1])
    F.RunTimers()
    expect(f.icon == nil and fb.Icon._missing == false and fb.Icon.file ~= QUESTION
        and near(fb.Icon.vertexColor[3], Folders.TINT[3]), "the folder's icon isn't its own again once the game has it")
    local escapes = false
    for _, name in ipairs(UISpecialFrames) do
        escapes = escapes or name == picker:GetName()
    end
    expect(escapes, "Escape doesn't shut the icon library")
    Folders.PickIcon(addons)
    F.RunScript(pcells[1], "OnEnter")
    picker:Hide()
    expect(not F.tooltip.shown, "an icon's name stays on screen once the library is shut")
    -- A new folder from the bar's menu opened at its right end, named, there; Gold dropped on its icon goes in.
    F.cursorX = (UIParent:GetWidth() - 2) * UIParent:GetEffectiveScale()
    F.cursorY = ns.InfoBar.Top() / 2 * UIParent:GetEffectiveScale()
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    F.cursorX, F.cursorY = nil, nil
    item = F.MenuItem(L.FOLDER_CREATE)
    if item then
        run(item.choose)
    end
    F.popupText = "  Outils  "
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    -- the last made, after « Add-ons » and the « Emote » made for the player to try
    local tools = Folders.List()[#Folders.List()]
    expect(tools and Folders.Get(tools).name == "Outils" and sideList("right")[1] == tools,
        "a folder made from the bar's menu isn't named, at the bar's right end")
    F.RunScript(InfoBar.lockButton, "OnClick", "LeftButton")
    F.RunTimers()
    local tb = tools and Buttons.Get(tools)
    if tb then
        F.cursorX, F.cursorY = tb.ux - tb:GetWidth() / 2 + 7, tb.uy
        Drag.Begin("KaLiHUD_Gold")
        Drag.Finish()
        F.RunTimers()
    end
    expect(inFolder("KaLiHUD_Gold", tools), "Gold dropped on a folder's icon isn't in it")
    -- A map button left to its addon goes back where it was, as it was; taken back, it's in the folder again.
    local h = Buttons.Handle(rawName)
    expect(h ~= nil, "unlocked, another addon's map button has no handle")
    if h then
        local clicks = #F.rawClicks
        F.RunScript(h, "OnClick", "RightButton")
        expect(#F.rawClicks == clicks, "unlocked, a right-click on another addon's map button's handle reaches its own")
        item = F.MenuItem(L.BUTTON_LEAVE)
        if item then
            run(item.choose)
        end
        F.RunTimers()
    end
    expect(raw:GetParent() == Minimap and raw:GetScale() == 1 and raw:GetPoint() == "TOPLEFT" and ns.db.buttonsLeft[rawName]
        and Hub.Entry(rawName) == nil and F.rawRing:GetAlpha() == 1 and raw:GetFrameStrata() == "MEDIUM"
        and select(1, raw:GetHitRectInsets()) == 0, "a map button left to its addon isn't given back as it was")
    -- it was dragged by nothing: it isn't now
    expect(#raw.drags == 0, "a map button left to its addon is dragged by the left button, which it never was")
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    item = F.MenuItem(string.format(L.TAKE_BACK, rawName))
    if item then
        run(item.choose)
    end
    F.RunTimers()
    expect(not ns.db.buttonsLeft[rawName] and inFolder(rawName, addons), "a map button taken back isn't in the Add-ons folder again")
    -- A folder deleted from its menu, asked first, the question saying what goes with it (Ikar 2026-11-16: "prompt the
    -- user if he is sure, as the content will be deleted, not displaced"): Gold, which can't be deleted, hidden, out of
    -- any folder; its icon library shuts. Undone from the bar's menu, it's back as it was, Gold in it; done again, gone.
    run(function()
        local function copy(v)
            if type(v) ~= "table" then
                return v
            end
            local t = {}
            for k, x in pairs(v) do
                t[k] = k ~= "opened" and copy(x) or nil
            end
            return t
        end
        local function same(a, b)
            if type(a) ~= "table" or type(b) ~= "table" then
                return a == b
            end
            for k, x in pairs(a) do
                if not same(x, b[k]) then
                    return false
                end
            end
            for k in pairs(b) do
                if a[k] == nil then
                    return false
                end
            end
            return true
        end
        local folder, gold = tools and copy(Folders.Get(tools)), copy(ns.db.items.KaLiHUD_Gold)
        expect(ns.History.Next() == string.format(L.ACT_move, Hub.Label("KaLiHUD_Gold")),
            "Gold dropped on a folder isn't the last action to undo: " .. tostring(ns.History.Next()))
        local asked
        if tools then
            Folders.PickIcon(tools)
            click(tools, "RightButton")
            item = F.MenuItem(L.FOLDER_DELETE)
            if item then
                run(item.choose)
            end
            asked = F.popup and StaticPopupDialogs[F.popup.which].text == L.FOLDER_DELETE_ASK and F.popup.text == "Outils"
            if F.popup then
                F.AcceptPopup()
            end
            F.RunTimers()
        end
        expect(asked, "deleting a folder that holds something doesn't ask first, saying its contents go with it")
        local saved = ns.db.items.KaLiHUD_Gold
        expect(tools and Folders.Get(tools) == nil and Hub.Entry("KaLiHUD_Gold").side == "hidden" and saved
            and saved.folder == nil and saved.last == nil, "a deleted folder's contents aren't gone with it")
        expect(not picker:IsShown(), "a deleted folder's icon library stays open")
        local undo = string.format(L.UNDO_WHAT, string.format(L.ACT_delete, "Outils"))
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        item = F.MenuItem(undo)
        expect(item and item:IsEnabled(), "the bar's menu has no « " .. undo .. " »")
        if item then
            run(item.choose)
        end
        F.RunTimers()
        expect(tools and same(copy(Folders.Get(tools)), folder) and same(ns.db.items.KaLiHUD_Gold, gold)
            and inFolder("KaLiHUD_Gold", tools) and Buttons.Get(tools):IsShown(),
            "an undone deletion doesn't bring the folder back as it was, Gold in it")
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        item = F.MenuItem(string.format(L.REDO_WHAT, string.format(L.ACT_delete, "Outils")))
        if item then
            run(item.choose)
        end
        F.RunTimers()
        expect(tools and Folders.Get(tools) == nil and Hub.Entry("KaLiHUD_Gold").side == "hidden"
            and not Buttons.Get(tools):IsShown(), "a deletion done again from the bar's menu doesn't delete")
        -- Gold where it goes by default, for what follows
        Hub.Reset("KaLiHUD_Gold")
        F.RunTimers()
    end)
    F.RunScript(InfoBar.lockButton, "OnClick", "LeftButton")
    F.RunTimers()
end
-- Another addon's plain readout, with no click of its own: its right-click is the hub menu's while shut too (the review
-- of 2026-11-17: it did nothing), and its tooltip says so; never the drag's hint while locked.
F.RunScript(Buttons.Get("Libs Error Display"), "OnEnter")
expect(F.tooltip.shown and has("Aucune erreur") and has(L.HINT_HUB_MENU) and not has(L.HINT_DRAG_SLOT),
    "another addon's tooltip isn't shown, or, locked, a plain readout's lacks the hub menu's hint, or has the drag's")
F.RunScript(Buttons.Get("KaLiHUD_Gold"), "OnEnter")
expect(F.tooltip.shown and has(L.HINT_GOLD) and not has(L.HINT_HUB_MENU) and not has(L.HINT_DRAG_SLOT),
    "locked, the gold's tooltip isn't shown with its own right-click's hint alone")
F.RunScript(Buttons.Get("KaLiHUD_Performance"), "OnEnter")
F.RunScript(Buttons.Get("KaLiHUD_Volume"), "OnMouseWheel", 1)
expect(F.cvars.Sound_MasterVolume == "0.85", "the wheel doesn't raise the volume: " .. tostring(F.cvars.Sound_MasterVolume))
click("KaLiHUD_Volume", "LeftButton")
F.RunTimers()
expect(F.cvars.Sound_EnableAllSound == "0" and Buttons.Get("KaLiHUD_Volume").Text:GetText() == L.MUTED, "a click doesn't mute")
click("KaLiHUD_Volume", "RightButton")
item = F.MenuItem(string.format(L.PERCENT, 50))
if item then
    run(item.choose)
end
expect(F.cvars.Sound_MasterVolume == "0.50", "the volume menu doesn't set the volume")
click("KaLiHUD_Repair", "LeftButton")
expect(F.toggled.character == "PaperDollFrame", "clicking repairs doesn't open the character sheet")
F.combat = true
click("KaLiHUD_Location", "LeftButton")
F.combat = false
expect(not F.toggled.map, "the map opened in a fight")

-- The bar's own menu: every element by category, sorted, ticked when shown; not the zone, nor where each goes.
F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
local character = F.MenuItem(L.CAT_character)
local labels = {}
for _, it in ipairs(character and character.items or {}) do
    labels[#labels + 1] = it.text
end
local sorted = { unpack(labels) }
table.sort(sorted, ns.TextLess)
expect(#labels >= 4 and table.concat(labels, ",") == table.concat(sorted, ","),
    "the bar menu's character items aren't sorted: " .. table.concat(labels, ","))
expect(F.MenuItem(L.CAT_minimap) and F.MenuItem(L.CAT_addons) and F.MenuItem(L.CAT_world)
    and not F.MenuItem(L.ITEM_LOCATION) and not F.MenuItem(L.SIDE_hidden), "the bar menu isn't by category, or lists the zone or places")
item = F.MenuItem(L.ITEM_BAGS, character)
if item then
    run(item.choose)
    F.RunTimers()
end
expect(ns.db.items.KaLiHUD_Bags and ns.db.items.KaLiHUD_Bags.side == "hidden" and not Buttons.Get("KaLiHUD_Bags"):IsShown(),
    "an item unticked still shows")
F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
item = F.MenuItem(L.ITEM_BAGS, F.MenuItem(L.CAT_character))
if item then
    run(item.choose)
    F.RunTimers()
end
expect(ns.db.items.KaLiHUD_Bags.side == "left" and Buttons.Get("KaLiHUD_Bags"):IsShown(), "an item ticked again isn't back on its side")
local function barRow()
    local row = {}
    for _, side in ipairs({ "left", "centre", "right" }) do
        local list = sideList(side)
        local from, to, by = 1, #list, 1
        if side == "right" then
            from, to, by = #list, 1, -1
        end
        for i = from, to, by do
            row[#row + 1] = list[i]
        end
    end
    return row
end
local before, nextOne = barRow(), nil
for i, name in ipairs(before) do
    if name == "KaLiHUD_Bags" then
        nextOne = before[i + 1]
    end
end
local right
click("KaLiHUD_Bags", "RightButton")
right = F.MenuItem(L.GO_RIGHT)
if right then
    run(right.choose)
    F.RunTimers()
end
local after = barRow()
local bagsAt, nextAt
for i, name in ipairs(after) do
    bagsAt = name == "KaLiHUD_Bags" and i or bagsAt
    nextAt = name == nextOne and i or nextAt
end
expect(nextOne and bagsAt and nextAt and bagsAt == nextAt + 1, "going right doesn't take Bags past its neighbour: " .. table.concat(after, ","))

-- The map placed out of the plate's reach: KaLi HUD lets it go as Blizzard has it (Ikar 2026-11-15: "we should apply
-- our changes only when we take ownership of it"): its shape, header and ring, Blizzard's widgets back in the cluster,
-- from the bar too; ours round it hidden, another addon's button round it back to its addon on the map. Back in reach,
-- all ours again.
do
    local raw, track = F.rawButton, MinimapCluster.Tracking
    Hub.Save("KaLiHUD_Gold", { side = "ring", angle = 90 })
    Hub.Save(raw:GetName(), { side = "ring", angle = 30 })
    Hub.Save(ns.Natives.NAME.CALENDAR, { side = "free", pos = 0.3 })
    F.RunTimers()
    expect(ns.Minimap.Owned() and raw:GetParent() == UIParent and GameTimeFrame:GetParent() == UIParent,
        "on the plate, the map's elements aren't ours to place")
    -- as it's dragged (Ikar 2026-11-16: "can't it happen during drag?"): Blizzard's out of reach before the drop,
    -- ours again back in reach
    F.EnterEditMode()
    move(Minimap, 981, 600)
    F.RunScript(Plate.frame, "OnUpdate")
    local outMidDrag = not ns.Minimap.Owned() and GetMinimapShape == nil and track:GetParent() == MinimapCluster
    move(Minimap, 981, 40.8)
    F.RunScript(Plate.frame, "OnUpdate")
    expect(outMidDrag and ns.Minimap.Owned() and GetMinimapShape and GetMinimapShape() == "ROUND",
        "dragged out of reach and back, the map changes hands only at the drop")
    F.ExitEditMode()
    F.RunTimers()
    place(Minimap, 981, 600)
    expect(not Plate.last.dome and not ns.Minimap.Owned() and ns.Minimap.Dome() == nil,
        "out of the plate's reach, the map is still KaLi HUD's")
    expect(track:GetParent() == MinimapCluster and GameTimeFrame:GetParent() == MinimapCluster
        and GameTimeFrame:GetScale() == 1 and GetMinimapShape == nil and MinimapCluster.ZoneTextButton.alpha ~= 0,
        "out of the plate's reach, the map isn't as Blizzard has it, its widgets the bar's included")
    expect(not Buttons.Get("KaLiHUD_Gold"):IsShown() and raw:GetParent() == Minimap and raw:GetScale() == 1,
        "round a map that isn't ours, our element shows or another addon's button isn't back on it")
    expect(not ns.InfoBar.Placed(ns.Natives.NAME.CALENDAR), "a widget of a map that isn't ours takes a place on the bar")
    place(Minimap, 981, 40.8)
    expect(Plate.last.dome and ns.Minimap.Owned() and select(2, ns.Minimap.Dome()) == true and GetMinimapShape() == "ROUND"
        and track:GetParent() == UIParent and Buttons.Get("KaLiHUD_Gold"):IsShown() and raw:GetParent() == UIParent
        and ns.InfoBar.Placed(ns.Natives.NAME.CALENDAR), "back in reach, the map and its elements aren't ours again")
    Hub.Reset("KaLiHUD_Gold")
    Hub.Reset(raw:GetName())
    Hub.Reset(ns.Natives.NAME.CALENDAR)
    F.RunTimers()
end

-- The info bar off: nothing lands at the screen's foot, and the pockets' places light up where their elements stand.
do
    ns.db.options.infoBar = false
    ns.ApplyAll()
    F.RunTimers()
    Hub.SetLocked(false)
    F.RunTimers()
    expect(Drag.Target(300, 10) == nil and Drag.Target(UIParent:GetWidth() - 40, 5) == nil,
        "with the info bar off, a drop at the screen's foot lands on the hidden bar")
    local d = ns.Minimap.Dome()
    local places = Hub.PocketSpots(d, 0).pocketLeft
    F.cursorX, F.cursorY = 300, 10
    -- where gold is saved to stand, if anywhere: as it was after the drop (whatever the session did with it before)
    local was = ns.DeepCopy(ns.db.items.KaLiHUD_Gold)
    Drag.Begin("KaLiHUD_Gold")
    local lit
    for _, f in ipairs(F.frames) do
        if f.Ring and f.Pockets and f.Ends then
            lit = f.Pockets[1]
        end
    end
    local x, y = Hub.PocketPoint(d, places, "pocketLeft", 1)
    expect(places[1] and lit and lit:IsShown() and near(select(4, lit:GetPoint()), x) and near(select(5, lit:GetPoint()), y),
        "with the info bar off, the pockets' places light up off where their elements stand")
    Drag.Finish()
    F.RunTimers()
    local now = ns.db.items.KaLiHUD_Gold
    expect((now and now.side) == (was and was.side) and (now and now.order) == (was and was.order)
        and (now and now.pos) == (was and was.pos), "with the info bar off, an element dropped at the screen's foot moved")
    Hub.SetLocked(true)
    ns.db.options.infoBar = nil
    ns.ApplyAll()
    F.RunTimers()
end

-- ---------- Macros, and the hub in a fight ----------
-- Made once for the player to try (Ikar 2026-11-16: "I asked for a list of all the emotes, not just 2, they just need
-- to be split into 2 categories, with different icons"): « Emote » on the bar's right side, the speech bubble on it,
-- holding every emote of the chat menu, the bubble on them, a separator, then every voice emote, the chat link on them
-- (not the faction's: the macros are the account's), each a secure button running its slash command on a left click.
do
    local Folders, Macros, Editor = ns.Folders, ns.Macros, ns.MacroEditor
    local function contents(id)
        local names = {}
        for _, m in ipairs(Hub.InFolder(id)) do
            local mac = Macros.Get(m.name)
            names[#names + 1] = m.isSeparator and ("|" .. (ns.Separators.Name(m.name) or "")
                .. (ns.Separators.StartsLine(m.name) and ">" or "")) or mac and (mac.text
                .. (mac.icon == "common-icon-chatlink" and "@" or mac.icon == "common-icon-speak" and "" or "?")) or "?"
        end
        return table.concat(names, " ")
    end
    -- each kind under its title, the game's words, the voices from a column of their own
    local EMOTE, VOICE = "|" .. ns.G("EMOTE", "Emote"), "|" .. ns.G("VOICEMACRO_LABEL", "Voice Emote") .. ">"
    local emotes = Folders.ByRole("emotes")
    expect(emotes and Hub.Entry(emotes).side == "right" and Folders.Setting(emotes, "icon") == "common-icon-speak"
        and Folders.Setting(emotes, "style") == "text" and Folders.Setting(emotes, "flow") == "vertical",
        "no « Emote » folder with the speech bubble on the bar's right side, its list running down")
    local got = emotes and contents(emotes) or ""
    expect(got == EMOTE .. " /danse /salut /signe " .. VOICE .. " /aide@ /bonjour@ /acclame@",
        "the « Emote » folder doesn't hold every emote, a separator, then every voice emote: " .. got)
    local held, folders = emotes and #Hub.InFolder(emotes), #Folders.List()
    ns.Seeds.Run()
    F.RunTimers()
    expect(emotes and #Hub.InFolder(emotes) == held and #Folders.List() == folders,
        "the « Emote » folder is filled again at the next start")
    -- Locked (UI/Hub/Seeds.lua): what an earlier build left in it (one of the player's macros, an emote's commands
    -- changed, another gone) made as the code makes it at the next login, with no mark of its own; the player's own out
    -- of it, kept
    do
        local mine = Macros.Create({ name = "Rire", icon = "common-icon-speak", text = "/rire" })
        Hub.PlaceAt(mine, "folder", 1, emotes)
        local changed, gone
        for _, e in ipairs(Hub.InFolder(emotes)) do
            if e.isMacro and e.name ~= mine then
                if not changed then
                    changed = e.name
                elseif not gone then
                    gone = e.name
                end
            end
        end
        Macros.Get(changed).text = "/dormir"
        Macros.Delete(gone)
        Hub.Changed()
        ns.Seeds.Run()
        F.RunTimers()
        local now, e = contents(emotes), Hub.Entry(mine)
        expect(now == got and e and e.side ~= "folder" and Macros.Get(mine).seed == nil,
            "a locked folder isn't made as the code makes it at the next login, or the player's macro stays in it: "
            .. now)
        Macros.Delete(mine)
        F.RunTimers()
    end
    -- What follows in a folder of two macros of its own, put away at the end.
    local folder = Folders.Create("Essai")
    Hub.Insert(folder, "right", 1)
    local emote = Macros.Create({ name = ns.G("EMOTE", "Emote"), icon = "common-icon-speak",
        text = ns.G("EMOTE102_CMD1", "/wave") })
    local voice = Macros.Create({ name = ns.G("VOICEMACRO_LABEL", "Voice Emote"), icon = "common-icon-chatlink",
        text = ns.G("EMOTE56_CMD1", "/hello") })
    Hub.InsertIntoFolder(emote, folder)
    Hub.InsertIntoFolder(voice, folder)
    F.RunTimers()
    local e, v = Macros.Get(emote), Macros.Get(voice)
    -- Opened, its macros are secure buttons in its list, which is a secure frame too.
    local fb, list = Buttons.Get(folder), Folders.Panel(folder)
    click(folder, "LeftButton")
    local eb, vb = Buttons.Get(emote), Buttons.Get(voice)
    expect(Folders.IsOpen(folder) and list:IsShown() and eb and eb:IsShown() and eb:GetParent() == list,
        "a click doesn't open the « Emote » folder with its macros in it")
    expect(eb and select(2, eb:IsProtected()) and select(2, fb:IsProtected()) and select(2, list:IsProtected())
        and eb:IsProtected() and InfoBar.frame:IsProtected(), "a macro, a folder or its list isn't a secure frame")
    expect(eb and eb:GetAttribute("*type1") == "macro" and eb:GetAttribute("macrotext") == e.text
        and eb:GetAttribute("useOnKeyDown") == false, "a macro's button isn't set to run its commands on the release")
    -- A left click runs it; a right click opens its menu and runs nothing.
    F.ranMacros = {}
    click(emote, "LeftButton")
    expect(#F.ranMacros == 1 and F.ranMacros[1].text == e.text, "a left click on a macro doesn't run its commands")
    F.lastMenu = nil
    click(emote, "RightButton")
    expect(#F.ranMacros == 1 and F.MenuItem(L.MACRO_EDIT) and F.MenuItem(ns.G("CALENDAR_COPY_EVENT", "Copier"))
        and F.MenuItem(L.MACRO_DELETE), "a right click on a macro runs it, or opens no menu to edit, copy or delete it")
    -- Its tooltip: its name, then its commands.
    GameTooltip:Hide()
    F.RunScript(eb, "OnEnter")
    local tip = table.concat(F.tooltip.lines, "\n")
    expect(F.tooltip.shown and tip:find(e.name, 1, true) and tip:find(e.text, 1, true)
        and tip:find(string.format(L.TYPE_LINE, L.TYPE_MACRO), 1, true),
        "a macro's tooltip doesn't show its commands, or doesn't say it's a macro")
    F.RunScript(eb, "OnLeave")

    -- In a fight: the folders open and shut and the macros run, nothing the game blocks; what would move, show or
    -- hide is greyed in the menus with its tooltip; a drag and the padlock are refused with the game's error line.
    local f = Folders.Get(folder)
    f.open = "hover"
    InfoBar.Refresh()
    click(folder, "LeftButton")
    expect(not Folders.IsOpen(folder), "a click doesn't shut an open folder")
    -- a menu open as the fight starts
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    local early = F.lastMenu
    expect(F.MenuItem(L.MACRO_CREATE, early) and F.MenuItem(L.MACRO_CREATE, early):IsEnabled(),
        "the bar's menu greys making a macro out of a fight")
    local blocked, refreshes, errors = #F.blocked, InfoBar.refreshes, #F.uiErrors
    Hub.Changed()
    F.EnterCombat()
    expect(not F.MenuItem(L.MACRO_CREATE, early):IsEnabled(), "a menu open as a fight starts doesn't grey what it can't do")
    expect(InfoBar.refreshes == refreshes + 1, "a layout waiting as a fight starts isn't drawn before the lockdown")
    fb.mouseOver = true
    F.RunScript(fb, "OnEnter")
    F.AutoHide(0.05)
    expect(Folders.IsOpen(folder) and list:IsShown() and fb.pressed, "a folder opening on hover doesn't in a fight")
    F.ranMacros = {}
    click(voice, "LeftButton")
    expect(#F.ranMacros == 1 and F.ranMacros[1].text == v.text, "a macro doesn't run in a fight")
    fb.mouseOver = nil
    F.RunScript(fb, "OnLeave")
    F.AutoHide(0.05)
    F.AutoHide(0.45)
    F.RunTimers()
    expect(not Folders.IsOpen(folder) and not list:IsShown() and not fb.pressed,
        "a folder opening on hover doesn't shut once the pointer has left it, in a fight")
    f.open = nil
    click(folder, "LeftButton")
    expect(Folders.IsOpen(folder) and list:IsShown(), "a folder doesn't open on a click in a fight")
    -- texts change, the elements change: nothing laid out until the fight is over
    Hub.Set("KaLiHUD_Gold", "text", "123 456 po")
    Hub.Changed()
    F.RunTimers()
    expect(InfoBar.refreshes == refreshes + 1, "the hub is laid out during a fight")
    -- greyed, with why
    click(folder, "RightButton")
    local where, rename = F.MenuItem(L.HUB_POSITION), F.MenuItem(L.FOLDER_RENAME)
    local why = where and table.concat(F.MenuTooltip(where) or {}, "\n") or ""
    expect(where and not where:IsEnabled() and rename and not rename:IsEnabled() and not F.MenuItem(L.GO_LEFT):IsEnabled()
        and not F.MenuItem(L.SLOTS_LOCKED):IsEnabled(), "a folder's hub menu doesn't grey what would move it in a fight")
    expect(why:find(ns.G("ERR_NOT_IN_COMBAT", "Impossible de faire ceci tout en combattant."), 1, true)
        and why:find(L.COMBAT_HELD, 1, true), "a greyed entry's tooltip doesn't say why")
    click(emote, "RightButton")
    expect(F.MenuItem(L.MACRO_EDIT):IsEnabled() and F.MenuItem(ns.G("CALENDAR_COPY_EVENT", "Copier")):IsEnabled()
        and not F.MenuItem(L.MACRO_DELETE):IsEnabled(), "a macro's menu greys editing or copying, or not deleting, in a fight")
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    local bars = F.lastMenu
    expect(not F.MenuItem(L.MACRO_CREATE, bars):IsEnabled() and not F.MenuItem(L.FOLDER_CREATE, bars):IsEnabled()
        and not F.MenuItem(Hub.Label("KaLiHUD_Gold"), bars):IsEnabled(),
        "the bar's menu doesn't grey making, showing or hiding elements in a fight")
    -- refused, with the game's line
    local locked = Hub.IsLocked()
    F.RunScript(InfoBar.lockButton, "OnClick", "LeftButton")
    expect(Hub.IsLocked() == locked and #F.uiErrors > errors, "the padlock turns in a fight, or says nothing")
    expect(not Drag.Begin(emote, eb) and Drag.Current() == nil, "a macro is dragged in a fight")
    -- the editor opens to read and prepare; saving waits
    Editor.Open(emote)
    local ed = Editor.Frame()
    expect(Editor.Current() == emote and not ed.Save:IsEnabled(), "the editor saves in a fight, or doesn't open")
    ed:Hide()
    expect(#F.blocked == blocked, "the game blocked the hub in a fight: " .. table.concat(F.blocked, ", ", blocked + 1))
    -- the fake does block: a secure button moved by the addon's code in a fight
    eb:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    expect(#F.blocked == blocked + 1, "the fake game lets an addon move a secure button in a fight")
    F.blocked[#F.blocked] = nil
    F.LeaveCombat()
    F.RunTimers()
    expect(InfoBar.refreshes > refreshes + 1, "what waited isn't drawn once the fight is over")

    -- A drag out of a fight: the macro runs nothing on the click ending it, and runs again after.
    Hub.SetLocked(false)
    F.RunTimers()
    F.cursorX, F.cursorY = 5000, 5000
    expect(Drag.Begin(emote, eb) and eb:GetAttribute("*type1") == nil, "a macro being dragged would run on the drop")
    Drag.Finish()
    F.RunTimers()
    expect(eb:GetAttribute("*type1") == "macro" and Hub.Entry(emote).folder == folder,
        "a macro dropped off the places doesn't go back, or doesn't run again")
    Hub.SetLocked(true)
    F.RunTimers()

    -- Edited: its name, its commands (the count under them), its icon; saved, its button runs the new ones.
    Editor.Open(emote)
    expect(ed.Name:GetText() == e.name and ed.Text:GetText() == e.text and ed.Save:IsEnabled() and ed.Text:IsEnabled()
        and ed.Count:GetText():find(tostring(#e.text), 1, true), "the editor doesn't show the macro's name and commands")
    ed.Name:SetText("Salut")
    F.Type(ed.Text, "/dance")
    F.RunScript(ed.IconButton, "OnClick", "LeftButton")
    local picker = _G.KaLiHUDIconPicker
    expect(picker and picker:IsShown(), "the editor's icon doesn't open the library")
    for _, c in ipairs(picker.cells or {}) do
        if c.atlas == "AnimCreate_Icon_Template" then
            F.RunScript(c, "OnClick", "LeftButton")
        end
    end
    expect(Macros.Get(emote).icon == "common-icon-speak", "an icon picked in the editor is saved before « Sauver »")
    expect(not picker:IsShown() and ed:IsShown(), "an icon picked in the editor leaves the library open, or shuts the editor")
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    e = Macros.Get(emote)
    expect(e.name == "Salut" and e.text == "/dance" and e.icon == "AnimCreate_Icon_Template" and not ed:IsShown()
        and not picker:IsShown(), "the editor doesn't save the name, the commands and the icon, or stays open")
    F.ranMacros = {}
    click(emote, "LeftButton")
    expect(F.ranMacros[1] and F.ranMacros[1].text == "/dance", "a saved macro's button runs its old commands")
    expect(not ed:IsShown(), "a macro's left click opens its editor, as a note's does")
    -- One of the game's macros, picked in the list: its commands shown to read, its own icon; it runs by name.
    Editor.Open(emote)
    local menu = F.DropdownMenu(ed.Runs)
    local mount = F.MenuItem("Monture", menu)
    expect(mount and F.MenuItem(F.characterMacros[1].name, menu) and F.MenuItem(L.MACRO_OWN, menu),
        "the editor doesn't list its own commands and the account's and the character's macros")
    -- « Exécute » a macro's alone, and no way to a note (Ikar 2026-11-17: "Remove the execute from note"): each of its
    -- choices its own commands or one of the game's macros
    for _, item in ipairs(menu.items) do
        expect(item.kind ~= "radio" or item.text == L.MACRO_OWN or Macros.Game(item.text) ~= nil,
            "a macro's « Exécute » offers more than its commands and the game's macros: " .. tostring(item.text))
    end
    expect(ed.Runs:IsShown() and ed.RunsLabel:IsShown(), "a macro's editor has no « Exécute »")
    if mount then
        mount.choose(mount.data)
    end
    expect(ed.Text:GetText() == F.macros[1].body and not ed.Text:IsEnabled() and ed.Note:IsShown(),
        "a game's macro's commands aren't shown to read")
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    e = Macros.Get(emote)
    F.ranMacros = {}
    click(emote, "LeftButton")
    expect(e.macro == "Monture" and e.icon == nil and e.text == "/dance" and eb:GetAttribute("macro") == "Monture"
        and F.ranMacros[1] and F.ranMacros[1].macro == "Monture" and Macros.Object(emote).icon == F.macros[1].icon,
        "a macro running one of the game's doesn't run it by name with its icon, or lost its own commands")
    -- that macro gone from the game: it runs nothing, the question mark on it, the tooltip says so
    local kept = F.macros
    F.macros = {}
    F.Fire("UPDATE_MACROS")
    F.RunTimers()
    F.ranMacros = {}
    click(emote, "LeftButton")
    GameTooltip:Hide()
    F.RunScript(eb, "OnEnter")
    expect(#F.ranMacros == 0 and eb:GetAttribute("*type1") == nil
        and Macros.Object(emote).icon == (QUESTION_MARK_ICON or 134400)
        and table.concat(F.tooltip.lines, "\n"):find(string.format(L.MACRO_GAME_MISSING, "Monture"), 1, true),
        "a macro whose game macro is gone still runs, or doesn't say so")
    F.RunScript(eb, "OnLeave")
    F.macros = kept
    F.Fire("UPDATE_MACROS")
    -- back to its own commands, kept meanwhile
    Editor.Open(emote)
    local own = F.MenuItem(L.MACRO_OWN, F.DropdownMenu(ed.Runs))
    own.choose()
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    expect(Macros.Get(emote).macro == nil and eb:GetAttribute("macrotext") == "/dance" and eb:GetAttribute("macro") == nil,
        "a macro back to its own commands doesn't run them")

    -- Its own right-click and its own tooltip (Ikar 2026-11-17: "Add the right click, and the tooltip"), typed in the
    -- editor. The padlock shut, a right-click runs its commands, the secure button's on the right button (*type2,
    -- macrotext2), and opens no menu of ours; its tooltip is the player's text in place of its commands.
    Editor.Open(emote)
    expect(ed.Right and ed.Right.scroll:IsShown() and ed.Tip and ed.Tip.scroll:IsShown(),
        "the editor has no box for a macro's right-click or tooltip")
    F.Type(ed.Right, "/sit")
    -- its letters counted as its commands' (Ikar 2026-11-18: "Add the character left for the secondary button click")
    expect(ed.RightCount:IsShown() and ed.RightCount:GetText() == string.format(L.MACRO_COUNT, 4, Macros.LETTERS),
        "the right-click's commands have no count of their letters: " .. tostring(ed.RightCount:GetText()))
    -- a section for each button (Ikar 2026-11-20, of the sketch: "Macro parfaite, implémente"): its icon at its head
    -- with its count, its description (a grey line in it while empty), its commands; the right's help says when they
    -- run; the tooltip's grey line says its commands stand in for it
    expect(ed.LeftBox:IsShown() and ed.RightBox:IsShown() and ed.RightHelp:IsShown()
        and ed.LeftDesc.Instructions:GetText() == L.MACRO_DESC_HINT and ed.Tip.Instructions:GetText() == L.MACRO_TIP_HINT
        and select(3, ed.LeftDesc:GetPoint()) > select(3, ed.Scroll:GetPoint())
        and select(3, ed.Scroll:GetPoint()) > select(3, ed.RightDesc:GetPoint())
        and select(3, ed.RightDesc:GetPoint()) > select(3, ed.Right.scroll:GetPoint())
        and select(3, ed.Right.scroll:GetPoint()) > select(3, ed.TipLabel:GetPoint()),
        "the editor isn't a section for each button, its description then its commands, then the tooltip")
    F.RunScript(ed.RightHelp, "OnEnter")
    expect(table.concat(F.tooltip.lines, " "):find(L.MACRO_RIGHT_HELP, 1, true),
        "the right-click's help doesn't say when its commands run")
    F.RunScript(ed.RightHelp, "OnLeave")
    F.Type(ed.Tip, "S'asseoir, ou danser")
    -- a short line for each button, above the tooltip (Ikar 2026-11-18: "Add Description to the macro right and left
    -- button, on top of infobulle. Single line enty, short"), its blanks round it gone
    expect(ed.LeftDesc:IsShown() and ed.RightDesc:IsShown() and ed.LeftDesc.icon:IsShown()
        and ed.LeftDesc:GetMaxLetters() == Macros.DESC_LETTERS
        and select(3, ed.RightDesc:GetPoint()) > select(3, ed.TipLabel:GetPoint())
        and select(3, ed.LeftDesc:GetPoint()) > select(3, ed.RightDesc:GetPoint()),
        "the editor has no short line for each button's description, the left's then the right's, above the tooltip")
    F.Type(ed.LeftDesc, "  Danser ")
    F.Type(ed.RightDesc, "S'asseoir")
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    e = Macros.Get(emote)
    expect(e.right == "/sit" and e.tip == "S'asseoir, ou danser" and eb:GetAttribute("*type2") == "macro"
        and eb:GetAttribute("macrotext2") == "/sit", "the editor doesn't save the right-click and the tooltip, or its "
        .. "button isn't set to run the right-click")
    expect(e.leftDesc == "Danser" and e.rightDesc == "S'asseoir",
        "the editor doesn't save each button's description on one line: " .. tostring(e.leftDesc) .. ", " .. tostring(e.rightDesc))
    F.ranMacros, F.lastMenu = {}, nil
    click(emote, "RightButton")
    click(emote, "LeftButton")
    expect(#F.ranMacros == 2 and F.ranMacros[1].text == "/sit" and F.ranMacros[2].text == "/dance" and F.lastMenu == nil,
        "shut, a macro's own right-click doesn't run its commands, opens a menu of ours, or its left one runs them")
    GameTooltip:Hide()
    F.RunScript(eb, "OnEnter")
    tip = table.concat(F.tooltip.lines, "\n")
    expect(tip:find("S'asseoir, ou danser", 1, true) and not tip:find("/dance", 1, true)
        and not tip:find(L.HINT_HUB_MENU, 1, true), "a macro's own tooltip isn't shown in place of its commands, or it "
        .. "says its right-click opens the hub menu")
    -- its buttons' descriptions on one line by their icons, left then right, over its type
    expect(F.tooltip.lines[#F.tooltip.lines - 1]
        == string.format(L.HINT_LEFT, "Danser") .. " · " .. string.format(L.HINT_RIGHT, "S'asseoir"),
        "a macro's tooltip doesn't say what its buttons do, left then right, over its type: " .. tip)
    F.RunScript(eb, "OnLeave")
    -- open, the HUD arranged: its right-click is the hub menu's, nothing run, its description not said
    Hub.SetLocked(false)
    F.RunTimers()
    F.ranMacros, F.lastMenu = {}, nil
    click(emote, "RightButton")
    expect(#F.ranMacros == 0 and F.MenuItem(L.MACRO_EDIT) and eb:GetAttribute("*type2") == nil,
        "open, a macro's own right-click runs its commands, or doesn't open its hub menu")
    GameTooltip:Hide()
    F.RunScript(eb, "OnEnter")
    tip = table.concat(F.tooltip.lines, "\n")
    expect(has(string.format(L.HINT_LEFT, "Danser")) and has(L.HINT_HUB_MENU)
        and not tip:find(string.format(L.HINT_RIGHT, "S'asseoir"), 1, true),
        "open, a macro's tooltip says its right-click does what it doesn't then: " .. tip)
    F.RunScript(eb, "OnLeave")
    Hub.SetLocked(true)
    F.RunTimers()
    -- the game's macro on its left button: its right-click runs its own commands, never that macro
    Editor.Open(emote)
    run(F.MenuItem("Monture", F.DropdownMenu(ed.Runs)).choose, F.MenuItem("Monture", F.DropdownMenu(ed.Runs)).data)
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    F.ranMacros = {}
    click(emote, "RightButton")
    expect(F.ranMacros[1] and F.ranMacros[1].text == "/sit" and F.ranMacros[1].macro == nil,
        "with the game's macro on its left, a macro's right-click runs that macro")
    -- its own commands again, no tooltip of its own: its commands, then its right-click's under « Clic droit : »
    Editor.Open(emote)
    F.MenuItem(L.MACRO_OWN, F.DropdownMenu(ed.Runs)).choose()
    F.Type(ed.Tip, "")
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    GameTooltip:Hide()
    F.RunScript(eb, "OnEnter")
    tip = table.concat(F.tooltip.lines, "\n")
    expect(Macros.Get(emote).tip == nil and tip:find("/dance", 1, true) and tip:find(L.MACRO_RIGHT_LABEL, 1, true)
        and tip:find("/sit", 1, true), "a macro's tooltip doesn't show its commands then its right-click's")
    F.RunScript(eb, "OnLeave")

    -- Copied, then pasted on the bar and in a folder: the same commands, its right-click's too, a new button each. Its
    -- menu while the padlock is open: shut, its right-click is its own.
    Hub.SetLocked(false)
    click(emote, "RightButton")
    run(F.MenuItem(ns.G("CALENDAR_COPY_EVENT", "Copier")).choose)
    Hub.SetLocked(true)
    F.RunTimers()
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    local paste = F.MenuItem(string.format(L.MACRO_PASTE, "Salut"))
    expect(paste and paste:IsEnabled(), "the bar's menu doesn't paste a copied macro")
    if paste then
        run(paste.choose)
    end
    F.RunTimers()
    local onBar = Macros.List()[#Macros.List()]
    expect(onBar ~= emote and Macros.Get(onBar).text == "/dance" and Macros.Get(onBar).right == "/sit"
        and Macros.Get(onBar).leftDesc == "Danser" and Macros.Get(onBar).rightDesc == "S'asseoir"
        and Hub.Entry(onBar).side == "right"
        and Buttons.Get(onBar) and Buttons.Get(onBar):IsShown() and Buttons.Get(onBar) ~= eb,
        "a pasted macro isn't a new one at the bar's right end")
    click(folder, "RightButton")
    paste = F.MenuItem(string.format(L.MACRO_PASTE, "Salut"))
    if paste then
        run(paste.choose)
    end
    F.RunTimers()
    local inFolder = Hub.InFolder(folder)
    expect(#inFolder == 3 and Macros.Get(inFolder[3].name).text == "/dance", "a macro pasted in a folder isn't its last")
    -- A new one from a folder's menu: in it, its editor open.
    click(folder, "RightButton")
    run(F.MenuItem(L.MACRO_CREATE).choose)
    F.RunTimers()
    inFolder = Hub.InFolder(folder)
    local fresh = inFolder[4] and inFolder[4].name
    expect(fresh and Macros.Get(fresh).name == L.MACRO_NEW and Editor.Current() == fresh
        and Buttons.Get(fresh):GetAttribute("*type1") == nil, "a new macro isn't in its folder, its editor open, running nothing")
    ed:Hide()
    -- Deleted: gone, its button running nothing.
    for _, id in ipairs({ fresh, onBar, inFolder[3].name }) do
        Macros.AskDelete(id)
        F.AcceptPopup()
    end
    F.RunTimers()
    expect(#Hub.InFolder(folder) == 2 and not Macros.Get(onBar) and not Buttons.Get(onBar):IsShown()
        and Buttons.Get(onBar):GetAttribute("*type1") == nil, "a deleted macro stays, or its button still runs")
    -- put away
    click(folder, "LeftButton")
    F.RunTimers()
    expect(#F.blocked == blocked, "the game blocked the hub: " .. table.concat(F.blocked, ", ", blocked + 1))
    expect(#F.snippetErrors == 0, "a secure snippet failed: " .. table.concat(F.snippetErrors, ", "))
    Macros.Delete(emote)
    Macros.Delete(voice)
    Folders.Delete(folder)
    F.RunTimers()
end

-- ---------- The bar's other items, their folders, separators and notes ----------
-- Ikar 2026-11-16, his list: each item read from the game, standing in the folder made for it (its role), its icon
-- alone on its button at the bar's left side, its list of icons with their text running down; a separator a rule in
-- its column; the macro's icon picked from its menu as a folder's; a note runs nothing.
-- What the blocks of the bar's other items share: its folders and macros, the errors the session keeps, an item's text,
-- a folder's members.
local Folders, Macros, Editor, Picker, Separators = ns.Folders, ns.Macros, ns.MacroEditor, ns.IconPicker, ns.Separators
local function errors()
    local n = 0
    for _ in pairs(KaLiHUDDevDB.errors or {}) do
        n = n + 1
    end
    return n
end
local function text(name)
    local b = Buttons.Get(name)
    return b and F.Shows(b):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or nil
end
local function names(id)
    local list = {}
    for _, e in ipairs(Hub.InFolder(id)) do
        list[#list + 1] = e.isSeparator and "|" or e.name:gsub("^KaLiHUD_", "")
    end
    return table.concat(list, " ")
end
do
    local before = errors()
    -- the folders, each once, at the bar's left side
    local roles = { "weapons", "professions", "stats", "reagents", "statistics", "guild", "group", "session", "infos",
        "reputations" }
    local made = 0
    for _, role in ipairs(roles) do
        local id = Folders.ByRole(role)
        if id and Hub.Entry(id).side == "left" and Folders.Setting(id, "iconOnly") and Folders.Setting(id, "style") == "text"
            and Folders.Setting(id, "flow") == "vertical" then
            made = made + 1
        end
    end
    expect(made == #roles, "the bar's folders aren't each made once at its left side: " .. made)
    local count = #Folders.List()
    ns.Seeds.Run()
    F.RunTimers()
    expect(#Folders.List() == count, "a folder made for the bar is made again while it's there")
    -- nine to a column, the emotes eleven, the reputations twelve; locked (UI/Hub/Seeds.lua), a count changed under
    -- one (an earlier build's, a file edited by hand) made back at the next login, with no mark of its own
    local per = 0
    for _, role in ipairs(roles) do
        per = per + (Folders.Setting(Folders.ByRole(role), "perLine") == (role == "reputations" and 12
            or role == "stats" and ns.Seeds.STATS_PER_LINE or 9) and 1 or 0)
    end
    expect(per == #roles and Folders.Setting(Folders.ByRole("emotes"), "perLine") == 11,
        "the bar's folders aren't nine to a column, the emotes eleven, the reputations twelve, the attributes "
        .. ns.Seeds.STATS_PER_LINE .. ": " .. per)
    Folders.Get(Folders.ByRole("weapons")).perLine = nil
    Folders.Get(Folders.ByRole("guild")).perLine = 3
    ns.Seeds.Run()
    F.RunTimers()
    expect(Folders.Setting(Folders.ByRole("weapons"), "perLine") == 9 and Folders.Setting(Folders.ByRole("guild"), "perLine") == 9,
        "a locked folder's count changed under it isn't made back at the next login")
    -- an icon alone on its button: its name on hover
    local weapons = Folders.ByRole("weapons")
    F.RunScript(Buttons.Get(weapons), "OnEnter")
    expect(F.tooltip.shown and F.tooltip.lines[1] == L.FOLDER_WEAPONS, "a folder with its icon alone has no name on hover")
    F.RunScript(Buttons.Get(weapons), "OnLeave")
    -- one with its name by its icon too (Ikar 2026-11-20, of « Emote »: "Social folder has no tooltip")
    do
        local emotesId = Folders.ByRole("emotes")
        F.RunScript(Buttons.Get(emotesId), "OnEnter")
        expect(Hub.Object(emotesId).text ~= nil and F.tooltip.shown and F.tooltip.lines[1] == Folders.Get(emotesId).name,
            "a folder with its name by its icon has no tooltip")
        F.RunScript(Buttons.Get(emotesId), "OnLeave")
    end
    -- What a click opens takes the tooltip away (Ikar 2026-11-18: "when opening anything, the tooltip should
    -- disappear"): a folder's list, none on its button while it's open; one of ours opening a pane; Blizzard's calendar,
    -- its own rebuilding of its tooltip not bringing it back. One whose click opens nothing (the memory) keeps it.
    do
        local wb = Buttons.Get(weapons)
        F.RunScript(wb, "OnEnter")
        click(weapons, "LeftButton")
        local folder = Folders.IsOpen(weapons) and not F.tooltip.shown and not GameTooltip:IsOwned(wb)
        F.RunScript(wb, "OnEnter")
        folder = folder and not F.tooltip.shown
        click(weapons, "LeftButton")
        F.RunScript(wb, "OnLeave")
        expect(folder and not Folders.IsOpen(weapons), "a folder's tooltip stays over its open list, or comes back on it")
        local gold = Buttons.Get("KaLiHUD_Gold")
        F.RunScript(gold, "OnEnter")
        local shown = F.tooltip.shown
        click("KaLiHUD_Gold", "LeftButton")
        expect(shown and not F.tooltip.shown and not GameTooltip:IsOwned(gold), "the gold's tooltip stays once its pane opens")
        F.RunScript(gold, "OnLeave")
        F.RunScript(GameTimeFrame, "OnEnter")
        F.RunScript(GameTimeFrame, "OnUpdate")
        shown = F.tooltip.shown
        F.Press(GameTimeFrame, "LeftButton")
        F.RunScript(GameTimeFrame, "OnUpdate")
        expect(shown and not F.tooltip.shown and not GameTooltip:IsOwned(GameTimeFrame),
            "the calendar button's tooltip stays once the calendar opens")
        F.RunScript(GameTimeFrame, "OnLeave")
        local perf = Buttons.Get("KaLiHUD_Performance")
        F.RunScript(perf, "OnEnter")
        click("KaLiHUD_Performance", "LeftButton")
        expect(F.tooltip.shown and GameTooltip:IsOwned(perf) and has(L.HINT_PERF),
            "the memory's tooltip goes on a click that opens nothing")
        F.RunScript(perf, "OnLeave")
    end
    expect(errors() == before, "an error in the bar's folders: " .. tostring(next(KaLiHUDDevDB.errors or {})))
end

do
    local before = errors()
    local weapons = Folders.ByRole("weapons")
    -- skills: weapons with defence, professions with secondary skills; one of a single rank in none
    expect(names(weapons) == "Skill_43 Skill_95", "the weapon skills' folder: " .. names(weapons))
    local professions = Folders.ByRole("professions")
    expect(names(professions) == "Skill_186 Skill_356", "the professions' folder: " .. names(professions))
    expect(text("KaLiHUD_Skill_43") == "Épées 120+5/150" and text("KaLiHUD_Skill_95") == "Défense 140+3/150",
        "a weapon skill's rank: " .. tostring(text("KaLiHUD_Skill_43")) .. ", " .. tostring(text("KaLiHUD_Skill_95")))
    table.insert(F.skills, 3, { skillID = 173, name = "Dagues", rank = 1, maxRank = 150, cat = 6 })
    F.Fire("SKILL_LINES_CHANGED")
    F.RunTimers()
    expect(names(weapons) == "Skill_43 Skill_95 Skill_173", "a skill learnt isn't in its folder: " .. names(weapons))
    table.remove(F.skills, 3)
    F.Fire("SKILL_LINES_CHANGED")
    F.RunTimers()
    expect(names(weapons) == "Skill_43 Skill_95" and not Hub.Entry("KaLiHUD_Skill_173"), "a skill unlearnt stays")
    -- a weapon skill's chances as the Skills tab gives them (the review of 2026-11-21): against an enemy of the
    -- character's level (23, a defence of 115 against the swords' 125: +0.40 %), against a raid boss (315: -7.60 %),
    -- its glancing blows by the game's calls (40 %, 35 % less); the defence none
    do
        F.RunScript(Buttons.Get("KaLiHUD_Skill_43"), "OnEnter")
        local sword = table.concat(F.tooltip.lines, "\n")
        F.RunScript(Buttons.Get("KaLiHUD_Skill_43"), "OnLeave")
        F.RunScript(Buttons.Get("KaLiHUD_Skill_95"), "OnEnter")
        local defense = table.concat(F.tooltip.lines, "\n")
        F.RunScript(Buttons.Get("KaLiHUD_Skill_95"), "OnLeave")
        local same, boss = "+" .. ns.Format.PercentOf(0.4, 2), "-" .. ns.Format.PercentOf(7.6, 2)
        expect(sword:find(WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER, 1, true)
            and sword:find(string.format(WEAPON_SKILL_DETAIL_SAME_LEVEL, same, same), 1, true)
            and sword:find(WEAPON_SKILL_DETAIL_BOSS_HEADER, 1, true)
            and sword:find(string.format(WEAPON_SKILL_DETAIL_BOSS, boss, boss, ns.Format.Percent(0.4),
                ns.Format.Percent(0.35)), 1, true)
            and not defense:find(WEAPON_SKILL_DETAIL_BOSS_HEADER, 1, true),
            "a weapon skill's tooltip doesn't give the Skills tab's chances: " .. sword .. " / " .. defense)
    end
    click("KaLiHUD_Skill_356", "LeftButton")
    expect(F.toggled.professions == 1, "a profession's click doesn't open the professions book")
    F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnEnter")
    -- Westfall's, as Forever's Group Finder suggests them (Data/Zones.lua), not Classic's 10-20
    expect(table.concat(F.tooltip.lines, "\n"):find("8-24", 1, true), "fishing's tooltip doesn't give the zone's levels")
    F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnLeave")
    -- Where a cast lands (Ikar 2026-11-18: "Go for it, but don't show a line, add a question mark icon"), from the
    -- original game's bases (Data/Fishing.lua), at 30: Westfall's 1-75, some landing; Elwynn's 1-25, every one, green;
    -- a sub-zone's own by the name the game gives its area (Azshara's Bay of Storms, 330-425, none, red), Azshara's
    -- elsewhere, and that name in another zone its zone's; a dungeon's by its instance, over the map's (the
    -- Deadmines'); one of Forever's own zones (Riverglades), a question mark, no dash.
    run(function()
        local fishing = Buttons.Get("KaLiHUD_Skill_356")
        local said = {}
        local function here(map, sub, instance)
            F.mapID, F.subZone, F.instance = map, sub, instance
            F.RunScript(fishing, "OnEnter")
            local found
            for i, line in ipairs(F.tooltip.lines) do
                if line == L.FISHING_HERE then
                    found = F.tooltip.lines[i + 1]
                end
            end
            said[map or 0] = table.concat(F.tooltip.lines, " | ")
            F.RunScript(fishing, "OnLeave")
            F.mapID, F.subZone, F.instance = nil, nil, nil
            return tostring(found)
        end
        local areaInfo = C_Map.GetAreaInfo
        C_Map.GetAreaInfo = function(id)
            return id == 1227 and "Baie des Tempêtes" or areaInfo(id)
        end
        local GOOD, BAD, Color = ns.Infos.GOOD, ns.Infos.BAD, ns.Infos.Color
        local westfall, elwynn = here(), here(1429)
        local bay, azshara = here(1447, "Baie des Tempêtes"), here(1447, "Valormok")
        local elsewhere = here(1436, "Baie des Tempêtes")
        local deadmines = here(1447, nil, { "Les Mortemines", "party", 36 })
        local riverglades = here(2548)
        C_Map.GetAreaInfo = areaInfo
        expect(westfall == "1-75" and elwynn == Color("1-25", GOOD), "fishing here: " .. westfall .. ", " .. elwynn)
        expect(bay == Color("330-425", BAD) and azshara == Color("205-300", BAD) and elsewhere == "1-75",
            "a sub-zone's own fishing isn't read, or read in another zone: " .. bay .. ", " .. azshara .. ", "
            .. elsewhere)
        expect(deadmines == "1-75", "a dungeon's fishing isn't its instance's: " .. deadmines)
        expect(riverglades == "|A:UI-LFG-PendingMark:0:0|a"
            and said[2548]:find(riverglades .. " " .. L.FISHING_WHY, 1, true) ~= nil
            and not said[1436]:find(L.FISHING_WHY, 1, true),
            "an unknown zone's fishing isn't a question mark, or doesn't say what it asks: " .. said[2548])
    end)
    -- A skill's bonus says where it comes from, as an attribute's (Ikar 2026-11-18: "for fishing, I see only bonus +5,
    -- not the source"): the rod's own line, a lure on it for a while, the gloves' enchantment, by the game's data; what
    -- nothing names « Autres ».
    run(function()
        local fishing
        for _, s in ipairs(F.skills) do
            if s.skillID == 356 then
                fishing = s
            end
        end
        local function sourced(name, amount)
            local lines = F.tooltip.lines
            for i, line in ipairs(lines) do
                if line:find(name, 1, true) and lines[i + 1] and lines[i + 1]:find(amount, 1, true) then
                    return true
                end
            end
            return false
        end
        fishing.modifier = 32
        F.itemLines[16] = { "Équiper\194\160: pêche augmentée de 5." }
        F.weaponEnchants[0] = { { hasEnchant = true, enchantType = 2, enchantID = 263 } }
        F.enchants[10], F.enchantLines[10] = 846, "Pêche +2"
        F.Fire("SKILL_LINES_CHANGED")
        F.RunTimers()
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnEnter")
        local all = table.concat(F.tooltip.lines, " | ")
        -- the enchantments by their slot (Ikar 2026-11-19: "Enchantement (bracelet) + 4, no full name of the item")
        local gloves = string.format(L.STAT_ENCHANT, ns.G("HANDSSLOT", "Hands"))
        local lure = string.format(L.STAT_ENCHANT, ns.G("MAINHANDSLOT", "Main Hand"))
        expect(sourced("Objet 16", "+5") and sourced(gloves, "+2") and sourced(lure, "+25")
            and not all:find(L.STAT_OTHER, 1, true), "fishing's bonus doesn't name the rod, the lure and the gloves: " .. all)
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnLeave")
        fishing.modifier = 35
        F.Fire("SKILL_LINES_CHANGED")
        F.RunTimers()
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnEnter")
        expect(sourced(L.STAT_OTHER, "+3"), "what nothing names of a skill's bonus isn't « Autres »: "
            .. table.concat(F.tooltip.lines, " | "))
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnLeave")
        -- a source the game gives no amount of wears the question mark there too, and the tooltip says what it means
        -- (Ikar 2026-11-19: "no lying"; the review of 2026-11-19: the mark came with no word of it under a skill)
        local firstAura = F.auras.HELPFUL[1]
        ns.EFFECTS[999002] = "1,1;30:356:0:0:"
        F.auras.HELPFUL[1] = { name = "Appât inconnu", spellId = 999002 }
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnEnter")
        all = table.concat(F.tooltip.lines, " | ")
        local marked = sourced("Appât inconnu", ns.Stats.UNKNOWN)
        F.RunScript(Buttons.Get("KaLiHUD_Skill_356"), "OnLeave")
        F.auras.HELPFUL[1], ns.EFFECTS[999002] = firstAura, nil
        expect(marked and all:find(ns.Stats.UNKNOWN .. " " .. string.format(L.STAT_WHY_CASTER, "Appât inconnu"), 1,
            true), "a skill's source of unknown amount hasn't the mark, or its tooltip doesn't say what it asks: " .. all)
        fishing.modifier = nil
        F.itemLines[16], F.weaponEnchants[0], F.enchants[10], F.enchantLines[10] = nil, nil, nil, nil
        F.Fire("SKILL_LINES_CHANGED")
        F.RunTimers()
    end)
    expect(errors() == before, "an error in the skills' items: " .. tostring(next(KaLiHUDDevDB.errors or {})))
end

do
    local before = errors()
    -- attributes: the sheet's, its categories apart; buffed green; hidden in a fight, they keep their last text
    local stats = Folders.ByRole("stats")
    local sheet = "^| Attr_HEALTH Attr_POWER Attr_MOVESPEED | Attr_STRENGTH Attr_AGILITY Attr_STAMINA Attr_INTELLECT "
        .. "Attr_SPIRIT | Attr_MAINHAND_DAMAGE"
    local sheetEnd = "Attr_REGEN | Attr_DEFENSE Attr_DODGE Attr_BLOCK Attr_BLOCKVALUE Attr_PARRY Attr_ARMOR "
        .. "Attr_ARMORCUT Attr_MISSED Attr_AVOIDANCE Attr_CRITTAKEN | Attr_SPELLHEALING Attr_HEALDONE Attr_HEALTAKEN Attr_HEALTAKEN_FLAT | Attr_SPELLPOWER_ARCANE Attr_SPELLPOWER_FIRE "
        .. "Attr_SPELLPOWER_FROST Attr_SPELLPOWER_NATURE Attr_SPELLPOWER_SHADOW Attr_SPELLPOWER_HOLY | Attr_ARCANE "
        .. "Attr_FIRE Attr_FROST Attr_NATURE Attr_SHADOW$"
    expect(names(stats):find(sheet) and names(stats):find(sheetEnd), "the attributes' folder: " .. names(stats))
    -- the sheet's: defence out of the level's most, a resistance raised green with its school's icon, its spell
    -- power's (Ikar 2026-11-23: "why spell damage and resistance have different icons ?"), the speed one can go
    expect(text("KaLiHUD_Attr_DEFENSE") == ns.G("DEFENSE", "Defense") .. " 143 / 115",
        "defence isn't the sheet's: " .. tostring(text("KaLiHUD_Attr_DEFENSE")))
    local fire = Buttons.Get("KaLiHUD_Attr_FIRE")
    expect(fire and F.Shows(fire):find("25", 1, true) and F.Shows(fire):find(ns.Infos.GOOD, 1, true)
        and Hub.Object("KaLiHUD_Attr_FIRE").icon == "Interface\\PaperDollInfoFrame\\SpellSchoolIcon3"
        and Hub.Object("KaLiHUD_Attr_SPELLPOWER_FIRE").icon == Hub.Object("KaLiHUD_Attr_FIRE").icon
        and not Hub.Object("KaLiHUD_Attr_FIRE").atlas,
        "a resistance raised isn't green, or has not its school's spell power's icon: " .. tostring(fire and F.Shows(fire)))
    local moving = ns.G("STAT_MOVEMENT_SPEED", "Movement Speed")
    F.speed = 0
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
    expect(text("KaLiHUD_Attr_MOVESPEED") == moving .. " " .. ns.Format.Percent(1),
        "standing still, the movement speed isn't the running one: " .. tostring(text("KaLiHUD_Attr_MOVESPEED")))
    F.swimming = true
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
    expect(text("KaLiHUD_Attr_MOVESPEED") == moving .. " " .. ns.Format.Percent(4.72 / 7),
        "in the water, the movement speed isn't the swimming one: " .. tostring(text("KaLiHUD_Attr_MOVESPEED")))
    F.swimming, F.speed = false, nil
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
    -- an attributes' folder as an earlier build left it (the bar's speed in the sheet's place, a separator, the
    -- resistances, two schools' spell power, the health's regeneration and the block value gone, an old single spell
    -- power in it): the next login makes it as the code does, locked (UI/Hub/Seeds.lua), with no mark of its own; the
    -- bar's speed, which isn't the folder's, goes where it goes with no place saved
    local items = ns.db.items
    local made = names(stats)
    items.KaLiHUD_Speed = { side = "folder", folder = stats, order = items.KaLiHUD_Attr_MOVESPEED.order }
    items.KaLiHUD_Attr_SPELLPOWER = { side = "folder", folder = stats, order = items.KaLiHUD_Attr_REGEN.order + 1 }
    for id in pairs(ns.db.separators) do
        local e = items[id]
        if e and e.folder == stats and e.order > items.KaLiHUD_Attr_CRITTAKEN.order then
            Separators.Drop(id)
            break
        end
    end
    for _, key in ipairs({ "MOVESPEED", "ARCANE", "FIRE", "FROST", "NATURE", "SHADOW", "SPELLPOWER_HOLY",
        "SPELLPOWER_ARCANE", "HEALTH_REGEN", "BLOCKVALUE" }) do
        items["KaLiHUD_Attr_" .. key] = nil
    end
    Hub.Changed()
    local old = names(stats)
    ns.Seeds.Run()
    F.RunTimers()
    expect(names(stats) == made and old ~= made and names(stats):find(sheet) and names(stats):find(sheetEnd)
        and Hub.Entry("KaLiHUD_Speed").side == "hidden",
        "an attributes' folder an earlier build left isn't made as the code makes it at the next login: " .. names(stats))
    local strength = Buttons.Get("KaLiHUD_Attr_STRENGTH")
    expect(strength and F.Shows(strength):find("110", 1, true) and F.Shows(strength):find(ns.Infos.GOOD, 1, true),
        "strength buffed isn't green: " .. tostring(strength and F.Shows(strength)))
    expect(text("KaLiHUD_Attr_MAINHAND_DAMAGE"):find("41 - 64", 1, true), "main hand: " .. tostring(text("KaLiHUD_Attr_MAINHAND_DAMAGE")))
    -- the sheet's hit chance: the best of melee, off hand, ranged and spells, one decimal
    -- (the numeral after it: its spells' 4.5 % never miss an enemy of the character's level, I)
    expect(text("KaLiHUD_Attr_HITCHANCE") == ns.G("STAT_HIT_CHANCE", "Hit") .. " " .. ns.Format.PercentOf(4.5, 1) .. " I",
        "the hit chance isn't the sheet's: " .. tostring(text("KaLiHUD_Attr_HITCHANCE")))
    -- a buff's change read at once: a chance changes with no other event than the auras'
    local critChance = GetCritChance
    GetCritChance = function()
        return 12.5
    end
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
    expect(text("KaLiHUD_Attr_CRITCHANCE") == ns.G("STAT_CRITICAL_STRIKE", "Critical Strike") .. " "
        .. ns.Format.PercentOf(12.5, 1), "a buff's critical strike isn't read: " .. tostring(text("KaLiHUD_Attr_CRITCHANCE")))
    GetCritChance = critChance
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
    -- on hover, the sheet's base and changes: strength 110 (105+5), the attack power, defence, armour and fire raised,
    -- a weapon's damage by its bonus and multiplier; nothing after one unchanged
    local GOOD, Number = ns.Infos.GOOD, ns.Format.Number
    -- the attributes' card, as a hover on the element draws it (Ikar 2026-11-19: "Go with card 1"): its head, then its
    -- columns' texts in the order drawn, its foot's hints left out
    local function tip(name)
        run(Hub.Object(name).OnEnter, Buttons.Get(name) or UIParent)
        return table.concat((ns.StatCard.Lines()), "\n")
    end
    local function base(n, raise)
        return " (" .. Number(n) .. ns.Infos.Color("+" .. Number(raise), GOOD) .. ")"
    end
    for name, parts in pairs({ STRENGTH = base(105, 5), ATTACK_AP = base(269, 20), DEFENSE = base(140, 3),
        ARMOR = base(1200, 140), FIRE = base(10, 15) }) do
        expect(tip("KaLiHUD_Attr_" .. name):find(parts, 1, true), "the hover of " .. name .. " hasn't the sheet's base: "
            .. tip("KaLiHUD_Attr_" .. name))
    end
    -- (no raise in green: its levels' row writes its sum in brackets, « Niveaux 2 à 23 (… - … - …) »)
    expect(not tip("KaLiHUD_Attr_AGILITY"):find("|c" .. GOOD .. "+", 1, true), "an unchanged attribute's hover has changes: "
        .. tip("KaLiHUD_Attr_AGILITY"))
    local unitDamage = UnitDamage
    UnitDamage = function()
        return 45, 75, 0, 0, 4, 0, 1.25
    end
    local hit = " (32 - 56" .. ns.Infos.Color(" +4", GOOD) .. ns.Infos.Color(" x" .. ns.Format.Percent(1.25), GOOD) .. ")"
    expect(tip("KaLiHUD_Attr_MAINHAND_DAMAGE"):find(hit, 1, true), "a weapon's hover hasn't the sheet's base damage: "
        .. tip("KaLiHUD_Attr_MAINHAND_DAMAGE"))
    -- the card as wide as its head needs (the review of 2026-11-19): a weapon's damage and its changes, longer than a
    -- column, don't run into its name
    expect(KaLiHUDStatCard:GetWidth() >= #table.concat((ns.StatCard.Lines()), "", 1, 3) * 6,
        "a weapon's card is narrower than its name, its damage and its changes: " .. tostring(KaLiHUDStatCard:GetWidth()))
    UnitDamage = unitDamage
    -- A value's base, named after where it comes from (Stats.lua's baseName and levelAP; Ikar 2026-11-21: "each base
    -- need to be explained", "lvl can be a source on it own, like intel"): the fake's level-23 human warrior's (on
    -- F, the file's locals at their most).
    -- What levels 2 to 23 have added, its sum beside it (Ikar 2026-11-23: "I told you to mark any formulas no ?"); a
    -- figure the card works out from what the game doesn't give, with the question mark (`asks`).
    F.BASE = {
        level = function(how)
            return string.format(ns.G("UNIT_LEVEL_TEMPLATE", "Level %d"), 23) .. " (" .. how .. ")"
        end,
        levels = function(how)
            return string.format(ns.G("UNIT_LEVEL_TEMPLATE", "Level %d"), 23) .. " (" .. how .. ")"
        end,
        asks = function(figure)
            return figure .. " " .. ns.Stats.UNKNOWN
        end,
        class = "Guerrière",
        classLevel = string.format(ns.G("UNIT_TYPE_LEVEL_TEMPLATE", "Level %d %s"), 23, "Guerrière"),
        all = string.format(ns.G("UNIT_TYPE_LEVEL_TEMPLATE", "Level %d %s"), 23, "Humaine Guerrière"),
        levelName = string.format(ns.G("UNIT_LEVEL_TEMPLATE", "Level %d"), 23),
    }
    -- Where the changes come from (Ikar 2026-11-16: "there is no list of modificators on each, from where the +10 or -2
    -- come from"): each item that carries some, in its quality's colour; each buff and debuff whose spell changes it
    -- (Data/Effects.lua, the game's data), by its points or its share and what that comes to; what's left, "Others".
    run(function()
        local BAD, Color, GREEN = ns.Infos.BAD, ns.Infos.Color, ITEM_QUALITY_COLORS[2].hex
        local function has(name, ...)
            local t = tip("KaLiHUD_Attr_" .. name)
            for i = 1, select("#", ...) do
                if not t:find((select(i, ...)), 1, true) then
                    return false, t
                end
            end
            return true, t
        end
        -- strength 110 (105+5): an item's +3, Strength of Earth's +2 (an area aura's points), nothing left
        F.itemStats[1], F.itemQuality[1] = { ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 7 }, 2
        F.auras.HELPFUL[1] = { name = "Force de la Terre", spellId = 8076, points = { 2 } }
        F.auras.HELPFUL[2] = { name = "Sans effet", spellId = 1, points = { 9 } }
        local ok, t = has("STRENGTH", GREEN .. "Objet 1|r", Color("+3", GOOD), "Force de la Terre", Color("+2", GOOD))
        expect(ok and not t:find(L.STAT_OTHER, 1, true) and not t:find("Sans effet", 1, true),
            "a buffed attribute's hover doesn't name its item and its buff, or names what doesn't change it: " .. t)
        -- the buff giving less: the point left, "Others"
        F.auras.HELPFUL[1].points = { 1 }
        ok, t = has("STRENGTH", L.STAT_OTHER, Color("+1", GOOD))
        expect(ok, "what no item nor aura gives isn't named as left: " .. t)
        -- a debuff: intelligence 26 (30 -4), Stupidity's -4 in red; strength's item not there
        local unitStat = UnitStat
        UnitStat = function(unit, i)
            if i == 4 then
                return 26, 26, 0, -4
            end
            return unitStat(unit, i)
        end
        F.auras.HARMFUL[1] = { name = "Stupidité", spellId = 457, points = { -4 } }
        ok, t = has("INTELLECT", "Stupidité", Color("-4", BAD))
        expect(ok and not t:find("Objet 1", 1, true) and not t:find(L.STAT_OTHER, 1, true),
            "a debuffed attribute's hover doesn't name its debuff, or names another's item: " .. t)
        -- a share of the whole: strength 121 (100+21), an item's +10, Blessing of Kings' +10 % (+11), nothing left
        UnitStat = function(unit, i)
            if i == 1 then
                return 121, 121, 21, 0
            end
            return unitStat(unit, i)
        end
        F.itemStats[1].ITEM_MOD_STRENGTH_SHORT = 10
        F.auras.HELPFUL[1] = { name = "Bénédiction des rois", spellId = 20217, points = { 10 } }
        ok, t = has("STRENGTH", Color("+10", GOOD), "Bénédiction des rois",
            Color("+" .. ns.Format.Percent(0.1), GOOD) .. " (" .. Color("+11", GOOD) .. ")")
        expect(ok and not t:find(L.STAT_OTHER, 1, true), "a share of the whole isn't worked out: " .. t)
        -- an aura's points numbered by its spell's effects or by its auras alone (12166: its second effect its one aura)
        UnitStat = function(unit, i)
            if i == 1 then
                return 110, 110, 5, 0
            end
            return unitStat(unit, i)
        end
        F.itemStats[1].ITEM_MOD_STRENGTH_SHORT = nil
        local by = {}
        for _, points in ipairs({ { 0, 5 }, { 5 } }) do
            F.auras.HELPFUL[1] = { name = "Deuxième effet", spellId = 12166, points = points }
            by[#by + 1] = select(2, has("STRENGTH"))
        end
        expect(ns.EFFECTS[12166]:find("^2,1;29:0:1:0:") and by[1]:find(Color("+5", GOOD), 1, true) and by[1] == by[2]
            and not by[1]:find(L.STAT_OTHER, 1, true), "an aura's points aren't found by either numbering: " .. by[1]
            .. " / " .. by[2])
        -- the camp's benefits: hidden auras the game gives no addon, named by « Avantages du camp »'s own tooltip in the
        -- game's words, its no-break spaces and its "\r\n" (Ikar 2026-11-22: "we see it in avantages de feux de
        -- camps"); a row each, « Camp : » and the item's name (the same day: "camp: name of the item"), with the
        -- figures its line writes, the aura's own, not the data's (Ikar's incense candle at level 26 had been the
        -- data's +25, and « Autres -16 »). Strength 108 (100+8): the fish bowl's +8 % (+8), nothing left; the lute's +13
        -- with it, 122 (113 x 1.08), two rows; the lute at a low level, its line's +5, and the 9 of its resistances for
        -- the fire's, which its line doesn't write; « Autres » where the text is secret (a fight) or names none; in
        -- English, the English words
        do
            local before = UnitStat
            local camp = "Obtention des avantages de camp suivants\194\160:\r\n\r\n"
            local bowl = "Bocal à poisson\194\160: augmentation de toutes les caractéristiques de 8 %.\r\n\r\n"
            local function lute(armour, all, resists)
                return "Luth enchanté\194\160: Armure augmentée de " .. armour .. ", augmentation de toutes les"
                    .. " caractéristiques de " .. all .. " et de toutes les résistances de " .. resists .. ".\r\n\r\n"
            end
            local function camped(strength, says, name)
                UnitStat = function(unit, i)
                    if i == 1 then
                        return strength, strength, strength - 100, 0
                    end
                    return unitStat(unit, i)
                end
                F.auras.HELPFUL[1] = { name = "Avantages du camp", spellId = 1229741, auraInstanceID = 41, says = says }
                return has("STRENGTH", name or string.format(L.STAT_CAMP_PART, "Bocal à poisson"))
            end
            ok, t = camped(108, camp .. bowl)
            expect(ok and t:find(Color("+" .. ns.Format.Percent(0.08), GOOD) .. " (" .. Color("+8", GOOD) .. ")", 1,
                true) and not t:find(L.STAT_OTHER, 1, true), "the camp's fish bowl isn't named after the item: " .. t)
            ok, t = camped(122, camp .. lute(308, 13, 22) .. bowl, string.format(L.STAT_CAMP_PART, "Luth enchanté"))
            expect(ok and t:find(Color("+13", GOOD), 1, true) and t:find(string.format(L.STAT_CAMP_PART, "Bocal à poisson"), 1, true)
                and not t:find("Avantages du camp", 1, true) and not t:find(L.STAT_OTHER, 1, true),
                "the camp's lute and fish bowl aren't a row each: " .. t)
            ok, t = camped(105, camp .. lute(123, 5, 9), string.format(L.STAT_CAMP_PART, "Luth enchanté"))
            expect(ok and t:find(Color("+5", GOOD), 1, true) and not t:find(L.STAT_OTHER, 1, true),
                "the lute's figure isn't the one its line writes: " .. t)
            local fire = tip("KaLiHUD_Attr_FIRE")
            expect(fire:find(string.format(L.STAT_CAMP_PART, "Luth enchanté"), 1, true) and fire:find(Color("+9", GOOD), 1, true),
                "the lute's fire resistance, which its line doesn't write, isn't its resistances' 9: " .. fire)
            -- each line its own: one that writes no figure for the attributes takes none of the next line's, the data's
            -- 13 then (read as one, the lute's line took the bowl's 8)
            ok, t = camped(113, camp .. "Luth enchanté\194\160: Armure augmentée de 123.\r\n\r\n" .. bowl,
                string.format(L.STAT_CAMP_PART, "Luth enchanté"))
            expect(ok and t:find(string.format(L.STAT_CAMP_PART, "Luth enchanté") .. "\n" .. Color("+13", GOOD), 1, true)
                and t:find(Color("+" .. ns.Format.Percent(0.08), GOOD) .. " (" .. Color("+8", GOOD) .. ")", 1, true),
                "a camp's line without a figure takes the next line's: " .. t)
            for _, says in ipairs({ F.SECRET, camp }) do
                ok, t = camped(108, says)
                expect(not ok and t:find(L.STAT_OTHER, 1, true),
                    "the camp's benefits are named from a text that names none: " .. t)
            end
            ns.LOCALE = "enUS"
            ok, t = camped(108, "Gained the following camp benefits:\r\n\r\nFish Bowl: All stats increased by 8%.\r\n\r\n",
                string.format(L.STAT_CAMP_PART, "Fish Bowl"))
            ns.LOCALE = "frFR"
            expect(ok and not t:find(L.STAT_OTHER, 1, true), "the camp's benefits aren't read in English: " .. t)
            UnitStat, F.auras.HELPFUL[1] = before, nil
        end
        -- the armour 1340: an item's bonus armour, Devotion Aura's, the agility's 160, what's left of the whole
        -- « Autres » 1075, the armour having no base of its own (Forever's own split of it is no base and changes:
        -- Ikar's screenshot of 2026-11-19, « Base -619 » and « Autres +619 »); a share of the whole (101: 20 %) worked
        -- out, what it comes to (223 of 1340) and what's left of the rest (the review of 2026-11-21: nothing had been)
        F.itemStats[2] = { ITEM_MOD_EXTRA_ARMOR_SHORT = 50 }
        F.auras.HELPFUL[1] = { name = "Aura de dévotion", spellId = 465, points = { 55, 0 } }
        ok, t = has("ARMOR", "Objet 2", Color("+50", GOOD), "Aura de dévotion", Color("+55", GOOD), L.STAT_OTHER,
            Color("+" .. Number(1075), GOOD))
        expect(ok, "the armour's hover doesn't name its sources: " .. t)
        local share
        for spell, effects in pairs(ns.EFFECTS) do
            if effects:find("^1,1;101:1:0:0:") then
                share = spell
            end
        end
        F.auras.HELPFUL[2] = { name = "Part d'armure", spellId = share, points = { 20 } }
        ok, t = has("ARMOR", "Part d'armure", Color("+" .. ns.Format.Percent(0.2), GOOD) .. " (" .. Color("+223", GOOD)
            .. ")", L.STAT_OTHER, Color("+852", GOOD))
        expect(share and ok, "a share of the armour isn't worked out, or what's left beside it not said: " .. t)
        -- Ikar 2026-11-17: "I don't see the effect of my elixirs and buffs". An elixir the game gives no points of: its own
        -- in the game's data (Elixir of the Arcane's +20 spell damage); one on fire alone, its school after its name; a
        -- value with no sum from the game (the spells' power) still names them, nothing left after
        local function find(pattern)
            for spell, effects in pairs(ns.EFFECTS) do
                local points = effects:match(pattern)
                if points then
                    return spell, tonumber(points)
                end
            end
        end
        local fire, firePoints = find("^1,1;13:4:0:0:(%d+)$")
        F.auras.HELPFUL[1] = { name = "Elixir des arcanes", spellId = 11390 }
        F.auras.HELPFUL[2] = { name = "Puissance de feu", spellId = fire, points = {} }
        -- each school's card its own (the review of 2026-11-23): the fire's the elixir's +20 and the fire one's, the
        -- frost's the elixir's alone, nothing left of either
        local bonusDamage = GetSpellBonusDamage
        GetSpellBonusDamage = function(school)
            return 20 + (school == 3 and (firePoints or 0) or 0)
        end
        ok, t = has("SPELLPOWER_FIRE", "Elixir des arcanes", Color("+20", GOOD), "Puissance de feu",
            Color("+" .. Number(firePoints or 0), GOOD))
        local frostOk, frost = has("SPELLPOWER_FROST", "Elixir des arcanes", Color("+20", GOOD))
        GetSpellBonusDamage = bonusDamage
        expect(fire and ok and frostOk and not t:find(L.STAT_OTHER, 1, true) and not t:find(L.STAT_ADDON_ERROR, 1, true)
            and not frost:find("Puissance de feu", 1, true) and not frost:find(L.STAT_OTHER, 1, true),
            "an elixir's spell damage isn't named on each school's card, or one of fire on the fire's alone: " .. t
            .. " / " .. frost)
        -- a chance: a buff's points of a percent, an item's rating as the sheet's share of a percent (10 points, 1 %)
        -- (the weapons' hit: the melee attacks' the best here, 3 %, the spells' modifier taken away)
        local hit, hitPoints = find("^1,1;54:0:0:0:(%d+)$")
        local spellHit = GetSpellHitModifier
        GetSpellHitModifier = function()
            return 0
        end
        F.auras.HELPFUL[1], F.auras.HELPFUL[2] = { name = "Toucher", spellId = hit }, nil
        F.itemStats[3], F.ratings[CR_HIT_MELEE] = { ITEM_MOD_HIT_RATING_SHORT = 10 }, 10
        ok, t = has("HITCHANCE", "Objet 3", Color("+" .. ns.Format.Percent(0.01), GOOD), "Toucher",
            Color("+" .. ns.Format.Percent((hitPoints or 0) / 100), GOOD))
        expect(hit and ok, "a hit buff or an item's hit rating isn't named as a chance: " .. t)
        -- a rating an aura gives (1299734: hit, 5 points, its mask the three hit ratings): worth what an item's is
        F.auras.HELPFUL[1] = { name = "Toucher en points", spellId = 1299734 }
        ok, t = has("HITCHANCE", "Toucher en points", Color("+" .. ns.Format.PercentOf(0.5, 1), GOOD))
        expect(ns.EFFECTS[1299734] == "1,1;189:224:0:0:5" and ok, "a rating an aura gives isn't named as a chance: " .. t)
        -- Ikar 2026-11-19: "the haste value seems doubled". The hit chance, the critical strike and the haste are the
        -- best of three, melee, ranged and spells, and a source counts for the one shown alone. With the spells' hit
        -- the best (4.5 %), a buff of the weapons' hit isn't one of its sources; one of both (13705) counts once
        GetSpellHitModifier = spellHit
        F.auras.HELPFUL[1] = { name = "Visée des armes", spellId = hit }
        F.auras.HELPFUL[2] = { name = "Précision", spellId = 13705, points = { 1, 1 } }
        ok, t = has("HITCHANCE", "Précision", Color("+" .. ns.Format.Percent(0.01), GOOD))
        expect(ns.EFFECTS[13705] == "2,2;54:0:0:0:1;55:0:1:1:1" and ok and not t:find("Visée des armes", 1, true)
            and not t:find(Color("+" .. ns.Format.Percent(0.02), GOOD), 1, true),
            "a source of the weapons' hit is named under the spells', or one of both counts twice: " .. t)
        F.ratings[CR_HIT_MELEE], F.itemStats[3] = nil, nil
        -- the haste: the troll's Berserker (20554) gives 10 % to melee, to ranged and to spells, three effects; 10 %
        -- once under the melee haste shown, not 20 nor 30; under the spells' haste when that's the best, a curse on
        -- casting alone (1714) too, which the melee haste doesn't name
        local meleeHaste, rangedHaste, spellHaste = GetMeleeHaste, GetRangedHaste, UnitSpellHaste
        GetMeleeHaste = function()
            return 10
        end
        GetRangedHaste = function()
            return 10, 0
        end
        F.auras.HELPFUL[1], F.auras.HELPFUL[2] = { name = "Berserker", spellId = 20554 }, nil
        F.auras.HARMFUL[1] = { name = "Malédiction des langages", spellId = 1714 }
        ok, t = has("HASTE", "Berserker", Color("+" .. ns.Format.Percent(0.1), GOOD),
            L.STAT_SOURCES .. " (" .. ns.G("MELEE", "Melee") .. ")")
        expect(ns.EFFECTS[20554] == "3,3;319:0:0:0:10;140:0:1:1:10;65:0:2:2:10" and ok
            and not t:find(ns.Format.Percent(0.2), 1, true) and not t:find(ns.Format.Percent(0.3), 1, true)
            and not t:find("Malédiction", 1, true),
            "a buff's melee haste and its ranged haste are added up, or the spells' is named with them: " .. t)
        UnitSpellHaste = function()
            return 15
        end
        ok, t = has("HASTE", "Berserker", Color("+" .. ns.Format.Percent(0.1), GOOD), "Malédiction des langages",
            Color("-" .. ns.Format.Percent(0.5), BAD), L.STAT_SOURCES .. " (" .. ns.G("SPELLS", "Spells") .. ")")
        expect(ok and not t:find(ns.Format.Percent(0.2), 1, true),
            "the spells' haste, the best, doesn't name what changes it alone: " .. t)
        -- what the haste gives, the sheet's own words, in the card's right column: each kind of attack's
        -- (as figures, each over the game's word for its kind of attack: Ikar 2026-11-19, "What about the other
        -- characteristics ?"); what it is in the middle one ("haste has no description"); and no rest beside its
        -- sources, the haste's changes multiplying, not adding up (a curse's -50 % had left « Autres +55 % »)
        local _, columns = ns.StatCard.Lines()
        expect(table.concat(columns, " ") == "sources about effects" and t:find(L.STAT_EFFECTS, 1, true)
            and not t:find(L.STAT_OTHER, 1, true)
            and t:find(ns.Format.PercentOf(10, 1) .. "\n" .. ns.G("MELEE", "Melee"), 1, true)
            and t:find(ns.Format.PercentOf(15, 1) .. "\n" .. ns.G("SPELLS", "Spells"), 1, true),
            "what the haste gives isn't said beside it: " .. t)
        GetMeleeHaste, GetRangedHaste, UnitSpellHaste = meleeHaste, rangedHaste, spellHaste
        F.auras.HARMFUL[1] = nil
        -- a buff whose points grow with the level, the game giving none on the aura: worked out as the server does
        -- (Ikar 2026-11-19: "the description should give an answer"): Battle Shout's 9, 0.3 a level from 1, its
        -- level counted up to 11: 12, unmarked
        F.auras.HELPFUL[1] = { name = "Cri de guerre", spellId = 6673 }
        ok, t = has("ATTACK_AP", "Cri de guerre", Color("+12", GOOD))
        expect(ns.EFFECTS[6673] == "1,1;99:0:0:0:9@0.30000001192,1,1,11" and ok and not t:find(ns.Stats.UNKNOWN, 1, true)
            and ns.Stats.FixedPoints("9@0.30000001192,1,1,11") == 12, "a buff growing with the level isn't worked "
            .. "out at the character's: " .. t)
        F.auras.HELPFUL[1] = { name = "Aura de dévotion", spellId = 465, points = { 55, 0 } }
        -- in a fight, none
        F.combat = true
        ok, t = has("ARMOR", "Objet 2")
        F.combat = false
        expect(not ok and t:find("1", 1, true), "a value's sources are named during a fight: " .. t)
        -- an unchanged one, none
        expect(not tip("KaLiHUD_Attr_AGILITY"):find("Objet", 1, true), "an unchanged attribute's hover names sources")
        UnitStat = unitStat
        F.itemStats, F.itemQuality, F.auras = {}, {}, { HELPFUL = {}, HARMFUL = {} }
        expect(errors() == before, "naming a value's sources errs")
    end)
    -- Ikar 2026-11-17: "Can we extend to include all sources?" What a value stands on (the attributes' share as the
    -- sheet works it out, the items' own armour, the rest « Base »), then the sources that aren't auras: the items'
    -- enchantments, the sets' bonuses, the talents at their rank, the race's and the class's passive spells, each only
    -- where what it needs is there; a spell met as an aura not named again. The spells, enchantments and sets are the
    -- game's own (Data/Effects.lua).
    run(function()
        local Color = ns.Infos.Color
        local function has(name, ...)
            local t = tip("KaLiHUD_Attr_" .. name)
            for i = 1, select("#", ...) do
                if not t:find((select(i, ...)), 1, true) then
                    return false, t
                end
            end
            return true, t
        end
        local function stat(i)
            return ns.G("SPELL_STAT" .. i .. "_NAME", ({ "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" })[i])
        end
        local function changed()
            F.Fire("TRAIT_CONFIG_UPDATED", 1)
            F.Fire("SPELLS_CHANGED")
        end
        -- the armour 1340: its agility's 160 (80, 2 a point), an item's own 300, what's left of the whole « Autres »
        -- 880
        F.itemStats[5] = { RESISTANCE0_NAME = 300 }
        local ok, t = has("ARMOR", stat(2), Number(160), "Objet 5", Number(300), L.STAT_OTHER,
            Color("+" .. Number(880), GOOD))
        expect(ok and not t:find("+" .. Number(160), 1, true),
            "the armour's base isn't its agility's, its items' own and the rest: " .. t)
        -- a share of the items' own armour (142, Dire Bear Form's 360 %), worked out: 1 080 of the item's 300, the
        -- armour 1 540 with the agility's 160, nothing left (the review of 2026-11-21: a bear's armour had been
        -- unexplained)
        do
            local unitArmor = UnitArmor
            UnitArmor = function()
                return 0, 1540, 1540, 0
            end
            F.itemStats[1] = nil
            F.auras.HELPFUL[1] = { name = "Forme d'ours redoutable", spellId = 9635, points = { 0, 360, 0, 0, 0, 0, 0 } }
            ok, t = has("ARMOR", "Forme d'ours redoutable", Color("+" .. ns.Format.Percent(3.6), GOOD) .. " ("
                .. Color("+" .. Number(1080), GOOD) .. ")")
            F.auras.HELPFUL[1] = nil
            UnitArmor = unitArmor
            expect(ok and not t:find(L.STAT_OTHER, 1, true),
                "a share of the items' own armour isn't worked out on them: " .. t)
        end
        F.itemStats[5] = nil
        -- the attack power 289 (269+20): its strength's 220 (2 a point), the level's 49 (3 a level less 20); health
        -- 1013, its stamina's 770 (the first 20 one each, 10 a point after), the game giving no sum of it; its base the
        -- original table's, the class's 20 at level 1 and the 223 levels 2 to 23 have given, before the stamina, nothing
        -- left (the review of 2026-11-19: its rows came short of it; Ikar 2026-11-24, the base split as the
        -- attributes'); the critical strike, the agility's 4 % and the intellect's 0.5 %, the rest the class's own
        ok, t = has("ATTACK_AP", stat(1), Number(220), (F.BASE.levelName .. " (x3)"), Number(69), L.STAT_BASE, Number(-20))
        expect(ok, "the attack power's base isn't its strength's and the level's: " .. t)
        ok, t = has("HEALTH", F.BASE.class, Number(20), F.BASE.levelName, Number(223), stat(3), Number(770))
        expect(ok and t:find(F.BASE.class, 1, true) < t:find(stat(3), 1, true) and not t:find(L.STAT_OTHER, 1, true),
            "health isn't the class's, the levels' and its stamina's, the base first: " .. t)
        -- (the sources' column alone: the column of what there is to know names the attributes too, by what a point
        -- of each gives)
        local function sourcesPart(text)
            local cut = text:find("\n" .. L.STAT_ABOUT, 1, true) or text:find("\n" .. L.STAT_EFFECTS, 1, true)
            return cut and text:sub(1, cut) or text
        end
        -- (the weapons' critical strike the best, 6.25 %: its agility's; the spells' the best: its intellect's)
        ok, t = has("CRITCHANCE", stat(2), ns.Format.Percent(0.04))
        local spellCrit = GetSpellCritChance
        GetSpellCritChance = function()
            return 20
        end
        local okSpells, spells = has("CRITCHANCE", stat(4), ns.Format.PercentOf(0.5, 1))
        GetSpellCritChance = spellCrit
        expect(ok and t:find(F.BASE.class .. "\n", 1, true) and not sourcesPart(t):find(stat(4), 1, true) and okSpells
            and not sourcesPart(spells):find(stat(2), 1, true),
            "the critical strike isn't its agility's, its intellect's and the rest: " .. t .. " / " .. spells)
        -- a value nothing changes still shows what it stands on: the ranged attack power 53, its agility's 40 and the
        -- level's 13, no rest, no mistake
        ok, t = has("RANGED_ATTACK_AP", stat(2), Number(40), (F.BASE.levelName .. " (x1)"), Number(23), L.STAT_BASE, Number(-10))
        expect(ok and not t:find(L.STAT_OTHER, 1, true) and not t:find(L.STAT_ADDON_ERROR, 1, true),
            "an unchanged value's base isn't shown, or has a rest: " .. t)
        -- what a point of an attribute gives, with what there is to know (Ikar 2026-11-19: "show the ratio"):
        -- strength, 2 attack power a point; a weapon's speed; a value nothing gives, at 0, says so (Ikar: "expertise
        -- is 0"); an item alone under its group's name, its icon before it (Ikar, of his mace's +3 defence named
        -- alone: "Unclear")
        local white = function(text)
            return Color(text, "ffffffff")
        end
        ok, t = has("STRENGTH", string.format(L.STAT_RATIO_POINT, stat(1), white("2") .. " "
            .. ns.G("STAT_ATTACK_POWER", "Attack Power")))
        expect(ok, "an attribute's card doesn't say what a point of it gives: " .. t)
        ok, t = has("MAINHAND_DAMAGE", L.STAT_ABOUT,
            string.format(ns.G("STAT_FORMAT", "%s:"), ns.G("ATTACK_SPEED_SECONDS", "Attack Speed (seconds)")))
        expect(ok, "a weapon's card doesn't say its speed: " .. t)
        ok, t = has("EXPERTISE", L.STAT_SOURCES, ns.G("NONE", "None"))
        expect(ok, "a value nothing gives doesn't say so: " .. t)
        -- every value has something to know (Ikar 2026-11-19: "haste has no description, other stats with no
        -- description ?"): the haste what it is, in the game's words; the armour penetration its second sentence;
        -- the defence where its « / 115 » comes from, the skill's most at level 23, and what the skill lacks of it
        -- (Ikar: "defense I have 113 / 115, where the 115 come from ?")
        ok, t = has("HASTE", L.STAT_ABOUT)
        expect(ok and (t:find(ns.G("STAT_HASTE_TOOLTIP", "?"), 1, true)
            or t:find(ns.G("STAT_HASTE_MELEE_TOOLTIP", "?"), 1, true)), "the haste says nothing of what it is: " .. t)
        ok, t = has("ARMORPEN", L.STAT_ABOUT)
        expect(ok, "the armour penetration has nothing to know: " .. t)
        ok, t = has("DEFENSE", string.format(L.STAT_DEFENSE_MAX, white(Number(115)), 23))
        expect(ok and not t:find(string.format(L.STAT_DEFENSE_SKILL, white(Number(140)), ""), 1, true),
            "the defence doesn't say where its « / 115 » comes from, or says a skill at its most lacks some: " .. t)
        local defenseSkill = UnitDefenseSkill
        UnitDefenseSkill = function()
            return 110, 3
        end
        ok, t = has("DEFENSE", string.format(L.STAT_DEFENSE_SKILL, white(Number(110)), white(Number(5))))
        UnitDefenseSkill = defenseSkill
        expect(ok, "the defence doesn't say what its skill lacks of its most: " .. t)
        -- and what it gives below its most: 2 short of 115, 0.08 % less to dodge, parry and block, 0.08 % more to be
        -- hit, as figures, not the sheet's sentence at « 0.00% » (Ikar's screenshot of 2026-11-20, at 113 / 115);
        -- past it, 143, 28 more: 1.12 % either way
        UnitDefenseSkill = function()
            return 110, 3
        end
        local below
        below, t = has("DEFENSE", L.STAT_EFFECTS, "-" .. ns.Format.PercentOf(0.08, 2), "+" .. ns.Format.PercentOf(0.08, 2))
        UnitDefenseSkill = defenseSkill
        local above, past = has("DEFENSE", "+" .. ns.Format.PercentOf(1.12, 2), "-" .. ns.Format.PercentOf(1.12, 2))
        expect(below and not t:find("0.00", 1, true) and above,
            "the defence's effects aren't its figures either way of its most: " .. t .. " / " .. past)
        F.itemStats[5] = { ITEM_MOD_STRENGTH_SHORT = 3 }
        ok, t = has("STRENGTH", L.STAT_GEAR, "|T134400:14:14|t ", "Objet 5", Color("+3", GOOD))
        expect(ok, "an item alone has no group's name over it, or no icon: " .. t)
        F.itemStats[5] = nil
        -- strength 110 (105+5): a permanent enchantment (823: strength +4), by its slot alone, not the item's name nor
        -- its tooltip's line (Ikar 2026-11-19: "I would prefere Enchantement (bracelet) + 4, no full name of the item,
        -- just it slot suffice"); the point left, "Others"
        local onHead = Color(string.format(L.STAT_ENCHANT, ns.G("HEADSLOT", "Head")), GOOD)
        F.enchants[1], F.enchantLines[1] = 823, "Force +4"
        ok, t = has("STRENGTH", onHead, Color("+4", GOOD), L.STAT_OTHER, Color("+1", GOOD))
        expect(ns.ENCHANTS[823] == "STRENGTH:4" and ok and not t:find("Objet 1", 1, true) and not t:find("Force +4", 1, true),
            "an item's enchantment isn't named by its slot alone: " .. t)
        -- one that puts a spell on its wearer (68: spell 7464, strength +1)
        F.enchants[1], F.enchantLines[1] = 68, nil
        ok, t = has("STRENGTH", onHead, Color("+1", GOOD), L.STAT_OTHER, Color("+4", GOOD))
        expect(ns.ENCHANTS[68] == "s:7464" and ns.EFFECTS[7464] == "1,1;29:0:0:0:1" and ok,
            "an enchantment's spell isn't named: " .. t)
        F.enchants[1] = nil
        -- a weapon's oil or stone, for a while (by Enum.WeaponSlot); a permanent one there not counted again
        F.weaponEnchants[0] = {
            { hasEnchant = true, enchantType = 2, timeLeft = 600000, charges = 0, enchantID = 823, enchantIconID = 0 },
            { hasEnchant = true, enchantType = 1, timeLeft = 0, charges = 0, enchantID = 8207, enchantIconID = 0 },
        }
        ok, t = has("STRENGTH", Color(string.format(L.STAT_ENCHANT, ns.G("MAINHANDSLOT", "Main Hand")), GOOD),
            Color("+4", GOOD))
        expect(ok and not t:find(Color("+10", GOOD), 1, true), "a weapon's enchantment for a while isn't named, or a "
            .. "permanent one is counted again: " .. t)
        F.weaponEnchants = {}
        -- a set's bonus from the pieces it takes (520: two give 200 armour), none from fewer
        F.items[1001], F.items[1003] = { class = 4, subclass = 4, set = 520 }, { class = 4, subclass = 4, set = 520 }
        F.setNames[520] = "Armure de test"
        local setLine = string.format(ns.G("ITEM_SET_BONUS_GRAY", "(%d) Set: %s"), 2, "Armure de test")
        ok, t = has("ARMOR", setLine, Color("+200", GOOD))
        expect(ns.ITEM_SETS[520]:find("^2:14803;") and ns.EFFECTS[14803] == "1,1;674:1:0:0:200" and ok,
            "a set's bonus isn't named: " .. t)
        F.items[1003] = nil
        ok, t = has("ARMOR", setLine)
        expect(not ok, "a set's bonus is named with fewer pieces than it takes: " .. t)
        F.items[1001] = nil
        -- a talent at its rank (13712: dodge, 2 % a rank, here 2 of 3) and a passive spell of the race the character
        -- knows (20582: dodge +1 %), beside the agility's 4 %
        F.talents = { { spell = 13712, rank = 2, ranks = 3 } }
        F.spellNames[13712], F.spellNames[20582] = "Esquive", "Vivacité"
        F.known[20582] = true
        changed()
        local rank = string.format(ns.G("TOOLTIP_TALENT_RANK", "Rank %d/%d"), 2, 3)
        local passive = ns.G("PASSIVE_PARENS", "(Passive)")
        ok, t = has("DODGE", "Esquive (" .. rank .. ")", Color("+" .. ns.Format.Percent(0.04), GOOD),
            "Vivacité " .. passive, Color("+" .. ns.Format.Percent(0.01), GOOD), stat(2))
        expect(ns.TALENT_POINTS[13712] == "0:0:2,4,6" and ns.EFFECTS[20582]:find(";49:0:0:0:1;", 1, true) and ok,
            "a talent at its rank or a known passive spell isn't named: " .. t)
        -- the talent's spell an aura on the character too: named once, as the aura
        F.auras.HELPFUL[1] = { name = "Esquive (aura)", spellId = 13712, points = { 4 } }
        ok, t = has("DODGE", "Esquive (aura)")
        expect(ok and not t:find(rank, 1, true), "a talent met as an aura is named twice: " .. t)
        F.auras.HELPFUL[1] = nil
        -- a passive spell the character doesn't know: none
        F.known[20582] = nil
        changed()
        ok, t = has("DODGE", "Vivacité")
        expect(not ok, "a passive spell the character doesn't know is named: " .. t)
        -- an effect of 0 points changes nothing and is no source: Berserker Stance's attack power (7381, 166 at 0),
        -- which had been read as a figure missing, a question mark and nothing left said (the audit of 2026-11-19)
        F.known[7381], F.spellNames[7381] = true, "Posture berserker (passif)"
        changed()
        ok, t = has("ATTACK_AP", (F.BASE.levelName .. " (x3)"))
        expect(ns.EFFECTS[7381]:find(";166:0:3:3:0", 1, true) and ok and not t:find("Posture berserker", 1, true)
            and not t:find(ns.Stats.UNKNOWN, 1, true), "an effect of 0 points is named, marked as unknown: " .. t)
        F.known[7381], F.spellNames[7381] = nil, nil
        changed()
        -- a talent that needs a melee weapon (12320: critical strikes, 1 % a rank): not with a bow, with an axe
        F.talents = { { spell = 12320, rank = 5, ranks = 5 } }
        F.spellNames[12320] = "Spécialisation"
        changed()
        F.items[1016] = { class = 2, subclass = 2 }
        ok, t = has("CRITCHANCE", "Spécialisation")
        expect(ns.EFFECT_NEEDS[12320] == "i:2:173555" and not ok, "a weapon's talent is named without its weapon: " .. t)
        F.items[1016] = { class = 2, subclass = 0 }
        ok, t = has("CRITCHANCE", "Spécialisation", Color("+" .. ns.Format.Percent(0.05), GOOD))
        expect(ok, "a weapon's talent isn't named with its weapon: " .. t)
        F.items[1016] = nil
        -- a form's passive spell (1178, the bear's: attack power by the level, 30 and 3 a level from 10, 69 at 23):
        -- in its form alone, worked out
        F.talents, F.known[1178], F.spellNames[1178] = {}, true, "Forme d'ours"
        changed()
        ok, t = has("ATTACK_AP", "Forme d'ours")
        expect(ns.EFFECT_NEEDS[1178] == "f:16:0:0:0" and not ok, "a form's passive spell is named out of its form: " .. t)
        F.form = 5
        -- (the game's attack power with the form's own in it: the fake's had been without, « Autres -49 » unseen, the
        -- addon's mistake in red since 2026-11-22)
        local attackPower = UnitAttackPower
        UnitAttackPower = function()
            return 269, 89, 0
        end
        ok, t = has("ATTACK_AP", "Forme d'ours " .. passive, Color("+69", GOOD))
        UnitAttackPower = attackPower
        expect(ok and not t:find(ns.Stats.UNKNOWN, 1, true) and not t:find(L.STAT_ADDON_ERROR, 1, true),
            "a form's passive spell isn't named in its form, or its points aren't worked out at the level: " .. t)
        F.form = nil
        F.itemStats, F.itemQuality, F.auras = {}, {}, { HELPFUL = {}, HARMFUL = {} }
        F.enchants, F.enchantLines, F.items, F.talents, F.known, F.setNames = {}, {}, {}, {}, {}, {}
        changed()
        expect(errors() == before, "naming the sources that aren't auras errs")
    end)
    -- The full review of 2026-11-20 (Ikar: "Do a full review of the characteristic and it calculation"): each case
    -- against this build's sheet code, its data and the original server's.
    run(function()
        local BAD, Color = ns.Infos.BAD, ns.Infos.Color
        local lines
        local function card(name)
            local t = tip("KaLiHUD_Attr_" .. name)
            lines = ns.StatCard.Lines()
            return t
        end
        local function after(a, b)
            for i = 1, #lines - 1 do
                if lines[i] == a and lines[i + 1] == b then
                    return true
                end
            end
            return false
        end
        local function changed()
            F.Fire("TRAIT_CONFIG_UPDATED", 1)
            F.Fire("SPELLS_CHANGED")
        end
        local unitStat = UnitStat
        -- Blessing of Kings (10 %) and an item's +10 on a strength of 100: 121 whichever way the game splits it, the
        -- original server's bonus 11 (its whole share times the bonus alone, the base 110)
        -- or 21; « Base 100 » either way, nothing left (it had said « Base 110 » and
        -- « Autres -10 »)
        F.itemStats[1], F.itemQuality[1] = { ITEM_MOD_STRENGTH_SHORT = 10 }, 2
        F.auras.HELPFUL[1] = { name = "Bénédiction des rois", spellId = 20217, points = { 10 } }
        local kings = {}
        for _, bonus in ipairs({ 11, 21 }) do
            UnitStat = function(unit, i)
                if i == 1 then
                    return 121, 121, bonus, 0
                end
                return unitStat(unit, i)
            end
            local t = card("STRENGTH")
            kings[bonus] = t
            -- (its base split by the original table: the human's 20, the warrior's 3 at level 1, the levels', and
            -- what the game's isn't the table's, « Forever »; Ikar 2026-11-23: "split to race, class and level")
            expect(after("Humaine", Number(20)) and after(F.BASE.class, Number(3))
                and t:find(F.BASE.levelName, 1, true) and t:find(L.STAT_FOREVER, 1, true)
                and t:find(Color("+" .. ns.Format.Percent(0.1), GOOD) .. " (" .. Color("+11", GOOD) .. ")", 1, true)
                and not t:find(L.STAT_OTHER, 1, true), "Kings, the game's bonus " .. bonus .. ", isn't a base of 100, "
                .. "the item and its share: " .. t)
        end
        -- the same sources whichever way the game splits it (its own split, in the card's head, is its own): the base
        -- is 100 either way, its share taken out (since the table splits the base, what's left of it is « Forever »,
        -- which hid a base of 110 from the check above)
        local function sources(t)
            return t:sub((t:find("Humaine", 1, true) or 1))
        end
        expect(sources(kings[11]) == sources(kings[21]), "Kings: the card's sources aren't the same, the game's bonus 11 or 21: "
            .. sources(kings[11]):gsub("\n", " | ") .. " / " .. sources(kings[21]):gsub("\n", " | "))
        -- the human's spirit without its racial's share (The Human Spirit, 10 % of it, named on its own), 20 as the
        -- original server's table has it, not the guides' 21 (the review of 2026-11-21)
        card("SPIRIT")
        expect(after("Humaine", Number(20)), "the human's spirit isn't the race's 20: "
            .. table.concat(lines, " | "))
        -- a share of one attribute by the mask its data gives (20257, Divine Intellect: intellect alone; its first misc
        -- is strength's, where it had gone)
        UnitStat = function(unit, i)
            if i == 4 then
                return 33, 33, 3, 0
            end
            return unitStat(unit, i)
        end
        F.itemStats[1], F.auras.HELPFUL[1] = nil, { name = "Intelligence divine", spellId = 20257, points = { 10 } }
        local intellect = card("INTELLECT")
        local strength = card("STRENGTH")
        expect(ns.EFFECTS[20257] == "1,1;137:8:0:0:2" and intellect:find("Intelligence divine", 1, true)
            and not intellect:find(L.STAT_OTHER, 1, true) and not strength:find("Intelligence divine", 1, true),
            "a share of the intellect by its mask isn't named on the intellect alone: " .. intellect .. " / " .. strength)
        UnitStat = unitStat
        F.auras.HELPFUL[1] = nil
        -- the defence's share of the dodge either way of its most (113 at level 23: -0.08 %), as the original server
        -- adds it to the dodge it shows; none on a block at 0, a character without a shield
        local defenseSkill = UnitDefenseSkill
        UnitDefenseSkill = function()
            return 110, 3
        end
        local t = card("DODGE")
        -- (its name with its sum, the review of 2026-11-23: « Défense (113 - 115) x 0,04 % »)
        local defense = ns.Stats.PartSum(ns.G("DEFENSE", "Defense"), 113, 115)
        local dodge = after(defense, ns.Format.PercentOf(-0.08, 2))
        local block = card("BLOCK")
        UnitDefenseSkill = defenseSkill
        expect(dodge and not after(defense, ns.Format.PercentOf(-0.08, 2)),
            "the defence below its most isn't named on the dodge, or is on a block at 0: " .. t .. " / " .. block)
        -- the weapon skill on the weapons' critical strike, either way of the level's most: the fake's swords 125 of
        -- 115, +0.4 %; 110, -0.2 %
        t = card("CRITCHANCE")
        local swords = string.format(L.STAT_SKILL_PART, "Épées")
        local over = after(ns.Stats.PartSum(swords, 125, 115), ns.Format.PercentOf(0.4, 1))
        local sword
        for _, s in ipairs(F.skills) do
            sword = s.skillID == 43 and s or sword
        end
        sword.rank = 105
        local short = card("CRITCHANCE")
        local under = after(ns.Stats.PartSum(swords, 110, 115), ns.Format.PercentOf(-0.2, 1))
        sword.rank = 120
        expect(over and under, "the weapon skill isn't named on the critical strike: " .. t .. " / " .. short)
        -- the speed as the original server works it out: of two raises of a kind the strongest alone, the other not
        -- stacking (Aspect of the Cheetah's 30 %, a 4 %), nothing left at 130 %; mounted, its own kinds: a mount's
        -- speed on a hidden aura what's left (150 %: « Autres +50 % »), on a visible one named (86458: 100 %)
        local unitSpeed = GetUnitSpeed
        GetUnitSpeed = function()
            return 9.1, 9.1, 0, 4.72
        end
        F.auras.HELPFUL[1] = { name = "Aspect du guépard", spellId = 5118, points = { 30 } }
        F.auras.HELPFUL[2] = { name = "Vitesse mineure", spellId = 13889, points = { 4 } }
        t = card("MOVESPEED")
        local strongest = after("Aspect du guépard", Color("+" .. ns.Format.Percent(0.3), GOOD))
            and after("Vitesse mineure", Color(L.STAT_NOT_STACKING, "ff808080")) and not t:find(L.STAT_OTHER, 1, true)
        F.mounted = true
        GetUnitSpeed = function()
            return 10.5, 10.5, 0, 4.72
        end
        F.auras.HELPFUL[1], F.auras.HELPFUL[2] = { name = "Cheval", spellId = 458 }, nil
        local hidden = card("MOVESPEED")
        local rest = after(L.STAT_OTHER, Color("+" .. ns.Format.Percent(0.5), GOOD))
            and not hidden:find("Aspect", 1, true)
        GetUnitSpeed = function()
            return 14, 14, 0, 4.72
        end
        F.auras.HELPFUL[2] = { name = "Monture épique", spellId = 86458 }
        local named = card("MOVESPEED")
        local epic = after("Monture épique", Color("+" .. ns.Format.Percent(1), GOOD))
            and not named:find(L.STAT_OTHER, 1, true)
        F.mounted, GetUnitSpeed = false, unitSpeed
        F.auras.HELPFUL[1], F.auras.HELPFUL[2] = nil, nil
        expect(strongest and rest and epic, "the speed's sources aren't the original server's: " .. t .. " / "
            .. hidden .. " / " .. named)
        -- the spells' power from a share of the spirit (14901, Spiritual Guidance at 3 of 5: 5 % of 40, 2) and a share
        -- of the whole (20572, Blood Fury: 10 %, its spell power's), an item's +20: (20 + 2) x 1.1, 24.2, nothing left;
        -- the healing the talent's other share, 15 % (6)
        local bonusDamage, bonusHealing = GetSpellBonusDamage, GetSpellBonusHealing
        GetSpellBonusDamage = function()
            return 24.2
        end
        GetSpellBonusHealing = function()
            return 26
        end
        F.talents, F.spellNames[14901] = { { spell = 14901, rank = 3, ranks = 5 } }, "Direction spirituelle"
        changed()
        F.itemStats[1] = { ITEM_MOD_SPELL_POWER_SHORT = 20 }
        F.auras.HELPFUL[1] = { name = "Fureur sanguinaire", spellId = 20572, points = { 10, 10, 10 } }
        local power = card("SPELLPOWER_SHADOW")
        local fromSpirit = power:find("Direction spirituelle", 1, true) and power:find(Color("+2", GOOD), 1, true)
            and power:find("Fureur sanguinaire\n" .. Color("+" .. ns.Format.Percent(0.1), GOOD) .. " ("
                .. Color("+2", GOOD) .. ")", 1, true) and not power:find(L.STAT_OTHER, 1, true)
        F.auras.HELPFUL[1] = nil
        local healing = card("SPELLHEALING")
        GetSpellBonusDamage, GetSpellBonusHealing = bonusDamage, bonusHealing
        F.talents, F.spellNames[14901], F.itemStats[1] = {}, nil, nil
        changed()
        expect(ns.EFFECTS[14901] == "2,2;174:4:0:0:8;175:4:1:1:25" and fromSpirit
            and healing:find(Color("+6", GOOD), 1, true) and not healing:find(L.STAT_OTHER, 1, true),
            "a share of the spirit or Blood Fury isn't named on the spells' power and healing: " .. power .. " / "
            .. healing)
        -- each school's spell power its own card (the review of 2026-11-23), and a warlock's pet's share of it on the
        -- school the sheet takes it from: of shadow's 120, 17 % and 10 % (20 and 12), not on the fire's
        do
            local unitClass = UnitClass
            GetSpellBonusDamage = function(school)
                return school == 6 and 120 or 50
            end
            UnitClass = function()
                return "Démoniste", "WARLOCK", 9
            end
            changed()
            local petLine = string.format((PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG_SHADOW:gsub("^(|c%x+)\n", "%1")), 20, 12)
            local schools = card("SPELLPOWER_SHADOW")
            local shadow = after(ns.G("STAT_SPELLPOWER", "Spell Power") .. " (" .. ns.G("DAMAGE_SCHOOL6", "Shadow") .. ")",
                Number(120))
            local pet = schools:find(petLine, 1, true)
            local fireCard = card("SPELLPOWER_FIRE")
            GetSpellBonusDamage, UnitClass = bonusDamage, unitClass
            changed()
            expect(shadow and pet and not fireCard:find(petLine, 1, true),
                "a school's spell power isn't its own card, or a warlock's pet's share not on the school it's of: "
                .. schools .. " / " .. fireCard)
        end
        -- the weapon's skill on its damage's card, as the sheet's tooltip adds it: the swords' 120, 5 more, of 150
        local sword = card("MAINHAND_DAMAGE")
        expect(sword:find(string.format(WEAPON_SKILL_PAPERDOLLFRAME_FORMAT, "Épées") .. " "
            .. Color("120 (5)/150", "ffffffff"), 1, true), "the main hand's card doesn't give its weapon's skill: " .. sword)
        -- the attack power from a share of the intellect (415140, the shaman's Mental Dexterity at 2 of 3: 66 % of 30,
        -- 20; 100 % before build 71037's data, whose ranks are 33, 66 and 100 %), melee and ranged (Ikar 2026-11-21:
        -- "dexteriter mental seem not to be shown in attack power"), in the game's base, as Forever counts it; Cat
        -- Form's of the agility (3025) not, the game's figure for the agility its own.
        -- the level's part (49, 3 a level less 20), always (Ikar: "The base shoudl now always match"): with
        -- the game's base 289 = 49 + 220 + 20, nothing left; with 269, the card's 20 the game hasn't, « Erreur de
        -- l'addon » -20 in red, its foot saying it's to be reported ("show the difference, to be reported, in red")
        F.talents, F.spellNames[415140] = { { spell = 415140, rank = 2, ranks = 3 } }, "Dextérité mentale"
        -- (Cat Form's passive as the game puts it on, an aura: its share of the agility its sixth effect, the others 0)
        F.auras.HELPFUL[1] = { name = "Forme de félin (Passive)", spellId = 3025, points = { 0, 0, 0, 0, 0, 100, 0, 0 } }
        changed()
        local melee = card("ATTACK_AP")
        -- (the level's part drawn as a source, as an attribute's: white, not the grey of what's left)
        local levelColor
        for i = 1, KaLiHUDStatCard.used do
            if KaLiHUDStatCard.texts[i]:GetText() == (F.BASE.levelName .. " (x3)") then
                levelColor = KaLiHUDStatCard.texts[i].textColor
            end
        end
        local meleeFoot = table.concat((ns.StatCard.Lines(true)), "\n")
        local ranged = card("RANGED_ATTACK_AP")
        F.auras.HELPFUL[1] = nil
        local attackPower = UnitAttackPower
        UnitAttackPower = function()
            return 289, 0, 0
        end
        changed()
        local inBase = card("ATTACK_AP")
        UnitAttackPower = attackPower
        -- a shaman's ranged attack power, none (Ikar 2026-11-21: "Why error on distance power ?", the game's 0 beside
        -- Mental Dexterity, the card's « Erreur de l'addon » -35): no level's part, no share of the intellect
        local unitClass, rangedPower, rangedForStat = UnitClass, UnitRangedAttackPower, GetRangedAttackPowerForStat
        UnitClass = function()
            return "Chaman", "SHAMAN", 7
        end
        UnitRangedAttackPower = function()
            return 0, 6, 0
        end
        GetRangedAttackPowerForStat = function()
            return 0
        end
        changed()
        local shaman = card("RANGED_ATTACK_AP")
        UnitClass, UnitRangedAttackPower, GetRangedAttackPowerForStat = unitClass, rangedPower, rangedForStat
        F.talents, F.spellNames[415140] = {}, nil
        changed()
        local talent = "Dextérité mentale (" .. string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", 2, 3) .. ")\n20\n"
        local mistake = L.STAT_ADDON_ERROR .. "\n" .. Color(Number(-20), BAD)
        -- (Cat Form's own attack power by level, +46, named; its agility's 80 not, on either)
        expect(melee:find(talent, 1, true) and ranged:find(talent, 1, true)
            and melee:find(L.STAT_BASE .. "\n" .. Number(-20) .. "\n" .. (F.BASE.levelName .. " (x3)") .. "\n" .. Number(69) .. "\n", 1, true) and levelColor
            and levelColor[1] == 1
            and ranged:find(L.STAT_BASE .. "\n" .. Number(-10) .. "\n" .. (F.BASE.levelName .. " (x1)") .. "\n" .. Number(23) .. "\n", 1, true)
            and melee:find(mistake, 1, true) and ranged:find(mistake, 1, true)
            and meleeFoot:find(L.STAT_ADDON_ERROR_TIP, 1, true)
            and melee:find("Forme de félin (Passive)\n" .. Color("+46", GOOD), 1, true)
            and not ranged:find("Forme de félin", 1, true)
            and inBase:find(talent, 1, true)
            and inBase:find(L.STAT_BASE .. "\n" .. Number(-20) .. "\n" .. (F.BASE.levelName .. " (x3)") .. "\n" .. Number(69) .. "\n", 1, true)
            and not inBase:find(L.STAT_ADDON_ERROR, 1, true) and not inBase:find(L.STAT_OTHER, 1, true)
            and not inBase:find(L.STAT_BONUS, 1, true),
            "the attack power's base isn't the level's, a share of the intellect and what the card can't account for: "
            .. melee .. " / " .. meleeFoot .. " / " .. ranged .. " / " .. inBase)
        expect(not shaman:find("Dextérité mentale", 1, true) and not shaman:find(L.STAT_ADDON_ERROR, 1, true)
            and not shaman:find(" x 23", 1, true) and not shaman:find(L.STAT_BASE .. "\n", 1, true),
            "a shaman's ranged attack power has a level's part, a share of the intellect or a base of 0: " .. shaman)
        -- a talent's value held against the game's own words at its rank (Ikar 2026-11-21: "review all talent, all
        -- similar assumption"; the probe found Mental Dexterity's 33, 66 and 100 % where the data says 50, 100 and
        -- 150): at rank 3 the words' 100 %, 30, not the data's 150 %, 45; words stating the data's figure keep it;
        -- words of several other figures, the mark, no figure the game doesn't give
        local says = "Augmente votre puissance d'attaque d'un montant égal à %s de votre intelligence."
        local function atRank3(text)
            F.talents, F.spellNames[415140] = { { spell = 415140, rank = 3, ranks = 3, says = text } }, "Dextérité mentale"
            changed()
            local out = card("ATTACK_AP")
            F.talents, F.spellNames[415140] = {}, nil
            changed()
            return out
        end
        local rank3 = "Dextérité mentale (" .. string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", 3, 3) .. ")\n"
        local words, data, unsure = atRank3(string.format(says, "100 %")), atRank3(string.format(says, "150 %")),
            atRank3(string.format(says, "20 % ou 40 %"))
        expect(words:find(rank3 .. "30\n", 1, true) and data:find(rank3 .. "45\n", 1, true)
            and unsure:find(rank3 .. ns.Stats.UNKNOWN, 1, true),
            "a talent's value isn't held against the game's own words at its rank: " .. words .. " / " .. data .. " / "
            .. unsure)
        -- the expertise: a rating an aura gives (1301076, the tier 1 sets' four pieces of a tank: 12 points), worth
        -- what the game makes of it (here 1 %); the enemy at hand's parry, 5 % at the character's level
        local getExpertise = GetExpertise
        GetExpertise = function()
            return 1, 1, 1
        end
        F.ratings[CR_EXPERTISE] = 12
        F.auras.HELPFUL[1] = { name = "Tenue de défense", spellId = 1301076 }
        t = card("EXPERTISE")
        GetExpertise, F.ratings[CR_EXPERTISE] = getExpertise, nil
        expect(after("Tenue de défense", Color("+" .. ns.Format.Percent(0.01), GOOD)) and not t:find(L.STAT_OTHER, 1, true)
            and t:find(string.format(L.STAT_TIER_ROW, L.STAT_TIER_NO_PARRY, ns.Format.Percent(0.05)), 1, true),
            "the expertise's rating or the parry of its level isn't said: " .. t)
        -- the armour ignored (21153, Bonereaver's Edge: 700), on the armour penetration, not the spells'
        local armorPen = GetArmorPenetration
        GetArmorPenetration = function()
            return 700
        end
        F.auras.HELPFUL[1] = { name = "Fléau de Bonereaver", spellId = 21153 }
        t = card("ARMORPEN")
        local ignored = after("Fléau de Bonereaver", Color("+700", GOOD)) and not t:find(L.STAT_OTHER, 1, true)
        local spells = card("SPELLPENETRATION")
        GetArmorPenetration = armorPen
        expect(ignored and not spells:find("Bonereaver", 1, true), "the armour ignored isn't the armour penetration's: "
            .. t .. " / " .. spells)
        -- the power shown's own sources: a rogue's Vigor (14983: 10 energy), the rest its base
        local powerType, powerMax = UnitPowerType, UnitPowerMax
        UnitPowerType = function()
            return 3, "ENERGY"
        end
        UnitPowerMax = function(_, kind)
            return kind == Enum.PowerType.Mana and 0 or 110
        end
        F.auras.HELPFUL[1] = { name = "Vigueur", spellId = 14983 }
        t = card("POWER")
        UnitPowerType, UnitPowerMax = powerType, powerMax
        F.auras.HELPFUL[1] = nil
        expect(after("Vigueur", Color("+10", GOOD)) and after(F.BASE.class, F.BASE.asks(Number(100))),
            "the energy's sources aren't named: " .. t)
        -- the mana's base by the class and the levels, Forever's own table (Data/Effects.lua's BASE_MANA; Ikar
        -- 2026-11-21: "what is the logic from 24 to 40 ? same for everything"): a mage's 100 at level 1, what the 22
        -- levels since add (431 at 23), the intellect's; 7 the card can't name, « Autres »
        local unitClass, levels = UnitClass, {}
        for v in ns.BASE_MANA.MAGE:gmatch("%d+") do
            levels[#levels + 1] = tonumber(v)
        end
        local intellect = select(2, UnitStat("player", 4))
        UnitClass = function()
            return "Mage", "MAGE", 8
        end
        UnitPowerType = function()
            return 0, "MANA"
        end
        UnitPowerMax = function()
            return levels[23] + math.min(20, intellect) + math.max(0, intellect - 20) * 15 + 7
        end
        t = card("POWER")
        UnitClass, UnitPowerType, UnitPowerMax = unitClass, powerType, powerMax
        -- (split as the attributes' since 2026-11-24, Ikar: "why mana and health are not broken by race, class and
        -- profession like the rest": the class's 100 at level 1, the 331 levels 2 to 23 have given)
        expect(levels[1] == 100 and levels[23] == 431 and after("Mage", Number(100))
            and after(F.BASE.levelName, Number(331)) and after(L.STAT_OTHER, Color("+7", GOOD)),
            "the mana's base isn't the class's at level 1 and the levels', and what's left: " .. t)
        -- a share of the whole health (the tauren's Endurance, 133: 5 %) worked out, what it comes to (51 of 1 064),
        -- the base still the class's and the levels' (the review of 2026-11-21: every tauren's had lost its base)
        local healthMax = UnitHealthMax
        UnitHealthMax = function()
            return 1064
        end
        F.known[20550], F.spellNames[20550] = true, "Endurance"
        changed()
        t = card("HEALTH")
        local tauren = after(F.BASE.class, Number(20)) and after(F.BASE.levelName, Number(223))
            and t:find("Endurance", 1, true)
            and t:find(Color("+" .. ns.Format.Percent(0.05), GOOD) .. " (" .. Color("+51", GOOD) .. ")", 1, true)
            and not t:find(L.STAT_OTHER, 1, true)
        UnitHealthMax, F.known[20550], F.spellNames[20550] = healthMax, nil, nil
        changed()
        expect(tauren, "a share of the whole health isn't worked out, or the base left out beside it: " .. t)
        -- the mana's regeneration held against the game's out of casting (the review of 2026-11-21: it had been
        -- held against nothing): the spirit's 15 in 5, 17 in all, 2 the card can't name
        local manaRegen, fromSpiritMana = GetManaRegen, GetManaRegenFromSpirit
        UnitPowerMax = function()
            return 500
        end
        GetManaRegenFromSpirit = function()
            return 3
        end
        GetManaRegen = function()
            return 3.4, 0.4
        end
        t = card("REGEN")
        local manaLeft = after(ns.G("SPELL_STAT5_NAME", "SPIRIT"), Number(15)) and after(L.STAT_OTHER, Color("+2", GOOD))
        UnitPowerMax, GetManaRegen, GetManaRegenFromSpirit = powerMax, manaRegen, fromSpiritMana
        expect(manaLeft, "the mana's regeneration isn't held against the game's: " .. t)
        -- the health's regeneration (Ikar 2026-11-21: "health regen ?"): in a fight 5, out of one 20, standing three
        -- quarters of what the spirit gives (4 a second: 15 in 5) and Demon Skin's 5 (161), nothing left; 2 the card
        -- can't name, « Autres »; a share of it out of a fight (Pure Water's 50 %, 88) named, nothing said left
        local fromSpirit, healthRegen, regenOut = GetHealthRegenFromSpirit, GetHealthRegen, 4
        GetHealthRegenFromSpirit = function()
            return 4, 0
        end
        GetHealthRegen = function()
            return regenOut, 1
        end
        local spirit = ns.G("SPELL_STAT5_NAME", "SPIRIT")
        F.auras.HELPFUL[1] = { name = "Peau de démon", spellId = 696, points = { 120, 5 } }
        t = card("HEALTH_REGEN")
        local skin = after(spirit, Number(15)) and after("Peau de démon", Color("+5", GOOD))
            and t:find(Number(5) .. " (" .. Number(20) .. ")", 1, true) and not t:find(L.STAT_OTHER, 1, true)
        regenOut = 4.4
        local more = card("HEALTH_REGEN")
        local left = after(L.STAT_OTHER, Color("+2", GOOD))
        F.auras.HELPFUL[2] = { name = "Eau pure", spellId = 8384, points = { 50, 5 } }
        local water = card("HEALTH_REGEN")
        F.auras.HELPFUL[1], F.auras.HELPFUL[2] = nil, nil
        GetHealthRegenFromSpirit, GetHealthRegen = fromSpirit, healthRegen
        expect(skin and left and water:find("Eau pure", 1, true) and not water:find(L.STAT_OTHER, 1, true),
            "the health's regeneration isn't the spirit's, its auras' and what's left: " .. t .. " / " .. more .. " / "
            .. water)
        -- the kinds the data had left out (the review of 2026-11-21, Ikar: "review all others"): a share of the mana's
        -- most (178, the gnome's Expansive Mind: 5 %); the ranged speed of a quiver (557, « Hâte »: 10 %), the melee
        -- one of Juju Flurry (9: 3 %); a share of the items' armour (466) on a debuff alone (Brèche furieuse: -40 %),
        -- the forms' twin of 142 left out (Bear Form: 180 % once)
        UnitPowerType = function()
            return 0, "MANA"
        end
        F.auras.HELPFUL[1] = { name = "Pensée expansive", spellId = 20591 }
        local mana = card("POWER")
        UnitPowerType = powerType
        local meleeHaste, rangedHaste, spellHaste = GetMeleeHaste, GetRangedHaste, UnitSpellHaste
        GetMeleeHaste, UnitSpellHaste = function()
            return 0
        end, function()
            return 0
        end
        GetRangedHaste = function()
            return 10, 0
        end
        F.auras.HELPFUL[1] = { name = "Hâte", spellId = 14824 }
        local ranged = card("HASTE")
        GetMeleeHaste = function()
            return 3
        end
        GetRangedHaste = function()
            return 0, 0
        end
        F.auras.HELPFUL[1] = { name = "Rafale de Juju", spellId = 16322 }
        local melee = card("HASTE")
        GetMeleeHaste, GetRangedHaste, UnitSpellHaste = meleeHaste, rangedHaste, spellHaste
        F.auras.HELPFUL[1] = nil
        F.auras.HARMFUL[1] = { name = "Brèche furieuse", spellId = 1270825 }
        local breach = card("ARMOR")
        F.auras.HARMFUL[1] = nil
        expect(mana:find("Pensée expansive\n" .. Color("+" .. ns.Format.Percent(0.05), GOOD), 1, true)
            and ranged:find("Hâte\n" .. Color("+" .. ns.Format.Percent(0.1), GOOD), 1, true)
            and melee:find("Rafale de Juju\n" .. Color("+" .. ns.Format.Percent(0.03), GOOD), 1, true)
            and breach:find("Brèche furieuse\n" .. Color("-" .. ns.Format.Percent(0.4), BAD), 1, true)
            and ns.EFFECTS[1178]:find("142:1:1:1:180", 1, true) and not ns.EFFECTS[1178]:find("466", 1, true),
            "a kind the data had left out isn't named: " .. mana .. " / " .. ranged .. " / " .. melee .. " / " .. breach)
        -- a rating not had yet, a set's next bonus of critical strike (1299738: 21 points): what the game makes of it
        -- at the level (here 14 points a percent: 1.5 %), not one percent a point (+21 %)
        F.items[1001], F.setNames[998], ns.ITEM_SETS[998] = { class = 4, subclass = 4, set = 998 }, "Tenue d'essai",
            "2:1299738"
        t = card("CRITCHANCE")
        F.items[1001], F.setNames[998], ns.ITEM_SETS[998] = nil, nil, nil
        expect(after(string.format(ns.G("ITEM_SET_NAME", "%s (%d/%d)"), "Tenue d'essai", 1, 2),
            "+" .. ns.Format.PercentOf(1.5, 1)), "a rating not had yet isn't what the game makes of it: " .. t)
        F.itemStats, F.itemQuality, F.auras = {}, {}, { HELPFUL = {}, HARMFUL = {} }
        expect(errors() == before, "the review's cases err")
    end)
    -- Ikar 2026-11-19: "Go with card 1". The attributes' hover is a card of the HUD's own, not a tooltip: its head the
    -- name and the value; then where the value comes from (the gear under one name with its sum, the changes under
    -- « Bonus » with theirs), what there is to know of it, what it gives as figures; a column with nothing to say left
    -- out; its foot the hints; gone with the pointer, or with a click.
    run(function()
        local Color = ns.Infos.Color
        local lines, columns
        -- (an item's row its name after its icon, the fake's 134400)
        local function after(a, b)
            for i = 1, #lines - 1 do
                if (lines[i] == a or lines[i] == "|T134400:14:14|t " .. a) and lines[i + 1] == b then
                    return true
                end
            end
            return false
        end
        F.itemStats[5], F.itemStats[6] = { RESISTANCE0_NAME = 300 }, { RESISTANCE0_NAME = 200 }
        local t = tip("KaLiHUD_Attr_ARMOR")
        lines, columns = ns.StatCard.Lines()
        expect(lines[1] == ns.G("STAT_ARMOR", "Armor") and table.concat(columns, " ") == "sources about effects"
            and GameTooltip:GetOwner() ~= Buttons.Get("KaLiHUD_Attr_ARMOR"),
            "an attribute's hover isn't a card, its name first and its three columns under: " .. t)
        expect(after(L.STAT_GEAR, Number(500)) and after(L.STAT_OTHER, Color("+" .. Number(680), GOOD)),
            "the card's sources aren't the gear with its sum and what's left of the whole: " .. t)
        expect(after(ns.Format.PercentOf(1340 / 3695 * 100, 2), L.STAT_GIVES_PHYSICAL) and t:find("Augmenté par", 1, true)
            and t:find("75 %", 1, true) and not t:find("Réduit les", 1, true),
            "the card doesn't give the armour's effect as a figure, or what there is to know of it: " .. t)
        -- its base first among what it stands on (Ikar 2026-11-19: "base should be first no ?")
        local at = {}
        for i, line in ipairs(lines) do
            at[line] = at[line] or i
        end
        local agility = ns.G("SPELL_STAT2_NAME", "AGILITY")
        expect(at[agility] and at[L.STAT_GEAR] and at[agility] < at[L.STAT_GEAR],
            "the card's sources don't start with the base: " .. t)
        -- Ikar 2026-11-19: "They shoudl show as a separate set bonus category, after equipement, could be in them, but
        -- near will simplify reading. Equipement et Set d'equipement". All the gear gives under « Équipement », slot by
        -- slot: an item's own armour and what its own spell adds while it's worn (its « Équipé : » line, 200 here) on
        -- one row, an enchantment after its item (16); the sets' bonuses under their own name right after (two of 200);
        -- what's left of the whole last, « Autres » (1916 less 160, 716 and 400: 640)
        do
            local unitArmor = UnitArmor
            UnitArmor = function()
                return 1200, 1916, 1916, 716
            end
            ns.ITEM_SPELLS[1005], ns.ITEM_SETS[999], F.enchants[6] = "14803", "2:14803;3:14803", 16
            for _, id in ipairs({ 1001, 1003, 1007 }) do
                F.items[id] = { class = 4, subclass = 4, set = 999 }
            end
            F.setNames[999] = "Armure d'essai"
            local worn = tip("KaLiHUD_Attr_ARMOR")
            lines = ns.StatCard.Lines()
            UnitArmor = unitArmor
            ns.ITEM_SPELLS[1005], ns.ITEM_SETS[999], F.enchants[6], F.setNames[999] = nil, nil, nil, nil
            F.items[1001], F.items[1003], F.items[1007] = nil, nil, nil
            local where = {}
            for i, line in ipairs(lines) do
                where[line] = where[line] or i
            end
            local waist = Color(string.format(L.STAT_ENCHANT, ns.G("WAISTSLOT", "Waist")), GOOD)
            expect(after(L.STAT_GEAR, Number(716)) and after("Objet 5", Number(300) .. " " .. Color("+200", GOOD))
                and after(waist, Color("+16", GOOD)),
                "the gear's rows aren't under one name with their sum, an item's own spell on its row, its enchantment "
                .. "after: " .. worn)
            expect(after(L.STAT_SETS, Color("+400", GOOD)) and where[L.STAT_GEAR] and where[L.STAT_SETS]
                and where[L.STAT_OTHER] and where[L.STAT_SETS] < where[L.STAT_OTHER]
                and where[L.STAT_GEAR] < where[L.STAT_SETS] and lines[where[L.STAT_SETS] - 1] == Color("+16", GOOD)
                and after(L.STAT_OTHER, Color("+" .. Number(640), GOOD)),
                "the sets' bonuses aren't a group of their own right after the gear's, the rest after them: " .. worn)
        end
        -- Ikar 2026-11-19: "do 10, 1, 2 […], 4". What a set's next pieces would give, after what the sets give, named
        -- as the game names a set with its pieces and grey, its figure too: three pieces worn, the bonus of two had
        -- (200), the one of four not yet (« Armure d'essai (3/4) », 200), the one of six left unsaid; in no sum (what's
        -- left is 516, not 316). And for a value nothing changes, under what it stands on
        do
            local unitArmor = UnitArmor
            UnitArmor = function()
                return 1200, 1916, 1916, 716
            end
            ns.ITEM_SETS[999] = "2:14803;4:14803;6:14803"
            for _, id in ipairs({ 1001, 1003, 1007 }) do
                F.items[id] = { class = 4, subclass = 4, set = 999 }
            end
            F.setNames[999] = "Armure d'essai"
            local worn = tip("KaLiHUD_Attr_ARMOR")
            lines = ns.StatCard.Lines()
            local nextPieces = string.format(ns.G("ITEM_SET_NAME", "%s (%d/%d)"), "Armure d'essai", 3, 4)
            expect(after(nextPieces, "+200") and after(L.STAT_OTHER, Color("+" .. Number(1056), GOOD))
                and not worn:find("(3/6)", 1, true),
                "a set's next pieces aren't said after the sets' bonuses, the nearest alone, grey and in no sum: "
                .. worn)
            UnitArmor = function()
                return 1200, 1200, 1200, 0
            end
            local still = tip("KaLiHUD_Attr_ARMOR")
            lines = ns.StatCard.Lines()
            expect(after(nextPieces, "+200"), "a set's next pieces aren't said for a value nothing changes: " .. still)
            UnitArmor = unitArmor
            ns.ITEM_SETS[999], F.setNames[999] = nil, nil
            F.items[1001], F.items[1003], F.items[1007] = nil, nil, nil
        end
        -- Ikar 2026-11-19: "find for every carachteristic any possible cap, golden value etc.", then "go for the live";
        -- 2026-11-20: "met un lvl avec dans l'info box tous les lvl, la liste, comment, pourquoi", "chiffre romain".
        -- What's worth reaching, level by level, first under « À savoir »: I an enemy of the character's level (23),
        -- II and III one and two above, IV a raid boss (26), each its rows, reached or what's missing; then how the
        -- figures are had, what the numerals are, and why they're worth reaching.
        do
            local ROMAN, mark, GOLD = ns.Stats.ROMAN, ns.Stats.UNKNOWN, "ffffd100"
            local P, PO, EITHER = ns.Format.Percent, ns.Format.PercentOf, L.STAT_CAP_EITHER
            local MELEE, SPELLS = ns.G("MELEE", "Melee"), ns.G("SPELLS", "Spells")
            local function level(n)
                return string.format(n == 4 and L.STAT_TIER_BOSS or L.STAT_TIER_LEVEL, 22 + n)
            end
            -- `text` holds level n's head (whom it's against), and under it, before the next level's, `row`
            local function under(text, n, who, row)
                local from = text:find(Color(ROMAN[n], GOLD) .. " " .. who .. "\n", 1, true)
                if not from then
                    return false
                end
                local to = n < #ROMAN and text:find(Color(ROMAN[n + 1], GOLD) .. " ", from, true) or #text + 1
                local at = text:find(row, from, true)
                return at ~= nil and at < (to or #text + 1)
            end
            local function capped(what, figure, status, asked)
                return string.format(L.STAT_TIER_ROW, what, figure) .. (asked and (" " .. mark) or "") .. " — " .. status
            end
            -- what the card's how-and-why line says on its hover, the card kept open (Ikar 2026-11-22: "hover to see
            -- details"); "" when it has none there
            local function details(name)
                local object, button = Hub.Object(name), Buttons.Get(name) or UIParent
                run(object.OnEnter, button)
                run(object.OnClick, button, "LeftButton")
                run(object.OnLeave, button)
                local d, said = KaLiHUDStatCardPinned and KaLiHUDStatCardPinned.Details, ""
                if d and d:IsShown() then
                    F.RunScript(d, "OnEnter")
                    said = table.concat(F.tooltip.lines, "\n")
                    F.RunScript(d, "OnLeave")
                end
                ns.StatCard.Unpin()
                return said
            end
            local function missing(what)
                return Color(string.format(L.STAT_CAP_MISSING, what), "ffffffff")
            end
            local reached = Color(L.STAT_CAP_REACHED, GOOD)
            -- the armour's most, 75 %, by the game's own sum at each level (5 725 more at 23, 6 490 against a raid boss),
            -- how and why after
            local armour = tip("KaLiHUD_Attr_ARMOR")
            expect(under(armour, 1, level(1), capped(L.STAT_TIER_ARMOR, P(0.75), missing(Number(5725))))
                and under(armour, 2, level(2), string.format(L.STAT_TIER_ROW, L.STAT_TIER_ARMOR, P(0.75)))
                and under(armour, 3, level(3), string.format(L.STAT_TIER_ROW, L.STAT_TIER_ARMOR, P(0.75)))
                and under(armour, 4, level(4), capped(L.STAT_TIER_ARMOR, P(0.75), missing(Number(6490)))),
                "the card doesn't say the armour's most level by level, I to IV, and what's short of it: " .. armour)
            -- (how and why: a line after the levels, their text on its hover alone)
            local said = details("KaLiHUD_Attr_ARMOR")
            expect(armour:find(L.STAT_DETAILS, 1, true) and not armour:find(L.STAT_HOW_ARMOR, 1, true)
                and armour:find(L.STAT_DETAILS, 1, true) > armour:find(Color(ROMAN[4], GOLD), 1, true)
                and said:find(Color(L.STAT_TIER_HOW, GOLD) .. " " .. L.STAT_HOW_ARMOR .. " " .. L.STAT_TIERS, 1, true)
                and said:find(Color(L.STAT_TIER_WHY, GOLD) .. " " .. L.STAT_GOAL_ARMOR, 1, true),
                "the card doesn't say, on its line's hover after the levels, how the armour's thresholds are had, what "
                .. "the numerals are, or why: " .. armour .. "\n/\n" .. said)
            -- the hit, a row a kind: never missed with 5 % of melee (2 short) at the character's level, its spells' 4 %
            -- reached; one or two above, the weapons' two figures (5.2 % or 5.5 %, 5.4 % or 6 %) and the question; a
            -- raid boss's 8 % or 9 %, marked (5 or 6 short), its spells' 17 % reached once they have it; the foot
            -- says what each mark asks, the sword's skill read (none said unread)
            local hit = tip("KaLiHUD_Attr_HITCHANCE")
            local foot = table.concat((ns.StatCard.Lines(true)), "\n")
            local spellHit = GetSpellHitModifier
            GetSpellHitModifier = function()
                return 16
            end
            local all = tip("KaLiHUD_Attr_HITCHANCE")
            GetSpellHitModifier = spellHit
            expect(under(hit, 1, level(1), capped(MELEE, P(0.05), missing(PO(2, 1))))
                and under(hit, 1, level(1), capped(SPELLS, string.format(EITHER, P(0.03), P(0.04)), reached, true))
                and under(hit, 2, level(2), capped(MELEE, string.format(EITHER, PO(5.2, 1), PO(5.5, 1)),
                    missing(string.format(EITHER, PO(2.2, 1), PO(2.5, 1))), true))
                and under(hit, 3, level(3), capped(MELEE, string.format(EITHER, PO(5.4, 1), P(0.06)),
                    missing(string.format(EITHER, PO(2.4, 1), PO(3, 1))), true))
                and under(hit, 4, level(4), capped(MELEE, string.format(EITHER, P(0.08), P(0.09)),
                    missing(string.format(EITHER, PO(5, 1), PO(6, 1))), true))
                and under(all, 4, level(4), capped(SPELLS, string.format(EITHER, P(0.16), P(0.17)), reached, true)),
                "the card doesn't say what never missing takes, level by level, each kind's: " .. hit .. " / " .. all)
            expect(foot:find(mark .. " " .. L.STAT_WHY_BOSS_HIT, 1, true) and foot:find(mark .. " " .. L.STAT_WHY_NEAR_HIT,
                1, true) and foot:find(mark .. " " .. L.STAT_WHY_SPELL_FLOOR, 1, true)
                and not foot:find(L.STAT_WHY_SKILL_UNREAD, 1, true),
                "a level's question isn't said at the foot, or a skill read is said unread: " .. foot)
            -- the line: after its value, in gold, the numeral of the highest level reached, each under it too, for the
            -- kind of attack it shows: the spells' 4.5 % an enemy of the character's level (I, not II's 5 %); with
            -- 20.5 %, a raid boss's 17 % (IV)
            local function shown()
                local b = ns.HubButtons.Get("KaLiHUD_Attr_HITCHANCE")
                return F.Shows(b)
            end
            local one = shown()
            GetSpellHitModifier = function()
                return 16
            end
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            local four = shown()
            GetSpellHitModifier = spellHit
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            expect(one:sub(-#(" " .. Color("I", GOLD))) == " " .. Color("I", GOLD)
                and four:sub(-#(" " .. Color("IV", GOLD))) == " " .. Color("IV", GOLD)
                and shown() == one, "the line doesn't wear the highest level it reaches, in gold: " .. one .. " / " .. four)
            -- a sword's skill short of its most (100 of 115): 0.04 % a point on top, as the Skills tab works it out,
            -- 5.6 % (2.6 short), said as an answer under the levels
            local sword = F.skills[2]
            local rank, modifier = sword.rank, sword.modifier
            sword.rank, sword.modifier = 100, 0
            local short = tip("KaLiHUD_Attr_HITCHANCE")
            sword.rank, sword.modifier = rank, modifier
            expect(under(short, 1, level(1), capped(MELEE, PO(5.6, 1), missing(PO(2.6, 1))))
                and short:find(string.format(L.STAT_SKILL_SHORT, "Épées", Number(100), Number(115),
                    "+" .. PO(0.6, 1)), 1, true),
                "a weapon's skill short of its most isn't counted in the thresholds, or not said: " .. short)
            -- the defence: none of its critical strikes from 240 at the character's level (97 short), 255 a raid boss's
            -- (112 short); the game states them: unmarked
            local defence = tip("KaLiHUD_Attr_DEFENSE")
            expect(under(defence, 1, level(1), capped(L.STAT_TIER_NO_CRIT, Number(240), missing(Number(97))))
                and under(defence, 4, level(4), capped(L.STAT_TIER_NO_CRIT, Number(255), missing(Number(112)))),
                "the card doesn't say the defence each level's critical strikes stop at, or marks it unknown: " .. defence)
            -- the tank's figures (Ikar 2026-11-21: "go for the glancing and crushing, tank figure"), level by level: the
            -- enemy's blows avoided or blocked, its 5 % of misses 0.04 % more a point of the defence's 143 past its
            -- skill, with the dodge's 5.1 % and the parry's 5 %: the game's sums alone at the character's level (16.2 %),
            -- 0.2 % less of each a level above (15.6 %, a raid boss's 14.4 %), asked; a raid boss's crushing blows, 15 %
            -- of them, and what leaves them no room, its 4.5 % of critical strikes the rest: 95.5 % avoided or blocked,
            -- 81.1 % short, asked; none below
            do
                local function said(what, figure, asked)
                    return string.format(L.STAT_TIER_ROW, what, figure) .. (asked and (" " .. mark) or "") .. "\n"
                end
                local tank = tip("KaLiHUD_Attr_DEFENSE")
                local tankFoot = table.concat((ns.StatCard.Lines(true)), "\n")
                expect(under(tank, 1, level(1), said(L.STAT_TIER_AVOID, PO(16.2, 1)))
                    and under(tank, 2, level(2), said(L.STAT_TIER_AVOID, PO(15.6, 1), true))
                    and under(tank, 4, level(4), said(L.STAT_TIER_AVOID, PO(14.4, 1), true))
                    and under(tank, 4, level(4), said(L.STAT_TIER_CRUSHING, P(0.15)))
                    and under(tank, 4, level(4), capped(L.STAT_TIER_NO_CRUSHING,
                        string.format(L.STAT_NO_CRUSHING_FIGURE, PO(95.5, 1)), missing(PO(81.1, 1)), true))
                    and not under(tank, 3, level(3), L.STAT_TIER_NO_CRUSHING)
                    and tankFoot:find(mark .. " " .. L.STAT_WHY_AVOID_LEVEL, 1, true),
                    "the card doesn't say the enemy's blows avoided or blocked, or a raid boss's crushing blows, level by "
                    .. "level: " .. tank)
                -- dodging and parrying near all of them (50 % and 40 %): what the roll leaves the crushing blows, 1.2 %,
                -- asked, 1.2 % short; past it (52 %), none land, the threshold reached
                local dodge, parry = GetDodgeChance, GetParryChance
                GetDodgeChance, GetParryChance = function()
                    return 50
                end, function()
                    return 40
                end
                local near = tip("KaLiHUD_Attr_DEFENSE")
                GetDodgeChance = function()
                    return 52
                end
                local full = tip("KaLiHUD_Attr_DEFENSE")
                GetDodgeChance, GetParryChance = dodge, parry
                local room = string.format(L.STAT_NO_CRUSHING_FIGURE, PO(95.5, 1))
                expect(under(near, 4, level(4), said(L.STAT_TIER_CRUSHING, PO(1.2, 1), true))
                    and under(near, 4, level(4), capped(L.STAT_TIER_NO_CRUSHING, room, missing(PO(1.2, 1)), true))
                    and under(full, 4, level(4), said(L.STAT_TIER_CRUSHING, P(0), true))
                    and under(full, 4, level(4), capped(L.STAT_TIER_NO_CRUSHING, room, reached, true)),
                    "the crushing blows aren't what the roll leaves them, or no room isn't reached past it: " .. near
                    .. " / " .. full)
            end
            -- the white hits' ceiling (Ikar: "go for the glancing"), level by level, the line showing the melee's: 100 %
            -- less the misses the hit's 3 % leaves (5 %, a raid boss's 8 % or 9 %), the dodges (5 %, 6.5 %) and the
            -- glancing blows the game gives (40 %, 35 % less damage), plus what an enemy above takes of the critical
            -- strikes, the sheet's holding the sword's 125 against the most's 115 already: 53 % at the character's level
            -- (10 % of crit, 43 % short), unmarked; a raid boss's 48.1 % or 49.9 %, the Skills tab taking 0.6 % of the
            -- sheet's, the original server 1.4 % (the skill's 0.4 % back, 0.2 % a point of its 5 past it), asked; two
            -- weapons 19 % more missed, 29.1 % or 30.9 %; none where the line shows the spells'
            do
                local critChance, dual, spellCrit = GetCritChance, IsDualWielding, GetSpellCritChance
                GetCritChance = function()
                    return 10
                end
                local white = tip("KaLiHUD_Attr_CRITCHANCE")
                local whiteFoot = table.concat((ns.StatCard.Lines(true)), "\n")
                IsDualWielding = function()
                    return true
                end
                local both = tip("KaLiHUD_Attr_CRITCHANCE")
                IsDualWielding, GetSpellCritChance = dual, function()
                    return 20
                end
                local caster = tip("KaLiHUD_Attr_CRITCHANCE")
                GetCritChance, GetSpellCritChance = critChance, spellCrit
                local glancing = string.format(L.STAT_TIER_ROW, L.STAT_TIER_GLANCING,
                    string.format(L.STAT_GLANCING_FIGURE, P(0.4), P(0.35))) .. "\n"
                expect(under(white, 1, level(1), glancing) and under(white, 4, level(4), glancing)
                    and under(white, 1, level(1), capped(L.STAT_TIER_WHITE_CAP, P(0.53), missing(PO(43, 1))))
                    and under(white, 4, level(4), capped(L.STAT_TIER_WHITE_CAP,
                        string.format(EITHER, PO(48.1, 1), PO(49.9, 1)),
                        missing(string.format(EITHER, PO(38.1, 1), PO(39.9, 1))), true))
                    and whiteFoot:find(mark .. " " .. L.STAT_WHY_WHITE_CAP, 1, true)
                    and details("KaLiHUD_Attr_CRITCHANCE"):find(" " .. L.STAT_HOW_CRIT .. " " .. L.STAT_TIERS_NONE, 1,
                        true),
                    "the card doesn't say the glancing blows and the white hits' ceiling level by level, or that the "
                    .. "line wears no numeral for them: " .. white)
                expect(under(both, 4, level(4), capped(L.STAT_TIER_WHITE_CAP .. ", " .. L.STAT_CAP_DUAL,
                        string.format(EITHER, PO(29.1, 1), PO(30.9, 1)),
                        missing(string.format(EITHER, PO(19.1, 1), PO(20.9, 1))), true)),
                    "the white hits' ceiling doesn't count two weapons' misses: " .. both)
                expect(not caster:find(L.STAT_TIER_WHITE_CAP, 1, true) and not caster:find(L.STAT_TIER_GLANCING, 1, true),
                    "the white hits' ceiling is said where the line shows the spells' critical strike: " .. caster)
            end
            -- the expertise: never dodged with 5 % at the character's level; a raid boss's parry 14 % or 16.5 % by the
            -- game's own texts, both, marked
            local expertise = tip("KaLiHUD_Attr_EXPERTISE")
            expect(under(expertise, 1, level(1), capped(L.STAT_TIER_NO_DODGE, P(0.05), missing(PO(5, 1))))
                and under(expertise, 4, level(4), capped(L.STAT_TIER_NO_PARRY, string.format(EITHER, P(0.14), PO(16.5, 1)),
                    missing(string.format(EITHER, PO(14, 1), PO(16.5, 1))), true)),
                "the card doesn't say the expertise each level never dodges and parries at: " .. expertise)
            -- a target two levels above (25): its level said so; the armour's most against it by the game's own sum
            -- (6 235 more), a resistance's five points a level (100 more)
            F.target = 25
            local them = level(3) .. " · " .. L.STAT_TIER_TARGET
            local onTarget = tip("KaLiHUD_Attr_HITCHANCE")
            local armourAt = tip("KaLiHUD_Attr_ARMOR")
            local fire = tip("KaLiHUD_Attr_FIRE")
            -- a target further above than the game's tables go (30): no level its own; the armour's and a resistance's
            -- most against it after the levels, at its level
            F.target = 30
            local far = tip("KaLiHUD_Attr_HITCHANCE")
            local farArmour = tip("KaLiHUD_Attr_ARMOR")
            local farFire = tip("KaLiHUD_Attr_FIRE")
            F.target = nil
            expect(under(onTarget, 3, them, capped(MELEE, string.format(EITHER, PO(5.4, 1), P(0.06)),
                    missing(string.format(EITHER, PO(2.4, 1), PO(3, 1))), true))
                and select(2, onTarget:gsub(L.STAT_TIER_TARGET, "")) == 1,
                "the target two levels above isn't said among the levels: " .. onTarget)
            expect(under(armourAt, 3, them, capped(L.STAT_TIER_ARMOR, P(0.75), missing(Number(6235))))
                and under(fire, 3, them, capped(L.STAT_TIER_RESIST, P(0.75), missing(Number(100)), true))
                and not armourAt:find(string.format(L.STAT_CAP_TARGET, 25), 1, true),
                "the armour's or a resistance's most isn't said against the target: " .. armourAt .. " / " .. fire)
            local farAt = string.format(L.STAT_CAP_TARGET, 30) .. "\n"
            expect(not far:find(L.STAT_TIER_TARGET, 1, true) and not far:find(farAt, 1, true)
                and farArmour:find(farAt .. string.format(L.STAT_TIER_ROW, L.STAT_TIER_ARMOR, P(0.75)) .. " — ", 1, true)
                and farFire:find(farAt .. string.format(L.STAT_TIER_ROW, L.STAT_TIER_RESIST, P(0.75)), 1, true),
                "a target further above than the game's tables go isn't left to the armour's and the resistances' own "
                .. "row: " .. far .. " / " .. farArmour)
        end
        local mark = ns.Stats.UNKNOWN
        -- the game's notes under what there is to know whatever the language (the review of 2026-11-19): in English
        -- their grey starts after the paragraph's first words, a raid boss's name in red, and its figures went under
        -- what the value gives
        CR_RANGED_EXPERTISE_TOOLTIP = "Increases the chance by %s\n\n|cFFFF5A5ARaid Boss|r|cffBCBCBC chance to:\n"
            .. "  6.50%% Dodge\n14.00%% Parry|r"
        t = tip("KaLiHUD_Attr_EXPERTISE")
        CR_RANGED_EXPERTISE_TOOLTIP = nil
        -- (its figures too, not the boss's name alone: with the notes' grey missed, the name stayed and they went)
        local effectsAt = t:find("\n" .. L.STAT_EFFECTS .. "\n", 1, true)
        expect(t:find("Raid Boss", 1, true) and effectsAt and t:find("Raid Boss", 1, true) < effectsAt
            and t:find("14.00% Parry", 1, true) and t:find("14.00% Parry", 1, true) < effectsAt,
            "the game's notes aren't under what there is to know when their grey starts mid-paragraph: " .. t)
        -- a source the data has no figure of (one following its caster's power): the mark in its place, and the
        -- card's foot saying what it asks, by its name (Ikar 2026-11-19: "the description should give an answer")
        ns.EFFECTS[999003] = "1,1;99:0:0:0:"
        F.auras.HELPFUL[1] = { name = "Cri inconnu", spellId = 999003 }
        t = tip("KaLiHUD_Attr_ATTACK_AP")
        lines = ns.StatCard.Lines()
        local meaning = table.concat((ns.StatCard.Lines(true)), "\n")
        F.auras.HELPFUL[1], ns.EFFECTS[999003] = nil, nil
        expect(after("Cri inconnu", mark) and meaning:find(mark .. " " .. string.format(L.STAT_WHY_CASTER, "Cri inconnu"),
            1, true), "a source of unknown amount has no question mark in its place, or the card doesn't say what it "
            .. "asks: " .. meaning)
        -- one known in part (one of its two effects without an amount): its figure, then the mark, not the figure
        -- passed off as the whole (the review of 2026-11-19)
        ns.EFFECTS[999001] = "2,2;99:0:0:0:;99:0:1:1:10"
        F.auras.HELPFUL[1] = { name = "Connu à moitié", spellId = 999001 }
        t = tip("KaLiHUD_Attr_ATTACK_AP")
        lines = ns.StatCard.Lines()
        F.auras.HELPFUL[1], ns.EFFECTS[999001] = nil, nil
        expect(after("Connu à moitié", Color("+10", GOOD) .. " " .. mark),
            "a source known in part shows its figure as the whole, without the mark: " .. t)
        F.itemStats[5], F.itemStats[6] = nil, nil
        -- strength: what it gives, each a figure over the game's own name for it
        t = tip("KaLiHUD_Attr_STRENGTH")
        lines = ns.StatCard.Lines()
        expect(after("+" .. Number(220), ns.G("STAT_ATTACK_POWER", "Attack Power"))
            and after("+5", ns.G("ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value")),
            "the card doesn't give strength's attack power and block value as figures: " .. t)
        -- an item's own spell while it's worn counts with its stats, on its row (7464: strength +1, the item's +3)
        do
            local stats = F.itemStats[2]
            ns.ITEM_SPELLS[1002], F.itemStats[2] = "7464", { ITEM_MOD_STRENGTH_SHORT = 3 }
            t = tip("KaLiHUD_Attr_STRENGTH")
            lines = ns.StatCard.Lines()
            ns.ITEM_SPELLS[1002], F.itemStats[2] = nil, stats
            expect(after("Objet 2", Color("+4", GOOD)), "an item's own spell while worn isn't counted on its row: " .. t)
        end
        -- a line without a figure inside a paragraph with one is something to know, and stays where figures stand for
        -- the sentences (Ikar 2026-11-19: "go"): the weapon skill's rate under intellect
        do
            local key = select(2, UnitClass("player")) .. "_INTELLECT_TOOLTIP"
            local was = _G[key]
            _G[key] = "Augmente les chances de coup critique avec les sorts de %.1f%%.\n"
                .. "Augmente la vitesse d'amélioration de la compétence d'arme."
            t = tip("KaLiHUD_Attr_INTELLECT")
            _G[key] = was
            local rate, effects = t:find("compétence d'arme", 1, true), t:find("\n" .. L.STAT_EFFECTS .. "\n", 1, true)
            expect(rate and effects and rate < effects and not t:find("coup critique avec les sorts de", 1, true),
                "a line without a figure is lost with its paragraph's figures, or the figures' sentence stays: " .. t)
        end
        -- health gives nothing: no such column; the hints at the card's foot, not among its texts
        t = tip("KaLiHUD_Attr_HEALTH")
        local _, healthColumns = ns.StatCard.Lines()
        local foot = table.concat((ns.StatCard.Lines(true)), "\n")
        expect(table.concat(healthColumns, " ") == "sources about" and not t:find(L.HINT_PIN, 1, true)
            and foot:find(L.HINT_PIN, 1, true),
            "a value that gives nothing keeps an empty column, or the card's foot hasn't the hints: " .. t)
        -- what the clicks do on one line; the input's glow on the left, and no output's for a card without that column
        -- (Ikar 2026-11-20)
        local card = _G.KaLiHUDStatCard
        local clicks = card.clicksAt and card.texts[card.clicksAt]:GetText() or ""
        expect(card.clicksAt == card.used and #card.clicks > 1 and clicks:find(L.HINT_PIN, 1, true)
            and clicks:find(card.clicks[#card.clicks], 1, true),
            "the card's click hints aren't on one line: " .. foot)
        expect(card.Glows.sources:IsShown() and select(1, card.Glows.sources:GetPoint()) == "TOPLEFT"
            and not card.Glows.effects:IsShown(),
            "the input's glow is missing, or the output's shows on a card without what it gives")
        tip("KaLiHUD_Attr_INTELLECT")
        local lit = card.Glows.effects.gradient
        expect(card.Glows.sources:IsShown() and card.Glows.effects:IsShown()
            and select(1, card.Glows.effects:GetPoint()) == "TOPRIGHT" and lit and lit[3].a > 0 and lit[2].a == 0,
            "the output's glow is missing, or doesn't light the card's right border")
        tip("KaLiHUD_Attr_HEALTH")
        -- it goes with the pointer, and with a click
        local shown = ns.StatCard.Owner() ~= nil
        Hub.Object("KaLiHUD_Attr_HEALTH").OnLeave()
        local left = ns.StatCard.Owner() == nil
        tip("KaLiHUD_Attr_HEALTH")
        F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        expect(shown and left and ns.StatCard.Owner() == nil, "the card stays once the pointer has left, or after a click")
        -- Ikar 2026-11-19: "do 10, 1, 2 […]", a card that stays open and follows; of how it shuts, "just keep the
        -- cross, and escape should close it too". A left click on an attribute keeps its card open, the character
        -- sheet left shut: a second card, there once the pointer has left and a click has landed elsewhere, with no
        -- hover's card beside it for the same value; drawn again as things change (the armour raised, a target
        -- taken); another attribute's on a click on that one; gone by its cross, after which nothing brings it back;
        -- gone by Escape as the game's windows are
        do
            local armour, health = Hub.Object("KaLiHUD_Attr_ARMOR"), Hub.Object("KaLiHUD_Attr_HEALTH")
            local button = Buttons.Get("KaLiHUD_Attr_ARMOR") or UIParent
            local function kept()
                return table.concat((ns.StatCard.PinnedLines(true)), "\n")
            end
            F.toggled.character = nil
            run(armour.OnEnter, button)
            run(armour.OnClick, button, "LeftButton")
            run(armour.OnLeave, button)
            F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
            F.RunTimers()
            local card = KaLiHUDStatCardPinned
            expect(card ~= nil and card:IsShown() and ns.StatCard.PinnedLines()[1] == ns.G("STAT_ARMOR", "Armor")
                and F.toggled.character == nil and not kept():find(L.HINT_PIN, 1, true),
                "a left click on an attribute doesn't keep its card open, the pointer gone and a click elsewhere: "
                .. kept())
            run(armour.OnEnter, button)
            expect(not KaLiHUDStatCard:IsShown(), "the hover's card shows beside the one kept open of the same value")
            run(armour.OnLeave, button)
            local unitArmor = UnitArmor
            UnitArmor = function()
                return 1200, 2000, 2000, 800
            end
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            local raised = kept()
            F.target = 25
            F.Fire("PLAYER_TARGET_CHANGED")
            F.RunTimers()
            expect(raised:find(Number(2000), 1, true) and not raised:find(L.STAT_TIER_TARGET, 1, true)
                and kept():find(L.STAT_TIER_TARGET, 1, true),
                "the card kept open isn't drawn again as the value changes, then as the target does: " .. raised
                .. " / " .. kept())
            -- the whole interface hidden and back (Alt+Z: the game tells the card it hides, though it wasn't shut):
            -- still kept, and drawn again after
            F.RunScript(card, "OnHide")
            UnitArmor = function()
                return 1200, 2100, 2100, 900
            end
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            expect(kept():find(Number(2100), 1, true),
                "the card kept open is let go when the whole interface hides, and no longer follows: " .. kept())
            UnitArmor, F.target = unitArmor, nil
            -- another attribute's card opens beside the first, which stays, neither over the other, both over the
            -- folders' lists (HIGH) and under the tooltips; a click on that attribute again shuts its card alone (Ikar
            -- 2026-11-23: "when clicking againt on a stat, it shoudl close the popup", "add a possibility to add
            -- multiple")
            local healthButton = Buttons.Get("KaLiHUD_Attr_HEALTH") or UIParent
            run(health.OnClick, healthButton, "LeftButton")
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            local second = ns.StatCard.PinnedFrame("HEALTH")
            local function apart()
                local l1, b1, r1, t1 = ns.StatCard.BoxOf("ARMOR")
                local l2, b2, r2, t2 = ns.StatCard.BoxOf("HEALTH")
                return l1 and l2 and (r1 <= l2 or r2 <= l1 or t1 <= b2 or t2 <= b1)
            end
            expect(card:IsShown() and second ~= nil and second ~= card and second:IsShown()
                and ns.StatCard.PinnedLines(false, "HEALTH")[1] == ns.G("HEALTH", "Health")
                and ns.StatCard.PinnedLines(false, "ARMOR")[1] == ns.G("STAT_ARMOR", "Armor")
                and apart() and card:GetFrameStrata() == "DIALOG" and second:GetFrameStrata() == "DIALOG",
                "a click on another attribute doesn't open its own card beside the first: " .. kept())
            run(health.OnClick, healthButton, "LeftButton")
            F.RunTimers()
            expect(not second:IsShown() and not ns.StatCard.Pinned("HEALTH") and card:IsShown()
                and ns.StatCard.Pinned("ARMOR"), "a click on an attribute whose card is kept open doesn't shut it alone")
            -- (its cross in a fight: the game's own close button hides through HideUIPanel, which a fight refuses, so
            -- the card's own click shuts it, as KaLi Recipe's notebook's since 2026-11-22)
            F.combat = true
            F.RunScript(card.Close, "OnClick", "LeftButton")
            F.combat = nil
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            expect(not card:IsShown(), "the card kept open stays after its cross, or comes back by itself")
            local escapes = false
            for _, name in ipairs(UISpecialFrames) do
                escapes = escapes or name == card:GetName()
            end
            run(armour.OnClick, button, "LeftButton")
            card:Hide()
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
            expect(escapes and not card:IsShown() and tip("KaLiHUD_Attr_ARMOR") ~= "",
                "Escape doesn't shut the card kept open for good, or the hover's card doesn't come back after it")
            Hub.Object("KaLiHUD_Attr_ARMOR").OnLeave()
        end
        -- Ikar 2026-11-19: "even better, update with a different color on an item, talent, consumable hover", then, of
        -- the colour, "go for the light blue". While a card is kept open, what the game's tooltip shows is tried on its
        -- value: the card says what would change, in the blue (darker since, Ikar 2026-11-25: Stats.lua's WOULD_HEX)
        do
            local BLUE, WAS = ns.Stats.WOULD_HEX, "ff808080"
            -- (the game's arrow, the font having no "→")
            local ARROW = ns.Stats.ARROW
            local function became(old, new)
                return Color(old, WAS) .. " " .. ARROW .. " " .. Color(new, BLUE)
            end
            local function link(id, name)
                return "|cffffffff|Hitem:" .. id .. ":::::::::60:::::|h[Objet " .. name .. "]|h|r"
            end
            local function kept()
                lines = ns.StatCard.PinnedLines()
                return table.concat((ns.StatCard.PinnedLines(true)), "\n")
            end
            -- (one card kept open at a time here: what each tries)
            local function pin(name)
                ns.StatCard.Unpin()
                run(Hub.Object(name).OnClick, Buttons.Get(name) or UIParent, "LeftButton")
            end
            local function hover(kind, data)
                F.Hover(kind, data)
                F.RunTimers()
                return kept()
            end
            local function talentsChanged()
                F.Fire("TRAIT_CONFIG_UPDATED", 1)
                F.RunTimers()
            end
            local function gone()
                F.RunScript(GameTooltip, "OnHide")
                F.RunTimers()
                return kept()
            end
            local unitArmor, stats5, stats6 = UnitArmor, F.itemStats[5], F.itemStats[6]
            UnitArmor = function()
                return 1200, 1340, 1340, 140
            end
            F.itemStats[5], F.itemStats[6] = { RESISTANCE0_NAME = 300 }, { RESISTANCE0_NAME = 200 }
            pin("KaLiHUD_Attr_ARMOR")
            local card = KaLiHUDStatCardPinned
            local narrow = card:GetWidth()
            -- an item for the chest, whose own armour is 300 now: 450, and 10 of agility, 2 of armour a point. The
            -- value would be 1 510, 170 more; the item worn goes, its figure down to 0, the one tried comes in its own
            -- quality's colour, the agility's share and the gear's sum say both figures; what the game's sums leave
            -- over (« Base », what's left of the changes) is as it was; the card wider for two figures a row
            F.items[2005] = { class = 4, subclass = 4, equip = "INVTYPE_CHEST" }
            F.itemStats[42] = { RESISTANCE0_NAME = 450, ITEM_MOD_AGILITY_SHORT = 10 }
            local t = hover("Item", { id = 2005, hyperlink = link(2005, 42) })
            expect(lines[2] == Color(Number(1510), BLUE) and lines[3] == Color(Number(1340), WAS) .. " "
                .. Color("+" .. Number(170), BLUE) .. " " .. ARROW and t:find(L.STAT_WOULD_HINT, 1, true),
                "the card kept open doesn't say what the value would be with the item under the pointer: " .. t)
            expect(after("Objet 5", became(Number(300), "0")) and after("|cff1eff00Objet 42|r", Color(Number(450), BLUE))
                and after(ns.G("SPELL_STAT2_NAME", "AGILITY"), became(Number(160), Number(180)))
                and after(L.STAT_GEAR, became(Number(500), Number(650))),
                "the rows that would go, come or change aren't said so, in the blue: " .. t)
            expect(after(L.STAT_OTHER, Color("+" .. Number(680), GOOD)),
                "what the game's sums leave over isn't as it was beside what would be: " .. t)
            expect(card:GetWidth() >= narrow + 80, "the card isn't wider for two figures a row")
            -- the tooltip gone: the card as it was
            t = gone()
            expect(not t:find(ARROW, 1, true) and lines[2] ~= Color(Number(1510), BLUE) and card:GetWidth() == narrow,
                "what would be stays once the tooltip has gone: " .. t)
            -- the same item beside a share of the items' own armour (Dire Bear Form's 360 %): its 150 more raised by
            -- it, 690, and the agility's 20, 710 more (the review of 2026-11-21: the share had been left out, 170)
            F.auras.HELPFUL[1] = { name = "Forme d'ours redoutable", spellId = 9635, points = { 0, 360, 0, 0, 0, 0, 0 } }
            t = hover("Item", { id = 2005, hyperlink = link(2005, 42) })
            expect(lines[3] == Color(Number(1340), WAS) .. " " .. Color("+" .. Number(710), BLUE) .. " " .. ARROW,
                "what an item would give beside a share of the items' own armour leaves the share out: " .. t)
            F.auras.HELPFUL[1] = nil
            gone()
            -- an item worn already (a ring, the second, which would else be tried in the first's place), and one that
            -- gives the value nothing: nothing to say
            F.items[1012] = { equip = "INVTYPE_FINGER" }
            F.itemStats[12] = { RESISTANCE0_NAME = 50 }
            t = hover("Item", { id = 1012, hyperlink = GetInventoryItemLink("player", 12) })
            F.items[2011] = { equip = "INVTYPE_FINGER" }
            F.itemStats[43] = { ITEM_MOD_STAMINA_SHORT = 5 }
            local nothing = hover("Item", { id = 2011, hyperlink = link(2011, 43) })
            expect(not t:find(ARROW, 1, true) and not nothing:find(ARROW, 1, true),
                "an item worn already, or one that gives the value nothing, is said to change it: " .. t .. " / "
                .. nothing)
            F.items[1012], F.itemStats[12], F.items[2011], F.itemStats[43] = nil, nil, nil, nil
            -- a two-handed weapon: the off hand's item goes with it (a shield's 100)
            F.itemStats[17] = { RESISTANCE0_NAME = 100 }
            F.items[2016] = { class = 2, subclass = 1, equip = "INVTYPE_2HWEAPON" }
            t = hover("Item", { id = 2016, hyperlink = link(2016, 44) })
            expect(after("Objet 17", became(Number(100), "0")),
                "a two-handed weapon is tried with the off hand's item kept: " .. t)
            F.itemStats[17], F.items[2016] = nil, nil
            -- a consumable whose spell the data has (200 of armour): a row more, 1 540, unmarked, the data's figure
            -- being the buff's own whoever has it (Ikar 2026-11-19, of an elixir's « +50 ? »: "what is the questio
            -- namrk for here ?"); nothing while the buff is on
            ns.ITEM_USES[3001] = "14803"
            F.items[3001] = { class = 0, subclass = 2 }
            t = hover("Item", { id = 3001, hyperlink = link(3001, 77) })
            expect(after("Objet 77", Color("+200", BLUE)) and lines[2] == Color(Number(1540), BLUE)
                and not t:find(ns.Stats.UNKNOWN, 1, true),
                "a consumable under the pointer isn't tried on the card kept open, or its fixed figure is marked: "
                .. t)
            -- (drunk under the pointer: the buff's coming draws the card again, the tooltip's refresh tries the same)
            F.auras.HELPFUL[1] = { name = "Bu", spellId = 14803, points = { 200 } }
            F.Fire("UNIT_AURA", "player")
            t = hover("Item", { id = 3001, hyperlink = link(3001, 77) })
            expect(not t:find(ARROW, 1, true), "a consumable whose buff is on is said to add it again: " .. t)
            F.auras.HELPFUL[1], ns.ITEM_USES[3001], F.items[3001] = nil, nil, nil
            -- a meal is a consumable as another (Ikar 2026-11-19: "wait, why meal does not work ?"): its buff, which
            -- the data follows from its eating, a row more, unmarked as an elixir's (Ikar 2026-11-19: "never seen a
            -- random buff are you sure about that ?"); one the data has no buff of changes nothing
            ns.ITEM_USES[3002] = "14803"
            F.items[3002], F.items[3003] = { class = 0, subclass = 5 }, { class = 0, subclass = 5 }
            t = hover("Item", { id = 3002, hyperlink = link(3002, 78) })
            local mealLines = lines
            local plain = hover("Item", { id = 3003, hyperlink = link(3003, 79) })
            expect(t:find("Objet 78", 1, true) and t:find(ARROW, 1, true) and not plain:find(ARROW, 1, true),
                "a meal under the pointer isn't tried as any consumable, or one with no buff is said to change the "
                .. "value: " .. t .. " / " .. plain)
            lines = mealLines
            expect(after("Objet 78", Color("+200", BLUE)) and mealLines[2] == Color(Number(1540), BLUE)
                and not t:find(ns.Stats.UNKNOWN, 1, true),
                "a meal's buff, the data's figure, is marked as unknown: " .. t)
            ns.ITEM_USES[3002], F.items[3002], F.items[3003] = nil, nil, nil
            gone()
            -- a weapon's oil goes with the weapon (strength: 4 from the main hand's, for a while)
            F.weaponEnchants[0] = { { hasEnchant = true, enchantType = 2, enchantID = 823 } }
            F.items[2017] = { class = 2, subclass = 7, equip = "INVTYPE_WEAPON" }
            pin("KaLiHUD_Attr_STRENGTH")
            t = hover("Item", { id = 2017, hyperlink = link(2017, 45) })
            expect(after(string.format(L.STAT_ENCHANT, ns.G("MAINHANDSLOT", "Main Hand")), became("+4", "0")),
                "a weapon's oil is kept with another weapon in its place: " .. t)
            -- (what the game's sums leave of an attribute, « Autres », as it is: once, not worked out again from what
            -- would be; the full review of 2026-11-20)
            expect(select(2, t:gsub("\n" .. L.STAT_OTHER .. "\n", "%0")) == 1,
                "an attribute's « Autres » is worked out again from what would be: " .. t)
            F.weaponEnchants, F.items[2017] = {}, nil
            gone()
            -- the dodge, whose share of the agility the game gives at its value now alone: followed point for point,
            -- 4 % at 80 of agility, 4.5 % at 90 with an item's 10, the dodge 5.1 % then 5.6 %, no question
            pin("KaLiHUD_Attr_DODGE")
            t = hover("Item", { id = 2005, hyperlink = link(2005, 42) })
            expect(lines[2] == Color(ns.Format.PercentOf(5.6, 2), BLUE), "the dodge isn't worked out with an item's "
                .. "agility: " .. t)
            gone()
            -- a talent (13712: 2 % of dodge a rank) at its next rank: 2 of 3 would be 3 of 3; nothing at its last; one
            -- not bought, at its first
            local function rank(n)
                return "Esquive (" .. string.format(ns.G("TOOLTIP_TALENT_RANK", "Rank %d/%d"), n, 3) .. ")"
            end
            local function percents(n)
                return "+" .. ns.Format.Percent(n / 100)
            end
            F.spellNames[13712] = "Esquive"
            F.talents = { { spell = 13712, rank = 2, ranks = 3 } }
            talentsChanged()
            t = hover("Spell", { id = 13712 })
            expect(after(rank(3), Color(percents(6), BLUE)) and after(rank(2), became(percents(4), "0")),
                "a talent under the pointer isn't tried at its next rank: " .. t)
            F.talents = { { spell = 13712, rank = 3, ranks = 3 } }
            talentsChanged()
            t = hover("Spell", { id = 13712 })
            expect(not t:find(ARROW, 1, true), "a talent at its last rank is tried at one more: " .. t)
            F.talents = { { spell = 13712, rank = 0, ranks = 3 } }
            talentsChanged()
            t = hover("Spell", { id = 13712 })
            expect(after(rank(1), Color(percents(2), BLUE)), "a talent not bought isn't tried at its first rank: " .. t)
            F.talents, F.spellNames[13712] = {}, nil
            talentsChanged()
            gone()
            -- beside a share of an attribute the game counts in its base (Mental Dexterity's 30 of the intellect): a
            -- ring of 10 attack power would make it 10 more, not 10 less its 30 (the review of 2026-11-21)
            local attackPower = UnitAttackPower
            UnitAttackPower = function()
                return 299, 20, 0
            end
            F.talents, F.spellNames[415140] = { { spell = 415140, rank = 2, ranks = 3 } }, "Dextérité mentale"
            talentsChanged()
            pin("KaLiHUD_Attr_ATTACK_AP")
            F.items[2006], F.itemStats[43] = { equip = "INVTYPE_FINGER" }, { ITEM_MOD_ATTACK_POWER_SHORT = 10 }
            t = hover("Item", { id = 2006, hyperlink = link(2006, 43) })
            expect(lines[2] == Color(Number(329), BLUE),
                "what would be beside a share of an attribute in the game's base is off by it: " .. t)
            gone()
            F.items[2006], F.itemStats[43], F.talents, F.spellNames[415140] = nil, nil, {}, nil
            UnitAttackPower = attackPower
            talentsChanged()
            card:Hide()
            UnitArmor, F.itemStats[5], F.itemStats[6] = unitArmor, stats5, stats6
            F.items[2005], F.itemStats[42] = nil, nil
            F.Fire("UNIT_STATS", "player")
            F.RunTimers()
        end
        expect(errors() == before, "the attributes' card errs")
    end)
    local was = text("KaLiHUD_Attr_ARMOR")
    F.statsSecret = true
    F.Fire("UNIT_STATS", "player")
    F.Fire("UNIT_RESISTANCES", "player")
    F.RunTimers()
    expect(text("KaLiHUD_Attr_ARMOR") == was and was:find("1", 1, true) and errors() == before,
        "an attribute hidden in a fight doesn't keep its text, or errs: " .. tostring(text("KaLiHUD_Attr_ARMOR")))
    F.statsSecret = false
    expect(errors() == before, "an error in the attributes' items: " .. tostring(next(KaLiHUDDevDB.errors or {})))
end

do
    local before = errors()
    -- reagents: a warrior's ammunition alone; another class's reagents nowhere, nor taken for another addon's
    local reagents = Folders.ByRole("reagents")
    expect(names(reagents) == "Ammo" and text("KaLiHUD_Ammo"):match("(%S+)$") == "412"
        and not Hub.Entry("KaLiHUD_Reagent_6265"),
        "the reagents' folder for a warrior: " .. names(reagents))
    -- the others: junk's worth, the currencies on the backpack, the zone's PvP state and levels, today's calendar
    local infos = Folders.ByRole("infos")
    expect(names(infos) == "Junk Currencies | ZonePvP ZoneLevel | Today Alarm Stopwatch", "the infos' folder: " .. names(infos))
    expect(Buttons.Get("KaLiHUD_Junk").Text:GetText() == GetMoneyString(195, true), "junk's worth: " .. tostring(text("KaLiHUD_Junk")))
    expect(text("KaLiHUD_Currencies"):find(ns.Format.Number(1250), 1, true), "currencies: " .. tostring(text("KaLiHUD_Currencies")))
    local pvp = Hub.Object("KaLiHUD_ZonePvP")
    expect(pvp.iconGrey and pvp.iconR == 0.1 and pvp.iconG == 1 and Buttons.Get("KaLiHUD_ZonePvP").Icon.desaturated ~= false,
        "a friendly zone's flag isn't green")
    -- one the game names no faction for (a PvE realm's): the player's, a hostile one the other's (Ikar 2026-11-21:
    -- "Aucun status jcj ... why ?")
    do
        local friendly = text("KaLiHUD_ZonePvP")
        local pvpInfo = C_PvP.GetZonePVPInfo
        C_PvP.GetZonePVPInfo = function()
            return "hostile"
        end
        F.Fire("ZONE_CHANGED_NEW_AREA")
        F.RunTimers()
        local hostile = text("KaLiHUD_ZonePvP")
        C_PvP.GetZonePVPInfo = pvpInfo
        F.Fire("ZONE_CHANGED_NEW_AREA")
        F.RunTimers()
        expect(friendly == "Territoire Alliance" and hostile == "Territoire Horde",
            "a zone the game names no faction for says no PvP state: " .. tostring(friendly) .. " / " .. tostring(hostile))
    end
    local pvpInfo = C_PvP.GetZonePVPInfo
    C_PvP.GetZonePVPInfo = function()
        return "contested"
    end
    F.Fire("ZONE_CHANGED_NEW_AREA")
    F.RunTimers()
    expect(pvp.iconR == 1 and pvp.iconG == 0.7 and text("KaLiHUD_ZonePvP") ~= L.PVP_NONE, "a contested zone's flag isn't orange")
    C_PvP.GetZonePVPInfo = pvpInfo
    -- The zone's levels as Forever's own Group Finder suggests them (Ikar 2026-11-18: "Add the table, scrap the data",
    -- "for forever, be carrefull"): Westfall's 8-24; a cave's map, its zone's; a city the Group Finder doesn't list,
    -- none.
    expect(text("KaLiHUD_ZoneLevel"):find("8-24", 1, true), "the zone's levels: " .. tostring(text("KaLiHUD_ZoneLevel")))
    run(function()
        local info = C_Map.GetMapInfo
        C_Map.GetMapInfo = function(map)
            if map == 99001 then
                return { mapID = map, name = "Mine", mapType = 5, parentMapID = 1436 }
            end
            return info(map)
        end
        F.mapID = 99001
        F.Fire("ZONE_CHANGED_NEW_AREA")
        F.RunTimers()
        local cave = text("KaLiHUD_ZoneLevel")
        F.mapID = 1453
        F.Fire("ZONE_CHANGED_NEW_AREA")
        F.RunTimers()
        local city = text("KaLiHUD_ZoneLevel")
        C_Map.GetMapInfo, F.mapID = info, nil
        F.Fire("ZONE_CHANGED_NEW_AREA")
        F.RunTimers()
        expect(cave:find("8-24", 1, true) and city:find("—", 1, true) and not city:find("%d"),
            "a cave's map doesn't give its zone's levels, or a city has some: " .. cave .. ", " .. city)
    end)
    expect(text("KaLiHUD_Today") == "1 +1" and (F.calendarOpened or 0) >= 1, "today: " .. tostring(text("KaLiHUD_Today")))
    F.RunScript(Buttons.Get("KaLiHUD_Today"), "OnEnter")
    expect(table.concat(F.tooltip.lines, "\n"):find("Foire de Sombrelune", 1, true), "today's events aren't in its tooltip")
    F.RunScript(Buttons.Get("KaLiHUD_Today"), "OnLeave")
    local calendar = F.toggled.calendar or 0
    click("KaLiHUD_Today", "LeftButton")
    expect(F.toggled.calendar == calendar + 1, "today's click doesn't open the calendar")

    -- the guild: online, its message cut to a few words; whisper from its menu; the friends
    expect(text("KaLiHUD_Guild") == "2" and text("KaLiHUD_GuildMotd"):find("…$") and text("KaLiHUD_Friends") == "3",
        "guild, its message, friends: " .. tostring(text("KaLiHUD_Guild")) .. ", " .. tostring(text("KaLiHUD_GuildMotd")))
    click("KaLiHUD_Guild", "RightButton")
    local lysa = F.MenuItem("|cffc79c6eLysa|r") or F.MenuItem("Lysa")
    if lysa then
        run(lysa.choose)
    end
    expect(lysa and F.toldTo == "Lysa-Forever", "the guild's menu doesn't whisper one online")

    -- the group: its loot rule once in one; the raid's tools the game's commands
    local group = Folders.ByRole("group")
    expect(text("KaLiHUD_Loot") == "—", "a loot rule out of a group: " .. tostring(text("KaLiHUD_Loot")))
    F.inGroup = true
    F.Fire("GROUP_ROSTER_UPDATE")
    F.RunTimers()
    expect(text("KaLiHUD_Loot") == "Butin de groupe · Inhabituel", "the loot rule: " .. tostring(text("KaLiHUD_Loot")))
    -- set from the item by the leader, as from the game's portrait (Ikar 2026-11-20: "the group loot shoudl also allow
    -- to change it when clicked"); the methods the game offers alone; anyone else's click opens nothing
    do
        F.lastMenu = nil
        click("KaLiHUD_Loot", "LeftButton")
        local none = F.lastMenu == nil
        F.RunScript(Buttons.Get("KaLiHUD_Loot"), "OnEnter")
        local told = has(L.LOOT_TIP)
        F.leader = true
        F.RunScript(Buttons.Get("KaLiHUD_Loot"), "OnEnter")
        local hinted = has(L.HINT_LOOT)
        click("KaLiHUD_Loot", "LeftButton")
        local need = F.MenuItem("Butin : Le besoin avant la cupidité")
        local master = F.MenuItem("Butin : Responsable du butin")
        local rare = F.MenuItem("|cff0070ddRare|r")
        if need and rare then
            run(need.choose)
            run(rare.choose)
        end
        local set = F.lootMethod == 4 and F.lootThreshold == 3
        if master then
            run(master.choose)
        end
        expect(none and told and hinted and set and master and F.lootMethod == 2 and F.lootMaster == UnitName("player")
            and F.MenuItem("Butin : Accès libre") == nil,
            "the loot rules aren't set from the item by the leader alone, or its tooltip doesn't say who sets them")
        F.leader, F.lootMethod, F.lootThreshold, F.lootMaster = nil, 3, 2, nil
    end
    F.inGroup = false
    F.Fire("GROUP_ROSTER_UPDATE")
    F.RunTimers()
    local commands = {}
    for _, e in ipairs(Hub.InFolder(group)) do
        local m = Macros.Get(e.name)
        commands[#commands + 1] = m and m.text or nil
    end
    -- the world markers as the raid's menu lists them, the skull first, wearing the raid frame's icon of their sign
    local skull
    for _, e in ipairs(Hub.InFolder(group)) do
        local m = Macros.Get(e.name)
        skull = skull or (m and m.text == "/tm 8" and m) or nil
    end
    -- each marker: its left click the sign on the target, its right click the marker on the ground, no [@cursor], each
    -- said by its button (Ikar 2026-11-20: "they shoudl be left click on target right click spell on ground")
    expect(commands[1] == "/readycheck" and commands[2] == "/countdown 10" and commands[3] == "/tm 8"
        and commands[4] == "/tm 7" and commands[10] == "/tm 1" and commands[11] == "/cwm all\n/click KaLiHUD_ClearSigns"
        and #commands == 11 and skull and skull.icon == "GM-raidMarker1" and skull.right == "/wm 8"
        and skull.leftDesc == L.MARKER_TARGET and skull.rightDesc == L.MARKER_GROUND,
        "the raid's tools: " .. table.concat(commands, ", ") .. " / " .. tostring(skull and skull.right))
    -- locked (UI/Hub/Seeds.lua): a marker as an earlier build made it, `/wm [@cursor] 8` on its left click, made as now
    -- at the next login
    do
        local function seeded(seed)
            for _, e in ipairs(Hub.InFolder(group)) do
                local m = Macros.Get(e.name)
                if m and m.seed == seed then
                    return e.name
                end
            end
        end
        do
            local skullId = seeded("group:marker8")
            local m = Macros.Get(skullId)
            m.text, m.right, m.rightDesc = "/wm [@cursor] 8", nil, nil
            ns.Seeds.Run()
            F.RunTimers()
            local o = Macros.Get(skullId)
            expect(o.text == "/tm 8" and o.right == "/wm 8" and o.rightDesc == L.MARKER_GROUND,
                "a marker an earlier build made isn't made as now at the next login")
        end
        -- « Tout effacer »: the ground's markers and the targets' signs (Ikar 2026-11-20: "tout effacer remove only the one
        -- on the ground"), the signs by the game's secure action, its button clicked by the macro; one an earlier build
        -- made made as now at the next login
        do
            local signs = _G[ns.Social.CLEAR_SIGNS]
            local n = F.raidTargetsRemoved or 0
            if signs then
                F.RunScript(signs, "OnClick", "LeftButton", false)
            end
            local cleared = (F.raidTargetsRemoved or 0) == n + 1
            local clear = seeded("group:clearmarkers")
            Macros.Get(clear).text, Macros.Get(clear).leftDesc = "/cwm all", nil
            ns.Seeds.Run()
            F.RunTimers()
            expect(cleared and Macros.Get(clear).text == "/cwm all\n/click KaLiHUD_ClearSigns"
                and Macros.Get(clear).leftDesc == L.MARKERS_CLEAR,
                "« Tout effacer » leaves the targets' signs, or one an earlier build made isn't made as now at the next login")
        end
    end
    -- the map the player's key opens (Ikar 2026-11-21: "qhen opening the map, we open the default map, not the one
    -- that open with m shortcut"): the game's, or an addon's that took the key (Zmap's override click)
    do
        local maps, theirs = F.toggled.map or 0, 0
        local own = CreateFrame("Button", "KaLiHUD_TestOtherMap", UIParent)
        own:SetScript("OnClick", function()
            theirs = theirs + 1
        end)
        -- (a button's Click, the game's, which runs its OnClick)
        function own:Click(button)
            F.RunScript(self, "OnClick", button, false)
        end
        click("KaLiHUD_Location", "LeftButton")
        local game = (F.toggled.map or 0) == maps + 1
        F.overrides.M = "CLICK KaLiHUD_TestOtherMap:LeftButton"
        click("KaLiHUD_Location", "LeftButton")
        click("KaLiHUD_ZonePvP", "LeftButton")
        F.overrides.M = nil
        expect(game and theirs == 2 and (F.toggled.map or 0) == maps + 1,
            "the map opened isn't the one the player's key opens")
    end
    click("KaLiHUD_Difficulty", "RightButton")
    run(F.MenuItem(ns.G("RESET_INSTANCES", "Reset all instances")).choose)
    expect(F.instancesReset == 1 and text("KaLiHUD_Difficulty") == "Normal", "the difficulty, or resetting the instances")

    -- the session: its time, away; the errors, the error addon's and the game's blocks
    local session = Folders.ByRole("session")
    expect(names(session):find("^Session Errors |") and text("KaLiHUD_Session") == ns.Format.Duration(4000),
        "the session's folder: " .. names(session))
    F.afk = true
    F.Fire("PLAYER_FLAGS_CHANGED", "player")
    F.RunTimers()
    expect(text("KaLiHUD_Session"):find("^" .. ns.G("AFK", "AFK")), "away doesn't show: " .. tostring(text("KaLiHUD_Session")))
    F.afk = false
    F.Fire("PLAYER_FLAGS_CHANGED", "player")
    F.RunTimers()
    local blockedBefore = #ns.Session.Blocked
    F.luaErrors[#F.luaErrors + 1] = { message = "Interface/AddOns/Other/x.lua:1: oops", session = 7, counter = 2 }
    EventRegistry:TriggerEvent("BugGrabber.BugGrabbed")
    F.Fire("ADDON_ACTION_BLOCKED", "OtherAddon", "Frame:Show()")
    F.RunTimers()
    expect(text("KaLiHUD_Errors") == tostring(3 + blockedBefore), "the session's errors: " .. tostring(text("KaLiHUD_Errors")))
    local last = {}
    for _, e in ipairs(Hub.InFolder(session)) do
        local m = Macros.Get(e.name)
        last[#last + 1] = m and m.text or nil
    end
    expect(table.concat(last, " ") == "/reload /cdm /logout /quit", "the session's commands: " .. table.concat(last, " "))

    -- the record: achievement points, deaths, the statistics the game knows
    local statistics = Folders.ByRole("statistics")
    expect(names(statistics) == "Achievements Deaths | Statistic_98", "the statistics' folder: " .. names(statistics))
    F.Fire("PLAYER_DEAD")
    F.RunTimers()
    expect(text("KaLiHUD_Deaths"):match("(%S+)$") == "1" and text("KaLiHUD_Statistic_98") == "Quêtes terminées 212",
        "deaths, a statistic: " .. tostring(text("KaLiHUD_Deaths")))

    -- A new measure, from the session readout's menu (the review of 2026-11-17, second round; Ikar: "Why not"): the gold
    -- won, the experience gained, the deaths and the time count from now, each tooltip saying since when; none says so
    -- before one is asked for, and the time since login stays in the session's tooltip.
    do
        local function tip(name)
            F.RunScript(Buttons.Get(name), "OnEnter")
            local lines = {}
            for i, line in ipairs(F.tooltip.lines) do
                lines[i] = tostring(line)
            end
            F.RunScript(Buttons.Get(name), "OnLeave")
            return lines
        end
        -- what stands right of a label in a tooltip
        local function value(lines, label)
            for i, line in ipairs(lines) do
                if line == label then
                    return lines[i + 1]
                end
            end
        end
        local prefix = L.MEASURE_SINCE:gsub("%%s.*", "")
        local function says(lines)
            for _, line in ipairs(lines) do
                if line:sub(1, #prefix) == prefix then
                    return true
                end
            end
            return false
        end
        F.money = F.money + 70000
        F.Fire("PLAYER_MONEY")
        F.xp.cur = F.xp.cur + 200
        F.Fire("PLAYER_XP_UPDATE", "player")
        F.RunTimers()
        local gold = tip("KaLiHUD_Gold")
        expect(ns.Items.MeasureSince() == nil and not says(gold) and value(gold, L.GOLD_SESSION) ~= "0c"
            and value(tip("KaLiHUD_XP"), L.XP_SESSION) ~= ns.Format.Number(0)
            and text("KaLiHUD_Deaths"):match("(%S+)$") == "1",
            "setup: gold won, experience gained and a death since login, no measure yet: " .. tostring(value(gold, L.GOLD_SESSION)))
        click("KaLiHUD_Session", "RightButton")
        local new = F.MenuItem(L.MEASURE_NEW)
        expect(new ~= nil, "the session's menu has no new measure")
        if new then
            run(new.choose)
            F.RunTimers()
            F.Advance(120)
            ns.Infos.Update()
            F.RunTimers()
            gold = tip("KaLiHUD_Gold")
            local deaths, session, xp = tip("KaLiHUD_Deaths"), tip("KaLiHUD_Session"), tip("KaLiHUD_XP")
            expect(ns.Items.MeasureSince() ~= nil and value(gold, L.GOLD_SESSION) == "0c" and says(gold),
                "a new measure doesn't start the gold won again, or its tooltip doesn't say since when: " .. tostring(value(gold, L.GOLD_SESSION)))
            expect(value(xp, L.XP_SESSION) == ns.Format.Number(0) and says(xp),
                "a new measure doesn't start the experience gained again, or its tooltip doesn't say since when: " .. tostring(value(xp, L.XP_SESSION)))
            expect(text("KaLiHUD_Deaths"):match("(%S+)$") == "0" and value(deaths, L.DEATHS_SESSION) == "0"
                and says(deaths),
                "a new measure doesn't start the deaths again, or their tooltip doesn't say since when: " .. tostring(text("KaLiHUD_Deaths")))
            expect(text("KaLiHUD_Session") ~= ns.Format.Duration(4000) and value(session, L.MEASURE) == text("KaLiHUD_Session")
                and value(session, L.SESSION_TIME) == ns.Format.Duration(4000),
                "a new measure doesn't start the session's time again, or the time since login leaves its tooltip: "
                .. tostring(text("KaLiHUD_Session")))
            F.xp.cur = F.xp.cur + 100
            F.Fire("PLAYER_XP_UPDATE", "player")
            F.RunTimers()
            expect(value(tip("KaLiHUD_XP"), L.XP_SESSION) == ns.Format.Number(100),
                "the experience gained after a new measure isn't counted from it: " .. tostring(value(tip("KaLiHUD_XP"), L.XP_SESSION)))
            F.xp.cur = F.xp.cur - 100
        end
        F.xp.cur = F.xp.cur - 200
        F.money = F.money - 70000
        F.Fire("PLAYER_MONEY")
        F.Fire("PLAYER_XP_UPDATE", "player")
        F.RunTimers()
    end

    -- The reputations (Ikar 2026-11-17, in place of a reputation chosen for each progress bar: "We can add a reputation
    -- folder"): one item for each faction the game's pane lists, none for a header with no standing of its own, in the
    -- folder made for them at the bar's left side; each its standing, in its colour, and how far into it, nothing more
    -- at the last standing. A faction met shows, last; one the pane no longer lists goes. Its menu sets the game's
    -- watched faction, the one a progress bar shows, and unsets it.
    do
        local reps = Folders.ByRole("reputations")
        local DARNASSUS, STORMWIND, DAWN = "KaLiHUD_Reputation_69", "KaLiHUD_Reputation_72", "KaLiHUD_Reputation_529"
        expect(reps and Hub.Entry(reps).side == "left"
            and Folders.Setting(reps, "perLine") == 12 and Folders.Get(reps).name == ns.G("REPUTATION", "Reputation")
            and Folders.Get(reps).icon == "delves-scenario-flag",
            "the reputations' folder isn't made at the bar's left side, twelve to a column")
        expect(reps and names(reps) == "Reputation_69 Reputation_72 Reputation_529",
            "the reputations' folder holds a header, or not each faction the pane lists: " .. tostring(reps and names(reps)))
        expect(text(DARNASSUS) == "Darnassus Honoré " .. ns.Format.Percent(6480 / 12000) and text(STORMWIND) == "Hurlevent Exalté"
            and text(DAWN) == "Aube d'argent Neutre " .. ns.Format.Percent(0.25)
            and F.Shows(Buttons.Get(DARNASSUS)):find("|cff00991a", 1, true),
            "a reputation doesn't say its standing in its colour and how far into it: " .. tostring(text(DARNASSUS)))
        F.RunScript(Buttons.Get(DARNASSUS), "OnEnter")
        local lines = table.concat(F.tooltip.lines, "|")
        F.RunScript(Buttons.Get(DARNASSUS), "OnLeave")
        expect(lines:find("Darnassus", 1, true) and lines:find("Honoré", 1, true)
            and lines:find(ns.Format.Number(6480) .. " / " .. ns.Format.Number(12000), 1, true)
            and lines:find(string.format(L.STATUS_TO_GO, ns.Format.Number(5520)), 1, true)
            and lines:find("Les elfes de la nuit de Teldrassil.", 1, true) and lines:find(L.HINT_XP, 1, true),
            "a reputation's tooltip lacks its standing, its count, what's left or the faction's own words: " .. lines)
        -- its menu: the game's watched faction, this one then none
        local watch = ns.G("SHOW_FACTION_ON_MAINSCREEN", L.REP_WATCH)
        click(DAWN, "RightButton")
        local box = F.MenuItem(watch)
        expect(box and box.kind == "checkbox" and not box.isSelected(), "a reputation's menu has no box to show it on the progress bar")
        if box then
            run(box.choose)
            F.RunTimers()
            click(DAWN, "RightButton")
            box = F.MenuItem(watch)
            expect(F.watched[#F.watched] == 529 and box and box.isSelected() and F.faction.name == "Aube d'argent",
                "a reputation's box doesn't make it the game's watched faction: " .. tostring(F.watched[#F.watched]))
            run(box.choose)
            F.RunTimers()
            click(DAWN, "RightButton")
            box = F.MenuItem(watch)
            expect(F.watched[#F.watched] == 0 and box and not box.isSelected(), "a reputation's box unticked leaves it the watched faction")
        end
        C_Reputation.SetWatchedFactionByID(69)
        -- one under a header folded in the pane: gone, back once unfolded; a faction met: last of the folder
        local stormwind = table.remove(F.factions, 3)
        F.Fire("UPDATE_FACTION")
        F.RunTimers()
        expect(names(reps) == "Reputation_69 Reputation_529" and Hub.Entry(STORMWIND) == nil,
            "a faction the pane no longer lists stays in the reputations' folder: " .. names(reps))
        table.insert(F.factions, 3, stormwind)
        F.factions[#F.factions + 1] = { factionID = 21, name = "Baie-du-Butin", description = "", reaction = 4,
            currentReactionThreshold = 0, nextReactionThreshold = 3000, currentStanding = 150, isHeader = false, isWatched = false }
        F.Fire("UPDATE_FACTION")
        F.RunTimers()
        expect(names(reps) == "Reputation_69 Reputation_72 Reputation_529 Reputation_21"
            and Hub.Label("KaLiHUD_Reputation_21") == "Baie-du-Butin",
            "a faction the pane lists again isn't back, or one met isn't last of the reputations' folder: " .. names(reps))
        table.remove(F.factions)
        F.Fire("UPDATE_FACTION")
        F.RunTimers()
        expect(names(reps) == "Reputation_69 Reputation_72 Reputation_529", "setup: the pane's three factions again: " .. names(reps))
        -- a locked folder a later build adds (a game saved before it): made at the next login, with no mark of its
        -- own, at the inner end of the bar's left side, so nothing on the bar moves, its items coming to it; made once
        do
            local count = #Folders.List()
            Folders.Get(reps).role = nil
            Hub.Changed()
            run(ns.Seeds.Run)
            F.RunTimers()
            local made = Folders.ByRole("reputations")
            local left = Hub.Side("left")
            expect(made and made ~= reps and #Folders.List() == count + 1
                and left[#left].name == made and names(made) == "Reputation_69 Reputation_72 Reputation_529",
                "a locked folder a later build adds isn't made at the next login, at the inner end of the bar's left side: "
                .. tostring(made and names(made)))
            run(ns.Seeds.Run)
            F.RunTimers()
            expect(#Folders.List() == count + 1, "a locked folder is made again while it's there")
            if made and made ~= reps then
                -- the first one back for what follows, the second gone
                Folders.Get(made).role = nil
                Folders.Get(reps).role = "reputations"
                Hub.Changed()
                Folders.Delete(made)
                F.RunTimers()
            end
            expect(Folders.ByRole("reputations") == reps and #Folders.List() == count
                and names(reps) == "Reputation_69 Reputation_72 Reputation_529", "setup: the reputations' folder as it was")
        end
        -- the bar's menu lists their folder, not each of them: it is locked (UI/Hub/Seeds.lua), its box stands for
        -- what it holds
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        expect(F.MenuItem(L.CAT_reputations) == nil and F.MenuItem("Darnassus") == nil
            and F.MenuItem(Folders.Get(reps).name, F.MenuItem(L.CAT_folders)) ~= nil,
            "the bar's menu lists the reputations one by one, or not their folder")
        ns.StatusBars.Refresh()
        F.RunTimers()
    end
    expect(errors() == before, "an error in the bar's readouts: " .. tostring(next(KaLiHUDDevDB.errors or {})))
end

do
    local before = errors()
    local infos = Folders.ByRole("infos")
    -- every item of ours named, as the bar's menu and Edit Mode list it, never by its id
    local unnamed = {}
    for _, e in ipairs(Hub.Entries()) do
        if e.ours and Hub.Label(e.name, e.obj) == e.name then
            unnamed[#unnamed + 1] = e.name
        end
    end
    expect(#unnamed == 0, "items of ours listed by their id: " .. table.concat(unnamed, ", "))
    -- the alarm's title says whether it's on, as the clock's window does
    F.RunScript(Buttons.Get("KaLiHUD_Alarm"), "OnEnter")
    expect(F.tooltip.lines[1] == ns.G("TIMEMANAGER_ALARM_DISABLED", "Alarm Disabled"),
        "the alarm off says it's on: " .. tostring(F.tooltip.lines[1]))
    F.RunScript(Buttons.Get("KaLiHUD_Alarm"), "OnLeave")
    -- in a list running down, the text of one without an icon starts where its neighbours' does, past an icon's room
    Folders.SetOpen(infos, true)
    InfoBar.Refresh()
    local function left(name)
        local b = Buttons.Get(name)
        return b.ux - b:GetWidth() / 2
    end
    local indent = left("KaLiHUD_Currencies") - left("KaLiHUD_Junk")
    expect(math.abs(indent - (Hub.IconSize() + 3)) < 0.5, "the currencies' text isn't under the junk's: " .. indent)
    Folders.SetOpen(infos, false)
    InfoBar.Refresh()

    -- Separators: added from a folder's menu, last in it; a rule across its line between its neighbours, counted not,
    -- the lines made by the count alone (Ikar 2026-11-16: "separators, I thought about horizontal, not vertical"): as
    -- many to a line as the emotes and one, they, the separator and the first voice emote in one, the second in the next
    -- (« Emote » is locked, UI/Hub/Seeds.lua: one of the player's for these, its role taken off until the block ends)
    local emotes = Folders.ByRole("emotes")
    Folders.Get(emotes).role = nil
    Folders.SetOpen(emotes, true)
    local inEmotes = Hub.InFolder(emotes)
    -- (made with a title over each kind, the voices' starting a column: plain rules here, as they were)
    F.heads = {}
    for _, e in ipairs(inEmotes) do
        if e.isSeparator then
            F.heads[#F.heads + 1] = { id = e.name, was = ns.db.separators[e.name] }
            ns.Separators.Dress(e.name, nil)
        end
    end
    local first, last, sep, voice, voice2, at
    for i, e in ipairs(inEmotes) do
        if e.isSeparator and first then
            last, sep, at = inEmotes[i - 1].name, e.name, i - 1
            voice, voice2 = inEmotes[i + 1] and inEmotes[i + 1].name, inEmotes[i + 2] and inEmotes[i + 2].name
        elseif not e.isSeparator then
            first = first or e.name
        end
    end
    local perBefore = Folders.Get(emotes).perLine
    Folders.Get(emotes).perLine = at
    InfoBar.Refresh()
    local fb, lb, sb, vb, v2 = Buttons.Get(first), Buttons.Get(last), Buttons.Get(sep), Buttons.Get(voice), Buttons.Get(voice2)
    local function edge(b)
        return b.ux - b:GetWidth() / 2
    end
    local function between(a, b, c)
        return (a - b) * (b - c) > 0
    end
    local function where()
        return string.format(" (first %.1f,%.1f; last %.1f,%.1f; separator %.1f,%.1f %.1fx%.1f; voice %.1f,%.1f; next %.1f,%.1f)",
            edge(fb), fb.uy, edge(lb), lb.uy, sb.ux, sb.uy, sb:GetWidth(), sb:GetHeight(), edge(vb), vb.uy, edge(v2), v2.uy)
    end
    expect(fb and lb and sb and vb and v2 and sb:IsShown() and math.abs(edge(fb) - edge(vb)) < 0.5
        and between(lb.uy, sb.uy, vb.uy) and sb:GetWidth() > 20 and sb:GetHeight() < 12
        and math.abs(edge(v2) - edge(fb)) > 20, "a separator down a list isn't a rule in its column, counted not" .. where())
    Folders.Get(emotes).flow = "horizontal"
    InfoBar.Refresh()
    expect(math.abs(fb.uy - vb.uy) < 0.5 and between(lb.ux, sb.ux, vb.ux) and sb:GetWidth() < 12 and sb:GetHeight() > 10
        and math.abs(v2.uy - fb.uy) > 10, "a separator across a list isn't a rule in its row, counted not" .. where())
    Folders.Get(emotes).flow, Folders.Get(emotes).perLine = "vertical", perBefore
    InfoBar.Refresh()
    -- text so many to a line, as icons: down a list, a new column after them; across, a new row
    local firsts = {}
    for _, e in ipairs(inEmotes) do
        if e.isSeparator and #firsts > 0 then
            break
        elseif not e.isSeparator then
            firsts[#firsts + 1] = Buttons.Get(e.name)
        end
    end
    local function leftOf(b)
        return b.ux - b:GetWidth() / 2
    end
    local perWas = Folders.Get(emotes).perLine
    Folders.Get(emotes).perLine = 2
    InfoBar.Refresh()
    local b1, b2, b3 = firsts[1], firsts[2], firsts[3]
    -- (the first under the plain rule that heads the list: a rule's room lower than the next column's first)
    expect(b1 and b2 and b3 and math.abs(leftOf(b1) - leftOf(b2)) < 0.5 and math.abs(b1.uy - b3.uy) < 10
        and math.abs(leftOf(b3) - leftOf(b1)) > 20, "a list with text running down doesn't start a new column after its count")
    Folders.Get(emotes).flow = "horizontal"
    InfoBar.Refresh()
    expect(math.abs(b1.uy - b2.uy) < 0.5 and math.abs(b1.uy - b3.uy) > 10,
        "a list with text running across doesn't start a new row after its count")
    Folders.Get(emotes).flow, Folders.Get(emotes).perLine = "vertical", perWas
    for _, h in ipairs(F.heads) do
        ns.db.separators[h.id] = h.was
        ns.Separators.Refresh(h.id)
    end
    Hub.Changed()
    InfoBar.Refresh()
    InfoBar.Refresh()

    -- A drop between two members: a rule across the line there, not a ring on the nearest (Ikar 2026-11-16: "make the
    -- drag and drop in a folder highlight the line between two element, the current circle is unclear"): down a list,
    -- a horizontal one between their rows; across, an upright one between them
    run(function()
        local inE = { select(2, unpack(Hub.InFolder(emotes))) }
        local d1, d2 = Buttons.Get(inE[1].name), Buttons.Get(inE[2].name)
        local function midway(a, b, c)
            return (a - b) * (b - c) > 0
        end
        -- along the whole line, not only over a name (Ikar 2026-11-19: "the position hight only when you hover on top
        -- of a texte, not the whole line"): past its text, between two rows, by the list's edge
        local r = Folders.Panel(emotes).rect
        for _, pt in ipairs({ { r.x0 + r.w - 3, d1.uy }, { r.x0 + r.w - 3, (d1.uy + d2.uy) / 2 }, { r.x0 + 2, d1.uy } }) do
            local t = Folders.DropTarget(pt[1], pt[2], "KaLiHUD_Junk")
            expect(t and t.kind == "line" and t.w > 10, "a drop down a list off a name isn't marked: " .. pt[1] .. " " .. pt[2])
        end
        local drop = Folders.DropTarget(d1.ux, d1.uy + (d2.uy - d1.uy) * 0.6, "KaLiHUD_Junk")
        expect(drop and drop.kind == "line" and drop.index == 3 and drop.w > 10 and drop.h <= 2 and midway(d1.uy, drop.y, d2.uy),
            "a drop down a list isn't marked by a rule between the two")
        -- in columns, the one the pointer is in, by its far edge too, though the next column's member be nearer by its
        -- middle (Ikar 2026-11-20: "it switch to the right column too early, when the cursor is still on the left")
        -- (opening right, the next column on the right, as the Attributes'; the column's first named long, so the
        -- second's middle lies far from the column's far edge)
        local folder, long = Folders.Get(emotes), ns.Macros.Get(inE[1].name)
        local perWas, dirWas, nameWas = folder.perLine, folder.dir, long.name
        long.name = "Une émote au nom vraiment très long"
        ns.Macros.Refresh(inE[1].name)
        Hub.Changed()
        folder.perLine, folder.dir = 2, "upright"
        InfoBar.Refresh()
        local inLeft = Folders.DropTarget(d1.ux, d1.uy, "KaLiHUD_Junk")
        drop = inLeft and Folders.DropTarget(inLeft.x + inLeft.w / 2 + 2, d2.uy, "KaLiHUD_Junk")
        expect(d1:GetWidth() > d2:GetWidth() + 60 and drop and drop.kind == "line" and near(drop.x, inLeft.x)
            and drop.index <= 4,
            "a drop by a column's far edge goes into the next column: " .. tostring(drop and drop.index))
        long.name = nameWas
        ns.Macros.Refresh(inE[1].name)
        Hub.Changed()
        folder.perLine, folder.dir = perWas, dirWas
        InfoBar.Refresh()
        Folders.Get(emotes).flow = "horizontal"
        InfoBar.Refresh()
        drop = Folders.DropTarget(d1.ux + (d2.ux - d1.ux) * 0.6, d1.uy, "KaLiHUD_Junk")
        expect(drop and drop.kind == "line" and drop.index == 3 and drop.h > 10 and drop.w <= 2 and midway(d1.ux, drop.x, d2.ux),
            "a drop across a list isn't marked by a rule between the two")
        Folders.Get(emotes).flow = "vertical"
        InfoBar.Refresh()
    end)

    -- a folder's list on the info bar's carved floor, carved or not (Ikar 2026-11-16: "the menu background should
    -- match the darkened version of the bottom bar, even if she is not darkened")
    run(function()
        local floor, c = Folders.Panel(emotes).Floor, ns.Plate.CHANNEL
        local got = floor and floor.colorTexture
        expect(got and got[1] == c[1] and got[2] == c[2] and got[3] == c[3] and got[4] == c[4] and floor:IsShown(),
            "a folder's list isn't on the carved bar's darker floor")
    end)

    -- Folders in folders (Ikar 2026-11-16: "we will also need folder in folders"): « Session » and « Statistiques »
    -- put last in « Infos »; a folder never into itself nor one it holds, by a menu, a call or a drop; one opens beside
    -- the list it stands in, one at a time, shut with it, in a fight too; one shutting on leaving stays open while the
    -- pointer is on a list opened from it
    local outer, inner, other = Folders.ByRole("infos"), Folders.ByRole("session"), Folders.ByRole("statistics")
    -- (the three are locked, UI/Hub/Seeds.lua: the player's for this, their roles taken off until it ends)
    Folders.Get(outer).role, Folders.Get(inner).role, Folders.Get(other).role = nil, nil, nil
    local kept = {}
    for _, id in ipairs({ inner, other }) do
        local item = ns.db.items[id]
        kept[id] = item and { side = item.side, order = item.order, folder = item.folder, slot = item.slot } or false
    end
    expect(Hub.InsertIntoFolder(inner, outer) and Hub.InsertIntoFolder(other, outer), "a folder doesn't go into another")
    InfoBar.Refresh()
    local held = Hub.InFolder(outer)
    local op, ip, xp = Folders.Panel(outer), Folders.Panel(inner), Folders.Panel(other)
    expect(held[#held - 1].name == inner and held[#held].name == other and Buttons.Get(inner):GetParent() == op,
        "a folder put in another isn't last in its list")
    expect(not Hub.InsertIntoFolder(outer, inner) and not Hub.InsertIntoFolder(outer, outer)
        and Hub.Entry(outer).side ~= "folder", "a folder goes into itself or into one it holds")
    ns.HubMenus.OpenElement(Buttons.Get(outer), outer)
    local place = F.MenuItem(L.HUB_POSITION)
    expect(place and not F.MenuItem(string.format(L.SIDE_folder, Folders.Get(inner).name), place)
        and not F.MenuItem(string.format(L.SIDE_folder, Folders.Get(outer).name), place)
        and F.MenuItem(string.format(L.SIDE_folder, Folders.Get(emotes).name), place),
        "a folder's menu offers to put it in itself or in one it holds")
    click(outer, "LeftButton")
    click(inner, "LeftButton")
    expect(op:IsShown() and ip:IsShown() and Folders.IsOpen(inner) and ip.rect.x0 >= op.rect.x0 + op.rect.w,
        "a folder in an open one doesn't open beside its list")
    local junkTo = Folders.DropTarget(ip.rect.x0 + ip.rect.w / 2, ip.rect.y0 + ip.rect.h / 2, "KaLiHUD_Junk")
    expect(junkTo and junkTo.folder == inner and Folders.DropTarget(ip.rect.x0 + ip.rect.w / 2,
        ip.rect.y0 + ip.rect.h / 2, outer) == nil, "a drop on a list opened from another doesn't go in it, or a folder "
        .. "goes into one it holds")
    click(other, "LeftButton")
    expect(xp:IsShown() and not ip:IsShown() and not Folders.IsOpen(inner), "two folders open from one list")
    click(outer, "LeftButton")
    expect(not op:IsShown() and not xp:IsShown() and not Folders.IsOpen(other), "a folder shut leaves one in it open")
    -- one folder open at a time (Ikar 2026-11-16: "only one folder open at a time, opening another close the
    -- previous"): « Emote » open, opening « Infos » shuts it, then one in « Infos » keeps « Infos »; « Emote » again
    -- shuts both; our code opening one shuts the others too
    local ep = Folders.Panel(emotes)
    click(emotes, "LeftButton")
    click(outer, "LeftButton")
    expect(op:IsShown() and not ep:IsShown() and not Folders.IsOpen(emotes), "two folders open at once")
    click(inner, "LeftButton")
    expect(op:IsShown() and ip:IsShown() and Folders.IsOpen(outer), "a folder opening shuts the one it stands in")
    click(emotes, "LeftButton")
    expect(ep:IsShown() and not op:IsShown() and not ip:IsShown() and not Folders.IsOpen(outer)
        and not Folders.IsOpen(inner), "a folder opening leaves another, or one in it, open")
    Folders.SetOpen(outer, true)
    InfoBar.Refresh()
    expect(op:IsShown() and not ep:IsShown() and not Folders.IsOpen(emotes), "our code opening a folder leaves another open")
    Folders.SetOpen(outer, false)
    InfoBar.Refresh()
    -- A press anywhere else shuts what's open (Ikar 2026-11-17: "a click outside should close it, regardless of the
    -- rules"); one on a list keeps it and those it stands in, shutting those opened from it, as a menu's submenus; one
    -- on a folder's button leaves its own click to decide; one while a menu of the game's is open shuts that menu first.
    do
        click(outer, "LeftButton")
        click(inner, "LeftButton")
        op.mouseOver = true
        F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        F.RunTimers()
        op.mouseOver = nil
        expect(op:IsShown() and not ip:IsShown(), "a press on a list doesn't keep it, or keeps the one opened from it")
        click(inner, "LeftButton")
        ip.mouseOver = true
        F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        F.RunTimers()
        ip.mouseOver = nil
        expect(op:IsShown() and ip:IsShown(), "a press on a list opened from another shuts the one it stands in")
        local ib = Buttons.Get(inner)
        ib.mouseOver = true
        F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        F.RunTimers()
        ib.mouseOver = nil
        expect(ip:IsShown(), "a press on a folder's button shuts its list before its own click")
        F.menuOpen = true
        F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
        F.RunTimers()
        F.menuOpen = nil
        expect(op:IsShown() and ip:IsShown(), "a press shutting one of the game's menus shuts the open lists too")
        F.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
        F.RunTimers()
        expect(not op:IsShown() and not ip:IsShown() and not Folders.IsOpen(outer) and not Folders.IsOpen(inner),
            "a press outside doesn't shut the open lists")
    end
    local blockedBefore, snippetsBefore = #F.blocked, #F.snippetErrors
    F.EnterCombat()
    click(outer, "LeftButton")
    click(inner, "LeftButton")
    local openInFight = op:IsShown() and ip:IsShown()
    click(emotes, "LeftButton")
    local oneInFight = ep:IsShown() and not op:IsShown() and not ip:IsShown()
    click(emotes, "LeftButton")
    click(outer, "LeftButton")
    click(inner, "LeftButton")
    click(outer, "LeftButton")
    expect(openInFight and oneInFight and not ip:IsShown() and #F.blocked == blockedBefore
        and #F.snippetErrors == snippetsBefore, "a folder in a folder doesn't open, or isn't shut with it, or two "
        .. "folders open at once, in a fight")
    F.LeaveCombat()
    F.RunTimers()
    Folders.Get(outer).open = "leave"
    InfoBar.Refresh()
    click(outer, "LeftButton")
    click(inner, "LeftButton")
    ip.mouseOver = true
    F.AutoHide(0.05)
    F.AutoHide(1)
    expect(op:IsShown() and ip:IsShown(), "a folder shutting on leaving shuts with the pointer on a list opened from it")
    ip.mouseOver = nil
    F.AutoHide(0.05)
    F.AutoHide(0.5)
    F.RunTimers()
    expect(not op:IsShown() and not ip:IsShown(), "a folder shutting on leaving stays open once the pointer has left")
    Folders.Get(outer).open = nil
    Folders.Get(outer).role, Folders.Get(inner).role, Folders.Get(other).role = "infos", "session", "statistics"
    for id, item in pairs(kept) do
        ns.db.items[id] = item or nil
    end
    Hub.Changed()
    InfoBar.Refresh()
    expect(Hub.Entry(inner).side ~= "folder" and Hub.Entry(other).side ~= "folder", "the folders aren't put back")

    -- in a fight every folder shuts once left, one opening on a click too, one open as it starts once the pointer has
    -- been on it (Ikar 2026-11-16: "always auto close in combat. make it an option, on by default"); after it, one
    -- opening on a click stays open again; the option off, it stays open in a fight
    local eb = Buttons.Get(emotes)
    local function leaveIt(frame)
        frame.mouseOver = true
        F.AutoHide(0.05)
        frame.mouseOver = nil
        F.AutoHide(0.05)
        F.AutoHide(0.5)
        F.RunTimers()
    end
    expect(ns.db.options.folderCombatClose == true and Folders.Setting(emotes, "open") == "click" and not ep:IsShown(),
        "the folders' closing in a fight isn't on by default")
    click(emotes, "LeftButton")
    F.EnterCombat()
    leaveIt(ep)
    local shutOpenBefore = not ep:IsShown() and not Folders.IsOpen(emotes)
    click(emotes, "LeftButton")
    leaveIt(eb)
    expect(shutOpenBefore and not ep:IsShown(), "a folder opening on a click, open as a fight starts or opened in it, "
        .. "stays open once left in it")
    click(emotes, "LeftButton")
    eb.mouseOver = true
    F.AutoHide(0.05)
    F.LeaveCombat()
    F.RunTimers()
    leaveIt(eb)
    local keptAfter = ep:IsShown()
    click(emotes, "LeftButton")
    click(emotes, "LeftButton")
    leaveIt(ep)
    expect(keptAfter and ep:IsShown(), "a folder opening on a click, open as a fight ends or opened after it, shuts "
        .. "once left")
    click(emotes, "LeftButton")
    ns.db.options.folderCombatClose = false
    InfoBar.Refresh()
    F.EnterCombat()
    click(emotes, "LeftButton")
    leaveIt(eb)
    local stays = ep:IsShown()
    click(emotes, "LeftButton")
    F.LeaveCombat()
    F.RunTimers()
    ns.db.options.folderCombatClose = true
    InfoBar.Refresh()
    expect(stays, "the option off, a folder opening on a click shuts once left in a fight")
    click(emotes, "RightButton")
    run(F.MenuItem(L.SEPARATOR_ADD).choose)
    F.RunTimers()
    local after = Hub.InFolder(emotes)
    local added = after[#after]
    expect(added and added.isSeparator and #after == #inEmotes + 1, "« Ajouter un séparateur » doesn't put one last")
    -- dragged: into a folder only
    Hub.SetLocked(false)
    expect(Drag.Begin(added.name, Buttons.Get(added.name)), "a separator isn't dragged")
    F.cursorX, F.cursorY = 1300, 10
    expect(Drag.Target(1300, 10) == nil, "a separator would land on the bar")
    Drag.Finish()
    F.RunTimers()
    expect(Hub.Entry(added.name) and Hub.Entry(added.name).folder == emotes, "a separator dropped off a folder left it")
    Hub.SetLocked(true)
    -- its right-click deletes it, its one menu
    click(added.name, "RightButton")
    run(F.MenuItem(L.SEPARATOR_DELETE).choose)
    F.RunTimers()
    expect(not Hub.Entry(added.name) and not ns.db.separators[added.name] and #Hub.InFolder(emotes) == #inEmotes,
        "a separator deleted from its menu stays")
    -- not among the bar menu's elements
    F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
    expect(not F.MenuItem(L.SEPARATOR), "a separator is listed in the bar's menu")
    Folders.SetOpen(emotes, false)
    InfoBar.Refresh()

    -- The editor by its macro's button, as a folder's list opens (Ikar 2026-11-17: "I want the menu to open as a folder
    -- popup, near the button"): from « Emote »'s list, which runs down, beside it the way « Emote » opens, level with
    -- the macro's button; the list shut, where it would open from the folder's button; a new one on the bar by its
    -- button once the bar has laid it out, towards the screen's middle, flush with its side.
    run(function()
        local first = inEmotes[2].name
        local mb = Buttons.Get(first)
        local dir = Folders.Setting(emotes, "dir")
        local up, left = dir:sub(1, 2) == "up", dir:find("left$") ~= nil
        Folders.SetOpen(emotes, true)
        InfoBar.Refresh()
        Editor.Open(first)
        local ed = Editor.Frame()
        local w = ed:GetWidth()
        local point, _, _, x, y = ed:GetPoint()
        local r = ep.rect or {}
        local beside = ep:IsShown() and r.x0 and (left and near(x + w, r.x0 - 3) or not left and near(x, r.x0 + r.w + 3))
        local level = up and point == "BOTTOMLEFT" and near(y, mb.uy - mb:GetHeight() / 2)
            or not up and point == "TOPLEFT" and near(y, mb.uy + mb:GetHeight() / 2)
        expect(beside and level, "the editor of a macro in an open list isn't beside the list, level with its button: "
            .. tostring(point) .. " " .. tostring(x) .. " " .. tostring(y))
        Folders.SetOpen(emotes, false)
        InfoBar.Refresh()
        Editor.Open(first)
        point, _, _, x, y = ed:GetPoint()
        local fw, fh = eb:GetWidth(), eb:GetHeight()
        local where = (left and near(x + w, eb.ux + fw / 2) or not left and near(x, eb.ux - fw / 2))
            and (up and point == "BOTTOMLEFT" and near(y, eb.uy + fh / 2 + 3)
                or not up and point == "TOPLEFT" and near(y, eb.uy - fh / 2 - 3))
        expect(not ep:IsShown() and where, "the editor of a macro in a shut list isn't where that list would open: "
            .. tostring(point) .. " " .. tostring(x) .. " " .. tostring(y))
        ed:Hide()
        local loose = Macros.New()
        local early = Editor.Current()
        F.RunTimers()
        local lb = Buttons.Get(loose)
        point, _, _, x, y = ed:GetPoint()
        expect(early == nil and Editor.Current() == loose and Hub.Entry(loose).side == "right" and lb.ux
            and lb.ux > UIParent:GetWidth() / 2 and lb.uy < UIParent:GetHeight() / 2 and point == "BOTTOMLEFT"
            and near(x + w, lb.ux + lb:GetWidth() / 2) and near(y, lb.uy + lb:GetHeight() / 2 + 3),
            "a new macro's editor isn't above its button on the bar, flush with its side, once laid out: "
            .. tostring(point) .. " " .. tostring(x) .. " " .. tostring(y))
        ed:Hide()
        Macros.Delete(loose)
        F.RunTimers()
    end)

    -- A macro's icon from its menu, the folders' own library, at once; over the editor, beside it
    local macro = inEmotes[2].name
    click(macro, "RightButton")
    run(F.MenuItem(L.FOLDER_ICON).choose)
    local picker = _G.KaLiHUDIconPicker
    expect(Picker.Current() == macro and picker:GetFrameStrata() == "FULLSCREEN_DIALOG",
        "a macro's « Icône… » doesn't open the folders' library over everything")
    for _, c in ipairs(picker.cells or {}) do
        if c.atlas == "AnimCreate_Icon_Template" then
            F.RunScript(c, "OnClick", "LeftButton")
        end
    end
    F.RunTimers()
    expect(Macros.Get(macro).icon == "AnimCreate_Icon_Template" and Hub.Object(macro).atlas == "AnimCreate_Icon_Template"
        and not picker:IsShown(), "an icon picked from a macro's menu isn't worn at once, or the library stays open")
    Macros.SetIcon(macro, "common-icon-speak")
    Picker.Close()
    Editor.Open(macro)
    F.RunScript(KaLiHUDMacroEditor.IconButton, "OnClick", "LeftButton")
    expect(Picker.Current() == "KaLiHUDMacroEditor" and picker:IsShown(), "the editor's icon doesn't open the library")
    KaLiHUDMacroEditor:Hide()
    expect(not picker:IsShown(), "the library stays open with the editor shut")

    -- A note: runs nothing, its text in its tooltip, written in the same editor
    local note = Macros.New(emotes, nil, true)
    F.RunTimers()
    local ed = KaLiHUDMacroEditor
    expect(note and Editor.Current() == note and Macros.Get(note).note and Hub.Object(note).atlas == Macros.NOTE_ICON
        and Buttons.Get(note):GetAttribute("*type1") == nil, "a new note isn't open in the editor, or would run")
    ed.Text:SetText("Acheter des flèches\nRendre la quête de Gryan")
    F.RunScript(ed.Save, "OnClick", "LeftButton")
    F.RunTimers()
    F.RunScript(Buttons.Get(note), "OnEnter")
    local tip = table.concat(F.tooltip.lines, "\n")
    expect(tip:find("Rendre la quête de Gryan", 1, true) and Buttons.Get(note):GetAttribute("*type1") == nil,
        "a note's text isn't in its tooltip, or it runs")
    expect(tip:find(L.HINT_NOTE, 1, true) and L.HINT_NOTE:find("housing-hotkey-icon-leftclick", 1, true),
        "a note's tooltip doesn't show that the left button opens it")
    F.RunScript(Buttons.Get(note), "OnLeave")
    -- Its left click opens its editor and a second shuts it, as a folder's list (Ikar 2026-11-17: "make the note open
    -- with left click"); no « Exécute » in it ("Remove the execute from note"), its text where that row stands for a
    -- macro, the editor shorter by as much; a macro's opened after has it again.
    click(note, "LeftButton")
    expect(Editor.Current() == note and not ed.Runs:IsShown() and not ed.RunsLabel:IsShown()
        and select(3, ed.TextLabel:GetPoint()) == select(3, ed.Runs:GetPoint()),
        "a note's left click doesn't open its editor, or it shows « Exécute », or its text stays under that row's place")
    expect(not ed.LeftDesc:IsShown() and not ed.RightDesc.icon:IsShown() and not ed.RightCount:IsShown()
        and not ed.LeftBox:IsShown() and not ed.RightBox:IsShown() and not ed.RightHelp:IsShown(),
        "a note's editor has a macro's buttons' descriptions, or its right-click's count")
    click(note, "LeftButton")
    expect(Editor.Current() == nil and Buttons.Get(note):GetAttribute("*type1") == nil,
        "a note's second left click doesn't shut its editor, or the note runs")
    Editor.Open(macro)
    expect(Editor.Current() == macro and ed.Runs:IsShown() and ed.RunsLabel:IsShown()
        and select(3, ed.TextLabel:GetPoint()) < select(3, ed.Runs:GetPoint()) - ed.runsRow,
        "a macro's editor after a note's has no « Exécute », or its commands where that row is")
    ed:Hide()
    -- What was typed and not saved isn't dropped without a word (Ikar 2026-11-19: "User should never loose it
    -- settings ... a deliberate decision (confirmation popup, etc)"). Shut by anything but « Sauver » and « Annuler »,
    -- the editor asks; the macro opened again before the answer takes up what was typed, the question gone; the whole
    -- interface hidden isn't the editor shut; yes saves it; « Annuler » drops it, asking nothing
    Editor.Open(note)
    F.Type(ed.Text, "Brouillon")
    F.popup = nil
    ed:Hide()
    expect(F.popup ~= nil and F.popup.which == "KALIHUD_MACRO_UNSAVED" and Macros.Get(note).text ~= "Brouillon",
        "the editor shut with something typed and not saved doesn't ask about it")
    Editor.Open(note)
    expect(ed.Text:GetText() == "Brouillon" and F.popup == nil,
        "a macro opened again doesn't take up what was typed and not saved, or its question stays")
    F.RunScript(ed, "OnHide")
    expect(Editor.Current() == note and F.popup == nil, "the editor forgets its macro when the whole interface hides")
    ed:Hide()
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    expect(Macros.Get(note).text == "Brouillon", "yes to the editor's question doesn't save what was typed")
    Editor.Open(note)
    F.Type(ed.Text, "Autre")
    F.popup = nil
    F.RunScript(ed.Cancel, "OnClick", "LeftButton")
    Editor.Open(note)
    expect(F.popup == nil and Macros.Get(note).text == "Brouillon" and ed.Text:GetText() == "Brouillon",
        "« Annuler » asks about what it drops, saves it, or it comes back")
    ed:Hide()
    Macros.Delete(note)
    F.RunTimers()
    expect(errors() == before, "an error in the bar's other items: " .. tostring(next(KaLiHUDDevDB.errors or {})))
    Folders.Get(emotes).role = "emotes"
end

-- The mouse's buttons in the hints as the house editor's icons, never as words (Ikar 2026-11-17: "Replace all click
-- gauche and droit text by the new icon"), in every language: each hint, each text that names a button, the help's
-- lines. « Au clic », the « Clic » sound and the like name no button and stay words.
run(function()
    local NAMED = { STATUS_RIGHT_CLICK = true, SLOTS_SHUT_TIP = true, SLOTS_OPEN_TIP = true, DELETE_HIDES_TIP = true, MACRO_EMPTY = true,
        MACRO_RIGHT_LABEL = true, MACRO_RIGHT_HELP = true, NOTE_EMPTY = true, COMPARTMENT_CLICK = true }
    -- its words, the icons' markup (whose atlases' names say click) left out
    local function says(text)
        local lower = tostring(text):gsub("|A:[^|]*|a", ""):lower()
        return lower:find("clic", 1, true) or lower:find("klick", 1, true)
    end
    local icons = 0
    for _, locale in ipairs({ "frFR", "enUS", "deDE", "esES", "esMX" }) do
        local own = ns.StringsFor(locale)
        for key, french in pairs(ns.STRINGS.frFR) do
            if NAMED[key] or key:find("^HINT_") then
                local text = own[key]
                expect(type(text) == "string" and not says(text), locale .. " " .. key .. " names a mouse button in words: "
                    .. tostring(text))
                local shows = type(text) == "string" and text:find("|A:housing%-hotkey%-icon%-") ~= nil
                expect(shows == (french:find("|A:housing%-hotkey%-icon%-") ~= nil),
                    locale .. " " .. key .. " shows a mouse button where French doesn't, or none where it does")
                icons = icons + (shows and 1 or 0)
            end
        end
        for i, line in ipairs(own.HELP) do
            expect(not says(line), locale .. " help line " .. i .. " names a mouse button in words: " .. line)
        end
    end
    expect(icons >= 5 * 30, "too few hints show a mouse button: " .. icons)
    expect(L.HINT_CLOCK:find("|A:housing-hotkey-icon-leftclick:16:16|a", 1, true)
        and L.HINT_CLOCK:find("|A:housing-hotkey-icon-rightclick:16:16|a", 1, true),
        "the clock's hint doesn't show the house editor's left and right buttons at 16")
end)

-- ---------- What a folder's list does with its separators and values ----------
-- Ikar 2026-11-20, of the sketch of the attributes: "C'est très bien, par contre, il faudra transformer la limite max
-- qui est de 12 aujourd'hui. Ça doit être un slider avec la limite max à 25"; "whatever we do there, I want it to be
-- recreatable by the user": every part a setting of any folder or separator.
do
    local Folders, Separators, Buttons, Seeds = ns.Folders, ns.Separators, ns.HubButtons, ns.Seeds
    local function choose(item)
        if item and item.choose then
            run(item.choose)
        end
        F.RunTimers()
    end
    -- a folder of the player's, its list with text running down, three of ours in it, a separator between
    local id = Folders.Create("Essai")
    Hub.Insert(id, "left", 1)
    local f = Folders.Get(id)
    f.style, f.flow, f.dir = "text", "vertical", "upright"
    local members = { "KaLiHUD_Attr_STRENGTH", "KaLiHUD_Attr_EXPERTISE", "KaLiHUD_Attr_HEALTH" }
    local before = {}
    for i, name in ipairs(members) do
        before[i] = Hub.Saved(name) and { side = Hub.Saved(name).side, folder = Hub.Saved(name).folder,
            order = Hub.Saved(name).order }
        Hub.InsertIntoFolder(name, id)
    end
    local sep = Separators.Create(id, 3)
    Hub.Changed()
    Folders.SetOpen(id, true)
    InfoBar.Refresh()

    -- as many to a line: a slider, 1 to 25, in the folder's menu; set as it moves, the list laid out again; handed
    -- back to the menu's pool with nothing of ours left on it
    click(id, "RightButton")
    -- (a list running down: a line is a column, and so named, the review of 2026-11-20)
    local per = F.MenuItem(L.FOLDER_PER_COLUMN)
    expect(per and F.MenuItem(L.FOLDER_PER_LINE) == nil and F.MenuItem(L.FOLDER_PER_COLUMN, F.MenuItem(L.FOLDER_LIST) or { items = {} }),
        "a folder's list running down counts « par ligne », or its count isn't under « Liste »")
    local entry = per and per.items[1]
    local frame = entry and entry.kind == "template" and F.MenuFrame(entry)
    local slider = frame and frame.kaliSlider
    expect(slider and slider.minValue == 1 and slider.maxValue == 25 and slider:GetValue() == Folders.Setting(id, "perLine")
        and frame:GetWidth() > 100 and slider:IsShown() and slider:IsSliderEnabled(),
        "a folder's count to a line isn't a slider from 1 to 25 in its menu")
    if slider then
        slider:SetValue(25)
        F.RunTimers()
        expect(Folders.Get(id).perLine == 25 and ns.DB.PER_LINE[2] == 25, "the slider's 25 isn't the folder's count")
        slider:SetValue(1)
        F.RunTimers()
        expect(Folders.Get(id).perLine == 1, "the slider's 1 isn't the folder's count")
        F.MenuRelease(entry, frame)
        slider:SetValue(7)
        expect(Folders.Get(id).perLine == 1 and not slider:IsShown(), "a slider handed back to the menu still sets the folder")
        f.perLine = nil
    end
    -- a saved count up to 25 kept, past it put right
    expect(ns.DB.PER_LINE[1] == 1 and ns.DB.PER_LINE[2] == 25, "a folder's count isn't kept from 1 to 25")

    -- a separator's title, from its menu (blank: none); one action to undo; drawn over a rule in a list with text
    -- running down, as tall as a member, its title in gold
    click(sep, "RightButton")
    local nameItem = F.MenuItem(L.SEPARATOR_NAME)
    choose(nameItem)
    F.popupText = "  Ma section "
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    InfoBar.Refresh()
    local sb, cell = Buttons.Get(sep), Hub.IconSize() + 6
    expect(Separators.Name(sep) == "Ma section" and sb.Text:IsShown() and sb.Text:GetText() == "Ma section"
        and math.abs(sb:GetHeight() - cell) < 0.5 and Hub.Object(sep).label == "Ma section",
        "a separator named from its menu isn't a title over its rule: " .. tostring(Separators.Name(sep)))
    ns.History.Undo()
    F.RunTimers()
    expect(Separators.Name(sep) == nil and ns.db.separators[sep] == true, "a separator's title undone stays")
    ns.History.Redo()
    F.RunTimers()
    -- across, or in a list of icons alone, its rule, its title in its tooltip
    f.flow = "horizontal"
    InfoBar.Refresh()
    expect(not sb.Text:IsShown() and sb:GetWidth() < 12, "a title drawn in a list running across")
    F.RunScript(sb, "OnEnter")
    expect(F.tooltip.lines[1] == "Ma section", "a separator's tooltip doesn't name its title")
    F.RunScript(sb, "OnLeave")
    f.flow = "vertical"
    InfoBar.Refresh()

    -- a separator starting a column, whatever the count: what follows it in the next
    local strength, expertise, health = Buttons.Get(members[1]), Buttons.Get(members[2]), Buttons.Get(members[3])
    local function leftOf(b)
        return b.ux - b:GetWidth() / 2
    end
    expect(math.abs(leftOf(strength) - leftOf(health)) < 0.5, "setup: one column")
    click(sep, "RightButton")
    local column = F.MenuItem(L.SEPARATOR_COLUMN)
    expect(column and F.MenuItem(L.SEPARATOR_ROW) == nil, "a separator down a list has no « Commence une colonne »")
    choose(column)
    InfoBar.Refresh()
    expect(Separators.StartsLine(sep) and math.abs(leftOf(health) - leftOf(strength)) > 20
        and math.abs(health.uy - strength.uy) > 0.5 and leftOf(sb) > leftOf(strength) + 20,
        "a separator starting a column doesn't take what follows it to the next")
    f.flow = "horizontal"
    click(sep, "RightButton")
    expect(F.MenuItem(L.SEPARATOR_ROW) ~= nil, "a separator across a list has no « Commence une ligne »")
    InfoBar.Refresh()
    expect(math.abs(health.uy - strength.uy) > 10, "a separator starting a row doesn't take what follows it to the next")
    f.flow = "vertical"
    Separators.SetStartsLine(sep, false)
    InfoBar.Refresh()

    -- the folder's values aligned on its list's right, those that say nothing in grey, each a box of its « Affichage »
    click(id, "RightButton")
    local align, dim = F.MenuItem(L.FOLDER_ALIGN), F.MenuItem(L.FOLDER_DIM)
    local shows
    for _, e in ipairs((F.MenuItem(L.FOLDER_LIST) or { items = {} }).items) do
        shows = shows or (e.text == L.FOLDER_SHOW and F.MenuItem(L.FOLDER_ALIGN, e) and e)
    end
    expect(align and dim and align.kind == "checkbox" and dim.kind == "checkbox" and shows,
        "« Affichage » has no box for the values")
    choose(align)
    choose(dim)
    InfoBar.Refresh()
    local function rightOf(b)
        return b.ux + b:GetWidth() / 2
    end
    local name = ns.G("SPELL_STAT1_NAME", "STRENGTH")
    expect(f.align and f.dim and strength.Value and strength.Value:IsShown() and strength.Text:GetText() == name
        and math.abs(rightOf(strength) - rightOf(health)) < 0.5 and strength.Value:GetText():find("110", 1, true),
        "a folder's values aren't set apart on its list's right: " .. tostring(strength.Text:GetText()))
    -- drawn again in place during a fight (Folders.Refill), it keeps its column's width
    Folders.Refill(id, members[1])
    expect(math.abs(rightOf(strength) - rightOf(health)) < 0.5,
        "a value set apart, drawn again during a fight, leaves its list's right")
    local grey, value, lit = expertise.Text.textColor or {}, expertise.Value.textColor or {}, strength.Text.textColor or {}
    expect((grey[1] or 1) < 0.6 and math.abs((grey[1] or 0) - (grey[2] or 1)) < 0.01 and (value[1] or 1) < 0.6
        and (lit[1] or 0) > 0.8,
        "a value that says nothing isn't grey, or one that says something is: " .. tostring(F.Shows(expertise)))
    -- what says nothing, however written; what says something
    for _, v in ipairs({ "0", "0 %", "0,0 %", "0.0%", "0 (0)", "—", "|cffff20200|r", ns.G("NONE", "None") }) do
        expect(Buttons.IsEmpty(v), "« " .. v .. " » taken for a value")
    end
    for _, v in ipairs({ "10", "0 / 115", "Révéré 0 %", "5 %", "1 (0)" }) do
        expect(not Buttons.IsEmpty(v), "« " .. v .. " » taken for nothing")
    end
    local split1, split2 = Buttons.Split({ type = "data source", label = "Force", text = "Force 55" })
    local other1, other2 = Buttons.Split({ type = "data source", label = "Or", text = "12g" })
    expect(split1 == "Force" and split2 == "55" and other1 == "Or" and other2 == "12g"
        and Buttons.Split({ type = "launcher", label = "x", text = "y" }) == nil,
        "a data source's name and value aren't its label and the rest")
    -- aligned off: the text as it comes, its value with it
    choose(align)
    InfoBar.Refresh()
    expect(not strength.Value:IsShown() and strength.Text:GetText():find("110", 1, true), "values set apart, the box off")

    -- in the saved file: a separator's fields, the folder's boxes, a count to 25; what can't be goes
    local saved = ns.DB.Repaired({ options = {}, items = {
        KaLiHUD_Separator901 = { side = "folder", folder = id, order = 5 },
        KaLiHUD_Separator902 = { side = "folder", folder = id, order = 6 } },
        separators = { KaLiHUD_Separator901 = { name = "Titre", line = true, extra = 3 },
            KaLiHUD_Separator902 = { name = 7, line = "yes" } },
        folders = { [id] = { name = "Essai", perLine = 25, align = true, dim = 1 },
            KaLiHUD_Folder902 = { name = "Trop", perLine = 26 } } })
    local s1 = saved and saved.separators.KaLiHUD_Separator901
    expect(type(s1) == "table" and s1.name == "Titre" and s1.line == true and s1.extra == nil
        and saved.separators.KaLiHUD_Separator902 == true and saved.folders[id].perLine == 25
        and saved.folders[id].align == true and saved.folders[id].dim == nil
        and saved.folders.KaLiHUD_Folder902.perLine == nil,
        "a separator's or a folder's saved fields aren't put right")

    Folders.SetOpen(id, false)
    Folders.Delete(id)
    for i, name in ipairs(members) do
        if before[i] then
            Hub.PlaceAt(name, before[i].side, before[i].order, before[i].folder)
        end
    end
    Hub.Changed()
    InfoBar.Refresh()

    -- A game saved before: the attributes', the emotes' and the group's separators plain, the attributes nine to a
    -- column, no title heading a list, a title of its own in the group's. Locked (UI/Hub/Seeds.lua), each is made at
    -- the next login with its titles and lines as made now, the one heading the list at its top, what values it sets
    -- apart, with no mark of its own.
    local function seps(folder)
        local list = {}
        for _, e in ipairs(Hub.InFolder(folder)) do
            if e.isSeparator then
                list[#list + 1] = e.name
            end
        end
        return list
    end
    local function said(folder)
        local out = {}
        for _, sid in ipairs(seps(folder)) do
            out[#out + 1] = (Separators.Name(sid) or "-") .. (Separators.StartsLine(sid) and ">" or "")
        end
        return table.concat(out, ",")
    end
    local stats, emotes, group = Folders.ByRole("stats"), Folders.ByRole("emotes"), Folders.ByRole("group")
    local made = {}
    for _, folder in ipairs({ stats, emotes, group }) do
        made[folder] = said(folder)
        local list = seps(folder)
        for _, sid in ipairs(list) do
            Separators.Dress(sid, nil)
        end
        if folder ~= group then
            Separators.Drop(list[1])
        end
    end
    local sf = Folders.Get(stats)
    sf.perLine, sf.align, sf.dim = 9, nil, nil
    Separators.Dress(seps(group)[1], { name = "Le mien" })
    Hub.Changed()
    ns.Seeds.Run()
    F.RunTimers()
    local G = ns.G
    expect(said(stats) == made[stats] and said(stats):find("^" .. G("STAT_CATEGORY_GENERAL", "General") .. ",")
        and said(stats):find(G("STAT_CATEGORY_WEAPONS", "Weapons") .. ">", 1, true)
        and said(stats):find(G("STAT_CATEGORY_DEFENSE", "Defense") .. ">", 1, true)
        and Hub.InFolder(stats)[1].isSeparator and sf.perLine == Seeds.STATS_PER_LINE and sf.align and sf.dim,
        "an attributes' folder made before hasn't the sheet's titles, its columns, its values set apart: " .. said(stats)
        .. " / " .. made[stats])
    expect(said(emotes) == made[emotes] and said(emotes) == G("EMOTE", "Emote") .. ","
        .. G("VOICEMACRO_LABEL", "Voice Emote") .. ">", "an emotes' folder made before hasn't its titles: " .. said(emotes))
    expect(said(group) == made[group] and said(group) == "-," .. L.GROUP_MARKERS .. ">",
        "the group's markers aren't under their title in a column of their own, or a title an earlier build left stays: "
        .. said(group))
end

-- ---------- Undo and redo, the locked folders ----------
-- Ikar 2026-11-16: "when deleting a folder, prompt the user if he is sure, as the content will be deleted, not
-- displaced"; "add an undo/redo stack, up to 10 actions. movement, deletion, creation"; 2026-11-23, the folders KaLi
-- HUD makes locked in place of their resets: "No edit, no reset, user can delete them whole (and bring back) and if
-- they drag and drop, it create a copy".
do
    local Folders, Macros, History = ns.Folders, ns.Macros, ns.History
    local function copy(v)
        if type(v) ~= "table" then
            return v
        end
        local t = {}
        for k, x in pairs(v) do
            t[k] = copy(x)
        end
        return t
    end
    local function same(a, b)
        if type(a) ~= "table" or type(b) ~= "table" then
            return a == b
        end
        for k, x in pairs(a) do
            if not same(x, b[k]) then
                return false
            end
        end
        for k in pairs(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    end
    -- the hub's saved data, whether a folder is open left out
    local function state()
        local s = copy({ items = ns.db.items, folders = ns.db.folders, macros = ns.db.macros,
            separators = ns.db.separators, options = ns.db.options })
        for _, f in pairs(s.folders) do
            f.opened = nil
        end
        return s
    end
    local function choose(item)
        if item and item:IsEnabled() then
            run(item.choose)
        end
        F.RunTimers()
        return item ~= nil and item:IsEnabled()
    end
    local function bar(text)
        F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
        return F.MenuItem(text)
    end
    local function undoText(kind, label)
        return string.format(L.UNDO_WHAT, string.format(L["ACT_" .. kind], label))
    end
    local function redoText(kind, label)
        return string.format(L.REDO_WHAT, string.format(L["ACT_" .. kind], label))
    end
    local function hubMenu(name)
        click(name, "RightButton")
        return F.lastMenu
    end
    local function names(id)
        local list = {}
        for _, e in ipairs(Hub.InFolder(id)) do
            list[#list + 1] = e.isSeparator and "|" or e.name
        end
        return table.concat(list, " ")
    end
    local blocked = #F.blocked
    History.Clear()

    -- Nothing done: both greyed.
    local u, r = bar(L.UNDO), F.MenuItem(L.REDO)
    expect(u and r and not u:IsEnabled() and not r:IsEnabled(), "with nothing done, « Annuler » and « Rétablir » aren't greyed")

    -- A move from an element's menu, undone and done again from the bar's menu: as before, then as after.
    local s0 = state()
    local bags = Hub.Label("KaLiHUD_Bags")
    choose(F.MenuItem(L.GO_RIGHT, hubMenu("KaLiHUD_Bags")))
    local s1 = state()
    expect(not same(s0, s1) and History.Count() == 1, "« Aller à droite » isn't one action to undo")
    expect(choose(bar(undoText("move", bags))) and same(state(), s0), "an undone move doesn't put the bar back as it was")
    expect(choose(bar(redoText("move", bags))) and same(state(), s1), "a move done again isn't as it was done")
    choose(bar(undoText("move", bags)))

    -- Making: a folder from the bar's menu, a separator and a macro from its own; each undone, the last first.
    choose(bar(L.FOLDER_CREATE))
    F.popupText = "Essai d'annulation"
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    local test = Folders.List()[#Folders.List()]
    local named = test and Folders.Get(test).name == "Essai d'annulation"
    expect(named and History.Count() == 1, "a folder made from the bar's menu isn't one action to undo")
    click(test, "RightButton")
    choose(F.MenuItem(L.SEPARATOR_ADD))
    click(test, "RightButton")
    choose(F.MenuItem(L.MACRO_CREATE))
    local macro = Hub.InFolder(test)[2] and Hub.InFolder(test)[2].name
    local s2 = state()
    expect(macro and Macros.Get(macro) and ns.MacroEditor.Current() == macro and History.Count() == 3,
        "a separator and a macro made in a folder aren't an action each")
    choose(bar(undoText("create", L.MACRO_NEW)))
    expect(not Macros.Get(macro) and ns.MacroEditor.Current() == nil and Buttons.Get(macro):GetAttribute("*type1") == nil,
        "an undone macro stays, its editor open, or its button runs")
    choose(bar(undoText("create", L.SEPARATOR)))
    choose(bar(undoText("create", "Essai d'annulation")))
    expect(same(state(), s0) and Folders.Get(test) == nil and not Buttons.Get(test):IsShown(),
        "undoing the three doesn't leave the bar as before them")
    for _, label in ipairs({ "Essai d'annulation", L.SEPARATOR, L.MACRO_NEW }) do
        choose(bar(redoText("create", label)))
    end
    expect(same(state(), s2) and Folders.Get(test) and Buttons.Get(test):IsShown(),
        "done again, the folder, its separator and its macro aren't back as made")

    -- Deleting one holding a folder (a macro in it), a separator and one of ours, from its menu, asked first: all gone
    -- (ours hidden); undone, all back as it was, the macro running.
    local inner = Folders.Create("Dedans")
    Hub.InsertIntoFolder(inner, test)
    Hub.InsertIntoFolder(macro, inner)
    Hub.InsertIntoFolder("KaLiHUD_Bags", test)
    Macros.Update(macro, { name = L.MACRO_NEW, text = "/salut" })
    F.RunTimers()
    local s3 = state()
    click(test, "RightButton")
    choose(F.MenuItem(L.FOLDER_DELETE))
    expect(F.popup and StaticPopupDialogs[F.popup.which].text == L.FOLDER_DELETE_ASK, "deleting a folder doesn't ask first")
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    local seps = 0
    for _ in pairs(ns.db.separators) do
        seps = seps + 1
    end
    expect(not Folders.Get(test) and not Folders.Get(inner) and not Macros.Get(macro) and seps == ns.Count(s3.separators) - 1
        and Hub.Entry("KaLiHUD_Bags").side == "hidden", "a folder's contents aren't deleted with it, however deep")
    choose(bar(undoText("delete", "Essai d'annulation")))
    expect(same(state(), s3) and Buttons.Get(test):IsShown() and Buttons.Get(macro):GetAttribute("macrotext") == "/salut",
        "an undone deletion isn't back as it was")
    -- an empty one: the shorter question
    local empty = Folders.Create("Vide")
    Hub.Insert(empty, "right", 1)
    F.RunTimers()
    Folders.AskDelete(empty)
    expect(F.popup and StaticPopupDialogs[F.popup.which].text == L.FOLDER_DELETE_EMPTY_ASK,
        "deleting an empty folder asks of contents it hasn't")
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()

    -- Ten kept, the oldest gone; a new action after an undo, nothing to do again.
    Hub.Reset("KaLiHUD_Bags")
    F.RunTimers()
    History.Clear()
    for i = 1, 12 do
        History.Do("move", "KaLiHUD_Bags", Hub.Step, "KaLiHUD_Bags", i % 2 == 0 and -1 or 1)
    end
    local kept = History.Count()
    History.Undo()
    local back, again = History.Count()
    History.Do("move", "KaLiHUD_Bags", Hub.Step, "KaLiHUD_Bags", 1)
    local _, after = History.Count()
    expect(kept == History.MOST and back == History.MOST - 1 and again == 1 and after == 0,
        "the stack isn't ten deep, or what was undone can be done again after a new action")
    -- During a fight, neither: greyed, and refused by the key too.
    local s4 = state()
    F.combat = true
    local greyed = not bar(undoText("move", bags)):IsEnabled()
    KaLiHUD_Binding("undo")
    F.combat = false
    expect(greyed and same(state(), s4), "an undo isn't greyed, or is done, during a fight")
    KaLiHUD_Binding("undo")
    F.RunTimers()
    expect(not same(state(), s4), "the key bound to undo doesn't undo")
    KaLiHUD_Binding("redo")
    F.RunTimers()
    expect(same(state(), s4), "the key bound to redo doesn't redo")

    -- A locked folder (UI/Hub/Seeds.lua; Ikar 2026-11-23: "No edit, no reset, user can delete them whole (and bring
    -- back) and if they drag and drop, it create a copy"; "The type shoudl be also "locked folder""): its menu says so
    -- and takes it off the HUD, nothing else but how it opens (scenarios/persist.lua); nothing goes into it; its type
    -- says it's locked.
    local stats = Folders.ByRole("stats")
    local menu = hubMenu(stats)
    local why = F.MenuItem(L.FOLDER_LOCKED_DRAG, menu)
    expect(why and not why:IsEnabled() and F.MenuItem(L.ITEM_REMOVE, menu) and not F.MenuItem(L.FOLDER_RENAME, menu)
        and not F.MenuItem(L.FOLDER_ICON, menu) and not F.MenuItem(L.FOLDER_LIST, menu)
        and not F.MenuItem(L.MACRO_CREATE, menu) and not F.MenuItem(L.SEPARATOR_ADD, menu),
        "a locked folder's menu changes it, or doesn't say why it can't")
    expect(ns.HubMenus.TypeOf(stats) == L.TYPE_LOCKED_FOLDER and ns.HubMenus.TypeOf(Folders.Default()) == L.TYPE_FOLDER,
        "a locked folder's type isn't « Dossier verrouillé », or « Add-ons »'s is")
    local mine = Macros.Create({ name = "À moi", text = "/dance" })
    Hub.Insert(mine, "right", 1)
    F.RunTimers()
    local position = F.MenuItem(L.HUB_POSITION, hubMenu(mine))
    expect(not Hub.InsertIntoFolder(mine, stats) and Hub.Entry(mine).side == "right" and position
        and not F.MenuItem(string.format(L.SIDE_folder, Folders.Get(stats).name), position),
        "something goes into a locked folder")
    -- what it holds: its menu says why nothing of it changes, nothing moves it
    local stat
    for _, e in ipairs(Hub.InFolder(stats)) do
        stat = stat or (Hub.IsOurs(e.name) and e.name) or nil
    end
    menu = hubMenu(stat)
    expect(F.MenuItem(L.FOLDER_LOCKED_DRAG, menu) and not F.MenuItem(L.GO_LEFT, menu)
        and not F.MenuItem(L.HUB_POSITION, menu) and not F.MenuItem(L.ITEM_REMOVE, menu)
        and not F.MenuItem(ns.G("RESET", "Réinitialiser"), menu),
        "what a locked folder holds moves, goes, or is reset from its menu")
    -- dragged out onto the bar, it stays in its folder: a copy lands, the item's own object, its value with it; the drop
    -- one action, undone; the copy deleted from its own menu, its item kept
    local before, wasLocked = names(stats), Hub.IsLocked()
    Hub.SetLocked(false)
    -- (nor by a drop on its button: Ikar 2026-11-23, "a locked folder btw obviously do not accept drang and drop
    -- inside of it")
    local fb = Buttons.Get(stats)
    Drag.Begin(mine)
    local onIt = fb and fb.ux and Drag.Target(fb.ux, fb.uy)
    Drag.Cancel()
    F.RunTimers()
    expect(fb and fb.ux and not (onIt and onIt.folder == stats) and Hub.Entry(mine).side == "right",
        "a drop on a locked folder's button goes into it")
    F.cursorX, F.cursorY = UIParent:GetWidth() * 0.3, InfoBar.Top() / 2
    Drag.Begin(stat)
    Drag.Finish()
    F.RunTimers()
    local copy
    for id, c in pairs(ns.db.copies) do
        if c.of == stat then
            copy = id
        end
    end
    local e = copy and Hub.Entry(copy)
    expect(names(stats) == before and e and Hub.BAR[e.side] and e.obj == Hub.Object(stat)
        and ns.HubMenus.TypeOf(copy) == L.TYPE_COPY,
        "dragged out of a locked folder, an item leaves it, or no copy of it lands on the bar: " .. names(stats))
    Hub.Set(stat, "text", "Essai 42")
    F.RunTimers()
    expect(copy and Buttons.Get(copy) and F.Shows(Buttons.Get(copy)):find("Essai 42", 1, true),
        "a copy doesn't show its item's value")
    choose(bar(undoText("copy", Hub.Label(stat))))
    expect(copy and not ns.db.copies[copy] and names(stats) == before, "an undone copy stays")
    choose(bar(redoText("copy", Hub.Label(stat))))
    choose(F.MenuItem(L.COPY_DELETE, hubMenu(copy)))
    expect(copy and not ns.db.copies[copy] and not Hub.Entry(copy) and names(stats) == before,
        "a copy isn't deleted from its menu, or takes its item with it")
    -- a macro it holds: copied from its menu, nothing else; dragged out, the copy is the player's own
    local group = Folders.ByRole("group")
    local ready
    for _, m in ipairs(Hub.InFolder(group)) do
        if m.isMacro and Macros.Get(m.name).seed == "group:readycheck" then
            ready = m.name
        end
    end
    menu = hubMenu(ready)
    expect(F.MenuItem(ns.G("CALENDAR_COPY_EVENT", "Copier"), menu) and not F.MenuItem(L.MACRO_EDIT, menu)
        and not F.MenuItem(L.MACRO_DELETE, menu), "a macro in a locked folder is edited or deleted from its menu")
    local count = ns.Count(ns.db.macros)
    Drag.Begin(ready)
    Drag.Finish()
    F.RunTimers()
    local theirs
    for id, m in pairs(ns.db.macros) do
        if id ~= ready and m.text == Macros.Get(ready).text then
            theirs = id
        end
    end
    expect(ns.Count(ns.db.macros) == count + 1 and theirs and Macros.Get(theirs).seed == nil
        and Hub.Entry(ready).folder == group, "a macro dragged out of a locked folder isn't copied as the player's")
    if theirs then
        Macros.Delete(theirs)
    end
    Hub.SetLocked(wasLocked)
    -- taken off the HUD whole from its menu, it comes back whole from the bar's, its box under « Dossiers »
    choose(F.MenuItem(L.ITEM_REMOVE, hubMenu(stats)))
    local gone = Hub.Entry(stats).side == "hidden"
    choose(bar(Folders.Get(stats).name))
    expect(gone and Hub.Entry(stats).side == "left" and names(stats) == before,
        "a locked folder taken off the HUD doesn't come back whole from the bar's menu")
    -- put in a folder of the player's, it isn't deleted with that folder (nothing would make it again before the next
    -- login): taken off the HUD whole, as from its menu
    local was = {}
    for k, v in pairs(ns.db.items[stats] or {}) do
        was[k] = v
    end
    local host = Folders.Create("Hôte")
    Hub.InsertIntoFolder(stats, host)
    F.RunTimers()
    local held = Hub.Entry(stats).folder == host
    Folders.Delete(host)
    F.RunTimers()
    expect(held and Folders.Get(stats) ~= nil and Hub.Entry(stats).side == "hidden" and names(stats) == before,
        "a locked folder in a folder of the player's is deleted with it")
    ns.db.items[stats] = was
    Hub.Changed()
    F.RunTimers()

    -- One of ours reset from its hub menu: its own options at their defaults, where it goes by default; the place's
    -- reset left to the others.
    ns.db.options.bagsFree = true
    Hub.Insert("KaLiHUD_Bags", "right", 1)
    F.RunTimers()
    menu = hubMenu("KaLiHUD_Bags")
    position = F.MenuItem(L.HUB_POSITION, menu)
    expect(position and F.MenuItem(ns.G("RESET", "Réinitialiser"), position) == nil,
        "one of ours has the place's reset as well as its own")
    F.popup = nil
    choose(F.MenuItem(ns.G("RESET", "Réinitialiser"), menu))
    expect(F.popup ~= nil and rawget(ns.db.options, "bagsFree") == true, "an item's reset doesn't ask first")
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    expect(rawget(ns.db.options, "bagsFree") == nil and ns.db.items.KaLiHUD_Bags == nil
        and Hub.Entry("KaLiHUD_Bags").side == "left", "an item's reset doesn't give it back its options and its place")
    Folders.Delete(test)
    Macros.Delete(mine)
    Hub.Reset("KaLiHUD_Bags")
    F.RunTimers()
    History.Clear()
    -- Made from the bar's menu where that menu was opened, as a drop there would put it, not at the bar's right end
    -- (Ikar 2026-11-20: "when adding a note, a macro or a folder, it shoudl appear where the user put it., not on the
    -- right"): a note asked for over the bar's left part; undone, gone
    do
        local ux, uy, scale = UIParent:GetWidth() * 0.3, InfoBar.Top() / 2, UIParent:GetEffectiveScale()
        local want = ns.HubDrag.Target(ux, uy)
        local side, pos, index = want and want.side, want and want.pos, want and want.index
        local before = {}
        for _, e in ipairs(Hub.Entries()) do
            before[e.name] = true
        end
        F.cursorX, F.cursorY = ux * scale, uy * scale
        choose(bar(L.NOTE_CREATE))
        F.cursorX, F.cursorY = nil, nil
        local made
        for _, e in ipairs(Hub.Entries()) do
            if not before[e.name] then
                made = e
            end
        end
        local at
        for i, e in ipairs(made and side and side ~= "free" and Hub.Side(side) or {}) do
            if e.name == made.name then
                at = i
            end
        end
        expect(made and side and side ~= "right" and made.side == side
            and (side == "free" and math.abs((made.pos or 0) - pos) < 0.001 or at == index),
            "a note made from the bar's menu isn't where that menu was opened: " .. tostring(made and made.side)
            .. " for " .. tostring(side))
        ns.MacroEditor.Close(made and made.name)
        choose(bar(undoText("create", L.NOTE_NEW)))
        History.Clear()
    end
    -- the bar's menu without the macros' list, the folders' kept (Ikar 2026-11-20: "The whole emote category shoudl
    -- go, keep only the folder")
    expect(bar(L.CAT_macros) == nil and F.MenuItem(L.CAT_folders) ~= nil,
        "the bar's menu lists the macros, or not the folders")
    -- what it shows first, its main use; undo and redo last (the review of 2026-11-20)
    do
        local items = F.lastMenu.items
        local function at(text)
            for i, e in ipairs(items) do
                if e.text == text then
                    return i
                end
            end
        end
        local last = items[#items] and items[#items].text or ""
        expect(at(L.CAT_folders) and at(L.FOLDER_CREATE) and at(L.CAT_folders) < at(L.FOLDER_CREATE)
            and last:find(L.REDO, 1, true) == 1, "the bar's menu doesn't list what it shows first, and undo and redo last")
        -- the options and a bug report, above undo and redo, as KaLi Quest's gear's menu (Ikar 2026-11-24)
        local options, report = at(ns.G("OPTIONS", "Options")), at(L.REPORT_TITLE)
        expect(options and report and at(L.FOLDER_CREATE) < options and options + 1 == report and report < #items - 1,
            "the bar's menu has no Options then Report a bug, above undo and redo")
        if report then
            choose(items[report])
            local frame = ns.Report.Frame()
            expect(frame and frame:IsShown(), "the bar's menu's Report a bug doesn't open the report")
            if frame then
                frame:Hide()
            end
        end
    end
    expect(#F.blocked == blocked, "the game blocked the hub: " .. table.concat(F.blocked, ", ", blocked + 1))
end

-- ---------- Borders & backgrounds ----------
do
    -- The plate's edge takes the border all along its computed outline, grown by its shadow: a quad a segment, its
    -- corners moved.
    expect(Plate.last.band and Plate.last.band > 20, "the plate's edge isn't drawn along its outline: " .. tostring(Plate.last.band))
    -- Grain over the border's metal, a band over the band, as Ikar approved it: internal, no option; none at 0.
    expect(Plate.last.grain == Plate.last.band, "the border's metal has no grain: " .. tostring(Plate.last.grain))
    local grain = ns.Border.Grain(ns.Border.Profile())
    expect(ns.Border.GRAIN.strength == 35 and ns.Border.GRAIN.length == 100 and grain and near(grain.tint[4], 0.35)
        and ns.DB.DEFAULTS.borderGrain == nil and ns.DB.DEFAULTS.borderGrainSize == nil,
        "the grain isn't Ikar's, internal: " .. tostring(grain and grain.tint[4]))
    ns.Border.GRAIN.strength = 0
    run(ns.ApplyAll)
    expect(Plate.last.grain == 0, "the grain shows at none: " .. tostring(Plate.last.grain))
    ns.Border.GRAIN.strength = 35
    run(ns.ApplyAll)
    expect(near(ns.Border.Profile().out, ns.LOOK.out * ns.db.options.borderSize / 100) and ns.LOOK.out > 0,
        "the plate's edge doesn't stand out by its shadow")
    -- Each stretch of border takes the profile lit as its outer side faces: the top's isn't the foot's nor a wall's.
    do
        local coords = ns.Border.Profile().coords
        local up, down, left = coords(10, 0, 0, 1), coords(10, 0, 0, -1), coords(10, 0, -1, 0)
        expect(up ~= down and up ~= left and up >= 0 and down < 1 and select(3, coords(10, 0, 0, 1)) > up,
            "the border's profile doesn't follow the way its edge faces: " .. up .. " " .. down .. " " .. left)
    end
    -- The background: its colour alone when smooth or at no depth, the material's grain imprinted in it otherwise.
    ns.db.options.bgStyle = "smooth"
    run(ns.ApplyAll)
    local plain = Plate.textures
    ns.db.options.bgStyle = "leather"
    run(ns.ApplyAll)
    expect(Plate.textures > plain + 5, "the background's material isn't imprinted: " .. Plate.textures .. " for " .. plain)
    local fill, lum = ns.Border.Fill(), ns.MATERIALS.leather.lum
    local red = ns.Border.RGB(ns.db.options.bgColor)
    expect(fill.material and near(fill.foot[1] + fill.matFoot[1] * lum, red * ns.Border.FOOT)
        and near(fill.top[1] + fill.matTop[1] * lum, red * ns.Border.TOP),
        "colour and material together don't keep the colour's light")
    F.missingAtlases[ns.MATERIALS.masonry.atlas] = true
    ns.db.options.bgStyle = "masonry"
    run(ns.ApplyAll)
    expect(Plate.textures == plain, "a material the game lacks isn't left out")
    F.missingAtlases[ns.MATERIALS.masonry.atlas] = nil
    ns.db.options.bgStyle = "leather"
    ns.db.options.bgIntensity = 0
    run(ns.ApplyAll)
    expect(Plate.textures == plain, "at no depth the material still shows")
    ns.db.options.bgIntensity = nil
    -- The info bar and the map's foot carved in.
    ns.db.options.footGroove = false
    run(ns.ApplyAll)
    local uncarved = Plate.textures
    ns.db.options.footGroove = nil
    run(ns.ApplyAll)
    expect(Plate.textures >= uncarved + 2, "the info bar and the map's foot aren't carved into the plate")
    -- The minimap pockets' free places marked as small round recesses, none under an item, only while unlocked.
    ns.db.options.pocketMarks = false
    run(ns.ApplyAll)
    local unmarked = Plate.textures
    ns.db.options.pocketMarks = nil
    run(ns.ApplyAll)
    expect(Plate.textures == unmarked, "the pockets' places are marked while the slots are locked")
    Hub.SetLocked(false)
    run(ns.ApplyAll)
    local pocketSpots, _, pocketTaken = Hub.Pockets(Plate.last.dome, Plate.last.T)
    local marks, held = 0, 0
    for _, side in ipairs({ "pocketLeft", "pocketRight" }) do
        for i = 1, #pocketSpots[side] do
            if pocketTaken[side][i] then
                held = held + 1
            else
                marks = marks + 1
            end
        end
    end
    expect(held > 0 and marks > 0 and Plate.textures == unmarked + marks,
        "the pockets' free places aren't the ones marked: " .. (Plate.textures - unmarked) .. " for " .. marks)
    Hub.SetLocked(true)
    run(ns.ApplyAll)
    -- Our border round the map: the ring whole, over the plate's edge.
    ns.db.options.minimapRing = "kali"
    run(ns.ApplyAll)
    local ringDome, prof = Plate.last.dome, ns.Border.Profile()
    expect(ns.Minimap.ringDrawn == #ns.Geometry.Band(ns.Geometry.Circle(ringDome.cx, ringDome.cy, ringDome.mapR - prof.out), prof.e),
        "the map's ring isn't drawn whole: " .. tostring(ns.Minimap.ringDrawn))
    ns.db.options.minimapRing = nil
    run(ns.ApplyAll)
    ns.db.options.cornerStyle = "bevel"
    run(ns.ApplyAll)
    local cuts = 0
    for _, p in ipairs(ns.Geometry.Pieces(Plate.last.segs, Plate.last.dome, 0, Plate.Corners(ns.db.options))) do
        cuts = cuts + ((p[1] == "bevel" or p[1] == "slope") and 1 or 0)
    end
    expect(cuts > 0 and Plate.last.band > 20, "bevelled corners aren't cut: " .. cuts)
    ns.db.options.cornerStyle = nil
    run(ns.ApplyAll)
    -- One look for our frames: the thin border as a band round them, the plate's corners, its metal from the frame's edge,
    -- its shadow outside, over the background; the status bars' ground is FlareUI's dark one.
    local deco = bars[-1].Holder.KaLiBorder
    local panelDeco = ns.Folders.Panel(ns.Folders.Default()).KaLiBorder
    expect(deco and #deco.pool > 0 and deco.pool[1]:IsShown() and panelDeco and panelDeco.Bg:IsShown() and not deco.Bg:IsShown()
        and bars[-1].Holder.Ground:IsShown() and ns.Border.Count() >= 2, "our frames have no border and background")
    expect(near(deco.edge, ns.LOOK.thin.edge * ns.db.options.borderSize / 100) and ns.LOOK.thin.edge < ns.LOOK.edge,
        "the status bars don't wear the thin border")
    -- Its metal darker than the plate's, as bright as FlareUI's XP bar border (Ikar 2026-11-15: "too bright").
    do
        local r = ns.Border.Color()
        local tint = deco.pool[1].vertexColor
        expect(ns.Border.THIN_SHADE < 1 and tint and near(tint[1], r * ns.Border.THIN_SHADE),
            "the status bars' border isn't darker than the plate's: " .. tostring(tint and tint[1]))
    end
    -- The plate hugs the damage meter and the chat (moved down earlier), its edge their border: no margin but the border's
    -- metal, their own skins see-through; without the plate they show again.
    local meterSlot
    for _, s in ipairs(Plate.last.slots) do
        meterSlot = s.key == "DamageMeter" and s or meterSlot
    end
    expect(meterSlot and near(meterSlot.margin, ns.Border.Hug()) and near(meterSlot.x, taken("DamageMeter").x),
        "the plate doesn't hug the damage meter")
    expect(DamageMeterSessionWindow1.FlareUI_DMSkin.Center.alpha == 0 and ChatFrame1.FlareUI_Skin.TopEdge.alpha == 0
        and ChatFrame1.FlareUI_Skin.alpha ~= 0, "the windows' own frames show under our border, or their tabs went with them")
    ns.db.options.plate = false
    run(ns.ApplyAll)
    expect(DamageMeterSessionWindow1.FlareUI_DMSkin.Center.alpha ~= 0 and ChatFrame1.FlareUI_Skin.TopEdge.alpha ~= 0,
        "without the plate, the windows' own frames don't come back")
    -- the info bar's own strip still drawn, the border along its top, nothing higher (Ikar 2026-11-20: "when disabling
    -- the plaque, the info bar, if still enabled, shoudl stil lshow it background as before"); none with the bar off too
    do
        local alone = Plate.drawn
        local top = alone and ns.Geometry.Top(alone.segs) or 0
        expect(alone and alone.alone and Plate.textures > 0 and (alone.band or 0) > 0
            and near(top, ns.InfoBar.Top() + ns.Border.Hug()),
            "the plate off, the info bar has no background of its own, or it reaches past the bar: " .. tostring(top))
        ns.db.options.infoBar = false
        run(ns.ApplyAll)
        expect(Plate.drawn == nil and Plate.textures == 0, "the plate and the info bar off, a strip is still drawn")
        ns.db.options.infoBar = nil
    end
    ns.db.options.plate = nil
    run(ns.ApplyAll)
    local leftmost = math.huge
    for _, t in ipairs(deco.pool) do
        if t:IsShown() then
            leftmost = math.min(leftmost, select(4, t:GetPoint()))
        end
    end
    expect(deco.out > 0 and near(leftmost, -deco.out), "the frame's border doesn't stand out by its shadow: " .. tostring(leftmost))
    ns.db.options.borderSize = 50
    ns.ApplyAll()
    expect(near(deco.edge, ns.LOOK.thin.edge / 2) and near(ns.Border.Profile().e, ns.LOOK.edge / 2), "the border's size: " .. tostring(deco.edge))
    ns.db.options.borderSize = nil
    ns.ApplyAll()
    -- Set closer than its metal, the plate's edge runs flush with the bars and the status bars' border, never over them.
    ns.db.options.marginStatus, ns.db.options.marginBars, ns.db.options.marginBags = 0, 0, 0
    ns.ApplyAll()
    do
        local flush, n = true, 0
        for _, s in ipairs(Plate.last.slots) do
            if s.kind == "status" or s.kind == "bar" then
                n = n + 1
                flush = flush and near(s.margin, ns.Border.Hug())
            end
        end
        expect(n > 2 and flush, "the plate's edge runs over a bar or a status bar set with no margin")
    end
    ns.db.options.marginStatus, ns.db.options.marginBars, ns.db.options.marginBags = nil, nil, nil
    ns.ApplyAll()
    -- The colour picker sets the background's colour, cancelled it puts it back.
    ns.Border.PickColor("bgColor")
    F.PickColor(0.2, 0.4, 0.6)
    expect(ns.db.options.bgColor == "336699", "the colour picked isn't the background's: " .. tostring(ns.db.options.bgColor))
    ColorPickerFrame.info.cancelFunc()
    expect(rawget(ns.db.options, "bgColor") == nil, "cancelling the colour picker didn't put the colour back")
    -- The info bar's icons and text at their sizes: at size 14, icons 20.
    ns.db.options.infoSize = 14
    ns.ApplyAll()
    F.RunTimers()
    expect(Buttons.Get("Spoken").Icon.width == 20, "the info bar's icons aren't at their size")
    -- An atlas's drawn part at the size, not its empty margin, its shape kept; the padlock's too.
    local volume = Buttons.Get("KaLiHUD_Volume").Icon
    expect(near(volume.height, 20) and volume.width < volume.height, "an atlas icon's art isn't at the icons' size, or is squashed")
    -- The padlock's block (Ikar 2026-11-20: "go for bloc"): flush with the screen's edge and foot, a little taller than the
    -- bar, wider than tall, its padlock over the bar's middle, the bar's items stopping short of it.
    do
        local lock, barH = InfoBar.lockButton, ns.Hub.BarHeight()
        local point, to, rel, x, y = lock:GetPoint()
        expect(point == "BOTTOMRIGHT" and to == InfoBar.frame and rel == "BOTTOMRIGHT" and x == 0 and y == 0
            and lock:GetHeight() > barH and lock:GetHeight() < barH * 1.3 and lock:GetWidth() > lock:GetHeight()
            and lock.Icon.height < barH and lock.Icon.height > barH / 2
            and InfoBar.Ends().rightEdge <= UIParent:GetWidth() - lock:GetWidth(),
            "the padlock's block isn't flush with the bar's end, a little taller than the bar, its padlock in it, or the bar's items run under it")
    end
    expect(Buttons.Get("KaLiHUD_Clock").Text.kaliSize == 14, "the info bar's text isn't at its size")
    ns.db.options.infoSize = nil
    ns.ApplyAll()
    F.RunTimers()
end

-- ---------- The status bars ----------
-- As FlareUI's: rested, the bonus runs ahead of the fill; the tooltip says what's left; a gain flashes the fill; the
-- numbers as asked; at the cap, the experience bar has nothing to show (no automatic choice, Ikar 2026-11-15). The
-- quests' XP is gone (Ikar 2026-11-15: not useful).
expect(bars[-1].info and bars[-1].info.kind == "xp" and bars[-1].Rested:IsShown() and bars[-1].Quest == nil
    and ns.DB.DEFAULTS.statusQuestXP == nil,
    "the rested bonus doesn't run ahead of the experience, or the quests' XP stays")
F.RunScript(bars[-1], "OnEnter")
expect(has(L.STATUS_XP_LEFT) and has(L.STATUS_RIGHT_CLICK), "the experience bar's tooltip doesn't say what's left")
F.RunScript(bars[-1], "OnLeave")
local plays = bars[-1].Flash.anim.plays or 0
F.xp.cur = F.xp.cur + 300
F.Fire("PLAYER_XP_UPDATE")
F.RunTimers()
expect((bars[-1].Flash.anim.plays or 0) == plays + 1, "an experience gain doesn't flash the fill")
F.xp.cur = F.xp.cur - 300
ns.db.options.statusLeftNumbers = "percent"
ns.StatusBars.Refresh()
expect(bars[-1].Text:GetText() == L.STATUS_XP .. "  " .. ns.Format.Percent(F.xp.cur / F.xp.max)
    and bars[1]:IsShown() and not bars[1].Text:GetText():find("%", 1, true),
    "the left bar's numbers aren't a percentage, or the right bar's are too: " .. tostring(bars[-1].Text:GetText()))
ns.db.options.statusLeftNumbers = nil
F.maxLevel = 23
ns.StatusBars.Refresh()
F.RunTimers()
expect(not bars[-1]:IsShown() and bars[1]:IsShown() and bars[1].Text:GetText():find("Darnassus", 1, true),
    "at the cap, the experience bar still shows, or the reputation leaves the right bar")
F.maxLevel = nil
ns.StatusBars.Refresh()
F.RunTimers()
F.RunScript(bars[-1], "OnMouseUp", "RightButton")
item = F.MenuItem(L.STATUS_honor)
if item then
    run(item.choose)
    F.RunTimers()
end
expect(ns.db.options.statusLeft == "honor" and bars[-1].Text:GetText():find("1", 1, true), "the left bar doesn't switch to honour")
ns.db.options.statusLeft = "xp"
F.maxLevel = 23
F.Fire("PLAYER_XP_UPDATE")
F.RunTimers()
-- At the cap the bar goes; its place stays on the plate until Edit Mode reads the game again, then it's gone for good.
expect(not bars[-1]:IsShown() and not bars[-1].Cap:IsShown() and hasSlot("status-1"),
    "at the level cap the experience bar or its cap stays, or its place leaves the plate outside Edit Mode")
F.EnterEditMode()
F.RunTimers()
expect(not hasSlot("status-1"), "in Edit Mode, the experience bar at the cap keeps its place")
F.ExitEditMode()
F.RunTimers()
expect(not hasSlot("status-1") and not bars[-1]:IsShown(), "frozen at the cap, the experience bar's place comes back")
expect(hasSlot("status1"), "the reputation bar's slot went with the experience bar's")
F.maxLevel = nil
F.faction = nil
F.Fire("UPDATE_FACTION")
F.RunTimers()
expect(not bars[1]:IsShown(), "with no watched faction the reputation bar stays")
-- The percentage in an end cap at the left bar's right end (Ikar 2026-11-15: "bright color, like a cartouche, a nice
-- end cap"): as tall as the slot, 2 over the box each way, over the box's end, the track running under its metal; the
-- plate's metal, smaller and brighter, its ends whole as the corners say; inside, the bar's colour lit from the top;
-- hovered or right-clicked, the bar's own. One size, the text's (Ikar: "no need for 2 options"). No cap (from its
-- menu): the bar runs to its slot's end, the row as tall as the other bar's cap.
do
    local b, o = bars[-1], ns.db.options
    local cap, slot = b.Cap, b.slot
    local box = o.statusLeftFontSize + 3
    local capX = select(4, cap:GetPoint())
    local trackEnd = slot.x + 2 + b.width
    expect(cap:IsShown() and b.Label:GetText() == ns.Format.Percent(b.fraction) and near(slot.h, box + 4)
        and near(cap.height, slot.h) and near(capX + cap.width, slot.x + slot.w) and near(b.Holder.height, box)
        and near(b.Holder.width, slot.w - cap.width / 2) and trackEnd > capX and trackEnd < capX + cap.width / 2,
        "the percentage's cap isn't at the bar's end as tall as its slot, the bar running under it")
    ns.Border.ApplyAll()
    local d = cap.KaLiBorder
    local _, g = ns.Border.Color()
    local first = d.pool[1]
    local metal = first and first.vertexColor
    expect(first and first:IsShown() and metal and metal[2] > g and near(metal[2], g * ns.Border.CAP_SHADE)
        and metal[1] <= 1 and near(d.edge, ns.LOOK.edge * ns.Border.CAP_SCALE * o.borderSize / 100)
        and ns.Border.CAP_SCALE < 0.5
        and #d.pool > 12,
        "the cap's border isn't the plate's metal, thinner than half (Ikar: \"reduce the border\") and brighter, round "
            .. "its ends")
    local c, ch, m = b.statusBarColor or { 1, 1, 1 }, { "r", "g", "b" }, 1
    for i = 2, 3 do
        m = c[i] > c[m] and i or m
    end
    -- how much of the bar's colour a colour is, nil when it isn't that colour
    local function share(col)
        if not col then
            return nil
        end
        local k = col[ch[m]] / c[m]
        for i = 1, 3 do
            if math.abs(col[ch[i]] - c[i] * k) > 1e-3 then
                return nil
            end
        end
        return k
    end
    local inside, lit = (d.slabCount or 0) > 2, true
    for i = 1, d.slabCount or 0 do
        local t = d.slabs[i]
        local x, y = select(4, t:GetPoint())
        inside = inside and x >= 0 and x + t.width <= cap.width and y >= 0 and y + t.height <= cap.height
        local gradient = t.gradient or {}
        local foot, top = share(gradient[2]), share(gradient[3])
        lit = lit and foot and top and foot >= 0.6 - 1e-3 and foot < top and top <= 1 + 1e-3
    end
    expect(inside and lit, "the cap isn't filled with the bar's colour, lit from the top, within it")
    -- the game's colours drawn greyer and darker (Ikar 2026-11-15: "less saturated, a bit darker"), the rested bonus
    -- too (FlareUI's 0.4, 0.8, 1: light 0.70, saturation 0.6)
    local function looks(col)
        local hi, lo = math.max(col[1], col[2], col[3]), math.min(col[1], col[2], col[3])
        return 0.299 * col[1] + 0.587 * col[2] + 0.114 * col[3], hi > 0 and (hi - lo) / hi or 0
    end
    local gameLight, gameSat = looks(b.info and b.info.colour or { 0, 0, 0 })
    local light, sat = looks(c)
    local restLight, restSat = looks(b.Rested.vertexColor or { 1, 1, 1 })
    expect(light < gameLight - 0.01 and sat < gameSat - 0.01 and restLight < 0.69 and restSat < 0.59,
        "the bars' colours aren't the game's, greyer and darker")
    -- two digits wide, its ends as long as their shape needs past them, a round or square one's with some room (Ikar
    -- 2026-11-15: it looked off centre in them); wider while it says 100 %
    local was = b.Label:GetText()
    b.Label:SetText(ns.Format.Percent(0.88))
    local twoW = math.ceil(b.Label:GetStringWidth())
    b.Label:SetText(was)
    local half = o.statusLeftFontSize * ns.StatusBars.INK / 2
    local function capWide(style)
        local room = style == "bevel" and 0 or o.statusLeftFontSize * ns.StatusBars.CAP_ROOM
        return twoW + 2 * (ns.Border.CapEnds(cap.height, half, style) + room)
    end
    expect(near(cap.width, capWide(o.cornerStyle)) and ns.StatusBars.CAP_ROOM > 0,
        "the cap isn't the percentage's width and its ends'")
    for _, style in ipairs({ "bevel", "square" }) do
        o.statusLeftCapShape = style
        ns.ApplyAll()
        F.RunTimers()
        expect(near(cap.width, capWide(style)), "a " .. style .. " cap isn't the percentage's width and its ends'")
    end
    o.statusLeftCapShape = nil
    ns.ApplyAll()
    F.RunTimers()
    local narrow, cur = cap.width, F.xp.cur
    F.xp.cur = F.xp.max - 1
    F.Fire("PLAYER_XP_UPDATE")
    F.RunTimers()
    local wide, full = cap.width, b.Label:GetText()
    F.xp.cur = cur
    F.Fire("PLAYER_XP_UPDATE")
    F.RunTimers()
    expect(full == ns.Format.Percent(1) and wide > narrow and near(cap.width, narrow),
        "the cap doesn't widen for 100 % and back")
    -- whatever the ends' shape and the size, the percentage's corners just clear of the metal
    local prof = ns.Border.CapProfile()
    local clear, snug = prof.e * ns.Border.CAP_METAL + ns.Border.CAP_CLEAR, true
    for _, style in ipairs({ "bevel", "round", "square" }) do
        for _, size in ipairs({ { 13, 2.3 }, { 21, 5.3 } }) do
            local h, half2 = size[1], size[2]
            local ends = ns.Border.CapEnds(h, half2, style)
            local w = 40 + 2 * ends
            local pts = ns.Geometry.Rect(-prof.out, -prof.out, w + prof.out, h + prof.out,
                style == "square" and 0 or math.huge, style, 0.05)
            local px, py, best = w - ends, h / 2 + half2, math.huge
            for i = 1, #pts - 3, 2 do
                local ax, ay, dx, dy = pts[i], pts[i + 1], pts[i + 2] - pts[i], pts[i + 3] - pts[i + 1]
                local t = ((px - ax) * dx + (py - ay) * dy) / math.max(dx * dx + dy * dy, 1e-12)
                t = math.max(0, math.min(1, t))
                best = math.min(best, math.sqrt((ax + t * dx - px) ^ 2 + (ay + t * dy - py) ^ 2))
            end
            snug = snug and math.abs(best - clear) < 0.02
        end
    end
    expect(snug, "the cap's ends don't keep the percentage's corners just clear of their metal")
    -- its ends as the corners say, as long as they need past the percentage: pointed the longest, square the shortest
    local widths = { round = cap.width or 0 }
    for style, sides in pairs({ bevel = 6, square = 4 }) do
        o.cornerStyle = style
        ns.ApplyAll()
        F.RunTimers()
        ns.Border.ApplyAll()
        local shown = 0
        for _, t in ipairs(d.pool) do
            shown = shown + (t:IsShown() and 1 or 0)
        end
        widths[style] = cap.width or 0
        -- under a pointed end, the track's corners too
        local tEnd, cx = b.slot.x + 2 + b.width, select(4, cap:GetPoint()) or math.huge
        expect(shown == sides and tEnd > cx and (style ~= "bevel" or tEnd >= cx + b.height / 2),
            "the cap's ends aren't " .. style .. ", or the track's end shows: " .. shown .. " sides")
    end
    expect(widths.bevel > widths.round and widths.round > widths.square, "the cap's ends don't take what they need")
    o.cornerStyle = nil
    ns.ApplyAll()
    F.RunTimers()
    cap.mouseOver = true
    F.RunScript(cap, "OnEnter")
    expect(b.Text:IsShown() and GameTooltip:IsOwned(b) and has(L.STATUS_RIGHT_CLICK),
        "hovering the cap doesn't show the bar's text and tooltip")
    cap.mouseOver = false
    F.RunScript(cap, "OnLeave")
    expect(not b.Text:IsShown(), "leaving the cap leaves the bar's text")
    F.lastMenu = nil
    F.RunScript(cap, "OnMouseUp", "RightButton")
    local noCap = F.MenuItem(L.CAP_none)
    expect(noCap ~= nil, "right-clicking the cap doesn't open the bar's menu, its cap's end in it")
    if noCap then
        run(noCap.choose)
        F.RunTimers()
    end
    local r = bars[1].slot
    expect(o.statusLeftCap == "none" and not cap:IsShown() and near(b.slot.h, box) and near(b.Holder.height, box)
        and near(b.Holder.width, b.slot.w) and near(b.width, b.slot.w - 4) and near(r.h, box + 4)
        and near(b.slot.y + box / 2, r.y + r.h / 2),
        "without its cap the bar doesn't run to the end of its slot, or it leaves the other bar's middle line")
    o.statusRightCap = "none"
    ns.ApplyAll()
    F.RunTimers()
    expect(near(bars[1].slot.h, box) and near(b.slot.y, bars[1].slot.y), "with no cap left a slot keeps a cap's height")
    o.statusLeftCap, o.statusRightCap = nil, nil
    ns.ApplyAll()
    F.RunTimers()
    -- its shape and its fill from that menu too
    F.RunScript(cap, "OnMouseUp", "RightButton")
    local square, reverse = F.MenuItem(L.SHAPE_square), F.MenuItem(L.OPT_STATUS_REVERSE)
    if square and reverse then
        run(square.choose)
        run(reverse.choose)
        F.RunTimers()
    end
    expect(o.statusLeftCapShape == "square" and o.statusLeftReverse == true and b.reverseFill == true,
        "the bar's menu doesn't set its cap's shape or reverse its fill")
    o.statusLeftCapShape, o.statusLeftReverse = nil, nil
    -- saved wrong, put right
    local saved = { version = 1, items = {}, folders = {}, buttonsLeft = {}, statusPlaces = {}, gold = {},
        options = { statusLeftCap = "middle", statusRightCapShape = "oval", statusLeftReverse = "yes" } }
    local _, info = ns.DB.Open(saved)
    expect(info and info.fixed == 3 and next(saved.options) == nil,
        "a bar's cap end, its shape or its fill saved wrong isn't put right")
    o.statusLeftFontSize = 14
    ns.ApplyAll()
    F.RunTimers()
    local other, size = bars[1], ns.DB.DEFAULTS.statusRightFontSize
    expect(b.Text.kaliSize == 14 and near(b.Holder.height, 17) and near(b.slot.h, 21) and near(cap.height, 21)
        and ns.DB.DEFAULTS.statusHeight == nil and other.Text.kaliSize == size and near(other.slot.h, size + 7)
        and near(other.slot.y + other.slot.h / 2, b.slot.y + b.slot.h / 2),
        "a bar's height doesn't follow its text's size, or the other bar's does too, or it leaves their middle line")
    o.statusLeftFontSize = 6
    ns.ApplyAll()
    F.RunTimers()
    expect(ns.DB.RANGES.statusLeftFontSize[1] == 6 and b.Text.kaliSize == 6 and near(b.Holder.height, 9)
        and near(b.slot.h, 13), "the bars don't go down to size 6 (Ikar: \"thinner than 8\")")
    o.statusLeftFontSize = nil
    ns.ApplyAll()
    F.RunTimers()
end
-- Each bar's cap on the map's side, its fill towards the map, by default (Ikar 2026-11-15); per bar its cap at either
-- end or none, its own shape, its fill reversed; the text lifted so its digits sit in the middle.
do
    local o, l, r = ns.db.options, bars[-1], bars[1]
    o.statusRight = "xp"
    ns.ApplyAll()
    F.RunTimers()
    local function capX(b)
        return select(4, b.Cap:GetPoint()) or math.huge
    end
    local rx = select(4, r:GetPoint()) or 0
    expect(r:IsShown() and r.Cap:IsShown() and near(capX(r), r.slot.x) and rx > capX(r) + r.Cap.width / 2
        and rx < capX(r) + r.Cap.width and near(select(4, r.Holder:GetPoint()), r.slot.x + r.Cap.width / 2)
        and r.reverseFill == true and r.Rested:GetPoint() == "TOPRIGHT"
        and near(capX(l) + l.Cap.width, l.slot.x + l.slot.w) and l.reverseFill == false
        and l.Rested:GetPoint() == "TOPLEFT",
        "by default the bars' caps aren't on the map's side, or they don't fill towards it")
    o.statusRightCap, o.statusRightCapShape, o.statusRightReverse, o.cornerStyle = "right", "square", true, "bevel"
    ns.ApplyAll()
    F.RunTimers()
    local function sides(b)
        local n = 0
        for _, t in ipairs(b.Cap.KaLiBorder.pool) do
            n = n + (t:IsShown() and 1 or 0)
        end
        return n
    end
    expect(near(capX(r) + r.Cap.width, r.slot.x + r.slot.w) and r.reverseFill == false
        and r.Rested:GetPoint() == "TOPLEFT" and sides(r) == 4 and sides(l) == 6,
        "a bar's cap end, its shape or its fill set by hand isn't its own")
    o.statusLeftCap = "left"
    ns.ApplyAll()
    F.RunTimers()
    local lift = o.statusLeftFontSize * ns.StatusBars.LIFT
    expect(near(capX(l), l.slot.x) and near(select(3, l.Label:GetPoint()), lift)
        and near(select(3, l.Text:GetPoint()), lift) and ns.StatusBars.LIFT > 0,
        "the left bar's cap doesn't go to its left end, or its percentage and text aren't lifted")
    o.statusRight, o.statusRightCap, o.statusRightCapShape, o.statusRightReverse = nil, nil, nil, nil
    o.cornerStyle, o.statusLeftCap = nil, nil
    ns.ApplyAll()
    F.RunTimers()
end
-- Every setting each bar's own (Ikar 2026-11-15: "make all the setting local to each bar"): the left bar's texture,
-- bubbles and text leave the right one's as they are; the right bar's menu, named for it, sets its own.
do
    local o, l, r = ns.db.options, bars[-1], bars[1]
    o.statusRight = "xp"
    o.statusLeftTexture, o.statusLeftTicks, o.statusLeftText = "flat", false, "always"
    ns.ApplyAll()
    F.RunTimers()
    expect(l.Track.file == "Interface\\Buttons\\WHITE8X8" and r.Track.file ~= l.Track.file and not l.Ticks[1]:IsShown()
        and r.Ticks[1]:IsShown() and l.Text:IsShown() and not r.Text:IsShown(),
        "a bar's texture, bubbles or text setting isn't its own")
    o.statusLeftTexture, o.statusLeftTicks, o.statusLeftText = nil, nil, nil
    F.lastMenu = nil
    F.RunScript(r, "OnMouseUp", "RightButton")
    local title, always, percent = F.lastMenu and F.lastMenu.items[1], F.MenuItem(L.STATUS_ALWAYS),
        F.MenuItem(L.NUM_percent)
    local shownAtOnce
    if always and percent then
        run(always.choose)
        shownAtOnce = r.Text:IsShown()
        run(percent.choose)
        F.RunTimers()
    end
    expect(title and title.text == string.format(L.STATUS_BAR_NAME, 2) and o.statusRightText == "always"
        and o.statusRightNumbers == "percent" and rawget(o, "statusLeftText") == nil
        and rawget(o, "statusLeftNumbers") == nil and shownAtOnce and r.Text:IsShown() and not l.Text:IsShown(),
        "the right bar's menu isn't named Barre de progression 2, or doesn't set its own text and numbers")
    o.statusRight, o.statusRightText, o.statusRightNumbers = nil, nil, nil
    ns.ApplyAll()
    F.RunTimers()
end
-- By default each bar runs in to the map's ring, its end straight under the ring's side, 3 above the info bar (Ikar
-- 2026-11-15: "they should sit like the one on the left", the bar he had dragged there).
do
    local d, T = Plate.last.dome, ns.InfoBar.Top()
    local left, right = bars[-1].slot, bars[1].slot
    expect(d and near(left.x + left.w, d.cx - d.ring) and near(right.x, d.cx + d.ring) and near(left.y, T + 3)
        and near(right.y, T + 3), "the bars don't run in to the map's ring, 3 above the info bar")
end
-- A width given to a bar: that bar that wide, from the map outwards, the other as it was; Auto again, out to the far
-- end of the bars above it.
do
    local left, right = bars[-1].slot, bars[1].slot
    local leftEnd, rightStart, rightW = left.x + left.w, right.x, right.w
    ns.db.options.statusLeftWidth = 300
    ns.ApplyAll()
    F.RunTimers()
    left, right = bars[-1].slot, bars[1].slot
    expect(near(left.w, 300) and near(left.x + left.w, leftEnd) and near(right.w, rightW) and near(right.x, rightStart),
        "a width given doesn't size its bar alone from the map outwards")
    ns.db.options.statusRightWidth = 300
    ns.ApplyAll()
    F.RunTimers()
    right = bars[1].slot
    expect(near(right.w, 300) and near(right.x, rightStart),
        "the right bar's width doesn't size it from the map outwards")
    ns.db.options.statusLeftWidth, ns.db.options.statusRightWidth = nil, nil
    ns.ApplyAll()
    F.RunTimers()
    expect(near(bars[-1].slot.x, 544.6 - ns.db.options.padBars),
        "back to Auto, the left bar doesn't reach the far end of the bars above it")
end
-- In Edit Mode each bar wears a box as Blizzard's frames do: a click opens the dialog at the status bars, a drag moves
-- the bar under the pointer, the plate following; let go, it stays, a frame the plate takes within reach and leaves out
-- of it. Revert and Put back lay it along the info bar again.
do
    local b, sel = bars[-1], bars[-1].Selection
    local home = b.slot.x
    expect(not sel:IsShown(), "a status bar wears its Edit Mode box outside Edit Mode")
    F.EnterEditMode()
    F.RunTimers()
    expect(sel.state == "highlight" and sel:IsShown() and near(select(4, sel:GetPoint()), b.slot.x)
        and near(sel.width, b.slot.w) and near(sel.height, b.slot.h),
        "a status bar has no box over it, cap included, in Edit Mode")
    F.RunScript(sel, "OnMouseDown", "LeftButton")
    local capRow, otherRow, sizeRow, shared, hides = nil, nil, nil, nil, 0
    for _, f in ipairs(KaLiHUDEditModeDialog.rows) do
        local key = f.row.key
        capRow = key == "statusLeftCap" and f or capRow
        otherRow = key == "statusRightCap" and f or otherRow
        sizeRow = key == "statusLeftFontSize" and f or sizeRow
        shared = (key == "statusFontSize" or key == "statusTexture" or key == "statusHeight") and f or shared
        hides = hides + (key == "hideExternalXP" and 1 or 0)
    end
    local names = {}
    for _, bar in ipairs(KaLiHUDEditModeDialog.sections) do
        names[bar.section.id] = bar.section.name
    end
    local name = L.STATUS_BAR_NAME
    expect(ns.EditPanel.IsShown() and capRow and capRow:IsShown() and otherRow and not otherRow:IsShown()
        and sizeRow and sizeRow:IsShown() and not shared and hides == 0 and names.bars == nil
        and names.barLeft == string.format(name, 1) and names.barRight == string.format(name, 2)
        and name == "Barre de progression %d" and sel.system:GetSystemName() == names.barLeft
        and bars[1].Selection.system:GetSystemName() == names.barRight,
        "clicking a bar's box doesn't open the dialog at all that bar's own settings, named Barre de progression 1, "
            .. "or a shared setting stays")
    F.cursorX, F.cursorY = b.slot.x + 10, b.slot.y + 3
    F.RunScript(sel, "OnDragStart")
    F.cursorX, F.cursorY = 610, 603
    F.RunScript(sel, "OnUpdate")
    expect(near(b.slot.x, 600) and near(b.slot.y, 600) and not hasSlot("status-1") and Plate.last.far["status-1"],
        "a status bar dragged up high doesn't follow the pointer, or the plate still takes it")
    F.cursorX, F.cursorY = 610, 203
    F.RunScript(sel, "OnUpdate")
    F.RunScript(sel, "OnDragStop")
    F.RunTimers()
    local place = ns.db.statusPlaces.left
    expect(place and near(place.x, 600) and near(place.y, 200) and hasSlot("status-1") and b:IsShown()
        and near(b.slot.h, ns.db.options.statusLeftFontSize + 7),
        "a status bar let go within reach isn't kept there and taken, its cap's height")
    ns.db.options.statusLeftWidth = 250
    ns.db.statusPlaces.right = { x = 1300, y = 600, w = 380 }
    ns.ApplyAll()
    F.RunTimers()
    expect(near(b.slot.w, 250) and ns.StatusBars.RowHeight() == 0,
        "a dragged bar isn't at the width given, or the row along the info bar stays with no bar left in it")
    ns.db.options.statusLeftWidth = nil
    ns.db.statusPlaces.right = nil
    ns.ApplyAll()
    F.RunTimers()
    ns.EditPanel.Revert()
    F.RunTimers()
    expect(ns.db.statusPlaces.left == nil and near(b.slot.x, home), "Revert doesn't put the dragged bar back")
    F.cursorX, F.cursorY = b.slot.x + 10, b.slot.y + 3
    F.RunScript(sel, "OnDragStart")
    F.cursorX, F.cursorY = 610, 203
    F.RunScript(sel, "OnDragStop")
    F.ExitEditMode()
    F.RunTimers()
    expect(not sel:IsShown() and ns.db.statusPlaces.left and hasSlot("status-1"),
        "out of Edit Mode the box stays, or the bar goes back")
    -- its own section's « Replacer », the other bar left where it was dragged
    ns.db.statusPlaces.right = { x = 1300, y = 600, w = 380 }
    local putBack
    for _, f in ipairs(KaLiHUDEditModeDialog.rows) do
        putBack = f.row.text == L.STATUS_PUT_BACK and f.section.id == "barLeft" and f.row or putBack
    end
    if putBack then
        run(putBack.click)
    end
    F.RunTimers()
    expect(putBack and ns.db.statusPlaces.left == nil and ns.db.statusPlaces.right and near(b.slot.x, home),
        "a bar's Replacer doesn't lay it alone along the info bar again")
    ns.db.statusPlaces.right = nil
    ns.ApplyAll()
    F.RunTimers()
end

-- ---------- Efficiency ----------
-- The hub's list is built once a change, not for each question: hovering the map, its dressing, a live redraw and a
-- text that changes build nothing; a text that changes draws its button alone, the bar re-placed when it grew.
do
    Hub.Entries()
    local builds = Hub.builds
    Minimap.mouseOver = true
    ns.Minimap.UpdateHover()
    Minimap.mouseOver = false
    ns.Minimap.UpdateHover()
    ns.Minimap.Apply()
    F.EnterEditMode()
    move(MultiBarBottomLeft, 544.6, 96)
    F.RunScript(Plate.frame, "OnUpdate")
    move(MultiBarBottomLeft, 544.6, 94.5)
    F.RunScript(Plate.frame, "OnUpdate")
    F.ExitEditMode()
    F.RunTimers()
    local refreshes, rightEnd = InfoBar.refreshes, InfoBar.Ends().right
    local libs = F.ldb.objects["Libs Error Display"]
    libs.text = "123456789"
    Hub.Set("KaLiHUD_Bags", "text", "7/28")
    F.RunTimers()
    expect(Hub.builds == builds, "the hub's list is built again for questions: " .. (Hub.builds - builds) .. " times")
    expect(Buttons.Get("Libs Error Display").Text:GetText():find("123456789", 1, true)
        and Buttons.Get("KaLiHUD_Bags").Text:GetText() == "7/28" and InfoBar.refreshes == refreshes,
        "a text that changes redraws the whole hub, or not its button")
    expect(InfoBar.Ends().right < rightEnd, "a text grown wider doesn't push the bar's right end")
    libs.text = "0"
    ns.Items.Update()
    F.RunTimers()
    -- The movement check allocates nothing: it runs every frame while live.
    collectgarbage("collect")
    collectgarbage("stop")
    local kb = collectgarbage("count")
    for _ = 1, 200 do
        Plate.Moved()
    end
    local grown = collectgarbage("count") - kb
    collectgarbage("restart")
    expect(grown < 1, "the movement check allocates " .. grown .. " KB in 200 checks")
    -- Outside Edit Mode nothing is followed: a press on a window has the plate look at nothing.
    F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    expect(Plate.frame:GetScript("OnUpdate") == nil, "outside Edit Mode, a press on a window has the plate look every frame")
    F.Fire("GLOBAL_MOUSE_UP", "LeftButton")
    -- Edit Mode's Revert draws the HUD once, however many settings it puts back.
    F.EnterEditMode()
    ns.db.options.marginBars, ns.db.options.padBars, ns.db.options.reach = 20, 9, 60
    local applies, applyAll = 0, ns.ApplyAll
    ns.ApplyAll = function()
        applies = applies + 1
        applyAll()
    end
    ns.EditPanel.Revert()
    ns.ApplyAll = applyAll
    expect(applies == 1 and ns.db.options.marginBars == ns.DB.DEFAULTS.marginBars and ns.db.options.reach == 40,
        "reverting three settings draws the HUD " .. applies .. " times")
    F.ExitEditMode()
    F.RunTimers()
end

-- ---------- Commands & Entry points ----------
do
    for _, text in ipairs({ "", "options", "edit", "help", "status", "redraw", "reach", "reach nope", "bridge", "bridge nope", "report" }) do
        slash(text)
    end
    F.ExitEditMode()
    F.RunTimers()
    run(KaLiHUD_OnAddonCompartmentClick)
    expect(printed(string.format(L.REACH, 40)), "/kh reach doesn't say the reach")
    expect(printed(string.format(L.REACH_USAGE, ns.DB.RANGES.reach[2])), "/kh reach with no number gives no usage")
    expect(printed(string.format(L.BRIDGE, 40)), "/kh bridge doesn't say the bridge")
    expect(printed(string.format(L.BRIDGE_USAGE, ns.DB.RANGES.bridge[2])), "/kh bridge with no number gives no usage")
    -- Less reach, no status bars under the bars: the bars 27 above the info bar go, the damage meter 6 above it stays.
    ns.db.options.statusLeft, ns.db.options.statusRight = "none", "none"
    slash("reach 10")
    expect(ns.db.options.reach == 10 and not taken("MainActionBar") and taken("DamageMeter"), "/kh reach 10 doesn't let the bars go")
    slash("reach 9999")
    expect(ns.db.options.reach == 10, "/kh reach takes a reach past the most")
    slash("reach 40")
    expect(taken("MainActionBar"), "/kh reach 40 doesn't take the bars back")
    ns.db.options.statusLeft, ns.db.options.statusRight = nil, nil
    ns.ApplyAll()
    F.RunTimers()
    run(SlashCmdList.KALIHUDPROBE, "")
    run(SlashCmdList.KALIHUDPROBE, "blocked")
    F.RunTimers()
end

-- ---------- The review's fixes (2026-11-16) ----------
-- Edit Mode's boxes: each of the HUD's takes whatever the mouse can do to it. The strip's box is Blizzard's template,
-- whose own drag scripts take its parent for one of Edit Mode's systems: dragging the strip raised an error.
do
    local places = ns.DeepCopy(ns.db.statusPlaces)
    F.EnterEditMode()
    F.RunTimers()
    local tried = F.TrySelections()
    expect(#tried == 0, "a press, a drag or the pointer on one of the HUD's boxes in Edit Mode raises an error: "
        .. table.concat(tried, " | "))
    local strip
    for _, box in ipairs(F.selections) do
        if box:GetParent() == KaLiHUDHolder then
            strip = box
        end
    end
    expect(strip and strip:IsShown() and strip:GetScript("OnDragStart") == nil and strip:GetScript("OnDragStop") == nil,
        "the strip's box keeps Blizzard's drag scripts, which call a parent that is no Edit Mode system")
    ns.EditFrame.Deselect()
    if strip then
        F.RunScript(strip, "OnMouseDown", "LeftButton")
        F.RunScript(strip, "OnDragStart", "LeftButton")
        F.RunScript(strip, "OnDragStop")
    end
    expect(ns.EditFrame.IsSelected() and KaLiHUDEditModeDialog:IsShown() and EditModeManagerFrame.selected == nil,
        "a press on the strip doesn't pick it, or picks it in Edit Mode's manager as one of Blizzard's systems")
    F.ExitEditMode()
    F.RunTimers()
    wipe(ns.db.statusPlaces)
    for key, place in pairs(places) do
        ns.db.statusPlaces[key] = place
    end
    ns.ApplyAll()
    F.RunTimers()
end

-- /kh status with the saved data refused: what the command is for then, and it raised an error.
do
    local db, disabled, errors = ns.db, ns.disabled, ns.Count(KaLiHUDDevDB.errors)
    ns.db, ns.disabled = nil, "test: refused"
    slash("status")
    local shown = KaLiHUDTextWindow and KaLiHUDTextWindow.Edit:GetText() or ""
    expect(ns.Count(KaLiHUDDevDB.errors) == errors and shown:find("saved data: refused, test: refused", 1, true)
        and shown:find("(no saved data: test: refused)", 1, true),
        "/kh status with the saved data refused raises an error, or doesn't say why: " .. tostring(next(KaLiHUDDevDB.errors)))
    F.printed = {}
    run(KaLiHUD_OnAddonCompartmentClick)
    expect(printed(string.format(L.DB_REFUSED, "test: refused")), "the compartment's click with the saved data refused doesn't say why")
    ns.db, ns.disabled = db, disabled
    KaLiHUDTextWindow:Hide()
end

-- The options page: a frame of the addon's own, nothing in the game's own lists of settings (what an addon puts there
-- the game's pages and its search then work with, and the game blames the addon for what they do: KaLi Quest, for the
-- Social page's Discord rows, 2026-11-12).
do
    local page = ns.Options.page
    expect(page and F.settingsLayout == nil and F.settingsCategory == nil and F.settingsRegistered == page.category
        and #F.settingsPages == 3, "the options page puts something in the game's own lists of settings")
    SettingsPanel:Hide()
    slash("options")
    expect(SettingsPanel:IsShown() and F.settingsPage == page.category and page.frame:IsShown()
        and page.frame.Title:GetText() == ns.TITLE, "/kh options doesn't open the page, under its title")
    local function row(name)
        return F.PageRow(page.category, name)
    end
    local sets, behaviour = page.pages[1], page.pages[2]
    -- (the addon's state no row of its own since 2026-11-20, the bug report carrying it: "Diagnose can be removed")
    local edit, report = row(L.OPTION_EDIT_MODE), row(L.REPORT_TITLE)
    expect(edit and report and ns.STRINGS.frFR.DIAG_STATUS == nil, "the options page lacks one of its rows, or shows the addon's state")
    -- Which of the HUD's parts are on is here as in Edit Mode's dialog (Ikar 2026-11-19: "keep 4, but duplicate in the
    -- settings too"): a box unticked here turns its part off, ticked on again
    local plate = row(L.OPT_PLATE)
    expect(plate and row(L.OPT_MINIMAP) and row(L.OPT_WIN_FOLD) and row(L.OPT_INFO_BAR),
        "the options page lacks one of the HUD's parts")
    if plate then
        plate.Check:SetChecked(false)
        F.RunScript(plate.Check, "OnClick")
        F.RunTimers()
        local off = ns.db.options.plate == false
        plate.Check:SetChecked(true)
        F.RunScript(plate.Check, "OnClick")
        F.RunTimers()
        expect(off and ns.db.options.plate == true, "a part's box on the options page doesn't turn it off and on")
    end
    -- Two pages under it, each as tall as the game's options show: « Préréglages », then « Comportement et sons »
    expect(sets and sets.category and sets.category.parent == page.category and sets.category.name == L.SET_TITLE
        and behaviour and behaviour.category and behaviour.category.parent == page.category
        and behaviour.category.name == L.OPTIONS_BEHAVIOUR,
        "the pages under KaLi HUD's aren't the presets' and the one of what it does and sounds like")
    -- « Comportement et sons »: what the HUD does by itself and what it sounds like, from Edit Mode's dialog, and the
    -- info bar's own boxes. A box sets its option, a click on its name too; a slider sets its own; a sound picked
    -- plays; the page's reset puts all back, playing none
    if behaviour and behaviour.category then
        F.PickSettingsPage(behaviour.category)
        local function sub(name)
            return F.PageRow(behaviour.category, name)
        end
        -- (not the bar's items' own since 2026-11-20, in their right-click: "some settings shoudl be a component option
        -- in it right click instead of a addon option"; the padlock on itself and in the bar's menu)
        local peek, reset, zoom, fold = sub(L.OPT_CHAT_PEEK), sub(L.OPTIONS_DEFAULTS), sub(L.OPT_MM_AUTOZOOM),
            sub(L.OPT_FOLD_SOUND)
        expect(peek and reset and zoom and fold and sub(L.OPT_FOLD_ANIM) and sub(L.OPT_FOLDER_SOUND)
            and sub(L.OPT_METER_COMBAT) and sub(L.OPT_FOLDER_COMBAT) and sub(L.OPT_HIDE_EXT_XP),
            "the page of what the HUD does and sounds like lacks one of its rows")
        expect(not sub(L.BAGS_SHOW_FREE) and not sub(L.GOLD_COPPER) and not sub(L.SLOTS_LOCKED),
            "an item's own setting, or the padlock, is on the page of what the HUD does")
        -- each sound a button by it that plays the one picked, greyed on « Aucun » (Ikar 2026-11-20: "the two sounds
        -- shoudl have a play button next")
        do
            local folder, was = sub(L.OPT_FOLDER_SOUND), ns.db.options.foldSound
            ns.db.options.foldSound = "tome"
            ns.Options.Changed()
            local n = #F.sounds
            -- (rawget: the fake game answers any name of a method's shape with one)
            local play = fold and rawget(fold, "PlayButton")
            if play then
                F.RunScript(play, "OnClick")
            end
            local played = play and F.sounds[n + 1] == ns.FOLD_SOUNDS.tome[1] and play:IsEnabled()
            ns.db.options.foldSound = "none"
            ns.Options.Changed()
            expect(played and not play:IsEnabled() and folder and rawget(folder, "PlayButton"),
                "a sound's row has no button that plays the one picked, or it plays « Aucun »")
            ns.db.options.foldSound = was
            ns.Options.Changed()
        end
        if peek and reset then
            local default = ns.DB.DEFAULTS.chatPeekOnType
            local was = ns.db.options.chatPeekOnType
            peek.Check:SetChecked(not was)
            F.RunScript(peek.Check, "OnClick")
            F.RunTimers()
            expect(ns.db.options.chatPeekOnType == not was, "a check box of the page doesn't set its option")
            F.RunScript(peek.Hover, "OnMouseUp", "LeftButton")
            F.RunTimers()
            expect(ns.db.options.chatPeekOnType == was and peek.Check:GetChecked() == was,
                "a click on a row's name doesn't tick its box")
            ns.db.options.chatPeekOnType = not default
            ns.Options.Changed()
            -- (asked first: Ikar 2026-11-19, "All reset ... should be deliberate decision (confirmation popup, etc)")
            F.popup = nil
            F.RunScript(reset.Button, "OnClick")
            F.RunTimers()
            expect(F.popup ~= nil and F.popup.which == "KALIHUD_ASK" and ns.db.options.chatPeekOnType == not default,
                "the page's reset puts its options back without asking first")
            if F.popup then
                F.AcceptPopup()
            end
            F.RunTimers()
            expect(ns.db.options.chatPeekOnType == default and peek.Check:GetChecked() == default,
                "the reset row doesn't put the check boxes back to their defaults, or they don't show it")
            ns.db.options.chatPeekOnType = was
        end
        if zoom and fold and reset then
            local wasZoom, wasSound = ns.db.options.minimapAutoZoom, ns.db.options.foldSound
            zoom.Slider:SetValue(7)
            F.RunTimers()
            F.sounds = {}
            for _, radio in ipairs(F.MenuRadios(fold.Dropdown)) do
                if radio.text == L.FOLD_SOUND_parchment then
                    radio.pick()
                end
            end
            F.RunTimers()
            local picked = ns.db.options.minimapAutoZoom == 7 and ns.db.options.foldSound == "parchment"
                and #F.sounds == 1 and F.sounds[1] == 1192
            F.RunScript(reset.Button, "OnClick")
            if F.popup then
                F.AcceptPopup()
            end
            F.RunTimers()
            expect(picked and ns.db.options.minimapAutoZoom == ns.DB.DEFAULTS.minimapAutoZoom
                and ns.db.options.foldSound == ns.DB.DEFAULTS.foldSound and #F.sounds == 1,
                "a slider or a sound picked on the page doesn't set its option, the sound playing; or the page's reset "
                .. "doesn't put them back, or plays one")
            ns.db.options.minimapAutoZoom, ns.db.options.foldSound = wasZoom, wasSound
        end
        -- The padlock clicked while the page shows: its box follows.
        local lock = sub(L.SLOTS_LOCKED)
        if lock then
            local locked = Hub.IsLocked()
            Hub.SetLocked(not locked)
            ns.ApplyAll()
            F.RunTimers()
            expect(lock.Check:GetChecked() == not locked, "the padlock clicked while the page shows, its box doesn't follow")
            Hub.SetLocked(locked)
            ns.ApplyAll()
            F.RunTimers()
        end
    end
    -- « Préréglages » (Ikar 2026-11-19: "this should go into the setting windows, not the edit mode"; of applying, "a
    -- checkbox for each state, on by default"; of the list a button opened, "vos prereglage can't be a drop down with
    -- button in it own section ? Grayed when innactive"). The settings as they are kept under a name asked for, and
    -- picked; the page's dropdown holds the sets and another character's own settings; its buttons, greyed while
    -- nothing is picked or the one picked doesn't allow it; « Appliquer… » opens it in its window, a box for each
    -- part, all ticked
    if sets and sets.category then
        F.PickSettingsPage(sets.category)
        local function sub(name)
            return F.PageRow(sets.category, name)
        end
        local own, picker, save = sub(L.SET_OWN), sub(L.SET_PICK_NAME), sub(L.SET_SAVE_NAME)
        local below
        for _, row in ipairs(sets.frame.rows) do
            below = below or (row.Buttons and row)
        end
        expect(own and picker and save and below and #below.Buttons == 5, "the presets' page lacks one of its rows")
        if own and picker and save and below then
            local Sets, o = ns.Sets, ns.db.options
            local apply, update, rename, share, delete = unpack(below.Buttons)
            local function radio(text)
                for _, r in ipairs(F.MenuRadios(picker.Dropdown)) do
                    if r.text == text then
                        return r
                    end
                end
            end
            local function lit()
                return apply:IsEnabled() and "a" or "-", update:IsEnabled() and "u" or "-",
                    rename:IsEnabled() and "r" or "-", share:IsEnabled() and "s" or "-", delete:IsEnabled() and "d" or "-"
            end
            local function litText()
                return table.concat({ lit() })
            end
            expect(litText() == "-----", "a button under the presets' dropdown is lit with nothing picked: " .. litText())
            F.popup = nil
            F.RunScript(save.Button, "OnClick")
            local asked = F.popup and F.popup.which == "KALIHUD_SET_NAME"
            if asked then
                F.popup.data.done("Tank")
                F.popup = nil
            end
            local kept = Sets.List()[1]
            expect(asked and kept and kept.name == "Tank" and #Sets.List() == 1,
                "the settings as they are aren't kept under a name asked for")
            expect(ns.SetWindow.PickedValue() == kept and litText() == "aursd",
                "a set kept isn't picked on the page, its buttons lit: " .. litText())
            ns.db.chars["Royaume-Thrall"] = { own = true, settings = Sets.Capture() }
            local item, other = radio("Tank"), radio(string.format(L.SET_OF, "Thrall"))
            expect(item and other, "the presets' dropdown lacks a set kept, or another character's own settings")
            if kept and item and other then
                item.pick()
                F.RunScript(apply, "OnClick")
                local w = KaLiHUDSetWindow
                local all = w ~= nil
                for _, part in ipairs(Sets.PARTS) do
                    all = all and w.Boxes[part]:GetChecked() == true
                end
                expect(all and w:IsShown() and ns.SetWindow.Shown().set == kept and w.Title:GetText() == "Tank",
                    "« Appliquer… » doesn't open the set picked in its window, a box for each part, all ticked")
                -- applied with a part unticked: that part stays as it is, the rest is taken, the window shuts, and the
                -- settings as they were are kept under the set's name
                local reach, color = o.reach, rawget(o, "borderColor")
                kept.settings.options.reach, kept.settings.options.borderColor = 77, "aabbcc"
                w.Boxes.plate:SetChecked(false)
                F.RunScript(w.Boxes.plate, "OnClick")
                F.RunScript(w.Apply, "OnClick")
                F.RunTimers()
                local was = Sets.List()[#Sets.List()]
                expect(o.borderColor == "aabbcc" and o.reach == reach and not w:IsShown(),
                    "a set applied from its window doesn't take the parts ticked alone, or the window stays: border "
                    .. tostring(o.borderColor) .. ", reach " .. tostring(o.reach))
                expect(was.backup and was.name == string.format(L.SET_BEFORE, "Tank"),
                    "a set applied from its window keeps nothing of the settings as they were")
                o.borderColor = color
                -- the settings as they were, picked: applied, shared or deleted, never changed
                radio(string.format(L.SET_BEFORE, "Tank")).pick()
                expect(litText() == "a--sd", "the settings as they were can be changed from the page: " .. litText())
                item.pick()
                -- no part ticked: nothing to apply
                F.RunScript(apply, "OnClick")
                for _, part in ipairs(Sets.PARTS) do
                    w.Boxes[part]:SetChecked(false)
                    F.RunScript(w.Boxes[part], "OnClick")
                end
                expect(not w.Apply:IsEnabled(), "« Appliquer » stays lit with no part ticked")
                w:Hide()
                -- renamed; brought up to date and deleted, each asked first, from the page's buttons
                F.RunScript(rename, "OnClick")
                if F.popup then
                    F.popup.data.done("Raid")
                    F.popup = nil
                end
                expect(kept.name == "Raid" and radio("Raid") and radio("Raid").selected,
                    "a set isn't renamed from the page, or isn't picked under its new name")
                o.reach = 66
                F.RunScript(update, "OnClick")
                local before = kept.settings.options.reach
                F.AcceptPopup()
                expect(before == 77 and kept.settings.options.reach == 66,
                    "a set isn't brought up to date from the page, or without being asked first")
                o.reach = reach
                F.RunScript(delete, "OnClick")
                local still = Sets.List()[1] == kept
                F.AcceptPopup()
                expect(still and Sets.List()[1] ~= kept and litText() == "-----",
                    "a set isn't deleted from the page, or without being asked first, or stays picked: " .. litText())
                -- another character's own settings: applied and shared, nothing else done to them from here
                radio(string.format(L.SET_OF, "Thrall")).pick()
                expect(litText() == "a--s-", "another character's own settings can be changed from here: " .. litText())
                F.RunScript(apply, "OnClick")
                expect(w:IsShown() and w.Title:GetText() == string.format(L.SET_OF, "Thrall"),
                    "another character's own settings don't open as a set does")
                w:Hide()
            end
            -- Ikar 2026-11-19: "let's do a proper export and import". A set shared is its text, selected in the text
            -- window, to copy. A text pasted in the import's window: what is wrong with it is said there, the window
            -- staying; one that reads is kept as a set under a name asked for, and opens, nothing applied
            local import = sub(L.SET_FROM_TEXT)
            expect(import ~= nil, "the presets' page has no row to import a set's text")
            if import then
                local function named(name)
                    for _, set in ipairs(Sets.List()) do
                        if set.name == name then
                            return set
                        end
                    end
                end
                local text, reach = Sets.Export(Sets.Capture()), o.reach
                Sets.Save("À partager")
                radio("À partager").pick()
                F.RunScript(apply, "OnClick")
                local w = KaLiHUDSetWindow
                local warned = w.Warn:IsShown()
                w:Hide()
                F.RunScript(share, "OnClick")
                local t = KaLiHUDSetImport
                expect(t ~= nil and t:IsShown() and t.Box:GetText():find("^KaLiHUD:1:") ~= nil and t.Box.highlighted
                    and F.focus == t.Box and not t.Take:IsShown(),
                    "a set shared from its window doesn't show its text to copy, selected")
                if t then
                    t:Hide()
                end
                w:Hide()
                -- (Ikar 2026-11-19, of the export: "it is quite convoluted") the settings as they are, from the page
                -- in one click, kept as no set; their text whole and selected whatever is typed in it; Ctrl+C shuts
                -- it, a line saying it's copied
                local share = sub(L.SET_SHARE_NAME)
                local kept = #Sets.List()
                if share then
                    F.RunScript(share.Button, "OnClick")
                end
                local shared = t and t.Box:GetText()
                expect(share and t and t:IsShown() and Sets.Read(shared) and #Sets.List() == kept
                    and t.Title:GetText() == string.format(L.SET_SHARE_TITLE, L.SET_CURRENT),
                    "the page doesn't share the settings as they are in one click")
                if t and t:IsShown() then
                    t.Box:SetText(shared .. "x")
                    F.RunScript(t.Box, "OnTextChanged", true)
                    expect(t.Box:GetText() == shared and t.Box.highlighted, "a shared text can be typed over")
                    F.ctrl = true
                    F.RunScript(t.Box, "OnKeyUp", "C")
                    F.ctrl = nil
                    expect(not t:IsShown() and printed(L.SET_COPIED), "a shared text copied doesn't shut its window")
                end
                -- /kh export, the same; /kh import, the import's window
                slash("export")
                expect(t and t:IsShown() and Sets.Read(t.Box:GetText()), "/kh export doesn't share the settings")
                slash("import")
                expect(t and t:IsShown() and t.Take:IsShown() and t.Box:GetText() == "",
                    "/kh import doesn't open the import's window, empty")
                if t then
                    t:Hide()
                end
                F.RunScript(import.Button, "OnClick")
                t = KaLiHUDSetImport
                expect(t ~= nil and t:IsShown(), "the page's import row doesn't open the import's window")
                if t then
                    local before = #Sets.List()
                    t.Box:SetText("n'importe quoi")
                    F.RunScript(t.Take, "OnClick")
                    expect(t:IsShown() and t.Wrong:GetText() == L.SET_IMPORT_not and #Sets.List() == before,
                        "a text that isn't a set's isn't refused with a word, the import's window staying")
                    t.Box:SetText(text)
                    F.popup = nil
                    F.RunScript(t.Take, "OnClick")
                    local asked = F.popup and F.popup.which == "KALIHUD_SET_NAME"
                    if asked then
                        F.popup.data.done("De Kael")
                        F.popup = nil
                    end
                    local got = named("De Kael")
                    expect(asked and got and not t:IsShown() and w:IsShown() and ns.SetWindow.Shown().set == got
                        and o.reach == reach,
                        "a set's text pasted isn't kept as a set under a name asked for and opened, nothing applied")
                    -- from someone else's text, its macros' commands run on a click: its window says so, that of a
                    -- set of the player's own doesn't
                    expect(got and got.imported == true and w.Warn:IsShown() and not warned,
                        "a set from a text that holds macros doesn't say their commands run on a click, or one of the "
                        .. "player's own does")
                    w:Hide()
                end
            end
            ns.db.chars["Royaume-Thrall"] = nil
            -- this character on settings of its own, by the page's box; and back
            own.Check:SetChecked(true)
            F.RunScript(own.Check, "OnClick")
            F.RunTimers()
            local onOwn = Sets.Own()
            -- (back on the account's replaces all it has set: asked first, the box ticked until the answer)
            own.Check:SetChecked(false)
            F.popup = nil
            F.RunScript(own.Check, "OnClick")
            F.RunTimers()
            expect(F.popup ~= nil and F.popup.which == "KALIHUD_ASK" and Sets.Own() and own.Check:GetChecked() == true,
                "the page's box takes a character off its own settings without asking first")
            if F.popup then
                F.AcceptPopup()
            end
            F.RunTimers()
            expect(onOwn and not Sets.Own() and own.Check:GetChecked() == false,
                "the page's box doesn't put the character on settings of its own, and back")
            while #Sets.List() > 0 do
                Sets.Delete(Sets.List()[1])
            end
        end
    end
    SettingsPanel:Hide()
    -- In a fight the game's options don't open from an addon: the game's line says why, and no list of commands.
    F.combat = true
    F.printed = {}
    local refused = #F.uiErrors
    slash("")
    slash("options")
    expect(not SettingsPanel:IsShown() and #F.uiErrors == refused + 2 and not printed(L.HELP[1]),
        "/kh in a fight opens the options, or lists the commands under the game's refusal")
    F.combat = false
end

-- The info bar off: what the hub had gathered from other addons on it, or in a folder on it, shows nowhere. Their
-- buttons go back to their addons, on the map: LibDBIcon's as other addons' own. Put away, they were out of reach.
do
    local RAW = "AutoBiographerMinimapButton"
    local saved = { Spoken = ns.DeepCopy(ns.db.items.Spoken), [RAW] = ns.DeepCopy(ns.db.items[RAW]) }
    local function settle()
        ns.ApplyAll()
        F.RunTimers()
    end
    for _, where in ipairs({ "bar", "folder" }) do
        if where == "bar" then
            Hub.Insert("Spoken", "right")
            Hub.Insert(RAW, "right")
        else
            local folder = ns.Folders.Default() or ns.Folders.List()[1]
            Hub.Insert(folder, "right")
            Hub.InsertIntoFolder("Spoken", folder)
            Hub.InsertIntoFolder(RAW, folder)
        end
        ns.db.options.infoBar = true
        settle()
        expect(F.dbiButton:GetParent() ~= Minimap and F.rawButton:GetParent() ~= Minimap,
            "setup: with the bar on, another addon's buttons aren't gathered from the map (" .. where .. ")")
        ns.db.options.infoBar = false
        settle()
        expect(F.dbiButton:GetParent() == Minimap and F.rawButton:GetParent() == Minimap and F.rawButton:GetAlpha() == 1
            and F.rawButton:IsMouseEnabled(),
            "the info bar off, another addon's button gathered on it (" .. where .. ") stays put away, out of reach")
        ns.db.options.infoBar = true
        settle()
        expect(F.dbiButton:GetParent() ~= Minimap and F.rawButton:GetParent() ~= Minimap,
            "the info bar back on, the buttons aren't gathered again (" .. where .. ")")
    end
    -- One the player hid in the hub stays away, bar or no bar; one set round the map never left it.
    Hub.SetShown("Spoken", false)
    ns.db.options.infoBar = false
    settle()
    expect(F.dbiButton:GetParent() ~= Minimap, "an object hidden in the hub has its map button back with the bar off")
    ns.db.options.infoBar = true
    for name, item in pairs(saved) do
        ns.db.items[name] = item
    end
    Hub.Changed()
    settle()
end

-- The mail on the bar keeps its place with no mail, empty: the items beside it stand still as mail comes and goes
-- (Ikar's rule: outside Edit Mode nothing moves on a game event).
do
    local MAIL = ns.Natives.NAME.MAIL
    local saved, hasNewMail = ns.DeepCopy(ns.db.items[MAIL]), HasNewMail
    local envelope = MinimapCluster.IndicatorFrame.MailFrame
    Hub.Insert(MAIL, "right", 1)
    ns.ApplyAll()
    F.RunTimers()
    local function places()
        local out = {}
        for _, e in ipairs(Hub.Side("right")) do
            local at = InfoBar.Placed(e.name)
            out[#out + 1] = e.name .. "@" .. (at and string.format("%.1f", at.x) or "-")
        end
        return table.concat(out, " ")
    end
    local withMail = places()
    expect(InfoBar.Placed(MAIL) ~= nil and MinimapCluster.IndicatorFrame:GetAlpha() > 0, "setup: the mail isn't on the bar, shown")
    HasNewMail = function()
        return false
    end
    envelope:Hide()
    F.Fire("UPDATE_PENDING_MAIL")
    F.RunTimers()
    expect(places() == withMail, "the mail read, the bar's items move: " .. withMail .. " > " .. places())
    -- nor at the next full layout, whatever asks for it
    ns.ApplyAll()
    F.RunTimers()
    expect(places() == withMail, "the mail read, the bar's items move at the next layout: " .. withMail .. " > " .. places())
    expect(MinimapCluster.IndicatorFrame:GetAlpha() == 0, "with no mail the envelope's frame still shows on the bar")
    HasNewMail = hasNewMail
    envelope:Show()
    F.Fire("UPDATE_PENDING_MAIL")
    F.RunTimers()
    expect(places() == withMail and MinimapCluster.IndicatorFrame:GetAlpha() > 0, "mail again, it doesn't show where it was")
    ns.db.items[MAIL] = saved
    Hub.Changed()
    ns.ApplyAll()
    F.RunTimers()
end

-- A colour chosen with the picker has its line in the list at once, chosen (it had none until a reload).
do
    F.EnterEditMode()
    F.RunTimers()
    ns.EditFrame.Select("borders")
    local dropdown
    for _, f in ipairs(KaLiHUDEditModeDialog.rows) do
        if f.row.key == "borderColor" then
            dropdown = f.Dropdown
        end
    end
    local function chosen()
        for _, radio in ipairs(dropdown and F.MenuRadios(dropdown) or {}) do
            if radio.selected then
                return radio.text
            end
        end
    end
    local before = chosen()
    ns.Border.PickColor("borderColor", ns.EditPanel.Changed)
    F.PickColor(0.11, 0.22, 0.33)
    F.RunTimers()
    expect(before ~= nil and chosen() == L.COLOR_CUSTOM, "a colour chosen with the picker has no line in the list: "
        .. tostring(before) .. " > " .. tostring(chosen()))
    ns.EditPanel.Revert()
    F.RunTimers()
    expect(chosen() == before, "setup: the colour put back")
    F.ExitEditMode()
    F.RunTimers()
end

-- Blizzard's frames are hooked, never their scripts replaced; a hook run every frame keeps its first error and stops.
do
    local diel, calendar = MinimapCluster.DielFrame, GameTimeFrame
    expect(diel.scripts.OnEnter == nil and diel.scripts.OnLeave == nil and #(diel.hooks.OnEnter or {}) >= 1
        and #(diel.hooks.OnLeave or {}) >= 1, "the day and night frame's own scripts are set by the addon, not hooked")
    local addHints, errors = ns.HubMenus.AddHints, ns.Count(KaLiHUDDevDB.errors)
    local calls = 0
    ns.HubMenus.AddHints = function()
        calls = calls + 1
        error("broken on purpose")
    end
    GameTooltip:SetOwner(calendar, "ANCHOR_LEFT")
    for _ = 1, 5 do
        F.RunScript(calendar, "OnUpdate")
    end
    ns.HubMenus.AddHints = addHints
    GameTooltip:Hide()
    local kept
    for msg, e in pairs(KaLiHUDDevDB.errors) do
        if tostring(msg):find("broken on purpose", 1, true) then
            kept = e
            KaLiHUDDevDB.errors[msg] = nil
        end
    end
    expect(calls == 1 and kept and kept.count == 1 and ns.Count(KaLiHUDDevDB.errors) == errors,
        "an error in the calendar's every-frame hook comes back every frame: " .. calls .. " times")
    for i = #F.errors, 1, -1 do
        if tostring(F.errors[i]):find("broken on purpose", 1, true) then
            table.remove(F.errors, i)
        end
    end
end

-- The live plate in Edit Mode, every frame: an error there is kept once and stops the following; the next time Edit
-- Mode opens tries again.
do
    F.EnterEditMode()
    F.RunTimers()
    local moved, errors = Plate.Moved, ns.Count(KaLiHUDDevDB.errors)
    local calls = 0
    Plate.Moved = function()
        calls = calls + 1
        error("broken on purpose")
    end
    for _ = 1, 5 do
        F.RunScript(Plate.frame, "OnUpdate", 0.016)
    end
    Plate.Moved = moved
    local kept
    for msg, e in pairs(KaLiHUDDevDB.errors) do
        if tostring(msg):find("broken on purpose", 1, true) then
            kept = e
            KaLiHUDDevDB.errors[msg] = nil
        end
    end
    expect(calls == 1 and kept and kept.count == 1 and Plate.frame:GetScript("OnUpdate") == nil
        and ns.Count(KaLiHUDDevDB.errors) == errors, "an error in the live plate comes back every frame: " .. calls .. " times")
    for i = #F.errors, 1, -1 do
        if tostring(F.errors[i]):find("broken on purpose", 1, true) then
            table.remove(F.errors, i)
        end
    end
    F.ExitEditMode()
    F.RunTimers()
    F.EnterEditMode()
    F.RunTimers()
    expect(Plate.frame:GetScript("OnUpdate") ~= nil, "after an error, the live plate doesn't follow again the next time Edit Mode opens")
    F.ExitEditMode()
    F.RunTimers()
end

-- A window's fold on its way, every frame: an error there is kept once, the fold is where it was going at once, and
-- nothing runs every frame any more.
do
    local o = ns.db.options
    local was = { o.chatFolded, o.windowFold, o.foldAnim }
    o.windowFold, o.foldAnim, o.chatFolded = true, true, false
    ns.ApplyAll()
    F.RunTimers()
    local running = {}
    for _, f in ipairs(F.frames) do
        running[f] = f.scripts.OnUpdate ~= nil
    end
    o.chatFolded = true
    ns.ApplyAll()
    local driver
    for _, f in ipairs(F.frames) do
        if f.scripts.OnUpdate ~= nil and not running[f] then
            driver = f
        end
    end
    expect(driver and ns.Windows.Animating(), "setup: a fold doesn't set off")
    if driver then
        local redraw, errors, calls = Plate.Redraw, ns.Count(KaLiHUDDevDB.errors), 0
        Plate.Redraw = function(...)
            calls = calls + 1
            if calls == 1 then
                error("broken on purpose")
            end
            return redraw(...)
        end
        for _ = 1, 3 do
            F.RunScript(driver, "OnUpdate", 0.01)
        end
        F.RunTimers()
        Plate.Redraw = redraw
        local kept
        for msg, e in pairs(KaLiHUDDevDB.errors) do
            if tostring(msg):find("broken on purpose", 1, true) then
                kept = e
                KaLiHUDDevDB.errors[msg] = nil
            end
        end
        expect(kept and kept.count == 1 and not ns.Windows.Animating() and ns.Count(KaLiHUDDevDB.errors) == errors
            and not taken("ChatFrame1"), "an error in a fold on its way comes back every frame, or leaves the fold half way")
        for i = #F.errors, 1, -1 do
            if tostring(F.errors[i]):find("broken on purpose", 1, true) then
                table.remove(F.errors, i)
            end
        end
    end
    o.chatFolded, o.windowFold, o.foldAnim = was[1], was[2], was[3]
    ns.ApplyAll()
    F.RunTimers()
    if ns.Windows.Animating() then
        run(ns.Windows.Step, nil, 10)
        F.RunTimers()
    end
end

-- A folded window comes back as see-through as it was, FlareUI's skin round the chat too: not at full strength,
-- whatever the player had set them to.
do
    local o = ns.db.options
    local was = { o.windowFold, o.foldAnim, o.chatFolded, o.meterFolded }
    local chatLeft, chatBottom = ChatFrame1.left, ChatFrame1.top - ChatFrame1.height
    o.windowFold, o.foldAnim, o.chatFolded, o.meterFolded = true, false, false, false
    place(ChatFrame1, 100, 40)
    ns.ApplyAll()
    F.RunTimers()
    ChatFrame1.FlareUI_Skin:SetAlpha(0.6)
    DamageMeterSessionWindow1:SetAlpha(0.7)
    ns.Windows.Toggle("ChatFrame1")
    ns.Windows.Toggle("DamageMeter")
    F.RunTimers()
    expect(ChatFrame1.FlareUI_Skin:GetAlpha() == 0 and DamageMeterSessionWindow1:GetAlpha() == 0,
        "setup: folded, the chat's skin or the damage meter's window still shows")
    ns.Windows.Toggle("ChatFrame1")
    ns.Windows.Toggle("DamageMeter")
    F.RunTimers()
    expect(ChatFrame1.FlareUI_Skin:GetAlpha() == 0.6 and DamageMeterSessionWindow1:GetAlpha() == 0.7,
        "unfolded, the chat's skin or the damage meter's window isn't as see-through as it was: "
        .. tostring(ChatFrame1.FlareUI_Skin:GetAlpha()) .. ", " .. tostring(DamageMeterSessionWindow1:GetAlpha()))
    ChatFrame1.FlareUI_Skin:SetAlpha(1)
    DamageMeterSessionWindow1:SetAlpha(1)
    o.windowFold, o.foldAnim, o.chatFolded, o.meterFolded = was[1], was[2], was[3], was[4]
    place(ChatFrame1, chatLeft, chatBottom)
    ns.ApplyAll()
    F.RunTimers()
end

-- The dialog's own controls. The session above sets the options itself and calls ns.ApplyAll, which says the HUD
-- follows its options, not that the dialog's rows and buttons set them: five deliberate breaks of the shared dialog
-- went unseen here on 2026-11-16.
do
    F.EnterEditMode()
    F.RunTimers()
    ns.EditFrame.Select()
    local dialog = KaLiHUDEditModeDialog
    local o = ns.db.options
    local function rowFor(key)
        for _, f in ipairs(dialog.rows) do
            if f.row.key == key then
                return f
            end
        end
    end
    local function bar(id)
        for _, b in ipairs(dialog.sections) do
            if b.section.id == id then
                return b
            end
        end
    end
    local function shown()
        local list = {}
        for _, f in ipairs(dialog.rows) do
            if f:IsShown() and f.row.key then
                list[#list + 1] = f.row.key
            end
        end
        return table.concat(list, ",")
    end
    local function open(id)
        if not rowFor(bar(id).section.rows[1].key):IsShown() then
            F.RunScript(bar(id), "OnClick")
        end
    end
    open("margins")
    expect(shown() == "marginBars,padBars,marginBags,marginStatus", "a section's bar doesn't open it, alone: " .. shown())
    F.RunScript(bar("margins"), "OnClick")
    expect(shown() == "", "a click on the open section's bar doesn't close it: " .. shown())
    open("margins")
    expect(not dialog.Revert:IsEnabled(), "« Annuler les modifications » is lit with nothing to cancel")
    local margin, top = o.marginBars, heightAt(600)
    expect(margin <= 21, "setup: the bars' margin leaves no room to raise it by 11: " .. tostring(margin))
    rowFor("marginBars").Slider:SetValue(margin + 11)
    F.RunTimers()
    expect(o.marginBars == margin + 11 and heightAt(600) > top + 5,
        "a margin set with the dialog's slider isn't kept, or the plate isn't drawn again at once")
    expect(dialog.Revert:IsEnabled(), "« Annuler les modifications » stays grey once something changed")
    open("plate")
    local groove = rowFor("footGroove")
    local had = groove.Button:GetChecked()
    groove.Button:SetChecked(not had)
    F.RunScript(groove.Button, "OnClick")
    F.RunTimers()
    expect(o.footGroove == not had, "a check box of the dialog doesn't set its option")
    -- Each section's own line under its rows (Ikar 2026-11-16: "add 2 button per section, cancel and default, no
    -- warning ... in one line"): its « Annuler » puts back its section's alone, its « Par défaut » sets its section's
    -- alone, neither asking; a status bar's « Annuler » puts back where it was dragged too.
    local function line(id)
        for _, f in ipairs(dialog.rows) do
            if f.section.id == id and f.row.kind == "buttons" then
                return f
            end
        end
    end
    local plateLine, marginsLine = line("plate"), line("margins")
    F.popup = nil
    expect(plateLine and plateLine:IsShown() and marginsLine and not marginsLine:IsShown()
        and plateLine.Revert:GetParent() == plateLine and plateLine.Defaults:GetParent() == plateLine
        and select(5, plateLine:GetPoint(1)) < select(5, groove:GetPoint(1)) and plateLine.Revert:IsEnabled()
        and plateLine.Defaults:IsEnabled(),
        "the open section's « Annuler » and « Par défaut » aren't on one line under its rows, or aren't lit")
    F.RunScript(plateLine.Revert, "OnClick")
    F.RunTimers()
    expect(o.footGroove == had and o.marginBars == margin + 11 and not F.popup and not plateLine.Revert:IsEnabled()
        and dialog.Revert:IsEnabled(),
        "a section's « Annuler » doesn't put back its own alone, or asks first")
    open("margins")
    expect(marginsLine:IsShown() and marginsLine.Revert:IsEnabled() and marginsLine.Defaults:IsEnabled(),
        "the margins' own line isn't shown, or isn't lit once a margin changed")
    F.RunScript(marginsLine.Defaults, "OnClick")
    F.RunTimers()
    expect(o.marginBars == ns.DB.DEFAULTS.marginBars and o.footGroove == had and not F.popup
        and not marginsLine.Defaults:IsEnabled(),
        "a section's « Par défaut » doesn't set its own alone, or asks first")
    open("barLeft")
    local placed = ns.db.statusPlaces.left
    ns.db.statusPlaces.left = { x = 900, y = 500, w = 300 }
    ns.EditPanel.Changed()
    local barLine = line("barLeft")
    expect(barLine:IsShown() and barLine.Revert:IsEnabled(), "a status bar's « Annuler » isn't lit once it was dragged")
    F.RunScript(barLine.Revert, "OnClick")
    F.RunTimers()
    local now = ns.db.statusPlaces.left
    expect((placed == nil and now == nil) or (placed and now and placed.x == now.x and placed.y == now.y),
        "a status bar's « Annuler » doesn't put back where it was dragged")
    -- The window's « Par défaut » asks first, saying what's lost, and only a yes sets the defaults.
    open("margins")
    rowFor("marginBars").Slider:SetValue(margin + 11)
    open("plate")
    groove.Button:SetChecked(not had)
    F.RunScript(groove.Button, "OnClick")
    F.RunTimers()
    F.RunScript(dialog.Defaults, "OnClick")
    F.RunTimers()
    expect(F.popup and F.popup.which == "KALIHUD_EDIT_DEFAULTS"
        and StaticPopupDialogs.KALIHUD_EDIT_DEFAULTS.text == L.EDIT_DEFAULTS_ASK
        and o.marginBars == margin + 11 and o.footGroove == not had,
        "« Par défaut » doesn't ask first, or sets the defaults before the answer")
    F.AcceptPopup()
    F.RunTimers()
    expect(o.marginBars == ns.DB.DEFAULTS.marginBars and o.footGroove == ns.DB.DEFAULTS.footGroove,
        "« Par défaut » leaves what the player changed")
    F.RunScript(dialog.Revert, "OnClick")
    F.RunTimers()
    expect(o.marginBars == margin and o.footGroove == had and near(heightAt(600), top) and not dialog.Revert:IsEnabled(),
        "« Annuler les modifications » doesn't put back what the dialog showed as it opened")
    ns.EditFrame.Deselect()
    F.ExitEditMode()
    F.RunTimers()
end

-- The styles (Data/Presets.lua; Ikar 2026-11-16: "presets ... centered around a minimap style, and a color"; "when
-- selecting and user have custom change, a warning that the changes may be lost should be given. Only for options the
-- preset touch."): each sets the look alone, in values the options take and the lists name, the first the defaults'
-- (Ikar 2026-11-17); picked over nothing the player changed it applies at once, from one style to another too; over a
-- value the player changed it asks first, naming that value alone, and a no leaves all as it was; the style section's
-- « Annuler » puts the look back as the dialog opened on it.
do
    local o = ns.db.options
    local function listed(list, v)
        for _, x in ipairs(list) do
            if x == v then
                return true
            end
        end
    end
    for _, preset in ipairs(ns.PRESETS) do
        local wrong = {}
        for _, key in ipairs(ns.PRESET_KEYS) do
            local v, choices = preset[key], ns.DB.CHOICES[key]
            if type(v) ~= type(ns.DB.DEFAULTS[key]) or (choices and not choices[v])
                or (ns.DB.COLORS[key] and not tostring(v):match("^%x%x%x%x%x%x$")) then
                wrong[#wrong + 1] = key
            end
        end
        expect(#wrong == 0 and L["PRESET_" .. preset.id] and listed(ns.Border.COLORS, preset.borderColor)
            and listed(ns.Border.BG_COLORS, preset.bgColor) and ns.DB.CHOICES.preset[preset.id],
            "the style " .. preset.id .. " sets a value the options don't take, a colour its list doesn't name, or has no"
            .. " name: " .. table.concat(wrong, ","))
    end
    -- Each colour of the two lists named: one without showed its string's key (L gives a missing one back), as the
    -- « Feu - rouge » style's two did until 2026-11-24 (Ikar: "fix the color names for firez they use a code right
    -- now, looks bad").
    local unnamed = {}
    for _, list in ipairs({ ns.Border.COLORS, ns.Border.BG_COLORS }) do
        for _, hex in ipairs(list) do
            if L["COLOR_" .. hex] == "COLOR_" .. hex then
                unnamed[#unnamed + 1] = hex
            end
        end
    end
    expect(#unnamed == 0, "a colour of the border's or the background's list has no name, its code shows instead: "
        .. table.concat(unnamed, ","))
    local notFirst = {}
    for _, key in ipairs(ns.PRESET_KEYS) do
        if ns.DB.DEFAULTS[key] ~= ns.PRESETS[1][key] then
            notFirst[#notFirst + 1] = key
        end
        expect(not ns.DB.RANGES[key], "a style sets a size, a margin or an opacity: " .. key)
    end
    expect(#notFirst == 0 and ns.DB.DEFAULTS.preset == ns.PRESETS[1].id,
        "the defaults aren't the first style's: " .. table.concat(notFirst, ","))
    local opened = ns.DB.Open({ version = ns.DB.VERSION, options = { preset = "nope", minimapRing = "forest" } })
    expect(rawget(opened.options, "preset") == nil and opened.options.minimapRing == "forest",
        "a saved style that can't be isn't dropped, or takes a value with it")

    -- the dialog opens on a look of the player's own: Forest's, its border's colour changed; an opacity of theirs
    for _, key in ipairs(ns.PRESET_KEYS) do
        o[key] = ns.PRESET_BY_ID.forest[key]
    end
    o.preset, o.borderColor, o.borderAlpha = "forest", "c4c8ce", 40
    ns.ApplyAll()
    F.EnterEditMode()
    F.RunTimers()
    ns.EditFrame.Select()
    local dialog = KaLiHUDEditModeDialog
    local function rowFor(key)
        for _, f in ipairs(dialog.rows) do
            if f.row.key == key then
                return f
            end
        end
    end
    local function line(id)
        for _, f in ipairs(dialog.rows) do
            if f.section.id == id and f.row.kind == "buttons" then
                return f
            end
        end
    end
    local function open(id)
        for _, b in ipairs(dialog.sections) do
            if b.section.id == id and not rowFor(b.section.rows[1].key):IsShown() then
                F.RunScript(b, "OnClick")
            end
        end
    end
    local function chosen(key)
        for _, radio in ipairs(F.MenuRadios(rowFor(key).Dropdown)) do
            if radio.selected then
                return radio.text
            end
        end
    end
    local function pick(key, text)
        for _, radio in ipairs(F.MenuRadios(rowFor(key).Dropdown)) do
            if radio.text == text then
                radio.pick()
                F.RunTimers()
                return true
            end
        end
    end
    local function is(id)
        local preset = ns.PRESET_BY_ID[id]
        for _, key in ipairs(ns.PRESET_KEYS) do
            if o[key] ~= preset[key] then
                return false
            end
        end
        return o.preset == id
    end
    local function own()
        return o.preset == "forest" and o.borderColor == "c4c8ce" and o.minimapRing == "forest" and o.foldArt == "forest"
    end
    open("style")
    F.popup = nil
    expect(rowFor("preset"):IsShown() and chosen("preset") == L.PRESET_CUSTOM,
        "the style section doesn't show a look of the player's own as theirs: " .. tostring(chosen("preset")))
    pick("preset", L.PRESET_rune)
    expect(F.popup and F.popup.which == "KALIHUD_PRESET" and F.popup.text == L.PRESET_rune
        and F.popup.text2 == L.OPT_BORDER_COLOR and own(),
        "a style over a colour the player changed doesn't ask first naming it alone, or applies before the answer: "
        .. tostring(F.popup and F.popup.text2))
    F.AcceptPopup()
    F.RunTimers()
    expect(is("rune") and o.borderAlpha == 40 and chosen("preset") == L.PRESET_rune and chosen("foldArt") == L.FOLD_ART_rune,
        "a yes doesn't apply the style, or it changes what it doesn't set")
    pick("preset", L.PRESET_golden)
    expect(is("golden") and not F.popup, "going from one style to another asks, or doesn't apply it")
    open("borders")
    pick("bgStyle", L.BGS_leather)
    open("style")
    pick("preset", L.PRESET_astronomy)
    expect(F.popup and F.popup.text2 == L.OPT_BG_STYLE, "a style over a material the player chose doesn't ask first")
    F.popup = nil
    expect(o.bgStyle == "leather" and o.minimapRing == "golden" and chosen("preset") == L.PRESET_CUSTOM,
        "a no applies the style anyway")
    local styleLine = line("style")
    expect(styleLine:IsShown() and styleLine.Revert:IsEnabled(), "the style section's « Annuler » isn't lit")
    F.RunScript(styleLine.Revert, "OnClick")
    F.RunTimers()
    expect(own() and o.bgStyle == ns.PRESET_BY_ID.forest.bgStyle and o.borderAlpha == 40 and not F.popup
        and not styleLine.Revert:IsEnabled(),
        "the style section's « Annuler » doesn't put back the player's own look as the dialog opened on it, or asks")
    F.RunScript(dialog.Defaults, "OnClick")
    F.AcceptPopup()
    F.RunTimers()
    expect(is("blizzard") and chosen("preset") == L.PRESET_blizzard, "« Par défaut » doesn't set the Blizzard style")
    pick("preset", L.PRESET_forest)
    expect(is("forest") and not F.popup, "a style picked over the defaults asks, or isn't applied")
    F.RunScript(dialog.Revert, "OnClick")
    F.RunTimers()
    expect(own() and o.borderAlpha == 40, "« Annuler les modifications » doesn't put back the player's own look")
    for _, key in ipairs(ns.PRESET_KEYS) do
        o[key] = nil
    end
    o.preset, o.borderAlpha = nil, nil
    ns.ApplyAll()
    ns.EditFrame.Deselect()
    F.ExitEditMode()
    F.RunTimers()
end

-- ---------- The review of 2026-11-17: its defects, each as it showed ----------
do
    local Folders, Macros, Menus, Collect = ns.Folders, ns.Macros, ns.HubMenus, ns.Collect
    -- An error made on purpose, taken out of the logs: how many times it was kept.
    local function purged(text)
        local count = 0
        for msg, e in pairs(KaLiHUDDevDB.errors) do
            if tostring(msg):find(text, 1, true) then
                count = count + (e.count or 0)
                KaLiHUDDevDB.errors[msg] = nil
            end
        end
        for i = #F.errors, 1, -1 do
            if tostring(F.errors[i]):find(text, 1, true) then
                table.remove(F.errors, i)
            end
        end
        return count
    end
    -- The bar's items as drawn: how many lie over the next one or past the screen's ends.
    local function crowded()
        local list, W = {}, UIParent:GetWidth()
        for _, e in ipairs(Hub.Entries()) do
            local p = InfoBar.Placed(e.name)
            if p and p.x then
                list[#list + 1] = { x0 = p.x - p.w / 2, x1 = p.x + p.w / 2 }
            end
        end
        table.sort(list, function(a, b)
            return a.x0 < b.x0
        end)
        local n = 0
        for i, a in ipairs(list) do
            local b = list[i + 1]
            if a.x0 < -0.01 or a.x1 > W + 0.01 or b and a.x1 > b.x0 + 0.01 then
                n = n + 1
            end
        end
        return n
    end
    local function unfittedCount()
        return ns.Count(InfoBar.Unfitted())
    end

    if F.combat then
        F.LeaveCombat()
    end
    ns.db.options.infoBar = true
    Hub.SetLocked(true)
    ns.ApplyAll()
    F.RunTimers()
    expect(crowded() == 0 and unfittedCount() == 0 and ns.Minimap.Owned(),
        "setup: the bar's items fit as the session left them, the map ours: " .. crowded() .. ", " .. unfittedCount())

    -- Another addon's launcher, with a click of its own, and its plain readout, with none; a folder of the player's.
    local clicks = {}
    local LAUNCHER, READOUT = "Lanceur de revue", "Releve de revue"
    F.ldb:NewDataObject(LAUNCHER, { type = "launcher", label = LAUNCHER, icon = 134400, OnClick = function(_, button)
        clicks[#clicks + 1] = button
    end })
    local readout = F.ldb:NewDataObject(READOUT, { type = "data source", label = "Relevé", text = "12" })
    local mine = Folders.Create("Revue")
    Hub.Insert(mine, "right", 1)
    Hub.Insert(READOUT, "right", 1)
    F.RunTimers()
    expect(Buttons.Get(LAUNCHER) ~= nil and InfoBar.Placed(READOUT) ~= nil and InfoBar.Placed(mine) ~= nil,
        "setup: another addon's launcher and readout, and a folder at the bar's right end")

    -- A right-click, the padlock shut: the launcher's is its addon's, untouched; the readout has none of its own, so its
    -- hub menu opens (it did nothing, its settings out of reach).
    F.lastMenu = nil
    click(LAUNCHER, "RightButton")
    expect(clicks[#clicks] == "RightButton" and F.lastMenu == nil, "shut, another addon's launcher's right-click isn't its own")
    F.RunScript(Buttons.Get(LAUNCHER), "OnEnter")
    expect(not has(L.HINT_HUB_MENU), "shut, another addon's launcher's tooltip promises the hub menu")
    F.RunScript(Buttons.Get(LAUNCHER), "OnLeave")
    click(READOUT, "RightButton")
    expect(F.lastMenu ~= nil and F.MenuItem(L.HUB_POSITION) ~= nil and not Menus.Theirs(Hub.Entry(READOUT)),
        "shut, a right-click on another addon's plain readout doesn't open its hub menu")

    -- Places that hold: a text that grows widens its place once, the items after it moving that once; one that shrinks
    -- leaves everything where it stands, no layout at all; the player arranging the bar gives each its own width again.
    do
        local neighbour
        for _, name in ipairs(sideList("right")) do
            if name ~= READOUT and InfoBar.Placed(name) then
                neighbour = name
                break
            end
        end
        local function at()
            return neighbour and InfoBar.Placed(neighbour) and InfoBar.Placed(neighbour).x
        end
        local x0, w0 = at(), InfoBar.Placed(READOUT).w
        local function width()
            return InfoBar.Placed(READOUT) and InfoBar.Placed(READOUT).w
        end
        readout.text = "123456"
        F.RunTimers()
        local x1, w1 = at(), width()
        expect(x0 and x1 and w1 > w0 and x1 < x0, "a text that grows doesn't widen its place: " .. tostring(w0) .. " > " .. tostring(w1))
        local version = InfoBar.Version()
        readout.text = "12"
        F.RunTimers()
        expect(width() == w1 and at() == x1 and InfoBar.Version() == version
            and tostring(Buttons.Get(READOUT).Text:GetText()):find("12", 1, true)
            and not tostring(Buttons.Get(READOUT).Text:GetText()):find("123456", 1, true),
            "a text that shrinks moves what's laid out after it, or isn't drawn: " .. tostring(width()))
        -- its place wide again, for the next way of arranging the bar
        local function swell()
            readout.text = "123456"
            F.RunTimers()
            readout.text = "12"
            F.RunTimers()
            return width() == w1
        end
        Hub.SetLocked(false)
        F.RunTimers()
        Hub.SetLocked(true)
        F.RunTimers()
        expect(width() == w0 and near(at(), x0), "the padlock turned doesn't give each item its own width again: " .. tostring(width()))
        expect(swell(), "setup: its place wide again")
        ns.ApplyAll()
        F.RunTimers()
        expect(width() == w0, "a setting changed doesn't give each item its own width again: " .. tostring(width()))
        expect(swell(), "setup: its place wide again")
        ns.History.Do("move", READOUT, Hub.Insert, READOUT, "right", 2)
        F.RunTimers()
        expect(width() == w0, "an element the player moved doesn't give each item its own width again: " .. tostring(width()))
        expect(swell(), "setup: its place wide again")
        ns.History.Undo()
        F.RunTimers()
        expect(width() == w0 and sideList("right")[1] == READOUT,
            "an undo doesn't give each item its own width again: " .. tostring(width()))
    end
    -- A choice of the player's from an element's menu (the bags by their free slots, or their used ones out of all):
    -- its place its own width again, not the wider one's it had.
    do
        local function bags()
            return InfoBar.Placed("KaLiHUD_Bags") and InfoBar.Placed("KaLiHUD_Bags").w
        end
        local function toggle()
            click("KaLiHUD_Bags", "RightButton")
            item = F.MenuItem(L.BAGS_SHOW_FREE)
            if item then
                run(item.choose)
            end
            F.RunTimers()
        end
        local wide = bags()
        expect(wide and ns.db.options.bagsFree == false, "setup: the bags on the bar, their used slots out of all")
        toggle()
        local narrow = bags()
        expect(wide and narrow and ns.db.options.bagsFree == true and narrow < wide,
            "a setting changed from an element's menu leaves its place as wide as it was: " .. tostring(wide) .. " > " .. tostring(narrow))
        toggle()
        expect(ns.db.options.bagsFree == false and bags() == wide, "setup: the bags by their used slots again")
    end
    -- The zone keeps to its own width, its name centred under the map: after a longer name, a shorter one has no wider
    -- place.
    do
        local zone
        for _, e in ipairs(Hub.Entries()) do
            if Hub.IsFixed(e.name) then
                zone = e.name
            end
        end
        local zb, was = zone and Buttons.Get(zone), F.zoneText
        F.zoneText = "Les Hautes-terres d'Arathi les plus lointaines"
        F.Fire("ZONE_CHANGED")
        F.RunTimers()
        local long = zone and InfoBar.Placed(zone) and InfoBar.Placed(zone).w
        F.zoneText = "Orgrimmar"
        F.Fire("ZONE_CHANGED")
        F.RunTimers()
        local p = zone and InfoBar.Placed(zone)
        expect(zb and long and p and p.w < long and near(p.w, zb:GetWidth()),
            "the zone, its name shorter, keeps the longer one's place: its name no longer under the map's centre")
        F.zoneText = was
        F.Fire("ZONE_CHANGED")
        F.RunTimers()
    end
    -- Where an element goes from its menu: into a folder, or a new one. The bar's sides, the map's pockets and ring and
    -- « Masqué » are no longer listed there (Ikar 2026-11-17: "remove all the send to, except folders. They are noisy
    -- options").
    do
        click("KaLiHUD_Clock", "RightButton")
        local place = F.MenuItem(L.HUB_POSITION)
        local folders, others = 0, 0
        for _, it in ipairs(place and place.items or {}) do
            if it.kind == "radio" and tostring(it.text):find("«", 1, true) then
                folders = folders + 1
            elseif it.text ~= L.FOLDER_CREATE then
                others = others + 1
            end
        end
        -- (every folder but the locked ones, UI/Hub/Seeds.lua, which nothing goes into)
        local open = 0
        for _, id in ipairs(Folders.List()) do
            open = open + (Folders.CanHold(id, "KaLiHUD_Clock") and 1 or 0)
        end
        expect(place and folders == open and open < #Folders.List() and others == 0 and F.MenuItem(L.FOLDER_CREATE, place) ~= nil
            and F.MenuItem(string.format(L.SIDE_folder, Folders.Get(mine).name), place) ~= nil,
            "an element's menu lists other places than the folders to send it to: " .. folders .. " folders, " .. others .. " others")
        item = F.MenuItem(string.format(L.SIDE_folder, Folders.Get(mine).name), place)
        if item then
            run(item.choose)
            F.RunTimers()
        end
        expect(Hub.Entry("KaLiHUD_Clock").side == "folder" and Hub.Entry("KaLiHUD_Clock").folder == mine,
            "a folder picked in an element's menu doesn't take it")
        ns.History.Undo()
        F.RunTimers()
        expect(Hub.Entry("KaLiHUD_Clock").side ~= "folder", "setup: the clock back where it stood")
    end

    -- An open folder's members changing together: its list laid out once, not once for each.
    local stats = Folders.ByRole("stats")
    expect(stats ~= nil, "setup: the attributes' folder")
    if stats then
        Folders.SetOpen(stats, true)
        F.RunTimers()
        local layout, layouts = Folders.Layout, 0
        Folders.Layout = function(...)
            layouts = layouts + 1
            return layout(...)
        end
        for i = 1, 5 do
            F.attributes[i] = F.attributes[i] + 7
        end
        F.Fire("UNIT_STATS", "player")
        F.RunTimers()
        Folders.Layout = layout
        local strength = Buttons.Get("KaLiHUD_Attr_STRENGTH")
        expect(layouts == 1 and strength and F.Shows(strength):find(tostring(F.attributes[1]), 1, true),
            "five members of an open folder changing lay its list out more than once, or aren't drawn: " .. layouts)
        for i = 1, 5 do
            F.attributes[i] = F.attributes[i] - 7
        end
        F.Fire("UNIT_STATS", "player")
        Folders.SetOpen(stats, false)
        F.RunTimers()
    end

    -- What doesn't fit on the bar. Attributes put at its left end, more than it's wide: none drawn over another nor off
    -- the screen; the innermost that aren't folders leave it for the list of « Suite » (made the first time something
    -- didn't fit, earlier in this session), as they read on the bar, their place still the bar's; the folders stay.
    -- (or here, this block run alone: run_tests.py's smoke_session)
    local home = Folders.Overflow() or ns.Seeds.Overflow()
    F.RunTimers()
    expect(home ~= nil and ns.db.seeds.overflow == true, "setup: the folder for what doesn't fit, made earlier in the session")
    if stats and home then
        local moved, was = {}, {}
        for _, e in ipairs(Hub.InFolder(stats)) do
            if e.ours and #moved < 34 then
                moved[#moved + 1] = e.name
                was[e.name] = ns.DeepCopy(ns.db.items[e.name])
            end
        end
        was[NATIVE.CALENDAR] = ns.DeepCopy(ns.db.items[NATIVE.CALENDAR])
        local folders = #Folders.List()
        local function uncrowd()
            for name in pairs(was) do
                ns.db.items[name] = ns.DeepCopy(was[name])
            end
            Hub.Changed()
            F.RunTimers()
        end
        expect(InfoBar.Placed(home) == nil and not Buttons.Get(home):IsShown(),
            "setup: the folder for what doesn't fit, holding nothing, has no button on the bar")
        -- First with no folder for it (the player unticked « Suite »'s box): one of Blizzard's widgets on the bar, at its
        -- left side's inner end, then more than the bar holds. What has no room is drawn nowhere, the widget too, and no
        -- handle is left where it stood; no other folder is made.
        Folders.SetOverflow(home, false)
        Hub.Insert(NATIVE.CALENDAR, "left")
        F.RunTimers()
        expect(Folders.Overflow() == nil and InfoBar.Placed(NATIVE.CALENDAR) ~= nil and GameTimeFrame:GetAlpha() > 0,
            "setup: no folder for what doesn't fit, the calendar on the bar")
        -- « Suite » itself, its box unticked: still no button on the bar while it holds nothing
        expect(InfoBar.Placed(home) == nil and not Buttons.Get(home):IsShown(),
            "« Suite », its box unticked, shows on the bar holding nothing")
        for _, name in ipairs(moved) do
            Hub.Insert(name, "left", 1)
        end
        F.RunTimers()
        do
            local hidden, nowhere = true, true
            for name, where in pairs(InfoBar.Unfitted()) do
                local e, b = Hub.Entry(name), Buttons.Get(name)
                nowhere = nowhere and where == false and InfoBar.Where(name) == nil
                hidden = hidden and (e == nil or e.native or (b ~= nil and not b:IsShown()))
            end
            expect(Folders.Overflow() == nil and #Folders.List() == folders and crowded() == 0 and unfittedCount() > 0
                and nowhere and hidden and InfoBar.Unfitted()[NATIVE.CALENDAR] == false and GameTimeFrame:GetAlpha() == 0,
                "with no folder for it, what doesn't fit is drawn all the same, or a folder is made again: " .. crowded())
            expect(InfoBar.Placed(home) == nil and not Buttons.Get(home):IsShown(),
                "more on the bar than it's wide, « Suite », its box unticked, shows on it holding nothing")
            Hub.SetLocked(false)
            F.RunTimers()
            local handle = Buttons.Handle(NATIVE.CALENDAR)
            expect(not (handle and handle:IsShown()) and GameTimeFrame:GetAlpha() == 0,
                "the padlock open, a widget with no room on the bar keeps a handle where it stood")
            Hub.SetLocked(true)
            F.RunTimers()
        end
        -- Then with its folder again: the same, in its list.
        Folders.SetOverflow(home, true)
        F.RunTimers()
        expect(Folders.Overflow() == home and #Folders.List() == folders,
            "the folder told to take what doesn't fit doesn't, or another is made: " .. tostring((Folders.Overflow())))
        expect(crowded() == 0 and unfittedCount() > 0,
            "more on the bar than it's wide is drawn one over another, or nothing leaves it: " .. crowded() .. ", " .. unfittedCount())
        do
            local panel = Folders.Panel(home)
            expect(InfoBar.Placed(home) ~= nil and Buttons.Get(home):IsShown(),
                "the folder for what doesn't fit doesn't show on the bar while it holds something")
            local leftFolders, kept = 0, true
            for _, e in ipairs(Hub.Side("left")) do
                if e.isFolder then
                    leftFolders = leftFolders + 1
                    kept = kept and InfoBar.Placed(e.name) ~= nil
                end
            end
            expect(leftFolders > 0 and kept, "a folder leaves the bar for want of room")
            -- as they read on the bar: the left side's in its order, the right side's from its inner end
            local expected, saved, parented = {}, true, true
            for _, e in ipairs(Hub.Side("left")) do
                if InfoBar.Unfitted()[e.name] ~= nil then
                    expected[#expected + 1] = e.name
                end
            end
            local right = Hub.Side("right")
            for i = #right, 1, -1 do
                if InfoBar.Unfitted()[right[i].name] ~= nil then
                    expected[#expected + 1] = right[i].name
                end
            end
            local listed = {}
            for _, c in ipairs(panel.cells) do
                listed[#listed + 1] = c.name
            end
            for name, where in pairs(InfoBar.Unfitted()) do
                local e, b = Hub.Entry(name), Buttons.Get(name)
                saved = saved and where == home and InfoBar.Where(name) == home and e ~= nil and Hub.BAR[e.side] == true
                parented = parented and (e == nil or e.native or (b ~= nil and b:GetParent() == panel))
            end
            expect(#expected == unfittedCount() and table.concat(listed, ",") == table.concat(expected, ","),
                "what doesn't fit isn't in its folder's list as it reads on the bar: " .. table.concat(listed, ","))
            expect(saved and parented, "what doesn't fit loses its place on the bar, or isn't in its folder's list")
            expect(InfoBar.Unfitted()[NATIVE.CALENDAR] == home and GameTimeFrame:GetParent() == panel and GameTimeFrame:GetAlpha() > 0,
                "one of Blizzard's widgets with no room on the bar isn't in the folder's list")
            -- its tooltip shut (none over its open list: UI/Hub/Buttons.lua's onEnter)
            F.RunScript(Buttons.Get(home), "OnEnter")
            expect(has(L.FOLDER_OVERFLOW_TIP) and F.tooltip.lines[#F.tooltip.lines] == string.format(L.TYPE_LINE, L.TYPE_FOLDER),
                "the folder for what doesn't fit doesn't say what it's for, or its type isn't its tooltip's last line")
            F.RunScript(Buttons.Get(home), "OnLeave")
            Folders.SetOpen(home, true)
            F.RunTimers()
            local first = Buttons.Get(expected[1])
            expect(panel:IsShown() and first and first:IsVisible(), "the folder for what doesn't fit doesn't open on it")
            Folders.SetOpen(home, false)
            F.RunTimers()
            -- a place growing past what the bar has left: laid out whole, something more put away
            local before = unfittedCount()
            readout.text = string.rep("9", 60)
            F.RunTimers()
            expect(crowded() == 0 and unfittedCount() > before,
                "a place grown past what the bar has left runs over its neighbours: " .. crowded())
            readout.text = "12"
            -- the folder that takes it is any the player says: a box in each folder's menu, as for where new addons land
            F.RunScript(Buttons.Get(mine), "OnClick", "RightButton")
            local box = F.MenuItem(L.FOLDER_OVERFLOW_HERE)
            expect(box and box.kind == "checkbox" and not box.isSelected(), "a folder's menu has no box for what doesn't fit")
            if box then
                run(box.choose)
                F.RunTimers()
                expect(Folders.Overflow() == mine and Folders.Get(home).overflow == nil and InfoBar.Unfitted()[NATIVE.CALENDAR] == mine,
                    "a folder's box ticked doesn't make it the one that takes what doesn't fit")
                Folders.SetOverflow(home, true)
                F.RunTimers()
            end
            -- room again: each back on the bar, the folder's button gone with nothing to hold, but while arranging
            uncrowd()
            expect(unfittedCount() == 0 and crowded() == 0 and InfoBar.Placed(home) == nil and not Buttons.Get(home):IsShown()
                and Folders.Get(home) ~= nil and GameTimeFrame:GetParent() ~= panel,
                "with room again, what didn't fit isn't back on the bar, or its folder's button stays")
            Hub.SetLocked(false)
            F.RunTimers()
            expect(InfoBar.Placed(home) ~= nil and Buttons.Get(home):IsShown(),
                "the padlock open, the folder for what doesn't fit doesn't show to be arranged")
            Hub.SetLocked(true)
            F.RunTimers()
            expect(InfoBar.Placed(home) == nil, "the padlock shut again, the empty folder for what doesn't fit stays")
            -- A folder of the player's told to take what doesn't fit is a folder as any other: on the bar where he put
            -- it, holding nothing too (one that left the bar would look deleted); « Suite », no longer the one, still
            -- shows only while it holds something.
            local spare = Folders.Create("Revue vide")
            Hub.Insert(spare, "left", 1)
            Folders.SetOverflow(spare, true)
            F.RunTimers()
            expect(Folders.Overflow() == spare and #Hub.InFolder(spare) == 0 and unfittedCount() == 0
                and InfoBar.Placed(spare) ~= nil and Buttons.Get(spare):IsShown(),
                "a folder of the player's told to take what doesn't fit, holding nothing, leaves the bar")
            expect(InfoBar.Placed(home) == nil and not Buttons.Get(home):IsShown(),
                "« Suite », another folder told to take what doesn't fit, shows on the bar holding nothing")
            -- « Suite » has no reset (Ikar 2026-11-23: "no reset"): its menu's box makes it the folder that takes what
            -- doesn't fit again.
            Hub.SetLocked(false)
            F.RunTimers()
            F.RunScript(Buttons.Get(home), "OnClick", "RightButton")
            local box = F.MenuItem(L.FOLDER_OVERFLOW_HERE)
            expect(box ~= nil and F.MenuItem(ns.G("RESET", "Réinitialiser")) == nil,
                "« Suite » has a reset, or not the box that makes it take what doesn't fit")
            if box then
                run(box.choose)
                F.RunTimers()
            end
            expect(Folders.Overflow() == home and Folders.Get(spare).overflow == nil,
                "« Suite »'s box doesn't make it the folder that takes what doesn't fit again")
            Hub.SetLocked(true)
            -- the folder told to take what doesn't fit deleted: « Suite » takes it again, nothing left with nowhere to
            -- show by a deletion that said nothing of it
            Folders.SetOverflow(spare, true)
            F.RunTimers()
            expect(Folders.Overflow() == spare and Folders.Get(home).overflow == nil, "setup: the spare folder takes what doesn't fit")
            Folders.Delete(spare)
            F.RunTimers()
            expect(Folders.Get(spare) == nil and Folders.Overflow() == home,
                "the folder told to take what doesn't fit deleted, « Suite » doesn't take it again: " .. tostring((Folders.Overflow())))
            expect(InfoBar.Placed(home) == nil, "« Suite », empty, shows on the bar once the padlock is shut")
        end
    end

    -- A fight that starts with the padlock open: shut for it, while the game still lets the macros' buttons be set, so a
    -- macro's own right-click runs and another addon's is its own; a list open on a click is in the game's auto-hide
    -- where that layout put it; left shut after (Ikar 2026-11-20: "make it lock on combat (no unlock after)"; it opened
    -- again after until then).
    do
        local macro = Macros.Create({ name = "Revue", text = "/danse", right = "/signe" })
        Hub.Insert(macro, "right", 1)
        -- the folder for what doesn't fit nearest the padlock, as it's made: its button, shown while the padlock is
        -- open, goes as it shuts, and what stands after it on that side moves
        if home then
            Hub.Insert(home, "right", 1)
        end
        F.RunTimers()
        local mb, panel, fb = Buttons.Get(macro), Folders.Panel(mine), Buttons.Get(mine)
        Hub.SetLocked(false)
        Folders.SetOpen(mine, true)
        F.RunTimers()
        expect(mb:GetAttribute("*type2") == nil and Menus.RightIsHub(LAUNCHER) and panel:IsShown(),
            "setup: open, the right-clicks are the hub's, the folder's list open")
        local placedAt = table.concat({ panel:GetPoint() }, " ", 4, 5)
        F.EnterCombat()
        F.RunTimers()
        expect(Hub.IsLocked() and mb:GetAttribute("*type2") == "macro",
            "a fight starting with the padlock open leaves it open, a macro's own right-click running nothing")
        F.lastMenu = nil
        local n = #clicks
        click(LAUNCHER, "RightButton")
        expect(#clicks == n + 1 and F.lastMenu == nil,
            "in a fight begun with the padlock open, another addon's right-click isn't its own")
        expect(not (Buttons.Handle(NATIVE.MAIL) and Buttons.Handle(NATIVE.MAIL):IsShown()),
            "in a fight begun with the padlock open, the handles stay over Blizzard's widgets")
        -- the list moved with that layout (the folder for what doesn't fit, shown while open, went): still shut once left
        expect(home == nil or table.concat({ panel:GetPoint() }, " ", 4, 5) ~= placedAt, "setup: the layout moved the list")
        panel.mouseOver = true
        F.AutoHide(0.05)
        panel.mouseOver = nil
        F.AutoHide(0.05)
        F.AutoHide(0.45)
        F.RunTimers()
        expect(not panel:IsShown() and not Folders.IsOpen(mine),
            "a list open as a fight starts with the padlock open isn't shut once left: the game's auto-hide lost it")
        expect(#F.blocked == 0, "shutting the padlock as a fight starts has the game block something: " .. table.concat(F.blocked, ", "))
        F.LeaveCombat()
        F.RunTimers()
        expect(Hub.IsLocked() and mb:GetAttribute("*type2") == "macro", "the padlock shut for a fight opens again after it")
        Macros.Delete(macro)
        F.RunTimers()
    end

    -- One element whose drawing raises an error: kept once, the question mark in its place, the rest of the bar laid out
    -- and following what the player does. It took the whole bar with it.
    do
        local text = setmetatable({}, { __tostring = function()
            error("broken on purpose: an element's text")
        end })
        local BROKEN = "Casse de revue"
        F.ldb:NewDataObject(BROKEN, { type = "data source", label = "Cassé", text = text })
        -- on the bar, the player's doing: a new addon's data source lands in the folder for them
        Hub.Insert(BROKEN, "right")
        F.RunTimers()
        for _ = 1, 3 do
            run(InfoBar.Refresh)
        end
        local count = purged("broken on purpose: an element's text")
        local b = Buttons.Get(BROKEN)
        expect(count == 1 and Buttons.Failed(BROKEN) and b and b:IsShown() and b.Icon._file == (QUESTION_MARK_ICON or 134400)
            and InfoBar.Placed(BROKEN) ~= nil and InfoBar.Placed(READOUT) ~= nil,
            "an element that fails to draw isn't kept once with the question mark in its place: " .. count)
        Hub.Insert(READOUT, "left", 1)
        F.RunTimers()
        local p = InfoBar.Placed(READOUT)
        expect(p and p.x < UIParent:GetWidth() / 2 and crowded() == 0 and purged("broken on purpose: an element's text") == 0,
            "with an element that fails to draw, the bar stops following what the player does")
        Hub.Insert(READOUT, "right", 1)
        F.RunTimers()
    end

    -- Nothing lands on the bar unasked (the review's second round, 9; Ikar 2026-11-17: "Agreed"): a new addon's data
    -- source lands in the folder where new addons land, as its launcher does; with no such folder, on the bar's right
    -- end as before.
    do
        local landing = Folders.Default()
        local NEW = "Releve nouveau"
        expect(landing ~= nil, "setup: a folder where new addons land")
        F.ldb:NewDataObject(NEW, { type = "data source", label = "Nouveau", text = "7" })
        F.RunTimers()
        local e = Hub.Entry(NEW)
        expect(e and e.side == "folder" and e.folder == landing and InfoBar.Placed(NEW) == nil and ns.db.items[NEW] == nil,
            "a new addon's data source lands on the bar, not in the folder where new addons land")
        Folders.SetDefault(landing, false)
        F.RunTimers()
        e = Hub.Entry(NEW)
        expect(e and e.side == "right" and InfoBar.Placed(NEW) ~= nil,
            "with no folder where new addons land, a new addon's data source isn't on the bar's right end")
        Folders.SetDefault(landing, true)
        F.RunTimers()
        e = Hub.Entry(NEW)
        expect(e and e.side == "folder" and e.folder == landing and ns.db.items[NEW] == nil,
            "a data source with no place saved doesn't land in the folder again once one takes new addons")
        -- off the HUD for what follows
        Hub.SetShown(NEW, false)
        F.RunTimers()
    end

    -- A sign that it's done (the review's P4; Ikar 2026-11-17: "Flash is ok, but why the folder open ? I don't see a
    -- case", then "And the flash yes"): an element shown again from the bar's menu is lit once where it stands; back in
    -- a shut folder, the folder's button is, its list left shut; sent into a folder from its own menu, and put back by
    -- an undo, the same. A layout alone lights nothing.
    do
        -- what was lit last, how many frames have lit, and that frame
        local function lit()
            local list = InfoBar.Flashes()
            local last = list[#list]
            return last and last.target, #list, last
        end
        -- its box in the bar's menu, picked
        local function tick(name)
            F.RunScript(InfoBar.frame, "OnMouseUp", "RightButton")
            local box = F.MenuItem(Hub.Label(name))
            if box then
                run(box.choose)
            end
            F.RunTimers()
            return box ~= nil
        end
        local _, n0 = lit()
        Hub.SetShown(READOUT, false)
        F.RunTimers()
        run(InfoBar.Refresh)
        local _, n1 = lit()
        expect(n1 == n0 and InfoBar.Placed(READOUT) == nil, "an element hidden, or the hub laid out, lights something")
        expect(tick(READOUT), "setup: the bar's menu lists another addon's readout")
        local target, n2, frame = lit()
        expect(InfoBar.Placed(READOUT) ~= nil and n2 == n1 + 1 and target == Buttons.Get(READOUT) and frame:IsShown()
            and frame.Fade.plays == 1, "an element shown again from the bar's menu isn't lit once where it stands: " .. n2 - n1)
        -- one of ours back in a shut folder (the player's: nothing in a locked one is hidden): the folder's button
        -- lit, its list left shut
        local clockWas = ns.db.items.KaLiHUD_Clock
        Hub.InsertIntoFolder("KaLiHUD_Clock", mine)
        Folders.SetOpen(mine, false)
        Hub.SetShown("KaLiHUD_Clock", false)
        F.RunTimers()
        expect(tick("KaLiHUD_Clock"), "setup: the bar's menu lists the clock")
        target = lit()
        expect(Hub.Entry("KaLiHUD_Clock").folder == mine and target == Buttons.Get(mine) and not Folders.IsOpen(mine),
            "an element shown again in a shut folder doesn't light the folder's button, or opens its list")
        ns.db.items.KaLiHUD_Clock = clockWas
        Hub.Changed()
        F.RunTimers()
        -- sent into a folder from its own menu, then put back by an undo
        Folders.SetOpen(mine, false)
        F.RunTimers()
        click(READOUT, "RightButton")
        local into = F.MenuItem(string.format(L.SIDE_folder, Folders.Get(mine).name))
        expect(into ~= nil, "setup: an element's menu lists the player's folder")
        if into then
            -- (a flash of its own: the one before lit the same button)
            local function plays()
                local n = 0
                for _, f in ipairs(InfoBar.Flashes()) do
                    n = n + (f.Fade.plays or 0)
                end
                return n
            end
            local played = plays()
            run(into.choose)
            F.RunTimers()
            target = lit()
            expect(Hub.Entry(READOUT).folder == mine and target == Buttons.Get(mine) and not Folders.IsOpen(mine)
                and plays() == played + 1,
                "an element sent into a folder from its menu doesn't light the folder's button, or opens its list")
            ns.History.Undo()
            F.RunTimers()
            target = lit()
            expect(InfoBar.Placed(READOUT) ~= nil and target == Buttons.Get(READOUT),
                "an element put back by an undo isn't lit where it stands")
        end
    end

    -- Its icon, its text or both, for any element with an icon (the review's second round, 10; Ikar 2026-11-17:
    -- "Agreed"), as folders and macros have: « Affichage » in its menu, on the bar. Gold by its text alone, then its
    -- icon alone, its value on hover; another addon's launcher, which comes by its icon alone, with its name, then its
    -- name alone. Saved with its place, one action each; none to choose for an element with no icon.
    do
        local GOLD = "KaLiHUD_Gold"
        local function choose(name, text)
            click(name, "RightButton")
            local look = F.MenuItem(L.LOOK)
            local radio = look and F.MenuItem(text, look)
            if radio then
                run(radio.choose)
            end
            F.RunTimers()
            return radio ~= nil
        end
        local function shows(name)
            local b = Buttons.Get(name)
            return b.Icon:IsShown(), tostring(b.Text:GetText() or ""), InfoBar.Placed(name) and InfoBar.Placed(name).w
        end
        local goldWas = ns.DeepCopy(ns.db.items[GOLD])
        local icon0, text0, w0 = shows(GOLD)
        expect(icon0 and text0 ~= "" and w0 and Hub.ItemLook(GOLD) == nil, "setup: gold on the bar, its icon and its text")
        expect(choose(GOLD, L.LOOK_value), "an element's menu has no « Affichage », or no text alone in it")
        local icon1, text1, w1 = shows(GOLD)
        expect(not icon1 and text1 == text0 and w1 and w1 < w0 and ns.db.items[GOLD].look == "text",
            "an element told to show its text alone keeps its icon: " .. tostring(w1) .. " for " .. tostring(w0))
        expect(choose(GOLD, L.LOOK_icon), "an element's « Affichage » has no icon alone")
        local icon2, text2, w2 = shows(GOLD)
        expect(icon2 and text2 == "" and w2 and w2 < w0 and ns.db.items[GOLD].look == "icon",
            "an element told to show its icon alone keeps its text: " .. text2)
        F.RunScript(Buttons.Get(GOLD), "OnEnter")
        expect(has(L.ITEM_GOLD), "an element shown by its icon alone has no tooltip to say its value")
        F.RunScript(Buttons.Get(GOLD), "OnLeave")
        -- one action each: undone, as it was before
        ns.History.Undo()
        F.RunTimers()
        expect(ns.db.items[GOLD].look == "text" and not select(1, shows(GOLD)), "a look chosen isn't one action, undone as one")
        expect(choose(GOLD, L.LOOK_value_both), "an element's « Affichage » has no icon and text")
        local icon3, text3, w3 = shows(GOLD)
        expect(icon3 and text3 == text0 and w3 == w0 and Hub.ItemLook(GOLD) == nil,
            "an element told to show its icon and its text again doesn't, or keeps a look saved: " .. tostring(w3))
        -- in a list, its folder's style decides: the look is the bar's
        Hub.SetItemLook(GOLD, "icon")
        Hub.InsertIntoFolder(GOLD, mine)
        Folders.Get(mine).style = "text"
        Folders.SetOpen(mine, true)
        F.RunTimers()
        expect(Hub.Entry(GOLD).folder == mine and Hub.ItemLook(GOLD) == "icon" and tostring(Buttons.Get(GOLD).Text:GetText() or "") == text0,
            "an element shown by its icon alone on the bar loses its text in a folder's list of texts")
        Folders.SetOpen(mine, false)
        Folders.Get(mine).style = nil
        ns.db.items[GOLD] = goldWas
        Hub.Changed()
        F.RunTimers()
        -- another addon's launcher on the bar: its icon alone as it comes, its name with it, its name alone (the padlock
        -- open: shut, its right-click is its addon's)
        Hub.SetLocked(false)
        Hub.Insert(LAUNCHER, "right", 1)
        F.RunTimers()
        local li, lt = shows(LAUNCHER)
        expect(li and lt == "" and Hub.DefaultLook(Hub.Object(LAUNCHER)) == "icon", "setup: a launcher on the bar, its icon alone")
        expect(choose(LAUNCHER, L.LOOK_both), "a launcher's « Affichage » has no icon and name")
        li, lt = shows(LAUNCHER)
        expect(li and lt == LAUNCHER and ns.db.items[LAUNCHER].look == "both", "a launcher told to show its name doesn't: " .. lt)
        expect(choose(LAUNCHER, L.LOOK_name), "a launcher's « Affichage » has no name alone")
        li, lt = shows(LAUNCHER)
        expect(not li and lt == LAUNCHER, "a launcher told to show its name alone keeps its icon, or says nothing: " .. lt)
        expect(choose(LAUNCHER, L.LOOK_icon) and ns.db.items[LAUNCHER].look == nil,
            "a launcher back to its icon alone, as it comes, keeps a look saved")
        Hub.InsertIntoFolder(LAUNCHER, Folders.Default())
        Hub.SetLocked(true)
        F.RunTimers()
        -- none to choose with no icon (the experience), for the zone, a folder (its own), one of Blizzard's widgets
        click("KaLiHUD_XP", "RightButton")
        local none = F.MenuItem(L.HUB_POSITION) ~= nil and F.MenuItem(L.LOOK) == nil
        expect(none and not Hub.HasLook("KaLiHUD_XP") and not Hub.HasLook("KaLiHUD_Location") and not Hub.HasLook(mine)
            and not Hub.HasLook(NATIVE.CALENDAR), "« Affichage » is offered to an element with no icon to show or hide")
        F.RunTimers()
    end

    -- An error while something is dragged: kept once, the element back where it stood, the hub no longer dragging; at
    -- the drag's first frame, each later one and the drop alike. It came back every frame and left the hub dragging.
    do
        local function updating()
            local set = {}
            for _, f in ipairs(F.frames) do
                if f.scripts and f.scripts.OnUpdate then
                    set[f] = true
                end
            end
            return set
        end
        local target = Folders.DropTarget
        local function breakIt()
            Folders.DropTarget = function()
                error("broken on purpose: a drag")
            end
        end
        local function mend()
            Folders.DropTarget = target
            if Drag.Current() then
                Drag.Cancel()
            end
            F.RunTimers()
        end
        Hub.SetLocked(false)
        F.RunTimers()
        F.cursorX, F.cursorY = 300, 10
        local was = updating()
        expect(Drag.Begin(READOUT) == true, "setup: the readout dragged")
        local watcher
        for f in pairs(updating()) do
            if not was[f] then
                watcher = f
            end
        end
        breakIt()
        for _ = 1, 3 do
            if watcher then
                pcall(F.RunScript, watcher, "OnUpdate", 0.016)
            end
        end
        local count = purged("broken on purpose: a drag")
        expect(watcher and count == 1 and Drag.Current() == nil and watcher.scripts.OnUpdate == nil,
            "an error while something is dragged comes back every frame, or leaves the hub dragging: " .. count)
        mend()
        expect(InfoBar.Placed(READOUT) ~= nil, "an element whose drag failed isn't back where it stood")
        Drag.Begin(READOUT)
        breakIt()
        run(Drag.Finish)
        count = purged("broken on purpose: a drag")
        expect(count == 1 and Drag.Current() == nil, "a drop whose place can't be read leaves the hub dragging: " .. count)
        mend()
        breakIt()
        local ok, began = pcall(Drag.Begin, READOUT)
        count = purged("broken on purpose: a drag")
        expect(ok and began == false and count == 1 and Drag.Current() == nil,
            "a drag failing at its first frame isn't refused, or leaves the hub dragging: " .. count)
        mend()
        Hub.SetLocked(true)
        F.RunTimers()
    end

    -- A minimap button another addon makes after the login's scans, an addon loaded on demand: taken as it loads.
    do
        local late = CreateFrame("Button", "TardifMinimapButton", Minimap)
        _G.TardifMinimapButton = late
        F.insecure.TardifMinimapButton = true
        late:SetSize(31, 31)
        late:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
        F.RunTimers()
        expect(Collect.Frame("TardifMinimapButton") == nil, "setup: a button made after login, not looked for yet")
        F.Fire("ADDON_LOADED", "Tardif")
        F.RunTimers()
        expect(Collect.Frame("TardifMinimapButton") == late and Hub.Entry("TardifMinimapButton") ~= nil,
            "a minimap button made by an addon loaded after login isn't taken")
    end

    -- A map crowded past what one call can hand back, another addon's pins by the thousand: GetChildren erred "stack
    -- overflow" (Ikar 2026-11-22, eight times since 2026-11-19). A button among them is still taken, and nothing errs.
    do
        local crowded = CreateFrame("Button", "EntasseMinimapButton", Minimap)
        _G.EntasseMinimapButton = crowded
        F.insecure.EntasseMinimapButton = true
        crowded:SetSize(31, 31)
        crowded:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
        -- a button of the same look elsewhere on the screen, which isn't the map's
        local elsewhere = CreateFrame("Button", "AilleursButton", UIParent)
        _G.AilleursButton = elsewhere
        F.insecure.AilleursButton = true
        elsewhere:SetSize(31, 31)
        local pins = {}
        for _ = 1, F.MOST_RESULTS + 1 do
            pins[CreateFrame("Frame", nil, Minimap)] = true
        end
        local function overflows()
            local n = 0
            for msg, e in pairs(KaLiHUDDevDB.errors) do
                if tostring(msg):find("stack overflow", 1, true) then
                    n = n + (e.count or 1)
                end
            end
            return n
        end
        local before = overflows()
        F.Fire("ADDON_LOADED", "Entasse")
        F.RunTimers()
        expect(overflows() == before and Collect.Frame("EntasseMinimapButton") == crowded
            and Collect.Frame("AilleursButton") == nil,
            "on a map crowded past what GetChildren can hand back, the look for buttons errs, misses the map's or takes "
                .. "one elsewhere: " .. overflows() - before .. " overflows")
        -- the pins gone again, from the map and from the game's list of frames, which every event goes through
        for _, list in ipairs({ Minimap.fakeChildren, F.frames }) do
            local n = 0
            for i = 1, #list do
                local f = list[i]
                if not pins[f] then
                    n = n + 1
                    list[n] = f
                end
            end
            for i = #list, n + 1, -1 do
                list[i] = nil
            end
        end
        for f in pairs(pins) do
            f.parent = nil
        end
    end

    -- What KaLi HUD offers other displays (LibDataBroker): what this character has, each under a name a player reads;
    -- never another class's reagents nor a statistic this build doesn't know, which it published all the same, nameless.
    do
        local published, nameless, absent, offered = 0, 0, 0, 0
        for name, obj in pairs(F.ldb.objects) do
            if name:find("^KaLiHUD_") then
                published = published + 1
                local label = obj.label
                if type(label) ~= "string" or label == "" or label:find("^%d+$") then
                    nameless = nameless + 1
                end
            end
        end
        for _, name in ipairs({ "KaLiHUD_Reagent_17020", "KaLiHUD_Reagent_17021", "KaLiHUD_Reagent_6265", "KaLiHUD_Reagent_5140",
            "KaLiHUD_Statistic_1197" }) do
            if Hub.IsOurs(name) and not Hub.Entry(name) then
                absent = absent + 1
                if F.ldb.objects[name] then
                    offered = offered + 1
                end
            end
        end
        expect(published > 40 and F.ldb.objects.KaLiHUD_Gold ~= nil and nameless == 0 and absent > 0 and offered == 0,
            "other displays are offered what this character hasn't, or items with no name: " .. published .. " published, "
                .. nameless .. " nameless, " .. offered .. " of " .. absent .. " it hasn't")
        -- one with no name yet (an item's the game hasn't loaded, a skill just learnt) waits for it
        local LATE = "KaLiHUD_ReviewLate"
        Hub.Add(LATE, { type = "data source", text = "1", category = "system" }, "hidden", 990)
        F.RunTimers()
        expect(Hub.Entry(LATE) ~= nil and F.ldb.objects[LATE] == nil, "an item of ours with no name yet is offered to other displays")
        Hub.Set(LATE, "label", "Revue")
        F.RunTimers()
        expect(F.ldb.objects[LATE] ~= nil and F.ldb.objects[LATE].label == "Revue",
            "an item of ours named after login is never offered to other displays")
        -- nor one this character hasn't, name or not (another class's ammunition)
        local ABSENT = "KaLiHUD_ReviewAbsent"
        Hub.Add(ABSENT, { type = "data source", label = "Absent", text = "1", category = "system", available = function()
            return false
        end }, "hidden", 991)
        F.RunTimers()
        expect(Hub.IsOurs(ABSENT) and Hub.Entry(ABSENT) == nil and F.ldb.objects[ABSENT] == nil,
            "an item of ours this character hasn't is offered to other displays")
    end

    -- The session's blocked actions: the last fifty kept, however many there were, their count going on; and the
    -- errors' count, its colour one table, isn't drawn again by an update that changes nothing, nor the time away.
    do
        local blocked = ns.Session.Blocked
        for i = 1, 60 do
            F.Fire("ADDON_ACTION_BLOCKED", "AutreAddon", "Essai" .. i)
        end
        F.RunTimers()
        expect(#blocked == 50 and blocked[50].what == "Essai60", "every action the game blocked is kept, without end: " .. #blocked)
        F.afk = true
        F.Fire("PLAYER_FLAGS_CHANGED", "player")
        F.RunTimers()
        local update, drawn = InfoBar.Update, {}
        InfoBar.Update = function(name)
            drawn[name] = (drawn[name] or 0) + 1
            return update(name)
        end
        ns.Infos.Update()
        F.RunTimers()
        InfoBar.Update = update
        expect(not drawn.KaLiHUD_Errors, "the errors' count is drawn again by an update that changes nothing")
        expect(not drawn.KaLiHUD_Session, "the time away is drawn again by an update that changes nothing")
        F.afk = false
        F.Fire("PLAYER_FLAGS_CHANGED", "player")
        F.RunTimers()
    end

    -- A folder left open as the session ends: the next login's setup, which raised an error and stopped the hub's start
    -- there (the function it called was declared after it), keeps it open.
    do
        -- left open for the next session's login (the runner's restart check starts from this session's saved file)
        Folders.SetOpen(mine, true)
        F.RunTimers()
        run(Folders.Setup)
        expect(Folders.IsOpen(mine) and Folders.Panel(mine):IsShown(), "a login with a folder left open shuts it")
    end
end

-- Nothing of the addon's was blocked by the game on the way.
expect(#F.blocked == 0, "the game blocked an action of the addon's: " .. table.concat(F.blocked, ", "))

-- ---------- Logout ----------
ns.db.options.copper = true
F.Fire("PLAYER_LOGOUT")
expect(rawget(ns.db.options, "plate") == nil and rawget(ns.db.options, "reach") == nil and rawget(ns.db.options, "copper") == true,
    "the options aren't trimmed to the changes")

for msg in pairs(KaLiHUDDevDB.errors or {}) do
    expect(false, "error during the session: " .. tostring(msg))
end
for _, msg in ipairs(F.errors) do
    expect(false, "error handler: " .. tostring(msg))
end
return failures
