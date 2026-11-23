-- Typing unfolds the folded chat, in the box of any window docked with it: with the game's chat style « messagerie
-- instantanée » each window types in its own box, and only the first was heard (the review of 2026-11-18; to see in
-- game). A window that stands apart from the chat isn't the chat's.
local F = FakeWoW
CreateFrame("EditBox", "ChatFrame2EditBox", UIParent)
CreateFrame("Frame", "ChatFrame3", UIParent)
CreateFrame("EditBox", "ChatFrame3EditBox", UIParent)
login()
ns.db.options.chatFolded, ns.db.options.foldAnim, ns.db.options.foldSound = true, false, "none"
ns.ApplyAll()
F.RunTimers()
expect(ns.Windows.Progress("ChatFrame1") == 1, "setup: the chat folded")

F.RunScript(ChatFrame2EditBox, "OnEditFocusGained")
F.RunTimers()
expect(ns.Windows.Progress("ChatFrame1") == 0,
    "typing in the box of a window docked with the chat, the folded chat stays folded")
F.RunScript(ChatFrame2EditBox, "OnEditFocusLost")
F.RunTimers()
expect(ns.Windows.Progress("ChatFrame1") == 1, "the typing over in a docked window's box, the chat isn't folded again")

F.RunScript(ChatFrame3EditBox, "OnEditFocusGained")
F.RunTimers()
expect(ns.Windows.Progress("ChatFrame1") == 1, "typing in a window that stands apart from the chat unfolds the chat")
F.RunScript(ChatFrame3EditBox, "OnEditFocusLost")

F.RunScript(ChatFrame1EditBox, "OnEditFocusGained")
F.RunTimers()
expect(ns.Windows.Progress("ChatFrame1") == 0 and errors() == 0, "typing in the chat's own box, the folded chat stays folded: "
    .. select(2, errors()))
