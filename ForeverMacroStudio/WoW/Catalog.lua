local _, studio = ...
local Catalog = {}
studio.Catalog = Catalog

local spells, bags
local pendingItems, failedItems = {}, {}

local function public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and public(value) then return value end
end

local function knownProfessionName(id)
    local known = read(C_SpellBook and C_SpellBook.IsSpellKnown, id)
    if known == nil then known = read(IsPlayerSpell, id) end
    local name = known and read(C_Spell and C_Spell.GetSpellName, id)
    if type(name) == "string" and name ~= "" then return name end
end

local function countValue(value)
    return public(value) and studio.Draft.IsInteger(value)
end

local function sorted(entries)
    table.sort(entries, function(first, second)
        if first.name == second.name then return first.id < second.id end
        return first.name < second.name
    end)
    return entries
end

local function loadSpellbook()
    local book = C_SpellBook or {}
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local count = read(book.GetNumSpellBookSkillLines)
    local entries, byId, byBaseId = {}, {}, {}
    if not bank or not countValue(count) or not book.GetSpellBookSkillLineInfo or not book.GetSpellBookItemInfo then
        return { entries = entries, byId = byId, byBaseId = byBaseId, state = "catalogUnavailable" }
    end

    local state
    for line = 1, count do
        local info = read(book.GetSpellBookSkillLineInfo, line)
        if type(info) == "table" and countValue(info.itemIndexOffset) and countValue(info.numSpellBookItems) then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = read(book.GetSpellBookItemInfo, slot, bank)
                local id = type(spell) == "table" and spell.spellID
                if public(id) and type(id) == "number" and not byId[id] and public(spell.isPassive)
                    and public(spell.isOffSpec) and not spell.isPassive and not spell.isOffSpec then
                    local name = read(C_Spell and C_Spell.GetSpellName, id) or spell.name
                    if public(name) and type(name) == "string" and name ~= "" then
                        local entry = { kind = "spell", id = id, name = name }
                        entries[#entries + 1], byId[id] = entry, entry
                        local baseId = spell.actionID
                        if public(baseId) and type(baseId) == "number" then byBaseId[baseId] = entry end
                    end
                elseif not spell then
                    state = "catalogPartial"
                end
            end
        else
            state = "catalogPartial"
        end
    end
    return { entries = entries, byId = byId, byBaseId = byBaseId, state = state }
end

local function loadSpells()
    local catalog = loadSpellbook()
    local byName, professionsById = {}, {}
    for _, spell in ipairs(catalog.entries) do byName[spell.name] = spell end

    -- Learned profession actions can be absent from the regular spellbook tabs.
    for _, preset in ipairs(studio.Presets.professions) do
        local ids = preset.spellIds or {}
        for _, id in ipairs(ids) do
            local spell = catalog.byId[id] or catalog.byBaseId[id]
            if not spell then
                local name = knownProfessionName(id)
                if name then
                    spell = byName[name]
                    if not spell then
                        spell = { kind = "spell", id = id, name = name }
                        catalog.entries[#catalog.entries + 1], byName[name] = spell, spell
                    end
                end
            end
            if spell then
                -- Profession ranks share a macro name. Drafts can keep their original ID.
                for _, rank in ipairs(ids) do professionsById[rank] = spell end
                break
            end
        end
    end
    sorted(catalog.entries)
    catalog.professionsById = professionsById
    return catalog
end

local function loadBags()
    local containers, items = C_Container or {}, C_Item or {}
    local entries, byId, seen = {}, {}, {}
    local state
    if not containers.GetContainerNumSlots or not containers.GetContainerItemID or not items.GetItemInfo then
        return { entries = entries, byId = byId, state = "catalogUnavailable" }
    end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local count = read(containers.GetContainerNumSlots, bag) or 0
        for slot = 1, count do
            local id = read(containers.GetContainerItemID, bag, slot)
            if type(id) == "number" and not seen[id] then
                seen[id] = true
                local name = read(items.GetItemInfo, id)
                if type(name) == "string" and name ~= "" then
                    local entry = { kind = "item", id = id, name = name }
                    entries[#entries + 1], byId[id] = entry, entry
                elseif failedItems[id] or type(items.RequestLoadItemDataByID) ~= "function" then
                    state = state or "catalogPartial"
                else
                    state = "catalogLoading"
                    if not pendingItems[id] then
                        pendingItems[id] = true
                        local ok = pcall(items.RequestLoadItemDataByID, id)
                        if not ok then
                            pendingItems[id], failedItems[id] = nil, true
                            state = "catalogPartial"
                        end
                    end
                end
            end
        end
    end
    return { entries = sorted(entries), byId = byId, state = state }
end

function Catalog.Get(kind)
    if kind == "spell" then
        spells = spells or loadSpells()
        return spells.entries, spells.state
    end
    bags = bags or loadBags()
    return bags.entries, bags.state
end

function Catalog.SpellName(id)
    spells = spells or loadSpells()
    local spell = spells.byId[id] or spells.professionsById[id]
    return spell and spell.name
end

function Catalog.KnownSpell(candidates)
    spells = spells or loadSpells()
    for _, id in ipairs(candidates) do
        local known = spells.byId[id] or spells.byBaseId[id] or spells.professionsById[id]
        if known then return known end
        local name = read(C_Spell and C_Spell.GetSpellName, id)
        if name then
            for _, spell in ipairs(spells.entries) do
                if spell.name == name then return spell end
            end
        end
    end
end

function Catalog.BagItem(candidates)
    bags = bags or loadBags()
    for _, id in ipairs(candidates) do
        if bags.byId[id] then return bags.byId[id] end
    end
    return nil, bags.state
end

function Catalog.SpellId(name)
    spells = spells or loadSpells()
    local id
    for _, spell in ipairs(spells.entries) do
        if spell.name == name then
            if id then return nil end
            id = spell.id
        end
    end
    return id
end

function Catalog.Invalidate(event, id, success)
    if event == "SPELLS_CHANGED" then
        spells = nil
    elseif event == "BAG_UPDATE_DELAYED" then
        bags = nil
    elseif event == "ITEM_DATA_LOAD_RESULT" and public(id) and pendingItems[id] then
        pendingItems[id] = nil
        failedItems[id] = not public(success) or not success
        bags = nil
    elseif event == "PLAYER_ENTERING_WORLD" then
        spells, bags = nil, nil
        pendingItems, failedItems = {}, {}
    else
        return false
    end
    return true
end
