local addonName = ...
local frame = CreateFrame("Frame")
local baseBody = "#showtooltip"
local fixtureIcon = 134400
local editedBodies = {
    utf8 = baseBody .. "\n\n" .. baseBody .. " Příliš žluťoučký kůň",
    a254 = baseBody .. " " .. string.rep("x", 241),
    a255 = baseBody .. " " .. string.rep("y", 242),
    a256 = baseBody .. " " .. string.rep("z", 243),
    u256b = baseBody .. " " .. string.rep("ž", 121) .. "x",
    u256c = baseBody .. " " .. string.rep("ř", 243),
    base = baseBody,
}
local watchedEvents = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UPDATE_MACROS", "SPELLS_CHANGED", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}
local accountDB, characterDB
local eventState = {}
local operation, pendingItem

local function isPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function show(value)
    if not isPublic(value) then return "restricted" end
    local kind = type(value)
    if kind == "number" or kind == "string" or kind == "boolean" or kind == "nil" then
        return tostring(value)
    end
    return kind
end

local function say(message)
    print("FMS E00: " .. message)
end

local function record(message, quiet)
    local history = accountDB.history
    if #history >= 200 then table.remove(history, 1) end
    history[#history + 1] = date("%Y-%m-%d %H:%M:%S") .. " " .. message
    if not quiet then say(message) end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function lockdown()
    local ok, value = call(InCombatLockdown)
    if not ok or not isPublic(value) then return "unknown" end
    if value == nil or value == false then return "out" end
    if value == true then return "combat" end
    return "unknown"
end

local function caps()
    local const = Constants and Constants.MacroConsts
    if const then return const.MAX_ACCOUNT_MACROS, const.MAX_CHARACTER_MACROS end
end

local function validCount(value)
    return isPublic(value) and type(value) == "number" and value >= 0 and value == math.floor(value)
end

local function readSlot(index)
    local ok, name, icon, body = call(GetMacroInfo, index)
    if not ok or not isPublic(name) or not isPublic(icon) or not isPublic(body) then
        return false
    end
    if name == nil then return true end
    if type(name) ~= "string" or (body ~= nil and type(body) ~= "string") then return false end
    return true, { index = index, name = name, icon = icon, body = body or "" }
end

local function scan()
    local maxAccount, maxCharacter = caps()
    local ok, countAccount, countCharacter = call(GetNumMacros)
    if not ok or not validCount(maxAccount) or not validCount(maxCharacter)
        or not validCount(countAccount) or not validCount(countCharacter)
        or maxAccount < 1 or maxCharacter < 1 or maxAccount + maxCharacter > 1000 then
        return nil, "počty nebo limity nelze přečíst"
    end

    local lists = {
        account = { expected = countAccount, capacity = maxAccount, first = 1 },
        character = { expected = countCharacter, capacity = maxCharacter, first = maxAccount + 1 },
    }
    for scope, list in pairs(lists) do
        for index = list.first, list.first + list.capacity - 1 do
            local readable, slot = readSlot(index)
            if not readable then return nil, "nelze přečíst index " .. index end
            if slot then list[#list + 1] = slot end
        end
        if #list ~= list.expected then return nil, "rozpor v počtu maker (" .. scope .. ")" end
    end
    return lists
end

local function find(lists, name)
    local foldedName = name:lower()
    local match, matchScope, count = nil, nil, 0
    for scope, list in pairs(lists) do
        for _, slot in ipairs(list) do
            if slot.name:lower() == foldedName then
                match, matchScope, count = slot, scope, count + 1
            end
        end
    end
    return match, matchScope, count
end

local function selectedIcon(slot)
    local ok, icon = call(C_Macro and C_Macro.GetSelectedMacroIcon, slot.index)
    if ok and isPublic(icon) and type(icon) == "number" then return icon, icon end
    return slot.icon
end

local function matchesFixture(slot, fixture)
    return slot.name == fixture.name and slot.body == fixture.body and selectedIcon(slot) == fixture.icon
end

local function buildInfo()
    local _, version, build, buildDate, interface = call(GetBuildInfo)
    local _, locale = call(GetLocale)
    local profile
    if isPublic(build) and tonumber(build) and isPublic(interface) and interface == 16001
        and isPublic(locale) and type(locale) == "string" then
        profile = show(build) .. "/" .. show(interface) .. "/" .. show(locale)
    end
    return profile, ("verze=%s build=%s datum=%s interface=%s locale=%s"):format(
        show(version), show(build), show(buildDate), show(interface), show(locale))
end

local function observeCharacter()
    local ok, guid = call(UnitGUID, "player")
    if not ok or not isPublic(guid) or type(guid) ~= "string" or not guid:match("^Player%-") then
        return "unknown"
    end
    if not characterDB.playerKey then
        characterDB.playerKey = guid
        return "first"
    end
    return characterDB.playerKey == guid and "same" or "changed"
end

local function report()
    local profile, build = buildInfo()
    local maxAccount, maxCharacter = caps()
    local ok, countAccount, countCharacter = call(GetNumMacros)
    local key = observeCharacter()
    record(build .. " | combat=" .. lockdown() .. " | Player GUID=" .. key)
    record(("MacroConsts=%s/%s | GetNumMacros ok=%s account=%s character=%s"):format(
        show(maxAccount), show(maxCharacter), show(ok), show(countAccount), show(countCharacter)))
    record(("API GetMacroInfo=%s CreateMacro=%s EditMacro=%s DeleteMacro=%s PickupMacro=%s selectedIcon=%s InCombatLockdown=%s"):format(
        type(GetMacroInfo), type(CreateMacro), type(EditMacro), type(DeleteMacro), type(PickupMacro),
        type(C_Macro and C_Macro.GetSelectedMacroIcon), type(InCombatLockdown)))
    record(("API C_SpellBook=%s C_Spell=%s C_Item=%s"):format(type(C_SpellBook), type(C_Spell), type(C_Item)))
    local events = {}
    for _, event in ipairs(watchedEvents) do
        events[#events + 1] = event .. "=" .. show(eventState[event])
    end
    record("události: " .. table.concat(events, " "), true)
    record(("SavedVariables: účet start=%d značka=%s | postava start=%d značka=%s"):format(
        accountDB.starts, show(accountDB.marker), characterDB.starts, show(characterDB.marker)))

    local lists, reason = scan()
    if not lists then return record("kontrola slotů: " .. reason) end
    for _, scope in ipairs({ "account", "character" }) do
        local list = lists[scope]
        local first, last = list[1], list[#list]
        record(("%s: %d/%d, použité indexy %s–%s"):format(
            scope, #list, list.capacity, show(first and first.index), show(last and last.index)))
        local db = scope == "account" and accountDB or characterDB
        local fixture = db.fixture
        if fixture then
            local slot, foundScope, count = find(lists, fixture.name)
            record(("%s: test %s, index=%s, shody=%d, rozsah=%s, stejný snímek=%s, profil=%s"):format(
                scope, fixture.name, show(slot and slot.index), count, show(foundScope),
                show(count == 1 and foundScope == scope and matchesFixture(slot, fixture)),
                show(profile ~= nil and fixture.profile == profile)))
        end
    end
end

local function describeBody(body)
    local _, chars = body:gsub("[^\128-\191]", "")
    local _, lines = body:gsub("\n", "")
    return ("%d B/%d znaků/%d LF"):format(#body, chars, lines)
end

local function mutate(action, scope, case)
    if scope ~= "account" and scope ~= "character" then
        return say("Zadej rozsah account nebo character.")
    end
    local lock = lockdown()
    if lock ~= "out" then return record(action .. " " .. scope .. " blokováno: " .. lock) end
    if scope == "character" and observeCharacter() ~= "same" then
        return record("Rozsah postavy vyžaduje potvrzený klíč. Nejprve zadej /fms probe.")
    end

    local fn = ({ create = CreateMacro, edit = EditMacro, delete = DeleteMacro })[action]
    if type(fn) ~= "function" then return record(action .. ": API nedostupné") end
    local lists, reason = scan()
    if not lists then return record(action .. ": " .. reason) end

    local db = scope == "account" and accountDB or characterDB
    local fixture, name, previous, intended = db.fixture
    local profile = buildInfo()
    if not profile then return record(action .. ": nelze potvrdit profil klienta") end
    local list = lists[scope]
    if action == "create" then
        if fixture then return record(scope .. ": nejprve dokonči test makra " .. fixture.name) end
        if #list >= list.capacity then return record(scope .. ": rozsah je plný") end
        local suffix = ("%05x"):format(time() % 1048576)
        for index = 1, 99 do
            local candidate = ("FMSE00%s%02d"):format(suffix, index)
            if not find(lists, candidate) then
                name = candidate
                break
            end
        end
        if not name then return record("Nelze najít volný testovací název.") end
        intended = baseBody
    else
        if not fixture then return record(scope .. ": nejprve vytvoř testovací makro") end
        name = fixture.name
        local found, foundScope, count = find(lists, name)
        if action == "delete" and count == 0 then
            db.fixture = nil
            return record(scope .. ": test " .. name .. " už ve hře není; místní záznam odstraněn")
        end
        if fixture.profile ~= profile or count ~= 1 or foundScope ~= scope or not matchesFixture(found, fixture) then
            return record(scope .. ": snímek " .. name .. " nesouhlasí. Zkontroluj ručně přes /macro.")
        end
        previous = found
        if action == "edit" then
            intended = editedBodies[case]
            if not intended then return say("Případy: utf8, a254, a255, a256, u256b, u256c, base.") end
        end
    end

    lock = lockdown()
    if lock ~= "out" then return record(action .. " " .. scope .. " blokováno: " .. lock) end
    operation = action
    local ok, result
    if action == "create" then
        ok, result = call(fn, name, fixtureIcon, intended, scope == "character")
    elseif action == "edit" then
        ok, result = call(fn, previous.index, nil, nil, intended)
    else
        ok, result = call(fn, previous.index)
    end
    operation = nil

    local after, problem = scan()
    local summary = ("%s %s %s ok=%s návrat=%s"):format(action, scope, name, show(ok), ok and show(result) or "chyba")
    if action == "edit" then summary = summary .. " případ=" .. case end
    if not after then return record(summary .. " | výsledek neověřen: " .. problem) end
    local actual, actualScope, count = find(after, name)
    local delta = #after[scope] - #list
    summary = summary .. (" | počet změna=%+d shody=%d index=%s→%s"):format(
        delta, count, show(previous and previous.index), show(actual and actual.index))
    if action == "delete" and count == 0 and delta == -1 then
        db.fixture = nil
        return record(summary .. " | test odstraněn")
    end
    if count ~= 1 or actualScope ~= scope or actual.name ~= name or action == "delete" then
        return record(summary .. " | výsledek neověřen; zkontroluj /macro")
    end

    local body = actual.body
    local exact = intended == body
    local truncated = body:sub(1, #baseBody) == baseBody and intended:sub(1, #body) == body and not exact
    local icon, selected = selectedIcon(actual)
    local expectedChange = action == "create" and delta == 1 and exact
        or action == "edit" and delta == 0 and icon == fixture.icon and (exact or truncated)
    if expectedChange then
        db.fixture = { name = name, body = body, icon = icon, profile = profile }
    end
    record(summary .. (" | požadováno %s, načteno %s, změna těla=%s, shoda=%s, oříznutý prefix=%s, ikona=%s, zvolená ikona=%s"):format(
        describeBody(intended), describeBody(body), show(not previous or previous.body ~= body),
        show(exact), show(truncated), show(actual.icon),
        show(selected)) .. (expectedChange and "" or " | snímek nepřevzat"))
end

local function probeBook()
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local book = C_SpellBook or {}
    local ok, count = call(book.GetNumSpellBookSkillLines)
    if not ok or not validCount(count) or bank == nil then return record("Knihu kouzel nelze načíst.") end
    local total, sample = 0, nil
    for line = 1, count do
        local readable, info = call(book.GetSpellBookSkillLineInfo, line)
        if readable and type(info) == "table" and validCount(info.itemIndexOffset) and validCount(info.numSpellBookItems) then
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local loaded, entry = call(book.GetSpellBookItemInfo, index, bank)
                if loaded and type(entry) == "table" then
                    total = total + 1
                    if not sample and isPublic(entry.spellID) and type(entry.spellID) == "number" then
                        local named, name = call(C_Spell and C_Spell.GetSpellName, entry.spellID)
                        sample = ("ID=%d kniha=%s C_Spell=%s"):format(
                            entry.spellID, show(entry.name), named and show(name) or "nedostupné")
                    end
                end
            end
        end
    end
    record(("Kniha kouzel: řádků=%d, načtených položek=%d, vzorek %s"):format(count, total, sample or "chybí"))
end

local function probeItem(id)
    pendingItem = id
    local ok, name = call(C_Item and C_Item.GetItemInfo, id)
    record(("C_Item.GetItemInfo %d ok=%s název=%s"):format(id, show(ok), show(name)))
    if ok and isPublic(name) and name == nil then
        local requested = call(C_Item.RequestLoadItemDataByID, id)
        record("Žádost o data předmětu: " .. show(requested))
    end
end

local function onCommand(message)
    local root, action, scope, case, extra = message:match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    if root ~= "probe" or extra ~= "" then return say("Použití: /fms probe") end
    if action == "" and scope == "" then
        report()
        return say("Další příkazy: book, item <ID>, mark <značka>, create|edit|delete <account|character> [případ pro edit].")
    end
    if action == "book" and scope == "" then return probeBook() end
    if action == "item" and case == "" and scope:match("^%d+$") and #scope <= 9 and tonumber(scope) > 0 then
        return probeItem(tonumber(scope))
    end
    if action == "mark" and case == "" and scope:match("^[%w_-]+$") and #scope <= 20 then
        accountDB.marker, characterDB.marker = scope, scope
        return record("Uložena zkušební značka " .. scope)
    end
    if operation then return say("Operace už probíhá.") end
    if ((action == "create" or action == "delete") and case == "") or action == "edit" then
        return mutate(action, scope, case)
    end
    say("Použití: /fms probe")
end

local function onEvent(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent(event)
        ForeverMacroStudioProbeDB = ForeverMacroStudioProbeDB or { starts = 0, history = {} }
        ForeverMacroStudioProbeCharDB = ForeverMacroStudioProbeCharDB or { starts = 0 }
        accountDB, characterDB = ForeverMacroStudioProbeDB, ForeverMacroStudioProbeCharDB
        accountDB.starts = accountDB.starts + 1
        characterDB.starts = characterDB.starts + 1
        for _, observed in ipairs(watchedEvents) do
            local ok, registered = pcall(self.RegisterEvent, self, observed)
            eventState[observed] = ok and registered == true
        end
        SLASH_FMS_E00_PROBE1 = "/fmsprobe"
        SlashCmdList.FMS_E00_PROBE = function(message)
            return onCommand("probe " .. message)
        end
        if not SlashCmdList.FOREVER_MACRO_STUDIO then
            SLASH_FMS_E00_LEGACY1 = "/fms"
            SlashCmdList.FMS_E00_LEGACY = onCommand
        end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
        if not pendingItem or not isPublic(arg1) or arg1 ~= pendingItem then return end
        local ok, name = call(C_Item and C_Item.GetItemInfo, pendingItem)
        return record(("%s id=%d success=%s read=%s název=%s"):format(
            event, pendingItem, show(arg2), show(ok), show(name)))
    end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if not isPublic(arg1) or arg1 ~= addonName then return end
        return record(event .. " " .. show(arg2), true)
    end
    if event == "PLAYER_ENTERING_WORLD" then
        local _, build = buildInfo()
        local key = observeCharacter()
        return record(("%s | %s | initial=%s reload=%s | Player GUID=%s | účet start=%d | postava start=%d"):format(
            event, build, show(arg1), show(arg2), key, accountDB.starts, characterDB.starts), true)
    end
    record(event .. " | combat=" .. lockdown() .. " | uvnitř=" .. (operation or "ne"), true)
end

frame:SetScript("OnEvent", onEvent)
frame:RegisterEvent("ADDON_LOADED")
