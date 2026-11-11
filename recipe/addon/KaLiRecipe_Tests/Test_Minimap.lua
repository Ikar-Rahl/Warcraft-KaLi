local T = KaLiRecipeTests
local ns = KaLiRecipeDev.ns
local B = ns.MinimapButton

local function near(a, b)
    return math.abs(a - b) < 0.001
end

T.Add("Minimap", "the button goes round the minimap's edge, round or square", function()
    -- A minimap 198 across: the button's centre 5 past its edge, 104 from its centre.
    local x, y = B.Offset(0, 198, 198, "ROUND")
    T.True(near(x, 104) and near(y, 0), "round, right: " .. x .. ", " .. y)
    x, y = B.Offset(90, 198, 198, "ROUND")
    T.True(near(x, 0) and near(y, 104), "round, top")
    x, y = B.Offset(225, 198, 198, "ROUND")
    T.True(near(x, -104 * math.sqrt(0.5)) and near(y, -104 * math.sqrt(0.5)), "round, bottom left: on the circle")
    -- Square: along the side, not on a circle inside it.
    x, y = B.Offset(30, 198, 198, "SQUARE")
    T.True(near(x, 104) and y > 52 and y < 104, "square, 30°: on the right side: " .. x .. ", " .. y)
    x, y = B.Offset(45, 198, 198, "SQUARE")
    T.True(x > 104 * math.sqrt(0.5) + 1 and y > 104 * math.sqrt(0.5) + 1, "square, 45°: towards the corner")
    -- A corner shape is round only in its own quarter; an unknown shape is taken as round.
    x, y = B.Offset(45, 198, 198, "CORNER-TOPRIGHT")
    T.True(near(x, 104 * math.sqrt(0.5)) and near(y, 104 * math.sqrt(0.5)), "the top right corner, round")
    x, y = B.Offset(135, 198, 198, "CORNER-TOPRIGHT")
    T.True(x < -104 * math.sqrt(0.5) - 1 and y > 104 * math.sqrt(0.5) + 1, "the top left, square")
    x, y = B.Offset(45, 198, 198, "SOMETHING-NEW")
    T.True(near(x, 104 * math.sqrt(0.5)), "an unknown shape: round")
end)
