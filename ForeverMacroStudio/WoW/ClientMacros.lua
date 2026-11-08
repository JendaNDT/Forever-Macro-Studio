local _, studio = ...
local ClientMacros = {}
studio.ClientMacros = ClientMacros

local function public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function validCount(value)
    return public(value) and studio.Draft.IsInteger(value)
end

function studio.GetCharacterName()
    if type(UnitFullName) ~= "function" then return nil end
    local ok, name, realm = pcall(UnitFullName, "player")
    if not ok or not public(name) or type(name) ~= "string" or name == "" then return nil end
    if public(realm) and (realm == nil or realm == "") and type(GetNormalizedRealmName) == "function" then
        local realmOK, fallback = pcall(GetNormalizedRealmName)
        if realmOK then realm = fallback end
    end
    if public(realm) and type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
    return name
end

function ClientMacros.List(scope)
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return nil end
    local caps = Constants and Constants.MacroConsts
    if not caps then return nil end
    local accountCap, characterCap = caps.MAX_ACCOUNT_MACROS, caps.MAX_CHARACTER_MACROS
    if not validCount(accountCap) or not validCount(characterCap) or accountCap < 1 or characterCap < 1
        or accountCap + characterCap > 1000 then return nil end

    local ok, account, character = pcall(GetNumMacros)
    if not ok or not validCount(account) or not validCount(character)
        or account > accountCap or character > characterCap then return nil end
    local isCharacter = scope == "character"
    local base = isCharacter and accountCap or 0
    local capacity = isCharacter and characterCap or accountCap
    local expected = isCharacter and character or account
    local entries = {}
    if expected == 0 then return entries end
    for index = base + 1, base + capacity do
        local read, name, icon, body = pcall(GetMacroInfo, index)
        if not read or not public(name) or not public(icon) or not public(body) then return nil end
        if name ~= nil then
            if type(name) ~= "string" or (body ~= nil and type(body) ~= "string") then return nil end
            if not (type(icon) == "string" or studio.Draft.IsInteger(icon) and icon > 0) then icon = nil end
            entries[#entries + 1] = { title = name, icon = icon, text = body or "" }
            if #entries == expected then return entries end
        end
    end
end
