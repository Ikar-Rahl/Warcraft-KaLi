-- Borders and backgrounds of KaLi HUD. The border: a band of quads along an outline, in the look's profile across
-- (Media/BandKaLi.tga, from hud/tools/make_media.py; Data/Look.lua says how deep): the plate's edge (UI/Plate.lua), the
-- map's ring (UI/Minimap.lua), and the status bars' thin one (Media/BandThin.tga) round them, with the plate's corners,
-- and their end caps' (the plate's metal, smaller and brighter, round the bar's colour); its size, opacity and colour
-- set in Edit Mode; faceted and polished as Blizzard's minimap and portrait rings (the look's, Ikar 2026-11-16). The
-- background: its colour lit from the top, one of Blizzard's tiling backgrounds (ns.MATERIALS) imprinted into it as
-- deep as set.
local _, ns = ...

local Border = {}
ns.Border = Border

local Geometry = ns.Geometry
local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOOK = ns.LOOK
-- The background's colour at the foot and the top of what it fills.
local FOOT, TOP = 0.6, 1.0
Border.FOOT, Border.TOP = FOOT, TOP
-- The status bars' corners: no rounder than this.
local THIN_CORNER = 4
-- The thin border's metal this much of the border's colour: as bright as FlareUI's XP bar border on average (Ikar
-- 2026-11-15: "too bright"; measured at 1.25 times it).
Border.THIN_SHADE = 0.8
-- The status bars' end caps (Ikar 2026-11-15: "bright color, like a cartouche, a nice end cap", then "reduce the border
-- on the cap"): the plate's metal at this much of its depth, brighter than the plate's; its inner side, dark line
-- included, this deep in from its outline (BandKaLi's profile), a label inside kept this far from it; their inside
-- meets it this deep, under it.
Border.CAP_SCALE, Border.CAP_SHADE, Border.CAP_METAL, Border.CAP_CLEAR = 0.35, 1.2, 0.72, 0.5
local CAP_FILL = 0.45
-- The band files' blocks: the profile once for each way an edge faces, lit from the top left.
local DIRS, TEXELS = LOOK.dirs or 1, LOOK.texels or 64
-- Media/BandGrain.tga, as make_media.py writes it: texels across the band, and rows of grain along it.
local GRAIN_ACROSS, GRAIN_ROWS = 16, 64
-- The grain's strength (%) and how far a speck runs along the edge (% of its width): internal, no option. Ikar's,
-- approved in game 2026-11-15 after trying them as sliders.
Border.GRAIN = { strength = 35, length = 100 }

-- The layers along an edge, in the border's draw layer from under to over: the band, its grain.
local SUB = { band = -1, grain = 1 }

-- The materials, smooth first (none).
Border.STYLES = { "smooth", "rock", "stone", "darkstone", "marble", "leather", "wood", "planks", "masonry", "parchment" }

-- Colour presets for the Edit Mode lists; any other colour comes from the colour picker. Each list's first, the
-- default: the « Blizzard - cuivre » style's copper and walnut (Ikar 2026-11-17, Data/Presets.lua), then the dark
-- bronzes, Ikar's own until then (2026-11-15). The border's rose gold, verdigris and taupe for the styles, from their
-- rings' metal (2026-11-16). The ember red and charred stone for the « Feu - rouge » style (2026-11-18). The old rose
-- for the « Gemme » style, from its art's pearl pinks and champagne gold (2026-11-19: "too dark for the gem style, is
-- shoudl be much clearer, in the colors of the art"), darker since (2026-11-20: "The gem style shoudl have darker
-- background, text unreadable other wise"), its hue kept.
Border.COLORS = { "c4977c", "aa9273", "dccb9c", "c9cdd1", "9a9ea4", "8e8c88", "b9bab3", "c4c8ce", "a4afbf", "c8ad7f",
    "c9a08f", "a0b4a8", "9a8b74", "b4544a" }
Border.BG_COLORS = { "4a3a2a", "3b3026", "4a4036", "2a2c2e", "1f2a33", "2e3324", "3a2226", "5e4a48", "1a1714", "2e1f1c" }

-- "rrggbb" -> r, g, b in 0..1; white when it isn't one.
function Border.RGB(hex)
    local r, g, b = tostring(hex or ""):match("^(%x%x)(%x%x)(%x%x)$")
    if not r then
        return 1, 1, 1
    end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

function Border.Hex(r, g, b)
    local function byte(v)
        return math.max(0, math.min(255, math.floor((v or 0) * 255 + 0.5)))
    end
    return string.format("%02x%02x%02x", byte(r), byte(g), byte(b))
end

local function options()
    return ns.db and ns.db.options or ns.DB.DEFAULTS
end

function Border.Color()
    return Border.RGB(options().borderColor)
end

local decorations = {}
-- What Profile, Grain and Fill give, kept until what they're made from changes: their options, and the look's depth
-- (the bench sets it live).
local profiles, grains, fillKept, fillFor = {}, setmetatable({}, { __mode = "k" }), nil, {}

-- The band files' block for an edge whose outer side faces (ox, oy): its u across, from its first texel to its last.
local function block(ox, oy)
    local i = DIRS > 1 and math.floor(math.atan2(oy or 1, ox or 0) / (2 * math.pi) * DIRS + 0.5) % DIRS or 0
    return (i * TEXELS + 0.5) / (DIRS * TEXELS), ((i + 1) * TEXELS - 0.5) / (DIRS * TEXELS)
end

-- A border's profile (Profile's), kept by key until the border's size or the look's depth changes.
local function profile(key, file, edge, lookOut, shade)
    local k = options().borderSize / 100
    local p = profiles[key]
    if p and p.k == k and p.edge == edge and p.lookOut == lookOut then
        return p
    end
    local e = edge * k
    p = { file = file, e = e, out = lookOut * k, k = k, edge = edge, lookOut = lookOut, shade = shade,
        coords = function(len, from, ox, oy)
            local s0 = from / e
            local s1 = s0 + len / e
            local u0, u1 = block(ox, oy)
            return u0, s0, u1, s0, u0, s1, u1, s1
        end }
    profiles[key] = p
    return p
end

-- What a border is drawn with: its profile across, outside first, e deep, its outer side `out` outside the outline; and
-- its texture coordinates for a stretch `len` long that starts `from` along it, its outer side facing (ox, oy), in
-- SetTexCoord's order with the upper corners on the outer side. thin: the status bars'. Kept: read it, never change it.
function Border.Profile(thin)
    if thin then
        local look = LOOK.thin or LOOK
        return profile("thin", ns.BAND_THIN, look.edge, look.out, Border.THIN_SHADE)
    end
    return profile("kali", ns.BAND_KALI, LOOK.edge, LOOK.out)
end

-- A status bar's end cap's: the plate's metal, its profile too, smaller and brighter.
function Border.CapProfile()
    local scale = Border.CAP_SCALE
    return profile("cap", ns.BAND_KALI, LOOK.edge * scale, LOOK.out * scale, Border.CAP_SHADE)
end

-- How far an end cap h tall reaches past a label 2 * half tall across its middle, each way: as far as its ends (the
-- corners' style: pointed at 45 degrees, round or square) keep the label's corners CAP_CLEAR inside their metal.
function Border.CapEnds(h, half, style)
    local prof = Border.CapProfile()
    local metal = prof.e * Border.CAP_METAL + Border.CAP_CLEAR
    if style == "bevel" then
        return half + metal * math.sqrt(2) - prof.out
    elseif style == "square" then
        return metal - prof.out
    end
    local r = h / 2 + prof.out - metal
    return h / 2 - math.sqrt(math.max(0, r * r - half * half))
end

local resolved = {}

-- A style's material as drawn: { file, size = units a tile, lum }; nil for smooth or when the game lacks it.
function Border.Material(style)
    local m = ns.MATERIALS[style]
    if not m then
        return nil
    end
    if resolved[style] == nil then
        local info = m.atlas and C_Texture.GetAtlasInfo(m.atlas)
        if m.file then
            resolved[style] = { file = m.file, size = 256, lum = m.lum }
        elseif info and info.file and (info.leftTexCoord or 0) == 0 and (info.rightTexCoord or 1) == 1
            and (info.topTexCoord or 0) == 0 and (info.bottomTexCoord or 1) == 1 then
            resolved[style] = { file = info.file, size = info.width, lum = m.lum }
        else
            resolved[style] = false
        end
    end
    return resolved[style] or nil
end

-- The background: { foot, top = { r, g, b, a } } its colour lit from the top, less what the material carries; the
-- material (Material's) added over it desaturated, tinted { matFoot, matTop }, the two together the colour's light.
-- Kept: read it, never change it.
function Border.Fill()
    local o, k = options(), fillFor
    if fillKept and k.color == o.bgColor and k.alpha == o.bgAlpha and k.style == o.bgStyle
        and k.depth == o.bgIntensity then
        return fillKept
    end
    k.color, k.alpha, k.style, k.depth = o.bgColor, o.bgAlpha, o.bgStyle, o.bgIntensity
    local r, g, b = Border.RGB(o.bgColor)
    local a = o.bgAlpha / 100
    local mat = Border.Material(o.bgStyle)
    local brightest = math.max(r, g, b)
    local s, share = 0, 0
    if mat and brightest > 0 then
        -- a vertex colour stops at 1: a dark texture under a light colour carries less of it
        s = math.min(o.bgIntensity / 100 / mat.lum, 1 / (brightest * TOP))
        share = mat.lum * s
    end
    local function lit(by, sum)
        return { math.min(1, r * by * sum), math.min(1, g * by * sum), math.min(1, b * by * sum), a }
    end
    local fill = { foot = lit(FOOT, 1 - share), top = lit(TOP, 1 - share) }
    if share > 0 then
        fill.material, fill.matFoot, fill.matTop = mat, lit(FOOT, s), lit(TOP, s)
    end
    fillKept = fill
    return fill
end

-- How deep the KaLi border's metal is at its size, its dark lines included: what a frame it hugs gives up round it.
function Border.Hug()
    return (LOOK.edge - 2 * LOOK.out) * options().borderSize / 100
end

-- The grain over the KaLi border's metal for its profile prof (Media/BandGrain.tga: lighter and darker specks, as
-- FlareUI's borders carry), drawn as a second band over it, as Border.GRAIN says; nil at no strength. Kept: read it,
-- never change it.
function Border.Grain(prof)
    local k, size = Border.GRAIN.strength / 100, Border.GRAIN.length
    if k <= 0 or prof.e <= 0 then
        return nil
    end
    local g = grains[prof]
    if g and g.k == k and g.size == size then
        return g
    end
    local period = prof.e / GRAIN_ACROSS * GRAIN_ROWS * size / 100
    g = { file = ns.BAND_GRAIN, e = prof.e, out = prof.out, sub = SUB.grain, tint = { 1, 1, 1, k }, k = k, size = size,
        coords = function(len, from)
            local v0, v1 = from / period, (from + len) / period
            return 0, v0, 1, v0, 0, v1, 1, v1
        end }
    grains[prof] = g
    return g
end

-- The border along quads (Geometry.Band's, in `frame`'s units from its bottom left), a texture each from pool, a table
-- the caller keeps; the rest of the pool hidden. prof: Profile's, the KaLi border's by default (the thin one's
-- darker, the end caps' brighter: a colour stops at 1), Grain's (its tint for the border's colour, its sub-level over
-- the band). Returns how many it drew.
function Border.DrawBand(frame, pool, quads, prof)
    prof = prof or Border.Profile()
    local r, g, b = Border.Color()
    local a = options().borderAlpha / 100
    if prof.tint then
        r, g, b, a = prof.tint[1], prof.tint[2], prof.tint[3], prof.tint[4] * a
    else
        local k = prof.shade or 1
        r, g, b = math.min(1, r * k), math.min(1, g * k), math.min(1, b * k)
    end
    local min, max = math.min, math.max
    local along = 0
    for i, q in ipairs(quads) do
        local t = pool[i]
        if not t then
            t = frame:CreateTexture(nil, "BORDER", nil, prof.sub or SUB.band)
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
            pool[i] = t
        end
        local x0, y0 = min(q[1], q[3], q[5], q[7]), min(q[2], q[4], q[6], q[8])
        local x1, y1 = max(q[1], q[3], q[5], q[7]), max(q[2], q[4], q[6], q[8])
        if t._tex ~= prof.file then
            t:SetTexture(prof.file, "CLAMP", "REPEAT")
            t._tex = prof.file
        end
        local dx, dy = q[3] - q[1], q[4] - q[2]
        local len = math.sqrt(dx * dx + dy * dy)
        -- Band's inner side is to the right of the way it walks: the outer one faces (-dy, dx)
        t:SetTexCoord(prof.coords(len, along, -dy, dx))
        along = along + len
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x0, y0)
        t:SetSize(max(x1 - x0, 0.01), max(y1 - y0, 0.01))
        -- vertices 1 to 4: upper left, lower left, upper right, lower right; the upper ones on the outer edge
        t:SetVertexOffset(1, q[1] - x0, q[2] - y1)
        t:SetVertexOffset(2, q[5] - x0, q[6] - y0)
        t:SetVertexOffset(3, q[3] - x1, q[4] - y1)
        t:SetVertexOffset(4, q[7] - x1, q[8] - y0)
        t:SetVertexColor(r, g, b, a)
        t:Show()
    end
    for i = #quads + 1, #pool do
        pool[i]:Hide()
    end
    return #quads
end

local DARK = { 0, 0, 0 }

-- The colour inside an end cap (a decoration with role cap), lit from the top as the plate's background; r, g, b: a new
-- one, else the one it has again.
function Border.Tint(d, r, g, b)
    if r then
        d.tint = d.tint or {}
        d.tint[1], d.tint[2], d.tint[3] = r, g, b
    end
    local c = d.tint or DARK
    for i = 1, d.slabCount or 0 do
        local t = d.slabs[i]
        local lo, hi = FOOT + (TOP - FOOT) * t.lo, FOOT + (TOP - FOOT) * t.hi
        t.foot:SetRGBA(c[1] * lo, c[2] * lo, c[3] * lo, 1)
        t.top:SetRGBA(c[1] * hi, c[2] * hi, c[3] * hi, 1)
        t:SetGradient("VERTICAL", t.foot, t.top)
    end
end

-- An end cap's inside: the shape its border follows, out to under the metal, in upright slabs (quads, as the band's).
local function enamel(d, outline, prof, h)
    d.slabs = d.slabs or {}
    local n = 0
    if outline then
        local inner = {}
        for _, q in ipairs(Geometry.Band(outline, prof.e * CAP_FILL)) do
            inner[#inner + 1], inner[#inner + 2] = q[5], q[6]
        end
        inner[#inner + 1], inner[#inner + 2] = inner[1], inner[2]
        for i, s in ipairs(Geometry.Slabs(inner)) do
            local t = d.slabs[i]
            if not t then
                t = d.host:CreateTexture(nil, "ARTWORK")
                t:SetTexture(WHITE)
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
                t.foot, t.top = CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1)
                d.slabs[i] = t
            end
            local y0, y1 = math.min(s[3], s[6]), math.max(s[2], s[5])
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", d.host, "BOTTOMLEFT", s[1], y0)
            t:SetSize(math.max(s[4] - s[1], 0.01), math.max(y1 - y0, 0.01))
            t:SetVertexOffset(1, 0, s[2] - y1)
            t:SetVertexOffset(2, 0, s[3] - y0)
            t:SetVertexOffset(3, 0, s[5] - y1)
            t:SetVertexOffset(4, 0, s[6] - y0)
            t.lo, t.hi = (s[3] + s[6]) / 2 / h, (s[2] + s[5]) / 2 / h
            t:Show()
            n = i
        end
    end
    for i = n + 1, #d.slabs do
        d.slabs[i]:Hide()
    end
    d.slabCount = n
    Border.Tint(d)
end

-- Redraws one decoration with the options as they are: the thin border round its host, the plate's corners, its metal
-- from the host's edge and its shadow outside; the background inside it. An end cap (role cap): the cap's border, its
-- ends whole (round, pointed or square: role.style, else the corners'), and its colour inside.
function Border.Update(d)
    local o = options()
    local w, h = d.host:GetWidth() or 0, d.host:GetHeight() or 0
    local cap = d.role.cap
    local prof = cap and Border.CapProfile() or Border.Profile(true)
    local e, out = prof.e, prof.out
    local quads, outline = {}, nil
    if w > 0 and h > 0 and e > 0 then
        local style = cap and d.role.style or o.cornerStyle
        local r = style == "square" and 0 or cap and math.huge or math.min(THIN_CORNER, o.corner / 2)
        outline = Geometry.Rect(-out, -out, w + out, h + out, r, style, cap and 2 or nil)
        quads = Geometry.Band(outline, e)
    end
    Border.DrawBand(d, d.pool, quads, prof)
    d.edge, d.out = e, out

    if cap or d.role.bg == false then
        d.Bg:Hide()
        d.Material:Hide()
        if cap then
            enamel(d, outline, prof, h)
        end
        return
    end
    local fill = Border.Fill()
    local inset = math.max(0, math.floor(e * (LOOK.thin or LOOK).inset - out + 0.5))
    for _, t in ipairs({ d.Bg, d.Material }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", d.host, "TOPLEFT", inset, -inset)
        t:SetPoint("BOTTOMRIGHT", d.host, "BOTTOMRIGHT", -inset, inset)
    end
    d.Bg:SetTexture(WHITE)
    d.Bg:SetGradient("VERTICAL", CreateColor(unpack(fill.foot)), CreateColor(unpack(fill.top)))
    d.Bg:Show()
    local mat = fill.material
    if mat then
        d.Material:SetTexture(mat.file, "REPEAT", "REPEAT")
        d.Material:SetDesaturated(true)
        d.Material:SetTexCoord(0, (w - 2 * inset) / mat.size, 0, (h - 2 * inset) / mat.size)
        d.Material:SetGradient("VERTICAL", CreateColor(unpack(fill.matFoot)), CreateColor(unpack(fill.matTop)))
        d.Material:Show()
    else
        d.Material:Hide()
    end
    d.inset = inset
end

-- Gives `host` the thin border over it and the background under its own regions; once per host, then refreshed.
-- role: { bg = false for none, level }.
function Border.Attach(host, role)
    local d = host.KaLiBorder
    if not d then
        d = CreateFrame("Frame", nil, host)
        d:SetAllPoints(host)
        d:EnableMouse(false)
        d.host = host
        d.pool = {}
        d.Bg = host:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.Material = host:CreateTexture(nil, "BACKGROUND", nil, -7)
        d.Material:SetBlendMode("ADD")
        host.KaLiBorder = d
        decorations[#decorations + 1] = d
        host:HookScript("OnSizeChanged", function()
            ns.SafeCall(Border.Update, d)
        end)
    end
    d.role = role or {}
    d:SetFrameLevel((host:GetFrameLevel() or 0) + (d.role.level or 1))
    Border.Update(d)
    return d
end

-- Every decoration again, after an option changed.
function Border.ApplyAll()
    for _, d in ipairs(decorations) do
        ns.SafeCall(Border.Update, d)
    end
end

function Border.Count()
    return #decorations
end

-- The colour picker for an option holding "rrggbb"; cancel puts back the colour it had.
function Border.PickColor(key, onChange)
    if not (ns.db and ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
        return
    end
    local o = ns.db.options
    local before = rawget(o, key)
    local r, g, b = Border.RGB(o[key])
    local function set(hex)
        o[key] = hex
        ns.ApplyAll()
        if onChange then
            ns.SafeCall(onChange)
        end
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        hasOpacity = false,
        swatchFunc = function()
            set(Border.Hex(ColorPickerFrame:GetColorRGB()))
        end,
        cancelFunc = function()
            set(before)
        end,
    })
end
