-- Run from the project root with lua5.1 tests/probe.lua.
local output = {}
local realPrint = print
print = function(line) output[#output + 1] = line end

local frame, combat, combatAt, lockChecks, mutations = nil, false, nil, 0, 0
local build, guid, refuse = "70862", "Player-test-a", false
local account = { { "UserMacro", 500, "/cast Existing" } }
local character = {}
local function event(name, ...)
    assert(frame.events[name], name .. " not registered")
    frame.handler(frame, name, ...)
end

function CreateFrame()
    local new = { events = {} }
    function new:SetScript(_, handler) self.handler = handler end
    function new:RegisterEvent(name) self.events[name] = true; return true end
    function new:UnregisterEvent(name) self.events[name] = nil end
    frame = new
    return new
end

SlashCmdList = {}
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 4, MAX_CHARACTER_MACROS = 2 } }
date, time = os.date, os.time
function GetBuildInfo() return "1.60.1", build, "Nov 6 2026", 16001 end
function GetLocale() return "enUS" end
function UnitGUID() return guid end
function InCombatLockdown()
    lockChecks = lockChecks + 1
    return combat or lockChecks == combatAt
end
function GetNumMacros() return #account, #character end
local function locate(index)
    if index > 4 then return character, index - 4 end
    return account, index
end
function GetMacroInfo(index)
    local list, offset = locate(index)
    if list[offset] then return unpack(list[offset]) end
end
function CreateMacro(name, icon, text, perCharacter)
    mutations = mutations + 1
    if refuse then error("simulated rejection") end
    local list = perCharacter and character or account
    list[#list + 1] = { name, icon, text }
    event("UPDATE_MACROS")
    return #list + (perCharacter and 4 or 0)
end
function EditMacro(index, name, icon, text)
    assert(name == nil and icon == nil)
    local list, offset = locate(index)
    assert(list[offset][1]:match("^FMSE00"))
    mutations = mutations + 1
    list[offset][3] = text:sub(1, 255)
    event("UPDATE_MACROS")
    return index
end
function DeleteMacro(index)
    local list, offset = locate(index)
    assert(list[offset][1]:match("^FMSE00"))
    mutations = mutations + 1
    table.remove(list, offset)
    event("UPDATE_MACROS")
end

Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function(index, bank)
        assert(index == 1 and bank == 0)
        return { spellID = 5, name = "Fixture Spell" }
    end,
}
C_Spell = { GetSpellName = function(id) assert(id == 5); return "Fixture Spell" end }
local itemLoaded = false
C_Item = {
    GetItemInfo = function(id) if id == 6948 and itemLoaded then return "Hearthstone" end end,
    RequestLoadItemDataByID = function(id) assert(id == 6948) end,
}

local function boot(reload)
    assert(loadfile("ForeverMacroStudioProbe/Probe.lua"))("ForeverMacroStudioProbe", {})
    event("ADDON_LOADED", "OtherAddon")
    assert(frame.events.ADDON_LOADED)
    event("ADDON_LOADED", "ForeverMacroStudioProbe")
    assert(SLASH_FMS_E00_PROBE1 == "/fmsprobe" and SLASH_FMS_E00_LEGACY1 == "/fms")
    event("PLAYER_ENTERING_WORLD", not reload, reload)
end

local function cmd(suffix)
    SlashCmdList.FMS_E00_LEGACY("probe" .. (suffix and " " .. suffix or ""))
end

local function hasLine(lines, value)
    for _, line in ipairs(lines) do
        if line:find(value, 1, true) then return true end
    end
    return false
end

boot(false)
local accountDB, characterDB = ForeverMacroStudioProbeDB, ForeverMacroStudioProbeCharDB
cmd()
cmd("book")
cmd("item 6948")
event("ITEM_DATA_LOAD_RESULT", 123, true)
itemLoaded = true
event("ITEM_DATA_LOAD_RESULT", 6948, true)
assert(hasLine(output, "Fixture Spell") and hasLine(output, "Hearthstone") and not hasLine(output, "id=123"))
assert(not hasLine(output, guid) and not hasLine(output, "UserMacro"))

cmd("create account extra")
assert(mutations == 0)
combat = true
cmd("create account")
combat = false
combatAt = lockChecks + 2
cmd("create account")
combatAt = nil
assert(mutations == 0)
refuse = true
cmd("create account")
assert(mutations == 1 and not accountDB.fixture and #account == 1)
refuse = false
cmd("create account")
cmd("create account")
assert(mutations == 2 and #account == 2)
assert(hasLine(accountDB.history, "uvnitř=create"))

cmd("create character")
assert(#character == 1 and characterDB.fixture.name == character[1][1])
cmd("edit account utf8")
assert(account[2][3]:find("\n\n", 1, true))
assert(account[2][3]:find("Příliš", 1, true))
cmd("edit account a254")
assert(#account[2][3] == 254)
cmd("edit account a255")
assert(#account[2][3] == 255)
local a255 = account[2][3]
cmd("edit account a256")
assert(#account[2][3] == 255 and account[2][3] ~= a255 and hasLine(output, "oříznutý prefix=true"))
cmd("edit account u256b")
assert(hasLine(output, "požadováno 256 B/135 znaků"))
cmd("edit account u256c")
assert(hasLine(output, "požadováno 499 B/256 znaků"))

cmd("mark reload")
boot(true)
assert(accountDB.starts == 2 and characterDB.starts == 2 and characterDB.marker == "reload")
assert(hasLine(accountDB.history, "reload=true") and hasLine(accountDB.history, "Player GUID=same"))
table.insert(account, 2, { "Other", 11, "/use Existing" })
cmd("edit account base")
assert(account[2][3] == "/use Existing" and account[3][3] == "#showtooltip")
local writes = mutations
table.insert(account, { account[3][1]:lower(), 134400, "#showtooltip" })
cmd("delete account")
assert(mutations == writes and #account == 4)
table.remove(account)
account[3][3] = "externally changed"
cmd("delete account")
assert(mutations == writes and #account == 3)
account[3][3] = "#showtooltip"
build = "99999"
cmd("delete account")
assert(mutations == writes)
build = "70862"
guid = "Player-test-b"
cmd("delete character")
assert(mutations == writes)
guid = "Player-test-a"
cmd("delete character")
cmd("delete account")
assert(#character == 0 and #account == 2 and not accountDB.fixture and not characterDB.fixture)
assert(account[1][3] == "/cast Existing" and account[2][3] == "/use Existing")
cmd("create account")
assert(accountDB.fixture and #account == 3)
table.remove(account)
writes = mutations
cmd("delete account")
assert(not accountDB.fixture and #account == 2 and mutations == writes)
assert(not hasLine(accountDB.history, guid) and not hasLine(accountDB.history, "UserMacro"))

realPrint("E00 probe: PASS (Lua 5.1 mock client)")
