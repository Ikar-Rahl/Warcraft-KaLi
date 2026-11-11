-- KaLi Recipe's part of the bug report (Shared/Report.lua builds it and its window): where reports go, and what only
-- KaLi Recipe tells. Opened from the options page and /kr report. Characters are counted, never named.
local _, ns = ...

local Report = ns.Report

-- Where reports are posted: a new issue on the KaLi family's GitHub repository, as Ikar ruled for KaLi Quest.
Report.URL = "https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new"

function Report.StatusLines()
    return string.format("map %s, screen %d × %d, UI scale %.2f", tostring(C_Map.GetBestMapForUnit("player")), GetScreenWidth(),
        GetScreenHeight(), UIParent:GetEffectiveScale())
end

Report.Sections = {
    { "notebook", function()
        return ns.db and ns.Commands.NotebookText() or Report.NoData()
    end },
    { "saved data", function()
        return ns.Commands.DataText()
    end },
    -- What the player changed: the options hold nothing else (docs/saved-data.md).
    { "options", Report.OptionsText },
}
