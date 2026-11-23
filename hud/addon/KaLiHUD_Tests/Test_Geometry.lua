-- KaLi HUD's geometry: what the plate takes, its outline and its pieces. Pure numbers, no game.
local T = KaLiHUDTests
local G = KaLiHUDDev.ns.Geometry

local function find(pieces, kind, test)
    for _, p in ipairs(pieces) do
        if p[1] == kind and test(p) then
            return p
        end
    end
end

local function count(pieces, kind)
    local n = 0
    for _, p in ipairs(pieces) do
        if p[1] == kind then
            n = n + 1
        end
    end
    return n
end

local function near(a, b)
    return math.abs(a - b) < 0.01
end

local function segAt(segs, x)
    for _, s in ipairs(segs) do
        if s.x0 <= x and s.x1 >= x then
            return s
        end
    end
end

T.Add("geometry", "the outline keeps the highest box over each stretch", function()
    local segs = G.Envelope({ { x0 = 100, x1 = 300, top = 80 }, { x0 = 200, x1 = 400, top = 50 } }, 1000, 22)
    T.Eq(#segs, 4, "segments")
    T.Eq(segs[1].top, 22, "first top")
    T.Eq(segs[2].x0, 100, "second from")
    T.Eq(segs[2].x1, 300, "second to")
    T.Eq(segs[2].top, 80, "second top")
    T.Eq(segs[3].x1, 400, "third to")
    T.Eq(segs[3].top, 50, "third top")
    T.Eq(segs[4].x1, 1000, "last to")
end)

T.Add("geometry", "stretches of the same height make one", function()
    local segs = G.Envelope({ { x0 = 100, x1 = 200, top = 60 }, { x0 = 200, x1 = 300, top = 60 } }, 1000, 22)
    T.Eq(#segs, 3, "segments")
    T.Eq(segs[2].x0, 100, "from")
    T.Eq(segs[2].x1, 300, "to")
end)

T.Add("geometry", "a step gets a rounded corner above and a concave curve below", function()
    local pieces = G.Pieces(G.Envelope({ { x0 = 100, x1 = 300, top = 80 } }, 1000, 22), nil, 0)
    T.Eq(count(pieces, "quarter"), 2, "rounded corners")
    T.Eq(count(pieces, "fillet"), 2, "concave curves")
    T.True(find(pieces, "quarter", function(p)
        return p[5] == "TL" and near(p[2], 108) and near(p[3], 72) and near(p[4], 8)
    end), "the left corner, 8 across, inside the step")
    T.True(find(pieces, "fillet", function(p)
        return near(p[2], 100) and near(p[3], 22) and near(p[4], 10) and p[5] == -1
    end), "the left curve, on the lower plate, against the wall")
    T.True(find(pieces, "fillet", function(p)
        return near(p[2], 300) and near(p[3], 22) and p[5] == 1
    end), "the right curve")
end)

T.Add("geometry", "grown layers keep their curves concentric", function()
    local segs = G.Envelope({ { x0 = 100, x1 = 300, top = 80 } }, 1000, 22)
    local pieces = G.Pieces(segs, nil, 2.3)
    T.True(find(pieces, "quarter", function(p)
        return p[5] == "TL" and near(p[2], 108) and near(p[3], 72) and near(p[4], 10.3)
    end), "the corner grows around the same centre")
    T.True(find(pieces, "fillet", function(p)
        return near(p[2], 97.7) and near(p[3], 24.3) and near(p[4], 7.7)
    end), "the curve shrinks by as much")
    T.Eq(count(G.Pieces(segs, nil, 12), "fillet"), 0, "a layer grown past the curve has none")
end)

-- y on a path { x1, y1, ... } at x, between the points either side (not on a wall).
local function yAt(pts, x)
    for i = 1, #pts - 3, 2 do
        if pts[i] <= x and pts[i + 2] >= x and pts[i + 2] > pts[i] then
            return pts[i + 1] + (pts[i + 3] - pts[i + 1]) * (x - pts[i]) / (pts[i + 2] - pts[i])
        end
    end
end

T.Add("geometry", "bevelled corners: a cut above and below each step, square ones: none", function()
    local segs = G.Envelope({ { x0 = 100, x1 = 300, top = 80 } }, 1000, 22)
    local pieces = G.Pieces(segs, nil, 0, { style = "bevel" })
    T.Eq(count(pieces, "bevel") .. count(pieces, "slope") .. count(pieces, "quarter") .. count(pieces, "fillet"), "2200",
        "two cuts on top, two at the feet, nothing round")
    local pts = G.Path(pieces, 1000, 1)
    T.True(near(yAt(pts, 104), 76), "the corner cut at 45 degrees: " .. tostring(yAt(pts, 104)))
    T.True(near(yAt(pts, 95), 27), "the foot's cut at 45 degrees: " .. tostring(yAt(pts, 95)))
    local grown = find(G.Pieces(segs, nil, 2, { style = "bevel" }), "bevel", function(p)
        return p[5] == "TL"
    end)
    -- the cut's line y - x = c: 2 out, it lies 2 away from the cut it grew from
    T.True(near((grown[3] - (grown[2] - grown[4]) - (72 - 100)) / math.sqrt(2), 2), "grown, the cut stays parallel, 2 away")
    local square = G.Pieces(segs, nil, 0, { style = "square", corner = 8, fillet = 10 })
    T.Eq(#square, 3, "square: the three stretches, nothing else")
    T.True(near(yAt(G.Path(square, 1000, 1), 101), 80), "the corner sharp")
end)

T.Add("geometry", "steps the border can't turn go up to their higher side; the dome stays", function()
    local function tops(segs)
        local out = {}
        for _, s in ipairs(segs) do
            out[#out + 1] = s.x0 .. "-" .. s.x1 .. ":" .. s.top
        end
        return table.concat(out, " ")
    end
    T.Eq(tops(G.Smooth({ { x0 = 0, x1 = 100, top = 50 }, { x0 = 100, x1 = 200, top = 53 }, { x0 = 200, x1 = 300, top = 20 } },
        8.5, 8, 10)), "0-200:53 200-300:20", "a 3-high step goes up, a 33-high one stays")
    T.Eq(tops(G.Smooth({ { x0 = 0, x1 = 100, top = 22 }, { x0 = 100, x1 = 110, top = 60 }, { x0 = 110, x1 = 300, top = 100 } },
        8.5, 8, 10)), "0-100:22 100-300:100", "a stair 10 wide goes up to the step above it")
    T.Eq(tops(G.Smooth({ { x0 = 0, x1 = 100, top = 100 }, { x0 = 100, x1 = 110, top = 40 }, { x0 = 110, x1 = 200, top = 120 } },
        8.5, 8, 10)), "0-110:100 110-200:120", "a notch 10 wide fills to its lower side")
    local wide = { { x0 = 0, x1 = 100, top = 100 }, { x0 = 100, x1 = 160, top = 40 }, { x0 = 160, x1 = 200, top = 120 } }
    T.Eq(tops(G.Smooth(wide, 8.5, 8, 10)), tops(wide), "a notch 60 wide stays")
    local twelve = { { x0 = 0, x1 = 100, top = 50 }, { x0 = 100, x1 = 200, top = 62 } }
    T.Eq(#G.Smooth(twelve, 8.5, 8, 10), 1, "12 high: too low for a corner and a curve")
    T.Eq(#G.Smooth(twelve, 8.5, 0, 0), 2, "square, it only has to hold the border")
    local dome = { { x0 = 0, x1 = 100, top = 50, dome = true }, { x0 = 100, x1 = 200, top = 52 } }
    T.Eq(tops(G.Smooth(dome, 8.5, 8, 10)), tops(dome), "nothing goes up to the dome's arch, nor the arch")
end)

T.Add("geometry", "limited corners: the smallest area fills first, only ever up", function()
    local function tops(segs)
        local out = {}
        for _, s in ipairs(segs) do
            out[#out + 1] = s.x0 .. "-" .. s.x1 .. ":" .. s.top
        end
        return table.concat(out, " ")
    end
    local segs = { { x0 = 0, x1 = 100, top = 50 }, { x0 = 100, x1 = 110, top = 20 }, { x0 = 110, x1 = 300, top = 50 },
        { x0 = 300, x1 = 400, top = 80 }, { x0 = 400, x1 = 1000, top = 30 } }
    T.Eq(G.Corners(segs), 8, "two corners a step")
    T.Eq(tops(G.LimitCorners(segs, nil)), tops(segs), "no limit: as it is")
    T.Eq(tops(G.LimitCorners(segs, 8)), tops(segs), "within the limit, as it is")
    T.Eq(tops(G.LimitCorners(segs, 6)), "0-300:50 300-400:80 400-1000:30", "the notch 10 wide fills first")
    T.Eq(tops(G.LimitCorners(segs, 2)), "0-400:80 400-1000:30", "then 300 x 30 before 600 x 50")
    T.Eq(tops(G.LimitCorners(segs, 0)), "0-1000:80", "0: one straight line")
    local dome = { { x0 = 0, x1 = 100, top = 20 }, { x0 = 100, x1 = 200, top = 60, dome = true }, { x0 = 200, x1 = 300, top = 20 } }
    T.Eq(G.Corners(dome), 4, "the dome's sides count")
    local up = G.LimitCorners(dome, 2)
    T.Eq(tops(up), "0-100:60 100-200:60 200-300:20", "a side goes up to the arch")
    T.True(up[2].dome, "the arch stays the dome's")
    local buried = G.LimitCorners({ { x0 = 0, x1 = 100, top = 80 }, { x0 = 100, x1 = 200, top = 60, dome = true },
        { x0 = 200, x1 = 300, top = 80 } }, 0)
    T.Eq(tops(buried), "0-300:80", "the arch goes up too, for a straight line")
    T.True(not buried[1].dome, "then it's plate like the rest")
    -- A step of just what counts as one: 0.51 - 0.5 is a hair over 0.01, and 0.5 + 0.01 is 0.51.
    local hair = { { x0 = 0, x1 = 100, top = 0.5 }, { x0 = 100, x1 = 200, top = 0.51 } }
    T.Eq(G.Corners(hair), 2, "it counts as a step")
    T.Eq(#G.LimitCorners(hair, 0), 1, "and still goes up, for a straight line")
end)

T.Add("geometry", "the dome stands on an arch, square where the disc's edge runs", function()
    local dome = G.Dome(400, 40, 140, 140)
    local segs = G.Outline({ W = 1000, T = 22, boxes = {}, dome = dome, reach = 40 })
    local arch = segAt(segs, dome.cx)
    T.Eq(#segs, 3, "the info bar either side")
    T.True(arch.dome and near(arch.x0, dome.cx - dome.r) and near(arch.x1, dome.cx + dome.r) and near(arch.top, dome.cy),
        "an arch up to the dome's centre")
    local pieces = G.Pieces(segs, dome, 0)
    T.Eq(count(pieces, "disc"), 1, "the disc")
    T.Eq(count(pieces, "quarter"), 0, "no corner rounded")
    T.Eq(count(pieces, "fillet"), 2, "a concave curve at each foot")
end)

T.Add("plate", "a gap narrower than the reach fills up to its lower side, a wider one stays", function()
    local segs = G.Envelope({ { x0 = 100, x1 = 300, top = 80 }, { x0 = 330, x1 = 500, top = 60 }, { x0 = 560, x1 = 700, top = 90 } }, 1000, 22)
    local closed = G.Close(segs, 1000, 40)
    T.Eq(segAt(closed, 315).top, 60, "30 wide: filled to the lower side")
    T.Eq(segAt(closed, 530).top, 22, "60 wide: as it was")
    T.Eq(segAt(closed, 200).top, 80, "a box as it was")
    T.Eq(segAt(closed, 800).top, 22, "a wide stretch of the info bar as it was")
    T.Eq(#G.Close(segs, 1000, 0), #segs, "no reach, no change")
end)

T.Add("plate", "a gap at the screen's edge narrower than the reach fills too", function()
    local closed = G.Close(G.Envelope({ { x0 = 25, x1 = 300, top = 80 }, { x0 = 900, x1 = 950, top = 70 } }, 1000, 22), 1000, 40)
    T.Eq(segAt(closed, 10).top, 80, "25 from the left edge: filled")
    T.Eq(segAt(closed, 980).top, 22, "50 from the right edge: as it was")
end)

T.Add("plate", "the plate fills up the dome's side, into the disc", function()
    local dome = G.Dome(400, 40, 140, 140)
    local segs = G.Outline({ W = 1000, T = 22, boxes = { { x0 = 100, x1 = 370, top = 140 } }, dome = dome, reach = 40 })
    local fill = segAt(segs, 376)
    T.True(near(fill.top, 140) and not fill.dome, "filled to the bars' height")
    local dx = fill.x1 - dome.cx
    T.True(dome.cy + math.sqrt(dome.r ^ 2 - dx ^ 2) >= 140 - 0.01, "up to where the disc stands that high")
    T.True(segAt(segs, dome.cx).dome, "the arch beyond")
    local wide = G.Outline({ W = 1000, T = 22, boxes = { { x0 = 100, x1 = 330, top = 140 } }, dome = dome, reach = 40 })
    T.Eq(segAt(wide, 356).top, 22, "a gap wider than the reach stays")
end)

-- Whether a pocket's places stand in it (between the ring, the dome's side, the floor or a status bar on it, outside
-- the map's middle half) and apart for icons `size` wide.
local function pocketed(dome, spots, size, floor, block, what)
    local rs = size / 2
    local onto = dome.ring + rs - G.POCKET_ENCROACH
    for i, s in ipairs(spots) do
        local low = floor + 2 + rs
        if block and s.dx + rs > block.dx then
            low = block.top + 2 + rs
        end
        T.True(math.sqrt(s.dx ^ 2 + (dome.cy - s.y) ^ 2) >= onto - 0.01 and s.dx + rs <= dome.r - 2 + 0.01
            and s.dx >= dome.mapR / 2 - 0.01 and s.y >= low - 0.01 and s.y <= dome.cy + 0.01,
            what .. ": place " .. i .. " outside the pocket")
        for j = i + 1, #spots do
            local o = spots[j]
            T.True(math.sqrt((s.dx - o.dx) ^ 2 + (s.y - o.y) ^ 2) >= size + 2 - 0.01, what .. ": places " .. i .. ", " .. j
                .. " too close")
        end
    end
end

-- Whether places stand as the pocket's triangle, rows along the floor and columns up the dome's side, one step
-- apart: the corner, above it, beside it towards the map, then (six) the next diagonal from up the side down. The
-- step, or nil.
local function triangled(spots, what)
    local c = spots[1]
    local step = spots[2] and spots[2].y - c.y
    local cells = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 2, 0 }, { 1, 1 }, { 0, 2 } }
    for i, s in ipairs(spots) do
        local r, col = cells[i][1], cells[i][2]
        T.True(near(s.y, c.y + r * step) and near(s.dx, c.dx - col * step),
            what .. ": place " .. i .. " off the triangle")
    end
    return step
end

T.Add("geometry", "a pocket's places stand as its triangle, evenly spaced, as wide as the pocket lets them", function()
    -- Ikar 2026-11-16: "you removed the triangle, keep it. I just wanted equal spacing, but on the triangle".
    local high = G.Dome(400, 60, 198, 198, 3.75, 6.25)
    local tight = G.Dome(400, 24, 198, 198, 3.75, 6.25)
    local ikar = G.Dome(400, 15, 158.4, 158.4, 3, 5)
    for _, c in ipairs({ { high, 22, 22, "a map high over the bar" }, { tight, 22, 14, "a map low on the bar" },
        { ikar, 11, 10, "Ikar's map, the smallest bar" }, { ikar, 18, 16, "Ikar's map, the default bar" } }) do
        local dome, floor, size, what = c[1], c[2], c[3], c[4]
        local spots = G.PocketSpots(dome, floor, size)
        T.Eq(#spots, 3, what .. ": three")
        pocketed(dome, spots, size, floor, nil, what)
        local step = triangled(spots, what)
        -- the same gap to the pocket's edges (their own 2 counted in) as between two icons: nothing in a corner
        local rs, e = size / 2, step - size - G.POCKET_GAP
        local corner = spots[1]
        T.True(near(corner.dx + rs + e, dome.r - 2) and near(corner.y - rs - e, floor + 2),
            what .. ": the corner's place not as far from the side and the floor as from the next place")
        -- as wide as it goes: one of them stands against the ring as far, or at the map's middle half, or level with
        -- the map's centre
        local slack = math.huge
        for _, s in ipairs(spots) do
            slack = math.min(slack, math.sqrt(s.dx ^ 2 + (dome.cy - s.y) ^ 2) - (dome.ring - G.POCKET_ENCROACH + e + rs),
                s.dx - dome.mapR / 2, dome.cy - s.y)
        end
        T.True(math.abs(slack) < 0.05, what .. ": the triangle could spread further: " .. slack)
    end
    -- the spread follows the pocket: a smaller bar, the same map, the places come down with the floor
    T.True(G.PocketSpots(ikar, 11, 10)[1].y < G.PocketSpots(ikar, 22, 10)[1].y, "a smaller bar: the places stay up")
end)

T.Add("geometry", "a roomy pocket has six places, a row and a column more, while they stay half an icon apart", function()
    -- Ikar 2026-11-16: "when we can afford, maybe add more than 3 slots"
    local high = G.Dome(400, 60, 198, 198, 3.75, 6.25)
    local six = G.PocketSpots(high, 11, 10)
    T.Eq(#six, 6, "six places")
    pocketed(high, six, 10, 11, nil, "six")
    local step = triangled(six, "six")
    T.True(step and step - 10 >= 5 - 0.01, "six places closer than half an icon: " .. tostring(step))
end)

T.Add("geometry", "a pocket too small for three has two, then one, then none", function()
    local tight = G.Dome(400, 24, 198, 198, 3.75, 6.25)
    local fewer = G.PocketSpots(tight, 22, 26)
    T.True(#fewer >= 1 and #fewer < 3, "icons too big for three: " .. #fewer)
    pocketed(tight, fewer, 26, 22, nil, "too big for three")
    T.Eq(#G.PocketSpots(tight, 22, 60), 0, "icons bigger than the pocket: none")
end)

T.Add("geometry", "a status bar under a pocket is its floor there", function()
    -- Ikar's map, 158.4 across, round Blizzard's ring; icons 14
    local dome = G.Dome(400, 24, 158.4, 158.4, 3, 5)
    local free = G.PocketSpots(dome, 22, 14)
    for _, block in ipairs({ { dx = dome.ring, top = 22 + 3 + 15 }, { dx = 60, top = 22 + 3 + 11 } }) do
        local what = "a status bar from " .. block.dx
        local spots = G.PocketSpots(dome, 22, 14, block)
        T.True(#spots >= 1, what .. ": no place left")
        pocketed(dome, spots, 14, 22, block, what)
        if #spots >= 3 then
            triangled(spots, what)
        end
        local moved = #spots ~= #free
        for i, s in ipairs(spots) do
            moved = moved or not (near(s.dx, free[i].dx) and near(s.y, free[i].y))
        end
        T.True(moved, what .. ": the places didn't make room for it")
    end
end)

T.Add("geometry", "a window's place on its way: nothing beside it lifted to it, itself sunk into the floor alone", function()
    -- Ikar 2026-11-16: a window folding near the foot had the border next to it jump up to its top for a few frames
    local e, corner, fillet = 6, 8, 10
    local function three(mid)
        return { { x0 = 0, x1 = 100, top = 30 }, { x0 = 100, x1 = 300, top = mid }, { x0 = 300, x1 = 400, top = 30 } }
    end
    local function on(mid)
        return { { x0 = 90, x1 = 310, top = mid, floor = 30 } }
    end
    local still = G.Smooth(three(33), e, corner, fillet)
    T.True(#still == 1 and near(still[1].top, 33), "at rest, a step too small to turn goes up to its higher side")
    local above = G.Smooth(three(33), e, corner, fillet, on(33))
    T.True(#above == 3 and near(above[1].top, 30) and near(above[2].top, 33) and near(above[3].top, 30),
        "on its way a little over the floor, the floor beside it is lifted")
    -- sinking past a taller neighbour: drawn as it comes, not held at the neighbour's height
    local tall = { { x0 = 0, x1 = 100, top = 60 }, { x0 = 100, x1 = 300, top = 57 }, { x0 = 300, x1 = 400, top = 30 } }
    local past = G.Smooth(tall, e, corner, fillet, { { x0 = 90, x1 = 310, top = 57, floor = 30 } })
    T.True(#past == 3 and near(past[2].top, 57), "on its way just under a taller neighbour, it's held at its height")
    -- under the floor: gone into it, as at rest
    local under = G.Smooth(three(27), e, corner, fillet, on(27))
    T.True(#under == 1 and near(under[1].top, 30), "on its way under the floor, its notch shows")
end)

T.Add("geometry", "an outline spliced: another's stretches in the zones, its own elsewhere", function()
    local W = 1000
    local base = { { x0 = 0, x1 = 300, top = 50 }, { x0 = 300, x1 = 600, top = 120 }, { x0 = 600, x1 = 1000, top = 50 } }
    local over = { { x0 = 0, x1 = 400, top = 30 }, { x0 = 400, x1 = 1000, top = 50 } }
    local zones = G.Differ(base, over, W)
    T.True(#zones == 2 and near(zones[1].x0, 0) and near(zones[1].x1, 600) and near(zones[2].x0, 600)
        or #zones == 1 and near(zones[1].x0, 0) and near(zones[1].x1, 600), "where they stand apart")
    local spliced = G.Splice(base, over, { { x0 = 300, x1 = 600 } }, W)
    T.True(near(segAt(spliced, 100).top, 50) and near(segAt(spliced, 350).top, 30) and near(segAt(spliced, 500).top, 50)
        and near(segAt(spliced, 800).top, 50), "the other's within the zone alone")
end)

T.Add("plate", "the disc is drawn only above the plate under it, never twice", function()
    local dome = G.Dome(400, 40, 140, 140)
    local segs = G.Outline({ W = 1000, T = 22, boxes = { { x0 = 100, x1 = 370, top = 140 } }, dome = dome, reach = 40 })
    local arcs = G.Arcs(segs, dome.cx, dome.cy, dome.r)
    for x = dome.cx - dome.r + 0.5, dome.cx + dome.r - 0.5, 2 do
        local under = math.max(segAt(segs, x).top, dome.cy)
        local over = {}
        for _, a in ipairs(arcs) do
            if a[5] < x and a[6] > x then
                over[#over + 1] = a
            end
        end
        T.True(#over <= 1 and (not over[1] or near(over[1][7], under)), "a strip from the plate's top at " .. x)
        if dome.cy + math.sqrt(dome.r ^ 2 - (x - dome.cx) ^ 2) > under + 0.01 then
            T.Eq(#over, 1, "the disc above the plate at " .. x)
        end
    end
end)

local function frame(key, x, y, w, h, kind)
    return { key = key, kind = kind or "bar", x = x, y = y, w = w, h = h }
end

T.Add("cover", "a frame within reach above the plate is taken, one further isn't", function()
    local taken, far = G.Cover({ T = 22, reach = 40, frames = { frame("near", 100, 60, 300, 30), frame("high", 600, 500, 300, 30) } })
    T.Eq(#taken, 1, "taken")
    T.Eq(taken[1].key, "near", "the near one")
    T.True(near(far.high, 478), "how far the other is")
end)

T.Add("cover", "a frame taken brings the next in reach, in any order", function()
    local frames = { frame("top", 100, 150, 300, 30), frame("middle", 100, 105, 300, 30), frame("low", 100, 60, 300, 30) }
    local taken = G.Cover({ T = 22, reach = 40, frames = frames })
    T.Eq(#taken, 3, "the stack")
    T.Eq(taken[1].key, "top", "in the frames' order")
    T.Eq(#G.Cover({ T = 22, reach = 20, frames = frames }), 0, "the lowest out of reach, the stack with it")
end)

T.Add("cover", "the minimap is taken with its dome, which brings a bar above it in reach", function()
    local taken = G.Cover({ T = 22, reach = 40, frames = { frame("bar", 400, 230, 200, 30), frame("map", 430, 40, 140, 140, "minimap") } })
    T.Eq(#taken, 2, "both")
end)

T.Add("status", "the status bars go under the level bars each side, in to the map's ring", function()
    local bars = { frame("a", 500, 50, 400, 30), frame("b", 1100, 50, 300, 30), frame("upright", 1450, 50, 30, 300), frame("c", 1000, 100, 200, 30) }
    local s = G.StatusSlots({ bars = bars, T = 22, heights = { [-1] = 12, [1] = 14 }, split = 1000, inner = 90 })
    T.Eq(s[-1].x, 500 - G.PAD, "left, from the bars' outer edge")
    T.Eq(s[-1].x + s[-1].w, 910, "in to the ring, past the bars' inner edge")
    T.Eq(s[1].x, 1090, "right, from the ring")
    T.Eq(s[1].x + s[1].w, 1400 + G.PAD, "an upright bar doesn't count")
    T.Eq(s[1].y, 22 + G.GAP, "the taller on the info bar")
    T.Eq(G.GAP, 3, "3 above it, where Ikar dragged his")
    T.Eq(s[-1].h, 12, "each as tall as its own")
    T.Eq(s[-1].y + 6, s[1].y + 7, "on the taller one's middle line")
    local none = G.StatusSlots({ bars = {}, T = 22, heights = { [-1] = 12, [1] = 12 }, split = 1000, inner = 2 })
    T.Eq(none[-1].x + none[-1].w, 998, "with no bar, against the centre")
    T.Eq(none[1].w, G.DEFAULT_STATUS_WIDTH, "at the default width")
    local wide = G.StatusSlots({ bars = bars, T = 22, heights = { [-1] = 12, [1] = 12 }, split = 1000, inner = 90,
        widths = { [-1] = 300, [1] = 0 } })
    T.Eq(wide[-1].x + wide[-1].w, 910, "a width given: the left one still ends at the ring")
    T.Eq(wide[-1].w, 300, "at that width")
    T.Eq(wide[1].x, 1090, "the right one still starts at the ring")
    T.Eq(wide[1].w, 315, "Auto, its own")
    local one = G.StatusSlots({ bars = bars, T = 22, heights = { [-1] = 0, [1] = 12 }, split = 1000, inner = 90 })
    T.Eq(one[-1], nil, "none where it's 0 tall")
    T.Eq(one[1].y, 22 + G.GAP, "the other on the info bar")
end)

T.Add("geometry", "each slot keeps its own component margin, and bridge is independent of reach", function()
    local a = G.Slot({ key = "bars", kind = "bar", x = 100, y = 50, w = 200, h = 30 }, 4, 12)
    local b = G.Slot({ key = "meter", kind = "window", x = 380, y = 40, w = 200, h = 100 }, 5, 2)
    local boxes = G.Boxes({ a, b })
    T.Eq(boxes[1].x0, 100 - 4 - 12, "bar outer margin")
    T.Eq(boxes[2].x1, 580 + 5 + 2, "window outer margin")
    local narrow = G.Outline({ W = 1000, T = 22, reach = 40, bridge = 20, boxes = boxes })
    local bridged = G.Outline({ W = 1000, T = 22, reach = 40, bridge = 90, boxes = boxes })
    T.Eq(segAt(narrow, 345).top, 22, "bridge 20 leaves a 57-wide gap open")
    T.Eq(segAt(bridged, 345).top, 96, "bridge 90 closes the gap to the lower side")
end)

T.Add("geometry", "dome pockets find room for tracking and mail under the minimap", function()
    local dome = G.Dome(981, 40.8, 138.6, 138.6, 6, 12)
    local pocket = G.DomePocket(dome, 22)
    T.True(pocket ~= nil and pocket.r > 12 and pocket.dx > 40, "a pocket in each lower corner")
    local high = G.Dome(981, 500, 138.6, 138.6, 6, 12)
    T.True(G.DomePocket(high, 22) ~= nil, "computed safely")
end)

T.Add("geometry", "polar and angle round-trip cleanly around the dome", function()
    for _, deg in ipairs({ 0, 45, 90, 138, 180, 218, 270, 322 }) do
        local x, y = G.Polar(1000, 120, 84, deg)
        T.Eq(G.Angle(1000, 120, x, y), deg, "angle " .. tostring(deg))
    end
end)

T.Add("geometry", "the plate's edge is one line across the screen, its curves followed", function()
    local flat = G.Path(G.Pieces({ { x0 = 0, x1 = 100, top = 20 } }, nil, 0), 100)
    T.Eq(table.concat(flat, ","), "0,20,100,20", "a flat plate: one segment")
    local segs = { { x0 = 0, x1 = 50, top = 20 }, { x0 = 50, x1 = 100, top = 40 } }
    local pts = G.Path(G.Pieces(segs, nil, 0, { corner = 8, fillet = 10 }), 100, 1)
    T.True(pts[1] == 0 and near(pts[2], 20) and pts[#pts - 1] == 100 and near(pts[#pts], 40), "from one edge to the other")
    local wall, curve, forwards = false, false, true
    for i = 3, #pts - 1, 2 do
        forwards = forwards and pts[i] >= pts[i - 2]
        wall = wall or (pts[i] == 50 and pts[i - 2] == 50)
        curve = curve or (pts[i] > 41 and pts[i] < 49 and pts[i + 1] > 21 and pts[i + 1] < 29)
    end
    T.True(forwards, "never back")
    T.True(wall, "the wall upright")
    T.True(curve, "the concave curve at the wall's foot")
    local dome = { cx = 500, cy = 60, r = 50 }
    local arch = G.Path(G.Pieces({ { x0 = 0, x1 = 450, top = 22 }, { x0 = 450, x1 = 550, top = 60, dome = true },
        { x0 = 550, x1 = 1000, top = 22 } }, dome, 0), 1000)
    local top = 0
    for i = 2, #arch, 2 do
        top = math.max(top, arch[i])
    end
    T.True(math.abs(top - 110) < 0.05, "over the dome's top: " .. tostring(top))
end)

T.Add("geometry", "a disc's rim a hair left of its arch's edge doesn't tilt the line beside it", function()
    -- the arch's edge rounded to a hundredth, the disc's rim 0.004 left of it (Ikar's diagonal, 2026-11-13)
    local dome = { cx = 499.996, cy = 60, r = 50 }
    local pts = G.Path(G.Pieces({ { x0 = 0, x1 = 450, top = 22 }, { x0 = 450, x1 = 550, top = 60, dome = true },
        { x0 = 550, x1 = 1000, top = 22 } }, dome, 0, { style = "square" }), 1000)
    T.True(near(yAt(pts, 300), 22), "flat up to the wall: " .. tostring(yAt(pts, 300)))
end)

T.Add("geometry", "a frame's border: a band inside its rectangle, round, cut or square corners", function()
    for _, style in ipairs({ "round", "bevel", "square" }) do
        local pts = G.Rect(0, 0, 100, 20, style == "square" and 0 or 4, style)
        T.True(pts[1] == pts[#pts - 1] and pts[2] == pts[#pts], style .. ": a closed line")
        local inside = true
        for _, q in ipairs(G.Band(pts, 3)) do
            for i = 5, 7, 2 do
                inside = inside and q[i] >= 3 - 1e-6 and q[i] <= 97 + 1e-6 and q[i + 1] >= 3 - 1e-6 and q[i + 1] <= 17 + 1e-6
            end
        end
        T.True(inside, style .. ": the band's inner edge 3 inside the rectangle")
    end
    T.Eq(#G.Rect(0, 0, 10, 10, 0) / 2, 5, "square: its four corners, closed")
end)

T.Add("geometry", "a convex shape in upright slabs: from corner to corner, its top and foot there", function()
    local function area(slabs)
        local sum = 0
        for _, s in ipairs(slabs) do
            sum = sum + (s[4] - s[1]) * ((s[2] - s[3]) + (s[5] - s[6])) / 2
        end
        return sum
    end
    local hexagon = G.Slabs(G.Rect(0, 0, 40, 10, math.huge, "bevel"))
    T.Eq(#hexagon, 3, "a pointed hexagon: its two ends and its middle")
    local first, last = hexagon[1], hexagon[3]
    T.True(near(first[1], 0) and near(first[2], 5) and near(first[3], 5) and near(last[4], 40) and near(last[5], 5),
        "pointed at both ends, halfway up")
    T.True(near(area(hexagon), 350), "its area: " .. area(hexagon))
    local box = G.Slabs(G.Rect(0, 0, 30, 8, 0))
    T.True(#box == 1 and near(box[1][2], 8) and near(box[1][3], 0) and near(area(box), 240), "a rectangle: one slab")
    local pill = G.Slabs(G.Rect(0, 0, 40, 10, math.huge, "round", 1))
    T.True(#pill > 10 and math.abs(area(pill) - (300 + math.pi * 25)) < 1.5, "a pill: " .. area(pill))
end)

T.Add("geometry", "the border's band: quads edge to edge, cut along each bend", function()
    local q = G.Band({ 0, 0, 10, 0, 10, 10 }, 2)
    T.Eq(#q, 2, "a quad a segment")
    T.Eq(table.concat(q[1], ","), "0,0,10,0,0,-2,12,-2", "the flat's inner edge runs into the bend")
    T.Eq(table.concat(q[2], ","), "10,0,10,10,12,-2,12,10", "the wall's starts where it ended")
    local arc = {}
    for i = 0, 12 do
        local a = math.pi - math.pi * i / 12
        arc[#arc + 1], arc[#arc + 2] = 50 + 3 * math.cos(a), 3 * math.sin(a)
    end
    local ok = true
    for _, quad in ipairs(G.Band(arc, 8)) do
        ok = ok and (quad[7] - quad[5]) * (quad[3] - quad[1]) + (quad[8] - quad[6]) * (quad[4] - quad[2]) > -1e-6
    end
    T.True(ok, "a bend tighter than the band: no inner edge runs backwards")
end)

T.Add("geometry", "a ring of the border round a circle: closed, its inner side outside", function()
    local pts = G.Circle(100, 50, 40)
    T.True(pts[1] == pts[#pts - 1] and pts[2] == pts[#pts], "the line ends where it starts")
    local q = G.Band(pts, 5)
    local first, last = q[1], q[#q]
    T.True(near(first[5], last[7]) and near(first[6], last[8]), "cut where it closes, the last quad meets the first")
    T.True(near(math.sqrt((first[5] - 100) ^ 2 + (first[6] - 50) ^ 2), 40 + 5 / math.cos(math.pi / #q)),
        "the inner edge 5 outside the circle")
end)
