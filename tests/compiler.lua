-- Run from the project root with lua5.1 tests/compiler.lua.
local studio = {}
for _, name in ipairs({ "Draft", "MacroText", "MacroSyntax", "Compiler", "Simulator" }) do
    assert(loadfile("ForeverMacroStudio/Domain/" .. name .. ".lua"))("ForeverMacroStudio", studio)
end
local Compiler = studio.Compiler

local function has(result, code, line, branch, group)
    for _, item in ipairs(result.diagnostics) do
        if item.code == code and item.line == line and item.branch == branch and item.group == group then
            return item.severity
        end
    end
end

local function group(unit, ...)
    return { unit = unit, predicates = { ... } }
end

local function spell(id, ...)
    return { groups = { ... }, argument = { kind = "spell", id = id, token = "Dřívější název" } }
end

local function structured(...)
    return { mode = "structured", lines = { ... } }
end

local names = { [1] = "Léčení", [2] = "Power Word: Shield", [3] = "Searing Pain (Rank 2)" }
local function spellName(id) return names[id] end

local single = Compiler.Compile(structured(
    { directive = "#showtooltip", branches = {} },
    { command = "/cast", branches = { spell(1) } }
), spellName)
assert(single.text == "#showtooltip\n/cast Léčení" and single.canCopy)
assert(single.characters == 25 and single.bytes == 28)

local cast = { command = "/cast", branches = {
    spell(1, group("mouseover", "help", "nodead"), group("target", "help", "nodead"), group("player")),
} }
local use = { command = "/use", branches = {
    { groups = { group(nil, "mod:shift") }, argument = { kind = "item", id = 6948, token = "" } },
    { groups = { group(nil) }, argument = { kind = "slot", token = "13" } },
} }
local body = structured({ directive = "#showtooltip", branches = {} }, cast, use)
local compiled = Compiler.Compile(body, spellName)
assert(compiled.text == "#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Léčení\n"
    .. "/use [mod:shift] item:6948; [] 13")
assert(compiled.canCopy and #compiled.diagnostics == 0)
assert(Compiler.Compile(body, spellName).text == compiled.text)
assert(cast.branches[1].argument.token == "Dřívější název")

local variants = Compiler.Compile(structured(
    { directive = "#showtooltip", branches = { spell(2, group(nil, "mod:alt")), spell(3, group(nil)) } },
    { command = "/cast", branches = { spell(2, group("player", "mod:ctrl")), spell(1, group(nil)) } }
), spellName)
assert(variants.text == "#showtooltip [mod:alt] Power Word: Shield; [] Searing Pain (Rank 2)\n"
    .. "/cast [@player,mod:ctrl] Power Word: Shield; [] Léčení")
assert(variants.canCopy)

local missing = Compiler.Compile(body, function() return nil end)
assert(not missing.canCopy and missing.text == nil and has(missing, "unresolved-spell", 2, 1) == "error")
local injection = Compiler.Compile(body, function() return "Heal; [] Smite" end)
assert(not injection.canCopy and injection.text == nil and has(injection, "invalid-argument", 2, 1))
local injectedLine = Compiler.Compile(body, function() return "Heal\n/run print('bad')" end)
assert(not injectedLine.canCopy and has(injectedLine, "invalid-argument", 2, 1))
local badUnit = Compiler.Compile(structured({ command = "/cast", branches = { spell(1, group("focus")) } }), spellName)
assert(not badUnit.canCopy and has(badUnit, "unsupported-unit", 1, 1, 1))
local badSlot = Compiler.Compile(structured({ command = "/use", branches = {
    { groups = {}, argument = { kind = "slot", token = "20" } },
} }))
assert(not badSlot.canCopy and has(badSlot, "invalid-argument", 1, 1))
assert(not Compiler.Compile({ mode = "structured", lines = { [2] = cast } }, spellName).canCopy)

local text = "#showtooltip\r\n\r\n/cast [@mouseover, help, nodead][@player] Léčení\r/use 13\r\n"
local normalized = "#showtooltip\n\n/cast [@mouseover, help, nodead][@player] Léčení\n/use 13\n"
local raw = Compiler.Compile({ mode = "raw", text = text, sourceLocale = "enUS" })
assert(raw.canCopy and raw.text == normalized and raw.bytes == #normalized)
assert(raw.characters == #normalized - 3)

local invalidCases = {
    { "/run print('no')", "unsupported-command", 1 },
    { "/script Print()", "unsupported-command", 1 },
    { "/click SomeButton", "unsupported-command", 1 },
    { "/castsequence A, B", "unsupported-command", 1 },
    { "#showtooltip\n\n/cast [help Léčení", "invalid-brackets", 3, 1, 1 },
    { "/cast [[help]] Heal", "invalid-brackets", 1, 1, 1 },
    { "/cast Heal]", "invalid-brackets", 1, 1 },
    { "/cast Heal; [@player,] Heal", "invalid-group", 1, 2, 1 },
    { "/cast [@player,@target] Heal", "invalid-group", 1, 1, 1 },
    { "/cast [target=focus] Heal", "unsupported-predicate", 1, 1, 1 },
    { "/cast [mod:foo] Heal", "unsupported-predicate", 1, 1, 1 },
    { "/cast []", "missing-argument", 1, 1 },
    { "/cast Heal;", "missing-argument", 1, 2 },
    { "/cast |cffff0000Heal|r", "invalid-argument", 1, 1 },
    { "/cast item:6948", "invalid-argument", 1, 1 },
    { "/use item:0", "invalid-argument", 1, 1 },
    { "/use 0 1", "invalid-argument", 1, 1 },
    { "/use 20", "invalid-argument", 1, 1 },
    { "/cast He\0al", "control-character", 1 },
    { "/cast He\194\133al", "control-character", 1 },
    { "/cast He\226\128\168al", "control-character", 1 },
    { "/cast Heal\n/use \192\175", "invalid-utf8", 2 },
    { "/use \237\160\128", "invalid-utf8", 1 },
    { "/use \240\159", "invalid-utf8", 1 },
}
for _, example in ipairs(invalidCases) do
    local invalid = Compiler.ValidateText(example[1])
    assert(not invalid.canCopy and invalid.text == example[1])
    assert(has(invalid, example[2], example[3], example[4], example[5]) == "error", example[2])
end
assert(has(Compiler.ValidateText(" \r\n\t"), "empty-macro") == "error")

local shadowed = Compiler.ValidateText("/cast [@target,help] Heal; [@target,help,nodead] Flash Heal")
assert(shadowed.canCopy and has(shadowed, "unreachable-branch", 1, 2) == "warning")
assert(shadowed.diagnostics[1].reason == nil)
local shadowedShift = Compiler.ValidateText("/cast [] Heal; [@player,mod:shift] Heal")
assert(has(shadowedShift, "unreachable-branch", 1, 2))
assert(shadowedShift.diagnostics[1].reason == "shift-after-default")
assert(Compiler.ValidateText("/cast Heal; [mod:shift][@mouseover,harm] Smite").diagnostics[1].reason == "after-default")
assert(has(Compiler.ValidateText("/cast [help][help,nodead] Heal"), "shadowed-group", 1, 1, 2))
assert(has(Compiler.ValidateText("/cast [help][nodead] Heal"), "overlapping-groups", 1, 1, 2))
assert(has(Compiler.ValidateText("/cast [help,harm] Heal; [] Heal"), "contradictory-group", 1, 1, 1))
assert(#Compiler.ValidateText("/cast [@mouseover,help] Heal; [@target,help] Heal").diagnostics == 0)
assert(#Compiler.ValidateText("/cast [harm][help] Heal").diagnostics == 0)

for length = 254, 256 do
    local prefix = "#showtooltip\r\n/cast "
    local ascii = Compiler.ValidateText(prefix .. string.rep("x", length - #prefix + 1))
    assert(ascii.characters == length and ascii.bytes == length and ascii.characterLimit == 255)
    assert(ascii.canCopy == (length <= 255))
    local utf8 = Compiler.ValidateText("/cast " .. string.rep("ř", length - 6))
    assert(utf8.characters == length and utf8.bytes == 6 + 2 * (length - 6))
    assert(utf8.canCopy == (length <= 255))
    assert((has(utf8, "macro-too-long") == "error") == (length > 255))
end
local nonBmp = Compiler.ValidateText("/cast Ž𐐀")
assert(nonBmp.characters == 8 and nonBmp.bytes == 12 and nonBmp.canCopy)

local namedUse = "#showtooltip Hearthstone\n/use [mod:shift] 13; Hearthstone"
local parsed = assert(Compiler.ToStructured({ mode = "raw", text = namedUse, sourceLocale = "enUS" }))
assert(Compiler.Compile(parsed).text == namedUse)
local rejected, reason = Compiler.ToStructured({ mode = "raw", text = "#showtooltip\n\n/cast Unknown", sourceLocale = "enUS" })
assert(not rejected and reason.code == "unresolved-spell" and reason.line == 3 and reason.name == "Unknown")
local scenario = { target = "friendly", mouseover = "deadFriendly", modifiers = { ["mod:shift"] = true } }
local simulation = studio.Simulator.Evaluate("#showtooltip\n\n"
    .. "/cast [@mouseover,help,nodead][@target,help,nodead] Heal\n"
    .. "/use [mod:shift] 13; Hearthstone\n/cast [@mouseover,harm] Smite", scenario)
assert(#simulation == 3 and simulation[1].line == 3 and simulation[1].groupIndex == 2)
assert(simulation[2].value == "13" and simulation[3].value == nil)

print("E03: generation, raw validation, branch diagnostics and UTF-8 length passed")
