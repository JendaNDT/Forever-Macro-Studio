-- Run from the project root with lua5.1 tests/storage.lua.
local studio = {}
local addon = "ForeverMacroStudio"
local timestamp = 100
local frame, lines, rescue
local emit = print

function GetBuildInfo() return "1.60.1", "70862", "Nov 6 2026", 16001 end
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
function time() return timestamp end
function print(line) lines[#lines + 1] = line end
function CreateFrame()
    frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(event, handler) self[event] = handler end
    return frame
end
C_AddOns = { GetAddOnMetadata = function() return "0.2.0" end }

local function start(saved)
    ForeverMacroStudioDB = saved
    SlashCmdList, lines, rescue, studio = {}, {}, nil, {}
    for file in io.lines(addon .. "/" .. addon .. ".toc") do
        if file:match("%.lua$") then
            assert(loadfile(addon .. "/" .. file))(addon, studio)
        end
    end
    studio.ShowRescue = function(_, text) rescue = text end
    frame:OnEvent("ADDON_LOADED", addon)
    assert(SLASH_FOREVER_MACRO_STUDIO1 == "/fms")
    return studio.library, ForeverMacroStudioDB, SlashCmdList.FOREVER_MACRO_STUDIO
end

local library, database, fms = start()
assert(database.schemaVersion == 2 and library.Count() == 0)
fms("debug")
assert(table.concat(lines, "\n"):find("Drafts in library: 0", 1, true))
fms("debug compiler")
assert(lines[#lines - 1] == "#showtooltip" and lines[#lines] == "/use [mod:shift] 13; [] 14")

local old = { schemaVersion = 1, preferences = { language = "csCZ" } }
library, database, fms = start(old)
assert(database ~= old and old.schemaVersion == 1 and old.drafts == nil)
assert(database.schemaVersion == 2 and database.preferences ~= old.preferences)
assert(library.preferences.language == "csCZ" and not library.issue)

local raw = {
    title = 'Léčení "test"',
    tags = { "podpora" },
    kind = "macro",
    icon = 134400,
    body = { mode = "raw", text = "#showtooltip\n\n/cast Příliš žluťoučký kůň | test", sourceLocale = "enUS" },
}
local created = assert(library.Save(raw))
assert(created.id == "draft-1" and created.revision == 1 and created.updatedAt == 100)
raw.tags[1], created.body.text = "změněno mimo knihovnu", "změněno mimo knihovnu"
assert(library.Get(created.id).tags[1] == "podpora")
assert(library.Get(created.id).body.text:find("žluťoučký", 1, true))

local structured = {
    title = "Mouseover",
    tags = {},
    kind = "template",
    body = { mode = "structured", lines = {
        { directive = "#showtooltip", branches = {} },
        { command = "/cast", branches = {
            {
                groups = { { unit = "mouseover", predicates = { "help", "nodead" } } },
                argument = { kind = "spell", id = 1234, token = "Heal" },
            },
        } },
    } },
}
local second = assert(library.Save(structured))
assert(second.id == "draft-2" and library.Count() == 2)
structured.body.lines[2].branches[1].groups[1].predicates[2] = "changed"
assert(library.Get(second.id).body.lines[2].branches[1].groups[1].predicates[2] == "nodead")

local edited, stale = library.Get(created.id), library.Get(created.id)
timestamp = 200
edited.title = "Nový název"
local revised = assert(library.Save(edited))
assert(revised.id == created.id and revised.revision == 2 and revised.updatedAt == 200)
local saved, errorCode = library.Save(stale)
assert(saved == nil and errorCode == "stale-revision" and library.Get(created.id).title == "Nový název")
local invalid = library.Get(second.id)
invalid.body.lines[2].branches[1].groups[1].predicates = { [2] = "nodead" }
saved, errorCode = library.Save(invalid)
assert(saved == nil and errorCode == "invalid-draft" and library.Get(second.id).revision == 1)

library, database, fms = start(database)
assert(library.Get(created.id).revision == 2 and library.Count() == 2)
assert(library.List()[2].body.lines[2].branches[1].argument.id == 1234)
fms("debug")
assert(table.concat(lines, "\n"):find("Návrhy v knihovně: 2", 1, true))

local corrupt = { schemaVersion = 2, preferences = { language = "csCZ" }, drafts = {
    ["draft-1"] = library.Get("draft-1"), ["draft-2"] = { id = "draft-2" },
}, nextDraftId = 3 }
library, database, fms = start(corrupt)
assert(database == corrupt and library.issue == "invalid-storage" and library.Count() == 1)
assert(library.Get("draft-2") == nil)
saved, errorCode = library.Save(raw)
assert(saved == nil and errorCode == "read-only" and corrupt.nextDraftId == 3)
library.preferences.language = "enUS"
assert(corrupt.preferences.language == "csCZ")
fms("rescue")
assert(rescue and not rescue:find("|", 1, true))
local recovered = assert(loadstring(rescue))()
assert(recovered.schemaVersion == 2 and recovered.drafts["draft-1"].body.text == corrupt.drafts["draft-1"].body.text)
assert(recovered.drafts["draft-2"] == nil and recovered.preferences == nil)

corrupt.schemaVersion = 3
library, database = start(corrupt)
assert(database == corrupt and database.schemaVersion == 3 and library.issue == "future-schema")
assert(library.RescueText())
library, database = start("not a table")
assert(database == "not a table" and library.issue == "invalid-storage" and library.RescueText() == nil)
emit("E02: TOC startup, schema migration, draft revisions, reload, and read-only recovery passed")
