-- Motion, as Blizzard's tracker animates: a new quest's row glows in, a finished objective checks off, a completed
-- quest's lines check off and fade before its completion text, a sequenced quest's next step fades in, a quest
-- turned in or removed keeps its place while it fades, and progress glows once. Nothing moves by itself: what's
-- behind a closed header makes that header glow instead. See tracker-parity.md, Motion and Objective lines.
local _, ns = ...

local Motion = {}
ns.Motion = Motion

local GLOW_ATLAS = "ui-questtracker-objfx-barglow"

local seen = {} -- questID -> { objectives = { { finished, count } }, complete }
local lineAnim = {} -- questID -> { [index] = "completing" | "adding" }
local stepsDone = {} -- questID -> { [index] = true }: sequenced steps finished this session, which stay shown
local completingUntil = {} -- questID -> time its finished lines stop showing before the completion text
local fading = {} -- questID -> true once its held lines have started fading
local heldInCombat = {} -- questID -> true: completed in combat, so its lines stay until the fight ends
local added = {} -- questID -> true: accepted, waiting for its row or a closed header to glow
local progressed = {} -- questID -> true: an objective moved, waiting for the same
local leaving = {} -- questID -> { quest, groupID, index, lines, kind, started }
local rescan = false -- the next scan only takes note: the tracker was off, so Blizzard's showed what changed

local LEAVE = { turnin = 0.66, remove = 1.0 }

local function now()
    return GetTime()
end

-- One short glow over a bar or group header, when something changes behind it while it's closed.
function Motion.AddFlash(frame, art)
    local glow = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    glow:SetAtlas(GLOW_ATLAS, false)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    if art then
        glow:SetAllPoints(art)
    else
        glow:SetPoint("TOPLEFT", -6, 3)
        glow:SetPoint("BOTTOMRIGHT", 6, -3)
    end
    frame.FlashGlow = glow
    local group = frame:CreateAnimationGroup()
    local up = group:CreateAnimation("Alpha")
    up:SetTarget(glow)
    up:SetFromAlpha(0)
    up:SetToAlpha(0.7)
    up:SetDuration(0.3)
    up:SetOrder(1)
    local down = group:CreateAnimation("Alpha")
    down:SetTarget(glow)
    down:SetFromAlpha(0.7)
    down:SetToAlpha(0)
    down:SetDuration(0.6)
    down:SetOrder(2)
    frame.Flash = group
    local fade = frame:CreateAnimationGroup()
    local fadeIn = fade:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)
    frame.FadeIn = fade
end

function Motion.Flash(frame)
    if frame and frame.Flash then
        frame.Flash:Stop()
        frame.Flash:Play()
    end
end

function Motion.FlashRow(row)
    if row and row.AreaFlash and not row.HeadSweep:IsPlaying() then
        row.AreaFlash:Stop()
        row.AreaFlash:Play()
    end
end

local function sweep(group, target, delay, duration, fadeDelay, fadeDuration)
    local scale = group:CreateAnimation("Scale")
    scale:SetTarget(target)
    scale:SetOrigin("LEFT", 0, 0)
    scale:SetScaleFrom(0.01, 1)
    scale:SetScaleTo(1, 1)
    scale:SetStartDelay(delay)
    scale:SetDuration(duration)
    local show = group:CreateAnimation("Alpha")
    show:SetTarget(target)
    show:SetFromAlpha(1)
    show:SetToAlpha(1)
    show:SetDuration(fadeDelay)
    local out = group:CreateAnimation("Alpha")
    out:SetTarget(target)
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetStartDelay(fadeDelay)
    out:SetDuration(fadeDuration)
end

-- A row's glows: the sweep across its title when it arrives or is turned in, the gold glow behind it on progress,
-- and its fades.
function Motion.AddRow(row)
    local head = row:CreateTexture(nil, "OVERLAY")
    head:SetAtlas(GLOW_ATLAS, false)
    head:SetBlendMode("ADD")
    head:SetSize(240, 20)
    head:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 3)
    head:SetAlpha(0)
    row.HeadGlow = head
    row.HeadSweep = row:CreateAnimationGroup()
    sweep(row.HeadSweep, head, 0.15, 0.31, 0.33, 0.41)
    -- Coming into the quest's area: the same glow over the title, up and down once, as a closed header's flash.
    row.AreaFlash = row:CreateAnimationGroup()
    local rise = row.AreaFlash:CreateAnimation("Alpha")
    rise:SetTarget(head)
    rise:SetFromAlpha(0)
    rise:SetToAlpha(0.7)
    rise:SetDuration(0.3)
    rise:SetOrder(1)
    local fall = row.AreaFlash:CreateAnimation("Alpha")
    fall:SetTarget(head)
    fall:SetFromAlpha(0.7)
    fall:SetToAlpha(0)
    fall:SetDuration(0.6)
    fall:SetOrder(2)

    local gold = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    gold:SetColorTexture(1, 0.824, 0, 1)
    gold:SetAllPoints(row.Bg)
    gold:SetAlpha(0)
    row.ProgressGlow = row:CreateAnimationGroup()
    local up = row.ProgressGlow:CreateAnimation("Alpha")
    up:SetTarget(gold)
    up:SetFromAlpha(0)
    up:SetToAlpha(0.2)
    up:SetDuration(0.18)
    up:SetOrder(1)
    local down = row.ProgressGlow:CreateAnimation("Alpha")
    down:SetTarget(gold)
    down:SetFromAlpha(0.2)
    down:SetToAlpha(0)
    down:SetDuration(0.52)
    down:SetOrder(2)

    row.FadeIn = row:CreateAnimationGroup()
    local fadeIn = row.FadeIn:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)

    row.FadeOut = row:CreateAnimationGroup()
    row.FadeOut:SetToFinalAlpha(true)
    local fadeOut = row.FadeOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    row.FadeOutAlpha = fadeOut
end

-- An objective line's check pop, its glow, and the sweep across it, as ObjectiveTrackerAnimLineTemplate's.
function Motion.AddLine(row, l)
    l.CheckGlow = row:CreateTexture(nil, "OVERLAY")
    l.CheckGlow:SetAtlas("ui-questtracker-tracker-check-glow", false)
    l.CheckGlow:SetSize(16, 16)
    l.CheckGlow:SetBlendMode("ADD")
    l.CheckGlow:SetAlpha(0)
    l.CheckGlow:SetPoint("CENTER", l.Check, "CENTER")
    l.Glow = row:CreateTexture(nil, "OVERLAY")
    l.Glow:SetAtlas(GLOW_ATLAS, false)
    l.Glow:SetBlendMode("ADD")
    l.Glow:SetSize(180, 22)
    l.Glow:SetPoint("LEFT", l.Text, "LEFT", -2, 0)
    l.Glow:SetAlpha(0)

    l.Complete = row:CreateAnimationGroup()
    for _, s in ipairs({ { 1, 1.2, 0.15, 0 }, { 1.2, 1, 0.15, 0.15 } }) do
        local pop = l.Complete:CreateAnimation("Scale")
        pop:SetTarget(l.Check)
        pop:SetScaleFrom(s[1], s[1])
        pop:SetScaleTo(s[2], s[2])
        pop:SetDuration(s[3])
        pop:SetStartDelay(s[4])
        local glowPop = l.Complete:CreateAnimation("Scale")
        glowPop:SetTarget(l.CheckGlow)
        glowPop:SetScaleFrom(s[1], s[1])
        glowPop:SetScaleTo(s[2], s[2])
        glowPop:SetDuration(s[3])
        glowPop:SetStartDelay(s[4])
    end
    local checkIn = l.Complete:CreateAnimation("Alpha")
    checkIn:SetTarget(l.Check)
    checkIn:SetFromAlpha(0)
    checkIn:SetToAlpha(1)
    checkIn:SetDuration(0.16)
    local glowIn = l.Complete:CreateAnimation("Alpha")
    glowIn:SetTarget(l.CheckGlow)
    glowIn:SetFromAlpha(0)
    glowIn:SetToAlpha(1)
    glowIn:SetDuration(0.15)
    local glowOut = l.Complete:CreateAnimation("Alpha")
    glowOut:SetTarget(l.CheckGlow)
    glowOut:SetFromAlpha(1)
    glowOut:SetToAlpha(0)
    glowOut:SetStartDelay(0.15)
    glowOut:SetDuration(0.15)
    sweep(l.Complete, l.Glow, 0.1, 0.66, 0.33, 0.58)

    l.Add = row:CreateAnimationGroup()
    for _, target in ipairs({ l.Text, l.Dash }) do
        local fade = l.Add:CreateAnimation("Alpha")
        fade:SetTarget(target)
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.5)
    end
    sweep(l.Add, l.Glow, 0.1, 0.66, 0.33, 0.58)

    l.Fade = row:CreateAnimationGroup()
    l.Fade:SetToFinalAlpha(true)
    for _, target in ipairs({ l.Text, l.Dash, l.Check }) do
        local fade = l.Fade:CreateAnimation("Alpha")
        fade:SetTarget(target)
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetStartDelay(1)
        fade:SetDuration(0.1)
    end
end

-- What changed since the last layout --------------------------------------------------------------------------

local function readObjectives(q)
    local list = {}
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(q.id)
    for i, o in ipairs(objectives or {}) do
        list[i] = { finished = o.finished == true, count = o.numFulfilled or 0 }
    end
    return list
end

-- Called at each layout with the log as read. inCombat: a quest completing now keeps its lines until the fight ends.
-- Returns the quests whose objectives moved since the last layout.
function Motion.Scan(quests, inCombat)
    local t = now()
    local moved = {}
    for id, q in pairs(quests) do
        local list = readObjectives(q)
        local prev = not rescan and seen[id]
        if prev then
            local anims = lineAnim[id] or {}
            for i, o in ipairs(list) do
                local before = prev.objectives[i]
                if not before then
                    anims[i] = "adding"
                    progressed[id] = true
                    moved[id] = true
                elseif o.finished and not before.finished then
                    anims[i] = "completing"
                    stepsDone[id] = stepsDone[id] or {}
                    stepsDone[id][i] = true
                    progressed[id] = true
                    moved[id] = true
                elseif o.count ~= before.count then
                    progressed[id] = true
                    moved[id] = true
                end
            end
            if next(anims) then
                lineAnim[id] = anims
            end
            if q.complete and not prev.complete then
                progressed[id] = true
                if inCombat then
                    heldInCombat[id] = true
                else
                    completingUntil[id] = t + 1.1
                    C_Timer.After(1.15, ns.RequestRefresh)
                end
            end
        end
        seen[id] = { objectives = list, complete = q.complete == true }
    end
    for id in pairs(seen) do
        if not quests[id] then
            seen[id], lineAnim[id], stepsDone[id], completingUntil[id], heldInCombat[id], progressed[id] = nil, nil, nil, nil, nil, nil
            fading[id] = nil
        end
    end
    rescan = false
    return moved
end

-- The tracker coming back on: quests that left meanwhile don't fade again, and progress made meanwhile doesn't glow.
function Motion.Reset()
    rescan = true
    for _, t in ipairs({ lineAnim, completingUntil, fading, heldInCombat, added, progressed, leaving }) do
        wipe(t)
    end
end

function Motion.CombatEnded()
    wipe(heldInCombat)
end

-- A completed quest still showing its objectives, checked, while they finish animating or until combat ends.
function Motion.HoldsLines(q)
    if not q.complete then
        return false
    end
    if heldInCombat[q.id] then
        return true
    end
    local untilT = completingUntil[q.id]
    if untilT and untilT > now() then
        return true
    end
    completingUntil[q.id] = nil
    fading[q.id] = nil
    return false
end

-- True once per completion, so its held lines fade out a second after checking off.
function Motion.StartFade(id)
    if completingUntil[id] and not fading[id] then
        fading[id] = true
        return true
    end
    return false
end

-- A sequenced quest shows a finished step only if it finished this session, as Blizzard's keeps lines it drew.
function Motion.ShowsFinishedStep(q, index, sequenced)
    if not sequenced then
        return true
    end
    return stepsDone[q.id] ~= nil and stepsDone[q.id][index] == true
end

-- Plays a line's animation once, when its row is drawn.
function Motion.PlayLine(id, index, l, watched)
    local state = lineAnim[id] and lineAnim[id][index]
    if not state then
        return
    end
    lineAnim[id][index] = nil
    if state == "completing" and l.Complete then
        l.Complete:Stop()
        l.Complete:Play()
    elseif state == "adding" and l.Add then
        l.Add:Stop()
        l.Add:Play()
        -- Blizzard's hidden tracker already plays it for quests on the game's list.
        if not watched and PlaySound and SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 then
            PlaySound(SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01)
        end
    end
end

function Motion.FadeLines(l)
    if l.Fade then
        l.Fade:Stop()
        l.Fade:Play()
    end
end

-- Row events ------------------------------------------------------------------------------------------------

function Motion.Accepted(id)
    added[id] = true
end

-- Plays a drawn row's own glows and fades, once each. progressGlow: the option.
function Motion.PlayRow(row, id, progressGlow)
    if added[id] then
        added[id] = nil
        progressed[id] = nil
        row.FadeIn:Stop()
        row.FadeIn:Play()
        row.HeadSweep:Stop()
        row.HeadSweep:Play()
    elseif progressed[id] then
        progressed[id] = nil
        if progressGlow then
            row.ProgressGlow:Stop()
            row.ProgressGlow:Play()
        end
    end
end

-- After a layout: what changed behind closed headers makes the nearest drawn header glow. headerOf(id) gives the
-- frame of the closest drawn header above the quest, or nil if none is drawn.
function Motion.FlashHidden(headerOf, progressGlow)
    local flashed = {}
    for id in pairs(added) do
        local frame = headerOf(id)
        if frame and not flashed[frame] then
            flashed[frame] = true
            Motion.Flash(frame)
        end
        added[id] = nil
        progressed[id] = nil
    end
    for id in pairs(progressed) do
        local frame = progressGlow and headerOf(id)
        if frame and not flashed[frame] then
            flashed[frame] = true
            Motion.Flash(frame)
        end
        progressed[id] = nil
    end
end

-- Leaving rows ----------------------------------------------------------------------------------------------

-- snapshot: { quest, groupID, index, lines } from the last layout, or nil if the quest wasn't drawn or known.
function Motion.Leave(id, kind, snapshot)
    local l = leaving[id]
    if l then
        if kind == "turnin" then
            l.kind = "turnin"
        end
        return
    end
    if not snapshot then
        return
    end
    snapshot.kind = kind
    leaving[id] = snapshot
end

function Motion.Leaving()
    return leaving
end

-- A row leaving where it is, as Blizzard's TurnInAnim: the glow sweeps its title if sweep, it fades over the second
-- half of duration, then done runs and the tracker redraws without it.
function Motion.FadeOut(row, duration, sweep, done)
    if sweep then
        row.HeadSweep:Stop()
        row.HeadSweep:Play()
    end
    row.FadeOutAlpha:SetStartDelay(duration / 2)
    row.FadeOutAlpha:SetDuration(duration / 2)
    row.FadeOut:Stop()
    row.FadeOut:Play()
    C_Timer.After(duration, function()
        done()
        ns.RequestRefresh()
    end)
end

-- Plays a leaving row's fade once, then lets it go.
function Motion.PlayLeave(row, id)
    local l = leaving[id]
    if not l or l.started then
        return
    end
    l.started = true
    Motion.FadeOut(row, LEAVE[l.kind] or 1, l.kind == "turnin", function()
        leaving[id] = nil
    end)
end

-- A leaving quest no longer drawn anywhere goes at once.
function Motion.DropUndrawn(drawn)
    for id, l in pairs(leaving) do
        if not l.started and not drawn[id] then
            leaving[id] = nil
        end
    end
end
