-- KaLi HUD's own selection box in Edit Mode, along the foot of the screen so every bar, window and the minimap above
-- stays freely clickable and draggable. Clicking it opens KaLi HUD's Edit Mode dialog (UI/EditPanel.lua) and lets go
-- of Blizzard's or another addon's active selection, just as KaLi Quest's frame does.
local _, ns = ...

local EditFrame = {}
ns.EditFrame = EditFrame

local holder, selection
local editing, selected = false, false
local letGo = false

function EditFrame.Holder()
    if not holder then
        holder = CreateFrame("Frame", "KaLiHUDHolder", nil)
        holder:SetParent(UIParent)
        holder:SetFrameStrata("MEDIUM")
        holder:SetFrameLevel(80)
        holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        holder:SetHeight(26)
        holder:EnableMouse(false)
    end
    local h = ns.db and math.max(24, ns.Hub.BarHeight()) or 26
    holder:SetHeight(h)
    return holder
end

-- section: the dialog's section to open, as a status bar's box asks for the status bars'.
function EditFrame.Select(section)
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
        if selection then
            selection:ShowSelected()
        end
    end
    ns.EditPanel.Open(section)
end

function EditFrame.Deselect()
    if not selected then
        return
    end
    selected = false
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
    selection:SetSystem({ GetSystemName = function()
        return ns.TITLE
    end })
    -- The box comes with Blizzard's own scripts, which take its parent for one of Edit Mode's systems: a press would
    -- select the parent in Edit Mode's manager, a drag call the parent's OnDragStart and OnDragStop. The strip is the
    -- addon's own frame and has neither (dragging it raised an error), and it doesn't move: a press picks it, a drag
    -- does nothing.
    selection:SetScript("OnMouseDown", function()
        ns.SafeCall(EditFrame.Select)
    end)
    selection:SetScript("OnDragStart", nil)
    selection:SetScript("OnDragStop", nil)
    selection:Hide()
end

function EditFrame.Sync()
    EditFrame.Holder()
    if not selection then
        if not editing then
            return
        end
        buildSelection()
    end
    if editing then
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
    if not editing and ns.Frames.IsEditing() then
        EditFrame.Enter()
    end
    C_Timer.After(0, function()
        if editing and selection and selection:IsShown() then
            ns.SafeCall(EditFrame.Select)
        end
    end)
end

local hooked = false
function EditFrame.Start()
    if hooked then
        return
    end
    hooked = true
    local manager = EditModeManagerFrame
    if manager and type(manager.SelectSystem) == "function" then
        hooksecurefunc(manager, "SelectSystem", function()
            ns.SafeCall(EditFrame.Deselect)
        end)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            ns.SafeCall(EditFrame.Enter)
        end, EditFrame)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            ns.SafeCall(EditFrame.Exit)
        end, EditFrame)
        EventRegistry:RegisterCallback("EditModeExternal.hideDialog", function()
            if not letGo then
                ns.SafeCall(EditFrame.Deselect)
            end
        end, EditFrame)
        EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
            ns.SafeCall(ns.EditPanel.Snapshot)
        end, EditFrame)
    end
    if ns.Frames.IsEditing() then
        EditFrame.Enter()
    end
end