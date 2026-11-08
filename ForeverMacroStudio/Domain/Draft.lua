local _, studio = ...
local Draft = {}
studio.Draft = Draft

function Draft.IsInteger(value)
    return type(value) == "number" and value >= 0 and value <= 9007199254740991 and value == math.floor(value)
end

local function copyArray(source, copyItem)
    if type(source) ~= "table" then return nil end
    local result, count = {}, 0
    local length = #source
    for index, value in pairs(source) do
        if not Draft.IsInteger(index) or index < 1 or index > length then return nil end
        local item = copyItem(value)
        if item == nil then return nil end
        result[index] = item
        count = count + 1
    end
    if count == length then return result end
end

local function copyString(value)
    if type(value) == "string" then return value end
end

local function copyGroup(group)
    if type(group) ~= "table" or (group.unit ~= nil and type(group.unit) ~= "string") then return nil end
    local predicates = copyArray(group.predicates, copyString)
    if predicates then return { unit = group.unit, predicates = predicates } end
end

local function copyBranch(branch)
    if type(branch) ~= "table" then return nil end
    local groups = copyArray(branch.groups, copyGroup)
    local argument = branch.argument
    if not groups or type(argument) ~= "table"
        or type(argument.kind) ~= "string" or type(argument.token) ~= "string" then
        return nil
    end
    if argument.id ~= nil and (not Draft.IsInteger(argument.id) or argument.id == 0) then return nil end
    return { groups = groups, argument = { kind = argument.kind, id = argument.id, token = argument.token } }
end

local function copyLine(line)
    if type(line) ~= "table" then return nil end
    if line.directive ~= nil then
        if type(line.directive) ~= "string" or line.command ~= nil then return nil end
    elseif type(line.command) ~= "string" then
        return nil
    end
    local branches = copyArray(line.branches, copyBranch)
    if branches then return { command = line.command, directive = line.directive, branches = branches } end
end

function Draft.CopyBody(body)
    if type(body) ~= "table" then return nil end
    if body.mode == "raw" and type(body.text) == "string" and type(body.sourceLocale) == "string" then
        local backup
        if body.structuredBackup ~= nil then
            if type(body.structuredBackup) ~= "table" or body.structuredBackup.mode ~= "structured" then return nil end
            backup = Draft.CopyBody(body.structuredBackup)
            if not backup then return nil end
        end
        return { mode = "raw", text = body.text, sourceLocale = body.sourceLocale, structuredBackup = backup }
    end
    if body.mode == "structured" then
        local lines = copyArray(body.lines, copyLine)
        if lines then return { mode = "structured", lines = lines } end
    end
end

function Draft.CopyContent(draft)
    if type(draft) ~= "table" or type(draft.title) ~= "string" then return nil end
    local icon = draft.icon
    if icon ~= nil and type(icon) ~= "string" and (not Draft.IsInteger(icon) or icon == 0) then return nil end
    local kind = draft.kind
    if kind ~= "macro" and kind ~= "template" then return nil end

    local tags = copyArray(draft.tags, copyString)
    local body = Draft.CopyBody(draft.body)
    if tags and body then
        return { title = draft.title, tags = tags, icon = icon, kind = kind, body = body }
    end
end

function Draft.Copy(draft)
    local result = Draft.CopyContent(draft)
    if not result or type(draft.id) ~= "string" or draft.id == ""
        or not Draft.IsInteger(draft.revision) or draft.revision < 1 or not Draft.IsInteger(draft.updatedAt) then
        return nil
    end
    result.id, result.revision, result.updatedAt = draft.id, draft.revision, draft.updatedAt
    return result
end
