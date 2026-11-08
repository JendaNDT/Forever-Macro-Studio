local _, studio = ...
local W, Catalog, Presets = studio.Widgets, studio.Catalog, studio.Presets

local function playerClass()
    if type(UnitClass) == "function" then
        local _, class = UnitClass("player")
        return class
    end
end

local function arrows(panel, y, move)
    local previous = W.Button(panel, 472, y, 34, function() move(-1) end)
    local following = W.Button(panel, 700, y, 34, function() move(1) end)
    previous:SetText("<")
    following:SetText(">")
    return previous, following
end

local function createCards(panel, start, refresh)
    local page = { index = 1 }
    local cards = {}
    for index = 1, 2 do
        local y = 176 + (index - 1) * 110
        cards[index] = {
            button = W.Button(panel, 472, y, 260, function(self)
                if self.starter then start(self.starter) end
            end),
            details = W.Label(panel, 472, y + 29, 258),
        }
    end
    local previous, following = arrows(panel, 399, function(delta)
        page.index = page.index + delta
        refresh()
    end)
    local indicator = W.Label(panel, 512, 404, 180)
    indicator:SetJustifyH("CENTER")
    local hint = W.Label(panel, 472, 435, 258)
    local empty = W.Label(panel, 472, 178, 258)
    local filter = W.Button(panel, 610, 74, 124, function()
        page.onlyAvailable, page.index = not page.onlyAvailable, 1
        refresh()
    end)

    function page.Render(entries, guide)
        if page.onlyAvailable then
            local available = {}
            for _, entry in ipairs(entries) do
                if entry.starter then available[#available + 1] = entry end
            end
            entries = available
            filter:LockHighlight()
        else
            filter:UnlockHighlight()
        end
        filter:SetText(guide.onlyAvailable)
        local pages = math.max(1, math.ceil(#entries / #cards))
        page.index = math.max(1, math.min(page.index, pages))
        local offset = (page.index - 1) * #cards
        for index, card in ipairs(cards) do
            local entry = entries[offset + index]
            card.button.starter = entry and entry.starter
            card.button:SetShown(entry ~= nil)
            card.details:SetShown(entry ~= nil)
            if entry then
                card.button:SetText(entry.title)
                card.button:SetEnabled(entry.starter ~= nil and not studio.library.issue)
                card.details:SetText(entry.description .. "\n" .. W.SafeText(entry.availability))
            end
        end
        previous:SetEnabled(page.index > 1)
        following:SetEnabled(page.index < pages)
        indicator:SetText(("%d / %d"):format(page.index, pages))
        empty:SetText(guide.noAvailablePresets)
        local hasEntries = #entries > 0
        empty:SetShown(not hasEntries)
        previous:SetShown(hasEntries)
        following:SetShown(hasEntries)
        indicator:SetShown(hasEntries)
        hint:SetShown(hasEntries)
        hint:SetText(guide.presetHint)
    end

    return page
end

local function card(preset, title, description, availability, action, shiftAction)
    return {
        title = title, description = description, availability = availability,
        starter = action and {
            pattern = preset.pattern, action = action, shiftAction = shiftAction,
            title = title .. " · " .. action.name,
        },
    }
end

local function classAvailability(preset, ownClass, guide)
    local name, shiftName = preset.names, preset.shiftName
    if not ownClass then return shiftName and guide.shiftPair:format(name, shiftName) or name end

    local action = Catalog.KnownSpell(preset.spellIds)
    if not shiftName then
        if action then return guide.spellLabel:format(action.name), action end
        local requirement = #preset.spellIds > 1 and guide.oneSpellRequired or guide.notLearned
        return requirement:format(name)
    end

    local alternate = Catalog.KnownSpell(preset.shiftSpellIds)
    if action and alternate then return guide.shiftPair:format(action.name, alternate.name), action, alternate end
    if action then return guide.missingShift:format(action.name, shiftName) end
    if alternate then return guide.missingDefault:format(alternate.name, name) end
    return guide.missingBoth:format(name, shiftName)
end

function studio.CreateClassPresets(panel, start)
    local selected, renderedClass, currentIndex
    local view = {}
    local heading = W.Label(panel, 472, 76, 132, true)
    local selector = W.Label(panel, 512, 111, 180)
    selector:SetJustifyH("CENTER")
    local status = W.Label(panel, 472, 143, 258)
    local function refresh() view.Render(studio.GetStrings().guide) end
    local page = createCards(panel, start, refresh)
    local previous, following = arrows(panel, 106, function(delta)
        selected, page.index = selected + delta, 1
        refresh()
    end)

    function view.Render(guide)
        local current = playerClass()
        if not selected or renderedClass ~= current then
            renderedClass, currentIndex, page.index = current, 1, 1
            for index, class in ipairs(Presets.classes) do
                if class == current then currentIndex = index break end
            end
            selected = currentIndex
        end
        local class = Presets.classes[page.onlyAvailable and currentIndex or selected]
        local ownClass = class == current
        heading:SetText(guide.classPresets)
        selector:SetText(guide.classNames[class])
        status:SetText(ownClass and guide.knownSpells or guide.otherClass)
        previous:SetEnabled(not page.onlyAvailable and selected > 1)
        following:SetEnabled(not page.onlyAvailable and selected < #Presets.classes)
        local entries = {}
        for _, preset in ipairs(Presets.byClass[class]) do
            local role = guide.roles[preset.role]
            local availability, spell, alternate = classAvailability(preset, ownClass, guide)
            entries[#entries + 1] = card(preset, role[1], role[2], availability, spell, alternate)
        end
        page.Render(entries, guide)
    end
    return view
end

function studio.CreateProfessionPresets(panel, start)
    local view = {}
    local heading = W.Label(panel, 472, 76, 132, true)
    local intro = W.Label(panel, 472, 106, 258)
    local page = createCards(panel, start, function() view.Render(studio.GetStrings().guide) end)

    function view.Render(guide)
        heading:SetText(guide.professions)
        intro:SetText(guide.professionIntro)
        local entries, unavailable = {}, {}
        for _, preset in ipairs(Presets.professions) do
            local role = guide.professionRoles[preset.role]
            local title = preset.profession and role[1]:format(guide.professionNames[preset.profession]) or role[1]
            local action, availability
            if preset.itemIds then
                local state
                action, state = Catalog.BagItem(preset.itemIds)
                availability = action and guide.itemLabel:format(action.name)
                    or (state == "catalogLoading" and guide.loadingBags or guide.noBandage)
            else
                action = Catalog.KnownSpell(preset.spellIds)
                availability = action and guide.spellLabel:format(action.name) or guide.notLearned:format(preset.names)
            end
            local group = action and entries or unavailable
            group[#group + 1] = card(preset, title, role[2], availability, action)
        end
        for _, entry in ipairs(unavailable) do entries[#entries + 1] = entry end
        page.Render(entries, guide)
    end
    return view
end
