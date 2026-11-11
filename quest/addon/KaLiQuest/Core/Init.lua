-- Who the addon is, for the code the KaLi addons share (Shared/, loaded next: events, guarded calls, the debug log),
-- then KaLi Quest's own helpers. Everything else hangs from ns.
local _, ns = ...

ns.TITLE = "KaLi Quest"
-- The debug log's chat prefix, and the slash command the shared code names.
ns.SHORT = "KQ"
ns.SLASH = "/kq"

-- Internal and unstable, for KaLiQuest_Tests and debugging. Not an API for other addons.
KaLiQuestDev = { ns = ns }

local REASONS = {
    combat = function()
        return ns.G("ERR_NOT_IN_COMBAT", "In combat")
    end,
    empty = function()
        return ns.L.EMPTY_NAME
    end,
    missing = function()
        return ns.L.GROUP_GONE
    end,
    npe = function()
        return ns.L.NPE_REFUSED
    end,
    nothing = function()
        return ns.L.NOTHING_TO_UNDO
    end,
}

-- Says in chat why something was refused: a reason the model gives, or any text.
function ns.Refused(reason)
    local text = REASONS[reason]
    ns.Say(text and text() or reason)
end

-- One layout per frame, however many events asked for it. ns.Refresh is set once there's something to draw.
function ns.RequestRefresh()
    ns.Later("refresh", function()
        if ns.Refresh then
            ns.Refresh()
        end
    end)
end
