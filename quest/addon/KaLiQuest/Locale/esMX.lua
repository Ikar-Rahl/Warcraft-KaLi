local _, ns = ...
local OWN = ns.STRINGS

-- Mexican Spanish: Castilian's strings, except where the game's own Mexican words differ (Calabozos, Modo de
-- edición, Disposición, Llamamiento).
OWN.esMX = setmetatable({
    INSTANCES = "Calabozos y bandas",
    FILTER_V_CALLING = "Llamamiento",
    OPTION_MARKERS_TIP = "Lo que muestran los marcadores de una misión tras su título: calabozo, diaria, grupo y el resto.",
    OPTION_EDIT_MODE_TIP = "El tamaño del rastreador, su lugar, sus opacidades, su apariencia y sus marcadores se ajustan en el modo de edición: un clic en el rastreador abre allí su ventana. Este botón cierra las opciones y abre el modo de edición, con el rastreador ya elegido.",
    EDIT_REVERT_TIP = "Devuelve los ajustes y el lugar a como estaban al entrar en el modo de edición, o en su último guardado.",
    EDIT_RESET_POSITION_TIP = "Devuelve el rastreador al lugar del de Blizzard, en esta disposición.",
    DIAG_STATE = "Combate: %s · bloqueo: %s · modo de edición: %s",
    DIAG_PLACE = "Lugar en modo de edición: %s (disposición %s)",
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
