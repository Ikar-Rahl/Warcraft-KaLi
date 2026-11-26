-- The slot hub's menus: an element's hub menu (its right-click: its own settings, then where it goes and how it shows),
-- the quick menu of what has no hub menu (a separator, the zone), the bar's own menu (the lock, Edit Mode, folders,
-- macros, and every element by category, shown or hidden), and the hint lines an element's tooltip ends with.
-- One right-click (Ikar 2026-11-17: "Let's focus on having a consistent right click", the Ctrl+right-click gone): the
-- padlock decides, as Edit Mode does. Shut, the HUD is used: a right-click is the element's own, ours its hub menu,
-- another addon's object or map button its addon's, untouched. Open, the HUD is arranged: a right-click on any
-- element opens its hub menu, nothing of the element's runs.
-- During a fight what would move, show or hide something on the bar or in a folder is greyed, its tooltip saying why
-- (Ikar 2026-11-16: "grey out any menu item that becomes unusable, in case the user tries to show, hide or move
-- anything during combat, with a clear tooltip"): the bar holds still then (UI/Hub/InfoBar.lua).
local _, ns = ...

local Menus = {}
ns.HubMenus = Menus

local Hub = ns.Hub
local L = ns.L

local ANGLES = {
    { 90, L.ANGLE_TOP }, { 45, L.ANGLE_TR }, { 0, L.ANGLE_RIGHT }, { 315, L.ANGLE_BR },
    { 270, L.ANGLE_BOTTOM }, { 225, L.ANGLE_BL }, { 180, L.ANGLE_LEFT }, { 135, L.ANGLE_TL },
}
local SHOW_MODES = { "always", "hover" }
local CATEGORIES = { "folders", "macros", "world", "time", "character", "stats", "skills", "social", "group", "system",
    "minimap", "addons" }

-- Usable out of a fight only; the menu asks again while it's open (a function: Blizzard's menu polls it), so one open
-- as a fight starts greys too.
local function outOfCombat()
    return not ns.InCombat()
end

-- Why it's greyed: the game's own words, then ours.
local function combatTooltip(tooltip, desc)
    GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(desc))
    GameTooltip_AddErrorLine(tooltip, ns.G("ERR_NOT_IN_COMBAT", "Impossible de faire ceci tout en combattant."), true)
    GameTooltip_AddNormalLine(tooltip, L.COMBAT_HELD, true)
end

-- An entry held during a fight: greyed then, with its tooltip when the menu is opened in one.
function Menus.Hold(desc)
    desc:SetEnabled(outOfCombat)
    if ns.InCombat() then
        desc:SetTooltip(combatTooltip)
    end
    return desc
end

-- A line under an entry's text as the pointer is on it; out of a fight, Hold's in one.
function Menus.Tip(desc, line)
    desc:SetTooltip(function(tooltip, d)
        GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(d))
        GameTooltip_AddNormalLine(tooltip, line, true)
    end)
    return desc
end

-- A slider in a menu (Ikar 2026-11-20: "Ça doit être un slider avec la limite max à 25"): the game's own, with its
-- steppers and its value on its right, in a frame of the menu's (Blizzard_Menu's CreateTemplate, a plain frame:
-- MenuTemplates has no slider). `spec` { min, max, get, set }: whole steps; each change set at once and the hub
-- drawn again, as a radio picked. Made once in each frame the menu takes from its pool and handed back hidden, its
-- callback gone (AddResetter), so a frame another menu takes after shows nothing of ours. Still during a fight when
-- `held`, as the entries Hold greys.
local SLIDER_W, SLIDER_H, SLIDER_NUMBER = 200, 30, 34
-- (the callback's owner: the menu's frame, its spec on it)
local function changed(frame, value)
    local spec = frame.kaliSpec
    if spec then
        ns.SafeCall(spec.set, math.floor(value + 0.5))
        ns.InfoBar.Forget()
        ns.InfoBar.Request()
    end
end
function Menus.Slider(desc, spec, held)
    local made = desc:CreateTemplate("Frame")
    made:AddInitializer(function(frame)
        local s = frame.kaliSlider
        if not s then
            s = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
            s:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            s:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SLIDER_NUMBER, 0)
            frame.kaliSlider = s
        end
        local right = MinimalSliderWithSteppersMixin.Label.Right
        s:Init(spec.get(), spec.min, spec.max, spec.max - spec.min, {
            [right] = CreateMinimalSliderFormatter(right) })
        frame.kaliSpec = spec
        s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, changed, frame)
        s:SetEnabled(not (held and ns.InCombat()))
        s:Show()
        return SLIDER_W, SLIDER_H
    end)
    made:AddResetter(function(frame)
        local s = frame.kaliSlider
        if s then
            s:UnregisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, frame)
            s:Hide()
        end
        frame.kaliSpec = nil
    end)
    return made
end

-- A `menu` list: { text, checked = bool or fn, radio, func, items = submenu, divider, title, held, tooltip, slider,
-- disabled }, or a function giving one; held: greyed during a fight (Menus.Hold); tooltip: a line under its text as
-- the pointer is on it; slider: Menus.Slider's spec; disabled: greyed always, a line saying something, its tooltip
-- more. A box or a radio picked has the hub drawn again (a folder's settings).
function Menus.AddEntries(desc, entries)
    if type(entries) == "function" then
        entries = entries()
    end
    for _, e in ipairs(type(entries) == "table" and entries or {}) do
        local made
        if e.divider then
            desc:CreateDivider()
        elseif e.slider then
            Menus.Slider(desc, e.slider, e.held)
        elseif e.title then
            desc:CreateTitle(e.title)
        elseif e.items then
            made = desc:CreateButton(e.text)
            Menus.AddEntries(made, e.items)
        elseif e.checked ~= nil then
            local function isOn()
                if type(e.checked) == "function" then
                    return e.checked() and true or false
                end
                return e.checked and true or false
            end
            local function pick()
                if e.func then
                    ns.SafeCall(e.func)
                end
                -- the player's own choice (a clock by twelve hours, a folder's name alone): each item of the bar its
                -- own width again, as when he arranges it (UI/Hub/InfoBar.lua's places)
                ns.InfoBar.Forget()
                ns.InfoBar.Request()
            end
            if e.radio then
                made = desc:CreateRadio(e.text, isOn, ns.Guarded(pick))
            else
                made = desc:CreateCheckbox(e.text, isOn, ns.Guarded(pick))
            end
        else
            made = desc:CreateButton(e.text, function()
                if e.func then
                    ns.SafeCall(e.func)
                end
            end)
        end
        if made and e.tooltip then
            Menus.Tip(made, e.tooltip)
        end
        if made and e.disabled then
            made:SetEnabled(false)
        end
        if made and e.held then
            Menus.Hold(made)
        end
    end
end

-- What a menu's entry does is run under the handlers' guard (ns.Guarded), as a frame's scripts: an error there went
-- to the game alone, and the addon's log and report never had it (the review of 2026-11-18).
local function lockBox(root)
    Menus.Hold(root:CreateCheckbox(L.SLOTS_LOCKED, Hub.IsLocked, ns.Guarded(function()
        Hub.SetLocked(not Hub.IsLocked())
    end)))
end

-- `fn(...)` as one action of the player's, undone from the bar's menu (UI/Hub/History.lua): a menu's func.
local function act(kind, name, fn, ...)
    local args = { n = select("#", ...), ... }
    return ns.Guarded(function()
        ns.History.Do(kind, name, fn, unpack(args, 1, args.n))
    end)
end

-- The hub menu of one element (ours, an addon's, a Blizzard widget, a map button, a folder): its own settings first,
-- then going left or right, the folder it goes into (or a new one), its angle on the ring, whether it
-- shows always or on hover round the map; back as it comes for one KaLi HUD brings (UI/Hub/Seeds.lua: ours here, a
-- folder's or a macro's in its own entries), back to its default place for any other; a map button can be left to its
-- addon. What moves it is one action each, undone from the bar's menu.
function Menus.Element(name, root)
    local entry = Hub.Entry(name)
    if not entry then
        return
    end
    local obj = entry.obj or {}
    root:CreateTitle(Hub.Label(name, obj))
    -- In a locked folder (UI/Hub/Seeds.lua), nothing of it changes nor moves (Ikar 2026-11-23: "No edit, no reset"):
    -- its own entries alone (one of ours, how it reads; a macro, copying it), then that a drag takes a copy out.
    if ns.Seeds.InLockedFolder(name) then
        if obj.menu and not entry.isSeparator then
            Menus.AddEntries(root, obj.menu)
            root:CreateDivider()
        end
        Menus.AddEntries(root, { { text = L.FOLDER_LOCKED_DRAG, disabled = true, tooltip = L.FOLDER_LOCKED_TIP } })
        root:CreateDivider()
        lockBox(root)
        return
    end
    if obj.menu then
        Menus.AddEntries(root, obj.menu)
        root:CreateDivider()
    end
    -- « Affichage », as a folder and a macro have: its icon and its text, its icon alone or its text alone, on the bar
    -- (Hub.SetItemLook); one action each, undone from the bar's menu. A launcher's text is its name.
    if Hub.HasLook(name) then
        local lookSub = Menus.Hold(root:CreateButton(L.LOOK))
        local launcher = obj.type == "launcher"
        for _, look in ipairs(Hub.ITEM_LOOKS) do
            local text = look == "icon" and L.LOOK_icon or look == "both" and (launcher and L.LOOK_both or L.LOOK_value_both)
                or (launcher and L.LOOK_name or L.LOOK_value)
            lookSub:CreateRadio(text, function()
                return (Hub.ItemLook(name) or Hub.DefaultLook(obj)) == look
            end, act("edit", name, Hub.SetItemLook, name, look))
        end
    end
    if entry.side ~= "hidden" then
        Menus.Hold(root:CreateButton(L.GO_LEFT, act("move", name, Hub.Step, name, -1)))
        Menus.Hold(root:CreateButton(L.GO_RIGHT, act("move", name, Hub.Step, name, 1)))
    end
    -- Where it goes from its menu: into a folder, any but itself and those it holds, or a new one. The bar's sides, the
    -- map's pockets and ring and « Masqué » were listed here too (Ikar 2026-11-17: "remove all the send to, except
    -- folders. They are noisy options"): its place on the bar or round the map is the drag's, the padlock open, and
    -- « Supprimer », below, takes it off the HUD.
    local placeSub = Menus.Hold(root:CreateButton(L.HUB_POSITION))
    for _, id in ipairs(ns.Folders.List()) do
        if ns.Folders.CanHold(id, name) then
            placeSub:CreateRadio(string.format(L.SIDE_folder, ns.Folders.Get(id).name), function()
                local cur = Hub.Entry(name)
                return cur and cur.side == "folder" and cur.folder == id
            end, ns.Guarded(function()
                ns.History.Do("move", name, Hub.InsertIntoFolder, name, id)
                -- gone from under the pointer: lit where it went, its folder's button when its list is shut
                ns.InfoBar.Flash(name)
            end))
        end
    end
    placeSub:CreateButton(L.FOLDER_CREATE, ns.Guarded(function()
        Hub.NewFolder(name)
    end))
    if entry.side == "ring" then
        local angleSub = Menus.Hold(root:CreateButton(L.HUB_ANGLE))
        for _, preset in ipairs(ANGLES) do
            local deg = preset[1]
            angleSub:CreateRadio(string.format("%s (%d°)", preset[2], deg), function()
                local cur = Hub.Entry(name)
                return cur and math.abs(((cur.angle - deg + 180) % 360) - 180) <= 12
            end, act("move", name, Hub.Save, name, { angle = deg }))
        end
    end
    if Hub.ROUND[entry.side] then
        local visSub = Menus.Hold(root:CreateButton(L.HUB_VISIBILITY))
        for _, mode in ipairs(SHOW_MODES) do
            visSub:CreateRadio(mode == "always" and L.SHOW_ALWAYS or L.SHOW_HOVER, function()
                local cur = Hub.Entry(name)
                return cur and cur.show == mode
            end, ns.Guarded(function()
                Hub.Save(name, { show = mode })
            end))
        end
    end
    if Hub.IsOurs(name) then
        -- asked first (ns.Ask), the question saying what comes back, as its tooltip
        Menus.Hold(Menus.Tip(root:CreateButton(ns.G("RESET", "Réinitialiser"), ns.Guarded(function()
            ns.Ask(string.format(L.RESET_ASK, Hub.Label(name, obj), L.ITEM_RESET_TIP),
                act("reset", name, ns.Seeds.ResetItem, name))
        end)), L.ITEM_RESET_TIP))
    elseif Hub.Saved(name) ~= nil and not ns.Seeds.IsBundled(name) and not entry.isCopy then
        placeSub:CreateDivider()
        placeSub:CreateButton(ns.G("RESET", "Réinitialiser"), act("move", name, Hub.Reset, name))
    end
    if entry.foreign then
        Menus.Hold(root:CreateButton(L.BUTTON_LEAVE, ns.Guarded(function()
            ns.Collect.Leave(name)
        end)))
    end
    -- Deleted (Ikar 2026-11-17: "make all components deletable"): a folder and a macro from their own entries, above
    -- (asked first, gone with what they hold), a separator from its own menu; any other isn't ours to destroy (ours,
    -- another addon's, Blizzard's): taken off the HUD, out of its folder, the bar's menu bringing it back where it was,
    -- and so « Retirer », not « Supprimer » (the review of 2026-11-20); a folder KaLi HUD made too (its own entries).
    -- A copy (UI/Hub/Hub.lua's) is deleted: its item stays in its folder.
    if entry.isCopy then
        Menus.Hold(root:CreateButton(L.COPY_DELETE, act("delete", name, Hub.DeleteCopy, name)))
    elseif not (entry.isFolder or entry.isMacro or entry.isSeparator) and entry.side ~= "hidden" then
        Menus.Hold(Menus.Tip(root:CreateButton(L.ITEM_REMOVE, act("hide", name, Hub.SetShown, name, false)),
            L.DELETE_HIDES_TIP))
    end
    root:CreateDivider()
    lockBox(root)
end

function Menus.OpenElement(owner, name)
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner, ns.Guarded(function(_, root)
        Menus.Element(name, root)
    end))
end

-- The quick menu of what has no hub menu, its own entries alone: a separator's, the zone's.
function Menus.OpenQuick(owner, name, obj)
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner, ns.Guarded(function(_, root)
        root:CreateTitle(Hub.Label(name, obj))
        Menus.AddEntries(root, obj.menu)
    end))
end

-- Whether an element's right-click is another addon's: its LibDataBroker object (its OnClick takes the right button, as
-- Titan Panel passes it) or its map button (its own frame's scripts). Blizzard's widgets have none of their own: the
-- tracking button and the addon compartment take the left button alone, the calendar's right does what its left does
-- (GameTimeFrameMixin:OnClick), the mail and the day/night ring take no click. Nor has another addon's object with no
-- click at all, a plain readout: its right-click did nothing while shut, its hub menu out of reach (the review of
-- 2026-11-17), so it opens the hub menu as ours do.
function Menus.Theirs(e)
    if e.foreign then
        return true
    elseif e.ours or e.native or e.isFolder or e.isMacro or e.isSeparator then
        return false
    end
    return type(e.obj) == "table" and type(e.obj.OnClick) == "function"
end

-- Whether a right-click on an element opens its hub menu: open, every element's but the zone's (it has none) and a
-- separator's (its own menu); shut, every one whose right-click isn't another addon's nor a macro's own (its
-- right-click's commands, UI/Hub/Macros.lua).
function Menus.RightIsHub(name)
    local e = Hub.Entry(name)
    if not e or e.isSeparator or Hub.IsFixed(name) then
        return false
    end
    local own = Menus.Theirs(e) or e.isMacro and ns.Macros.RightClick(name) ~= nil
    return not Hub.IsLocked() or not own
end

-- What kind of element it is, in the player's language (Ikar 2026-11-17: "add a type field, can you propose names
-- for each?"): ours an information; another addon's object its launcher or its information (LibDataBroker's own two
-- kinds), its map button; Blizzard's widget; a folder, a macro, a note, a separator. None says « (KaLi HUD) », those
-- KaLi HUD brought neither (Ikar 2026-11-17: "remove the (kali hud) from type"). Nil for no element.
function Menus.TypeOf(name)
    local e = name and Hub.Entry(name)
    if not e then
        return nil
    end
    if e.isCopy then
        return L.TYPE_COPY
    elseif e.ours then
        return L.TYPE_OURS
    elseif e.isFolder then
        -- (Ikar 2026-11-23: "The type shoudl be also "locked folder"")
        return ns.Seeds.IsLockedFolder(name) and L.TYPE_LOCKED_FOLDER or L.TYPE_FOLDER
    elseif e.isMacro then
        local m = ns.Macros.Get(name)
        return m and m.note and L.TYPE_NOTE or L.TYPE_MACRO
    elseif e.isSeparator then
        return L.TYPE_SEPARATOR
    elseif e.native then
        return L.TYPE_NATIVE
    elseif e.foreign then
        return L.TYPE_MAP_BUTTON
    end
    return type(e.obj) == "table" and e.obj.type == "launcher" and L.TYPE_LAUNCHER or L.TYPE_ADDON_INFO
end

-- Its type's line (TypeOf), muted, the tooltip's last (Ikar 2026-11-17: "make type last").
function Menus.AddType(tooltip, name)
    local kind = Menus.TypeOf(name)
    if kind then
        tooltip:AddLine(string.format(L.TYPE_LINE, kind), 0.6, 0.6, 0.6, true)
    end
end

-- The lines under an element's tooltip (ours, another addon's, a Blizzard widget's): what its right-click opens when
-- it's the hub menu, but on one of ours whose tooltip names its right-click itself (its icon, « options »: those with a
-- menu of their own, which comes first in it); while open, that it drags, after the fight during one; its type last.
-- Its own hints come last in its own tooltip, its left button's before its right's, so the buttons' hints follow one
-- another, left then right, in every tooltip (Ikar 2026-11-17: "make sure bouttons always come one after another,
-- same order, left then right").
function Menus.AddHints(tooltip, name)
    local e = name and Hub.Entry(name)
    if e and Menus.RightIsHub(name) and not (e.ours and type(e.obj) == "table" and e.obj.menu) then
        tooltip:AddLine(L.HINT_HUB_MENU, 0.5, 0.5, 0.5, true)
    end
    if not Hub.IsLocked() then
        tooltip:AddLine(ns.InCombat() and L.HINT_DRAG_COMBAT or L.HINT_DRAG_SLOT, 0.5, 0.5, 0.5, true)
    end
    Menus.AddType(tooltip, name)
end

local function categoryOf(entry)
    if entry.isFolder then
        return "folders"
    elseif entry.isMacro then
        return "macros"
    elseif entry.native then
        return "minimap"
    end
    return entry.ours and entry.obj.category or "addons"
end

local function byLabel(a, b)
    return ns.TextLess(a.label, b.label)
end

-- Undo and redo, each saying what (UI/Hub/History.lua): greyed with none, and during a fight.
local function historyEntries(root)
    local undo, redo = ns.History.Next()
    local u = Menus.Hold(root:CreateButton(undo and string.format(L.UNDO_WHAT, undo) or L.UNDO, ns.Guarded(function()
        ns.History.Undo()
    end)))
    local r = Menus.Hold(root:CreateButton(redo and string.format(L.REDO_WHAT, redo) or L.REDO, ns.Guarded(function()
        ns.History.Redo()
    end)))
    if not undo then
        u:SetEnabled(false)
    end
    if not redo then
        r:SetEnabled(false)
    end
end

-- The bar's own menu (right-click on empty bar space or on the padlock): undo and redo, the lock, Edit Mode, a new
-- folder, a new macro, the one copied pasted, the map buttons left to their addons, then every element by category,
-- ticked while shown (hidden or shown again, one action each); where each goes is in its own menu. A folder, a macro
-- or a note made from it goes where it was opened (UI/Hub/Drag.lua's PlaceAt).
-- The bar's menu: what it shows first, by category, its main use; then the padlock, Edit Mode and what can be made
-- there; undo and redo last, greyed while there is none (the review of 2026-11-20: they opened it, greyed, above all).
local shownEntries, shownBox
function Menus.Bar(_, root)
    local at = { ns.HubDrag.CursorUI() }
    root:CreateTitle(L.BAR_TITLE)
    shownEntries(root)
    root:CreateDivider()
    lockBox(root)
    Menus.Hold(root:CreateButton(ns.G("HUD_EDIT_MODE_MENU", "Mode Édition"), function()
        ns.SafeCall(ns.EditFrame.OpenEditMode)
    end))
    Menus.Hold(root:CreateButton(L.FOLDER_CREATE, ns.Guarded(function()
        Hub.NewFolder(nil, at)
    end)))
    Menus.Hold(root:CreateButton(L.MACRO_CREATE, ns.Guarded(function()
        ns.Macros.New(nil, nil, nil, at)
    end)))
    Menus.Hold(root:CreateButton(L.NOTE_CREATE, ns.Guarded(function()
        ns.Macros.New(nil, nil, true, at)
    end)))
    local paste = ns.Macros.PasteEntry()
    if paste then
        Menus.Hold(root:CreateButton(paste.text, ns.Guarded(paste.func)))
    end
    local left = {}
    for button in pairs(ns.db.buttonsLeft) do
        left[#left + 1] = button
    end
    if #left > 0 then
        table.sort(left, ns.TextLess)
        local sub = Menus.Hold(root:CreateButton(L.BUTTONS_LEFT))
        for _, button in ipairs(left) do
            sub:CreateButton(string.format(L.TAKE_BACK, button), ns.Guarded(function()
                ns.Collect.TakeBack(button)
            end))
        end
    end
    -- The options and a bug report, as KaLi Quest's gear's menu has them (Ikar 2026-11-24: "KaLi hud need an option
    -- and report bug in the right click menu, like the kali quests"); in a fight the options page says it can't open
    root:CreateDivider()
    Menus.Hold(root:CreateButton(ns.G("OPTIONS", "Options"), function()
        ns.SafeCall(ns.Options.Open)
    end))
    Menus.Hold(root:CreateButton(L.REPORT_TITLE, function()
        ns.SafeCall(ns.Report.Open)
    end))
    root:CreateDivider()
    historyEntries(root)
end

-- Each category's elements, a box each: shown or taken off the HUD, one action each.
function shownEntries(root)
    local groups = {}
    for _, entry in ipairs(Hub.Entries()) do
        -- (not a copy, deleted from its own menu, nor what a locked folder holds, its folder's box standing for it)
        local locked = ns.Seeds.InLockedFolder(entry.name) or entry.ours and ns.Seeds.HomeLocked(entry.obj)
        if not Hub.IsFixed(entry.name) and not entry.isSeparator and not entry.isCopy and not locked then
            local cat = categoryOf(entry)
            groups[cat] = groups[cat] or {}
            table.insert(groups[cat], { name = entry.name, label = Hub.Label(entry.name, entry.obj) })
        end
    end
    -- the macros left out (Ikar 2026-11-20: "the emote huge list when you right click on the bar. The whole emote
    -- category shoudl go, keep only the folder"): one is deleted, never hidden, so its tick did nothing a folder's
    -- doesn't; « Emote » stays among the folders
    -- « Add-ons » or « Suite » gone (renamed, it is the player's), unticked among the folders, by name: ticked, made
    -- again as made (Ikar 2026-11-20: "and I still don't see how to bring back my emote folder")
    for _, gone in ipairs(ns.Seeds.Missing()) do
        groups.folders = groups.folders or {}
        table.insert(groups.folders, { label = gone.name, role = gone.role })
    end
    for _, cat in ipairs(CATEGORIES) do
        local list = cat ~= "macros" and groups[cat]
        if list then
            table.sort(list, byLabel)
            local sub = root:CreateButton(L["CAT_" .. cat])
            for _, item in ipairs(list) do
                if item.role then
                    Menus.Hold(sub:CreateCheckbox(item.label, function()
                        return false
                    end, ns.Guarded(function()
                        local id = ns.History.Do("create", nil, ns.Seeds.Restore, item.role)
                        if id then
                            ns.InfoBar.Flash(id)
                        end
                    end)))
                else
                    shownBox(sub, item)
                end
            end
        end
    end
end

-- An element's box in the bar's menu: shown, or taken off the HUD.
function shownBox(sub, item)
        Menus.Hold(sub:CreateCheckbox(item.label, function()
            local cur = Hub.Entry(item.name)
            return cur ~= nil and cur.side ~= "hidden"
        end, ns.Guarded(function()
            local cur = Hub.Entry(item.name)
            local show = cur ~= nil and cur.side == "hidden"
            ns.History.Do(show and "show" or "hide", item.name, Hub.SetShown, item.name, show)
            -- shown again where it was, often in a shut folder: lit there, so it's seen to have come
            if show then
                ns.InfoBar.Flash(item.name)
            end
        end)))
end
-- the menu's own making, as what its entries do
Menus.Bar = ns.Guarded(Menus.Bar)
