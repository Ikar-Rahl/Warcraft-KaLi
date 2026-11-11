-- KaLi Quest's part of the bug report (Shared/Report.lua builds it and its window): where reports go, and what only
-- KaLi Quest tells. Opened from the gear's menu, the options page, the diagnostics panel and /kq report.
local _, ns = ...

local Report = ns.Report

-- Where reports are posted: a new issue on the KaLi family's GitHub repository.
Report.URL = "https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new"

function Report.StatusLines()
    local _, classFile = UnitClass("player")
    return table.concat({
        string.format("character: %s, level %s, %s · map %s, %s", tostring(classFile), tostring(UnitLevel("player")),
            tostring(UnitFactionGroup("player")), tostring(C_Map.GetBestMapForUnit("player")), tostring(GetZoneText())),
        string.format("screen %d × %d, UI scale %.2f", GetScreenWidth(), GetScreenHeight(), UIParent:GetEffectiveScale()),
    }, "\n")
end

Report.Sections = {
    { "diagnostics", function()
        return table.concat(ns.DebugPanel.Lines(), "\n")
    end },
    { "options", Report.OptionsText },
    { "groups", function()
        return ns.db and ns.Commands.GroupsText() or Report.NoData()
    end },
    { "tree", function()
        return ns.db and ns.Commands.TreeText() or Report.NoData()
    end },
}
