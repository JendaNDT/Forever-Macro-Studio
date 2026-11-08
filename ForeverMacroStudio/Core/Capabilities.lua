local _, studio = ...

function studio.ReadClient()
    local version, build, _, interface = GetBuildInfo()
    local locale = GetLocale()
    return {
        version = version,
        build = tostring(build),
        interface = interface,
        locale = locale,
        verified = tostring(build) == "70862" and interface == 16001 and locale == "enUS",
    }
end

local function combatLabel(strings)
    if type(InCombatLockdown) ~= "function" then return strings.combatUnknown end
    local inCombat = InCombatLockdown()
    if issecretvalue and issecretvalue(inCombat) then return strings.combatUnknown end
    if inCombat then return strings.inCombat end
    return strings.outOfCombat
end

function studio.GetStatusLines(strings)
    local client = studio.client
    local library = studio.library
    local draftCount = library.Count()
    local macroRead = client.verified and type(GetNumMacros) == "function" and type(GetMacroInfo) == "function"
    local lines = {
        strings.profile:format(client.version, client.build, client.interface, client.locale),
        client.verified and strings.checkedProfile or strings.unknownProfile,
        macroRead and strings.macroRead or strings.macroReadPending,
        strings.manual,
        combatLabel(strings),
        strings.storedDrafts:format(draftCount),
    }
    if library.issue then
        lines[#lines + 1] = library.issue == "future-schema" and strings.storageFuture or strings.storageInvalid
        lines[#lines + 1] = strings.storageUnavailable
        if draftCount > 0 then lines[#lines + 1] = strings.rescueHint end
    end
    return lines
end
