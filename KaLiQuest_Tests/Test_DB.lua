local T = KaLiQuestTests
local ns = KaLiQuestDev.ns
local DB = ns.DB

T.Add("DB", "a first run gets the current version and the defaults", function()
    local db = DB.Load(nil)
    T.Eq(db.version, DB.VERSION, "version")
    T.Eq(#db.groups, 0, "groups")
    T.Eq(db.nextGroupID, 1, "nextGroupID")
    T.Eq(db.open.tracker, true, "tracker open")
    T.Eq(db.open.categories.journal, true, "Journal starts open")
    T.Eq(db.options.autoQuestWatch, false, "auto-tracking off at install, Ikar's ruling")
    T.Eq(db.options.progressFlash, true, "glow on by default")
    T.Eq(db.options.areaHighlight, true, "area highlight on by default, Ikar's defaults of 2026-11-07")
    T.Eq(db.options.findGroup, false, "the find-group eye off by default")
    T.Eq(db.options.width .. "/" .. db.options.height .. "/" .. db.options.opacityCombat, "310/530/50", "width, height, opacity in combat")
    T.Eq(db.options.textSize, nil, "text size follows Edit Mode, whose default is 12")
    T.Eq(db.options.tracker, true, "the addon's tracker on by default")
    T.Eq(db.options.markerStyle, "icons", "markers as icons by default")
    T.Eq(type(db.repeatable), "table", "repeatable quests remembered")
end)

T.Add("DB", "data from a newer addon is left untouched", function()
    local saved = { version = DB.VERSION + 1, groups = { { id = 1, name = "x", quests = { 5, 5 } } } }
    local db, reason = DB.Load(saved)
    T.Eq(db, nil, "refused")
    T.True(reason:find(tostring(DB.VERSION + 1), 1, true), "reason names the version: " .. tostring(reason))
    T.Eq(#saved.groups[1].quests, 2, "not repaired either")
end)

T.Add("DB", "something that isn't a table is refused", function()
    local db, reason = DB.Load("broken")
    T.Eq(db, nil, "refused")
    T.Eq(reason, "not a table", "reason")
end)

T.Add("DB", "an upgrade works on a copy", function()
    local saved = { groups = { { id = 1, name = "A", quests = { 3 } } } }
    local db = DB.Load(saved)
    T.True(db ~= saved, "a new table")
    T.Eq(saved.version, nil, "the original keeps its old version")
    T.Eq(db.groups[1].name, "A", "the layout carries over")
end)

T.Add("DB", "a failing step leaves the original alone", function()
    local step = DB.STEPS[1]
    DB.STEPS[1] = function()
        error("boom")
    end
    local saved = { groups = {} }
    local ok, db, reason = pcall(DB.Load, saved)
    DB.STEPS[1] = step
    T.True(ok, "Load itself doesn't throw")
    T.Eq(db, nil, "refused")
    T.True(tostring(reason):find("step 1", 1, true), "reason names the step: " .. tostring(reason))
    T.Eq(saved.version, nil, "original untouched")
end)

T.Add("DB", "current data loads into a copy, and the saved table is never changed", function()
    local saved = DB.Load(nil)
    saved.groups = { { id = 1, name = "A", quests = { 3, 3 } } }
    saved.nextGroupID = 2
    local again = DB.Load(saved)
    T.True(again ~= saved, "a new table, which the caller stores")
    T.List(again.groups[1].quests, { 3 }, "the copy is repaired")
    T.List(saved.groups[1].quests, { 3, 3 }, "the saved table isn't")
end)

T.Add("DB", "a failing repair leaves the original alone", function()
    local saved = DB.Load(nil)
    saved.options = nil
    local repair = DB.Repair
    DB.Repair = function()
        error("boom")
    end
    local ok, db, reason = pcall(DB.Load, saved)
    DB.Repair = repair
    T.True(ok, "Load itself doesn't throw")
    T.Eq(db, nil, "refused")
    T.True(tostring(reason):find("repair", 1, true), "reason names the repair: " .. tostring(reason))
    T.Eq(saved.options, nil, "original untouched, defaults included")
end)

T.Add("DB", "repair: a NaN or infinite group ID is dropped, not an error", function()
    local saved = DB.Load(nil)
    saved.groups = { { id = 0 / 0, name = "nan", quests = {} }, { id = math.huge, name = "inf", quests = {} }, { id = 3, name = "ok", quests = {} } }
    local db, fixed = DB.Load(saved)
    T.Eq(#db.groups, 1, "only the valid group")
    T.Eq(db.groups[1].name, "ok", "kept")
    T.True(fixed >= 2, "counted")
end)

T.Add("DB", "defaults don't overwrite the player's choices", function()
    local saved = DB.Load(nil)
    saved.options.autoQuestWatch = true
    saved.open.tracker = false
    saved.open.categories.journal = false
    local db = DB.Load(saved)
    T.Eq(db.options.autoQuestWatch, true, "auto-tracking")
    T.Eq(db.open.tracker, false, "collapse-all")
    T.Eq(db.open.categories.journal, false, "a closed Journal")
end)

T.Add("DB", "repair: a quest in two groups stays in the first", function()
    local saved = DB.Load(nil)
    saved.groups = { { id = 1, name = "A", quests = { 7, 8 } }, { id = 2, name = "B", quests = { 8, 9 } } }
    saved.nextGroupID = 3
    local db, fixed = DB.Load(saved)
    T.List(db.groups[1].quests, { 7, 8 }, "first group")
    T.List(db.groups[2].quests, { 9 }, "second group")
    T.Eq(fixed, 1, "one fix")
end)

T.Add("DB", "repair: broken groups go, IDs stay unique, nextGroupID moves past them", function()
    local saved = DB.Load(nil)
    saved.groups = { { id = 4, name = "A", quests = {} }, { id = 4, name = "dup", quests = {} }, "junk", { name = "no id" }, { id = 2, name = "", quests = { "x", 3 } } }
    saved.nextGroupID = 2
    local db = DB.Load(saved)
    T.Eq(#db.groups, 2, "groups kept")
    T.Eq(db.groups[2].name, "?", "an empty name gets a placeholder")
    T.List(db.groups[2].quests, { 3 }, "non-numbers dropped")
    T.Eq(db.nextGroupID, 5, "nextGroupID")
end)

T.Add("DB", "repair: broken filters, Journal order and sizes are dropped, good ones kept", function()
    local saved = DB.Load(nil)
    saved.filters = { state = { ready = true, [5] = true, failed = "yes" }, ["repeat"] = { daily = true } }
    saved.categoryOrder = { "pvp", "world" }
    saved.options.textSize = "big"
    saved.options.height = 500
    local db = DB.Load(saved)
    T.Eq(db.filters.state.ready, true, "a good tick stays")
    T.True(db.filters.state[5] == nil and db.filters.state.failed == nil, "odd keys and values go")
    T.Eq(db.filters["repeat"].daily, true, "another category untouched")
    T.List(db.categoryOrder, { "pvp", "world" }, "a good order stays")
    T.Eq(db.options.textSize, nil, "a size that isn't a number goes back to following Edit Mode")
    T.Eq(db.options.height, 500, "a height set here stays")
    saved.filters = { state = "ready" }
    saved.categoryOrder = { "pvp", 3 }
    db = DB.Load(saved)
    T.True(next(db.filters) == nil, "a category that isn't a table resets the filter")
    T.Eq(db.categoryOrder, nil, "an order with a non-ID goes back to the default")
    saved.categoryOrder = "pvp"
    T.Eq(DB.Load(saved).categoryOrder, nil, "and one that isn't a list")
    saved.options.height, saved.options.heightDefaulted = nil, true
    T.Eq(DB.Load(saved).options.height, nil, "the default height is given once, so a height Edit Mode took over stays Edit Mode's")
end)

T.Add("DB", "repair: a number outside its option's range comes back inside it, NaN goes back to the default", function()
    local saved = DB.Load(nil)
    local o = saved.options
    o.width, o.opacity, o.height, o.titleGap, o.textSize, o.saturation = 5000, -20, 3, 0 / 0, 0 / 0, 40
    local db = DB.Load(saved)
    T.Eq(db.options.width, DB.RANGES.width[2], "too wide")
    T.Eq(db.options.opacity, DB.RANGES.opacity[1], "below its range")
    T.Eq(db.options.height, DB.RANGES.height[1], "too short")
    T.Eq(db.options.titleGap, DB.DEFAULTS.titleGap, "NaN takes the default")
    T.Eq(db.options.textSize, nil, "a NaN text size follows Edit Mode")
    T.Eq(db.options.saturation, 40, "one inside stays")
    for key, range in pairs(DB.RANGES) do
        local default = DB.DEFAULTS[key]
        T.True(range[1] < range[2] and default >= range[1] and default <= range[2], "the default is inside its range: " .. key)
    end
end)

T.Add("DB", "repair: a broken learned spot is dropped, a good one kept", function()
    local saved = DB.Load(nil)
    saved.spots = { [12] = { 1436, 0.41, 0.6 }, [13] = { 1436, "x", 0.6 }, [14] = "here", [15] = { 1436, 0.4 }, [16] = { nil, 0.4, 0.6 },
        x = { 1, 2, 3 } }
    local spots = DB.Load(saved).spots
    T.List(spots[12], { 1436, 0.41, 0.6 }, "a map and a place stay")
    T.True(spots[13] == nil and spots[14] == nil and spots[15] == nil and spots[16] == nil and spots.x == nil, "the rest go")
    saved.spots = "nowhere"
    T.True(next(DB.Load(saved).spots) == nil, "spots that aren't a table start empty")
end)

T.Add("DB", "repair: a marker style the addon doesn't know goes back to icons, a known one stays", function()
    local saved = DB.Load(nil)
    T.Eq(saved.options.markers.dungeon and saved.options.markers.class and saved.options.markers.offlist, true, "every marker on at first")
    saved.options.markers.daily, saved.options.markers.weekly = false, "no"
    local markers = DB.Load(saved).options.markers
    T.Eq(markers.daily, false, "one switched off stays off")
    T.Eq(markers.weekly, true, "one that isn't true or false goes back on")
    saved.options.markers = "all"
    T.Eq(DB.Load(saved).options.markers.timed, true, "markers that aren't a table start all on")
    saved.options.markerStyle = "text"
    T.Eq(DB.Load(saved).options.markerStyle, "text", "text stays")
    saved.options.markerStyle = "emoji"
    T.Eq(DB.Load(saved).options.markerStyle, "icons", "an unknown one")
    saved.options.markerStyle = 3
    T.Eq(DB.Load(saved).options.markerStyle, "icons", "a number")
end)
