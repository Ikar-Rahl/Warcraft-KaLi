-- The plate's shape, in UIParent's units with y going up from the screen's foot: which frames it takes (Cover), the
-- minimap's dome (Dome), the status bars' places (StatusSlots), and its outline around all that (Outline, Pieces).
-- Plain numbers and no game call, so the tests run it as it is. The look was settled on the draft (art-draft/).
local _, ns = ...

local Geometry = {}
ns.Geometry = Geometry

local max, min, abs, sin, cos, sqrt, pi, huge = math.max, math.min, math.abs, math.sin, math.cos, math.sqrt, math.pi, math.huge

-- Default padding inside a slot, the plate's margin around it, the status bars' gap above the info bar (3: where Ikar
-- dragged his, 2026-11-15), a step's rounded corner and the concave curve under it. Live values come from options where
-- given.
local PAD, MARGIN, GAP, CORNER, FILLET = 5, 8, 3, 8, 10
Geometry.PAD, Geometry.MARGIN, Geometry.GAP = PAD, MARGIN, GAP
Geometry.CORNER, Geometry.FILLET = CORNER, FILLET
-- The minimap's bronze ring past the map, and the dome past the ring.
Geometry.RING, Geometry.DOME = 6, 12
-- A status bar's width with no bar above it.
Geometry.DEFAULT_STATUS_WIDTH = 420
-- How many steps stand for the dome's upper half when the plate fills up to it.
local CHORDS = 8
-- How far a pocket's place comes onto the map's ring (Ikar 2026-11-14: "ok if it encroaches a bit").
Geometry.POCKET_ENCROACH = 2

-- The dome around a minimap at x, y, w by h: its centre, the map's radius, the bronze ring's radius and the dome's.
function Geometry.Dome(x, y, w, h, ringWidth, domeWidth)
    local mapR = max(w, h) / 2
    local ring = mapR + (ringWidth or Geometry.RING)
    return { cx = x + w / 2, cy = y + h / 2, mapR = mapR, ring = ring, r = ring + (domeWidth or Geometry.DOME) }
end

-- A point on a circle (cx, cy, r) at `deg` degrees counter-clockwise from 3 o'clock (90 = top, 180 = left, 270 = foot).
function Geometry.Polar(cx, cy, r, deg)
    local rad = deg * pi / 180
    return cx + r * cos(rad), cy + r * sin(rad)
end

-- Angle in degrees [0, 360) from (cx, cy) to (x, y), counter-clockwise from 3 o'clock.
function Geometry.Angle(cx, cy, x, y)
    local deg = math.atan2(y - cy, x - cx) * 180 / pi
    if deg < 0 then
        deg = deg + 360
    end
    return math.floor(deg + 0.5) % 360
end

-- The largest disc nestled in each lower corner pocket between the dome's outer wall (dome.r), its ring (dome.ring)
-- and the info bar's top (T): { r, dx, y }, or nil when the minimap sits too high/low for a pocket.
function Geometry.DomePocket(dome, T)
    local a, c, ro = dome.r - 2, dome.cy - (T + 2), dome.ring + 2
    if a <= 4 or c <= 4 then
        return nil
    end
    local lo, hi = 0, min(a, c)
    for _ = 1, 24 do
        local r = (lo + hi) / 2
        if sqrt((a - r) ^ 2 + (c - r) ^ 2) - (ro + r) > 0 then
            lo = r
        else
            hi = r
        end
    end
    if lo < 6 then
        return nil
    end
    return { r = lo, dx = a - lo, y = T + 2 + lo }
end

-- A pocket's places stand as a triangle like the pocket's own (Ikar 2026-11-16: "you removed the triangle, keep it. I
-- just wanted equal spacing, but on the triangle"): rows along the floor, columns up the dome's side, each row one
-- shorter than the one under it, so three are one in the corner, one above it, one beside it towards the map; six add
-- a row and a column. At most this many rows: six places a pocket.
local POCKET_ROWS = 3
-- The gap between two places' icons, and round them to the pocket's edges, at the least: for three; for more, while
-- they can afford it (Ikar 2026-11-16: "when we can afford, maybe add more than 3 slots"), half an icon at the least.
Geometry.POCKET_GAP = 2
local POCKET_ROOMY = 0.5

-- The cells (r, c) of a triangle k rows high, r up from the floor, c in from the dome's side: the corner, then each
-- diagonal from up the side down to the floor.
local function triangle(k)
    local cells = {}
    for shell = 0, k - 1 do
        for r = shell, 0, -1 do
            cells[#cells + 1] = { r = r, c = shell - r }
        end
    end
    return cells
end
local TRIANGLES = {}
for k = 1, POCKET_ROWS do
    TRIANGLES[k] = triangle(k)
end
-- Two places where three don't fit: the corner and above it, or the corner and beside it.
local PAIRS = { { { r = 0, c = 0 }, { r = 1, c = 0 } }, { { r = 0, c = 0 }, { r = 0, c = 1 } } }

-- Where icons `size` wide stand in a lower corner pocket of the dome: between the dome's side, the map's ring
-- (POCKET_ENCROACH onto it), the floor (the info bar's top, or block's top where block stands under the pocket:
-- { dx, top }, a status bar from dx out from the dome's centre), never under the map's middle half (the zone's).
-- Places as a triangle (TRIANGLES) evenly spaced: the same gap between two icons as between an icon and the pocket's
-- edges (the edges' own 2 counted in), the widest the pocket lets them have, so they spread as far as it goes without
-- pressing into its corners. As
-- many rows as stand POCKET_ROOMY apart, three places as soon as they stand apart at all; else two, else one. A status
-- bar under the pocket: the triangle on the info bar beside the bar's end, or on the bar, whichever spreads it more.
-- Each { dx, y }, dx out from the dome's centre, the corner first; none without room for one.
function Geometry.PocketSpots(dome, T, size, block)
    local rs = size / 2
    local wall, inner, ring = dome.r - 2, dome.mapR / 2, dome.ring - Geometry.POCKET_ENCROACH
    -- the pocket's edges (the side and floor 2 in, the ring 2 onto) already keep POCKET_GAP: an icon's gap to them is
    -- what its gap to the next icon has over that
    local function clear(dx, y, g)
        local e, floor = g - Geometry.POCKET_GAP, T + 2
        if block and dx + rs + e > block.dx then
            floor = block.top + 2
        end
        return dx >= inner - 0.01 and y <= dome.cy + 0.01 and y - rs - e >= floor - 0.01
            and dx * dx + (dome.cy - y) ^ 2 >= (ring + e + rs - 0.01) ^ 2
    end
    -- the triangle's corner: by the dome's side on the info bar, else beside a status bar's end, else on it
    local anchors = { { x = wall, floor = T + 2 } }
    if block then
        anchors[2] = { x = min(wall, block.dx), floor = T + 2 }
        anchors[3] = { x = wall, floor = block.top + 2 }
    end
    local function stand(cells, a, g, out)
        local step, inset = size + g, rs + g - Geometry.POCKET_GAP
        for i, cell in ipairs(cells) do
            local dx, y = a.x - inset - cell.c * step, a.floor + inset + cell.r * step
            if not clear(dx, y, g) then
                return false
            end
            if out then
                out[i] = { dx = dx, y = y }
            end
        end
        return true
    end
    -- the widest gap the cells stand at from anchor a, lo at the least; nil when not even lo
    local function widest(cells, a, lo)
        if not stand(cells, a, lo) then
            return nil
        end
        local hi = lo + 4
        while stand(cells, a, hi) do
            lo, hi = hi, hi * 2
            if hi > 1000 then
                return lo
            end
        end
        for _ = 1, 24 do
            local mid = (lo + hi) / 2
            if stand(cells, a, mid) then
                lo = mid
            else
                hi = mid
            end
        end
        return lo
    end
    local function spread(cells, lo)
        local g, at
        for _, a in ipairs(anchors) do
            local w = widest(cells, a, lo)
            if w and (not g or w > g + 0.01) then
                g, at = w, a
            end
        end
        if not g then
            return nil
        end
        local out = {}
        stand(cells, at, g, out)
        return out, g
    end
    for k = POCKET_ROWS, 2, -1 do
        local out = spread(TRIANGLES[k], k == 2 and Geometry.POCKET_GAP or max(Geometry.POCKET_GAP, POCKET_ROOMY * size))
        if out then
            return out
        end
    end
    local pair, pairGap
    for _, cells in ipairs(PAIRS) do
        local out, g = spread(cells, Geometry.POCKET_GAP)
        if out and (not pairGap or g > pairGap + 0.01) then
            pair, pairGap = out, g
        end
    end
    return pair or spread(TRIANGLES[1], Geometry.POCKET_GAP) or {}
end

-- A frame's slot, its dark recess: the frame and its padding, carrying its margin and kind for the plate.
function Geometry.Slot(f, pad, margin)
    local p = pad ~= nil and pad or f.pad ~= nil and f.pad or PAD
    local m = margin ~= nil and margin or f.margin ~= nil and f.margin or MARGIN
    return { key = f.key, kind = f.kind, x = f.x - p, y = f.y - p, w = f.w + 2 * p, h = f.h + 2 * p, margin = m }
end

-- The plate's columns around slots { x, y, w, h, margin }: each grown by its margin, from the foot up.
function Geometry.Boxes(slots, defaultMargin)
    local fallback = defaultMargin ~= nil and defaultMargin or MARGIN
    local boxes = {}
    for _, s in ipairs(slots) do
        local m = s.margin ~= nil and s.margin or fallback
        boxes[#boxes + 1] = { x0 = s.x - m, x1 = s.x + s.w + m, top = s.y + s.h + m }
    end
    return boxes
end

-- What a frame takes of the plate, from the foot up: its slot's column, or for the minimap its dome.
local function column(f, o)
    if f.kind == "minimap" then
        local d = Geometry.Dome(f.x, f.y, f.w, f.h, o and o.domeRing, o and o.marginDome)
        return { x0 = d.cx - d.r, x1 = d.cx + d.r, top = d.cy + d.r }
    end
    local s = Geometry.Slot(f)
    local m = s.margin
    return { x0 = s.x - m, x1 = s.x + s.w + m, top = s.y + s.h + m }
end

-- The frames the plate takes. o.frames = { { key, kind, x, y, w, h, pad, margin } }: the accepted frames that show;
-- o.T: the info bar's top; o.reach. A frame is taken when its foot is at most reach above the plate under it, the
-- info bar's or a taken frame's, so taking one can bring another in reach. Returns the frames taken, in o.frames'
-- order, and how far above the plate each one left out is: { [key] = distance }.
function Geometry.Cover(o)
    local taken, columns = {}, {}
    local function under(f)
        local top = o.T
        for _, c in ipairs(columns) do
            if c.x0 < f.x + f.w and c.x1 > f.x then
                top = max(top, c.top)
            end
        end
        return top
    end
    local more = true
    while more do
        more = false
        for i, f in ipairs(o.frames) do
            if not taken[i] and f.y - under(f) <= o.reach then
                taken[i], more = true, true
                columns[#columns + 1] = column(f, o)
            end
        end
    end
    local out, far = {}, {}
    for i, f in ipairs(o.frames) do
        if taken[i] then
            out[#out + 1] = f
        else
            far[f.key] = f.y - under(f)
        end
    end
    return out, far
end

-- The status bars' places along the info bar, either side of o.split (the dome's centre, or the screen's): from o.inner
-- off it (the map's ring, Ikar 2026-11-15: "they should sit like the one on the left") out to the far end of the level
-- bars taken on that side (o.bars; an upright one doesn't count), DEFAULT_STATUS_WIDTH with none, or o.widths[side]
-- when above 0; o.heights[side] tall (none when 0), on the taller one's middle line.
-- Returns { [-1] = slot, [1] = slot }.
function Geometry.StatusSlots(o)
    local out = {}
    local pad = o.pad ~= nil and o.pad or PAD
    local margin = o.margin ~= nil and o.margin or MARGIN
    local gap = o.gap ~= nil and o.gap or GAP
    local row = max(o.heights[-1] or 0, o.heights[1] or 0)
    for _, side in ipairs({ -1, 1 }) do
        local edge, w, any = o.split + side * o.inner, 0, false
        for _, b in ipairs(o.bars) do
            local bp = b.pad ~= nil and b.pad or pad
            if b.w >= b.h and (b.x + b.w / 2 - o.split) * side > 0 then
                any = true
                w = max(w, ((side < 0 and b.x - bp or b.x + b.w + bp) - edge) * side)
            end
        end
        if not any then
            w = Geometry.DEFAULT_STATUS_WIDTH
        end
        local given, h = o.widths and o.widths[side] or 0, o.heights[side] or 0
        if given > 0 then
            w = given
        end
        if w > 1 and h > 0 then
            out[side] = { key = "status" .. side, kind = "status", x = side < 0 and edge - w or edge,
                y = o.T + gap + (row - h) / 2, w = w, h = h, margin = margin }
        end
    end
    return out
end

local function round(v)
    return math.floor(v * 100 + 0.5) / 100
end

-- A function over 0..W in stretches, from its value at the middle of each stretch between cuts: value(x) gives a top
-- and whether it's the dome's arch. Neighbours alike merge.
local function sample(cuts, W, value)
    local seen, xs = {}, {}
    for _, x in ipairs(cuts) do
        x = round(max(0, min(W, x)))
        if not seen[x] then
            seen[x] = true
            xs[#xs + 1] = x
        end
    end
    table.sort(xs)
    local segs = {}
    for i = 1, #xs - 1 do
        local lo, hi = xs[i], xs[i + 1]
        local top, dome = value((lo + hi) / 2)
        local last = segs[#segs]
        if last and abs(last.top - top) < 0.01 and last.dome == dome then
            last.x1 = hi
        else
            segs[#segs + 1] = { x0 = lo, x1 = hi, top = top, dome = dome }
        end
    end
    return segs
end

local function segmentAt(segs, x)
    for _, s in ipairs(segs) do
        if s.x0 <= x and s.x1 >= x then
            return s
        end
    end
end

-- The plate's top edge across the screen: the highest box over each stretch, the info bar's (T) under all. Returns
-- { { x0, x1, top, dome } } from left to right; dome marks a stretch of the dome's arch.
function Geometry.Envelope(boxes, W, T)
    local cuts = { 0, W }
    for _, b in ipairs(boxes) do
        cuts[#cuts + 1] = b.x0
        cuts[#cuts + 1] = b.x1
    end
    return sample(cuts, W, function(x)
        local top, dome = T, false
        for _, b in ipairs(boxes) do
            if b.x0 <= x and b.x1 >= x and b.top > top then
                top, dome = b.top, b.dome == true
            end
        end
        return top, dome
    end)
end

local function edges(cuts, segs, by)
    for _, s in ipairs(segs) do
        for _, x in ipairs({ s.x0, s.x1 }) do
            cuts[#cuts + 1] = x - by
            cuts[#cuts + 1] = x + by
        end
    end
    return cuts
end

-- The outline closed over every gap narrower than reach: a hollow between two higher stretches, or between one and
-- the screen's edge, fills up to its lower side; nothing else changes. A closing by a flat reach-wide segment: the
-- highest over each reach around, then the lowest of that.
function Geometry.Close(segs, W, reach)
    if not (reach and reach > 0 and W > reach) then
        return segs
    end
    local e = reach / 2
    local wide = sample(edges({ 0, W, e, W - e }, segs, e), W, function(x)
        -- Past the screen's edges, a wall.
        if x - e < 0 or x + e > W then
            return huge, false
        end
        local top = -huge
        for _, s in ipairs(segs) do
            if s.x0 < x + e and s.x1 > x - e then
                top = max(top, s.top)
            end
        end
        return top, false
    end)
    return sample(edges({ 0, W }, wide, e), W, function(x)
        local top = huge
        for _, s in ipairs(wide) do
            if s.x0 < x + e and s.x1 > x - e then
                top = min(top, s.top)
            end
        end
        return top, false
    end)
end

-- Where two outlines over 0..W stand apart: { { x0, x1 } } from left to right.
function Geometry.Differ(a, b, W)
    local out = {}
    for _, s in ipairs(sample(edges(edges({ 0, W }, a, 0), b, 0), W, function(x)
        return abs(segmentAt(a, x).top - segmentAt(b, x).top) > 0.01 and 1 or 0, false
    end)) do
        if s.top > 0 then
            out[#out + 1] = { x0 = s.x0, x1 = s.x1 }
        end
    end
    return out
end

-- The outline `base` with `over` in its place within zones ({ x0, x1 }): one outline over 0..W.
function Geometry.Splice(base, over, zones, W)
    return sample(edges(edges(edges({ 0, W }, base, 0), over, 0), zones, 0), W, function(x)
        local from = base
        for _, z in ipairs(zones) do
            if z.x0 <= x and z.x1 >= x then
                from = over
            end
        end
        local s = segmentAt(from, x)
        return s.top, s.dome == true
    end)
end

-- The plate's outline. o.W, o.T; o.boxes: the columns of what it holds; o.dome: the minimap's, or nil; o.bridge (or
-- o.reach): widest horizontal gap to close. The dome stands on an arch, a column up to its centre that the disc rounds
-- off. Every gap narrower than bridge closes, the dome's upper half counting as steps inside it, so the plate fills up
-- its side; where the disc stands higher than what fills up to it, the arch stays as it is. Returns Envelope's stretches.
function Geometry.Outline(o)
    local W, T, dome = o.W, o.T, o.dome
    local bridge = o.bridge ~= nil and o.bridge or o.reach
    local boxes, chords = {}, {}
    for _, b in ipairs(o.boxes) do
        boxes[#boxes + 1] = b
    end
    if not dome then
        return Geometry.Close(Geometry.Envelope(boxes, W, T), W, bridge)
    end
    boxes[#boxes + 1] = { x0 = dome.cx - dome.r, x1 = dome.cx + dome.r, top = dome.cy, dome = true }
    local plain = Geometry.Envelope(boxes, W, T)
    local all = {}
    for i, b in ipairs(boxes) do
        all[i] = b
    end
    for i = 1, CHORDS do
        local a = i * pi / 2 / (CHORDS + 1)
        local half = dome.r * cos(a)
        chords[i] = { x0 = dome.cx - half, x1 = dome.cx + half, top = dome.cy + dome.r * sin(a) }
        all[#all + 1] = chords[i]
    end
    local closed = Geometry.Close(Geometry.Envelope(all, W, T), W, bridge)
    local cuts = edges(edges({ 0, W }, closed, 0), plain, 0)
    return sample(edges(cuts, chords, 0), W, function(x)
        local c, p = segmentAt(closed, x).top, segmentAt(plain, x)
        local k = -huge
        for _, s in ipairs(chords) do
            if s.x0 < x and s.x1 > x then
                k = max(k, s.top)
            end
        end
        if c > k + 0.01 and c > p.top + 0.01 then
            return c, false
        end
        return p.top, p.dome
    end)
end

-- A plate from below the screen's foot to `top`, its top corners turned by a (left) and c (right), grown by off: round,
-- a quarter disc; bevel, a 45-degree cut.
local BEVEL_GROW = 2 - sqrt(2)
local function roundedRect(out, x0, x1, top, a, c, off, bevel)
    local L, R, t, bot = x0 - off, x1 + off, top + off, -off - 2
    -- grown by off, a cut stays off away from where it was: its sides grow by less
    local grow = bevel and off * BEVEL_GROW or off
    local a2 = a > 0 and a + grow or 0
    local c2 = c > 0 and c + grow or 0
    local kind = bevel and "bevel" or "quarter"
    out[#out + 1] = { "rect", L + a2, bot, R - c2, t }
    if a2 > 0 then
        out[#out + 1] = { "rect", L, bot, L + a2, t - a2 }
        out[#out + 1] = { kind, L + a2, t - a2, a2, "TL" }
    end
    if c2 > 0 then
        out[#out + 1] = { "rect", R - c2, bot, R, t - c2 }
        out[#out + 1] = { kind, R - c2, t - c2, c2, "TR" }
    end
end

-- Every piece of the plate, grown by off; drawn one over the other in one colour, they make one shape. A piece is:
--   { "rect", x0, y0, x1, y1 }
--   { "quarter", cx, cy, r, "TL"|"TR" }: the quarter of a disc above its centre, on that side
--   { "bevel", cx, cy, r, "TL"|"TR" }: the same square cut by its diagonal, the half under the cut
--   { "fillet", x, y, r, sx }: a square from (x, y), r wide towards sx and r high, less the quarter disc centred on
--     its far top corner: the concave curve where a lower plate meets a wall
--   { "slope", x, y, r, sx }: the same square's half against the wall, under its diagonal: a concave cut
--   { "disc", cx, cy, r }
-- dome: { cx, cy, r } or nil. The arch's corners and those against it stay square: the disc's edge runs there.
-- opts: { corner, fillet, style = "round"|"square"|"bevel" }.
function Geometry.Pieces(segs, dome, off, opts)
    local style = opts and opts.style or "round"
    local bevel = style == "bevel"
    local cornerR = style == "square" and 0 or opts and opts.corner ~= nil and opts.corner or CORNER
    local filletR = style == "square" and 0 or opts and opts.fillet ~= nil and opts.fillet or FILLET
    local out = {}
    for i, s in ipairs(segs) do
        local prev, nxt = segs[i - 1], segs[i + 1]
        local width = s.x1 - s.x0
        local a = prev and prev.top < s.top and not (s.dome or prev.dome) and min(cornerR, (s.top - prev.top) / 2, width / 2) or 0
        local c = nxt and nxt.top < s.top and not (s.dome or nxt.dome) and min(cornerR, (s.top - nxt.top) / 2, width / 2) or 0
        roundedRect(out, s.x0, s.x1, s.top, a, c, off, bevel)
        if prev and abs(prev.top - s.top) > 0.5 then
            local thisLower = s.top < prev.top
            local lowerWidth = thisLower and width or prev.x1 - prev.x0
            local wallSeg = thisLower and prev or s
            local lowerTop = min(s.top, prev.top)
            local r = min(filletR, abs(prev.top - s.top) / 2, lowerWidth / 2) - (bevel and off * BEVEL_GROW or off)
            local sx = thisLower and 1 or -1
            if r > 0.2 then
                local wallX = s.x0
                if dome and (s.dome or prev.dome) and wallSeg.dome and lowerTop > dome.cy then
                    local k = (dome.r + filletR) ^ 2 - (lowerTop + filletR - dome.cy) ^ 2
                    if k > 0 then
                        wallX = dome.cx - sx * (sqrt(k) - filletR)
                    end
                end
                out[#out + 1] = { bevel and "slope" or "fillet", wallX + sx * off, lowerTop + off, r, sx }
            end
        end
    end
    if dome then
        out[#out + 1] = { "disc", dome.cx, dome.cy, dome.r + off }
    end
    return out
end

-- The disc (cx, cy, r) where it stands above the stretches under it, a strip over each: { "arc", cx, cy, r, x0, x1, y0 },
-- from y0 up to its edge. Drawn over the stretches, a see-through colour or the material would show twice.
function Geometry.Arcs(segs, cx, cy, r)
    local out = {}
    for _, s in ipairs(segs) do
        local x0, x1, y0 = max(s.x0, cx - r), min(s.x1, cx + r), max(s.top, cy)
        local d = max(x0 - cx, cx - x1, 0)
        if x1 > x0 and d < r and cy + sqrt(r * r - d * d) > y0 then
            out[#out + 1] = { "arc", cx, cy, r, x0, x1, y0 }
        end
    end
    return out
end

-- The plate's highest point, for its colour running from the foot to the top.
function Geometry.Top(segs, dome)
    local top = 0
    for _, s in ipairs(segs) do
        top = max(top, s.top)
    end
    if dome then
        top = max(top, dome.cy + dome.r)
    end
    return top
end

-- The top of one of Pieces' pieces over x, or nil where it isn't.
local function pieceTop(p, x)
    local kind = p[1]
    if kind == "rect" then
        if x >= p[2] and x <= p[4] then
            return p[5]
        end
    elseif kind == "fillet" then
        local r = p[4]
        local u = (x - p[2]) * p[5]
        if u >= 0 and u <= r then
            return p[3] + r - sqrt(max(0, r * r - (r - u) ^ 2))
        end
    elseif kind == "slope" then
        local r = p[4]
        local u = (x - p[2]) * p[5]
        if u >= 0 and u <= r then
            return p[3] + r - u
        end
    elseif kind == "bevel" then
        local dx, r = x - p[2], p[4]
        if p[5] == "TL" and dx >= -r and dx <= 0 or p[5] == "TR" and dx >= 0 and dx <= r then
            return p[3] + r - abs(dx)
        end
    else
        local dx, r = x - p[2], p[4]
        local lo, hi = -r, r
        if kind == "quarter" then
            lo, hi = p[5] == "TL" and -r or 0, p[5] == "TL" and 0 or r
        end
        if dx >= lo and dx <= hi then
            return p[3] + sqrt(max(0, r * r - dx * dx))
        end
    end
end

-- The outline without transitions it couldn't draw, the border e deep, corners and curves of corner and fillet: a
-- step lower than both together, or than e, goes up to its higher side; a stretch too narrow for its own (both, or
-- two curves between two higher sides) goes up to the lower of the higher sides next to it. Only ever up, so it still
-- covers what it took. The dome's arch stays as it is. moving: { { x0, x1, top, floor } }, the places of windows on
-- their way folding or unfolding, the stretches at their top within them: they never raise another, nor are raised
-- but onto the plate's floor (sunk under it, a place is gone into it), their steps drawn as small as they come, the
-- curves shrunk to them (Pieces; Ikar 2026-11-16: a window folding near the foot had the border next to it jump up to
-- its top "for a couple of frames ... looks bad").
function Geometry.Smooth(segs, e, corner, fillet, moving)
    local jump, notch = max(e, corner + fillet), max(e, 2 * fillet)
    local function movingFloor(s)
        for _, m in ipairs(moving or {}) do
            if abs(s.top - m.top) < 0.01 and s.x0 >= m.x0 - 0.01 and s.x1 <= m.x1 + 0.01 then
                return m.floor or -huge
            end
        end
    end
    local out = {}
    for i, s in ipairs(segs) do
        local floor = movingFloor(s)
        out[i] = { x0 = s.x0, x1 = s.x1, top = s.top, dome = s.dome, moving = floor ~= nil, floor = floor }
    end
    local function higher(n, s)
        return n and not n.dome and not n.moving and n.top > s.top + 0.01 and n.top or nil
    end
    local changed = true
    while changed do
        changed = false
        for i, s in ipairs(out) do
            local hp, hn = higher(out[i - 1], s), higher(out[i + 1], s)
            if not s.dome and (hp or hn) then
                local narrow = s.x1 - s.x0 < (hp and hn and notch or jump)
                local up
                if hp and (narrow or hp - s.top < jump) then
                    up = hp
                end
                if hn and (narrow or hn - s.top < jump) then
                    up = up and min(up, hn) or hn
                end
                if up and s.moving and up > s.floor + 0.01 then
                    up = nil
                end
                if up then
                    s.top, changed = up, true
                end
            end
        end
        local merged = {}
        for _, s in ipairs(out) do
            local last = merged[#merged]
            if last and not (last.dome or s.dome) and abs(last.top - s.top) < 0.01 then
                last.x1, last.moving, last.floor = s.x1, last.moving or s.moving, last.floor or s.floor
            else
                merged[#merged + 1] = s
            end
        end
        out = merged
    end
    return out
end

-- The outline's corners: two at each step between stretches, the dome's arch's included.
function Geometry.Corners(segs)
    local n = 0
    for i = 2, #segs do
        local a, b = segs[i - 1], segs[i]
        if abs(a.top - b.top) >= 0.01 then
            n = n + 2
        end
    end
    return n
end

-- The outline with at most `most` corners (Corners'), 0 for one straight line; nil: as it is. Each time, the stretch
-- that fills the least area going up to its lower higher neighbour goes up, merging with it; the dome's arch too, then
-- plate like the rest, its disc still standing on it. Only ever up, so it still covers what it took.
function Geometry.LimitCorners(segs, most)
    local out = {}
    for i, s in ipairs(segs) do
        out[i] = { x0 = s.x0, x1 = s.x1, top = s.top, dome = s.dome }
    end
    if not most then
        return out
    end
    -- A neighbour that stands higher by what Corners counts as a step, written as Corners writes it: asked another
    -- way (n.top > s.top + 0.01), a step of just that much was a corner for one and none for the other, and nothing
    -- was found to raise (0.51 - 0.5 is a hair over 0.01; 0.5 + 0.01 is 0.51).
    local function higher(n, s)
        return n and n.top - s.top >= 0.01 and n.top or nil
    end
    -- a step always has a lower side that can go up: this ends
    while Geometry.Corners(out) > most do
        local best, bestTop, bestArea
        for i, s in ipairs(out) do
            local hp, hn = higher(out[i - 1], s), higher(out[i + 1], s)
            local up = hp and hn and min(hp, hn) or hp or hn
            local area = up and (s.x1 - s.x0) * (up - s.top)
            if area and (not bestArea or area < bestArea) then
                best, bestTop, bestArea = s, up, area
            end
        end
        if not best then
            break
        end
        best.top, best.dome = bestTop, nil
        local merged = {}
        for _, s in ipairs(out) do
            local last = merged[#merged]
            if last and not (last.dome or s.dome) and abs(last.top - s.top) < 0.01 then
                last.x1 = s.x1
            else
                merged[#merged + 1] = s
            end
        end
        out = merged
    end
    return out
end

local function topAt(pieces, x)
    local top = -huge
    for _, p in ipairs(pieces) do
        local t = pieceTop(p, x)
        if t and t > top then
            top = t
        end
    end
    return top
end
-- The plate's top over x: the highest of Pieces' pieces there.
Geometry.TopAt = topAt

-- x every `step` along an arc of (cx, r) from angle a0 to a1.
local function arcXs(xs, cx, r, a0, a1, step)
    local n = max(1, math.ceil(abs(a1 - a0) * r / step))
    for i = 0, n do
        xs[#xs + 1] = cx + r * cos(a0 + (a1 - a0) * i / n)
    end
end

-- A circle as a closed line, counter-clockwise, in steps about `step` long: Band puts its inner side outside it.
function Geometry.Circle(cx, cy, r, step)
    local n = max(12, math.ceil(2 * pi * r / (step or 2)))
    local pts = {}
    for i = 0, n - 1 do
        local a = 2 * pi * i / n
        pts[#pts + 1], pts[#pts + 2] = cx + r * cos(a), cy + r * sin(a)
    end
    pts[#pts + 1], pts[#pts + 2] = pts[1], pts[2]
    return pts
end

-- A rectangle as a closed line, clockwise: Band puts its inner side inside it. Its corners r round (in steps about
-- `step` long), cut (style "bevel") or square (r 0).
function Geometry.Rect(x0, y0, x1, y1, r, style, step)
    r = max(0, min(r or 0, (x1 - x0) / 2, (y1 - y0) / 2))
    local pts = {}
    local function corner(cx, cy, a0)
        if r <= 0 then
            pts[#pts + 1], pts[#pts + 2] = cx, cy
            return
        end
        local n = style == "bevel" and 1 or max(2, math.ceil(pi / 2 * r / (step or 1)))
        for i = 0, n do
            local a = a0 - pi / 2 * i / n
            pts[#pts + 1], pts[#pts + 2] = cx + r * cos(a), cy + r * sin(a)
        end
    end
    corner(x0 + r, y1 - r, pi)
    corner(x1 - r, y1 - r, pi / 2)
    corner(x1 - r, y0 + r, 0)
    corner(x0 + r, y0 + r, -pi / 2)
    pts[#pts + 1], pts[#pts + 2] = pts[1], pts[2]
    return pts
end

-- The plate's edge as one line across the screen, left to right: { x1, y1, x2, y2, ... }. Pieces draw the plate from
-- the foot up, so its edge is the highest piece over each x: walls upright, curves in steps about `step` long.
function Geometry.Path(pieces, W, step)
    step = step or 2
    local xs = { 0, W }
    for _, p in ipairs(pieces) do
        local kind, r = p[1], p[4]
        if kind == "rect" then
            xs[#xs + 1], xs[#xs + 2] = p[2], p[4]
        elseif kind == "quarter" then
            arcXs(xs, p[2], r, p[5] == "TL" and pi or pi / 2, p[5] == "TL" and pi / 2 or 0, step)
        elseif kind == "fillet" then
            arcXs(xs, p[2] + p[5] * r, r, p[5] > 0 and pi or 0, p[5] > 0 and 1.5 * pi or -pi / 2, step)
        elseif kind == "bevel" then
            xs[#xs + 1], xs[#xs + 2] = p[2], p[2] + (p[5] == "TL" and -r or r)
        elseif kind == "slope" then
            xs[#xs + 1], xs[#xs + 2] = p[2], p[2] + p[5] * r
        else
            arcXs(xs, p[2], r, pi, 0, step)
        end
    end
    local sorted = {}
    for _, x in ipairs(xs) do
        if x >= 0 and x <= W then
            sorted[#sorted + 1] = x
        end
    end
    table.sort(sorted)
    local pts = {}
    local function add(x, y)
        local n = #pts
        if n >= 2 and abs(pts[n - 1] - x) < 1e-6 and abs(pts[n] - y) < 1e-6 then
            return
        end
        -- three points in a line: the middle one goes
        if n >= 4 then
            local x0, y0, x1, y1 = pts[n - 3], pts[n - 2], pts[n - 1], pts[n]
            local len = sqrt((x - x0) ^ 2 + (y - y0) ^ 2)
            local ahead = (x1 - x0) * (x - x1) + (y1 - y0) * (y - y1) >= 0
            if ahead and len > 0 and abs((x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)) / len < 0.01 then
                pts[n - 1], pts[n] = x, y
                return
            end
        end
        pts[n + 1], pts[n + 2] = x, y
    end
    -- edges less than a hundredth apart are one, read past all of them: a disc's rim a hair inside it tilted the line
    local i = 1
    while i <= #sorted do
        local j = i
        while j < #sorted and sorted[j + 1] - sorted[j] < 0.01 do
            j = j + 1
        end
        local lo, hi = sorted[i], sorted[j]
        local x = round((lo + hi) / 2)
        if lo > 0 then
            add(x, topAt(pieces, lo - 1e-3))
        end
        if hi < W then
            add(x, topAt(pieces, hi + 1e-3))
        end
        i = j + 1
    end
    return pts
end

-- The band `e` wide inside a line { x1, y1, ... } walked left to right with the plate below it: a quad a segment,
-- { ox0, oy0, ox1, oy1, ix0, iy0, ix1, iy1 }, its outer edge on the line and its inner one e in, cut at each bend along
-- the bisector so the quads meet edge to edge; a line that ends where it starts is cut there too. Where a convex bend is
-- tighter than e, inner edges would run backwards: their ends gather at one point instead.
function Geometry.Band(pts, e)
    local segs = {}
    for i = 1, #pts - 3, 2 do
        local x0, y0, x1, y1 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        local len = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
        if len > 1e-6 then
            segs[#segs + 1] = { x0, y0, x1, y1, (y1 - y0) / len, -(x1 - x0) / len }
        end
    end
    local n = #segs
    local closed = n > 2 and abs(pts[1] - pts[#pts - 1]) < 1e-6 and abs(pts[2] - pts[#pts]) < 1e-6
    local ix, iy = {}, {}
    for j = 0, n do
        local a, b = segs[j], segs[j + 1]
        if closed then
            a, b = a or segs[n], b or segs[1]
        end
        if a and b then
            local k = e / max(0.05, 1 + a[5] * b[5] + a[6] * b[6])
            ix[j], iy[j] = b[1] + (a[5] + b[5]) * k, b[2] + (a[6] + b[6]) * k
        elseif b then
            ix[j], iy[j] = b[1] + b[5] * e, b[2] + b[6] * e
        elseif a then
            ix[j], iy[j] = a[3] + a[5] * e, a[4] + a[6] * e
        end
    end
    local function backwards(i)
        local s = segs[i]
        return (ix[i] - ix[i - 1]) * (s[3] - s[1]) + (iy[i] - iy[i - 1]) * (s[4] - s[2]) < -1e-6
    end
    for _ = 1, 6 do
        local fixed, i = false, 1
        while i <= n do
            if backwards(i) then
                local j = i
                while j < n and backwards(j + 1) do
                    j = j + 1
                end
                local sx, sy = 0, 0
                for k = i - 1, j do
                    sx, sy = sx + ix[k], sy + iy[k]
                end
                local m = j - i + 2
                for k = i - 1, j do
                    ix[k], iy[k] = sx / m, sy / m
                end
                fixed, i = true, j + 1
            else
                i = i + 1
            end
        end
        if not fixed then
            break
        end
    end
    local quads = {}
    for i, s in ipairs(segs) do
        quads[i] = { s[1], s[2], s[3], s[4], ix[i - 1], iy[i - 1], ix[i], iy[i] }
    end
    return quads
end

-- A convex closed line { x1, y1, ..., x1, y1 } as upright slabs between its corners, left to right, to fill it with
-- quads: each { x0, top0, foot0, x1, top1, foot1 }.
function Geometry.Slabs(pts)
    local xs = {}
    for i = 1, #pts - 3, 2 do
        xs[#xs + 1] = pts[i]
    end
    table.sort(xs)
    -- the line's top and foot over x; an upright edge there gives both its ends
    local function span(x)
        local top, foot = -huge, huge
        for i = 1, #pts - 3, 2 do
            local ax, ay, bx, by = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
            if x >= min(ax, bx) - 1e-6 and x <= max(ax, bx) + 1e-6 then
                if abs(bx - ax) < 1e-6 then
                    top, foot = max(top, ay, by), min(foot, ay, by)
                else
                    local y = ay + (by - ay) * (x - ax) / (bx - ax)
                    top, foot = max(top, y), min(foot, y)
                end
            end
        end
        return top, foot
    end
    local slabs, last = {}, nil
    for _, x in ipairs(xs) do
        if last == nil or x - last > 1e-3 then
            if last then
                local t0, f0 = span(last)
                local t1, f1 = span(x)
                slabs[#slabs + 1] = { last, t0, f0, x, t1, f1 }
            end
            last = x
        end
    end
    return slabs
end
