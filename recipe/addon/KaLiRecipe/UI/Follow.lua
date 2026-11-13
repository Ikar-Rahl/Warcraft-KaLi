-- « Suivre » (Ikar, 2026-11-09), one switch for all professions: on, the notebook opens with the professions window,
-- hangs on its side and moves with it, shows the profession open there and follows when it changes, and closes with
-- it. It only listens (TRADE_SKILL_SHOW, TRADE_SKILL_CLOSE) and anchors the notebook to the window: nothing is
-- written to Blizzard's frame. Closed by hand while docked, the notebook stays closed until the window closes.
local _, ns = ...

local Follow = {}
ns.Follow = Follow

-- Past Forever's profession tabs down the window's right edge.
local GAP = 48
local docked, closedByHand, closing = false, false, false

local function windowShown()
    return ProfessionsFrame ~= nil and ProfessionsFrame:IsShown()
end

-- On the window's right, or on its left when the screen runs out.
local function side()
    local right = ProfessionsFrame:GetRight()
    local screen = UIParent:GetRight()
    local width = ns.db.options.width
    if right and screen and right + GAP + width > screen then
        return "left"
    end
    return GAP
end

function Follow.Attach()
    if not (ns.db.options.follow and windowShown()) or closedByHand then
        return
    end
    local skill = ns.Game.OpenSkill()
    docked = true
    ns.Notebook.Dock(ProfessionsFrame, side())
    ns.Notebook.Show(skill)
end

local function detach(hide)
    if not docked then
        return
    end
    docked = false
    if hide then
        closing = true
        ns.Notebook.Close()
        closing = false
    end
    ns.Notebook.Dock(nil)
end

function Follow.Set(on)
    ns.db.options.follow = on and true or false
    closedByHand = false
    if on then
        Follow.Attach()
    else
        detach(false)
    end
    -- The options window's box says so, set from the notebook's own button too.
    ns.SafeCall(ns.Options.Changed)
end

-- The notebook was closed: by hand while docked, it stays closed until the window closes.
function Follow.NotebookHidden()
    if docked and not closing then
        closedByHand = windowShown()
        docked = false
        ns.Notebook.Dock(nil)
    end
end

function Follow.IsDocked()
    return docked
end

function Follow.Start()
    ns.On("TRADE_SKILL_SHOW", function()
        ns.Later("follow", Follow.Attach)
    end)
    for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
        ns.On(event, function()
            ns.Later("follow", function()
                if docked and ns.Notebook.IsShown() then
                    local skill = ns.Game.OpenSkill()
                    if skill then
                        ns.Notebook.Show(skill)
                    end
                elseif not docked then
                    Follow.Attach()
                end
            end)
        end)
    end
    ns.On("TRADE_SKILL_CLOSE", function()
        closedByHand = false
        detach(true)
    end)
end
