local _, studio = ...
local Text = studio.MacroText
local Syntax = {}
studio.MacroSyntax = Syntax

local commands = { ["/cast"] = true, ["/use"] = true, ["#showtooltip"] = true }
local units = { player = true, target = true, mouseover = true }
local predicates = {
    help = true, harm = true, exists = true, nodead = true,
    ["mod:shift"] = true, ["mod:ctrl"] = true, ["mod:alt"] = true,
}
local defaultGroup = { predicates = {} }
local defaultGroups = { defaultGroup }

function Syntax.AddDiagnostic(diagnostics, severity, code, line, branch, group)
    diagnostics[#diagnostics + 1] = {
        severity = severity, code = code, line = line, branch = branch, group = group,
    }
end

function Syntax.CheckCommand(command)
    if not commands[command] then return "unsupported-command" end
end

function Syntax.CheckGroup(group)
    if group.unit and not units[group.unit] then return "unsupported-unit" end
    for _, predicate in ipairs(group.predicates) do
        if not predicates[predicate] then return "unsupported-predicate" end
    end
end

function Syntax.IsName(value)
    return value:find("[A-Za-z\128-\255]") and not value:find("[^A-Za-z0-9\128-\255 '%-:%.%(%)]")
        and not value:lower():match("^spell:")
end

local function isPositiveId(value)
    return value and studio.Draft.IsInteger(value) and value > 0
end

function Syntax.CheckArgument(command, value)
    if value == "" then return "missing-argument" end
    if value:find("[%[%]]") then return "invalid-brackets" end
    local itemId = value:match("^item:(%d+)$")
    if value:lower():match("^item:") then
        if command == "/cast" or not isPositiveId(tonumber(itemId)) then return "invalid-argument" end
    elseif value:match("^%d+$") then
        local slot = tonumber(value)
        if command == "/cast" or slot < 1 or slot > 19 then return "invalid-argument" end
    elseif not Syntax.IsName(value) then
        return "invalid-argument"
    end
end

local function parseGroup(content)
    local group = { predicates = {} }
    if Text.Trim(content) == "" then return group end
    for entry in (content .. ","):gmatch("(.-),") do
        local token = Text.Trim(entry)
        if token == "" then return nil, "invalid-group" end
        if token:sub(1, 1) == "@" then
            if group.unit then return nil, "invalid-group" end
            group.unit = token:sub(2)
        else
            group.predicates[#group.predicates + 1] = token
        end
    end
    return group, Syntax.CheckGroup(group)
end

function Syntax.ParseLine(text)
    local command, arguments = text:match("^(%S+)[ \t]*(.*)$")
    local branches = {}
    local commandError = Syntax.CheckCommand(command)
    if commandError then return nil, commandError end
    if arguments == "" and command == "#showtooltip" then return { command = command, branches = branches } end

    for entry in (arguments .. ";"):gmatch("(.-);") do
        local value = Text.Trim(entry)
        local groups, cursor = {}, 1
        local branchIndex = #branches + 1
        while value:sub(cursor, cursor) == "[" do
            local _, last, content = value:find("^%[([^%[%]]*)%][ \t]*", cursor)
            if not last then return nil, "invalid-brackets", branchIndex, #groups + 1 end
            local group, groupError = parseGroup(content)
            if groupError then return nil, groupError, branchIndex, #groups + 1 end
            groups[#groups + 1] = group
            cursor = last + 1
        end
        local argument = value:sub(cursor)
        local argumentError = Syntax.CheckArgument(command, argument)
        if argumentError then return nil, argumentError, branchIndex end
        branches[branchIndex] = { groups = groups, value = argument }
    end
    return { command = command, branches = branches }
end

local function asRule(group)
    local required = {}
    for _, condition in ipairs(group.predicates) do required[condition] = true end
    return { unit = group.unit or "target", required = required }
end

local function conflicts(first, second)
    return (first.help and second.harm) or (first.harm and second.help)
end

local function covers(previous, current)
    if next(previous.required) == nil then return true end
    if previous.unit ~= current.unit then return false end
    for condition in pairs(previous.required) do
        if not current.required[condition] then return false end
    end
    return true
end

function Syntax.AnalyzeBranches(branches, diagnostics, line)
    local earlier = {}
    for branchIndex, branch in ipairs(branches) do
        local groups = branch.groups
        local current, canMatch, reached = {}, false, false
        local hasGroups = #groups > 0
        for groupIndex, group in ipairs(hasGroups and groups or defaultGroups) do
            local rule = asRule(group)
            if conflicts(rule.required, rule.required) then
                Syntax.AddDiagnostic(diagnostics, "warning", "contradictory-group", line, branchIndex, groupIndex)
            else
                canMatch = true
                local covered = false
                for _, previous in ipairs(earlier) do
                    if covers(previous, rule) then covered = true break end
                end
                if not covered then reached = true end

                for _, previous in ipairs(current) do
                    if covers(previous, rule) then
                        Syntax.AddDiagnostic(diagnostics, "warning", "shadowed-group", line, branchIndex, groupIndex)
                        break
                    end
                    if next(rule.required) and previous.unit == rule.unit and not conflicts(previous.required, rule.required) then
                        Syntax.AddDiagnostic(diagnostics, "warning", "overlapping-groups", line, branchIndex, groupIndex)
                        break
                    end
                end
                current[#current + 1] = rule
            end
        end
        if canMatch and not reached then
            Syntax.AddDiagnostic(diagnostics, "warning", "unreachable-branch", line, branchIndex)
        end
        for _, rule in ipairs(current) do earlier[#earlier + 1] = rule end
    end
end
