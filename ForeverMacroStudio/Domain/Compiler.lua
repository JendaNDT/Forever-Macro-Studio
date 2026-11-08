local _, studio = ...
local Text, Syntax = studio.MacroText, studio.MacroSyntax
local Compiler = { manualCharacterLimit = 255 }
studio.Compiler = Compiler

local function addError(diagnostics, code, line, branch, group)
    Syntax.AddDiagnostic(diagnostics, "error", code, line, branch, group)
end

local function result(text, diagnostics, characters)
    local canCopy = text ~= nil
    for _, item in ipairs(diagnostics) do
        if item.severity == "error" then canCopy = false break end
    end
    return {
        text = text,
        bytes = text and #text,
        characters = characters,
        characterLimit = Compiler.manualCharacterLimit,
        diagnostics = diagnostics,
        canCopy = canCopy,
    }
end

function Compiler.ValidateText(input)
    local diagnostics = {}
    if type(input) ~= "string" then
        addError(diagnostics, "invalid-text")
        return result(nil, diagnostics)
    end

    local text = Text.Normalize(input)
    local characters, invalidByte = Text.CountCharacters(text)
    if not characters then
        local _, newlines = text:sub(1, invalidByte - 1):gsub("\n", "")
        addError(diagnostics, "invalid-utf8", newlines + 1)
        return result(text, diagnostics)
    end
    if not text:find("[^ \t\n]") then
        addError(diagnostics, "empty-macro")
        return result(text, diagnostics, characters)
    end

    local withinLimit = characters <= Compiler.manualCharacterLimit
    if not withinLimit then addError(diagnostics, "macro-too-long") end
    local line = 0
    for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line + 1
        local trimmed = Text.Trim(rawLine)
        if Text.HasControls(trimmed) then
            addError(diagnostics, "control-character", line)
        elseif trimmed ~= "" then
            local parsed, code, branch, group = Syntax.ParseLine(trimmed)
            if code then
                addError(diagnostics, code, line, branch, group)
            elseif withinLimit then
                Syntax.AnalyzeBranches(parsed.branches, diagnostics, line)
            end
        end
    end
    return result(text, diagnostics, characters)
end

local function resolveArgument(command, argument, resolveSpellName)
    if argument.kind == "spell" and command ~= "/use" then
        local name = argument.id and type(resolveSpellName) == "function" and resolveSpellName(argument.id)
        if type(name) ~= "string" or name == "" then return nil, "unresolved-spell" end
        if Text.Trim(name) ~= name or not Syntax.IsName(name) or name:lower():match("^item:")
            or not Text.CountCharacters(name) or Text.HasControls(name) then
            return nil, "invalid-argument"
        end
        return name
    end
    if argument.kind == "item" and command ~= "/cast" and argument.id then
        return ("item:%.0f"):format(argument.id)
    end
    if argument.kind == "slot" and command ~= "/cast" and argument.token:match("^%d+$") then
        local slot = tonumber(argument.token)
        if slot >= 1 and slot <= 19 then return ("%d"):format(slot) end
    end
    return nil, "invalid-argument"
end

local function renderGroup(group)
    local tokens = {}
    if group.unit then tokens[1] = "@" .. group.unit end
    for _, predicate in ipairs(group.predicates) do tokens[#tokens + 1] = predicate end
    return "[" .. table.concat(tokens, ",") .. "]"
end

local function renderBranch(groups, value)
    local tokens = {}
    for index, group in ipairs(groups) do tokens[index] = renderGroup(group) end
    return #tokens > 0 and (table.concat(tokens) .. " " .. value) or value
end

local function renderLine(line, resolveSpellName)
    local command = line.command or line.directive
    local code = Syntax.CheckCommand(command)
    if code then return nil, code end
    if #line.branches == 0 then
        if command == "#showtooltip" then return command end
        return nil, "missing-argument"
    end

    local branches = {}
    for branchIndex, branch in ipairs(line.branches) do
        for groupIndex, group in ipairs(branch.groups) do
            code = Syntax.CheckGroup(group)
            if code then return nil, code, branchIndex, groupIndex end
        end
        local value
        value, code = resolveArgument(command, branch.argument, resolveSpellName)
        if not value then return nil, code, branchIndex end
        branches[branchIndex] = renderBranch(branch.groups, value)
    end
    return command .. " " .. table.concat(branches, "; ")
end

local function identifyArgument(command, value, findSpellId)
    local item = tonumber((value:match("^item:(%d+)$")))
    if item then return { kind = "item", id = item, token = value } end
    if value:match("^%d+$") then return { kind = "slot", token = value } end
    local spell = command ~= "/use" and type(findSpellId) == "function" and findSpellId(value)
    if spell then return { kind = "spell", id = spell, token = value } end
end

function Compiler.ToStructured(body, findSpellId, resolveSpellName)
    if type(body) ~= "table" or body.mode ~= "raw" then return nil end
    local checked = Compiler.ValidateText(body.text)
    for _, diagnostic in ipairs(checked.diagnostics) do
        if diagnostic.severity == "error" and diagnostic.code ~= "macro-too-long" then return nil end
    end
    local backup = body.structuredBackup
    if backup and Compiler.Compile(backup, resolveSpellName).text == checked.text then
        return studio.Draft.CopyBody(backup)
    end

    local structured, canonical = { mode = "structured", lines = {} }, {}
    for rawLine in (checked.text .. "\n"):gmatch("([^\n]*)\n") do
        local text = Text.Trim(rawLine)
        if text ~= "" then
            local parsed = Syntax.ParseLine(text)
            local command = parsed.command
            local line = { branches = {} }
            if command == "#showtooltip" then line.directive = command else line.command = command end
            local branches = {}
            for index, branch in ipairs(parsed.branches) do
                local argument = identifyArgument(command, branch.value, findSpellId)
                if not argument then return nil end
                line.branches[index] = { groups = branch.groups, argument = argument }
                branches[index] = renderBranch(branch.groups, branch.value)
            end
            structured.lines[#structured.lines + 1] = line
            canonical[#canonical + 1] = #branches == 0 and command or command .. " " .. table.concat(branches, "; ")
        end
    end
    if Compiler.Compile(structured, resolveSpellName).text == table.concat(canonical, "\n") then return structured end
end

function Compiler.Compile(body, resolveSpellName)
    local snapshot = studio.Draft.CopyBody(body)
    if snapshot and snapshot.mode == "raw" then return Compiler.ValidateText(snapshot.text) end

    local diagnostics, lines = {}, {}
    if not snapshot then
        addError(diagnostics, "invalid-body")
        return result(nil, diagnostics)
    end
    for line, source in ipairs(snapshot.lines) do
        local rendered, code, branch, group = renderLine(source, resolveSpellName)
        if code then
            addError(diagnostics, code, line, branch, group)
        else
            lines[#lines + 1] = rendered
        end
    end
    if #diagnostics > 0 then return result(nil, diagnostics) end
    return Compiler.ValidateText(table.concat(lines, "\n"))
end
