-- Macros: elements of the slot hub that run a macro on the player's click (Ikar 2026-11-16: "allowing the usage of
-- macros in the components. They could either reuse an existing macro, or write their own"; "I want both"): their own
-- commands, written in KaLi HUD (UI/Hub/MacroEditor.lua), or one of the game's macros, by name. Each is Blizzard's
-- SecureActionButtonTemplate, which runs it as an action button runs a macro (`type` "macro", its `macrotext` or its
-- `macro`): in combat too, on the player's click only, never on its own. The game lets no addon change a secure button
-- during a fight, so saving, placing, pasting and deleting wait for its end (greyed in the menus, UI/Hub/Menus.lua).
-- Copied from its menu, a macro is pasted beside another, into a folder or onto the bar. A note is one that runs
-- nothing (Ikar 2026-11-16, "may need an editor"): its text read in its tooltip, written in the same editor, which its
-- left click opens and shuts, as a folder's its list (Ikar 2026-11-17: "make the note open with left click"). A note
-- stays a note and a macro a macro: the editor's « Exécute » is a macro's alone ("Remove the execute from note").
-- A macro may have a right-click of its own and a tooltip of its own (Ikar 2026-11-17: "Add the right click, and the
-- tooltip"): its right-click's commands run by the same secure button on the right button (`*type2`, `macrotext2`,
-- the game's own suffix for it), while the padlock is shut; open, the HUD arranged, its right-click is the hub menu's
-- as every element's (UI/Hub/Menus.lua's RightIsHub), so they run nothing then. Its tooltip, written by the player,
-- shows in place of its commands. Each of its buttons may have a short description of one line (Ikar 2026-11-18:
-- "Add Description to the macro right and left button"), said in its tooltip by that button's icon.
local _, ns = ...

local Macros = {}
ns.Macros = Macros

local Hub = ns.Hub
local L = ns.L

-- Their ids, and the list of them (UI/Hub/Hub.lua's Made, shared with the folders and the separators).
local made = Hub.Made("macros")
-- A new one's icon, and one's that runs its own commands with none picked: the library's text glyph.
Macros.ICON = "AnimCreate_Icon_Text"
-- Its own commands: the game's own macros' limit, in letters (MACROFRAME_CHAR_LIMIT), its right-click's too; a note's
-- text, more, and its own tooltip's.
Macros.LETTERS = 255
Macros.NOTE_LETTERS = 1000
-- Each button's description: one short line (Ikar 2026-11-18: "Single line enty, short").
Macros.DESC_LETTERS = 40
-- A note's icon with none picked: the library's book.
Macros.NOTE_ICON = "LevelUp-Icon-Book"
local GOLD, BODY, WHITE, NOTE = { 1, 0.82, 0 }, { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.88, 0.88, 0.88 }
-- A click's hint, as the hub's (UI/Hub/Menus.lua's AddHints)
local HINT = { 0.5, 0.5, 0.5 }
-- Its commands in its tooltip, at most this many lines; a note's, more.
local BODY_LINES, NOTE_LINES = 8, 30

local objects = {}
-- Those whose button couldn't be set during a fight: set once it's over.
local unarmed = {}
-- What « Copier » took: a macro's fields, for this session.
local clipboard

local function all()
    return ns.db.macros
end

function Macros.Get(id)
    return all()[id]
end

function Macros.IsMacro(name)
    return all()[name] ~= nil
end

-- Whether a name is a macro's id, saved or not: its button is a secure one (HubButtons.Make).
Macros.IsId = made.IsId

-- Every macro's id, in the order they were made: read it, never change it. The list is taken again when next asked for
-- once told to forget (Hub.Changed).
Macros.List, Macros.Forget = made.List, made.Forget

-- ---------- The game's macros ----------

-- One of the game's macros by name: its index, its icon and its commands; nil when it has none of that name.
function Macros.Game(name)
    local index = type(name) == "string" and GetMacroIndexByName(name) or 0
    if not index or index == 0 then
        return nil
    end
    local _, icon, body = GetMacroInfo(index)
    return index, icon, body
end

-- The game's macros, the account's then this character's: { { name, icon, character } }.
function Macros.GameMacros()
    local list = {}
    local general, perCharacter = GetNumMacros()
    local consts = type(Constants) == "table" and Constants.MacroConsts
    local base = consts and consts.MAX_ACCOUNT_MACROS or 120
    local function add(i, character)
        local name, icon = GetMacroInfo(i)
        if name then
            list[#list + 1] = { name = name, icon = icon, character = character }
        end
    end
    for i = 1, general or 0 do
        add(i, false)
    end
    for i = base + 1, base + (perCharacter or 0) do
        add(i, true)
    end
    return list
end

-- ---------- Its secure button ----------

-- Its right-click's own commands, nil for none (a note has none).
function Macros.RightClick(id)
    local m = all()[id]
    local right = m and not m.note and m.right
    return type(right) == "string" and right ~= "" and right or nil
end

-- Its button as its fields say: a left click runs its own commands or the game's macro, nothing with neither, with
-- the game's gone, or while it's dragged (disarmed); a right click its right-click's commands, while the padlock is
-- shut. During a fight, once it's over.
function Macros.Arm(id)
    local b = ns.HubButtons.Get(id)
    if not b then
        return
    end
    if InCombatLockdown() then
        unarmed[id] = true
        return
    end
    unarmed[id] = nil
    local m = all()[id]
    local runs = m and not m.note
    local game = runs and m.macro and Macros.Game(m.macro) and m.macro or nil
    local text = runs and not m.macro and type(m.text) == "string" and m.text ~= "" and m.text or nil
    local right = Macros.RightClick(id)
    b:SetAttribute("macro", game)
    b:SetAttribute("macrotext", text)
    -- the left button, whatever the modifiers
    b:SetAttribute("*type1", (game or text) and not b.kaliDisarmed and "macro" or nil)
    -- the right one: its own commands, never the game's macro of the left one, which the secure button would read
    -- first (SECURE_ACTIONS.macro: "macro", then "macrotext"; ATTRIBUTE_NOOP rules one out); else the hub menu's
    b:SetAttribute("macrotext2", right)
    b:SetAttribute("macro2", right and (ATTRIBUTE_NOOP or "") or nil)
    b:SetAttribute("*type2", right and Hub.IsLocked() and not b.kaliDisarmed and "macro" or nil)
end

-- Every one set again: the padlock turned (Hub.SetLocked), which decides whose a right-click is.
function Macros.ArmAll()
    for id in pairs(all()) do
        Macros.Arm(id)
    end
end

-- While dragged it runs nothing, so the click that ends the drag doesn't run it; out of combat, as a drag is.
function Macros.Disarm(id, off)
    local b = ns.HubButtons.Get(id)
    if b then
        b.kaliDisarmed = off and true or nil
        Macros.Arm(id)
    end
end

-- A macro's new button (HubButtons.Make, out of combat): it acts on the click's release, as our buttons are
-- registered. An addon's secure button is told nothing of the press otherwise (SecureActionButton_OnClick), so it would
-- follow the ActionButtonUseKeyDown setting and act on the press alone.
function Macros.Wire(b, id)
    b:SetAttribute("useOnKeyDown", false)
    Macros.Arm(id)
end

-- ---------- As an element ----------

local function addBody(tooltip, body, note)
    local n, most, c = 0, note and NOTE_LINES or BODY_LINES, note and NOTE or BODY
    for line in tostring(body or ""):gmatch("[^\n]+") do
        n = n + 1
        if n > most then
            tooltip:AddLine("…", c[1], c[2], c[3])
            break
        end
        -- a note's lines wrap, a macro's commands don't
        tooltip:AddLine(line, c[1], c[2], c[3], note)
    end
    return n
end

-- What its buttons do, as the player described them (Ikar 2026-11-18: "Add Description to the macro right and left
-- button"), on one line by their icons as our items' hints: its left button's; its right's while that runs its own
-- commands (the padlock shut: open, its right-click is the hub menu's, whose hint follows).
local function describe(tooltip, id, m)
    local said = {}
    if m.leftDesc then
        said[#said + 1] = string.format(L.HINT_LEFT, m.leftDesc)
    end
    if m.rightDesc and Macros.RightClick(id) and not ns.HubMenus.RightIsHub(id) then
        said[#said + 1] = string.format(L.HINT_RIGHT, m.rightDesc)
    end
    if #said > 0 then
        tooltip:AddLine(table.concat(said, " · "), HINT[1], HINT[2], HINT[3], true)
    end
end

-- Its name, then what it runs: its commands, or the game's macro's (or that it's gone), then its right-click's under
-- the right button's icon (L.MACRO_RIGHT_LABEL); a note's text, then that its left click opens it; or, written by the
-- player, its own tooltip in place of all that. Under them, its buttons' descriptions.
local function tooltipOf(tooltip, id)
    local m = all()[id]
    tooltip:SetText(m and m.name or id, GOLD[1], GOLD[2], GOLD[3])
    if not m then
        return
    end
    if m.note then
        if addBody(tooltip, m.text, true) == 0 then
            tooltip:AddLine(L.NOTE_EMPTY, BODY[1], BODY[2], BODY[3], true)
        else
            tooltip:AddLine(L.HINT_NOTE, HINT[1], HINT[2], HINT[3], true)
        end
        return
    end
    if type(m.tip) == "string" and m.tip ~= "" then
        addBody(tooltip, m.tip, true)
        describe(tooltip, id, m)
        return
    end
    local right = Macros.RightClick(id)
    if m.macro then
        local index, _, body = Macros.Game(m.macro)
        if index then
            tooltip:AddLine(string.format(L.MACRO_GAME_TIP, m.macro), 0.8, 0.8, 0.8, true)
            addBody(tooltip, body)
        else
            tooltip:AddLine(string.format(L.MACRO_GAME_MISSING, m.macro), 1, 0.3, 0.3, true)
        end
    elseif addBody(tooltip, m.text) == 0 and not right then
        tooltip:AddLine(L.MACRO_EMPTY, BODY[1], BODY[2], BODY[3], true)
    end
    if right then
        tooltip:AddLine(L.MACRO_RIGHT_LABEL, 0.8, 0.8, 0.8)
        addBody(tooltip, right)
    end
    describe(tooltip, id, m)
end

-- The icon it wears: the library's it was given (a white glyph in the folders' colour), else the game's macro's own,
-- else the text glyph; the question mark for a game's macro that's gone.
local function dress(o, id)
    local m = all()[id]
    local look = ns.Hub.LookOf(m)
    o.label = m and m.name or id
    local atlas = m and (m.icon or m.note and Macros.NOTE_ICON or not m.macro and Macros.ICON) or nil
    local _, gameIcon = Macros.Game(m and m.macro)
    o.atlas = atlas
    o.icon = not atlas and (gameIcon or QUESTION_MARK_ICON or 134400) or nil
    local c = atlas and Hub.IsGlyph(atlas) and ns.Folders.TINT or WHITE
    o.iconR, o.iconG, o.iconB = c[1], c[2], c[3]
    -- a note's left click its editor's (openNote); a macro's its secure button's alone
    o.OnClick = m and m.note and o.openNote or nil
    -- its name by its icon, its icon alone or its name alone (Hub.LookOf)
    o.text = look ~= "icon" and o.label or nil
    if look == "name" then
        o.atlas, o.icon = nil, nil
    end
end

-- The macro as an element of the hub: a launcher, its icon and its name by it, as its look says (Ikar 2026-11-16:
-- "macro should display their name when they have one"); its name by its icon in a list with text.
function Macros.Object(id)
    local o = objects[id]
    if not o then
        o = { type = "launcher", isMacro = true }
        o.OnTooltipShow = function(tooltip)
            tooltipOf(tooltip, id)
        end
        o.menu = function()
            return Macros.Menu(id)
        end
        -- a note's left click opens its editor, a second one shuts it unsaved, as a folder's its list
        o.openNote = function(_, mouseButton)
            if mouseButton ~= "LeftButton" then
                return
            elseif ns.MacroEditor.Current() == id then
                ns.MacroEditor.Close(id)
            else
                ns.MacroEditor.Open(id)
            end
        end
        objects[id] = o
    end
    dress(o, id)
    return o
end

-- ---------- Making, changing, copying ----------

-- Its icon and name, its icon alone or its name alone (Hub.LOOKS): drawn again, the bar laid out anew (its width).
function Macros.SetLook(id, look)
    local m = all()[id]
    if m then
        ns.Hub.SetLook(m, look)
        if objects[id] then
            dress(objects[id], id)
        end
        ns.InfoBar.Update(id)
        ns.InfoBar.Request()
    end
end

local clean = Hub.CleanName

-- A text that says something, cut to `bytes`; nil for none or only blanks.
local function some(text, bytes)
    return type(text) == "string" and text:find("%S") and text:sub(1, bytes) or nil
end

-- A button's description: its words on one line, the blanks round them gone; nil for none.
local function oneLine(text)
    return type(text) == "string" and some((text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")), ns.DB.DESC_BYTES)
        or nil
end

-- A macro's fields as saved: a note runs nothing, its text longer, no right-click nor tooltip of its own (its text is
-- its tooltip), nor its buttons' descriptions.
local function fields(spec)
    local note = spec.note == true or nil
    local text = type(spec.text) == "string" and spec.text:sub(1, note and ns.DB.NOTE_BYTES or ns.DB.MACRO_BYTES) or nil
    local macro = not note and type(spec.macro) == "string" and spec.macro ~= "" and spec.macro or nil
    local right = not note and some(spec.right, ns.DB.MACRO_BYTES) or nil
    local tip = not note and some(spec.tip, ns.DB.NOTE_BYTES) or nil
    local leftDesc = not note and oneLine(spec.leftDesc) or nil
    local rightDesc = not note and oneLine(spec.rightDesc) or nil
    return spec.icon, text, macro, note, right, tip, leftDesc, rightDesc
end

-- A new macro, spec = { name, icon, text, macro, note, right, tip, leftDesc, rightDesc, seed }; its id. Where it
-- stands is the hub's. seed:
-- one made by KaLi HUD for a folder (UI/Hub/Seeds.lua), its key there.
function Macros.Create(spec)
    local id = made.NewId()
    local m = { name = clean(spec.name) or (spec.note and L.NOTE_NEW or L.MACRO_NEW) }
    m.icon, m.text, m.macro, m.note, m.right, m.tip, m.leftDesc, m.rightDesc = fields(spec)
    m.seed = type(spec.seed) == "string" and spec.seed or nil
    all()[id] = m
    objects[id] = nil
    made.Forget()
    -- a button left from one deleted before: set for this one
    Macros.Arm(id)
    Hub.Changed()
    return id
end

-- Its fields as the editor saves them; false during a fight, when its button can't change. (One made by KaLi HUD
-- stands in its locked folder, where nothing is edited: UI/Hub/Seeds.lua.)
function Macros.Update(id, spec)
    local m = all()[id]
    if not m or InCombatLockdown() then
        return false
    end
    m.name = clean(spec.name) or m.name
    m.icon, m.text, m.macro, m.note, m.right, m.tip, m.leftDesc, m.rightDesc = fields(spec)
    Macros.Arm(id)
    Hub.Changed()
    return true
end

-- One made by KaLi HUD as its locked folder makes it (UI/Hub/Seeds.lua's Sync): spec's name, icon and commands, its
-- icon and name by it.
function Macros.Restore(id, spec)
    local m = all()[id]
    if not m or InCombatLockdown() then
        return false
    end
    m.name = clean(spec.name) or m.name
    m.icon, m.text, m.macro, m.note, m.right, m.tip, m.leftDesc, m.rightDesc = fields(spec)
    m.seed, m.iconOnly, m.nameOnly = spec.seed, nil, nil
    Macros.Refresh(id)
    Hub.Changed()
    return true
end

-- Its icon, one of the library's, from its menu as a folder's: it wears it at once (a fight's end for its button).
function Macros.SetIcon(id, atlas)
    local m = all()[id]
    if m then
        m.icon = atlas
        if objects[id] then
            dress(objects[id], id)
        end
        ns.InfoBar.Update(id)
    end
end

-- The icon library next to its button, as a folder's (UI/Hub/IconPicker.lua).
function Macros.PickIcon(id)
    local m = all()[id]
    if not m then
        return
    end
    ns.IconPicker.Open(id, ns.HubButtons.Get(id), m.name, m.icon or (m.note and Macros.NOTE_ICON)
        or (not m.macro and Macros.ICON) or nil, function(atlas)
        Macros.SetIcon(id, atlas)
    end)
end

-- Its saved data changed under it (UI/Hub/History.lua, Restore): its button set and drawn as it says; gone, running
-- nothing, its editor and icon library closed.
function Macros.Refresh(id)
    objects[id] = nil
    made.Forget()
    Macros.Arm(id)
    if not all()[id] then
        ns.MacroEditor.Close(id)
        ns.IconPicker.Close(id)
    end
end

-- Gone, its button left running nothing.
function Macros.Delete(id)
    if not all()[id] or InCombatLockdown() then
        return
    end
    all()[id] = nil
    Hub.Unplace(id)
    Macros.Refresh(id)
    Hub.Changed()
end

function Macros.AskDelete(id)
    local m = all()[id]
    if not m then
        return
    end
    StaticPopupDialogs.KALIHUD_MACRO_DELETE = StaticPopupDialogs.KALIHUD_MACRO_DELETE or {
        text = L.MACRO_DELETE_ASK,
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = ns.Guarded(function(_, data)
            ns.History.Do("delete", data, Macros.Delete, data)
        end),
    }
    StaticPopup_Show("KALIHUD_MACRO_DELETE", m.name, nil, id)
end

-- Where a new or pasted one goes: just after `near` in its folder or its side of the bar, else last in `folder`, else
-- where the bar's menu was opened, `at` ({ x, y }; Ikar 2026-11-20: "it shoudl appear where the user put it., not on
-- the right"), else at the bar's right end, as a new folder.
local function place(id, folder, near, at)
    local e = near and Hub.Entry(near)
    if e and e.side == "folder" then
        local at
        for i, member in ipairs(Hub.InFolder(e.folder)) do
            if member.name == near then
                at = i + 1
            end
        end
        Hub.InsertIntoFolder(id, e.folder, at)
    elseif e and Hub.BAR[e.side] and e.side ~= "free" then
        Hub.InsertNear(id, e.side, near, not Hub.REVERSED[e.side])
    elseif folder and ns.Folders.Get(folder) then
        Hub.InsertIntoFolder(id, folder)
    elseif at then
        ns.HubDrag.PlaceAt(id, at[1], at[2])
    else
        Hub.Insert(id, "right", 1)
    end
end

-- A new one in `folder`, beside `near` or where the bar's menu was opened, `at` (UI/Hub/Menus.lua's entries), a note if
-- `note`, its editor opened by its button once the bar has laid it out, on the next frame; nil during a fight.
function Macros.New(folder, near, note, at)
    if InCombatLockdown() then
        return nil
    end
    local id = ns.History.Do("create", nil, function()
        local made = Macros.Create({ name = note and L.NOTE_NEW or L.MACRO_NEW, text = "", note = note })
        place(made, folder, near, at)
        return made
    end)
    -- after the bar's own redraw, asked for first (Hub.Changed); none for one whose making failed (History.Do)
    if id then
        ns.Later("macro editor " .. tostring(id), function()
            ns.MacroEditor.Open(id)
        end)
    end
    return id
end

-- « Copier »: its fields kept for « Coller », in any folder, on the bar or beside another.
function Macros.Copy(id)
    local m = all()[id]
    if m then
        clipboard = { name = m.name, icon = m.icon, text = m.text, macro = m.macro, note = m.note, right = m.right,
            tip = m.tip, leftDesc = m.leftDesc, rightDesc = m.rightDesc }
    end
end

function Macros.Clipboard()
    return clipboard
end

-- A copy of what was copied, placed as a new one; nil during a fight or with nothing copied.
function Macros.Paste(folder, near)
    if not clipboard or InCombatLockdown() then
        return nil
    end
    return (ns.History.Do("create", nil, function()
        local id = Macros.Create(clipboard)
        place(id, folder, near)
        return id
    end))
end

-- The entry pasting what was copied in `folder` or beside `near`, for a menu; nil with nothing copied.
function Macros.PasteEntry(folder, near)
    if not clipboard then
        return nil
    end
    return { text = string.format(L.MACRO_PASTE, clipboard.name), held = true, func = function()
        Macros.Paste(folder, near)
    end }
end

-- Its quick menu (a right-click): edit (the editor opens in combat too; only saving waits), its icon (as a folder's),
-- copy, paste beside it, delete. One in a locked folder (UI/Hub/Seeds.lua) is copied, nothing else.
function Macros.Menu(id)
    local copyEntry = { text = ns.G("CALENDAR_COPY_EVENT", "Copier"), func = function()
        Macros.Copy(id)
    end }
    if ns.Seeds.InLockedFolder(id) then
        return { copyEntry }
    end
    local entries = {
        { text = L.MACRO_EDIT, func = function()
            ns.MacroEditor.Open(id)
        end },
        { text = L.FOLDER_ICON, held = true, func = function()
            Macros.PickIcon(id)
        end },
        copyEntry,
    }
    entries[#entries + 1] = ns.Hub.LookEntry(function()
        return all()[id]
    end, function(look)
        Macros.SetLook(id, look)
    end)
    entries[#entries + 1] = Macros.PasteEntry(nil, id)
    entries[#entries + 1] = { divider = true }
    entries[#entries + 1] = { text = L.MACRO_DELETE, held = true, func = function()
        Macros.AskDelete(id)
    end }
    return entries
end

-- ---------- At login ----------

-- The game's macros changed: those running one are set and drawn again (one gone runs nothing, its icon the
-- question mark).
local function gameMacrosChanged()
    for id, m in pairs(all()) do
        if m.macro then
            Macros.Arm(id)
            if objects[id] then
                dress(objects[id], id)
            end
            ns.InfoBar.Update(id)
        end
    end
end

local function fightEnds()
    for id in pairs(unarmed) do
        Macros.Arm(id)
    end
end

function Macros.Start()
    ns.On("UPDATE_MACROS", function()
        ns.SafeCall(gameMacrosChanged)
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        ns.SafeCall(fightEnds)
    end)
end

-- For the report and /kh status.
function Macros.Text()
    local lines = {}
    for _, id in ipairs(Macros.List()) do
        local m = all()[id]
        local runs = m.macro and string.format("game macro %s%s", m.macro, Macros.Game(m.macro) and "" or " (gone)")
            or string.format("%s%d bytes", m.note and "note, " or "", #(m.text or ""))
        lines[#lines + 1] = string.format("%s: %s, %s, %s%s%s%s", id, m.name, runs, tostring(m.icon or "default"),
            m.right and string.format(", right-click %d bytes", #m.right) or "",
            m.tip and string.format(", tooltip %d bytes", #m.tip) or "", unarmed[id] and ", waits for the fight's end" or "")
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end
