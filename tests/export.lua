-- Run: lua5.1 tests/export.lua
local studio = { client = { verified = true } }
studio.Compiler = { Compile = function(body)
    return { canCopy = body.valid ~= false, text = body.text, characters = #(body.text or "") }
end }
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 4, MAX_CHARACTER_MACROS = 2 } }
local account = { { "Existing", 1, "/cast Existing" } }
local character = {}
local combat = false
function InCombatLockdown() return combat end
function GetNumMacros() return #account, #character end
function GetMacroInfo(i)
    local entry = i > 4 and character[i - 4] or account[i]
    if entry then return unpack(entry) end
end
local Export = assert(loadfile("ForeverMacroStudio/WoW/MacroExport.lua"))("ForeverMacroStudio", studio)
local draft = { title = "NewMacro", body = { text = "/cast Test" } }
local function reject(expected, d, scope)
    local value, err = Export.Prepare(d or draft, scope or "account")
    assert(value == nil and err == expected, tostring(err) .. " ~= " .. expected)
end
local result = assert(Export.Prepare(draft, "account"))
assert(result.readOnly and result.bytes == 10 and result.count == 1)
assert(#account == 1)
reject("invalid-scope", draft, "other")
reject("name-conflict", { title = "existing", body = draft.body })
reject("invalid-body", { title = "New", body = { text = "/cast Test", valid = false } })
reject("invalid-name", { title = "12345678901234567", body = draft.body })
combat = true
reject("combat-unknown-or-active")
combat = false
studio.client.verified = false
reject("unverified-client")
studio.client.verified = true
account[2], account[3], account[4] = { "A", 1, "x" }, { "B", 1, "x" }, { "C", 1, "x" }
reject("full")
assert(#account == 4)
print("E06 export preparation: PASS (read-only mock)")
