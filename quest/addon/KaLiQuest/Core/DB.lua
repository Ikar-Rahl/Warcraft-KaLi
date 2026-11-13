-- Saved data: one table per character. Loading never loses a layout: upgrades and repairs run on a copy that
-- replaces the original only if every step succeeds, and data from a newer addon is left alone.
local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 1

-- Ikar's defaults, 2026-11-07, set on the test bench. The zoom, Ikar's ruling on 2026-11-10, starts at 100 %.
DB.DEFAULTS = {
    width = 310, height = 530, zoom = 100, titleGap = -4, groupIndent = 0, questIndent = 40, groupGap = 5, barGap = 5,
    markerSize = 13, blockRest = 15, blockCombat = 15, blockHover = 40, opacity = 90, opacityCombat = 50, saturation = 50,
    bgOpacity = 0,
}

-- The options page's ranges, which loading also keeps saved numbers in.
DB.RANGES = {
    width = { 220, 400 }, height = { 200, 1000 }, zoom = { 50, 200 }, titleGap = { -6, 10 }, groupIndent = { 0, 24 },
    questIndent = { 20, 44 }, groupGap = { 0, 16 }, barGap = { 0, 16 }, markerSize = { 10, 20 }, blockRest = { 0, 100 },
    blockCombat = { 0, 100 }, blockHover = { 0, 100 }, opacity = { 0, 100 }, opacityCombat = { 0, 100 }, saturation = { 0, 100 },
    bgOpacity = { 0, 100 },
}

-- Where the tracker stands in each Edit Mode layout, once moved there: a corner of the screen and the distance to it.
DB.CORNERS = { TOPLEFT = true, TOPRIGHT = true }

-- Every marker a quest row can show, in the plan's order. Each can be switched off in the options.
DB.MARKERS = { "offlist", "timed", "size", "dungeon", "raid", "pvp", "repeatable", "daily", "weekly", "legendary", "class" }

-- Shared/Core.lua's: a number the file can hold, tested by how it prints (the game's Lua doesn't compare nan as other
-- Luas do), and a copy all the way down.
local finite, deepCopy = ns.Finite, ns.DeepCopy

-- Step n turns version n - 1 into version n. A released step never changes; new formats add a step.
DB.STEPS = {
    [1] = function(db)
        db.nextGroupID = db.nextGroupID or 1
        db.groups = db.groups or {}
    end,
}

-- Keys that may be missing in the current version's data. Not an upgrade: only fills gaps.
function DB.FillDefaults(db)
    if db.locked == nil then
        db.locked = false
    end
    db.open = type(db.open) == "table" and db.open or {}
    local open = db.open
    if open.tracker == nil then
        open.tracker = true
    end
    open.categories = type(open.categories) == "table" and open.categories or {}
    if open.categories.journal == nil then
        open.categories.journal = true
    end
    open.groups = type(open.groups) == "table" and open.groups or {}
    open.headers = type(open.headers) == "table" and open.headers or {}
    db.filters = type(db.filters) == "table" and db.filters or {}
    -- Planned for other addons' widgets, never used.
    db.disabledExtensions = nil
    db.spots = type(db.spots) == "table" and db.spots or {}
    -- Where each quest last progressed: [questID] = { mapID, x, y }. Anything else is dropped.
    for id, spot in pairs(db.spots) do
        if not finite(id) or type(spot) ~= "table" or not finite(spot[1]) or not finite(spot[2]) or not finite(spot[3]) then
            db.spots[id] = nil
        end
    end
    db.repeatable = type(db.repeatable) == "table" and db.repeatable or {}
    db.options = type(db.options) == "table" and db.options or {}
    local o = db.options
    if o.autoQuestWatch == nil then
        o.autoQuestWatch = false -- Ikar's ruling: off when the addon is installed
    end
    if o.progressFlash == nil then
        o.progressFlash = true
    end
    if o.areaHighlight == nil then
        o.areaHighlight = true
    end
    if o.tracker == nil then
        o.tracker = true
    end
    if o.findGroup == nil then
        o.findGroup = false
    end
    if o.shareOnHover == nil then
        o.shareOnHover = true
    end
    if o.markerStyle ~= "icons" and o.markerStyle ~= "text" and o.markerStyle ~= "none" then
        o.markerStyle = "icons"
    end
    o.markers = type(o.markers) == "table" and o.markers or {}
    for _, kind in ipairs(DB.MARKERS) do
        if type(o.markers[kind]) ~= "boolean" then
            o.markers[kind] = true
        end
    end
    -- nan and inf count as missing.
    local D = DB.DEFAULTS
    for _, key in ipairs({ "width", "zoom", "titleGap", "groupIndent", "questIndent", "groupGap", "barGap", "markerSize",
        "blockRest", "blockCombat", "blockHover", "opacity", "opacityCombat", "saturation" }) do
        if not finite(o[key]) then
            o[key] = D[key]
        end
    end
    -- Height stays nil, following Blizzard's tracker, until set. So does the background's opacity: Blizzard's, set in
    -- Edit Mode before the tracker had a dialog of its own, until set in the addon.
    for _, key in ipairs({ "height", "bgOpacity" }) do
        if not finite(o[key]) then
            o[key] = nil
        end
    end
    -- Edit Mode's own height, last seen, until the tracker became an Edit Mode frame of its own on 2026-11-13.
    o.editModeHeight = nil
    -- The addon's own text size, until the zoom replaced it on 2026-11-10. Edit Mode's sets the text now.
    o.textSize, o.editModeTextSize = nil, nil
    for key, range in pairs(DB.RANGES) do
        if o[key] then
            o[key] = math.max(range[1], math.min(range[2], o[key]))
        end
    end
    -- The default height is given once, so one Edit Mode later took over stays Edit Mode's.
    if not o.heightDefaulted then
        o.height = o.height or D.height
        o.heightDefaulted = true
    end
    for cat, set in pairs(db.filters) do
        if type(cat) ~= "string" or type(set) ~= "table" then
            db.filters = {}
            break
        end
        for value, on in pairs(set) do
            if type(value) ~= "string" or on ~= true then
                set[value] = nil
            end
        end
    end
    -- The tracker's place in each Edit Mode layout it was moved in, by the layout's key (UI/EditFrame.lua).
    db.editMode = type(db.editMode) == "table" and db.editMode or {}
    local positions = type(db.editMode.positions) == "table" and db.editMode.positions or {}
    db.editMode.positions = positions
    for key, p in pairs(positions) do
        if type(key) ~= "string" or type(p) ~= "table" or not DB.CORNERS[p.point] or not finite(p.x) or not finite(p.y) then
            positions[key] = nil
        end
    end
    -- Journal's order from dragging its bars: a list of category IDs, or nothing for the default.
    if db.categoryOrder ~= nil then
        local valid = type(db.categoryOrder) == "table"
        for _, id in ipairs(valid and db.categoryOrder or {}) do
            valid = valid and type(id) == "string"
        end
        if not valid then
            db.categoryOrder = nil
        end
    end
end

-- Keeps the layout usable whatever happened to the file: each quest in at most one group (the first wins),
-- group IDs unique, and nextGroupID above all of them. Returns how many things it fixed.
function DB.Repair(db)
    local fixed = 0
    local groups, ids, placed = {}, {}, {}
    local maxID = 0
    for _, g in ipairs(type(db.groups) == "table" and db.groups or {}) do
        -- nan can't be a table key, and inf is no ID.
        local validID = type(g) == "table" and finite(g.id)
        if validID and not ids[g.id] then
            ids[g.id] = true
            maxID = math.max(maxID, g.id)
            if type(g.name) ~= "string" or g.name == "" then
                g.name = "?"
                fixed = fixed + 1
            end
            local quests = {}
            for _, q in ipairs(type(g.quests) == "table" and g.quests or {}) do
                if finite(q) and not placed[q] then
                    placed[q] = true
                    quests[#quests + 1] = q
                else
                    fixed = fixed + 1
                end
            end
            g.quests = quests
            groups[#groups + 1] = g
        else
            fixed = fixed + 1
        end
    end
    db.groups = groups
    if not finite(db.nextGroupID) or db.nextGroupID <= maxID then
        db.nextGroupID = maxID + 1
        fixed = fixed + 1
    end
    return fixed
end

-- Returns the data to use and how many things Repair fixed, or nil and a reason when the saved table must be
-- left untouched. The data is always a new table, so the caller stores what this returns.
function DB.Load(saved)
    if saved == nil then
        saved = {}
    elseif type(saved) ~= "table" then
        return nil, "not a table"
    end
    local version = saved.version or 0
    if not finite(version) or version < 0 or math.floor(version) ~= version then
        return nil, "bad version"
    end
    if version > DB.VERSION then
        return nil, "version " .. version .. " > " .. DB.VERSION
    end
    local data = deepCopy(saved)
    for v = version + 1, DB.VERSION do
        local ok, err = pcall(DB.STEPS[v], data)
        if not ok then
            return nil, "step " .. v .. ": " .. tostring(err)
        end
        data.version = v
    end
    local ok, fixed = pcall(function()
        DB.FillDefaults(data)
        return DB.Repair(data)
    end)
    if not ok then
        return nil, "repair: " .. tostring(fixed)
    end
    return data, fixed
end

-- At logout, the last event before the game writes the files: a number it can't write back as one (nan, inf) would
-- make the file unreadable and lose every group, so none stays (KaLi Recipe's rule, docs/saved-data.md there). How
-- many went is kept, for /kq status. Returns that many.
function DB.BeforeSave(db)
    local n = ns.DropNonFinite(db)
    if n > 0 then
        db.nonFinite = (finite(db.nonFinite) and db.nonFinite or 0) + n
    end
    return n
end
