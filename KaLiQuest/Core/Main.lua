-- Startup. Saved data is first touched in this addon's own ADDON_LOADED, the earliest documented point, so
-- nothing written while files load is lost when the client restores the saved values.
local ADDON, ns = ...

local function onAddonLoaded(_, name)
    if name ~= ADDON then
        return
    end
    ns.Off("ADDON_LOADED", onAddonLoaded)
    ns.Debug.Init()
    ns.firstRun = KaLiQuestCharDB == nil
    local data, fixedOrReason = ns.DB.Load(KaLiQuestCharDB)
    if not data then
        ns.disabled = fixedOrReason
        ns.Say(string.format(ns.L.DB_REFUSED, fixedOrReason))
        ns.Debug.Log("init", "saved data refused: %s", fixedOrReason)
        return
    end
    KaLiQuestCharDB = data
    ns.db = data
    ns.Debug.Log("init", "%s %s loaded, data v%d, first run %s, repaired %d", ns.TITLE, ns.VERSION, data.version, tostring(ns.firstRun), fixedOrReason)
end
ns.On("ADDON_LOADED", onAddonLoaded)

ns.On("PLAYER_LOGIN", function()
    if not ns.db then
        return
    end
    local _, classFile = UnitClass("player")
    ns.categories = ns.Categories.New({
        locale = ns.LOCALE,
        ownClassName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile],
        areaName = function(areaID)
            return C_Map.GetAreaInfo(areaID)
        end,
    })
    ns.Tracking.Start()
    ns.Tracker.Start()
end)

-- Its own handler, so the options page and the compartment's entry exist even if the tracker fails to start.
ns.On("PLAYER_LOGIN", function()
    if ns.db then
        ns.Options.Register()
    end
end)
