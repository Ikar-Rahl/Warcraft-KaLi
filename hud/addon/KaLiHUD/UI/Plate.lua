-- The plate: the HUD's metal base under the frames it takes. It takes what Frames.ACCEPTED lists when it shows and
-- stands within reach above the plate (Geometry.Cover). Static outside Edit Mode (Ikar 2026-11-15: "people do not
-- expect their UI to change with dynamic events"): in Edit Mode it follows the frames live; leaving it, they're frozen
-- as they stand, saved per character, and the plate is drawn from that until Edit Mode again, a UI scale or screen
-- change, or /kh redraw; a bar that shows or hides meanwhile changes nothing. What the player moves himself (the chat
-- by its tab) is followed once he lets go, that frame alone. A window folding sinks its own place alone, the rest as
-- it stands. Its pieces (Geometry.Pieces) are its fill, the background's colour lit
-- from the top with its material; its edge, one line along the outline (Geometry.Path), takes the KaLi border
-- (UI/Border.lua's Profile), its shadow outside, as a band of quads cut along each bend (Geometry.Band), each a texture
-- whose corners SetVertexOffset moves. The chat and the damage meter it hugs: its edge is their border. The info bar
-- and the map's foot are carved into it; the other slots show the plate's background, no recess.
-- Strata BACKGROUND and no mouse: it never touches a Blizzard frame, so nothing changes in a fight.
local _, ns = ...

local Plate = {}
ns.Plate = Plate

local Geometry, Frames = ns.Geometry, ns.Frames
local max, min = math.max, math.min

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BRONZE, BRONZE_LIGHT = { 0.651, 0.490, 0.271 }, { 0.86, 0.66, 0.37 }
-- The carved channel: its floor this dark, the shadow its lip casts this deep, the lip's cut and lit lines.
local CHANNEL, CHANNEL_SHADOW = { 0, 0, 0, 0.32 }, 7
-- the folders' lists' floor too, carved or not (UI/Hub/Folders.lua)
Plate.CHANNEL = CHANNEL
local CLEAR, SHADE = { 0, 0, 0, 0 }, { 0, 0, 0, 0.5 }
local LIP_CUT, LIP_LIT = { 0, 0, 0, 0.75 }, { BRONZE_LIGHT[1], BRONZE_LIGHT[2], BRONZE_LIGHT[3], 0.4 }
-- The minimap pockets' marks and the recess round a map with no ring: near black, as dark as the slots' recesses were
-- by default (the slots have none since Ikar's 0 %, 2026-11-16: "creux: 0%").
local RECESS = { 0.02, 0.018, 0.015, 0.4 }
-- The map's shadow on the plate: past its ring by this much, this much lower, this dark.
local SHADOW_GROW, SHADOW_DROP, MAP_SHADOW = 20, 10, { 0, 0, 0, 0.95 }
-- Under the map: the dark rim under our ring or Blizzard's, or round none a recess, a bronze lip and a dark neck.
local UNDER_RING, NECK = { 0.01, 0.01, 0.01, 1 }, { 0.015, 0.015, 0.015, 1 }
local POCKET_DIR = { pocketLeft = -1, pocketRight = 1 }

local frame
local pool, used = {}, 0
local bandPool, bandUsed = {}, 0
local grainPool, grainUsed = {}, 0
local masks, masksUsed = {}, 0
local colorMin, colorMax
local lastCoords, lastCount = {}, 0
local liveOn, dirty = false, false
-- The frames as frozen leaving Edit Mode: { W, H, t, frames = { { key, x, y, w, h } } }, nil until the first freeze.
local frozen
-- How long after the world shows the first freeze waits, when none fits the screen: late frames have come by then.
local SETTLE = 3
local ACCEPTED_BY = {}
for _, entry in ipairs(Frames.ACCEPTED) do
    ACCEPTED_BY[entry[1]] = entry
end
-- Drawing's own tables, set again each time: a disc and its layer.
local discPiece, discLayer = { "disc" }, { drawLayer = "ARTWORK" }
-- What was drawn last, for the report and the tests: the outline's segments, the dome, the slots.
Plate.last = nil

local function setColor(col, r, g, b, a)
    if col.SetRGBA then
        col:SetRGBA(r, g, b, a)
    else
        col.r, col.g, col.b, col.a = r, g, b, a
    end
    return col
end

local function acquire(layer, sub)
    used = used + 1
    local t = pool[used]
    if not t then
        t = frame:CreateTexture(nil, layer, nil, sub)
        pool[used] = t
    elseif t._layer ~= layer or t._sub ~= sub then
        t:SetDrawLayer(layer, sub)
    end
    if t._mask then
        t:RemoveMaskTexture(t._mask)
        t._mask = nil
    end
    t._layer, t._sub = layer, sub
    t:ClearAllPoints()
    if not t._shown then
        t:Show()
        t._shown = true
    end
    return t
end

local function setTex(t, path, u0, u1, v0, v1)
    if t._mat then
        t:SetDesaturated(false)
        t:SetBlendMode("BLEND")
        t._mat = nil
    end
    if t._tex ~= path then
        t:SetTexture(path)
        t._tex = path
    end
    if t._u0 ~= u0 or t._u1 ~= u1 or t._v0 ~= v0 or t._v1 ~= v1 then
        t:SetTexCoord(u0, u1, v0, v1)
        t._u0, t._u1, t._v0, t._v1 = u0, u1, v0, v1
    end
end

-- A piece's box: x0, y0, x1, y1.
local function box(p)
    local kind = p[1]
    if kind == "rect" then
        return p[2], p[3], p[4], p[5]
    elseif kind == "quarter" or kind == "bevel" then
        local cx, cy, r = p[2], p[3], p[4]
        if p[5] == "TL" then
            return cx - r, cy, cx, cy + r
        end
        return cx, cy, cx + r, cy + r
    elseif kind == "fillet" or kind == "slope" then
        local x, y, r = p[2], p[3], p[4]
        if p[5] > 0 then
            return x, y, x + r, y + r
        end
        return x - r, y, x, y + r
    elseif kind == "arc" then
        return p[5], p[7], p[6], p[3] + p[4]
    end
    return p[2] - p[4], p[3] - p[4], p[2] + p[4], p[3] + p[4]
end

local function acquireMask()
    masksUsed = masksUsed + 1
    local m = masks[masksUsed]
    if not m then
        m = frame:CreateMaskTexture()
        masks[masksUsed] = m
    end
    m:ClearAllPoints()
    m:Show()
    return m
end

local function mix(a, b, k)
    k = max(0, min(1, k))
    return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * k
end

-- A texture over x0..x1, y0..y1, coloured as the layer is at those heights (reusing static ColorMixin objects).
local function paint(t, x0, y0, x1, y1, foot, top, artTop)
    colorMin = colorMin or CreateColor(0, 0, 0, 1)
    colorMax = colorMax or CreateColor(0, 0, 0, 1)
    t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x0, y0)
    t:SetSize(max(x1 - x0, 0.01), max(y1 - y0, 0.01))
    top = top or foot
    local r0, g0, b0, a0 = mix(foot, top, y0 / artTop)
    local r1, g1, b1, a1 = mix(foot, top, y1 / artTop)
    t:SetGradient("VERTICAL", setColor(colorMin, r0, g0, b0, a0), setColor(colorMax, r1, g1, b1, a1))
end

-- A piece of the material over the colour, added, its texels fixed to the screen so the pieces join; a curved or cut
-- piece shaped by a mask, the disc, the fillet or the bevel over its box.
local function drawTextured(p, mat, foot, top, artTop)
    local t = acquire("BACKGROUND", 1)
    local x0, y0, x1, y1 = box(p)
    local size = mat.size
    if t._tex ~= mat.file then
        t:SetTexture(mat.file, "REPEAT", "REPEAT")
        t._tex, t._mat = mat.file, nil
    end
    if not t._mat then
        t:SetDesaturated(true)
        t:SetBlendMode("ADD")
        t._mat = true
    end
    t._u0 = nil
    t:SetTexCoord(x0 / size, x1 / size, -y1 / size, -y0 / size)
    paint(t, x0, y0, x1, y1, foot, top, artTop)
    local kind = p[1]
    if kind == "rect" then
        return
    end
    local m = acquireMask()
    if kind == "fillet" or kind == "slope" or kind == "bevel" then
        -- Bevel.tga fills its lower right half: a top right corner and a cut against a wall on its left are mirrored
        local mirrored
        if kind == "fillet" then
            mirrored = p[5] < 0
        elseif kind == "slope" then
            mirrored = p[5] > 0
        else
            mirrored = p[5] == "TR"
        end
        if kind == "fillet" then
            m:SetTexture(mirrored and ns.FILLET_MIRROR or ns.FILLET, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        else
            m:SetTexture(mirrored and ns.BEVEL_MIRROR or ns.BEVEL, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        m:SetTexCoord(0, 1, 0, 1)
        m:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x0, y0)
        m:SetSize(x1 - x0, y1 - y0)
    else
        local cx, cy, rr = p[2], p[3], p[4]
        m:SetTexture(ns.DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetTexCoord(0, 1, 0, 1)
        m:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cx - rr, cy - rr)
        m:SetSize(2 * rr, 2 * rr)
    end
    t:AddMaskTexture(m)
    t._mask = m
end

-- The plate's edge: the border along the outline grown by its shadow, a quad a segment.
local function drawEdge(art, pieceOpts)
    local B = ns.Border
    local prof = B.Profile()
    if prof.e <= 0 then
        return 0
    end
    local path = Geometry.Path(Geometry.Pieces(art.segs, art.dome, prof.out, pieceOpts), art.W)
    local quads = Geometry.Band(path, prof.e)
    local grain = B.Grain(prof)
    grainUsed = grain and B.DrawBand(frame, grainPool, quads, grain) or 0
    return B.DrawBand(frame, bandPool, quads, prof)
end

-- A flat texture over x0..x1, y0..y1 shaded from one colour to another, upwards (or rightwards).
local function shade(t, x0, y0, x1, y1, from, to, rightwards)
    colorMin = colorMin or CreateColor(0, 0, 0, 1)
    colorMax = colorMax or CreateColor(0, 0, 0, 1)
    to = to or from
    setTex(t, WHITE, 0, 1, 0, 1)
    t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x0, y0)
    t:SetSize(max(x1 - x0, 0.01), max(y1 - y0, 0.01))
    t:SetGradient(rightwards and "HORIZONTAL" or "VERTICAL", setColor(colorMin, from[1], from[2], from[3], from[4]),
        setColor(colorMax, to[1], to[2], to[3], to[4]))
end

-- The info bar and the map's foot carved into the plate, as one channel: a darker floor; along its lip, where the plate
-- stands higher, the lip's shadow on the floor, a cut line and a lit line above it; up the walls under the map, the same.
local function drawChannel(art, pieces, e)
    local T, W, d = art.T, art.W, art.dome
    local x0, x1, top
    if d and d.cy > T then
        x0, x1, top = d.cx - d.ring, d.cx + d.ring, d.cy
    end
    shade(acquire("BACKGROUND", 3), 0, 0, W, T, CHANNEL)
    if x0 then
        shade(acquire("BACKGROUND", 3), x0, T, x1, top, CHANNEL)
    end
    local function lip(a, b)
        if b - a > 0.5 then
            shade(acquire("BACKGROUND", 4), a, T - CHANNEL_SHADOW, b, T, CLEAR, SHADE)
            shade(acquire("BACKGROUND", 5), a, T - 1, b, T, LIP_CUT)
            shade(acquire("BACKGROUND", 6), a, T, b, T + 1, LIP_LIT)
        end
    end
    for _, s in ipairs(art.segs) do
        if s.top > T + e then
            if x0 then
                lip(s.x0, min(s.x1, x0))
                lip(max(s.x0, x1), s.x1)
            else
                lip(s.x0, s.x1)
            end
        end
    end
    if not x0 then
        return
    end
    -- the walls, as high as the plate beside them stands below its border
    local left = min(top, Geometry.TopAt(pieces, x0 - 1) - e)
    if left > T + 1 then
        shade(acquire("BACKGROUND", 4), x0, T, x0 + CHANNEL_SHADOW, left, SHADE, CLEAR, true)
        shade(acquire("BACKGROUND", 5), x0, T, x0 + 1, left, LIP_CUT)
        shade(acquire("BACKGROUND", 6), x0 - 1, T, x0, left, LIP_LIT)
    end
    local right = min(top, Geometry.TopAt(pieces, x1 + 1) - e)
    if right > T + 1 then
        shade(acquire("BACKGROUND", 5), x1 - 1, T, x1, right, LIP_CUT)
        shade(acquire("BACKGROUND", 6), x1, T, x1 + 1, right, LIP_LIT)
    end
end

local function drawPiece(p, layer, artTop)
    local kind = p[1]
    local t = acquire(layer.drawLayer or "BACKGROUND", layer.sub)
    if kind == "rect" then
        setTex(t, WHITE, 0, 1, 0, 1)
        paint(t, p[2], p[3], p[4], p[5], layer.foot, layer.top, artTop)
    elseif kind == "quarter" then
        local cx, cy, r = p[2], p[3], p[4]
        if p[5] == "TL" then
            setTex(t, ns.DISC, 0, 0.5, 0, 0.5)
            paint(t, cx - r, cy, cx, cy + r, layer.foot, layer.top, artTop)
        else
            setTex(t, ns.DISC, 0.5, 1, 0, 0.5)
            paint(t, cx, cy, cx + r, cy + r, layer.foot, layer.top, artTop)
        end
    elseif kind == "fillet" then
        local x, y, r, sx = p[2], p[3], p[4], p[5]
        if sx > 0 then
            setTex(t, ns.FILLET, 0, 1, 0, 1)
            paint(t, x, y, x + r, y + r, layer.foot, layer.top, artTop)
        else
            setTex(t, ns.FILLET, 1, 0, 0, 1)
            paint(t, x - r, y, x, y + r, layer.foot, layer.top, artTop)
        end
    elseif kind == "bevel" then
        -- Bevel.tga fills its lower right half, a top left corner's
        local cx, cy, r = p[2], p[3], p[4]
        if p[5] == "TL" then
            setTex(t, ns.BEVEL, 0, 1, 0, 1)
            paint(t, cx - r, cy, cx, cy + r, layer.foot, layer.top, artTop)
        else
            setTex(t, ns.BEVEL, 1, 0, 0, 1)
            paint(t, cx, cy, cx + r, cy + r, layer.foot, layer.top, artTop)
        end
    elseif kind == "slope" then
        local x, y, r, sx = p[2], p[3], p[4], p[5]
        if sx > 0 then
            setTex(t, ns.BEVEL, 1, 0, 0, 1)
            paint(t, x, y, x + r, y + r, layer.foot, layer.top, artTop)
        else
            setTex(t, ns.BEVEL, 0, 1, 0, 1)
            paint(t, x - r, y, x, y + r, layer.foot, layer.top, artTop)
        end
    elseif kind == "arc" then
        local cx, cy, r, x0, x1, y0 = p[2], p[3], p[4], p[5], p[6], p[7]
        local d = 2 * r
        setTex(t, ns.DISC, (x0 - cx + r) / d, (x1 - cx + r) / d, 0, (cy + r - y0) / d)
        paint(t, x0, y0, x1, cy + r, layer.foot, layer.top, artTop)
    else
        local cx, cy, r = p[2], p[3], p[4]
        setTex(t, ns.DISC, 0, 1, 0, 1)
        paint(t, cx - r, cy - r, cx + r, cy + r, layer.foot, layer.top, artTop)
    end
end

local function marginFor(group, o)
    if group == "bags" then
        return o.padBars, o.marginBags
    end
    return o.padBars, o.marginBars
end

-- A window's place folding away with the darkening blind (Windows.Shading): darker as it comes down, lighter as it
-- rises again (Ikar 2026-11-15), from the plate's foot to its top, up to this much black ("half darken will be
-- enough": 0.7 before, then 0.35 until Ikar asked for 0.5, 2026-11-16).
local FOLD_DARK = 0.5
Plate.FOLD_DARK = FOLD_DARK
local foldShade = { 0, 0, 0, 0 }
local function drawFoldShade(f, dark, foot)
    local top = f.y + f.h
    if top > foot then
        foldShade[4] = FOLD_DARK * dark
        shade(acquire("BACKGROUND", 6), f.x, foot, f.x + f.w, top, foldShade)
    end
end

local function quant(v)
    return math.floor(v * 4 + 0.5)
end

-- Which accepted frames were read this time (seen[frame] == stamp), so a frame under two names is read once.
local seen, stamp = {}, 0

-- An accepted frame's span in UIParent's units as the game shows it: shown and on the screen; nil otherwise, or when
-- read already this time.
local function readSpan(name, W, H)
    local f = Frames.Get(name)
    if not f or seen[f] == stamp then
        return nil
    end
    seen[f] = stamp
    if not Frames.Shown(name):IsVisible() then
        return nil
    end
    local x, y, w, h = Frames.Span(name)
    if x and w > 0 and h > 0 and x < W and x + w > 0 and y < H and y + h > 0 then
        return x, y, w, h
    end
end

-- Whether the frames are read from the game now: in Edit Mode, or before the first freeze.
local function live()
    return frozen == nil or Frames.IsEditing()
end

-- Whether an accepted frame moved, showed, hid or changed size since the last drawing (to a quarter unit). Nothing
-- allocated: it runs every frame while live.
function Plate.Moved()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    stamp = stamp + 1
    local n = 0
    for _, entry in ipairs(Frames.ACCEPTED) do
        local name = entry[1]
        local x, y, w, h = readSpan(name, W, H)
        if x then
            local base = n * 5
            n = n + 1
            if lastCoords[base + 1] ~= name or lastCoords[base + 2] ~= quant(x) or lastCoords[base + 3] ~= quant(y)
                or lastCoords[base + 4] ~= quant(w) or lastCoords[base + 5] ~= quant(h) then
                return true
            end
        end
    end
    return n ~= lastCount
end

local function recordCoords(candidates)
    lastCount = #candidates
    for i, f in ipairs(candidates) do
        local base = (i - 1) * 5
        lastCoords[base + 1] = f.key
        lastCoords[base + 2] = quant(f.x)
        lastCoords[base + 3] = quant(f.y)
        lastCoords[base + 4] = quant(f.w)
        lastCoords[base + 5] = quant(f.h)
    end
end

-- The accepted frames that show on the screen, in UIParent's units, each with its slot's padding and margin; a frame
-- under two names once. Read from the game while live, else as frozen.
function Plate.Candidates()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local o, hug = ns.db.options, ns.Border.Hug()
    local out = {}
    local function add(entry, x, y, w, h)
        local name, kind, group = entry[1], entry[2], entry[3]
        local pad, margin = marginFor(group, o)
        -- the plate's edge never covers what it holds: at the least, its metal runs flush with it
        margin = max(margin, hug)
        if kind == "window" then
            -- hugged: the plate's edge runs round them, its metal where their own border was
            pad, margin = 0, hug
        end
        out[#out + 1] = { key = name, kind = kind, group = group, x = x, y = y, w = w, h = h, pad = pad, margin = margin }
    end
    if live() then
        stamp = stamp + 1
        for _, entry in ipairs(Frames.ACCEPTED) do
            local x, y, w, h = readSpan(entry[1], W, H)
            if x then
                add(entry, x, y, w, h)
            end
        end
    else
        for _, f in ipairs(frozen.frames) do
            local entry = ACCEPTED_BY[f.key]
            if entry then
                add(entry, f.x, f.y, f.w, f.h)
            end
        end
    end
    return out
end

-- The frames as they show now, frozen: the plate is drawn from them until Edit Mode, and they're saved for this
-- character, so the next session draws the same plate.
function Plate.Freeze()
    if not ns.db then
        return
    end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local frames = {}
    stamp = stamp + 1
    for _, entry in ipairs(Frames.ACCEPTED) do
        local x, y, w, h = readSpan(entry[1], W, H)
        if x then
            frames[#frames + 1] = { key = entry[1], x = x, y = y, w = w, h = h }
        end
    end
    frozen = { W = W, H = H, t = time(), frames = frames, bars = ns.StatusBars.Shows() }
    ns.db.plates[ns.CharKey()] = frozen
    Plate.Request()
end

-- ---------- What the player moves himself ----------
-- Outside Edit Mode the plate stays as frozen, but a frame the player moves or sizes himself, the chat by its tab or
-- the damage meter by its grip, is followed (Ikar 2026-11-16: "add support for the user actions"): once he lets go,
-- that frame's record in the freeze is read again, and nothing else. Blizzard's frames end such a drag with
-- StopMovingOrSizing; the damage meter's window moves apart from its Edit Mode frame.
local MOVED_WITH = { DamageMeter = { "DamageMeterSessionWindow1" } }
local ORDER_OF, followers, watched = {}, {}, {}
for i, entry in ipairs(Frames.ACCEPTED) do
    ORDER_OF[entry[1]] = i
end

local function follow(name)
    if not frozen or Frames.IsEditing() then
        return
    end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    stamp = stamp + 1
    local x, y, w, h = readSpan(name, W, H)
    local list, at, before = frozen.frames, nil, nil
    for i, f in ipairs(list) do
        if f.key == name then
            at = i
        elseif not before and (ORDER_OF[f.key] or 0) > ORDER_OF[name] then
            before = i
        end
    end
    if x then
        local rec = at and list[at] or { key = name }
        rec.x, rec.y, rec.w, rec.h = x, y, w, h
        if not at then
            -- in the accepted frames' order, as a freeze has them
            table.insert(list, before or #list + 1, rec)
        end
    elseif at then
        table.remove(list, at)
    else
        return
    end
    frozen.t = time()
    Plate.Request()
end

-- The frames a player can move himself watched for his letting go (they may come late: watched again at each freeze).
local function watchMoves()
    for _, entry in ipairs(Frames.ACCEPTED) do
        local name = entry[1]
        local fn = followers[name]
        if not fn then
            -- hooked on the game's frames: under the handlers' guard (ns.Guarded)
            fn = ns.Guarded(function()
                ns.Later("moved " .. name, function()
                    follow(name)
                end)
            end)
            followers[name] = fn
        end
        local with = MOVED_WITH[name]
        for i = 0, with and #with or 0 do
            local target
            if i == 0 then
                target = Frames.Get(name)
            else
                target = _G[with[i]]
            end
            if type(target) == "table" and target.StopMovingOrSizing and not watched[target] then
                watched[target] = true
                hooksecurefunc(target, "StopMovingOrSizing", fn)
            end
        end
    end
end

-- What a status bar ("left", "right") showed as the plate was frozen, { kind, shows }; nil while live.
function Plate.FrozenBar(key)
    if live() or type(frozen.bars) ~= "table" then
        return nil
    end
    return frozen.bars[key]
end

-- A saved freeze this screen can use: made at its size (the UI scale and the resolution give it).
local function fits(p)
    return type(p) == "table" and math.abs(p.W - UIParent:GetWidth()) < 0.5 and math.abs(p.H - UIParent:GetHeight()) < 0.5
end

function Plate.Frozen()
    return frozen
end

-- The corners the options give the plate: the corner style, and the round corners' and curves' (or the cuts') sizes.
function Plate.Corners(o)
    local square = o.cornerStyle == "square"
    return { style = o.cornerStyle, corner = square and 0 or o.corner, fillet = square and 0 or o.fillet }
end

-- The outline over slots and the dome: closed over the narrow gaps, without the steps its border couldn't turn but
-- those of windows on their way (moving, Geometry.Smooth's); with `limit`, at most the corners set.
local function outlineOver(slots, dome, W, floor, o, corners, e, limit, moving)
    local outline = Geometry.Outline({ W = W, T = floor, reach = o.reach, bridge = o.bridge, boxes = Geometry.Boxes(slots),
        dome = dome })
    local segs = Geometry.Smooth(outline, e, corners.corner, corners.fillet, moving)
    if limit and o.maxCorners < ns.DB.UNLIMITED_CORNERS then
        -- raising a stretch can leave a step too small to turn: smoothed again
        segs = Geometry.Smooth(Geometry.LimitCorners(segs, o.maxCorners), e, corners.corner, corners.fillet)
    end
    return segs, outline
end

-- Lays the plate out from the frames (Candidates: the game's in Edit Mode, else as frozen): the frames taken and their
-- slots, the minimap's dome, the status bars placed under the bars taken or where they were dragged; the outline as
-- they give it, and as drawn, without the steps its border couldn't turn.
function Plate.Layout(fast)
    local o = ns.db.options
    local W = UIParent:GetWidth()
    local T = ns.InfoBar.Top()
    local candidates = Plate.Candidates()
    recordCoords(candidates)
    local mapW
    for _, f in ipairs(candidates) do
        if f.kind == "minimap" then
            mapW = f.w
        end
    end
    local ring, domeTop = ns.Minimap.RingWidth(o, mapW)
    local statusMargin = max(o.marginStatus, ns.Border.Hug())
    -- status bars dragged in Edit Mode are frames among the others; the rest lie along the foot under the bars, and
    -- what stands on them is within reach of their top
    for _, f in ipairs(ns.StatusBars.PlaceMoved(statusMargin, fast)) do
        candidates[#candidates + 1] = f
    end
    local row = ns.StatusBars.RowHeight()
    local base = row > 0 and T + Geometry.GAP + row + statusMargin or T
    local taken, far = Geometry.Cover({ T = base, reach = o.reach, domeRing = ring, marginDome = domeTop - ring, frames = candidates })
    local slots, bars, dome = {}, {}, nil
    for _, f in ipairs(taken) do
        if f.kind == "minimap" then
            dome = Geometry.Dome(f.x, f.y, f.w, f.h, ring, domeTop - ring)
        else
            slots[#slots + 1] = Geometry.Slot(f, f.pad, f.margin)
            if f.kind == "bar" then
                bars[#bars + 1] = f
            end
        end
    end
    local status = Geometry.StatusSlots({
        bars = bars, T = T, heights = ns.StatusBars.Heights(), widths = ns.StatusBars.Widths(),
        split = dome and dome.cx or W / 2,
        -- in to the map's ring, each bar's end straight under its side
        inner = dome and dome.ring or Geometry.GAP / 2,
        pad = o.padBars, margin = statusMargin,
    })
    for _, slot in ipairs(ns.StatusBars.Place(status, fast)) do
        slots[#slots + 1] = slot
    end
    -- where nothing stands, the edge comes down onto the info bar: its metal lies on the bar's top, never over it
    local floor = T > 0 and T + ns.Border.Hug() or T
    local corners = Plate.Corners(o)
    local e = ns.Border.Profile().e
    local segs, outline = outlineOver(slots, dome, W, floor, o, corners, e, true)
    -- A window folding or folded sinks its own place as far as its fold went (Windows.AdjustSpan), where the plate
    -- changes for it alone; the rest stands as it is, corners the limit merged included (Ikar 2026-11-15: folding
    -- mustn't change the layout).
    local held, placed, shown, gone, moving, folding = {}, {}, {}, {}, {}, false
    for _, f in ipairs(taken) do
        if f.kind == "window" then
            held[f.key] = f
        end
    end
    for _, s in ipairs(slots) do
        local f = s.kind == "window" and held[s.key]
        if f and ns.Windows.Progress(s.key) > 0 then
            folding = true
            local x, y, w, h = ns.Windows.AdjustSpan(s.key, f.x, f.y, f.w, f.h, T)
            placed[s.key] = false
            if x then
                placed[s.key] = { key = s.key, kind = "window", group = f.group, x = x, y = y, w = w, h = h, pad = 0,
                    margin = f.margin }
                local slot = Geometry.Slot(placed[s.key])
                shown[#shown + 1] = slot
                -- its place on its way, and the gaps beside it the plate bridges at its height
                local box = Geometry.Boxes({ slot })[1]
                moving[#moving + 1] = { x0 = box.x0 - o.bridge, x1 = box.x1 + o.bridge, top = box.top, floor = floor }
            end
        else
            shown[#shown + 1] = s
            gone[#gone + 1] = s
        end
    end
    if folding then
        local whole = o.maxCorners < ns.DB.UNLIMITED_CORNERS and outlineOver(slots, dome, W, floor, o, corners, e) or segs
        local without = outlineOver(gone, dome, W, floor, o, corners, e)
        local now = outlineOver(shown, dome, W, floor, o, corners, e, nil, moving)
        segs = Geometry.Smooth(Geometry.Splice(segs, now, Geometry.Differ(whole, without, W), W), e, corners.corner,
            corners.fillet, moving)
        -- what the plate holds now: each folding window as far as it went, none once folded
        local holds = {}
        for _, f in ipairs(taken) do
            local p = placed[f.key]
            if p == nil then
                holds[#holds + 1] = f
            elseif p then
                holds[#holds + 1] = p
            end
        end
        taken, slots = holds, shown
    end
    return { W = W, T = T, segs = segs, outline = outline, dome = dome, slots = slots, taken = taken, held = held, far = far }
end

-- A disc of the plate's (under the map, a pocket's mark): drawn as a piece, `foot` lit to `top`.
local function disc(cx, cy, r, sub, foot, top, artTop)
    discPiece[2], discPiece[3], discPiece[4] = cx, cy, r
    discLayer.sub, discLayer.foot, discLayer.top = sub, foot, top
    drawPiece(discPiece, discLayer, artTop)
end

function Plate.Draw(art)
    used, bandUsed, masksUsed, grainUsed = 0, 0, 0, 0
    if art then
        local o = ns.db.options
        local pieceOpts = Plate.Corners(o)
        local artTop = max(Geometry.Top(art.segs, art.dome), 1)
        local fill = ns.Border.Fill()
        local base = { foot = fill.foot, top = fill.top, sub = 0 }
        local pieces = Geometry.Pieces(art.segs, art.dome, 0, pieceOpts)
        local function fillPiece(q)
            drawPiece(q, base, artTop)
            if fill.material then
                drawTextured(q, fill.material, fill.matFoot, fill.matTop, artTop)
            end
        end
        for _, p in ipairs(pieces) do
            if p[1] == "disc" then
                for _, q in ipairs(Geometry.Arcs(art.segs, p[2], p[3], p[4])) do
                    fillPiece(q)
                end
            else
                fillPiece(p)
            end
        end
        art.band = drawEdge(art, pieceOpts)
        art.grain = grainUsed
        bandUsed = art.band
        if o.infoBar and o.footGroove and art.T > 2 then
            drawChannel(art, pieces, ns.Border.Profile().e)
        end
        art.shade = 0
        for _, f in ipairs(art.taken) do
            local dark = f.kind == "window" and ns.Windows.Shading(f.key)
            if dark then
                drawFoldShade(f, dark, art.T)
                art.shade = max(art.shade, dark)
            end
        end
        -- The slots: no recess (Ikar 2026-11-16, "creux: 0%"), the plate's background under each frame.
        -- the minimap pockets' free spots, each a small round recess, while the slots are unlocked and the map is ours
        -- (taken, with the minimap option on); under an item it read as the icon's background
        if o.pocketMarks and o.minimap and art.dome and not ns.Hub.IsLocked() then
            local spots, size, taken = ns.Hub.Pockets(art.dome, art.T, art.slots)
            for side, dir in pairs(POCKET_DIR) do
                for i, s in ipairs(spots[side]) do
                    if not taken[side][i] then
                        disc(art.dome.cx + dir * s.dx, s.y, size / 2, 1, RECESS, nil, artTop)
                    end
                end
            end
        end
        -- The map stands off the plate: it casts a soft shadow down on it, onto the info bar.
        local d = art.dome
        if d then
            local r = d.ring + SHADOW_GROW
            local sh = acquire("BACKGROUND", 2)
            setTex(sh, ns.SHADOW, 0, 1, 0, 1)
            paint(sh, d.cx - r, d.cy - SHADOW_DROP - r, d.cx + r, d.cy - SHADOW_DROP + r, MAP_SHADOW, nil, artTop)
            if o.minimap and o.minimapRing ~= "none" then
                disc(d.cx, d.cy, d.mapR + 1, 3, UNDER_RING, nil, artTop)
            else
                disc(d.cx, d.cy, d.ring + 4, 3, RECESS, nil, artTop)
                disc(d.cx, d.cy, d.ring + 1.2, 4, BRONZE, BRONZE_LIGHT, artTop)
                disc(d.cx, d.cy, d.ring, 5, NECK, nil, artTop)
            end
        end
    end
    for i = used + 1, #pool do
        if pool[i]._shown then
            pool[i]:Hide()
            pool[i]._shown = false
        end
    end
    for i = bandUsed + 1, #bandPool do
        bandPool[i]:Hide()
    end
    for i = grainUsed + 1, #grainPool do
        grainPool[i]:Hide()
    end
    for i = masksUsed + 1, #masks do
        masks[i]:Hide()
    end
    Plate.textures = used + bandUsed
end

-- With the plate off and the info bar on, the bar's own strip as the plate draws it where nothing stands on the bar:
-- its background, its border along its top, its floor (Ikar 2026-11-20: "when disabling the plaque, the info bar, if
-- still enabled, shoudl stil lshow it background as before"); nothing round the frames, the map or the windows.
local function barAlone(art)
    local o = ns.db.options
    if o.plate or not o.infoBar or art.T <= 0 then
        return nil
    end
    local segs = outlineOver({}, nil, art.W, art.T + ns.Border.Hug(), o, Plate.Corners(o), ns.Border.Profile().e)
    return { W = art.W, T = art.T, segs = segs, slots = {}, taken = {}, alone = true }
end

-- Laid out and drawn as the game is now (fast: while live, the status bars placed without reading their sources
-- again); laid out even with the plate off, the status bars going under the bars all the same, the info bar's strip
-- drawn alone (barAlone). The windows' folds and the map's dressing follow.
function Plate.Redraw(fast)
    dirty = false
    if not frame then
        return
    end
    fast = fast == true
    ns.Windows.Begin()
    local art = Plate.Layout(fast)
    local drawn = ns.db.options.plate and art or barAlone(art)
    Plate.Draw(drawn)
    Plate.drawn = drawn
    Plate.last = art
    ns.Windows.Sync(art, fast)
    ns.Minimap.SetDome(art.dome)
end

local function redrawIfAsked()
    if dirty then
        Plate.Redraw()
    end
end

-- Asked for many times in a frame, drawn once.
function Plate.Request()
    dirty = true
    ns.Later("plate", redrawIfAsked)
end

local function onLiveUpdate()
    if Plate.Moved() then
        Plate.Redraw(true)
    end
end

-- Live in Edit Mode alone: each frame, whatever was dragged, resized, shown or hidden is followed.
local function syncLive()
    if not frame then
        return
    end
    local want = Frames.IsEditing()
    if want ~= liveOn then
        liveOn = want
        -- An error there stops the following (ns.EveryFrame): the plate stays as last drawn, and the next time Edit
        -- Mode opens tries again.
        ns.EveryFrame(frame, want and onLiveUpdate or nil)
    end
end

-- Frozen again once the game has settled: the next frame, Edit Mode closed.
local function freezeLater()
    ns.Later("freeze", function()
        if not Frames.IsEditing() then
            Plate.Freeze()
        end
    end)
end

-- For /kh status and the report: each accepted frame this client has, and what the plate made of it.
function Plate.Text()
    local art = Plate.last
    local taken, seen, lines = {}, {}, {}
    for _, f in ipairs(art and art.taken or {}) do
        taken[f.key] = f
    end
    for _, entry in ipairs(Frames.ACCEPTED) do
        local name = entry[1]
        local f = Frames.Get(name)
        if f and not seen[f] then
            seen[f] = true
            local t, far = taken[name], art and art.far[name]
            local state
            if t then
                state = string.format("taken, %.1f %.1f %.1f x %.1f", t.x, t.y, t.w, t.h)
            elseif far then
                state = string.format("%.1f above the plate, out of reach", far)
            else
                state = f:IsVisible() and "off screen" or "hidden"
            end
            lines[#lines + 1] = name .. ": " .. state
        end
    end
    if ns.db then
        lines[#lines + 1] = string.format("reach %s, bridge %s", tostring(ns.db.options.reach), tostring(ns.db.options.bridge))
    end
    if Frames.IsEditing() then
        lines[#lines + 1] = "live: Edit Mode"
    elseif frozen then
        lines[#lines + 1] = string.format("frozen %s, %d frames", date("%Y-%m-%d %H:%M", frozen.t or 0), #frozen.frames)
    else
        lines[#lines + 1] = "live until the first freeze"
    end
    return table.concat(lines, "\n")
end

function Plate.Start()
    frame = CreateFrame("Frame", nil, nil)
    frame:SetParent(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    Plate.frame = frame
    -- this character's last freeze, when made at this screen's size; else one as soon as the world has settled
    local saved = ns.db.plates[ns.CharKey()]
    frozen = fits(saved) and saved or nil
    local settling = false
    watchMoves()
    ns.On("PLAYER_ENTERING_WORLD", function()
        watchMoves()
        if not frozen and not settling then
            settling = true
            C_Timer.After(SETTLE, function()
                if not frozen then
                    freezeLater()
                end
            end)
        end
        Plate.Request()
    end)
    -- the screen's units change with the UI scale and the resolution: the frames are read again where they stand
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        ns.On(event, freezeLater)
    end
    -- hooked on Edit Mode's manager and told by the game's registry: each under the handlers' guard (ns.Guarded)
    local manager = _G.EditModeManagerFrame
    local request = ns.Guarded(Plate.Request)
    if type(manager) == "table" and manager.OnSystemPositionChange then
        hooksecurefunc(manager, "OnSystemPositionChange", request)
    end
    if type(manager) == "table" and manager.OnSystemSettingChange then
        hooksecurefunc(manager, "OnSystemSettingChange", request)
    end
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Enter", ns.Guarded(function()
            syncLive()
            Plate.Request()
        end), Plate)
        EventRegistry:RegisterCallback("EditMode.Exit", ns.Guarded(function()
            syncLive()
            watchMoves()
            freezeLater()
        end), Plate)
    end
    Plate.Request()
end
