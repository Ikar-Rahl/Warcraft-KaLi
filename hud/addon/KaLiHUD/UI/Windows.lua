-- Folding for ChatFrame1 and DamageMeter: one of Ikar's cartouches with the fold arrow in its ring, or the arrow alone,
-- on top of each covered window folds it away at a click, left alone on the plate, without moving any
-- Blizzard frame or touching DamageMeter:SetMinimized
-- (which taints secret session values). In Edit Mode, folded windows show at full size so they can be placed freely.
-- A fold is animated (foldAnim, on or off): the window goes at once, then its place on the plate comes down into it as
-- a blind, darkening as it goes; unfolding, the place rises first, lighter as it comes, and the window shows as it
-- comes to rest. No fading.
-- While the plate holds them, its edge is their border: their own frame and background (FlareUI's skins too) go
-- see-through, their alpha only.
local _, ns = ...

local Windows = {}
ns.Windows = Windows

local Frames, L = ns.Frames, ns.L

-- The fold arrow at rest and hovered; in a cartouche's ring, this much of it across.
local ARROW_REST, ARROW_HOVER = { 0.72, 0.56, 0.34 }, { 1.00, 0.86, 0.58 }
local ARROW = 0.75
-- Folded, a cartouche's level in BACKGROUND: over the plate (0) and its border's frames (a level or two over it).
local FOLDED_LEVEL = 20
-- The arrow alone ("arrow"), as Data/Cartouches.lua's but in UIParent's units at the default width: its V's foot on the
-- flat line.
local ARROW_ALONE = { w = 24, h = 24, ringX = 12, ringY = 12, base = 7, rise = 0 }
-- A fold's time, in seconds: a sheet's, both ways (Windows.Ease); 0.25 and 0.35 before, too quick to see it slow down.
local FOLD_TIME, UNFOLD_TIME = 0.5, 0.5
Windows.FOLD_TIME, Windows.UNFOLD_TIME = FOLD_TIME, UNFOLD_TIME

local SPECS = {
    ChatFrame1 = { option = "chatFolded", titleKey = "WIN_CHAT" },
    DamageMeter = { option = "meterFolded", titleKey = "WIN_METER" },
}

local state = {}
local unread = 0
local typing = false
local inCombat = false

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
}

local function isFolded(name)
    local o = ns.db.options
    if not o.windowFold or Frames.IsEditing() then
        return false
    end
    if name == "ChatFrame1" then
        return o.chatFolded and not (o.chatPeekOnType and typing)
    elseif name == "DamageMeter" then
        return o.meterFolded and not (o.meterUnfoldCombat and inCombat)
    end
    return false
end

-- How far a window is folded away as seen, 0 (open) to 1 (folded): on its way while its fold is animated.
local function progress(name)
    local st = state[name]
    if st and st.p then
        return st.p
    end
    return isFolded(name) and 1 or 0
end
Windows.Progress = progress

-- How much of its way a fold has gone after `u` of its time (Ikar 2026-11-15: "make it not linear"; 2026-11-16: "when
-- it collapses it should end the motion more slowly ... I am sure folding unfolding animation have some golden
-- value"): iOS's sheet curve, cubic-bezier(0.32, 0.72, 0, 1), as Vaul's drawer has it over 0.5 s, both ways. Its
-- place stays in sight and comes to rest, as a sheet does: it sets off at once, as the click asks, is 90 % there at a
-- third of its time and slows into place over the rest (a cubic ease-out over 0.25 s, before, ended too fast to see).
-- The ease-in of what leaves the screen isn't for it. A fold turned back on its way sets off back from where it stands.
local EASE = { 0.32, 0.72, 0, 1 }
local function bezier(t, a, b)
    local s = 1 - t
    return 3 * s * s * t * a + 3 * s * t * t * b + t * t * t
end
-- the curve's height where its run is u (0 to 1), or its run where its height is p: both rise with t
local function solve(v, from, to, fromB, toB)
    if v <= 0 then
        return 0
    elseif v >= 1 then
        return 1
    end
    local lo, hi = 0, 1
    for _ = 1, 30 do
        local m = (lo + hi) / 2
        if bezier(m, from, fromB) < v then
            lo = m
        else
            hi = m
        end
    end
    return bezier((lo + hi) / 2, to, toB)
end
local function ease(u)
    return solve(u, EASE[1], EASE[2], EASE[3], EASE[4])
end
Windows.Ease = ease
local function timeShare(p)
    return solve(p, EASE[2], EASE[1], EASE[4], EASE[3])
end

-- Unfolding, the window shows again once its place has risen this close to whole (Ikar 2026-11-16: "show the panels a
-- bit earlier, at the end of the transition"), not after the slow end of its rise.
local SHOW_AT = 0.05
Windows.SHOW_AT = SHOW_AT

-- SetAlphaFromBoolean isn't SetAlpha, so FlareUI's hook on the chat, which puts back any alpha but its own, lets it be.
local function zero(f)
    if f.SetAlphaFromBoolean then
        f:SetAlphaFromBoolean(false, 1, 0)
    else
        f:SetAlpha(0)
    end
end

-- The frames a window shows as: the chat with every window docked with it, the dock showing the one whose tab is picked.
local alone = {}
local function partsOf(name)
    local dock = name == "ChatFrame1" and _G.GENERAL_CHAT_DOCK
    if type(dock) == "table" and dock.primary == _G.ChatFrame1 and type(dock.DOCKED_CHAT_FRAMES) == "table" then
        return dock.DOCKED_CHAT_FRAMES
    end
    local parts = alone[name] or {}
    parts[1] = _G[name]
    alone[name] = parts
    return parts
end

-- A frame of a window hidden: see-through and deaf to the mouse, how it was kept in st.was; or shown as it was again.
local alphaHooked = {}
local function hideFrame(st, f, hide)
    local was = st.was[f]
    if hide then
        if not was then
            local alpha = f.GetAlpha and f:GetAlpha() or 1
            was = { alpha = alpha > 0 and alpha or 1, mouse = f.IsMouseEnabled and f:IsMouseEnabled(),
                wheel = f.IsMouseWheelEnabled and f:IsMouseWheelEnabled() }
            st.was[f] = was
            if f.EnableMouse then
                f:EnableMouse(false)
            end
            if f.EnableMouseWheel then
                f:EnableMouseWheel(false)
            end
            -- FlareUI's skin round it, as see-through as the player set it there: kept, to give back
            if f.FlareUI_Skin then
                was.skin = f.FlareUI_Skin:GetAlpha()
                f.FlareUI_Skin:SetAlpha(0)
            end
            if not alphaHooked[f] and f.SetAlpha then
                alphaHooked[f] = true
                hooksecurefunc(f, "SetAlpha", ns.Guarded(function(target, a)
                    if st.was[target] and a > 0 then
                        zero(target)
                    end
                end))
            end
        end
        zero(f)
    elseif was then
        st.was[f] = nil
        f:SetAlpha(was.alpha)
        if was.mouse ~= nil and f.EnableMouse then
            f:EnableMouse(was.mouse)
        end
        if was.wheel ~= nil and f.EnableMouseWheel then
            f:EnableMouseWheel(was.wheel)
        end
        if f.FlareUI_Skin then
            f.FlareUI_Skin:SetAlpha(was.skin or 1)
        end
    end
end

local function setHiddenVisual(name, hide)
    if type(_G[name]) ~= "table" then
        return
    end
    local st = state[name] or {}
    state[name] = st
    st.was = st.was or {}
    if hide then
        for _, part in ipairs(partsOf(name)) do
            hideFrame(st, part, true)
        end
    else
        for part in pairs(st.was) do
            hideFrame(st, part, false)
        end
    end
    if hide == st.hidden then
        return
    end
    st.hidden = hide
    local w = name == "DamageMeter" and _G.DamageMeterSessionWindow1
    if not w then
        return
    end
    if hide then
        -- as see-through as it was, to give back (it came back at full strength whatever it had been)
        local alpha = w.GetAlpha and w:GetAlpha() or 1
        st.winAlpha = alpha > 0 and alpha or 1
        st.winMouse = w.IsMouseEnabled and w:IsMouseEnabled()
        st.winWheel = w.IsMouseWheelEnabled and w:IsMouseWheelEnabled()
        zero(w)
        if w.EnableMouse then
            w:EnableMouse(false)
        end
        if w.EnableMouseWheel then
            w:EnableMouseWheel(false)
        end
    else
        w:SetAlpha(st.winAlpha or 1)
        if st.winMouse ~= nil and w.EnableMouse then
            w:EnableMouse(st.winMouse)
        end
        if st.winWheel ~= nil and w.EnableMouseWheel then
            w:EnableMouseWheel(st.winWheel)
        end
    end
end

-- Backdrop.lua's pieces: a skin's frame and background, without what sits on it (FlareUI's tabs and header buttons).
local BACKDROP_PIECES = { "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner", "TopRightCorner",
    "BottomLeftCorner", "BottomRightCorner" }

-- Their own frame and background, which the plate's edge replaces while it holds them.
local function ownArt(name)
    local out = {}
    local function skin(s)
        if type(s) == "table" then
            for _, key in ipairs(BACKDROP_PIECES) do
                out[#out + 1] = s[key]
            end
        end
    end
    if name == "ChatFrame1" then
        for _, f in ipairs(partsOf(name)) do
            local frameName = f.GetName and f:GetName()
            for _, key in ipairs(frameName and _G.CHAT_FRAME_TEXTURES or {}) do
                out[#out + 1] = _G[frameName .. key]
            end
            skin(f.FlareUI_Skin)
        end
    elseif name == "DamageMeter" then
        local w = _G.DamageMeterSessionWindow1
        out[#out + 1] = w and type(w.GetBackground) == "function" and w:GetBackground() or nil
        skin(w and w.FlareUI_DMSkin)
    end
    return out
end

-- Regions kept see-through, { [region] = the alpha to give back }; when Blizzard fades one in, it's noted and undone.
local veiled, veilHooked = {}, {}
local function veil(region, on)
    if type(region) ~= "table" or not region.SetAlpha then
        return
    end
    if on and veiled[region] == nil then
        veiled[region] = region:GetAlpha() or 1
        if not veilHooked[region] then
            veilHooked[region] = true
            hooksecurefunc(region, "SetAlpha", ns.Guarded(function(r, a)
                if veiled[r] ~= nil and a > 0 then
                    veiled[r] = a
                    r:SetAlpha(0)
                end
            end))
        end
        region:SetAlpha(0)
    elseif not on and veiled[region] ~= nil then
        local a = veiled[region]
        veiled[region] = nil
        region:SetAlpha(a)
    end
end

-- What folds a window: a cartouche's art with a dark well in its ring, its own colour (or neither), the arrow over
-- them; its tooltip names the window (and the chat's unread count) over what a click does.
local function makeFoldButton(toggle)
    local b = CreateFrame("Button", nil, nil)
    b:SetParent(UIParent)
    b:RegisterForClicks("LeftButtonUp")
    -- Folded, it's drawn behind the info bar (Ikar 2026-11-18: "when collapsed, can we put the cartouche behind the
    -- info bar ?"), over the plate, where the window's see-through rows over it would take its clicks: Catch, unseen,
    -- over the part of it the bar leaves, takes them for it, its scripts the cartouche's.
    local c = CreateFrame("Button", nil, nil)
    c:SetParent(UIParent)
    c:RegisterForClicks("LeftButtonUp")
    c:SetFrameStrata("HIGH")
    c:SetFrameLevel(21)
    b.Catch = c
    -- its scripts under the handlers' guard (ns.Guarded): its click redraws the plate, and takes the tooltip away (Ikar
    -- 2026-11-18: "when opening anything, the tooltip should disappear"), which said what the click was to do
    local click = ns.Guarded(function(_, ...)
        toggle(b, ...)
        if GameTooltip:GetOwner() == b then
            GameTooltip:Hide()
        end
    end)
    -- Folded, what of it lies under the bar's top fades out down to the bar's middle, under the bar's buttons, and
    -- isn't drawn under that (Ikar 2026-11-19: "the cartouche not hidden, just drawn bellow icon, but on top of the bar,
    -- feel ugly still"; 2026-11-20: "instead of hiding the bottom, make a transparency gradient, till half the info
    -- bar"): its art and its well each in two, the part over the bar whole and the part that fades (ArtFade,
    -- WellFade), on Body, within Clip.
    local clip = CreateFrame("Frame", nil, b)
    clip:SetClipsChildren(true)
    local body = CreateFrame("Frame", nil, clip)
    body:SetAllPoints(b)
    b.Clip = clip
    b.Art = body:CreateTexture(nil, "ARTWORK")
    b.ArtFade = body:CreateTexture(nil, "ARTWORK")
    b.Well = body:CreateTexture(nil, "BORDER")
    b.Well:SetTexture(ns.DISC)
    b.WellFade = body:CreateTexture(nil, "BORDER")
    b.WellFade:SetTexture(ns.DISC)
    b.Icon = body:CreateTexture(nil, "OVERLAY")
    b.Icon:SetTexture(ns.CHEVRON)
    b.Icon:SetVertexColor(ARROW_REST[1], ARROW_REST[2], ARROW_REST[3], 0.9)
    local enter = ns.Guarded(function()
        b.Icon:SetVertexColor(ARROW_HOVER[1], ARROW_HOVER[2], ARROW_HOVER[3], 1)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip_SetTitle(GameTooltip, b.title or "")
        GameTooltip_AddInstructionLine(GameTooltip, b.tip or "")
        GameTooltip:Show()
    end)
    local leave = ns.Guarded(function()
        b.Icon:SetVertexColor(ARROW_REST[1], ARROW_REST[2], ARROW_REST[3], 0.9)
        if GameTooltip:GetOwner() == b then
            GameTooltip:Hide()
        end
    end)
    for _, f in ipairs({ b, c }) do
        f:SetScript("OnClick", click)
        f:SetScript("OnEnter", enter)
        f:SetScript("OnLeave", leave)
    end
    b:Hide()
    c:Hide()
    return b
end

-- One of the cartouche's textures over f, from y0 up to y1 (UIParent units; f's foot at fy), its texture's right
-- and bottom at u1, v1, in colour c: whole down to `from`, fading out from there down to `to` (fade, the other half),
-- nothing under `to`. from = to: no fade, cut there.
local function fadeDown(f, fy, tex, fade, left, width, y0, y1, u1, v1, from, to, c)
    local function v(y)
        return (y1 - y) / (y1 - y0) * v1
    end
    local cut = math.max(y0, math.min(y1, from))
    local stop = math.max(y0, math.min(y1, to))
    if y1 > cut then
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, cut - fy)
        tex:SetSize(width, y1 - cut)
        tex:SetTexCoord(0, u1, 0, v(cut))
        tex:SetVertexColor(c[1], c[2], c[3], c[4])
        tex:Show()
    else
        tex:Hide()
    end
    if cut > stop then
        local function alpha(y)
            return c[4] * math.min(1, math.max(0, (y - to) / (from - to)))
        end
        fade:ClearAllPoints()
        fade:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, stop - fy)
        fade:SetSize(width, cut - stop)
        fade:SetTexCoord(0, u1, v(cut), v(stop))
        fade:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], alpha(stop)), CreateColor(c[1], c[2], c[3], alpha(cut)))
        fade:Show()
    else
        fade:Hide()
    end
end
local WHITE = { 1, 1, 1, 1 }

-- A cartouche (Data/Cartouches.lua) or the arrow alone over a window's span t, its ring over the window's middle: a
-- cartouche foldArtWidth of the window's width, half by default, its height and its ring as its art has them (Ikar
-- 2026-11-20, asked whether each should be half its window's width, its ring then changing from one window and one
-- art to the next: "Yes, keep the slider, but it shoudl show relative size, default to 50%"; its ring the same size on
-- every cartouche and window from 2026-11-18 until then, "Make the button the same size, allow the length to varry");
-- the arrow alone its own size at the default width, grown or shrunk as the slider is from it. Its flat line stands
-- look.rise over the middle of the plate's metal over `foot` (the window's top), so it follows the border at half its
-- width and keeps its place at any size; foldArtLift raises or sinks it. up: a click unfolds, the arrow points up. Set
-- again only when something changed.
local function placeFold(f, look, t, foot, folded, up)
    local o = ns.db.options
    local s = look.file and o.foldArtWidth / 100 * t.w / look.w or o.foldArtWidth / ns.DB.DEFAULTS.foldArtWidth
    local line = foot + ns.Border.Hug() / 2 + look.rise + o.foldArtLift
    local x, y = t.x + t.w / 2 - look.ringX * s, line - look.base * s
    f.tip = up and L.WIN_UNFOLD or L.WIN_FOLD
    local bar = ns.InfoBar.Top()
    if f:IsShown() and f._look == look and f._s == s and f._x == x and f._y == y and f._folded == folded
        and f._up == up and f._bar == bar then
        return
    end
    f._look, f._s, f._x, f._y, f._folded, f._up, f._bar = look, s, x, y, folded, up, bar
    f:SetSize(look.w * s, look.h * s)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    local cx, cy = look.ringX * s, -look.ringY * s
    -- folded, whole down to the bar's top, faded out down to its middle; open, whole
    local top, mid = y + look.h * s, bar / 2
    local from, to = folded and bar or y, folded and mid or y
    for _, t in ipairs({ f.Art, f.ArtFade, f.Well, f.WellFade }) do
        t:Hide()
    end
    if look.file then
        -- drawn smaller than its texture wherever a UIParent unit is less than its texels (a small size, a low
        -- screen, a small UI scale): filtered as Blizzard's own scaled map art is, so its thin lines don't break up
        f.Art:SetTexture(look.file, nil, nil, "TRILINEAR")
        f.ArtFade:SetTexture(look.file, nil, nil, "TRILINEAR")
        fadeDown(f, y, f.Art, f.ArtFade, 0, look.w * s, y, top, look.right, look.bottom, from, to, WHITE)
        local r = look.ringR * s
        fadeDown(f, y, f.Well, f.WellFade, cx - r, 2 * r, top + cy - r, top + cy + r, 1, 1, from, to, look.well)
    end
    local across = (look.ringR and ARROW * 2 * look.ringR or look.w) * s
    f.Icon:SetSize(across, across)
    f.Icon:ClearAllPoints()
    f.Icon:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
    f.Icon:SetRotation(up and math.pi or 0)
    -- folded, behind the info bar's buttons (LOW) and over the plate (BACKGROUND, its border's frames a level or two
    -- up), faded out down to the bar's middle and cut there, its clicks taken over the window's see-through rows by
    -- Catch where the bar leaves it, the bar's buttons under the rest; open, over the window, whole
    local c = f.Catch
    f:SetFrameStrata(folded and "BACKGROUND" or "MEDIUM")
    f:SetFrameLevel(folded and FOLDED_LEVEL or 40)
    f:EnableMouse(not folded)
    local bottom = folded and math.max(y, bar) or y
    f.Clip:ClearAllPoints()
    f.Clip:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.Clip:SetSize(look.w * s, math.max(top - math.max(y, to), 0))
    if folded and top > bottom then
        c:ClearAllPoints()
        c:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, bottom)
        c:SetSize(look.w * s, top - bottom)
        c:Show()
    else
        c:Hide()
    end
    f:Show()
end

local function ensureUI(name)
    local st = state[name] or {}
    state[name] = st
    if not st.fold then
        st.fold = makeFoldButton(function()
            Windows.Toggle(name)
        end)
    end
    return st
end

-- A window's place on the plate as far as its fold went: none once folded (it leaves the plate); while it folds, its
-- top comes down to under the plate's foot, its place sinking into the plate.
function Windows.AdjustSpan(name, x, y, w, h, footTop)
    if not SPECS[name] then
        return x, y, w, h
    end
    local p = progress(name)
    if p >= 1 then
        return nil
    elseif p > 0 then
        local top = y + h + (footTop - ns.Border.Hug() - y - h) * p
        local bottom = math.min(y, top - 1)
        return x, bottom, w, top - bottom
    end
    return x, y, w, h
end

-- ---------- Folding animated (Ikar 2026-11-15: "no fading, I want folding") ----------

local driver
-- Each fold on: the share of its time where it stands (ease's inverse), on by `elapsed`, and where that puts it.
local function step(_, elapsed)
    local moving = false
    for _, st in pairs(state) do
        if st.p and st.target and st.p ~= st.target then
            local folding = st.p < st.target
            local gone = folding and st.p or 1 - st.p
            local u = timeShare(gone) + (elapsed or 0) / (folding and FOLD_TIME or UNFOLD_TIME)
            if u >= 1 - 1e-6 then
                st.p = st.target
            else
                gone = ease(u)
                st.p = folding and gone or 1 - gone
            end
            moving = moving or st.p ~= st.target
        end
    end
    if not moving then
        driver:SetScript("OnUpdate", nil)
    end
    -- every frame fast, the last one in full
    ns.Plate.Redraw(moving)
end
Windows.Step = step

-- An error while a fold was on its way: each fold where it was going, at once, and the plate drawn in full.
local function settle()
    for _, st in pairs(state) do
        if st.target then
            st.p = st.target
        end
    end
    ns.Plate.Request()
end

-- Before each layout: a window whose fold changed sets off, animated if it stands on the plate, else is there at once.
function Windows.Begin()
    local o = ns.db.options
    for name in pairs(SPECS) do
        local st = state[name] or {}
        state[name] = st
        local target = isFolded(name) and 1 or 0
        if st.target ~= target then
            local animate = st.target ~= nil and st.onPlate and o.windowFold and o.foldAnim
                and not Frames.IsEditing()
            st.target = target
            if animate then
                driver = driver or CreateFrame("Frame")
                ns.EveryFrame(driver, step, settle)
            else
                st.p = target
            end
        end
    end
end

function Windows.Animating()
    return driver ~= nil and driver:GetScript("OnUpdate") ~= nil
end

-- For the plate: how dark a window's place is now with the darkening blind (Ikar 2026-11-15, the accordion gone; the
-- only fold animated since 2026-11-18), as far as it went, 0 to 1; else nil.
function Windows.Shading(name)
    local st = state[name]
    if st and st.p and st.p > 0 and st.p < 1 and ns.db.options.foldAnim then
        return st.p
    end
end

local function takenOf(art, name)
    for _, f in ipairs(art.taken) do
        if f.key == name then
            return f
        end
    end
end

-- The plate's top over x, as drawn.
local function plateTop(art, x)
    for _, s in ipairs(art.segs) do
        if s.x0 <= x and s.x1 >= x then
            return s.top
        end
    end
    return art.T
end

local function title(name)
    local label = L[SPECS[name].titleKey]
    if name == "ChatFrame1" and unread > 0 then
        return string.format("%s (%d)", label, unread)
    end
    return label
end

-- Syncs the cartouches or arrows once the plate knows which frames it took; while live (fast), what didn't change is
-- left: a window's own art is looked for again on a full redraw only.
function Windows.Sync(art, fast)
    local o = ns.db.options
    local look = ns.CARTOUCHES[o.foldArt] or ARROW_ALONE
    for name, spec in pairs(SPECS) do
        local st = ensureUI(name)
        -- where the plate holds it whole (art.held), and its place there as far as its fold went (art.taken)
        local held = art.held and art.held[name]
        local t = takenOf(art, name) or held
        st.onPlate = held ~= nil
        -- the window goes as its fold starts and comes back as its place is all but whole again
        local away = (st.target or progress(name)) == 1
        local hidden = held ~= nil and (away or progress(name) > SHOW_AT)
        if not (fast and hidden == st.hidden) then
            setHiddenVisual(name, hidden)
        end
        local veiled = held ~= nil and o.plate
        if not (fast and veiled == st.veiled) then
            st.veiled = veiled
            for _, region in ipairs(ownArt(name)) do
                veil(region, veiled)
            end
        end
        local f = st.fold
        f.title = title(name)
        if hidden then
            -- alone on the plate, where its metal lies under the window's middle: on its place's top while it moves
            local foot = math.max(plateTop(art, t.x + t.w / 2) - ns.Border.Hug(), art.T)
            placeFold(f, look, t, foot, true, away)
        elseif t and o.windowFold then
            -- in Edit Mode too, its click as saved
            placeFold(f, look, t, t.y + t.h, false, Frames.IsEditing() and o[spec.option])
        else
            f:Hide()
            f.Catch:Hide()
        end
    end
end

function Windows.Toggle(name)
    local spec = SPECS[name]
    if spec then
        local o = ns.db.options
        o[spec.option] = not o[spec.option]
        if name == "ChatFrame1" and not o.chatFolded then
            unread = 0
        end
        ns.Plate.Redraw()
        ns.PlaySoundOf(ns.FOLD_SOUNDS, o.foldSound, not o[spec.option])
    end
end

function Windows.Cartouche(name)
    return state[name] and state[name].fold
end

function Windows.Start()
    for _, ev in ipairs(CHAT_EVENTS) do
        ns.On(ev, function()
            if ns.db and ns.db.options.chatFolded and isFolded("ChatFrame1") then
                unread = unread + 1
                local st = state.ChatFrame1
                if st and st.fold then
                    st.fold.title = title("ChatFrame1")
                end
            end
        end)
    end
    ns.On("PLAYER_REGEN_DISABLED", function()
        inCombat = true
        if ns.db and ns.db.options.meterFolded and ns.db.options.meterUnfoldCombat then
            ns.Plate.Request()
        end
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        inCombat = false
        if ns.db and ns.db.options.meterFolded and ns.db.options.meterUnfoldCombat then
            ns.Plate.Request()
        end
    end)
    -- Typing: the chat's own box, and with the chat style « messagerie instantanée » (the game's chatStyle "im") the
    -- box of each window docked with it, where a line is typed then (the review of 2026-11-18: only the first was
    -- heard, so with another tab picked the folded chat stayed folded; to see in game). A window that stands apart
    -- from the chat isn't the chat's.
    local function typed(index, on)
        local frame, dock = _G["ChatFrame" .. index], _G.GENERAL_CHAT_DOCK
        local docked = index == 1
        for _, f in ipairs(not docked and type(dock) == "table" and type(dock.DOCKED_CHAT_FRAMES) == "table"
            and dock.DOCKED_CHAT_FRAMES or {}) do
            docked = docked or f == frame
        end
        if not docked then
            return
        end
        typing = on
        if ns.db and ns.db.options.chatFolded and ns.db.options.chatPeekOnType then
            ns.Plate.Request()
        end
    end
    for index = 1, type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10 do
        local eb = _G["ChatFrame" .. index .. "EditBox"]
        if type(eb) == "table" and eb.HookScript then
            eb:HookScript("OnEditFocusGained", ns.Guarded(function()
                typed(index, true)
            end))
            eb:HookScript("OnEditFocusLost", ns.Guarded(function()
                typed(index, false)
            end))
        end
    end
end