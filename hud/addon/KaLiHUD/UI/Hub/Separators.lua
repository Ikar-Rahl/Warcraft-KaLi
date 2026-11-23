-- Separators in a folder's list (Ikar 2026-11-16: "add a separator to the menu, draggable, deletable, added by folder
-- option"): a line between its members, added from the folder's menu, dragged as any of them (into a folder only),
-- deleted from its own right-click. A separator is a rule across its line, between its neighbours (Ikar 2026-11-16:
-- "separators, I thought about horizontal, not vertical"): the list running down, a horizontal one in its column;
-- running across, an upright one in its row; the lines made by the folder's count alone (UI/Hub/Folders.lua lays them
-- out).
-- Named, it is a section's title (Ikar 2026-11-20, of the sketch of the attributes: "C'est très bien"; "whatever we do
-- there, I want it to be recreatable by the user"): in a list of icons with their text running down, its name in gold
-- over a rule, above what follows it; elsewhere a rule, its name in its tooltip. Any separator can start a line of
-- its folder's list, whatever the count to a line: the next column when the list runs down, the next row across.
local _, ns = ...

local Separators = {}
ns.Separators = Separators

local Hub = ns.Hub
local L = ns.L

-- Their ids, and the list of them (UI/Hub/Hub.lua's Made, shared with the folders and the macros).
local made = Hub.Made("separators")
local GOLD, GREY = { 1, 0.82, 0 }, { 0.5, 0.5, 0.5 }

local objects = {}

local function all()
    return ns.db.separators
end

-- Whether a name is a separator's id, saved or not.
Separators.IsId = made.IsId

-- Every separator's id, in the order they were made: read it, never change it. The list is taken again when next
-- asked for once told to forget (Hub.Changed).
Separators.List, Separators.Forget = made.List, made.Forget

-- A new one in folder `folder`, at its 1-based place among the members (last without one); its id. Nil during a
-- fight, when the list holds still.
function Separators.Create(folder, at)
    if InCombatLockdown() or not ns.Folders.Get(folder) then
        return nil
    end
    return (ns.History.Do("create", nil, function()
        local id = Separators.Make()
        Hub.InsertIntoFolder(id, folder, at)
        return id
    end))
end

-- A new one's id, placed by its maker (UI/Hub/Seeds.lua, writing a whole folder at once): `spec` its title and
-- whether it starts a line ({ name, line }), a plain rule without.
function Separators.Make(spec)
    local id = made.NewId()
    local name = spec and type(spec.name) == "string" and spec.name ~= "" and spec.name or nil
    local line = spec and spec.line == true or nil
    all()[id] = (name or line) and { name = name, line = line } or true
    made.Forget()
    return id
end

-- Its title and line as `spec` says ({ name, line }), a plain rule without: what's made once (UI/Hub/Seeds.lua).
function Separators.Dress(id, spec)
    if all()[id] == nil then
        return
    end
    local name = spec and type(spec.name) == "string" and spec.name ~= "" and spec.name or nil
    local line = spec and spec.line == true or nil
    all()[id] = (name or line) and { name = name, line = line } or true
    objects[id] = nil
end

-- Its fields: true for a plain rule, else { name, line }.
local function fields(id)
    local s = all()[id]
    return type(s) == "table" and s or nil
end

-- Its title, nil for a plain rule.
function Separators.Name(id)
    local s = fields(id)
    return s and s.name or nil
end

-- Whether it starts a line of its folder's list (a column when the list runs down).
function Separators.StartsLine(id)
    local s = fields(id)
    return s ~= nil and s.line == true
end

local function set(id, key, v)
    local s = all()[id]
    if s == nil then
        return
    end
    if type(s) ~= "table" then
        s = {}
        all()[id] = s
    end
    s[key] = v
    if next(s) == nil then
        all()[id] = true
    end
    objects[id] = nil
    Hub.Changed()
end

-- Its title given (its blanks gone in the question, Folders.AskName), a blank one taking it away; one action to undo.
-- Not during a fight, when the list holds still.
function Separators.Rename(id, name)
    if InCombatLockdown() or not all()[id] then
        return
    end
    ns.History.Do("rename", id, set, id, "name", type(name) == "string" and name ~= "" and name or nil)
end

-- Starting a line of its folder's list, or not; one action to undo. Not during a fight.
function Separators.SetStartsLine(id, on)
    if InCombatLockdown() or not all()[id] then
        return
    end
    ns.History.Do("edit", id, set, id, "line", on and true or nil)
end

-- Its folder deleted: gone with it, the folder drawing the hub again.
function Separators.Drop(id)
    all()[id] = nil
    Hub.Unplace(id)
    objects[id] = nil
    made.Forget()
end

-- Deleted from its menu; not during a fight.
function Separators.Delete(id)
    if InCombatLockdown() or not all()[id] then
        return
    end
    ns.History.Do("delete", id, function()
        Separators.Drop(id)
        Hub.Changed()
    end)
end

-- Its saved data changed under it (UI/Hub/History.lua): made again as it's drawn.
function Separators.Refresh(id)
    objects[id] = nil
    made.Forget()
end

-- The separator as an element of the hub: no icon nor text, a line its folder's layout draws (its title over it);
-- its tooltip says what it is, its title, and that a right-click sets it. Its menu: its title, starting a line (a
-- column or a row, as its folder's list runs), deleting it; each held during a fight, when the list holds still.
function Separators.Object(id)
    local o = objects[id]
    if not o then
        local name = Separators.Name(id)
        o = { type = "data source", isSeparator = true, label = name or L.SEPARATOR, noHints = true }
        o.OnTooltipShow = function(tooltip)
            tooltip:SetText(name or L.SEPARATOR, GOLD[1], GOLD[2], GOLD[3])
            if name then
                tooltip:AddLine(L.SEPARATOR, 1, 1, 1)
            end
            -- (one in a locked folder sets nothing: UI/Hub/Seeds.lua)
            if not ns.Seeds.InLockedFolder(id) then
                tooltip:AddLine(L.HINT_SEPARATOR, GREY[1], GREY[2], GREY[3], true)
            end
            if not Hub.IsLocked() then
                tooltip:AddLine(ns.InCombat() and L.HINT_DRAG_COMBAT or L.HINT_DRAG_SLOT, GREY[1], GREY[2], GREY[3], true)
            end
        end
        o.menu = function()
            if ns.Seeds.InLockedFolder(id) then
                return { { text = L.FOLDER_LOCKED_DRAG, disabled = true, tooltip = L.FOLDER_LOCKED_TIP } }
            end
            local e = Hub.Entry(id)
            local across = e and e.folder and ns.Folders.Setting(e.folder, "flow") == "horizontal"
            return {
                { text = L.SEPARATOR_NAME, held = true, func = function()
                    ns.Folders.AskName(Separators.Name(id), function(text)
                        Separators.Rename(id, text)
                    end, L.SEPARATOR_NAME_ASK, true)
                end },
                { text = across and L.SEPARATOR_ROW or L.SEPARATOR_COLUMN, held = true, checked = function()
                    return Separators.StartsLine(id)
                end, func = function()
                    Separators.SetStartsLine(id, not Separators.StartsLine(id))
                end },
                { divider = true },
                { text = L.SEPARATOR_DELETE, held = true, func = function()
                    Separators.Delete(id)
                end },
            }
        end
        objects[id] = o
    end
    return o
end

-- For the report and /kh status.
function Separators.Text()
    local lines = {}
    for _, id in ipairs(Separators.List()) do
        local e = Hub.Entry(id)
        local name, line = Separators.Name(id), Separators.StartsLine(id)
        lines[#lines + 1] = string.format("%s: %s%s%s", id, e and ("folder " .. tostring(e.folder)) or "nowhere",
            name and (", « " .. name .. " »") or "", line and ", starts a line" or "")
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end
