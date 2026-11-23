local _, ns = ...
local OWN = ns.STRINGS

-- Mexican Spanish: Castilian's strings, except where the game's own Mexican words differ (Marcador de mapa, Audio).
OWN.esMX = setmetatable({
    PLACE_WAYPOINT = "Poner un marcador de mapa",
    WAYPOINT_SET = "Marcador colocado: %s.",
    WAYPOINT_REFUSED = "El mapa no acepta un marcador en ese lugar.",
    OPT_SOUND_VOLUME_TIP = "Los dos sonidos, respecto a su volumen habitual en el juego: al 100 %, suenan como en el juego; por encima, más fuerte. Los volúmenes «Volumen general» y «Efectos» de las opciones de Audio del juego también se aplican.",
}, { __index = OWN.esES })

-- Mexico writes a decimal with a point, as the game's Mexican Spanish (DECIMAL_SEPERATOR): each of Castilian's texts
-- with a figure such as « 0,04 % » gets its Mexican copy, « 0.04 % » (found by the stats session, 2026-11-21).
for key, value in pairs(OWN.esES) do
    if type(value) == "string" and rawget(OWN.esMX, key) == nil and value:find("%d,%d") then
        OWN.esMX[key] = (value:gsub("(%d),(%d)", "%1.%2"))
    end
end

-- Castilian's typography for its own words (the RAE): a no-break space between a figure and %.
local NBSP = ns.NBSP
ns.Typeset(OWN.esMX, function(s)
    return (s:gsub("(%d) %%", "%1" .. NBSP .. "%%"):gsub("(%%[%-%d%.]*[A-Za-z]) %%%%", "%1" .. NBSP .. "%%%%"))
end)
