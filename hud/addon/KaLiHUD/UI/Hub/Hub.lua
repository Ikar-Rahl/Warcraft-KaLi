-- The slot hub's model: every element the HUD places, where each is saved to stand, and the edits that move them.
-- Elements are KaLi HUD's own items (UI/Hub/Items.lua), other addons' LibDataBroker objects, Blizzard's minimap
-- widgets (UI/Hub/Natives.lua), other addons' map buttons (UI/Hub/Collect.lua), the folders (UI/Hub/Folders.lua), the
-- macros (UI/Hub/Macros.lua) and the separators in folders (UI/Hub/Separators.lua).
-- Their list is kept until something changes (Hub.Changed); UI/Hub/InfoBar.lua draws them, UI/Hub/Drag.lua and
-- UI/Hub/Menus.lua move them.
local _, ns = ...

local Hub = {}
ns.Hub = Hub

local Geometry = ns.Geometry

-- The sides an element stands on: the bar's (free: anywhere along it, at `pos`, its centre, a fraction of the screen's
-- width), round the map, in a folder, or hidden (Core/DB.lua's SIDES).
Hub.BAR = { left = true, free = true, centre = true, right = true }
Hub.ROUND = { pocketLeft = true, pocketRight = true, ring = true }
-- Laid out right to left: the bar's right side from its end, the left pocket outwards.
Hub.REVERSED = { right = true, pocketLeft = true }
-- Round the map: the elements' centres this far past the ring, one step along it about a button; a pocket on the
-- ring's lower corner when the plate has none.
local PIN_GAP, RING_STEP = 8, 26
Hub.RING_STEP = RING_STEP
Hub.POCKET_ANGLE = { pocketLeft = 218, pocketRight = 322 }

local own, ownList = {}, {}
local natives, nativeList = {}, {}
-- The list as last built, and by name; nil once something changed, until asked for again.
local entries, index
-- How many times the list was built, for the tests.
Hub.builds = 0

-- ---------- The elements ----------

-- Published to other displays once every addon has loaded (Hub.Start).
local started = false
local publish

-- One of KaLi HUD's items: its default side, order, angle and visibility. obj.home: the role of the folder made for
-- it (Folders.ByRole), where it stands by default while that folder is there, else on `side`; obj.available(): whether
-- this character has it at all (a skill, a class's reagent), none shown anywhere while not. One added after login (a
-- skill learnt) is published and drawn at once.
function Hub.Add(name, obj, side, order, angle, show)
    if not own[name] then
        ownList[#ownList + 1] = name
    end
    own[name] = { obj = obj, side = side, order = order, angle = angle or 225, show = show or "always" }
    if started then
        publish(name)
        Hub.Changed()
    end
end

-- Whether this character has one of our items (its obj.available), drawn anywhere at all.
local function available(d)
    return type(d.obj.available) ~= "function" or d.obj.available() == true
end

-- One of ours offered to other displays (LibDataBroker), once: what this character has, under a name a player reads
-- there. Every item was published, 95 of them, 31 another class's reagents or statistics the build doesn't know, with
-- no label: another display beside KaLi HUD offered them all, empty (the review of 2026-11-17). One whose label comes
-- later (an item's name the game hadn't yet, a skill learnt) is published then (Hub.Set).
local published = {}
function publish(name)
    local d = own[name]
    if not (started and d) or published[name] or not available(d) then
        return
    end
    local label = d.obj.label
    if type(label) ~= "string" or label == "" or label:find("^%d+$") then
        return
    end
    local ldb = Hub.Broker()
    if not ldb then
        return
    end
    published[name] = true
    if not ns.Call(ldb.GetDataObjectByName, ldb, name) then
        ns.Call(ldb.NewDataObject, ldb, name, d.obj)
    end
end

-- One of Blizzard's minimap widgets: spec = { label, side, order, angle, show }, its defaults.
function Hub.AddNative(name, spec)
    if not natives[name] then
        nativeList[#nativeList + 1] = name
    end
    natives[name] = spec
    entries, index = nil, nil
end

function Hub.Native(name)
    return natives[name]
end

function Hub.IsOurs(name)
    return own[name] ~= nil
end

-- ---------- What the hub makes: folders, macros, separators ----------
-- Each kind is saved in a table of its own (`db.folders`, `db.macros`, `db.separators`) under an id, its prefix and a
-- number (Core/DB.lua's IDS: any other key is dropped at load). What the three shared, written three times: whether a
-- name is one of its ids, saved or not (its button's kind is told by it: UI/Hub/Buttons.lua's Kind); its ids in the
-- order they were made, kept until told to forget (Hub.Changed); the next free id; an id's number.
function Hub.Made(kind)
    local prefix = ns.DB.IDS[kind]
    local pattern, ids = "^" .. prefix .. "%d+$", nil
    local made = {}
    function made.Number(id)
        return tonumber(id:match("%d+$")) or 0
    end
    local function byNumber(a, b)
        return made.Number(a) < made.Number(b)
    end
    function made.IsId(name)
        return type(name) == "string" and name:find(pattern) ~= nil
    end
    -- read it, never change it
    function made.List()
        if not ids then
            ids = {}
            for id in pairs(ns.db[kind]) do
                ids[#ids + 1] = id
            end
            table.sort(ids, byNumber)
        end
        return ids
    end
    function made.Forget()
        ids = nil
    end
    function made.NewId()
        local n = 1
        while ns.db[kind][prefix .. n] do
            n = n + 1
        end
        return prefix .. n
    end
    return made
end

-- ---------- Copies ----------
-- One of our items shown once more (Ikar 2026-11-23: the folders KaLi HUD makes are locked, "if they drag and drop, it
-- create a copy"): dragged out of a locked folder (UI/Hub/Seeds.lua), what lands is a copy, the item staying in it.
-- The item's own object, so its value, tooltip, clicks and settings are the item's; saved under an id of its own
-- (`db.copies[id] = { of = name }`), its place as any element's. Deleted from its menu; one whose item this character
-- hasn't (another class's reagent) shows nowhere.
local copies = Hub.Made("copies")
Hub.IsCopy = copies.IsId

-- The item a copy shows, by its name; nil for no copy.
function Hub.CopyOf(id)
    local c = ns.db.copies[id]
    return c and c.of or nil
end

-- A new copy of item `name`, its id, nil for no item of ours. Not drawn.
function Hub.NewCopy(name)
    if not own[name] then
        return nil
    end
    local id = copies.NewId()
    ns.db.copies[id] = { of = name }
    copies.Forget()
    entries, index = nil, nil
    return id
end

-- Gone, from its menu.
function Hub.DeleteCopy(id)
    if not ns.db.copies[id] then
        return
    end
    ns.db.copies[id] = nil
    ns.db.items[id] = nil
    Hub.Changed()
end

-- A name the player typed for a folder or a macro: the blanks round it gone; nil for none, or one too long to save.
function Hub.CleanName(text)
    local name = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > ns.DB.NAME_BYTES then
        return nil
    end
    return name
end

-- Whether an icon of the library (Data/Icons.lua) is a white glyph, drawn in the folders' colour.
local glyphs = {}
for _, icon in ipairs(ns.ICONS) do
    glyphs[icon[1]] = icon[6] == true
end
function Hub.IsGlyph(atlas)
    return glyphs[atlas] == true
end

-- The zone stays on its side, shown: never dragged nor hidden, it has no hub menu.
function Hub.IsFixed(name)
    local d = own[name]
    return d ~= nil and d.obj.fixed == true
end

-- LibDataBroker-1.1, when another addon loaded it.
function Hub.Broker()
    local stub = LibStub
    local ldb = type(stub) == "table" and ns.Call(stub.GetLibrary, stub, "LibDataBroker-1.1", true)
    return type(ldb) == "table" and ldb or nil
end

-- An element's object: its data object, a widget's spec, a folder's or a map button's.
function Hub.Object(name)
    local e = Hub.Entry(name)
    if e then
        return e.obj
    end
    local ldb = Hub.Broker()
    return ldb and ns.Call(ldb.GetDataObjectByName, ldb, name)
end

-- What an element is called in menus and tooltips.
function Hub.Label(name, obj)
    obj = obj or Hub.Object(name)
    return type(obj) == "table" and type(obj.label) == "string" and obj.label or name
end

-- ---------- The list ----------

local function inOrder(a, b)
    if a.order ~= b.order then
        return a.order < b.order
    end
    return a.name < b.name
end

local function byText(a, b)
    return ns.TextLess(a.name, b.name)
end

-- Every element, ours first, then the folders, the macros, the separators, Blizzard's widgets, other addons' map
-- buttons and LDB objects, each { name, obj, side, folder, order, angle, show, pos, ours, native, foreign, isFolder,
-- isMacro, isSeparator }, sorted by order. Other addons' launchers and map buttons land in the default folder, and
-- their data sources too: one landed on the bar's right end, where it shifted what stood there (the review of
-- 2026-11-17, second round; Ikar: "Agreed": nothing lands on the bar unasked), and does so still with no such folder.
-- A separator stands in a folder only: one whose folder is gone shows nowhere.
local function build()
    Hub.builds = Hub.builds + 1
    local saved, Folders = ns.db.items, ns.Folders
    local landing = Folders.Default()
    local list, named = {}, {}
    local function add(name, obj, kind, side, order, angle, show, folder)
        local s = saved[name]
        local e = {
            name = name, obj = obj,
            side = s and s.side or side,
            folder = s and s.folder or folder,
            order = s and s.order or order,
            angle = s and s.angle or angle,
            show = s and s.show or show,
            pos = s and s.pos or 0.5,
            slot = s and s.slot,
            ours = kind == "ours", native = kind == "native", foreign = kind == "foreign", isFolder = kind == "folder",
            isMacro = kind == "macro", isSeparator = kind == "separator",
            -- a copy is ours as its item is, drawn and used as it
            isCopy = kind == "copy" or nil,
        }
        e.ours = e.ours or e.isCopy == true
        -- its folder gone: where it goes with none saved
        if e.side == "folder" and not Folders.Get(e.folder) then
            local lands = side == "folder" and Folders.Get(folder) ~= nil
            e.side, e.folder = lands and "folder" or (side == "folder" and "right" or side), lands and folder or nil
        end
        if e.isSeparator and e.side ~= "folder" then
            return e
        end
        list[#list + 1] = e
        named[name] = e
        return e
    end
    for _, name in ipairs(ownList) do
        local d = own[name]
        if available(d) then
            local home = d.obj.home and Folders.ByRole(d.obj.home)
            local e = add(name, d.obj, "ours", home and "folder" or d.side, d.order, d.angle, d.show, home)
            if d.obj.fixed then
                e.side, e.show = d.side, "always"
            end
        end
    end
    for i, id in ipairs(Folders.List()) do
        add(id, Folders.Object(id), "folder", "right", i, 225, "always")
    end
    for i, id in ipairs(ns.Macros.List()) do
        add(id, ns.Macros.Object(id), "macro", "right", 40 + i, 225, "always")
    end
    for i, id in ipairs(ns.Separators.List()) do
        add(id, ns.Separators.Object(id), "separator", "hidden", 900 + i, 225, "always")
    end
    for i, id in ipairs(copies.List()) do
        local of = ns.db.copies[id].of
        local d = own[of]
        if d and available(d) then
            add(id, d.obj, "copy", "right", 60 + i, d.angle, "always").of = of
        end
    end
    for i, name in ipairs(nativeList) do
        local spec = natives[name]
        add(name, spec, "native", spec.side or "ring", spec.order or 50 + i, spec.angle or 135, spec.show or "always")
    end
    for i, name in ipairs(ns.Collect.List()) do
        add(name, ns.Collect.Object(name), "foreign", landing and "folder" or "right", 80 + i, (200 + i * 22) % 360,
            "always", landing)
    end
    local ldb = Hub.Broker()
    if ldb and ldb.DataObjectIterator then
        local others = {}
        for name, obj in ldb.DataObjectIterator(ldb) do
            -- ours published but not this character's (another class's reagent) aren't another addon's
            if type(name) == "string" and not named[name] and not own[name] then
                others[#others + 1] = { name = name, obj = obj }
            end
        end
        table.sort(others, byText)
        for i, o in ipairs(others) do
            add(o.name, o.obj, "ldb", landing and "folder" or "right", 100 + i, (200 + i * 22) % 360, "always", landing)
        end
    end
    table.sort(list, inOrder)
    entries, index = list, named
end

-- The elements in their order: read it, never change it.
function Hub.Entries()
    if not entries then
        build()
    end
    return entries
end

function Hub.Entry(name)
    if not entries then
        build()
    end
    return index[name]
end

-- A side's elements in their order, `exclude` left out: a new list.
function Hub.Side(side, exclude)
    local list = {}
    for _, e in ipairs(Hub.Entries()) do
        if e.side == side and e.name ~= exclude then
            list[#list + 1] = e
        end
    end
    return list
end

-- A folder's elements in their order, `exclude` left out: a new list.
function Hub.InFolder(id, exclude)
    local list = {}
    for _, e in ipairs(Hub.Entries()) do
        if e.side == "folder" and e.folder == id and e.name ~= exclude then
            list[#list + 1] = e
        end
    end
    return list
end

-- Everything that shows the elements drawn again, once, on the next frame.
function Hub.Redraw()
    ns.InfoBar.Request()
    ns.Natives.Request()
    -- the pockets' free places are marked on the plate while unlocked
    if ns.db.options.pocketMarks and not Hub.IsLocked() then
        ns.Plate.Request()
    end
end

-- Which elements there are, or where one stands, changed: the list is built again when next asked for, and drawn.
function Hub.Changed()
    entries, index = nil, nil
    ns.Folders.Forget()
    ns.Macros.Forget()
    ns.Separators.Forget()
    copies.Forget()
    Hub.Redraw()
end

-- A field of one of KaLi HUD's items (its text, its colour): only its button is drawn again, and its copies'.
function Hub.Set(name, key, value)
    local d = own[name]
    if d and d.obj[key] ~= value then
        d.obj[key] = value
        ns.InfoBar.Update(name)
        for _, id in ipairs(copies.List()) do
            if ns.db.copies[id].of == name then
                ns.InfoBar.Update(id)
            end
        end
        -- named at last: offered to other displays now
        if key == "label" then
            publish(name)
        end
    end
end

-- ---------- The lock ----------

function Hub.IsLocked()
    return ns.db.options.slotsLocked ~= false
end

-- Unlocked, elements are dragged, Blizzard's widgets and map buttons get handles, the pockets' free places show.
function Hub.SetLocked(locked)
    ns.db.options.slotsLocked = locked and true or false
    -- a macro's own right-click runs while it's shut alone (UI/Hub/Macros.lua)
    ns.SafeCall(ns.Macros.ArmAll)
    -- the player arranging the bar: each item's place its width again (UI/Hub/InfoBar.lua's places)
    ns.InfoBar.Forget()
    ns.InfoBar.UpdateLock()
    Hub.Redraw()
    ns.Plate.Request()
end

-- ---------- Placing ----------

-- Writes where `name` stands, patch = { side, folder, order, angle, show, pos, last, slot } over what's saved; not
-- drawn. slot: its place in a pocket, 0 for none (the first free).
local function write(name, patch)
    local cur = Hub.Entry(name)
    local saved = ns.db.items[name] or {}
    saved.side = patch.side or saved.side or (cur and cur.side) or "right"
    if patch.slot then
        saved.slot = patch.slot > 0 and patch.slot or nil
    end
    if not Hub.POCKET_ANGLE[saved.side] then
        saved.slot = nil
    end
    -- in a folder, which; hidden from one, the one it goes back to
    if saved.side == "folder" then
        saved.folder = patch.folder or saved.folder or (cur and cur.folder)
    elseif saved.side ~= "hidden" then
        saved.folder = nil
    elseif patch.last == "folder" then
        saved.folder = saved.folder or (cur and cur.folder)
    end
    saved.order = patch.order or saved.order or (cur and cur.order) or 50
    local angle = patch.angle or saved.angle
    if angle then
        saved.angle = math.floor(angle + 0.5) % 360
    end
    saved.show = patch.show or saved.show
    if patch.pos then
        saved.pos = math.max(0, math.min(1, patch.pos))
    end
    -- where a hidden one goes back to
    saved.last = patch.last
    ns.db.items[name] = saved
end

-- Saves where `name` stands (write's patch) and draws it there.
function Hub.Save(name, patch)
    write(name, patch)
    Hub.Changed()
end

-- ---------- The saved places, for the hub's other files ----------
-- Each element's saved place (`db.items[name]`) is this file's alone to write (the review of 2026-11-18: it was
-- written from eighteen places in six files, one of which knew its rules; an offline check now fails the table named
-- anywhere else). The others read it and ask. None of these draws: Hub.Changed after the last of them.

-- An element's saved place, nil with none: read it, never change it.
function Hub.Saved(name)
    return ns.db.items[name]
end

-- Every saved place by its element's name, for a loop: read them, never change them. One may be taken away as the
-- loop goes (Unplace), or changed (OutOfFolder); none added.
function Hub.EachSaved()
    return pairs(ns.db.items)
end

-- write, for one moved among others in one go.
Hub.Write = write

-- No place saved: back where it goes by default, at the next drawing.
function Hub.Unplace(name)
    ns.db.items[name] = nil
end

-- A place saved anew, all that was saved of it before forgotten (its angle, its look): on `side` at `order` there, in
-- `folder` for one in a folder.
function Hub.PlaceAt(name, side, order, folder)
    ns.db.items[name] = { side = side, order = order, folder = side == "folder" and folder or nil }
end

-- Its folder gone (UI/Hub/Folders.lua's Delete): hidden if it stood in it (`stood`: it did, by its saved place or by
-- default), the way back into it forgotten by one hidden from it.
function Hub.OutOfFolder(name, stood)
    local saved = ns.db.items[name] or {}
    if stood or saved.side == "folder" then
        saved.side, saved.slot = "hidden", nil
    end
    saved.folder, saved.last = nil, nil
    ns.db.items[name] = saved
end

-- Back where it goes by default.
function Hub.Reset(name)
    Hub.Unplace(name)
    Hub.Changed()
end

-- Puts `name` at its 1-based place among `side`'s elements (last without one), the side renumbered; set free, it
-- stays where it stands on the bar.
function Hub.Insert(name, side, at, angle)
    if side == "free" then
        local p = ns.InfoBar.Placed(name)
        Hub.Save(name, { side = "free", pos = p and p.x / UIParent:GetWidth() or 0.5 })
        return
    end
    if Hub.POCKET_ANGLE[side] then
        -- a pocket: `at` is the place it's put on, any of them (none: the first free); the element there goes where
        -- this one stood in that pocket, else to the first free place, else on the bar
        local d, onPlate = ns.Minimap.Dome()
        local T, cur = ns.InfoBar.Top(), Hub.Entry(name)
        local here = d and onPlate and cur and cur.side == side and Hub.PlaceOf(cur, d, T) or nil
        local last = 0
        for _, e in ipairs(Hub.Side(side, name)) do
            last = math.max(last, e.order or 0)
            if at and d and onPlate and Hub.PlaceOf(e, d, T) == at then
                write(e.name, { side = side, slot = here or 0 })
            end
        end
        write(name, { side = side, slot = at or 0, angle = angle,
            order = cur and cur.side == side and cur.order or last + 10 })
        Hub.Changed()
        return
    end
    local list = Hub.Side(side, name)
    table.insert(list, math.max(1, math.min(#list + 1, at or #list + 1)), { name = name })
    for i, e in ipairs(list) do
        write(e.name, { side = side, order = i * 10, angle = e.name == name and angle or nil })
    end
    Hub.Changed()
end

-- Puts `name` among `side`'s elements just before `ref`, or after it.
function Hub.InsertNear(name, side, ref, after, angle)
    local at
    for i, e in ipairs(Hub.Side(side, name)) do
        if e.name == ref then
            at = after and i + 1 or i
            break
        end
    end
    Hub.Insert(name, side, at, angle)
end

-- Puts `name` in folder id at its 1-based place (last without one), the folder renumbered.
-- `name` into folder `id` at `at` (last by default); true once done, a folder never into itself nor one it holds.
function Hub.InsertIntoFolder(name, id, at)
    if not ns.Folders.CanHold(id, name) then
        return false
    end
    local list = Hub.InFolder(id, name)
    table.insert(list, math.max(1, math.min(#list + 1, at or #list + 1)), { name = name })
    for i, e in ipairs(list) do
        write(e.name, { side = "folder", folder = id, order = i * 10 })
    end
    Hub.Changed()
    return true
end

-- Hidden, or shown again on the side it left: its folder while there is one, else the bar's right end.
function Hub.SetShown(name, shown)
    local e = Hub.Entry(name)
    if not e or (e.side ~= "hidden") == shown then
        return
    end
    if not shown then
        Hub.Save(name, { side = "hidden", last = e.side })
        return
    end
    local saved = ns.db.items[name] or {}
    local d = own[name] or natives[name]
    -- ours made for a folder of its own goes back into it
    local home = own[name] and own[name].obj.home and ns.Folders.ByRole(own[name].obj.home)
    local side = saved.last or home and "folder" or d and d.side ~= "hidden" and d.side or "right"
    if side == "folder" then
        local into = ns.Folders.Get(saved.folder) and saved.folder or home
        if into and Hub.InsertIntoFolder(name, into) then
            return
        end
        side = "right"
    end
    if side == "free" then
        Hub.Save(name, { side = "free" })
    else
        Hub.Insert(name, side)
    end
end

-- A folder's or a macro's look (Ikar 2026-11-16: "macro should display their name when they have one, and as any
-- other, should be able to show name, icon, or both"), saved as `iconOnly` or `nameOnly` (true), else both: "both",
-- "icon" or "name". On the bar and round the map as it says; in a list with text, its name by its icon unless its name
-- alone (HubButtons' textOf).
Hub.LOOKS = { "both", "icon", "name" }
function Hub.LookOf(t)
    return type(t) == "table" and (t.iconOnly and "icon" or t.nameOnly and "name") or "both"
end

function Hub.SetLook(t, look)
    t.iconOnly, t.nameOnly = look == "icon" or nil, look == "name" or nil
end

-- Its menu's entry: « Affichage », the three as radios; `get` gives the saved table, `set(look)` changes it.
function Hub.LookEntry(get, set)
    local items = {}
    for _, look in ipairs(Hub.LOOKS) do
        items[#items + 1] = { text = ns.L["LOOK_" .. look], radio = true, held = true, checked = function()
            return Hub.LookOf(get()) == look
        end, func = function()
            set(look)
        end }
    end
    return { text = ns.L.LOOK, held = true, items = items }
end

-- Any other element's look on the bar (the review of 2026-11-17, second round's 10; Ikar: "Agreed"): one of ours or
-- another addon's object with an icon, as "both" (its icon and its text, a launcher's name), "icon" (its value on
-- hover) or "text" (a launcher's name alone), saved with its place (`db.items[name].look`); none saved, as it comes: a
-- launcher its icon alone, any other both. On the bar only: in a list its folder's style decides, round the map its
-- icon stands alone. One with no icon has no choice to make.
Hub.ITEM_LOOKS = { "both", "icon", "text" }

function Hub.DefaultLook(obj)
    return type(obj) == "table" and obj.type == "launcher" and "icon" or "both"
end

-- Whether `name` has that choice: ours but the zone, or another addon's object, with an icon.
function Hub.HasLook(name)
    local e = Hub.Entry(name)
    if not e or e.native or e.foreign or e.isFolder or e.isMacro or e.isSeparator or Hub.IsFixed(name) then
        return false
    end
    local obj = e.obj
    return type(obj) == "table" and (type(obj.atlas) == "string" or obj.icon ~= nil)
end

-- The look chosen for it, nil for none (as it comes).
function Hub.ItemLook(name)
    local saved = ns.db.items[name]
    return saved and saved.look or nil
end

-- Chooses it, its place saved with it where it stands; the one it comes with saves none.
function Hub.SetItemLook(name, look)
    local e = Hub.Entry(name)
    if not e then
        return
    end
    if not ns.db.items[name] then
        write(name, {})
    end
    ns.db.items[name].look = look ~= Hub.DefaultLook(e.obj) and look or nil
    Hub.Changed()
end

-- A new folder, named by the player, where it was asked for (Ikar 2026-11-20: "it shoudl appear where the user put
-- it., not on the right"): in `item`'s place, `item` put in it; else where the bar's menu was opened, `at` ({ x, y },
-- HubDrag.PlaceAt); else at the bar's right end. One action (UI/Hub/History.lua).
function Hub.NewFolder(item, at)
    ns.Folders.AskName(nil, function(folderName)
        local id = ns.History.Do("create", nil, function()
            local id = ns.Folders.Create(folderName)
            local e = item and Hub.Entry(item)
            if e and e.side == "folder" then
                local index
                for i, member in ipairs(Hub.InFolder(e.folder)) do
                    if member.name == item then
                        index = i
                    end
                end
                Hub.InsertIntoFolder(id, e.folder, index)
            elseif e and e.side == "free" then
                write(id, { side = "free", pos = e.pos })
            elseif e and Hub.BAR[e.side] then
                Hub.InsertNear(id, e.side, item, false)
            elseif at then
                ns.HubDrag.PlaceAt(id, at[1], at[2])
            else
                Hub.Insert(id, "right", 1)
            end
            if item then
                Hub.InsertIntoFolder(item, id)
            end
            return id
        end)
        -- the menu that asked for it gone: lit where it was made
        ns.InfoBar.Flash(id)
    end)
end

-- ---------- Going left or right ----------

local function byX(a, b)
    if a.x ~= b.x then
        return a.x < b.x
    end
    return a.n < b.n
end

local function byCos(a, b)
    return math.cos(math.rad(a.angle)) < math.cos(math.rad(b.angle))
end

-- A row's elements as on the screen, left to right: the bar's (left, then those below the minimap and those set free
-- by where they stand, right) or round the map (left pocket, the ring by x, right pocket; in a pocket by where their
-- places stand, those with none at its outer end).
local function rowOf(row)
    local list = {}
    local function add(side)
        local part = Hub.Side(side)
        local from, to, by = 1, #part, 1
        if Hub.REVERSED[side] then
            from, to, by = #part, 1, -1
        end
        for i = from, to, by do
            list[#list + 1] = part[i]
        end
    end
    local function addPocket(side)
        local d, onPlate = ns.Minimap.Dome()
        local T, out = ns.InfoBar.Top(), side == "pocketLeft" and -math.huge or math.huge
        local part = {}
        for i, e in ipairs(Hub.Side(side)) do
            local x = d and onPlate and Hub.SlotPoint(e, d, T, true)
            part[i] = { e = e, x = x or out, n = i }
        end
        table.sort(part, byX)
        for _, p in ipairs(part) do
            list[#list + 1] = p.e
        end
    end
    if row == "bar" then
        add("left")
        local mid, W = {}, UIParent:GetWidth()
        for _, side in ipairs({ "centre", "free" }) do
            for _, e in ipairs(Hub.Side(side)) do
                local p = ns.InfoBar.Placed(e.name)
                mid[#mid + 1] = { e = e, x = p and p.x or e.pos * W, n = #mid }
            end
        end
        table.sort(mid, byX)
        for _, m in ipairs(mid) do
            list[#list + 1] = m.e
        end
        add("right")
    else
        addPocket("pocketLeft")
        local ring = Hub.Side("ring")
        table.sort(ring, byCos)
        for _, e in ipairs(ring) do
            list[#list + 1] = e
        end
        addPocket("pocketRight")
    end
    return list
end

-- The place of a pocket next to place i that way on the screen (dir: 1 right, -1 left), the nearest across, then the
-- nearest up or down; with no i, the first one met coming in that way. nil when there's none.
local function nextPlace(side, i, dir)
    local d, onPlate = ns.Minimap.Dome()
    if not (d and onPlate) then
        return nil
    end
    local places = Hub.PocketSpots(d, ns.InfoBar.Top())[side]
    local sx, here = side == "pocketLeft" and -1 or 1, i and places[i]
    local best, bh, bv
    for j, p in ipairs(places) do
        -- how far that way on the screen from here (from the far side coming in), and how far up or down
        local h = here and (p.dx - here.dx) * sx * dir or -p.dx * sx * dir
        local v = here and math.abs(p.y - here.y) or p.y
        if j ~= i and (not here or h > 0.5) and (not best or h < bh - 0.5 or math.abs(h - bh) <= 0.5 and v < bv) then
            best, bh, bv = j, h, v
        end
    end
    return best
end

-- « Aller à gauche / à droite »: past its neighbour on that side in its row, crossing into the next part of the row
-- (left → below the minimap → right; pocket → ring → pocket); in a pocket, to its next place that way, free or not.
-- False when it's already last that way.
function Hub.Step(name, dir)
    local entry = Hub.Entry(name)
    if not entry or entry.side == "hidden" then
        return false
    end
    if entry.side == "folder" then
        local list = Hub.InFolder(entry.folder)
        for i, e in ipairs(list) do
            if e.name == name then
                if not list[i + dir] then
                    return false
                end
                Hub.InsertIntoFolder(name, entry.folder, i + dir)
                return true
            end
        end
        return false
    end
    if Hub.POCKET_ANGLE[entry.side] then
        local d, onPlate = ns.Minimap.Dome()
        local i = d and onPlate and Hub.PlaceOf(entry, d, ns.InfoBar.Top())
        local to = i and nextPlace(entry.side, i, dir)
        if to then
            Hub.Insert(name, entry.side, to)
            return true
        end
    end
    local list = rowOf(Hub.BAR[entry.side] and "bar" or "round")
    local n
    for i, e in ipairs(list) do
        if e.name == name then
            n = list[i + dir]
            break
        end
    end
    if not n then
        return false
    end
    if n.side == "ring" then
        local d = ns.Minimap.Dome()
        local step = math.deg(RING_STEP / (d and Hub.PinRadius(d) or 84))
        local a1, a2 = (n.angle + step) % 360, (n.angle - step) % 360
        local further = math.cos(math.rad(a1)) > math.cos(math.rad(a2))
        Hub.Save(name, { side = "ring", angle = (dir > 0) == further and a1 or a2 })
    elseif n.side == "free" then
        -- just past it: the bar's layout keeps them apart
        local p = ns.InfoBar.Placed(n.name)
        local W = UIParent:GetWidth()
        Hub.Save(name, { side = "free", pos = ((p and p.x or n.pos * W) + dir) / W })
    elseif Hub.POCKET_ANGLE[n.side] then
        -- into a pocket: its first place coming in that way
        Hub.Insert(name, n.side, nextPlace(n.side, nil, dir))
    else
        -- right of n on the screen is after it in the order, but before it where the side runs right to left
        Hub.InsertNear(name, n.side, n.name, (dir > 0) ~= (Hub.REVERSED[n.side] == true))
    end
    return true
end

-- ---------- Sizes ----------

-- One size for the info bar, its text's (Ikar 2026-11-15: "unify hauteur, taille du texte and tailles des icônes"):
-- the bar's height and the icons follow it as they stood at 10 (18 tall, icons 14), the spacing too.
local BAR_PER_SIZE, ICON_PER_SIZE, SPACING_AT = 1.8, 1.4, 10

function Hub.TextSize()
    return ns.db.options.infoSize
end

function Hub.BarHeight()
    return math.floor(ns.db.options.infoSize * BAR_PER_SIZE + 0.5)
end

function Hub.IconSize()
    return math.floor(ns.db.options.infoSize * ICON_PER_SIZE + 0.5)
end

function Hub.Spacing()
    local o = ns.db.options
    return o.infoSpacing * o.infoSize / SPACING_AT
end

-- ---------- Round the map ----------

-- A pocket's place: an icon and a little room (Blizzard's widgets are drawn at the icon size too).
function Hub.PocketSize()
    return Hub.IconSize() + 2
end

-- How far from the map's centre the elements round it stand.
function Hub.PinRadius(d)
    return d.ring + PIN_GAP
end

-- What stands on a pocket's floor (a status bar, its end cap included) in the pocket's terms: { dx, top }, how far out
-- from the dome's centre it starts and how high it stands; nil when nothing does. slots: the plate's.
local function floorBlock(d, slots, dir, into)
    local found = false
    for _, s in ipairs(slots or {}) do
        if s.kind == "status" and s.y < d.cy then
            local inner = dir > 0 and s.x - d.cx or d.cx - (s.x + s.w)
            local outer = dir > 0 and s.x + s.w - d.cx or d.cx - s.x
            if outer > 0 and inner < d.r then
                into.dx = found and math.min(into.dx, math.max(inner, 0)) or math.max(inner, 0)
                into.top = found and math.max(into.top, s.y + s.h) or s.y + s.h
                found = true
            end
        end
    end
    return found and into or nil
end

local spots, spotsFor = { pocketLeft = {}, pocketRight = {} }, { pocketLeft = {}, pocketRight = {} }
local blocks, found = { pocketLeft = {}, pocketRight = {} }, {}
local POCKET_DIR = { pocketLeft = -1, pocketRight = 1 }
-- The places in each lower pocket of dome d over the bar's top T (Geometry.PocketSpots', at the pocket size), the
-- status bars under them their floor: { pocketLeft = { { dx, y } }, pocketRight = ... }, three as a triangle, six
-- where the pocket affords them, fewer where it's too small. slots: the plate's, the last drawing's by default. Kept
-- while nothing they're made of changes (where the map stands across the screen doesn't, its places being out from
-- its centre): read them, never change them.
function Hub.PocketSpots(d, T, slots)
    slots = slots or (ns.Plate.last and ns.Plate.last.slots)
    local size, k = Hub.PocketSize(), spotsFor
    local same = k.cy == d.cy and k.T == T and k.mapR == d.mapR and k.r == d.r and k.ring == d.ring and k.size == size
    for side, dir in pairs(POCKET_DIR) do
        local b, was = floorBlock(d, slots, dir, blocks[side]), k[side]
        found[side] = b or false
        same = same and (b and b.dx) == was.dx and (b and b.top) == was.top
    end
    if not same then
        for side in pairs(POCKET_DIR) do
            local b = found[side] or nil
            spots[side] = Geometry.PocketSpots(d, T, size, b)
            k[side].dx, k[side].top = b and b.dx, b and b.top
        end
        k.cy, k.T, k.mapR, k.r, k.ring, k.size = d.cy, T, d.mapR, d.r, d.ring, size
    end
    return spots
end

-- Which place each pocket element takes (Ikar 2026-11-16: "you cannot choose freely one of the 3 spots, you have to
-- fill them one by one"): the one it was put on (its saved slot) while the pocket has it and no element before it
-- took it, else the first free one; none past them all, it goes on the bar. { [name] = i or false }, and each pocket's
-- places taken, { pocketLeft = { [i] = name } }; worked out again when the elements or the places change.
local placeOf, taken, placedFor = {}, { pocketLeft = {}, pocketRight = {} }, {}
local function assign()
    local list = Hub.Entries()
    if placedFor.list == list and placedFor.left == spots.pocketLeft and placedFor.right == spots.pocketRight then
        return
    end
    placedFor.list, placedFor.left, placedFor.right = list, spots.pocketLeft, spots.pocketRight
    wipe(placeOf)
    for side in pairs(POCKET_DIR) do
        local used, n = taken[side], #spots[side]
        wipe(used)
        for _, e in ipairs(list) do
            local s = e.side == side and e.slot
            if s and s <= n and not used[s] then
                used[s], placeOf[e.name] = e.name, s
            end
        end
        local free = 1
        for _, e in ipairs(list) do
            if e.side == side and placeOf[e.name] == nil then
                while used[free] do
                    free = free + 1
                end
                if free <= n then
                    used[free], placeOf[e.name] = e.name, free
                else
                    placeOf[e.name] = false
                end
            end
        end
    end
end

-- Which place of its pocket in dome d (the plate's) over T entry takes; nil past them all.
function Hub.PlaceOf(entry, d, T)
    Hub.PocketSpots(d, T)
    assign()
    return placeOf[entry.name] or nil
end

-- The pockets, for the plate's marks: their places (PocketSpots'), their size, and which places their elements take,
-- { pocketLeft = { [i] = name }, pocketRight = ... } (kept: read it at once).
function Hub.Pockets(d, T, slots)
    local s = Hub.PocketSpots(d, T, slots)
    assign()
    return s, Hub.PocketSize(), taken
end

-- Where a pocket's place i stands (places: that pocket's); nil past them.
function Hub.PocketPoint(d, places, side, i)
    local s = places[i]
    if not s then
        return nil
    end
    return d.cx + POCKET_DIR[side] * s.dx, s.y
end

-- Which of its pocket's elements entry is, from 1.
local function pocketIndex(entry)
    local n = 1
    for _, e in ipairs(Hub.Entries()) do
        if e.name == entry.name then
            break
        end
        if e.side == entry.side then
            n = n + 1
        end
    end
    return n
end

-- Whether entry stands in a pocket of the plate's dome d (ns.Minimap.Dome's, onPlate) with no place left for it at
-- this size: it goes on the bar below the map, else nowhere (Ikar 2026-11-16: "they should be put into the bottom
-- bar, or if no space, removed altogether").
function Hub.Spills(entry, d, T, onPlate)
    if not (d and onPlate and Hub.POCKET_ANGLE[entry.side]) then
        return false
    end
    return Hub.PlaceOf(entry, d, T) == nil
end

-- Where an element round the map stands, in UIParent's units: on the ring at its angle, `radius` from the centre
-- (PinRadius's by default); in a pocket at its place there (onPlate: the plate's dome, which has the pockets), nil
-- with none (Spills), or along the ring from its lower corner.
function Hub.SlotPoint(entry, d, T, onPlate, radius)
    radius = radius or Hub.PinRadius(d)
    local side = entry.side
    if not Hub.POCKET_ANGLE[side] then
        return Geometry.Polar(d.cx, d.cy, radius, entry.angle)
    end
    if onPlate then
        local i = Hub.PlaceOf(entry, d, T)
        if not i then
            return nil
        end
        return Hub.PocketPoint(d, spots[side], side, i)
    end
    local step = math.deg(RING_STEP / radius)
    local n, a = pocketIndex(entry) - 1, Hub.POCKET_ANGLE[side]
    return Geometry.Polar(d.cx, d.cy, radius, side == "pocketLeft" and a + n * step or a - n * step)
end

-- ---------- Other displays ----------

-- Another addon's object changed: its type says where it lands; anything else is its button's alone.
local function attributeChanged(_, name, key)
    if key == "type" then
        Hub.Changed()
    else
        ns.InfoBar.Update(name)
    end
end

-- LibDataBroker, once it's there: our items published for other displays, then other addons' objects followed. The
-- library comes with another addon, at login or later (one loaded on demand): looked for at both.
local brokerWatched = false
local function watchBroker()
    local ldb = not brokerWatched and Hub.Broker()
    if not ldb then
        return
    end
    brokerWatched = true
    for _, name in ipairs(ownList) do
        publish(name)
    end
    -- called by the library from another addon's own code: under the handlers' guard (ns.Guarded)
    if type(ldb.RegisterCallback) == "function" then
        ns.Call(ldb.RegisterCallback, Hub, "LibDataBroker_DataObjectCreated", ns.Guarded(Hub.Changed))
        ns.Call(ldb.RegisterCallback, Hub, "LibDataBroker_AttributeChanged", ns.Guarded(attributeChanged))
    end
    return true
end

-- At login, once every addon has loaded: our items published for other displays, other addons' objects followed,
-- the first folder made, then the macros and what's made once for the player to try (UI/Hub/Seeds.lua). Each of the
-- three on its own, as the HUD's pieces start (Core/Main.lua): the folders' failing took the macros' start and what's
-- made once with it (the review of 2026-11-17).
function Hub.Start()
    started = true
    watchBroker()
    ns.On("ADDON_LOADED", function()
        if watchBroker() then
            Hub.Changed()
        end
    end)
    for _, step in ipairs({ ns.Folders.Setup, ns.Macros.Start, ns.Seeds.Run }) do
        ns.SafeCall(step)
    end
end

-- For the report and /kh status.
function Hub.Text()
    local lines = {}
    for _, e in ipairs(Hub.Entries()) do
        local obj = e.obj or {}
        lines[#lines + 1] = string.format("%s: %s %s, %s%s%s%s", e.name,
            e.side == "folder" and ("folder " .. tostring(e.folder)) or e.side, tostring(e.order),
            tostring(obj.type or (e.native and "minimap" or "item")),
            e.isCopy and (", copy of " .. tostring(e.of)) or e.ours and ", ours"
                or (e.native and ", native" or e.foreign and ", map button" or e.isMacro and ", macro"
                or e.isSeparator and ", separator" or ""),
            obj.menu and ", menu" or "", type(obj.OnClick) == "function" and ", click" or "")
        -- one whose drawing raised an error this session shows the question mark (UI/Hub/Buttons.lua's SafeFill)
        if ns.HubButtons.Failed(e.name) then
            lines[#lines] = lines[#lines] .. ", FAILED TO DRAW"
        end
    end
    local text = #lines > 0 and table.concat(lines, "\n") or "(none)"
    -- what had no room on the bar at the last layout, and where it is for now (UI/Hub/InfoBar.lua's fit)
    local out = {}
    for name, where in pairs(ns.InfoBar.Unfitted()) do
        out[#out + 1] = string.format("%s: %s", tostring(name), where and ("in " .. tostring(where)) or "nowhere")
    end
    table.sort(out)
    return text .. "\nfolders:\n" .. ns.Folders.Text() .. "\nmacros:\n" .. ns.Macros.Text() .. "\nseparators:\n"
        .. ns.Separators.Text() .. "\nno room on the bar:\n" .. (#out > 0 and table.concat(out, "\n") or "(none)")
end
