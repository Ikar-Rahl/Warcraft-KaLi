-- KaLi HUD's page in the game's options (Options > AddOns), reached from the addon compartment, /kh and /kh options.
-- As in KaLi Quest, all visual, margin and minimap settings live in Edit Mode's own dialog (UI/EditPanel.lua), with a
-- button here that opens Edit Mode directly on KaLi HUD; what the HUD does and sounds like is on a page under this
-- one, and which of its parts are on is in both places. It's a page of the addon's own (Shared/Page.lua), in the look
-- of Blizzard's: nothing of it goes into the game's own lists of settings, where the game blames an addon for what its
-- own pages then do (KaLi Quest, 2026-11-12).
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local page

-- An option changed here: the info bar's items and the HUD drawn again, and the Edit Mode dialog's row of it while that
-- shows (the four parts' switches are in both: Ikar 2026-11-19, "keep 4, but duplicate in the settings too").
local function changed()
    ns.SafeCall(ns.Items.Update)
    ns.SafeCall(ns.ApplyAll)
    ns.SafeCall(ns.EditPanel.Changed)
    -- (the attributes' lines and cards kept open read again: the mana's regeneration a second's or not)
    if ns.Stats and ns.Stats.Refresh then
        ns.SafeCall(ns.Stats.Refresh)
    end
end

-- An option's row, by its key: a check box, a slider between its range's ends, a choice among values. Each sets its
-- option when it differs, and back to its default with the page's reset.
local function check(key, name, tip)
    return { kind = "check", key = key, name = name, tip = tip,
        get = function()
            return ns.db.options[key] == true
        end,
        set = function(value)
            if (ns.db.options[key] == true) ~= value then
                ns.db.options[key] = value
                changed()
            end
        end }
end
local function slider(key, name, step, format, tip)
    local range = ns.DB.RANGES[key]
    return { kind = "slider", key = key, name = name, tip = tip, min = range[1], max = range[2], step = step,
        format = format,
        get = function()
            return ns.db.options[key]
        end,
        set = function(value)
            if ns.db.options[key] ~= value then
                ns.db.options[key] = value
                changed()
            end
        end }
end
-- A sound among its kind's, or none: one picked plays as it would; one put back by the reset doesn't. A button by it
-- plays the one picked again (Ikar 2026-11-20: "the two sounds shoudl have a play button next"), greyed on « Aucun »,
-- its tooltip the game's words for it (the Cooldown Viewer's).
local function sound(key, name, sounds, order, prefix, tip)
    local values = { { "none", L.SOUND_none } }
    for _, id in ipairs(order) do
        values[#values + 1] = { id, L[prefix .. id] }
    end
    return { kind = "choice", key = key, name = name, tip = tip, values = values,
        playTip = ns.G("COOLDOWN_VIEWER_SETTINGS_ALERT_MENU_PLAY_SAMPLE", L.SOUND_PLAY),
        play = function()
            ns.PlaySoundOf(sounds, ns.db.options[key], true)
        end,
        canPlay = function()
            return sounds[ns.db.options[key]] ~= nil
        end,
        get = function()
            return ns.db.options[key]
        end,
        set = function(value, quiet)
            if ns.db.options[key] ~= value then
                ns.db.options[key] = value
                if not quiet then
                    ns.PlaySoundOf(sounds, value, true)
                end
                changed()
            end
        end }
end
-- A page's reset: each of its options' rows back to its default, asked first (ns.Ask), the page named.
local function reset(list, page)
    return { kind = "button", name = L.OPTIONS_DEFAULTS, text = ns.G("RESET", "Réinitialiser"), tip = L.OPTIONS_DEFAULTS_TIP,
        click = function()
            ns.Ask(string.format(L.OPTIONS_DEFAULTS_ASK, page), function()
                for _, row in ipairs(list) do
                    if row.key then
                        row.set(ns.DB.DEFAULTS[row.key], true)
                    end
                end
            end)
        end }
end

local function seconds(value)
    return value == 0 and L.OFF or string.format(L.SECONDS, value)
end

-- The page's rows, in its order, asked for when it first shows: the way to Edit Mode, where the look is set; which of
-- the HUD's parts are on, as in Edit Mode's dialog; then a bug's report, which carries the addon's state (its row of
-- its own gone, Ikar 2026-11-20: "Diagnose can be removed, it is i nthe report bug"). Each page as tall as
-- the game's options show without scrolling, which a page of an addon's own doesn't: hence the pages under it.
local function rows()
    return {
        { kind = "header", text = L.OPTIONS_LOOK },
        { kind = "button", name = L.OPTION_EDIT_MODE, text = ns.G("HUD_EDIT_MODE_MENU", "Mode Édition"),
            tip = L.OPTION_EDIT_MODE_TIP, click = ns.EditFrame.OpenEditMode },
        { kind = "header", text = L.OPTIONS_PARTS },
        check("plate", L.OPT_PLATE, L.OPT_PLATE_TIP),
        check("minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TIP),
        -- (each by the same name as in Edit Mode's dialog: the review of 2026-11-20, one thing one name)
        check("windowFold", L.OPT_WIN_FOLD, L.OPT_WIN_FOLD_TIP),
        check("infoBar", L.OPT_INFO_BAR, L.OPT_INFO_BAR_TIP),
        { kind = "header", text = L.DIAG_TITLE },
        { kind = "button", name = L.REPORT_TITLE, text = L.REPORT_OPEN, tip = L.REPORT_OPEN_TIP, click = ns.Report.Open },
    }
end

-- The page under it, « Préréglages » (Core/Sets.lua, UI/SetWindow.lua; Ikar 2026-11-19: "this should go into the
-- setting windows, not the edit mode"): whether this character plays on settings of its own, as the game's own
-- « Raccourcis clavier propres au personnage »; the sets kept in a dropdown, what can be done to the one picked under
-- it, each button greyed while it can't (Ikar, the same day: "vos prereglage can't be a drop down with button in it
-- own section ? Grayed when innactive"), and a shared text taken as one more. The settings as they are first, in one
-- section (Ikar 2026-11-20: "the first checkbox and the two (save and share) should be combined into one"): this
-- character's own or not, kept as one more set, shared.
local function setRows()
    local W = ns.SetWindow
    -- a button under the dropdown: what it does to the one picked, greyed while that can't be done
    local function pick(text, what, tip)
        return { text = text, tip = tip, enabled = function()
            return W.Can(what)
        end, click = function()
            W.Do(what)
        end }
    end
    return {
        { kind = "header", text = L.SET_CURRENT },
        { kind = "check", name = L.SET_OWN, tip = L.SET_OWN_TIP,
            get = function()
                return ns.Sets.Own()
            end,
            -- back on the account's, all it has set is replaced: asked first, as the game asks for its key bindings,
            -- the box staying ticked until the answer
            set = function(value)
                if value then
                    ns.Sets.SetOwn(true)
                    return
                end
                local name = UnitName("player") or "?"
                ns.Ask(string.format(L.SET_OWN_ASK, name, string.format(L.SET_OWN_KEPT, name)), function()
                    ns.Sets.SetOwn(false)
                    Options.Changed()
                end)
            end },
        { kind = "button", name = L.SET_SAVE_NAME, text = L.SET_SAVE, tip = L.SET_SAVE_TIP, click = W.AskSave },
        -- (Ikar 2026-11-19, of the export: "it is quite convoluted": the settings as they are, in one click, without
        -- keeping them as a set first)
        { kind = "button", name = L.SET_SHARE_NAME, text = L.SET_SHARE_GO, tip = L.SET_SHARE_TIP,
            click = W.ShareCurrent },
        { kind = "header", text = L.SET_YOURS },
        { kind = "choice", name = L.SET_PICK_NAME, tip = L.SET_CHOOSE_TIP, empty = L.SET_CHOOSE,
            values = W.Choices, get = W.PickedValue, set = W.Pick },
        { kind = "buttons", buttons = {
            pick(L.SET_APPLY_GO, "apply", L.SET_APPLY_TIP), pick(L.SET_UPDATE, "update", L.SET_UPDATE_TIP),
            pick(L.SET_RENAME, "rename"), pick(L.SET_SHARE_GO, "share"), pick(L.SET_DELETE, "delete"),
        } },
        { kind = "button", name = L.SET_FROM_TEXT, text = L.SET_IMPORT, tip = L.SET_IMPORT_TIP, click = W.AskImport },
    }
end

-- The page under it, « Comportement et sons »: what the HUD does by itself and what it sounds like, which Edit Mode's
-- dialog held (Ikar 2026-11-19: "see options in the edit mode, should some go to the settings instead ?"; what is set
-- while looking at it stays there). Not what one element of the bar has of its own: the bags' free slots and the
-- gold's copper are in their right-click, the padlock opens and shuts on itself and in the bar's menu (Ikar
-- 2026-11-20: "some settings shoudl be a component option in it right click instead of a addon option").
local function behaviourRows()
    local list = {
        { kind = "header", text = L.OPTIONS_BEHAVIOUR_HEAD },
        slider("minimapAutoZoom", L.OPT_MM_AUTOZOOM, 1, seconds, L.OPT_MM_AUTOZOOM_TIP),
        check("chatPeekOnType", L.OPT_CHAT_PEEK, L.OPT_CHAT_PEEK_TIP),
        check("meterUnfoldCombat", L.OPT_METER_COMBAT, L.OPT_METER_COMBAT_TIP),
        check("folderCombatClose", L.OPT_FOLDER_COMBAT, L.OPT_FOLDER_COMBAT_TIP),
        check("hideExternalXP", L.OPT_HIDE_EXT_XP, L.OPT_HIDE_EXT_XP_TIP),
        check("manaPerSecond", L.OPT_MANA_PER_SECOND, L.OPT_MANA_PER_SECOND_TIP),
        { kind = "header", text = L.OPTIONS_SOUNDS },
        check("foldAnim", L.OPT_FOLD_ANIM, L.OPT_FOLD_ANIM_TIP),
        sound("foldSound", L.OPT_FOLD_SOUND, ns.FOLD_SOUNDS, ns.FOLD_SOUND_ORDER, "FOLD_SOUND_", L.OPT_FOLD_SOUND_TIP),
        sound("folderSound", L.OPT_FOLDER_SOUND, ns.FOLDER_SOUNDS, ns.FOLDER_SOUND_ORDER, "FOLDER_SOUND_",
            L.OPT_FOLDER_SOUND_TIP),
    }
    list[#list + 1] = reset(list, L.OPTIONS_BEHAVIOUR)
    return list
end

function Options.Register()
    if page then
        return
    end
    page = ns.Page.New({ name = ns.TITLE, rows = rows, pages = {
        { name = L.SET_TITLE, rows = setRows },
        { name = L.OPTIONS_BEHAVIOUR, rows = behaviourRows },
    } })
    Options.page = page
end

-- The game's options can't open in a fight: the page says so, with the game's own line (Shared/Page.lua).
function Options.Open()
    return page ~= nil and page:Open()
end

-- An option of the page changed elsewhere (the info bar's padlock), while the page shows.
function Options.Changed()
    if page then
        page:Refresh()
        for _, under in ipairs(page.pages) do
            under:Refresh()
        end
    end
end

function KaLiHUD_OnAddonCompartmentClick()
    if not ns.db then
        ns.Say(string.format(L.DB_REFUSED, tostring(ns.disabled)))
        return
    end
    if ns.Frames.IsEditing() then
        ns.SafeCall(ns.EditFrame.Select)
    else
        ns.SafeCall(Options.Open)
    end
end

function KaLiHUD_OnAddonCompartmentEnter(_, button)
    ns.SafeCall(function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.TITLE)
        GameTooltip:AddLine(L.COMPARTMENT_CLICK, 1, 1, 1)
        GameTooltip:Show()
    end)
end

function KaLiHUD_OnAddonCompartmentLeave(_, button)
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end