-- A set of settings as a text, and a text read back (Core/Sets.lua; Ikar 2026-11-19: "let's do a proper export and
-- import"): there and back whole; what isn't such a text, one that is cut and one a newer version wrote told apart;
-- wrong values in a text dropped as the file's own are; kept as a set, it changes nothing until applied.
local F = FakeWoW
login()
local Sets, o = ns.Sets, ns.db.options
o.reach, o.borderColor = 55, "112233"
local folder = ns.Folders.Create("Essai")
F.RunTimers()
local text = Sets.Export(Sets.Capture())
expect(type(text) == "string" and text:find("^KaLiHUD:1:") ~= nil and not text:find("%s"),
    "a set isn't written as one line of text under its head: " .. tostring(text):sub(1, 40))
local read, version = Sets.Read(text)
expect(read and read.options.reach == 55 and read.options.borderColor == "112233" and read.folders[folder] ~= nil
    and read.folders[folder].name == "Essai" and version == ns.VERSION,
    "a set's text isn't read back as the settings it was written from, with the version that wrote it")
-- pasted with the line breaks and spaces a chat or a mail put in it
local broken = text:sub(1, 30) .. "\n  " .. text:sub(31, 60) .. " \r\n" .. text:sub(61)
expect(Sets.Read(broken) ~= nil, "a set's text with line breaks and spaces in it isn't read")
-- what isn't one, one cut short, one from a newer version
local none, why = Sets.Read("Bonjour, voici mon interface")
local cut, short = Sets.Read(text:sub(1, #text - 7))
local newer, later = Sets.Read("KaLiHUD:2:" .. text:match(":1:(.+)$"))
expect(none == nil and why == "not" and cut == nil and short == "cut" and newer == nil and later == "newer"
    and Sets.Read(nil) == nil and Sets.Read("KaLiHUD:1:") == nil,
    "a text that isn't a set's, one cut short and one from a newer version aren't told apart: " .. tostring(why) .. ", "
    .. tostring(short) .. ", " .. tostring(later))
-- wrong values in a text: dropped, as the file's own
local odd = Sets.Read(Sets.Export({ options = { reach = "wide", bridge = 80, borderColor = "red" }, folders = { [3] = "x" } }))
expect(odd and odd.options.reach == nil and odd.options.bridge == 80 and odd.options.borderColor == nil
    and next(odd.folders) == nil, "a text's wrong values aren't dropped as it is read")
-- kept as a set: nothing changes until it is applied
o.reach = 60
local kept = Sets.Save("De Kael", read)
expect(kept and kept.settings == read and o.reach == 60 and #Sets.List() == 1,
    "a text kept as a set changes the settings before it is applied, or isn't kept")
Sets.Apply(kept.settings)
F.RunTimers()
expect(o.reach == 55, "a set from a text isn't applied as another")
expect(errors() == 0, "a set as a text errs: " .. select(2, errors()))
