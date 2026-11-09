local _, studio = ...
local W = studio.Widgets

local frame
local nextLanguage = { auto = "csCZ", csCZ = "enUS", enUS = "auto" }

local function createWindow()
    local window = CreateFrame("Frame", "ForeverMacroStudioFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(760, 530)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:Hide()
    window.TitleText:SetText("Forever Macro Studio")

    local libraryPanel = CreateFrame("Frame", nil, window)
    libraryPanel:SetAllPoints(window)
    local wizard, render
    local importing, scope, archived, characterFilter, archiveMessage = false, "account", false
    local function showLibrary()
        libraryPanel:Show()
        render()
    end
    wizard = studio.CreateWizard(window, showLibrary)

    local function start(draft, raw, starter, options)
        importing, archiveMessage = false, nil
        libraryPanel:Hide()
        wizard.Start(draft, raw, starter, options)
    end

    local heading = W.Label(libraryPanel, 24, 39, 450, true)
    local searchLabel = W.Label(libraryPanel, 24, 108, 124)
    local search = W.Box(libraryPanel, 150, 102, 290, 24)
    local new = W.Button(libraryPanel, 24, 70, 130, function() start(nil, false) end)
    local paste = W.Button(libraryPanel, 160, 70, 126, function() start(nil, true) end)
    local import = W.Button(libraryPanel, 292, 70, 152, function()
        importing, archiveMessage = not importing, nil
        W.SetText(search, "")
        render()
    end)
    local count = W.Label(libraryPanel, 24, 380, 420)
    local hint = W.Label(libraryPanel, 24, 405, 420)
    local divider = libraryPanel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 455, -42)
    divider:SetSize(1, 423)
    divider:SetColorTexture(0.85, 0.76, 0.54, 0.22)
    local sidePanels = {}
    local sidePage = studio.library.issue and "diagnostics" or "examples"
    for _, page in ipairs({ "examples", "classPresets", "professions", "diagnostics" }) do
        local panel = CreateFrame("Frame", nil, libraryPanel)
        panel:SetAllPoints(libraryPanel)
        sidePanels[page] = panel
    end
    local diagnostics = W.Label(sidePanels.diagnostics, 472, 76, 262, true)
    local status = W.Label(sidePanels.diagnostics, 472, 106, 258)
    status:SetSpacing(4)
    local guideHeading = W.Label(sidePanels.examples, 472, 76, 258, true)
    local guideIntro = W.Label(sidePanels.examples, 472, 106, 258)
    local examples = {}
    for index, pattern in ipairs({ "self", "mouseover", "shift" }) do
        local y = 174 + (index - 1) * 84
        examples[pattern] = {
            button = W.Button(sidePanels.examples, 472, y, 260, function()
                start(nil, false, { pattern = pattern })
            end),
            description = W.Label(sidePanels.examples, 472, y + 28, 258),
        }
    end
    local function startPreset(starter)
        start(nil, false, starter)
    end
    local classPresets = studio.CreateClassPresets(sidePanels.classPresets, startPreset)
    local professionPresets = studio.CreateProfessionPresets(sidePanels.professions, startPreset)
    local sideTabs = {}
    for _, tab in ipairs({
        { "examples", 472, 39, 66 }, { "classPresets", 542, 39, 112 }, { "professions", 658, 39, 76 },
        { "diagnostics", 621, 485, 113 },
    }) do
        local page = tab[1]
        sideTabs[page] = W.Button(libraryPanel, tab[2], tab[3], tab[4], function()
            sidePage = page
            render()
        end)
    end
    local language = W.Button(libraryPanel, 24, 485, 200, function()
        local preferences = studio.preferences
        preferences.language = nextLanguage[preferences.language or "auto"] or "auto"
        render()
    end)
    local draftRows = CreateFrame("Frame", nil, libraryPanel)
    draftRows:SetAllPoints(libraryPanel)
    local importRows = CreateFrame("Frame", nil, libraryPanel)
    importRows:SetAllPoints(libraryPanel)
    local pager = W.Pager(draftRows, 24, 137, 420, 8, function() render() end, function(draft) start(draft) end, {
        {
            width = 109,
            label = function() return studio.GetStrings().editCopy end,
            choose = function(draft)
                if studio.library.issue then return end
                local strings = studio.GetStrings()
                local copy = studio.Draft.CopyContent(draft)
                copy.title = strings.copyTitle:format(copy.title ~= "" and copy.title or strings.untitledDraft)
                copy.archived = nil
                start(copy)
            end,
        },
        {
            width = 91,
            label = function(draft)
                local strings = studio.GetStrings()
                return draft.archived and strings.restoreDraft or strings.archiveDraft
            end,
            choose = function(draft)
                if studio.library.issue then return end
                draft.archived = not draft.archived
                local saved = studio.library.Save(draft)
                archiveMessage = saved and (draft.archived and "draftArchived" or "draftRestored") or "draftSaveFailed"
                render()
            end,
        },
    })
    local importPager = W.Pager(importRows, 24, 168, 420, 7, function() render() end, function(entry)
        if studio.library.issue then return end
        local rawBody = { mode = "raw", text = entry.text, sourceLocale = studio.client.locale }
        local converted, issue = studio.Compiler.ToStructured(rawBody, studio.Catalog.SpellId, studio.Catalog.SpellName)
        characterFilter, archived, pager.page = nil, false, 1
        W.SetText(search, "")
        start({
            kind = "macro", title = entry.title, icon = entry.icon, tags = {},
            body = converted or rawBody,
            character = scope == "character" and studio.GetCharacterName() or nil,
        }, false, nil, { preview = true, conversionIssue = issue })
    end)
    local archiveToggle = W.Button(draftRows, 306, 435, 138, function()
        archived, archiveMessage, pager.page = not archived, nil, 1
        render()
    end)
    local characters = {}
    local characterToggle = W.Button(draftRows, 24, 435, 274, function()
        local index = 0
        for position, name in ipairs(characters) do
            if name == characterFilter then index = position break end
        end
        characterFilter, archiveMessage, pager.page = characters[index + 1], nil, 1
        render()
    end)
    local characterText = characterToggle:GetFontString()
    characterText:SetWordWrap(false)
    characterText:SetMaxLines(1)
    local scopeButtons = {}
    for index, option in ipairs({ "account", "character" }) do
        local chosen = option
        scopeButtons[chosen] = W.Button(importRows, 24 + (index - 1) * 157, 137, 149, function()
            scope, importPager.page = chosen, 1
            render()
        end)
    end
    search:SetScript("OnTextChanged", function(_, user)
        if user then
            pager.page, importPager.page, archiveMessage = 1, 1, nil
            render()
        end
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if importing then importPager.ChooseFirst() else pager.ChooseFirst() end
    end)

    render = function()
        local strings = studio.GetStrings()
        local query = W.Lower(search:GetText())
        local entries = {}
        draftRows:SetShown(not importing)
        importRows:SetShown(importing)
        heading:SetText(importing and strings.importHeading or strings.library)
        searchLabel:SetText(strings.search)
        new:SetText(strings.newMacro)
        paste:SetText(strings.pasteText)
        import:SetText(importing and strings.backToDrafts or strings.importMacros)
        new:SetEnabled(not studio.library.issue)
        paste:SetEnabled(not studio.library.issue)
        import:SetEnabled(importing or not studio.library.issue)
        if importing then
            local macros = studio.ClientMacros.List(scope)
            for _, entry in ipairs(macros or {}) do
                if W.Lower(entry.title):find(query, 1, true) then entries[#entries + 1] = entry end
            end
            for option, button in pairs(scopeButtons) do
                button:SetText(option == "account" and strings.accountMacros or strings.characterMacros)
                if option == scope then button:LockHighlight() else button:UnlockHighlight() end
            end
            count:SetText(macros and strings.importCount:format(#macros) or "")
            hint:SetText(not macros and strings.importUnavailable
                or #macros == 0 and strings.importEmpty or #entries == 0 and strings.importNoMatches or strings.importHint)
            importPager.Render(entries, function(entry) return entry.title end)
        else
            local names = {}
            for _, draft in ipairs(studio.library.List()) do
                local name = draft.character or ""
                names[name] = true
                if (draft.archived == true) == archived and (not characterFilter or characterFilter == name) then
                    local searchable = W.Lower(draft.title .. " " .. table.concat(draft.tags, " "))
                    if searchable:find(query, 1, true) then entries[#entries + 1] = draft end
                end
            end
            characters = {}
            for name in pairs(names) do
                if name ~= "" then characters[#characters + 1] = name end
            end
            table.sort(characters)
            if names[""] then characters[#characters + 1] = "" end
            local current = characterFilter == "" and strings.unassignedCharacter
                or characterFilter and W.SafeText(characterFilter) or strings.allCharacters
            characterToggle:SetText(strings.characterFilter:format(current))
            characterToggle:SetEnabled(#characters > 0)
            if characterFilter then characterToggle:LockHighlight() else characterToggle:UnlockHighlight() end
            archiveToggle:SetText(archived and strings.activeDrafts or strings.archivedDrafts)
            if archived then archiveToggle:LockHighlight() else archiveToggle:UnlockHighlight() end
            count:SetText(strings.storedDrafts:format(studio.library.Count()) .. "  (" .. #entries .. ")")
            hint:SetText(archiveMessage and strings[archiveMessage] or #entries > 0 and strings.openDraft
                or (query ~= "" or characterFilter) and strings.noSearchResults
                or archived and strings.archiveEmpty or strings.libraryEmpty)
            pager.Render(entries, function(draft) return draft.title ~= "" and draft.title or strings.untitledDraft end,
                nil, not studio.library.issue)
        end
        local guide = strings.guide
        for page, panel in pairs(sidePanels) do
            local active = page == sidePage
            panel:SetShown(active)
            sideTabs[page]:SetText(guide[page])
            if active then sideTabs[page]:LockHighlight() else sideTabs[page]:UnlockHighlight() end
        end
        if sidePage == "diagnostics" then
            diagnostics:SetText(strings.header)
            status:SetText(table.concat(studio.GetStatusLines(strings), "\n"))
        elseif sidePage == "classPresets" then
            classPresets.Render(guide)
        elseif sidePage == "professions" then
            professionPresets.Render(guide)
        else
            guideHeading:SetText(guide.start)
            guideIntro:SetText(guide.intro)
            for pattern, card in pairs(examples) do
                local example = guide.starters[pattern]
                card.button:SetText(example[1])
                card.button:SetEnabled(not studio.library.issue)
                card.description:SetText(example[2])
            end
        end
        language:SetText(strings.language:format(studio.GetLanguageLabel(strings)))
    end

    function window:Refresh()
        if wizard.IsOpen() then wizard.Refresh() else render() end
    end

    function window:RequestClose()
        wizard.Close(function() self:Hide(); showLibrary() end)
    end

    window:SetScript("OnHide", function(self)
        if not self:IsShown() and wizard.IsOpen() then
            wizard.Close(function() self:Hide(); showLibrary() end)
        end
    end)
    local userScale = 1
    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(self, delta)
        if not IsControlKeyDown or not IsControlKeyDown() then return end
        userScale = math.max(0.7, math.min(1.2, userScale + (delta > 0 and 0.05 or -0.05)))
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        self:SetScale(math.min(userScale, (width - 24) / 760, (height - 24) / 530))
    end)
    window:SetScript("OnShow", function(self)
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        self:SetScale(math.min(userScale, (width - 24) / 760, (height - 24) / 530))
        self:Refresh()
    end)
    if window.CloseButton then window.CloseButton:SetScript("OnClick", function() window:RequestClose() end) end
    tinsert(UISpecialFrames, window:GetName())
    return window
end

function studio.ToggleWindow()
    frame = frame or createWindow()
    if frame:IsShown() then
        frame:RequestClose()
    else
        frame:Show()
    end
end

function studio.RefreshWindow()
    if frame and frame:IsShown() then frame:Refresh() end
end
