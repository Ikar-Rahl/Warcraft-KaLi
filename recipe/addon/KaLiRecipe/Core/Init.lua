-- Who the addon is, for the code the KaLi addons share (Shared/, loaded next: events, guarded calls, the debug log),
-- then KaLi Recipe's own helpers. Everything else hangs from ns.
local _, ns = ...

ns.TITLE = "KaLi Recipe"
-- The debug log's chat prefix, and the slash command the shared code names.
ns.SHORT = "KR"
ns.SLASH = "/kr"

-- Internal and unstable, for KaLiRecipe_Tests and debugging. Not an API for other addons.
KaLiRecipeDev = { ns = ns }

-- What changed in the notebook's knowledge, redrawn once per frame wherever it shows: the notebook, the count lines,
-- the markers. Each UI piece adds itself with ns.OnChange.
local listeners = {}
function ns.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function ns.Changed()
    ns.Later("changed", function()
        for _, fn in ipairs(listeners) do
            ns.SafeCall(fn)
        end
    end)
end
