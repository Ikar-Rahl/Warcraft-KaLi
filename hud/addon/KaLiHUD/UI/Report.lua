-- KaLi HUD's part of the bug report (Shared/Report.lua builds it and its window): where reports go, and what only
-- KaLi HUD tells. Opened with /kh report. Characters are counted, never named.
local _, ns = ...

local Report = ns.Report

-- Where reports are posted: a new issue on the KaLi family's GitHub repository.
Report.URL = "https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new"
-- KaLi's mailbox, filing each mail as an issue (tools/mail).
Report.MAIL = "warcraft.kali.addons@gmail.com"

function Report.StatusLines()
    return string.format("screen %d x %d, UI scale %.2f", GetScreenWidth(), GetScreenHeight(), UIParent:GetEffectiveScale())
end

Report.Sections = {
    -- what the stat cards couldn't account for, with what they read (UI/Hub/Infos/StatCheck.lua; Ikar 2026-11-22:
    -- "add that to the error report")
    { "stat cards", function()
        return ns.StatCheck and ns.StatCheck.Text() or "(not loaded)"
    end },
    { "plate", function()
        return ns.db and ns.Plate.Text() or Report.NoData()
    end },
    { "info bar", function()
        return ns.db and (ns.Hub.Text() .. "\ncharacters with gold noted: " .. ns.Count(ns.db.gold)) or Report.NoData()
    end },
    { "options", Report.OptionsText },
}
