-- Startup and logout. Saved data is first touched in this addon's own ADDON_LOADED, the earliest documented point, so
-- nothing written while files load is lost when the client restores the saved values; and last touched in
-- PLAYER_LOGOUT, the last event before the client writes the files.
local ADDON, ns = ...

local function onAddonLoaded(_, name)
    if name ~= ADDON then
        return
    end
    ns.Off("ADDON_LOADED", onAddonLoaded)
    ns.Debug.Init()
    local data, info = ns.DB.Open(KaLiRecipeDB, KaLiRecipeCopyDB)
    if not data then
        ns.disabled = info
        ns.Say(string.format(ns.L.DB_REFUSED, info))
        ns.Debug.Log("init", "saved data refused: %s", info)
        return
    end
    KaLiRecipeDB = data
    ns.db = data
    ns.dbInfo = info
    ns.firstRun = info.firstRun
    ns.Debug.Log("init", "%s %s loaded, data v%d, first run %s, repaired %d, set aside %d, restored %s, from the copy %d, copy refused %s",
        ns.TITLE, ns.VERSION, data.version, tostring(info.firstRun), info.fixed, info.setAside, tostring(info.restored ~= nil),
        info.recovered, tostring(info.copyRefused))
end
ns.On("ADDON_LOADED", onAddonLoaded)

-- Before the client writes the files: options back at their default go, the notebook says who wrote it, and this
-- character's file gets its copy, unless it holds one this version can't read, which then stays as it is.
ns.On("PLAYER_LOGOUT", function()
    if not ns.db then
        return
    end
    local now = time()
    ns.DB.BeforeSave(ns.db, now)
    if not ns.dbInfo.copyRefused then
        KaLiRecipeCopyDB = ns.DB.Copy(ns.db, ns.book and ns.book.me or ns.Game.Key(), now)
    end
end)

-- The model over the saved table, the generated data and the client.
function ns.NewBook(db, me)
    return ns.Model.New(db, {
        recipes = ns.RECIPES,
        items = ns.RECIPE_ITEMS,
        categories = ns.CATEGORIES,
        categoryNames = ns.CATEGORY_NAMES[ns.LOCALE] or ns.CATEGORY_NAMES.enUS,
    }, ns.Game.World, me)
end

ns.On("PLAYER_LOGIN", function()
    if not ns.db then
        return
    end
    ns.Game.Record(ns.db)
    ns.book = ns.NewBook(ns.db, ns.Game.Key())
    ns.Scan.AtLogin()
    ns.book:Invalidate()
end)

-- Each piece starts on its own, so one that fails leaves the others, and the options page exists whatever happens.
ns.On("PLAYER_LOGIN", function()
    if not ns.db then
        return
    end
    for _, start in ipairs({ ns.Options.Register, ns.Notebook.Start, ns.Follow.Start, ns.CountLines.Start, ns.Markers.Start,
        ns.MapPins.Start, ns.MinimapButton.Start }) do
        ns.SafeCall(start)
    end
    local ok, on = ns.SafeCall(ns.Tooltips.Start)
    ns.tooltipsOn = ok and on
    -- The one time startup speaks: the saved data needed a copy, or held something unreadable. Once chat is there.
    local info, L = ns.dbInfo, ns.L
    if info.restored then
        ns.Say(string.format(L.DB_RESTORED, info.restored.at and ns.Text.Date(info.restored.at) or "?",
            ns.Plural(info.restored.recipes, L.RECIPES_ONE, L.RECIPES_MANY)))
    elseif info.recovered > 0 then
        ns.Say(string.format(L.DB_RECOVERED, info.recovered))
    end
    if info.setAside > 0 then
        ns.Say(string.format(L.DB_SET_ASIDE, info.setAside))
    end
end)

-- The API check, last, once the notebook and its pieces are there to be tried; with the saved data refused too, as
-- KaLi Quest's, since what the game answers doesn't depend on it.
ns.On("PLAYER_LOGIN", ns.SelfCheck.AtLogin)
