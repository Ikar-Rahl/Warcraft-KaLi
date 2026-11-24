local _, ns = ...
local OWN = ns.STRINGS
local LEFT_CLICK, RIGHT_CLICK = ns.LEFT_CLICK, ns.RIGHT_CLICK

-- Mexican Spanish: Castilian's strings, except where the game's own Mexican words differ (Modo de edición, Costo,
-- Barra de posturas, Marcador de mapa) and for numbers, written there as in English.
OWN.esMX = setmetatable({
    THOUSANDS = ",",
    THOUSANDS_FROM = "4",
    DECIMAL = ".",
    REPAIR_COST = "Costo de la reparación",
    STAT_CAMP_PART = "Hoguera: %s",
    STAT_MANA_CLASS_TIP = "El maná base de la clase en el nivel 1, según la tabla de Forever. La raza no da maná propio, solo por su intelecto.",
    OPT_MARGIN_BARS_TIP = "Margen de la placa alrededor de todas las barras de acción, de posturas, de mascota y de tótems. En lo más ajustado, su borde las toca sin montarse nunca sobre ellas.",
    FOLDER_SOUND_waypoint = "Marcador de mapa",
    STATUS_PUT_BACK_TIP = "En el modo de edición, arrastra la barra para dejarla en otro sitio: la placa la toma si está a su alcance. Recolocar la devuelve junto a la barra de información, contra el anillo del minimapa.",
    EDIT_REVERT_TIP = "Devuelve los ajustes a como estaban al entrar en el modo de edición.",
    EDIT_SECTION_REVERT_TIP = "Devuelve los ajustes de esta sección a como estaban al entrar en el modo de edición.",
    OPTION_EDIT_MODE_TIP = "Abre el modo de edición directamente en la ventana de ajustes de KaLi HUD.",
    HELP = {
        "La placa toma las barras, el chat, el medidor de daño y el minimapa allí donde están: colócalos y ajusta KaLi HUD en el modo de edición (/kh edit).",
        RIGHT_CLICK .. " en la barra de información: los elementos que muestra; " .. RIGHT_CLICK .. " en un elemento: sus ajustes y adónde va (el de otro addon, con el candado abierto); " .. RIGHT_CLICK .. " en una barra de progreso: lo que muestra.",
        "/kh: opciones · /kh edit: modo de edición · /kh status: estado del addon",
        "/kh report: informar de un error · /kh errors: los errores · /kh stats: guardar las tarjetas de estadísticas para el informe",
        "/kh export: compartir tus ajustes · /kh import: importar un texto compartido",
    },
}, { __index = OWN.esES })

-- The folder icons' names: Castilian's, but for the game's own Mexican words (Abismos, Calabozos, Objetivos de bonific.).
OWN.esMX.ICON_NAMES = setmetatable({
    ["DungeonSkull"] = "Calavera de calabozo",
    ["delves-bountiful"] = "Abismo abundante",
    ["Bonus-Objective-Star"] = "Objetivo de bonificación",
    ["poi-scrapper"] = "Trituradora",
}, { __index = OWN.esES.ICON_NAMES })

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
