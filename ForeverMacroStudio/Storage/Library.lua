local _, studio = ...
local Draft = studio.Draft
local schemaVersion = 3
local validLanguage = { auto = true, csCZ = true, enUS = true }

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function validPreferences(preferences)
    return type(preferences) == "table" and (preferences.language == nil or validLanguage[preferences.language] == true)
end

local function draftId(number)
    return ("draft-%.0f"):format(number)
end

local function validateRoot(root)
    if not validPreferences(root.preferences) or type(root.drafts) ~= "table"
        or not Draft.IsInteger(root.nextDraftId) or root.nextDraftId < 1 then
        return false
    end
    for id, draft in pairs(root.drafts) do
        local serial = type(id) == "string" and tonumber(id:match("^draft%-(%d+)$"))
        if not Draft.IsInteger(serial) or serial < 1 or id ~= draftId(serial) or serial >= root.nextDraftId
            or not Draft.Copy(draft) or draft.id ~= id then
            return false
        end
    end
    return true
end

local function prepare(saved)
    if saved == nil then
        return { schemaVersion = schemaVersion, preferences = { language = "auto" }, drafts = {}, nextDraftId = 1 }
    end
    if type(saved) ~= "table" then return nil, "invalid-storage" end
    if Draft.IsInteger(saved.schemaVersion) and saved.schemaVersion > schemaVersion then
        return nil, "future-schema"
    end

    local root = saved
    if saved.schemaVersion == 1 and validPreferences(saved.preferences)
        and saved.drafts == nil and saved.nextDraftId == nil then
        root = copyTable(saved)
        root.preferences = copyTable(saved.preferences)
        root.schemaVersion, root.drafts, root.nextDraftId = schemaVersion, {}, 1
    end
    if saved.schemaVersion == 2 and validateRoot(saved) then
        root = copyTable(saved)
        root.preferences = copyTable(saved.preferences)
        root.drafts = copyTable(saved.drafts)
        root.schemaVersion = schemaVersion
    end
    if root.schemaVersion == schemaVersion and validateRoot(root) then return root end
    return nil, "invalid-storage"
end

local function recoverDrafts(saved)
    local readable = {}
    if type(saved) ~= "table" or type(saved.drafts) ~= "table" then return readable end
    for id, stored in pairs(saved.drafts) do
        local draft = Draft.Copy(stored)
        if draft and draft.id == id then readable[id] = draft end
    end
    return readable
end

-- Only the known draft fields enter the export. Keys are sorted for stable output.
local function serialize(value, indent)
    if type(value) == "string" then
        local escaped = ("%q"):format(value):gsub("|", "\\124")
        return escaped
    end
    if type(value) == "number" then return ("%.0f"):format(value) end
    if type(value) == "boolean" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    local lines = { "{" }
    for _, key in ipairs(keys) do
        lines[#lines + 1] = indent .. "  [" .. serialize(key, "") .. "] = " .. serialize(value[key], indent .. "  ") .. ","
    end
    lines[#lines + 1] = indent .. "}"
    return table.concat(lines, "\n")
end

function studio.OpenLibrary(saved, now)
    local root, issue = prepare(saved)
    local drafts = root and root.drafts or recoverDrafts(saved)
    local preferences = root and root.preferences
    if not preferences then
        local original = type(saved) == "table" and saved.preferences
        local language = validPreferences(original) and original.language or "auto"
        preferences = { language = language }
    end
    local library = { issue = issue, preferences = preferences }

    function library.Count()
        local count = 0
        for _ in pairs(drafts) do count = count + 1 end
        return count
    end

    function library.Get(id)
        if type(id) == "string" then return Draft.Copy(drafts[id]) end
    end

    function library.List()
        local result = {}
        for _, draft in pairs(drafts) do result[#result + 1] = Draft.Copy(draft) end
        table.sort(result, function(left, right)
            if left.updatedAt ~= right.updatedAt then return left.updatedAt > right.updatedAt end
            return left.id < right.id
        end)
        return result
    end

    function library.Save(input)
        if issue then return nil, "read-only" end
        local draft = Draft.CopyContent(input)
        if not draft then return nil, "invalid-draft" end
        draft.updatedAt = now()
        if not Draft.IsInteger(draft.updatedAt) then return nil, "invalid-time" end

        if input.id == nil then
            if input.revision ~= nil then return nil, "invalid-draft" end
            if not Draft.IsInteger(root.nextDraftId + 1) then return nil, "id-limit" end
            draft.id, draft.revision = draftId(root.nextDraftId), 1
            root.nextDraftId = root.nextDraftId + 1
        else
            local current = type(input.id) == "string" and drafts[input.id]
            if not current then return nil, "not-found" end
            if input.revision ~= current.revision then return nil, "stale-revision" end
            if not Draft.IsInteger(current.revision + 1) then return nil, "revision-limit" end
            draft.id, draft.revision = current.id, current.revision + 1
        end
        drafts[draft.id] = draft
        return Draft.Copy(draft)
    end

    function library.RescueText()
        if not issue or next(drafts) == nil then return nil end
        return "return " .. serialize({ schemaVersion = schemaVersion, drafts = drafts }, "")
    end

    return library, root
end
