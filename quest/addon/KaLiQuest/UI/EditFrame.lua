-- KaLi Quest's own frame in Edit Mode, Ikar's choice on 2026-11-13 ("One dialog, FlareUI's way"). The tracker is picked,
-- dragged and set up as one of Edit Mode's frames, with one dialog of its own (UI/EditPanel.lua), so neither Blizzard's
-- dialog for its tracker nor its text size shows any more. Blizzard's tracker stays the host (UI/Host.lua), with its
-- selection see-through.
--
-- Where it stands, for each Edit Mode layout: on Blizzard's tracker, as before, until it's moved in that layout; then
-- where it was dropped, held by its top corner on the side of the screen it's on, so it grows down and away from the
-- nearer edge. "Revenir à la position par défaut" puts it back on Blizzard's tracker, which keeps its own place in each
-- layout and among the frames down the right of the screen.
--
-- Built as LibEditMode builds a frame's selection, without the library: Blizzard's selection template with the
-- addon's own scripts, Blizzard's selected frame let go through its manager, as a click on another frame would.
local _, ns = ...

local EditFrame = {}
ns.EditFrame = EditFrame

-- The arrow keys move it 1, with Shift 10, as Blizzard's frames. Dropped within SNAP of the screen's edge or a line of
-- Edit Mode's grid, while its snapping is on, it lands on it.
EditFrame.SMALL_STEP, EditFrame.BIG_STEP, EditFrame.SNAP = 1, 10, 10

local holder, selection
local editing, selected, dragging = false, false, false
local letGo = false -- while the addon itself asks other dialogs to close, so it doesn't close its own

local function presets()
    local meta = Enum and Enum.EditModePresetLayoutsMeta
    return meta and meta.NumValues or 2
end

-- The active layout: Blizzard's presets by their place, the player's own by name. A layout renamed loses its place
-- here and goes back to following Blizzard's tracker.
function EditFrame.LayoutKey()
    if not (C_EditMode and C_EditMode.GetLayouts) then
        return "default"
    end
    local ok, info = pcall(C_EditMode.GetLayouts)
    if not ok or type(info) ~= "table" or type(info.activeLayout) ~= "number" then
        return "default"
    end
    local active = info.activeLayout
    if active <= presets() then
        return "preset" .. active
    end
    local layout = type(info.layouts) == "table" and info.layouts[active - presets()]
    if type(layout) == "table" and type(layout.layoutName) == "string" then
        return "custom:" .. layout.layoutName
    end
    return "layout" .. active
end

local function positions()
    return ns.db.editMode.positions
end

-- The active layout's own place, or nil while the tracker follows Blizzard's.
function EditFrame.Position()
    return ns.db and positions()[EditFrame.LayoutKey()] or nil
end

function EditFrame.Holder()
    if not holder then
        holder = CreateFrame("Frame", "KaLiQuestHolder", UIParent)
        holder:SetSize(1, 1)
        holder:SetClampedToScreen(true)
        holder:SetMovable(true)
        -- The game would otherwise keep a dragged frame's place in its own layout file, over the addon's.
        pcall(holder.SetDontSavePosition, holder, true)
    end
    return holder
end

function EditFrame.Apply()
    local f = EditFrame.Holder()
    f:ClearAllPoints()
    local p = EditFrame.Position()
    if p then
        f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    else
        ns.Host.Anchor(f)
    end
end

-- The size the tracker takes on screen: its rows' width and the scrollbar's room, zoomed, by the height set.
function EditFrame.SetSize(width, height)
    EditFrame.Holder():SetSize(width, height)
end

local function changed()
    if ns.EditPanel then
        ns.EditPanel.Changed()
    end
end

-- The edge or grid line nearest to one of the frame's edges, within SNAP: the shift that puts the edge on it.
local function nearest(edges, lines)
    local best
    for _, edge in ipairs(edges) do
        for _, line in ipairs(lines) do
            local shift = line - edge
            if math.abs(shift) <= EditFrame.SNAP and (not best or math.abs(shift) < math.abs(best)) then
                best = shift
            end
        end
    end
    return best or 0
end

local function gridLines(size, spacing)
    local lines, centre = { 0, size }, size / 2
    if spacing and spacing > 0 then
        for i = 0, math.floor(centre / spacing) do
            lines[#lines + 1] = centre + i * spacing
            lines[#lines + 1] = centre - i * spacing
        end
    end
    return lines
end

-- Edit Mode's snapping, when it's on: the screen's edges always, the grid's lines while the grid shows.
local function snap(left, top)
    local manager = EditModeManagerFrame
    if not (manager and manager.IsSnapEnabled and manager:IsSnapEnabled()) then
        return left, top
    end
    local grid = manager.Grid
    local spacing = grid and grid:IsShown() and grid.gridSpacing or nil
    local w, h = holder:GetWidth(), holder:GetHeight()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    left = left + nearest({ left, left + w }, gridLines(sw, spacing))
    top = top + nearest({ top, top - h }, gridLines(sh, spacing))
    return left, top
end

local function round(v)
    return math.floor(v + 0.5)
end

-- Keeps where the frame stands now as the active layout's place.
local function store(left, top)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local w = holder:GetWidth()
    local p
    if left + w / 2 > sw / 2 then
        p = { point = "TOPRIGHT", x = round(left + w - sw), y = round(top - sh) }
    else
        p = { point = "TOPLEFT", x = round(left), y = round(top - sh) }
    end
    positions()[EditFrame.LayoutKey()] = p
    EditFrame.Apply()
    changed()
end

-- From where it stands, even while it follows Blizzard's tracker. Not in combat: the quest items' buttons, which are
-- protected, hang from the rows.
function EditFrame.Nudge(dx, dy)
    if InCombatLockdown() or not holder then
        return
    end
    local left, top = holder:GetLeft(), holder:GetTop()
    if left and top then
        store(left + dx, top + dy)
    end
end

function EditFrame.HasPosition()
    return EditFrame.Position() ~= nil
end

function EditFrame.ResetPosition()
    if ns.db then
        positions()[EditFrame.LayoutKey()] = nil
        EditFrame.Apply()
        changed()
    end
end

-- Every layout's place, for the dialog's "Annuler les modifications".
function EditFrame.Positions()
    return ns.DeepCopy(positions())
end

function EditFrame.SetPositions(saved)
    ns.db.editMode.positions = ns.DeepCopy(saved)
    EditFrame.Apply()
end

local function onDragStart()
    if not (editing and selected) or InCombatLockdown() then
        return
    end
    dragging = true
    holder:StartMoving()
end

local function onDragStop()
    if not dragging then
        return
    end
    dragging = false
    holder:StopMovingOrSizing()
    pcall(holder.SetUserPlaced, holder, false)
    local left, top = holder:GetLeft(), holder:GetTop()
    if left and top then
        store(snap(left, top))
    end
end

-- Picked, as a frame of Blizzard's: Blizzard's selected frame and other addons' dialogs let go, through Edit Mode's
-- manager and the event LibEditMode's addons listen for, as a click on another frame would make them.
function EditFrame.Select()
    if not editing or InCombatLockdown() then
        return
    end
    if EventRegistry and EventRegistry.TriggerEvent then
        letGo = true
        pcall(EventRegistry.TriggerEvent, EventRegistry, "EditModeExternal.hideDialog")
        letGo = false
    end
    if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
    end
    if not selected then
        selected = true
        selection:ShowSelected()
    end
    ns.EditPanel.Open()
end

function EditFrame.Deselect()
    if not selected then
        return
    end
    selected = false
    if dragging then
        onDragStop()
    end
    if editing and selection then
        selection:ShowHighlighted()
    end
    ns.EditPanel.Close()
end

function EditFrame.IsSelected()
    return selected
end

function EditFrame.IsEditing()
    return editing
end

local function buildSelection()
    selection = CreateFrame("Frame", nil, EditFrame.Holder(), "EditModeSystemSelectionTemplate")
    selection:SetAllPoints()
    -- Its name, on the box once picked and in the tooltip before, as Blizzard's frames give theirs.
    selection:SetSystem({ GetSystemName = function()
        return ns.TITLE
    end })
    selection:SetScript("OnMouseDown", function()
        ns.SafeCall(EditFrame.Select)
    end)
    selection:SetScript("OnDragStart", function()
        ns.SafeCall(onDragStart)
    end)
    selection:SetScript("OnDragStop", function()
        ns.SafeCall(onDragStop)
    end)
    selection:Hide()
end

-- Shown in Edit Mode while the addon draws the tracker, the way Blizzard shows its frames' boxes.
function EditFrame.Sync()
    if not selection then
        if not (ns.Tracker.IsActive() and editing) then
            return
        end
        buildSelection()
    end
    if editing and ns.Tracker.IsActive() then
        if selected then
            selection:ShowSelected()
        else
            selection:ShowHighlighted()
        end
    else
        EditFrame.Deselect()
        selection:Hide()
    end
end

function EditFrame.Enter()
    editing = true
    ns.EditPanel.Snapshot()
    EditFrame.Sync()
end

function EditFrame.Exit()
    EditFrame.Deselect()
    editing = false
    EditFrame.Sync()
end

-- The options page's « Mode Édition » and the gear's (Ikar, 2026-11-13: "comme dans flare ... y mettre un bouton vers
-- le mode édition"), as Blizzard's own button on its options page goes there: the options close keeping what was set,
-- or Blizzard asks first when a change waits for « Appliquer », and then nothing more happens; Edit Mode opens through
-- ShowUIPanel, as /editmode opens it, and the tracker is picked once its box shows, so its dialog is open.
function EditFrame.OpenEditMode()
    if ns.CombatRefused() then
        return
    end
    local manager = EditModeManagerFrame
    if not manager then
        return
    end
    if manager.CanEnterEditMode and not manager:CanEnterEditMode() then
        if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
            UIErrorsFrame:AddExternalErrorMessage(ns.G("ERROR_SLASH_EDITMODE_CANNOT_ENTER",
                "Impossible de passer en mode édition pour le moment"))
        end
        return
    end
    local options = SettingsPanel
    if options and options:IsShown() and options.Close then
        pcall(options.Close, options, true)
        if options:IsShown() then
            return
        end
    end
    if not manager:IsShown() then
        ShowUIPanel(manager)
    end
    C_Timer.After(0, function()
        if editing and selection and selection:IsShown() then
            ns.SafeCall(EditFrame.Select)
        end
    end)
end

local hooked = false
function EditFrame.Hook()
    if hooked then
        return
    end
    hooked = true
    local manager = EditModeManagerFrame
    -- A frame of Blizzard's picked lets go of this one.
    if manager and type(manager.SelectSystem) == "function" then
        hooksecurefunc(manager, "SelectSystem", function()
            ns.SafeCall(EditFrame.Deselect)
        end)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditModeExternal.hideDialog", function()
            if not letGo then
                ns.SafeCall(EditFrame.Deselect)
            end
        end, EditFrame)
        -- Edit Mode's save: what "Annuler les modifications" goes back to from now.
        EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
            ns.SafeCall(ns.EditPanel.Snapshot)
        end, EditFrame)
    end
    -- Another layout: its own place.
    ns.On("EDIT_MODE_LAYOUTS_UPDATED", function()
        if ns.Tracker.IsActive() then
            ns.SafeCall(EditFrame.Apply)
            changed()
        end
    end)
    -- A fight stops a drag, as it stops Blizzard's.
    ns.On("PLAYER_REGEN_DISABLED", function()
        if dragging then
            ns.SafeCall(onDragStop)
        end
    end)
end
