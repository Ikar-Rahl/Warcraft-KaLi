-- KaLi HUD's check of its own stat cards (UI/Hub/Infos/Stats.lua). Ikar 2026-11-22, of the cards' mistakes found in
-- game one at a time: "why didn't you catch them on your numerous reviews ? Is there a better way to do it ?", then
-- "ok, go, and add that to the error report". The game is what says whether a card is right, so a card that can't
-- account for all of the game's figure keeps what it saw, to be read again offline from that alone
-- (hud/tools/lua/scenarios/cards.lua, the fake's F.Replay; hud/tools/card_cases.py reads them from the saved file):
-- what's left (« Autres » above 0, a source the game may hide; « Erreur de l'add-on » below 0, or of the base), the
-- card's rows, what its value's own calls gave (Stats.ReadValue), and the state its sources were read from
-- (Stats.ReadState, kept once for all the cards read in it). The same card with the same rows once, with how many
-- times it was looked at and when first and last; MAX of them, the last /kh stats' whole, then those that can't
-- account for all of it, the last seen first. /kh stats keeps every card as it is (asked: at a camp, after a level,
-- in a form). In the account's KaLiHUDDevDB.statChecks, beside the errors: the bug report has
-- them (UI/Report.lua), /kh clear empties them with the errors. Out of a fight alone, the game hiding the values then;
-- never a character's or a realm's name.
local _, ns = ...

local StatCheck = {}
ns.StatCheck = StatCheck

-- The cards kept; what the bug report gives of their inputs, at most (GitHub takes 65,536 characters in an issue, and
-- the report's other parts come after this one).
StatCheck.MAX = 40
local REPORT_CHARS = 20000

local function now()
    return date("%Y-%m-%d %H:%M:%S")
end

-- A name without its colours and icons.
local function plain(text)
    return (tostring(text or ""):gsub("|T.-|t%s*", ""):gsub("|A.-|a%s*", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", ""))
end

-- What's kept, made anew when the saved data holds none or something else.
local function store()
    local d = ns.DevDB()
    if type(d) ~= "table" then
        return nil
    end
    local kept = d.statChecks
    if type(kept) ~= "table" or type(kept.cards) ~= "table" or type(kept.states) ~= "table" then
        kept = { cards = {}, states = {}, seen = 0 }
        d.statChecks = kept
    end
    return kept
end

-- A text's short mark, to know the same card or the same state again (djb2, on 32 bits).
local function mark(text)
    local h = 5381
    for i = 1, #text do
        h = (h * 33 + text:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

-- A value as Lua, sorted, so that the same value is the same text: a case to paste into the scenario. No | as it is,
-- which the report's window reads as a code, nor a line break: each such character its code in three figures, as
-- Lua reads at most three (the review of 2026-11-23: "\10" before "29 min" read back as "f9 min").
local RESERVED = {}
for word in ("and break do else elseif end false for function if in local nil not or repeat return then true until "
    .. "while"):gmatch("%a+") do
    RESERVED[word] = true
end
local function literal(v, out)
    local kind = type(v)
    if kind == "table" then
        out[#out + 1] = "{"
        local n = #v
        for i = 1, n do
            literal(v[i], out)
            out[#out + 1] = ","
        end
        local keys = {}
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then
                return type(a) < type(b)
            end
            return a < b
        end)
        for _, k in ipairs(keys) do
            if type(k) == "string" and k:find("^[%a_][%w_]*$") and not RESERVED[k] then
                out[#out + 1] = k .. "="
            else
                out[#out + 1] = "["
                literal(k, out)
                out[#out + 1] = "]="
            end
            literal(v[k], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif kind == "string" then
        out[#out + 1] = '"' .. v:gsub('[%c"\\|]', function(c)
            return string.format("\\%03d", c:byte())
        end) .. '"'
    elseif kind == "number" then
        out[#out + 1] = ns.Finite(v) and string.format("%.14g", v) or "0"
    elseif kind == "boolean" then
        out[#out + 1] = tostring(v)
    else
        out[#out + 1] = "nil"
    end
end
function StatCheck.Literal(v)
    local out = {}
    literal(v, out)
    return table.concat(out)
end

-- A card's rows as kept: their names plain, their figures, what each is (`keep`: a regeneration's share kept while
-- casting or in a fight, Stats.lua's RegenTable).
function StatCheck.Rows(list)
    local rows = {}
    for i, e in ipairs(list) do
        rows[i] = { name = plain(e.name), points = e.points, share = e.share, keep = e.keep, percent = e.percent or nil,
            base = e.base or nil, other = e.other or nil, origin = e.origin or nil, mistake = e.mistake or nil,
            unsure = e.unsure or nil, next = e.next or nil, item = e.item or nil }
    end
    return rows
end

-- What a card can't account for among its rows: what's left, « Autres » (`other`, not a base named after where it
-- comes from), or the addon's mistake.
function StatCheck.Gaps(list)
    local gaps = {}
    for _, e in ipairs(list) do
        if type(e.points) == "number" and (e.mistake or (e.other and not e.origin)) then
            gaps[#gaps + 1] = { name = plain(e.name), points = e.points, percent = e.percent or nil,
                mistake = e.mistake or nil }
        end
    end
    return gaps
end

-- Whether a card kept can't account for all of the game's figure.
local function gapped(e)
    return #(e.gaps or {}) > 0
end

-- Past MAX, what goes first (the review of 2026-11-23: each /kh stats keeps a card a value, and the third pushed out
-- the first card that couldn't account for its figure): the cards of the last /kh stats stay whole, then those that
-- can't account for all of it, then the others; the last seen first in each.
local function prune(kept)
    if #kept.cards <= StatCheck.MAX then
        return
    end
    local latest = tonumber(kept.asks)
    local function rank(e)
        if latest and e.asked == latest then
            return 0
        end
        return gapped(e) and 1 or 2
    end
    table.sort(kept.cards, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then
            return ra < rb
        end
        return (tonumber(a.seen) or 0) > (tonumber(b.seen) or 0)
    end)
    for i = #kept.cards, StatCheck.MAX + 1, -1 do
        kept.cards[i] = nil
    end
end

-- A card drawn (Stats.lua's cardSources, its sources `list` at the kind of attack `channel`): kept when it can't
-- account for all of the game's figure, or when asked (`asked`: the number of the /kh stats asking); seen again,
-- counted, but for the card kept open drawn again (`again`: the values changed under it, the pointer went over
-- something to try), which is no new look (the review of 2026-11-23: each of its redraws counted). `state`: the one
-- read already for the cards kept together (/kh stats). Returns the card kept, nil for one with nothing to keep.
function StatCheck.Note(s, list, channel, asked, state, again)
    local kept = store()
    if not kept or ns.InCombat() or type(list) ~= "table" then
        return nil
    end
    local rows, gaps = StatCheck.Rows(list), StatCheck.Gaps(list)
    if #gaps == 0 and not asked then
        return nil
    end
    local signature = { s.key, tostring(ns.Plain(UnitLevel("player"))) }
    for _, r in ipairs(rows) do
        signature[#signature + 1] = r.name .. "=" .. tostring(r.points) .. "/" .. tostring(r.share)
    end
    local key = mark(table.concat(signature, "|"))
    kept.seen = (tonumber(kept.seen) or 0) + 1
    for _, e in ipairs(kept.cards) do
        if e.key == key then
            e.count, e.last, e.seen = (tonumber(e.count) or 0) + (again and 0 or 1), now(), kept.seen
            e.asked = asked or e.asked
            return e
        end
    end
    state = state or ns.Stats.ReadState()
    local id = mark(StatCheck.Literal(state))
    kept.states[id] = kept.states[id] or state
    local when = now()
    local entry = { key = key, stat = s.key, title = plain(s.name and s.name()), count = 1, first = when, last = when,
        seen = kept.seen, version = ns.VERSION, build = select(2, GetBuildInfo()), state = id,
        value = ns.Stats.ReadValue(s, channel), rows = rows, gaps = gaps, asked = asked or nil }
    kept.cards[#kept.cards + 1] = entry
    -- MAX of them (prune), and the states a card kept is read in
    prune(kept)
    local used = {}
    for _, e in ipairs(kept.cards) do
        used[e.state] = true
    end
    for k in pairs(kept.states) do
        if not used[k] then
            kept.states[k] = nil
        end
    end
    return entry
end

-- /kh stats: every card as it is now, kept as asked. How many, and how many of them can't account for all of the
-- game's figure; nil in a fight, the game hiding the values then.
function StatCheck.SaveAll()
    local kept = store()
    if ns.InCombat() or not kept then
        return nil
    end
    -- (its number: the last /kh stats' cards stay whole, prune)
    kept.asks = (tonumber(kept.asks) or 0) + 1
    local state = ns.Stats.ReadState()
    local cards, gaps = 0, 0
    for _, s in ipairs(ns.Stats.LIST) do
        if s.sources then
            local ok, list, channel = ns.SafeCall(ns.Stats.SourcesOf, s, true)
            local e = ok and list and StatCheck.Note(s, list, channel, kept.asks, state)
            if e then
                cards, gaps = cards + 1, gaps + (#e.gaps > 0 and 1 or 0)
            end
        end
    end
    return cards, gaps
end

-- A card kept with its state, as a case of the scenario (hud/tools/lua/scenarios/cards.lua).
function StatCheck.Case(e, kept)
    kept = kept or store() or { states = {} }
    return { stat = e.stat, build = e.build, version = e.version, value = e.value, rows = e.rows, gaps = e.gaps,
        state = kept.states[e.state] }
end

-- How many cards are kept, and how many of them can't account for all of it.
function StatCheck.Count()
    local kept, gaps = store(), 0
    for _, e in ipairs(kept and kept.cards or {}) do
        gaps = gaps + (#(e.gaps or {}) > 0 and 1 or 0)
    end
    return kept and #kept.cards or 0, gaps
end

local function figure(v, percent)
    return percent and string.format("%.2f%%", v) or string.format("%.14g", v)
end

-- The cards kept in the report's order (numbered so there and by hud/tools/card_cases.py): those that can't account
-- for all of it first, the last seen first.
function StatCheck.Sorted()
    local kept = store()
    local list = {}
    for _, e in ipairs(kept and kept.cards or {}) do
        list[#list + 1] = e
    end
    table.sort(list, function(a, b)
        if gapped(a) ~= gapped(b) then
            return gapped(a)
        end
        return (tonumber(a.seen) or 0) > (tonumber(b.seen) or 0)
    end)
    return list, kept
end

-- The bug report's part: a line a card, in that order; then, as many of those that can't account for all of it as
-- REPORT_CHARS holds, a case each, what it read.
function StatCheck.Text()
    local list, kept = StatCheck.Sorted()
    if #list == 0 then
        return "(none)"
    end
    local cards, withGaps = StatCheck.Count()
    local lines = { string.format("%d cards kept, %d that can't account for all of the game's figure%s", cards, withGaps,
        withGaps > 0 and "; each of those then as a case of hud/tools/lua/scenarios/cards.lua" or "") }
    for i, e in ipairs(list) do
        local state = kept.states[e.state] or {}
        local race, class = state.race or {}, state.class or {}
        local left = {}
        for _, g in ipairs(e.gaps or {}) do
            left[#left + 1] = g.name .. " " .. figure(g.points, g.percent)
        end
        lines[#lines + 1] = string.format("%d. %s (%s) x%s, %s to %s, v%s build %s, level %s %s %s%s%s", i,
            tostring(e.stat), tostring(e.title), tostring(e.count), tostring(e.first), tostring(e.last),
            tostring(e.version), tostring(e.build), tostring(state.level), tostring(race[2]), tostring(class[2]),
            #left > 0 and ": " .. table.concat(left, ", ") or "", e.asked and " (asked)" or "")
    end
    local used = #table.concat(lines, "\n")
    for i, e in ipairs(list) do
        if not gapped(e) then
            break
        end
        local text = "case " .. i .. " = " .. StatCheck.Literal(StatCheck.Case(e, kept))
        if used + #text > REPORT_CHARS then
            lines[#lines + 1] = "(the others' cases are in the saved data)"
            break
        end
        lines[#lines + 1] = text
        used = used + #text + 1
    end
    return table.concat(lines, "\n")
end

function StatCheck.Clear()
    local d = ns.DevDB()
    if type(d) == "table" then
        d.statChecks = nil
    end
end

-- /kh clear empties them with the errors (Shared/Debug.lua's Clear, the shared command's).
local clearErrors = ns.Debug.Clear
function ns.Debug.Clear(...)
    clearErrors(...)
    StatCheck.Clear()
end
