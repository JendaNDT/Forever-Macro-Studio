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
    local function showLibrary()
        libraryPanel:Show()
        render()
    end
    wizard = studio.CreateWizard(window, showLibrary)

    local function start(draft, raw, starter)
        libraryPanel:Hide()
        wizard.Start(draft, raw, starter)
    end

    local heading = W.Label(libraryPanel, 24, 39, 450, true)
    local searchLabel = W.Label(libraryPanel, 24, 108, 124)
    local search = W.Box(libraryPanel, 150, 102, 290, 24)
    local new = W.Button(libraryPanel, 24, 70, 184, function() start(nil, false) end)
    local paste = W.Button(libraryPanel, 215, 70, 150, function() start(nil, true) end)
    local count = W.Label(libraryPanel, 24, 380, 420)
    local hint = W.Label(libraryPanel, 24, 405, 420)
    local sidePanels = {}
    local sidePage = studio.library.issue and "diagnostics" or "examples"
    for _, page in ipairs({ "examples", "classPresets", "professions", "diagnostics" }) do
        local panel = CreateFrame("Frame", nil, libraryPanel)
        panel:SetAllPoints(libraryPanel)
        sidePanels[page] = panel
    end
    local diagnostics = W.Label(sidePanels.diagnostics, 472, 42, 262, true)
    local status = W.Label(sidePanels.diagnostics, 472, 71, 258)
    status:SetSpacing(4)
    local guideHeading = W.Label(sidePanels.examples, 472, 42, 258, true)
    local guideIntro = W.Label(sidePanels.examples, 472, 71, 258)
    local examples = {}
    for index, pattern in ipairs({ "self", "mouseover", "shift" }) do
        local y = 144 + (index - 1) * 84
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
        { "examples", 410, 70 }, { "classPresets", 484, 105 }, { "professions", 593, 66 }, { "diagnostics", 663, 72 },
    }) do
        local page = tab[1]
        sideTabs[page] = W.Button(libraryPanel, tab[2], 485, tab[3], function()
            sidePage = page
            render()
        end)
    end
    local language = W.Button(libraryPanel, 24, 485, 200, function()
        local preferences = studio.preferences
        preferences.language = nextLanguage[preferences.language or "auto"] or "auto"
        render()
    end)
    local pager = W.Pager(libraryPanel, 24, 137, 420, 8, function() render() end, function(draft) start(draft) end)
    search:SetScript("OnTextChanged", function(_, user)
        if user then pager.page = 1; render() end
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); pager.ChooseFirst() end)

    render = function()
        local strings = studio.GetStrings()
        local query = W.Lower(search:GetText())
        local entries = {}
        for _, draft in ipairs(studio.library.List()) do
            local searchable = W.Lower(draft.title .. " " .. table.concat(draft.tags, " "))
            if searchable:find(query, 1, true) then entries[#entries + 1] = draft end
        end
        heading:SetText(strings.library)
        searchLabel:SetText(strings.search)
        new:SetText(strings.newMacro)
        paste:SetText(strings.pasteText)
        new:SetEnabled(not studio.library.issue)
        paste:SetEnabled(not studio.library.issue)
        count:SetText(strings.storedDrafts:format(studio.library.Count()))
        hint:SetText(#entries == 0 and (query == "" and strings.libraryEmpty or strings.noSearchResults) or strings.openDraft)
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
        pager.Render(entries, function(draft) return draft.title ~= "" and draft.title or strings.untitledDraft end)
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
    window:SetScript("OnShow", function(self)
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        self:SetScale(math.min(1, (width - 24) / 760, (height - 24) / 530))
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
