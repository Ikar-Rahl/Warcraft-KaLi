-- The addon's lines in the game's tooltips, through Blizzard's tooltip data post-calls (nothing hooked in the
-- tooltip itself): a recipe's (who knows it, who holds it, where it was seen), and a material's « Fabriqué par » and
-- « Utilisé dans ». All in the light blue of « Composant d'artisanat ».
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local Tooltips = {}
ns.Tooltips = Tooltips

local MAX_WHERE = 4

-- Each line is { left, right, colour, rightColour }; a blank line is { "" }. Pure apart from the model's names, so
-- the tests read them.
function Tooltips.RecipeLines(m, spell, style)
    if style == "off" then
        return {}
    end
    local me = m.me
    local blue = { W.AddonColor() }
    local info = m:Info(spell)
    local mine = m:Knows(me, spell)
    local others = {}
    for _, key in ipairs(m:Knowers(spell)) do
        if key ~= me then
            others[#others + 1] = key
        end
    end
    local pos = m:Possession(spell, me)
    local seen = m:Sightings(spell)
    local out = { { "" } }
    if style == "compact" then
        local bits = {}
        if mine then
            bits[1] = L.COMPACT_KNOWN
        elseif #others > 0 then
            local names = {}
            for i, key in ipairs(others) do
                names[i] = m:CharName(key)
            end
            bits[1] = string.format(L.COMPACT_KNOWN_BY, table.concat(names, ", "))
        else
            bits[1] = L.COMPACT_UNKNOWN
        end
        if #seen > 0 then
            bits[#bits + 1] = string.format(L.COMPACT_SEEN, #seen)
        end
        if pos and pos.mine then
            bits[#bits + 1] = L.COMPACT_ON_YOU
        end
        if pos and #pos.alts > 0 then
            local names = {}
            for i, a in ipairs(pos.alts) do
                names[i] = m:CharName(a.key)
            end
            bits[#bits + 1] = string.format(L.COMPACT_ON, table.concat(names, ", "))
        end
        out[#out + 1] = { L.CARNET_PREFIX .. table.concat(bits, " · "), nil, blue }
        return out
    end
    out[#out + 1] = { L.CARNET, nil, blue }
    if not mine then
        if #others > 0 then
            local names = {}
            for i, key in ipairs(others) do
                names[i] = string.format(L.KNOWN_RANK, m:CharName(key), ns.Game.ProfName(info.skill), m:Rank(key, info.skill))
            end
            out[#out + 1] = { string.format(L.KNOWN_BY, table.concat(names, ", ")), nil, blue }
        else
            out[#out + 1] = { L.UNKNOWN_TO_ALL, nil, blue }
        end
    end
    if pos and pos.mine then
        out[#out + 1] = { string.format(L.YOU_HAVE, pos.mine.total, ns.Text.Held(pos.mine.bags, pos.mine.bank)), nil, blue }
    end
    for _, a in ipairs(pos and pos.alts or {}) do
        out[#out + 1] = { string.format(L.ALT_HAS, m:CharName(a.key), a.total, ns.Text.Held(a.bags, a.bank)), nil, blue }
    end
    -- Where, and at a vendor, what it asked.
    for i = 1, math.min(#seen, MAX_WHERE) do
        out[#out + 1] = { ns.Text.Where(m, seen[i]), ns.Text.Price(seen[i]), blue, W.WHITE }
    end
    if #seen > MAX_WHERE then
        out[#out + 1] = { string.format(L.MORE, #seen - MAX_WHERE), nil, W.GRAY }
    end
    return out
end

-- « Fabriqué par » and « Utilisé dans », by profession, the character's own professions first: the recipes, who knows
-- each, « vue » for one only seen; where it was seen is the recipe's own tooltip's (Ikar, 2026-11-10).
function Tooltips.MaterialLines(m, item, o)
    local out = {}
    local blue = { W.AddonColor() }
    local me = m.me
    if o.mCraft then
        local made = m:MadeBy(item)
        if #made > 0 then
            out[#out + 1] = { "" }
            out[#out + 1] = { L.MADE_BY, nil, blue }
            for _, x in ipairs(made) do
                local info = m:Info(x.spell)
                local right
                if #x.who > 0 then
                    local names = {}
                    for i, key in ipairs(x.who) do
                        names[i] = m:CharName(key)
                    end
                    right = table.concat(names, ", ")
                else
                    right = L.SEEN_WORD
                end
                out[#out + 1] = { "  " .. ns.Game.ProfName(info.skill) .. " · " .. m:Name(x.spell), right,
                    #x.who > 0 and W.WHITE or W.GRAY, W.GRAY }
            end
        end
    end
    if not o.usedIn then
        return out
    end
    local known, seen = m:UsedIn(item)
    local rows = {}
    for _, k in ipairs(known) do
        rows[#rows + 1] = k
    end
    if o.usedInSeen then
        for _, k in ipairs(seen) do
            rows[#rows + 1] = { spell = k.spell, seen = true }
        end
    end
    if #rows == 0 then
        return out
    end
    out[#out + 1] = { "" }
    out[#out + 1] = { L.USED_IN, nil, blue }
    local by, skills = {}, {}
    for _, r in ipairs(rows) do
        local skill = m:Info(r.spell).skill
        if not by[skill] then
            by[skill] = {}
            skills[#skills + 1] = skill
        end
        table.insert(by[skill], r)
    end
    table.sort(skills, function(a, b)
        local ha, hb = m:HasProf(me, a), m:HasProf(me, b)
        if ha ~= hb then
            return ha
        end
        return ns.TextLess(ns.Game.ProfName(a), ns.Game.ProfName(b))
    end)
    local shown, max = 0, o.usedInMax or 10
    for _, skill in ipairs(skills) do
        if shown >= max then
            break
        end
        out[#out + 1] = { ns.Game.ProfName(skill), nil, W.GOLD }
        for _, r in ipairs(by[skill]) do
            if shown >= max then
                break
            end
            local right
            if r.seen then
                right = L.SEEN_WORD
            else
                local names = {}
                local mineToo = false
                for _, key in ipairs(r.who) do
                    if key == me then
                        mineToo = true
                    else
                        names[#names + 1] = m:CharName(key)
                    end
                end
                right = not mineToo and table.concat(names, ", ") or nil
            end
            out[#out + 1] = { "  " .. m:Name(r.spell), right, r.seen and W.GRAY or W.WHITE, W.GRAY }
            shown = shown + 1
        end
    end
    if #rows > shown then
        out[#out + 1] = { string.format(L.MORE, #rows - shown), nil, W.GRAY }
    end
    return out
end

-- ---------- A vendor, on hover ----------

-- The game's green (GREEN_FONT_COLOR).
local GREEN = { 0.1, 1, 0.1 }

-- A vendor's line (Ikar 2026-11-21: "show no receipe (gray), or has receipe (white). with icon if from alt. never visited
-- in green, and if alt already visisted but alt discoverability is diabled shoudl be green for local character"): opened,
-- with how many recipes seen there, grey with none, white with some, the friend icon when only another character opened
-- it; never opened, green, where the game's icon says it sells. alts: another's visit counts (« Sur un autre
-- personnage »). Nil where there's nothing to say.
function Tooltips.VendorLine(m, npc, sells, alts)
    local v = m:Vendor(npc)
    local other = alts and v.other and not v.mine
    if not (v.mine or other) then
        return sells and { L.VENDOR_NEVER, nil, GREEN } or nil
    end
    local text = v.recipes > 0 and ns.Plural(v.recipes, L.VENDOR_ONE, L.VENDOR_MANY) or L.VENDOR_NONE
    return { (other and "|A:" .. W.ATLAS.friend .. ":14:14|a " or "") .. text, nil, v.recipes > 0 and W.WHITE or W.GRAY }
end

-- The icons the game gives a vendor before any talk, as its nameplate's (Ikar's probe, 2026-11-21: a vendor
-- « Pickup », an innkeeper « Innkeeper »; repairers and the merchant cursor's own as Cursormode names them). One that
-- talks or gives quests shows that instead: it says nothing until opened.
local SELLS = { pickup = true, buy = true, innkeeper = true, repairnpc = true }
local icon

-- Whether the game's icon for the unit says it sells: SetUnitCursorTexture on a texture of the addon's own, never shown,
-- the lower priority icons too (the probe's flight master and quest giver had none without), its file read back,
-- « Crosshair_<kind>_64 », « Unable » before the kind out of reach.
function Tooltips.Sells(unit)
    if type(SetUnitCursorTexture) ~= "function" then
        return false
    end
    icon = icon or UIParent:CreateTexture()
    icon:Hide()
    if not ns.Plain(ns.Call(SetUnitCursorTexture, icon, unit, nil, true, false)) then
        return false
    end
    local file = ns.Plain(ns.Call(icon.GetTextureFilePath, icon))
    local kind = tostring(file or ""):lower():match("crosshair_(%a+)_%d+$")
    return SELLS[kind and (kind:gsub("^unable", ""))] == true
end

local function add(tooltip, lines)
    for _, line in ipairs(lines) do
        local c, rc = line[3] or W.WHITE, line[4] or W.GRAY
        if line[2] then
            tooltip:AddDoubleLine(line[1], line[2], c[1], c[2], c[3], rc[1], rc[2], rc[3])
        else
            tooltip:AddLine(line[1], c[1], c[2], c[3], line[1] ~= "" and #line[1] > 60)
        end
    end
end

-- Only the game's own tooltip and chat links' get lines: not the comparison tooltips beside them.
local function wanted(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

local function onItem(tooltip, data)
    if not (ns.book and wanted(tooltip) and data and type(data.id) == "number") then
        return
    end
    -- « Composant d'artisanat »: its colour is the addon's blue.
    for _, line in ipairs(data.lines or {}) do
        if ns.Plain(line.leftText) == ns.G("PROFESSIONS_USED_IN_COOKING", nil) and line.leftColor then
            W.NoteReagentColor(line.leftColor)
            break
        end
    end
    local o = ns.db.options
    local spell = ns.RECIPE_ITEMS[data.id]
    if spell then
        add(tooltip, Tooltips.RecipeLines(ns.book, spell, o.recipeTip))
    else
        add(tooltip, Tooltips.MaterialLines(ns.book, data.id, o))
    end
end

-- A trainer's list and the notebook's trainer recipes show the recipe's spell.
local function onSpell(tooltip, data)
    if not (ns.book and wanted(tooltip) and data and type(data.id) == "number" and ns.RECIPES[data.id]) then
        return
    end
    add(tooltip, Tooltips.RecipeLines(ns.book, data.id, ns.db.options.recipeTip))
end

-- An NPC under the mouse: the vendor's line, on the game's own tooltip only.
local function onUnit(tooltip, data)
    if not (ns.book and tooltip == GameTooltip and data) then
        return
    end
    local _, unit = tooltip:GetUnit()
    unit = ns.Plain(unit)
    local npc = ns.Game.NPCFromGUID(ns.Plain(data.guid) or (unit and ns.Plain(UnitGUID(unit))))
    if not npc then
        return
    end
    local line = Tooltips.VendorLine(ns.book, npc, unit ~= nil and Tooltips.Sells(unit), ns.db.options.mAlt)
    if line then
        add(tooltip, { line })
    end
end

function Tooltips.Start()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType) then
        return false
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        ns.SafeCall(onItem, tooltip, data)
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        ns.SafeCall(onSpell, tooltip, data)
    end)
    if Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            ns.SafeCall(onUnit, tooltip, data)
        end)
    end
    return true
end
