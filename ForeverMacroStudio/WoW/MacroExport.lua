local _, studio = ...
local Export = {}
studio.MacroExport = Export

-- E06 preparation. No write API is called by this module.
local function safe(value)
    return not issecretvalue or not issecretvalue(value)
end

local function integer(value)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and safe(value)
end

local function snapshot(scope)
    if scope ~= "account" and scope ~= "character" then return nil, "invalid-scope" end
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return nil, "missing-api" end
    local constants = Constants and Constants.MacroConsts
    if not constants then return nil, "missing-capacity" end
    local a, c = constants.MAX_ACCOUNT_MACROS, constants.MAX_CHARACTER_MACROS
    if not integer(a) or not integer(c) or a < 1 or c < 1 or a + c > 1000 then return nil, "invalid-capacity" end
    local ok, na, nc = pcall(GetNumMacros)
    if not ok or not integer(na) or not integer(nc) or na > a or nc > c then return nil, "invalid-count" end
    local base, capacity, count = 0, a, na
    if scope == "character" then base, capacity, count = a, c, nc end
    local entries = {}
    for i = base + 1, base + capacity do
        local read, name, icon, body = pcall(GetMacroInfo, i)
        if not read or not safe(name) or not safe(icon) or not safe(body) then return nil, "unreadable-slot" end
        if name ~= nil then
            if type(name) ~= "string" or type(body) ~= "string" then return nil, "invalid-slot" end
            entries[#entries + 1] = { index = i, name = name, body = body }
        end
    end
    if #entries ~= count then return nil, "inconsistent-count" end
    return { count = count, capacity = capacity, entries = entries }
end

function Export.Prepare(draft, scope, spellName)
    if not studio.client or not studio.client.verified then return nil, "unverified-client" end
    if not draft or type(draft) ~= "table" or type(draft.title) ~= "string" then return nil, "invalid-draft" end
    if not safe(draft.title) or draft.title == "" or #draft.title > 16
        or draft.title:find("[%c]") then return nil, "invalid-name" end
    local compileOK, compiled = pcall(studio.Compiler.Compile, draft.body, spellName)
    if not compileOK or type(compiled) ~= "table" or compiled.canCopy ~= true
        or type(compiled.text) ~= "string" or #compiled.text > 255
        or not safe(compiled.text) then return nil, "invalid-body" end
    local combatOK, inCombat = pcall(InCombatLockdown or function() return nil end)
    if not combatOK or not safe(inCombat) or inCombat ~= false then return nil, "combat-unknown-or-active" end
    local state, err = snapshot(scope)
    if not state then return nil, err end
    if state.count >= state.capacity then return nil, "full" end
    for _, item in ipairs(state.entries) do
        if item.name:lower() == draft.title:lower() then return nil, "name-conflict" end
    end
    return {
        scope = scope, name = draft.title, text = compiled.text,
        bytes = #compiled.text, characters = compiled.characters,
        count = state.count, capacity = state.capacity,
        -- An opaque preview, NOT permission to mutate.
        readOnly = true,
    }
end

-- Second step rechecks all inputs and the live slot snapshot. Still read-only.
function Export.ConfirmPreview(preview, draft, scope, spellName)
    if type(preview) ~= "table" or preview.readOnly ~= true then return nil, "invalid-preview" end
    local current, err = Export.Prepare(draft, scope, spellName)
    if not current then return nil, err end
    if preview.scope ~= current.scope or preview.name ~= current.name
        or preview.text ~= current.text or preview.count ~= current.count
        or preview.capacity ~= current.capacity then return nil, "stale-preview" end
    return {
        scope = current.scope, name = current.name, text = current.text,
        bytes = current.bytes, count = current.count, capacity = current.capacity,
        readOnly = true, confirmed = true,
    }
end

return Export
