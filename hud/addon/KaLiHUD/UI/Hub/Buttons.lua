-- The frames the slot hub draws for its elements: our buttons (KaLi HUD's items, LDB objects, folders, macros)
-- wherever they stand, every icon's art at the icon size; and, while unlocked, a handle over each of Blizzard's widgets
-- and other addons' map buttons to drag them by. Clicks are the element's own; a right-click opens its hub menu, but
-- another addon's own while the padlock is shut (UI/Hub/Menus.lua's RightIsHub). A
-- folder's and a macro's are secure buttons, Blizzard's templates, which the game runs on the player's click in combat
-- too and which no addon may move, show, hide or size during a fight (UI/Hub/InfoBar.lua holds the bar then).
local _, ns = ...

local Buttons = {}
ns.HubButtons = Buttons

local Hub = ns.Hub

local GOLD, TEXT = { 1, 0.82, 0 }, { 0.88, 0.88, 0.88 }
-- The handles' hover.
local LIT = { 1, 1, 1 }

-- The drawn part of the atlases we show as icons (texels over 40/255 alpha in Forever's art): left, top, right, bottom
-- of the atlas, so every icon's art, not its empty margin, comes out at the icon size. Others are drawn whole.
local ART = {
    ["auctionhouse-icon-clock"] = { 0.083, 0.083, 0.875, 0.917 },
    ["bag-main"] = { 0.052, 0.031, 0.927, 0.969 },
    ["Crosshair_Repair_32"] = { 0.062, 0.062, 0.938, 0.969 },
    ["chatframe-button-icon-speaker-on"] = { 0.207, 0.172, 0.828, 1 },
    ["ui-hud-minimap-tracking-button"] = { 0.022, 0.043, 0.978, 0.978 },
    ["ui-hud-minimap-calendar-button"] = { 0.022, 0.043, 0.978, 0.978 },
    ["ui-hud-minimap-addon-indicator"] = { 0.109, 0.068, 0.913, 0.886 },
    ["ui-hud-minimap-mail-icon"] = { 0.062, 0.083, 0.938, 0.917 },
}
-- The folders' icons' too (Data/Icons.lua).
for _, icon in ipairs(ns.ICONS) do
    ART[icon[1]] = ART[icon[1]] or { icon[2], icon[3], icon[4], icon[5] }
end
local WHOLE = { 0, 0, 1, 1 }

local buttons, handles = {}, {}
-- Our elements whose button is secure, by kind: a folder's opens its list in combat (UI/Hub/Folders.lua), a macro's runs
-- it (UI/Hub/Macros.lua). Made so from the start, known by their id: a frame can't become secure later.
local SECURE = {
    folder = table.concat({ "SecureHandlerClickTemplate", "SecureHandlerEnterLeaveTemplate" }, ", "),
    macro = "SecureActionButtonTemplate",
}

-- Shows the part `box` of a texture `w` x `h` (within l, r, t, b of its file) on `tex`, its longer side `size`; returns
-- the width it takes.
function Buttons.FitTexture(tex, box, w, h, size, l, r, t, b)
    l, r, t, b = l or 0, r or 1, t or 0, b or 1
    tex:SetTexCoord(l + (r - l) * box[1], l + (r - l) * box[3], t + (b - t) * box[2], t + (b - t) * box[4])
    w, h = w * (box[3] - box[1]), h * (box[4] - box[2])
    local k = size / math.max(w, h)
    tex:SetSize(w * k, h * k)
    return w * k
end

-- An atlas as an icon, its drawn part `size` across its longer side; the width it takes, nil if the game lacks it.
function Buttons.FitAtlas(tex, atlas, size)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not (info and info.file) then
        return nil
    end
    tex:SetTexture(info.file)
    return Buttons.FitTexture(tex, ART[atlas] or WHOLE, info.width or 1, info.height or 1, size,
        info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
end

-- In place of an icon the game no longer has (Ikar 2026-11-16: "in case Blizzard changes them... a default icon, like a
-- question mark"): Blizzard's own for that, QUESTION_MARK_ICON (Blizzard_FrameXMLBase's Constants.lua; 134400 is that
-- file), cropped of its frame as the bar's file icons, `size` across. Returns the width it takes.
function Buttons.Missing(tex, size)
    tex:SetTexture(QUESTION_MARK_ICON or 134400)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex:SetSize(size, size)
    return size
end

-- An atlas as an icon (FitAtlas), or the question mark when the game lacks it: the width it takes, and true for that.
function Buttons.FitIcon(tex, atlas, size)
    local w = Buttons.FitAtlas(tex, atlas, size)
    if w then
        return w, false
    end
    return Buttons.Missing(tex, size), true
end

-- A font string of the hub's at the info bar's text size, in the game's own small font.
function Buttons.SizeText(fs)
    local size = ns.Hub.TextSize()
    if fs.kaliSize ~= size then
        local font, _, flags = GameFontHighlightSmall:GetFont()
        if font then
            fs:SetFont(font, size, flags)
            fs.kaliSize = size
        end
    end
end

function Buttons.Get(name)
    return buttons[name]
end

-- Every button made, by name: read it, never change it.
function Buttons.All()
    return buttons
end

-- While something is dragged, none lights up under the pointer, the drop's marker alone saying where it goes: in a
-- list, a button is as wide as its text, so its light followed the names, not the line (Ikar 2026-11-19: "the position
-- hight only when you hover on top of a texte, not the whole line").
function Buttons.Highlights(on)
    local a = on and 1 or 0
    for _, set in ipairs({ buttons, handles }) do
        for _, b in pairs(set) do
            if b.Highlight then
                b.Highlight:SetAlpha(a)
            end
        end
    end
end

function Buttons.Handle(name)
    return handles[name]
end

-- ---------- Our buttons ----------

local function objectOf(b)
    return Hub.Object(b.name) or {}
end

local function onEnter(self)
    if ns.HubDrag.Current() then
        return
    end
    if self.textColor then
        self.Text:SetTextColor(1, 1, 1)
    end
    local obj = objectOf(self)
    if obj.isFolder then
        -- its name, and what it's for and its type; with its name by it too since 2026-11-20 (Ikar, of « Emote »:
        -- "Social folder has no tooltip"; none there from 2026-11-14). One that opens on hover does so by its secure
        -- handler (Folders.Wire), which ran before this. None over its open list (Ikar 2026-11-18: "when opening
        -- anything, the tooltip should disappear").
        local list = ns.Folders.Panel(self.name)
        if obj.label and not (list and list:IsShown()) then
            GameTooltip:SetOwner(self, Hub.ROUND[self.slotSide] and "ANCHOR_LEFT" or "ANCHOR_TOP")
            GameTooltip:SetText(obj.label, GOLD[1], GOLD[2], GOLD[3])
            -- the one that takes what doesn't fit on the bar says so (UI/Hub/InfoBar.lua's fit); its type last
            local folder = ns.Folders.Get(self.name)
            if folder and folder.overflow then
                GameTooltip:AddLine(ns.L.FOLDER_OVERFLOW_TIP, 0.5, 0.5, 0.5, true)
            end
            ns.HubMenus.AddType(GameTooltip, self.name)
            GameTooltip:Show()
        end
    elseif type(obj.OnEnter) == "function" then
        ns.SafeCall(obj.OnEnter, self)
        -- an addon drawing its own tooltip elsewhere (LibQTip) gets none of ours
        if GameTooltip:IsOwned(self) then
            ns.HubMenus.AddHints(GameTooltip, self.name)
            GameTooltip:Show()
        end
    else
        GameTooltip:SetOwner(self, Hub.ROUND[self.slotSide] and "ANCHOR_LEFT" or "ANCHOR_TOP")
        if type(obj.OnTooltipShow) == "function" then
            ns.SafeCall(obj.OnTooltipShow, GameTooltip)
        else
            GameTooltip:SetText(Hub.Label(self.name, obj), GOLD[1], GOLD[2], GOLD[3])
        end
        if not Hub.IsFixed(self.name) and not obj.noHints then
            ns.HubMenus.AddHints(GameTooltip, self.name)
        else
            -- the zone, a separator (its own hints): its type alone
            ns.HubMenus.AddType(GameTooltip, self.name)
        end
        GameTooltip:Show()
    end
    -- one round the map seen on hover keeps the others seen while the pointer is on it
    if Hub.ROUND[self.slotSide] then
        ns.SafeCall(ns.Minimap.UpdateHover)
    end
end

local function onLeave(self)
    if self.textColor then
        self.Text:SetTextColor(self.textColor[1], self.textColor[2], self.textColor[3])
    end
    local obj = objectOf(self)
    if type(obj.OnLeave) == "function" then
        ns.SafeCall(obj.OnLeave, self)
    else
        GameTooltip:Hide()
    end
    if Hub.ROUND[self.slotSide] then
        ns.SafeCall(ns.Minimap.UpdateHover)
    end
end

local function onClick(self, mouseButton)
    if self._dragged then
        self._dragged = false
        -- a folder's secure handler opened or shut its list on the click that ended the drag: as it was before
        if ns.Folders.IsId(self.name) then
            ns.Folders.AfterDrag(self.name)
        end
        return
    end
    local obj = objectOf(self)
    if mouseButton == "RightButton" and obj.isSeparator then
        -- a separator's one menu: it goes nowhere but into folders
        ns.HubMenus.OpenQuick(self, self.name, obj)
    elseif mouseButton == "RightButton" and ns.HubMenus.RightIsHub(self.name) then
        -- ours, or any while the padlock is open: the hub menu (UI/Hub/Menus.lua's RightIsHub)
        ns.HubMenus.OpenElement(self, self.name)
    elseif mouseButton == "RightButton" and obj.isMacro then
        -- its own right-click, which its secure button ran before this (UI/Hub/Macros.lua's Arm): nothing of ours
        -- but the tooltip's going, below
    elseif mouseButton == "RightButton" and (Hub.IsOurs(self.name) or obj.isFolder) then
        -- the zone, which has no hub menu: its quick menu, when it has one
        if obj.menu then
            ns.HubMenus.OpenQuick(self, self.name, obj)
        end
    elseif type(obj.OnClick) == "function" then
        ns.SafeCall(obj.OnClick, self, mouseButton)
    end
    -- What a click opens (a window, a list, a note, another addon's panel; a macro's commands) takes the tooltip away
    -- (Ikar 2026-11-18: "when opening anything, the tooltip should disappear"), the pointer coming back on the button
    -- bringing it again. One whose click opens nothing, only changing what its tooltip says (keepsTip: the memory, the
    -- sound), has it drawn again, as the padlock's.
    if GameTooltip:IsOwned(self) then
        if obj.keepsTip then
            onEnter(self)
        else
            GameTooltip:Hide()
        end
    end
end

local function onWheel(self, delta)
    local obj = objectOf(self)
    if type(obj.OnMouseWheel) == "function" then
        ns.SafeCall(obj.OnMouseWheel, self, delta)
    end
end

-- The handles' too: what the pointer took is dragged, and its click that ends the drag is no click.
local function onDragStart(self)
    if ns.HubDrag.Begin(self.name, self) then
        self._dragged = true
    end
end

local function onDragStop()
    ns.HubDrag.Finish()
end

-- Our buttons' scripts, each under the handlers' guard (ns.Guarded), made once for all of them: these guarded what
-- an element's own object does (ns.SafeCall), not what they do themselves, and an error there went to the game alone
-- (the review of 2026-11-18).
local SCRIPTS = {}
for script, fn in pairs({ OnEnter = onEnter, OnLeave = onLeave, OnClick = onClick, OnMouseWheel = onWheel,
    OnDragStart = onDragStart, OnDragStop = onDragStop }) do
    SCRIPTS[script] = ns.Guarded(fn)
end

-- Which secure kind an element's button is: "folder", "macro", or nil for a plain one.
function Buttons.Kind(name)
    if ns.Folders.IsId(name) then
        return "folder"
    elseif ns.Macros.IsId(name) then
        return "macro"
    end
end

-- Our button for `name`, made the first time (out of combat: the hub lays out no other time); where it stands is
-- InfoBar's or a folder's. A secure template's own scripts run first, ours after them.
function Buttons.Make(name)
    local b = buttons[name]
    if b then
        return b
    end
    local kind = Buttons.Kind(name)
    b = CreateFrame("Button", nil, nil, kind and SECURE[kind] or nil)
    b:SetParent(UIParent)
    b.name, b.secure = name, kind ~= nil
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.Text:SetWordWrap(false)
    b.Highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.Highlight:SetPoint("TOPLEFT", -4, -2)
    b.Highlight:SetPoint("BOTTOMRIGHT", 4, 2)
    b.Highlight:SetColorTexture(1, 0.82, 0, 0.08)
    for script, fn in pairs(SCRIPTS) do
        if b:GetScript(script) then
            b:HookScript(script, fn)
        else
            b:SetScript(script, fn)
        end
    end
    buttons[name] = b
    if kind == "folder" then
        ns.Folders.Wire(b, name)
    elseif kind == "macro" then
        ns.Macros.Wire(b, name)
    end
    return b
end

-- The icon from the object: an atlas cropped to its art (the question mark for one the game lacks: icon._missing), or a
-- file with its coordinates; set again only when one of them or the size changed. Returns the width it takes, nil
-- without one.
local function setIcon(icon, obj, size)
    local atlas = type(obj.atlas) == "string" and obj.atlas or nil
    local file = not atlas and obj.icon or nil
    local c = file and type(obj.iconCoords) == "table" and obj.iconCoords or nil
    local l, r, t, b = 0.08, 0.92, 0.08, 0.92
    if c then
        l, r, t, b = c[1] or 0, c[2] or 1, c[3] or 0, c[4] or 1
    end
    if icon._atlas == atlas and icon._file == file and icon._size == size
        and icon._l == l and icon._r == r and icon._t == t and icon._b == b then
        return icon._w
    end
    icon._atlas, icon._file, icon._size, icon._l, icon._r, icon._t, icon._b = atlas, file, size, l, r, t, b
    icon._missing = nil
    if atlas then
        icon._w, icon._missing = Buttons.FitIcon(icon, atlas, size)
        -- the question mark is asked again at the next drawing: the icon comes back if the game has it then
        if icon._missing then
            icon._atlas = nil
        end
    elseif file then
        icon:SetTexture(file)
        icon:SetTexCoord(l, r, t, b)
        icon:SetSize(size, size)
        icon._w = size
    else
        icon._w = nil
    end
    return icon._w
end

-- What a button on the bar or in a list says: a data source its text (or value), with its label when it has no icon
-- and isn't ours; a launcher nothing by its icon, its name withLabel.
local function textOf(name, obj, hasIcon, withLabel)
    if obj.type == "launcher" then
        if withLabel then
            return Hub.Label(name, obj)
        end
        -- a macro of ours: its name as its look says (Hub.LookOf)
        if obj.isMacro then
            return obj.text
        end
        return not hasIcon and obj.label or nil
    end
    -- a folder showing its icon alone on the bar: its name by it in a list with text
    if withLabel and obj.isFolder and obj.text == nil then
        return obj.label
    end
    local text = obj.text ~= nil and tostring(obj.text) or nil
    if obj.value ~= nil and text == nil then
        text = tostring(obj.value) .. (obj.suffix and (" " .. tostring(obj.suffix)) or "")
    end
    if not Hub.IsOurs(name) and not hasIcon and type(obj.label) == "string" and obj.label ~= text then
        text = NORMAL_FONT_COLOR:WrapTextInColorCode(obj.label) .. (text and (" " .. text) or "")
    end
    return text
end

-- ---------- A list's values ----------
-- A folder's list with text may set its values apart, aligned on its right, and grey those that say nothing (Ikar
-- 2026-11-20, the sketch of the attributes: "C'est très bien"; UI/Hub/Folders.lua's Values), whoever's they are.

-- A text without its colours, textures and atlases.
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

-- A data source's name and value: its label, and its text less the label it starts with (ours, "Force 55"), else
-- its text whole (another addon's, its label apart, as display addons show them); nil for what has no label, or
-- nothing but it.
function Buttons.Split(obj)
    if type(obj) ~= "table" or obj.type ~= "data source" or obj.isFolder or obj.isSeparator then
        return nil
    end
    local name = type(obj.label) == "string" and obj.label ~= "" and obj.label or nil
    local text = obj.text ~= nil and tostring(obj.text) or nil
    if text == nil and obj.value ~= nil then
        text = tostring(obj.value) .. (obj.suffix and (" " .. tostring(obj.suffix)) or "")
    end
    if not name or not text or text == "" or text == name then
        return nil
    end
    if text:sub(1, #name + 1) == name .. " " then
        text = text:sub(#name + 2)
    end
    return name, text
end

-- Whether a value says nothing: a nought however it's written (0, 0 %, 0,0 %, 0 (0)), with nothing else in it but
-- its marks; a dash; the game's « Aucun ». « Révéré 0 % » says something.
-- (the spaces a number is written with: French puts a no-break one before its « % »)
local DASHES = { ["—"] = true, ["-"] = true, [""] = true }
function Buttons.IsEmpty(value)
    local p = plain(tostring(value or "")):gsub("\194\160", " "):gsub("\226\128\175", " "):match("^%s*(.-)%s*$")
    if DASHES[p] or p == ns.G("NONE", "None") then
        return true
    end
    local rest = p:gsub("–", ""):gsub("[0%s%%,.()/%-]", "")
    return rest == "" and p:find("0") ~= nil
end

-- The value's string, made with the button, on its right.
local function valueOf(b)
    if not b.Value then
        b.Value = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        b.Value:SetWordWrap(false)
        b.Value:SetJustifyH("RIGHT")
        b.Value:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    end
    return b.Value
end
-- Between a name and its value, at the least; a value's colour, and one that says nothing's (GRAY_FONT_COLOR).
local VALUE_GAP = 12
local VALUE, DIM = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }
Buttons.VALUE_GAP = VALUE_GAP

-- Draws b from its object. round (round the map, a folder's grid): a place of its own, its icon on nothing (Ikar
-- 2026-11-14: Blizzard's dark round button behind it shrank the icon), or its text's first letters. Else, on the bar
-- or in a list `h` high: its icon then its text, a launcher's name by its icon withLabel (a list with text); `list`,
-- what that list does with values (UI/Hub/Folders.lua's Values): `align`, its name and its value apart, the value on
-- its right (b._nameW and b._valueW what each takes, b as wide as its list's column says, b._alignW); `dim`, all of it
-- grey when its value says nothing; `names`, its text alone, without its icon. Returns the width it takes.
function Buttons.Fill(b, obj, h, round, withLabel, list)
    -- a secure button keeps its size and how it's drawn through a fight, the game forbidding to change them
    if b.secure and InCombatLockdown() then
        return b._width or b:GetWidth()
    end
    local iconW = setIcon(b.Icon, obj, Hub.IconSize())
    local hasIcon = iconW ~= nil
    -- on the bar, the look the player chose for it (Hub.SetItemLook): its text alone, its icon alone, or both
    local look = hasIcon and not round and not withLabel and Hub.ItemLook(b.name) or nil
    if look == "text" then
        hasIcon = false
    end
    -- in a list showing texts alone (UI/Hub/Folders.lua's Values): no icon by one that has a text
    if hasIcon and not round and list and list.names then
        local text = textOf(b.name, obj, false, withLabel)
        if text and text ~= "" then
            hasIcon = false
        end
    end
    -- the question mark as it is: a folder's colour is for its white glyphs, or an icon made grey to be tinted
    -- (iconGrey: the zone's PvP state in its colour)
    if b.Icon._missing then
        b.Icon:SetVertexColor(1, 1, 1)
    else
        b.Icon:SetVertexColor(obj.iconR or 1, obj.iconG or 1, obj.iconB or 1)
    end
    b.Icon:SetDesaturated(obj.iconGrey == true and not b.Icon._missing)
    b.textColor = type(obj.textColor) == "table" and obj.textColor or nil
    local c = b.textColor or TEXT
    b.Text:SetTextColor(c[1], c[2], c[3])
    b:EnableMouseWheel(type(obj.OnMouseWheel) == "function")
    -- anchored again only when the way it's drawn changes: a folder's button pressed in keeps its icon's offset
    local mode = round and "round" or hasIcon and "icon" or "text"
    if b._mode ~= mode then
        b._mode = mode
        b.Icon:ClearAllPoints()
        b.Text:ClearAllPoints()
        if round then
            b.Icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.Text:SetPoint("CENTER", b, "CENTER", 0, 0)
        else
            b.Icon:SetPoint("LEFT", b, "LEFT", 0, 0)
            if hasIcon then
                b.Text:SetPoint("LEFT", b.Icon, "RIGHT", 3, 0)
            else
                b.Text:SetPoint("LEFT", b, "LEFT", 0, 0)
            end
        end
    end
    b.Icon:SetShown(hasIcon)
    b._nameW, b._valueW = nil, nil
    if b.Value then
        b.Value:Hide()
    end
    if round then
        local place = Hub.PocketSize()
        b:SetSize(place, place)
        if hasIcon then
            b.Text:SetText("")
            b.Text:Hide()
        else
            local plain = tostring(obj.shortText or obj.text or obj.label or ""):gsub("|c%x%x%x%x%x%x%x%x", "")
            plain = plain:gsub("|r", "")
            b.Text:SetText(plain:sub(1, 3))
            b.Text:Show()
        end
        b._width = place
        return place
    end
    b:SetHeight(h)
    Buttons.SizeText(b.Text)
    local text = textOf(b.name, obj, hasIcon, withLabel)
    if look == "icon" then
        text = nil
    elseif look == "both" and obj.type == "launcher" then
        -- a launcher says nothing by its icon as it comes: its name, asked for
        text = Hub.Label(b.name, obj)
    end
    local name, value
    if list and withLabel then
        name, value = Buttons.Split(obj)
    end
    local apart = list and list.align and name ~= nil
    local empty = list and list.dim and value ~= nil and Buttons.IsEmpty(value)
    if apart then
        text = name
    end
    if empty then
        text = text and plain(text)
        b.Text:SetTextColor(DIM[1], DIM[2], DIM[3])
    end
    b.Text:SetText(text or "")
    b.Text:Show()
    local width = (hasIcon and iconW or 0) + (text and text ~= "" and ((hasIcon and 3 or 0) + b.Text:GetStringWidth()) or 0)
    if apart then
        local v = valueOf(b)
        Buttons.SizeText(v)
        v:SetText(empty and plain(value) or value)
        local vc = empty and DIM or VALUE
        v:SetTextColor(vc[1], vc[2], vc[3])
        v:Show()
        b._nameW, b._valueW = width, v:GetStringWidth()
        width = width + VALUE_GAP + b._valueW
    end
    width = math.max(width, 4)
    b:SetWidth(apart and b._alignW and math.max(b._alignW, width) or width)
    b._width = width
    return width
end

-- Fill, guarded (the review of 2026-11-17): one element whose drawing raises an error, ours or another addon's
-- object, mustn't take the bar's layout with it, as it did (the bar came up with 12 buttons of 111). The error is kept
-- once; for the rest of the session that element shows the question mark in its place, and the others are laid out
-- as ever. What failed once isn't tried again this session: an error each layout would come back with every change.
local failed, STANDIN = {}, {}
function Buttons.SafeFill(b, obj, h, round, withLabel, list)
    if not failed[b.name] then
        local ok, width = ns.SafeCall(Buttons.Fill, b, obj, h, round, withLabel, list)
        if ok then
            return width
        end
        failed[b.name] = true
    end
    STANDIN.icon = QUESTION_MARK_ICON or 134400
    return Buttons.Fill(b, STANDIN, h, round, withLabel)
end

-- Whether an element's drawing failed this session, for the report and the tests.
function Buttons.Failed(name)
    return failed[name] == true
end

-- A separator's button, `w` x `h`: a line one pixel thick along its middle, down it when `vertical`, the shade of the
-- game's own dividers in its menus; its icon hidden. With a `title` (UI/Hub/Separators.lua's Name), a section's
-- head: its title in gold, as the tracker's headers, over a gold rule at its foot.
local LINE, TITLE_LINE = { 1, 1, 1, 0.22 }, { 1, 0.82, 0, 0.3 }
local TITLE_LIFT = 3
-- The width a title takes in `b`'s text.
function Buttons.TitleWidth(b, title)
    Buttons.SizeText(b.Text)
    b.Text:SetText(title)
    return b.Text:GetStringWidth()
end
function Buttons.Separator(b, w, h, vertical, title)
    b.Icon:Hide()
    if not b.Line then
        b.Line = b:CreateTexture(nil, "ARTWORK")
    end
    local c = title and TITLE_LINE or LINE
    b.Line:SetColorTexture(c[1], c[2], c[3], c[4])
    b:SetSize(w, h)
    b.Line:ClearAllPoints()
    b._mode = nil
    if title then
        Buttons.SizeText(b.Text)
        b.Text:ClearAllPoints()
        b.Text:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, TITLE_LIFT)
        b.Text:SetText(title)
        b.Text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        b.Text:Show()
        b.Line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.Line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        PixelUtil.SetHeight(b.Line, 1, 1)
        b.Line:Show()
        b._width = w
        return
    end
    b.Text:Hide()
    if vertical then
        b.Line:SetPoint("TOP", b, "TOP", 0, 0)
        b.Line:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
        PixelUtil.SetWidth(b.Line, 1, 1)
    else
        b.Line:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.Line:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        PixelUtil.SetHeight(b.Line, 1, 1)
    end
    b.Line:Show()
    b._width = w
end

-- ---------- Pressed in ----------

-- A button pressed in, the usual toggle (Ikar 2026-11-14: not gold): a dark well lit from the top left as the plate's
-- recesses, its upper and left walls in shadow, its lower and right lips catching light. An open folder's button sits
-- in one, and the icon picker's current icon.
local WELL, WELL_DEPTH = { 0.02, 0.018, 0.015, 0.6 }, 3
local LIP_LOW, LIP_SIDE = { 0.86, 0.66, 0.37, 0.4 }, { 0.86, 0.66, 0.37, 0.22 }
local WALL_TOP, WALL_SIDE, CLEAR = CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0.4), CreateColor(0, 0, 0, 0)
Buttons.WELL_DEPTH = WELL_DEPTH

-- A well drawn on `owner`'s own layers: its textures, to show and hide together; its walls and lips follow its floor
-- (w.floor), placed by the caller.
function Buttons.Well(owner)
    local w = {}
    local function tex(layer)
        local t = owner:CreateTexture(nil, layer)
        w[#w + 1] = t
        return t
    end
    local floor, top, side, low, right = tex("BACKGROUND"), tex("BORDER"), tex("BORDER"), tex("BORDER"), tex("BORDER")
    floor:SetColorTexture(WELL[1], WELL[2], WELL[3], WELL[4])
    top:SetColorTexture(1, 1, 1, 1)
    top:SetGradient("VERTICAL", CLEAR, WALL_TOP)
    top:SetPoint("TOPLEFT", floor)
    top:SetPoint("TOPRIGHT", floor)
    top:SetHeight(WELL_DEPTH)
    side:SetColorTexture(1, 1, 1, 1)
    side:SetGradient("HORIZONTAL", WALL_SIDE, CLEAR)
    side:SetPoint("TOPLEFT", floor)
    side:SetPoint("BOTTOMLEFT", floor)
    side:SetWidth(WELL_DEPTH)
    low:SetColorTexture(LIP_LOW[1], LIP_LOW[2], LIP_LOW[3], LIP_LOW[4])
    low:SetPoint("BOTTOMLEFT", floor)
    low:SetPoint("BOTTOMRIGHT", floor)
    low:SetHeight(1)
    right:SetColorTexture(LIP_SIDE[1], LIP_SIDE[2], LIP_SIDE[3], LIP_SIDE[4])
    right:SetPoint("TOPRIGHT", floor)
    right:SetPoint("BOTTOMRIGHT", floor)
    right:SetWidth(1)
    w.floor = floor
    return w
end

function Buttons.ShowWell(w, on)
    for _, t in ipairs(w) do
        t:SetShown(on)
    end
end

-- ---------- Handles over Blizzard's widgets and other addons' map buttons ----------

local function clickTarget(name)
    return ns.Natives.ClickTarget(name) or ns.Collect.Frame(name)
end

-- As Blizzard's DropdownButtonProxyMixin: a left press here mustn't close the widget's menu before the click toggles it.
local function handlesGlobalMouseEvent(self, mouseButton, event)
    return event == "GLOBAL_MOUSE_DOWN" and mouseButton == "LeftButton" and ns.Natives.IsDropdown(self.name)
end

local function onHandleClick(self, mouseButton)
    if self._dragged then
        self._dragged = false
        return
    end
    local target = clickTarget(self.name)
    -- a handle shows while the padlock is open alone, the HUD arranged: its right-click the hub menu
    if mouseButton == "RightButton" then
        ns.HubMenus.OpenElement(self, self.name)
    elseif ns.Natives.IsDropdown(self.name) then
        if mouseButton == "LeftButton" and target and target.SetMenuOpen then
            ns.SafeCall(target.SetMenuOpen, target, not target:IsMenuOpen())
        end
    elseif target and target.Click then
        ns.SafeCall(target.Click, target, mouseButton)
    end
    -- what it opened takes its tooltip away, as our buttons' click does (onClick)
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

local function onHandleEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(Hub.Label(self.name), GOLD[1], GOLD[2], GOLD[3])
    ns.HubMenus.AddHints(GameTooltip, self.name)
    GameTooltip:Show()
end

local function onHandleLeave(self)
    if GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end

-- The handles' scripts, guarded as our buttons' (SCRIPTS), whose drag they share.
local HANDLE_SCRIPTS = { OnClick = ns.Guarded(onHandleClick), OnEnter = ns.Guarded(onHandleEnter),
    OnLeave = ns.Guarded(onHandleLeave), OnDragStart = SCRIPTS.OnDragStart, OnDragStop = SCRIPTS.OnDragStop }

local function handle(name)
    local h = handles[name]
    if h then
        return h
    end
    h = CreateFrame("Button", nil, nil)
    h:SetParent(UIParent)
    -- over the folders' lists
    h:SetFrameStrata("DIALOG")
    h:SetSize(26, 26)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:RegisterForDrag("LeftButton")
    h.name = name
    h.Icon = h:CreateTexture(nil, "ARTWORK")
    h.Icon:SetPoint("CENTER")
    h.Highlight = h:CreateTexture(nil, "HIGHLIGHT")
    h.Highlight:SetTexture(ns.DISC)
    h.Highlight:SetAllPoints()
    h.Highlight:SetVertexColor(LIT[1], LIT[2], LIT[3], 0.18)
    h.HandlesGlobalMouseEvent = handlesGlobalMouseEvent
    for script, fn in pairs(HANDLE_SCRIPTS) do
        h:SetScript(script, fn)
    end
    handles[name] = h
    return h
end

-- Wherever a widget or map button is put: its handle there while unlocked, `size` across (none while locked, or for
-- ux nil). shown: the widget shows; else its `atlas` on the handle (the question mark if the game lacks it), for it to
-- be dragged all the same.
function Buttons.PlaceHandle(name, ux, uy, size, shown, atlas)
    if not ux or Hub.IsLocked() then
        if handles[name] then
            handles[name]:Hide()
        end
        return
    end
    local h = handle(name)
    if ns.HubDrag.Current() ~= name then
        h:SetFrameStrata("DIALOG")
        h:ClearAllPoints()
        h:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux, uy)
    end
    h:SetSize(size or 26, size or 26)
    if atlas and not shown then
        Buttons.FitIcon(h.Icon, atlas, Hub.IconSize())
        h.Icon:Show()
    else
        h.Icon:Hide()
    end
    h:Show()
end
