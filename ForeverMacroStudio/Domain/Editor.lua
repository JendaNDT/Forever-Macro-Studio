local _, studio = ...
local Draft = studio.Draft
local Editor = {}
studio.Editor = Editor
local startingGroups = {
    self = { { unit = "player", predicates = {} } },
    mouseover = {
        { unit = "mouseover", predicates = { "help", "nodead" } },
        { unit = "target", predicates = { "help", "nodead" } },
        { unit = "player", predicates = {} },
    },
    shift = { { predicates = { "mod:shift" } } },
    hostile = {
        { unit = "mouseover", predicates = { "harm", "nodead" } },
        { unit = "target", predicates = { "harm", "nodead" } },
    },
}

local function copy(draft)
    local snapshot = Draft.CopyContent(draft)
    snapshot.id, snapshot.revision = draft.id, draft.revision
    return snapshot
end

local function newDraft(raw, locale, starter)
    local body = raw and { mode = "raw", text = "", sourceLocale = locale }
        or { mode = "structured", lines = {
            { directive = "#showtooltip", branches = {} },
            { command = "/cast", branches = { Editor.NewBranch("spell") } },
        } }
    if not raw and starter then
        local line = body.lines[2]
        local branch = line.branches[1]
        branch.groups = startingGroups[starter.pattern] or branch.groups
        if starter.action then Editor.SelectAction(line, branch, starter.action) end
        if starter.shiftAction and starter.action and starter.shiftAction.kind == starter.action.kind then
            local alternate = Editor.NewBranch(starter.shiftAction.kind)
            alternate.groups = startingGroups.shift
            if Editor.SelectAction(line, alternate, starter.shiftAction) then
                table.insert(line.branches, 1, alternate)
            end
        end
        body = Draft.CopyBody(body)
    end
    return { title = starter and starter.title or "", kind = "macro", tags = {}, body = body }
end

function Editor.NewBranch(kind)
    return { groups = {}, argument = { kind = kind, token = "" } }
end

function Editor.Open(draft, raw, locale, starter)
    local history = { draft and copy(draft) or newDraft(raw, locale, starter) }
    local index, saved = 1, history[1]
    local id, revision
    if draft then
        id, revision = draft.id, draft.revision
        if not id then saved = nil end
    end
    local mergeKey
    local editor = {}

    function editor.Get() return history[index] end
    function editor.IsDirty() return history[index] ~= saved end

    function editor.Change(update, key)
        local snapshot = copy(history[index])
        update(snapshot)
        for i = #history, index + 1, -1 do history[i] = nil end
        if key and mergeKey == key and history[index] ~= saved then
            history[index] = snapshot
        else
            index = index + 1
            history[index] = snapshot
            if index > 40 then
                table.remove(history, 1)
                index = index - 1
            end
        end
        mergeKey = key
    end

    function editor.EndEdit() mergeKey = nil end
    function editor.CanUndo() return index > 1 end
    function editor.CanRedo() return index < #history end

    function editor.Undo()
        if editor.CanUndo() then index = index - 1 end
        mergeKey = nil
    end

    function editor.Redo()
        if editor.CanRedo() then index = index + 1 end
        mergeKey = nil
    end

    function editor.Save(library)
        local snapshot = copy(history[index])
        snapshot.id, snapshot.revision = id, revision
        local draft, errorCode = library.Save(snapshot)
        if not draft then return nil, errorCode end
        id, revision = draft.id, draft.revision
        saved = history[index]
        mergeKey = nil
        return draft
    end

    return editor
end

function Editor.SelectAction(line, branch, entry)
    local command = entry.kind == "spell" and "/cast" or "/use"
    if line.command and line.command ~= command and #line.branches > 1 then return false end
    if line.command then line.command = command end
    branch.argument = { kind = entry.kind, id = entry.id, token = entry.token or entry.name }
    return true
end

function Editor.Group(branch, index)
    if not branch.groups[index] then branch.groups[index] = { predicates = {} } end
    return branch.groups[index]
end
