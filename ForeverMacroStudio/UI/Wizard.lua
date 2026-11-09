local _, studio = ...
local W, Editor, Catalog, Compiler = studio.Widgets, studio.Editor, studio.Catalog, studio.Compiler
local closeDialog = "FOREVER_MACRO_STUDIO_UNSAVED"
local rawDialog = "FOREVER_MACRO_STUDIO_RAW"
local targetChoices = { "", "target", "player", "mouseover" }
local conditions = { "help", "harm", "exists", "nodead", "mod:shift", "mod:ctrl", "mod:alt" }

local function cap(index, count)
    return math.max(1, math.min(index, count))
end

local function move(entries, index, direction)
    local destination = index + direction
    if entries[destination] then
        entries[index], entries[destination] = entries[destination], entries[index]
    end
end

local function describeGroups(groups, strings)
    if #groups == 0 then return strings.targets[""] end
    local choices = {}
    for index, group in ipairs(groups) do
        if index > 4 then break end
        local conditions = {}
        for _, predicate in ipairs(group.predicates) do
            conditions[#conditions + 1] = strings.conditions[predicate] or predicate
        end
        local target = strings.targets[group.unit or ""] or group.unit
        local rule = #conditions > 0 and (" (" .. table.concat(conditions, ", ") .. ")") or ""
        choices[index] = W.SafeText(target .. rule)
        if #groups > 1 then choices[index] = index .. ". " .. choices[index] end
    end
    if #groups > 4 then choices[5] = "…" end
    return table.concat(choices, "\n")
end

local function actionName(argument, strings)
    if not argument or argument.token == "" then return nil end
    local name = argument.token
    if argument.kind == "spell" then
        name = Catalog.SpellName(argument.id)
    elseif argument.kind == "slot" then
        name = name == "13" and strings.trinket1 or name == "14" and strings.trinket2 or name
    end
    return name and W.SafeText(name)
end

local function summarizeBranch(branch, group, branchCount, advanced, strings)
    local guide = strings.guide
    if not branch then return strings.noAction end
    if not advanced and branchCount > 1 then
        return guide.summaryVariants:format(branchCount), guide.summaryByVariant, guide.summaryByVariant
    end

    local argument = branch.argument
    local action = actionName(argument, strings)
    if not action then
        action = argument.token ~= "" and W.SafeText(strings.spellMissing:format(argument.token)) or strings.noAction
    end
    local unit = group and group.unit or ""
    local target = strings.targets[unit] or W.SafeText(unit)
    local labels = {}
    for _, predicate in ipairs(group and group.predicates or {}) do
        labels[#labels + 1] = strings.conditions[predicate] or W.SafeText(predicate)
    end
    local rules = #labels > 0 and table.concat(labels, ", ") or guide.summaryNoConditions
    if not advanced and #branch.groups > 1 then
        local more = (" +%d"):format(#branch.groups - 1)
        target, rules = target .. more, rules .. more
    end
    return action, target, rules
end

local function describeMacro(body, strings)
    local guide = strings.guide
    if body.mode == "raw" then return guide.complex end
    local branches
    for _, line in ipairs(body.lines) do
        if line.command then
            if branches then return guide.complex end
            branches = line.branches
        end
    end
    local branch = branches and branches[1]
    if not branch then return guide.unavailableAction end
    if #branches == 2 then
        local group, default = branch.groups[1], branches[2]
        if #branch.groups == 1 and not group.unit and #group.predicates == 1
            and group.predicates[1] == "mod:shift" and #default.groups == 0 then
            local normalName = actionName(default.argument, strings)
            local shiftName = actionName(branch.argument, strings)
            return normalName and shiftName and guide.shiftPair:format(normalName, shiftName) or guide.unavailableAction
        end
    end
    if #branches ~= 1 then return guide.complex end
    local name = actionName(branch.argument, strings)
    if not name then return guide.unavailableAction end
    if #branch.groups == 0 then return guide.pressSimple:format(name) end
    return guide.press:format(name) .. "\n\n" .. describeGroups(branch.groups, strings)
end

local function makeNavigator(parent, x, y, labelWidth, onSelect, onEdit)
    local nav = { label = W.Label(parent, x, y, labelWidth) }
    local definitions = {
        { "<", function() onSelect(-1) end }, { ">", function() onSelect(1) end },
        { "+", function() onEdit("add") end }, { "-", function() onEdit("remove") end },
        { "↑", function() onEdit("move", -1) end }, { "↓", function() onEdit("move", 1) end },
    }
    for index, definition in ipairs(definitions) do
        local button = W.Button(parent, x + (index - 1) * 33, y + 19, 30, definition[2])
        button:SetText(definition[1])
        nav[index] = button
    end
    function nav.Render(label, selected, count, allowAdd)
        nav.label:SetText(label)
        nav[1]:SetEnabled(selected > 1)
        nav[2]:SetEnabled(selected < count)
        nav[3]:SetEnabled(allowAdd)
        nav[4]:SetEnabled(count > 0)
        nav[5]:SetEnabled(selected > 1)
        nav[6]:SetEnabled(selected < count)
    end
    return nav
end

function studio.CreateWizard(parent, showLibrary)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()

    local view, editor, refresh = {}
    local step, selectedLine, selectedBranch, selectedGroup, category, message, advanced
    local issueIndex, issueBody = 1
    local simulating, conversionIssue
    local pendingClose
    local steps = {}
    for index = 1, 5 do
        steps[index] = CreateFrame("Frame", nil, frame)
        steps[index]:SetAllPoints(frame)
    end

    local function current()
        local body = editor.Get().body
        local lines = body.lines or {}
        selectedLine = cap(selectedLine, #lines)
        local line = lines[selectedLine]
        local branches = line and line.branches or {}
        selectedBranch = cap(selectedBranch, #branches)
        local branch = branches[selectedBranch]
        local groups = branch and branch.groups or {}
        selectedGroup = cap(selectedGroup, #groups)
        return line, branch, groups[selectedGroup], #lines, #branches, #groups
    end

    local function selectFirstAction(body)
        selectedLine, selectedBranch, selectedGroup = 1, 1, 1
        local actions, multiBranch = 0, false
        for index, line in ipairs(body.lines or {}) do
            if line.command then
                if actions == 0 then selectedLine = index end
                actions = actions + 1
            end
            if #line.branches > 1 then multiBranch = true end
        end
        return multiBranch or actions > 1
    end

    local function update(action, key)
        editor.Change(action, key)
        message = nil
        refresh()
    end

    local function save()
        if studio.MacroText.Trim(editor.Get().title) == "" then
            editor.Change(function(draft) draft.title = studio.GetStrings().untitledDraft end)
        end
        local saved, errorCode = editor.Save(studio.library)
        message = saved and "draftSaved" or errorCode == "stale-revision" and "draftStale" or "draftSaveFailed"
        refresh()
        return saved
    end

    local function finishClose(action)
        editor, pendingClose, issueBody = nil, nil, nil
        frame:Hide()
        action()
    end

    function view.Close(action)
        if not editor or not editor.IsDirty() then
            finishClose(action)
            return
        end
        if pendingClose then return end
        pendingClose = action
        local strings = studio.GetStrings()
        StaticPopupDialogs[closeDialog] = {
            text = strings.unsaved, button1 = strings.saveDraft, button2 = strings.cancel, button3 = strings.discard,
            OnShow = studio.ApplyPopupTypeface, OnHide = studio.RestorePopupTypeface,
            OnAccept = function()
                local close = pendingClose
                pendingClose = nil
                parent:Show()
                if save() then finishClose(close) end
            end,
            OnCancel = function()
                pendingClose = nil
                parent:Show()
            end,
            OnAlt = function() finishClose(pendingClose) end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        if not StaticPopup_Show(closeDialog) then
            pendingClose = nil
            parent:Show()
        end
    end

    local libraryButton = W.Button(frame, 24, 38, 132, function() view.Close(showLibrary) end)
    local titleLabel = W.Label(frame, 170, 26, 350)
    local title = W.Box(frame, 174, 43, 356, 24)
    local undo = W.Button(frame, 544, 42, 94, function() editor.Undo(); message = nil; refresh() end)
    local redo = W.Button(frame, 644, 42, 94, function() editor.Redo(); message = nil; refresh() end)
    local stepTitle = W.Label(frame, 266, 85, 470, true)
    local progress = CreateFrame("StatusBar", nil, frame)
    progress:SetPoint("TOPLEFT", frame, "TOPLEFT", 266, -105)
    progress:SetSize(466, 5)
    progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progress:SetStatusBarColor(0.76, 0.64, 0.35)
    progress:SetMinMaxValues(0, 5)
    progress:SetValue(1)
    local feedback = W.Label(frame, 24, 459, 710)

    local function goTo(destination)
        step, message = destination, nil
        refresh()
    end
    local summary = W.Label(frame, 24, 87, 215, true)
    local stepButtons = {}
    for index = 1, #steps do
        local destination = index
        local button = W.Button(frame, 24, 111 + (index - 1) * 26, 215, function() goTo(destination) end)
        local label = button:GetFontString()
        label:SetWidth(196)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetMaxLines(1)
        stepButtons[index] = button
    end

    local miniTitle = W.Label(frame, 24, 393, 215)
    local miniText = W.Label(frame, 24, 410, 215)
    miniText:SetMaxLines(1)
    miniText:SetWordWrap(false)
    local guidePanel = CreateFrame("Frame", nil, frame)
    guidePanel:SetAllPoints(frame)
    local guideTitle = W.Label(guidePanel, 24, 253, 215, true)
    local guideText = W.Label(guidePanel, 24, 277, 214)
    guideText:SetSpacing(2)
    local showAdvanced = W.Button(frame, 24, 428, 215, function()
        advanced = not advanced
        refresh()
    end)
    local back = W.Button(frame, 24, 485, 110, function() goTo(step - 1) end)
    local nextStep = W.Button(frame, 628, 485, 110, function() goTo(step + 1) end)

    title:SetScript("OnTextChanged", function(self, user)
        if user and editor then
            update(function(draft) draft.title = self:GetText() end, "title")
        end
    end)
    title:SetScript("OnEditFocusLost", function() if editor then editor.EndEdit() end end)

    local outline = CreateFrame("Frame", nil, frame)
    outline:SetAllPoints(frame)
    local lineNav = makeNavigator(outline, 24, 249, 218, function(delta)
        selectedLine, selectedBranch, selectedGroup = selectedLine + delta, 1, 1
        message = nil
        refresh()
    end, function(action, direction)
        update(function(draft)
            local lines = draft.body.lines
            if action == "add" then
                lines[#lines + 1] = { command = "/cast", branches = { Editor.NewBranch("spell") } }
                selectedLine, selectedBranch, selectedGroup = #lines, 1, 1
            elseif action == "remove" then
                table.remove(lines, selectedLine)
                selectedBranch, selectedGroup = 1, 1
            else
                move(lines, selectedLine, direction)
                selectedLine = selectedLine + direction
            end
        end)
    end)
    local branchNav = makeNavigator(outline, 24, 307, 218, function(delta)
        selectedBranch, selectedGroup = selectedBranch + delta, 1
        message = nil
        refresh()
    end, function(action, direction)
        update(function(draft)
            local line = draft.body.lines[selectedLine]
            local branches = line.branches
            if action == "add" then
                branches[#branches + 1] = Editor.NewBranch(line.command == "/use" and "item" or "spell")
                selectedBranch, selectedGroup = #branches, 1
            elseif action == "remove" then
                table.remove(branches, selectedBranch)
                selectedGroup = 1
            else
                move(branches, selectedBranch, direction)
                selectedBranch = selectedBranch + direction
            end
        end)
    end)
    local tooltip = W.Button(outline, 24, 370, 194, function()
        update(function(draft)
            local lines = draft.body.lines
            for index, line in ipairs(lines) do
                if line.directive == "#showtooltip" then
                    table.remove(lines, index)
                    if selectedLine > index then selectedLine = selectedLine - 1 end
                    if selectedLine == index then selectedBranch, selectedGroup = 1, 1 end
                    return
                end
            end
            table.insert(lines, 1, { directive = "#showtooltip", branches = {} })
            selectedLine = selectedLine + 1
        end)
    end)

    local groupPanel = CreateFrame("Frame", nil, frame)
    groupPanel:SetAllPoints(frame)
    local groupNav = makeNavigator(groupPanel, 266, 123, 460, function(delta)
        selectedGroup = selectedGroup + delta
        message = nil
        refresh()
    end, function(action, direction)
        update(function(draft)
            local branch = draft.body.lines[selectedLine].branches[selectedBranch]
            local groups = branch.groups
            if action == "add" then
                Editor.Group(branch, #groups + 1)
                selectedGroup = #groups
            elseif action == "remove" then
                table.remove(groups, selectedGroup)
            else
                move(groups, selectedGroup, direction)
                selectedGroup = selectedGroup + direction
            end
        end)
    end)

    local categories = {}
    local catalogFilterLabel = W.Label(steps[1], 266, 151, 145)
    local catalogFilter = W.Box(steps[1], 416, 144, 318, 24)
    local selectionIcon = steps[1]:CreateTexture(nil, "ARTWORK")
    selectionIcon:SetPoint("TOPLEFT", steps[1], "TOPLEFT", 266, -385)
    selectionIcon:SetSize(38, 38)
    selectionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    local selectionName = W.Label(steps[1], 314, 394, 415)
    local catalogStatus = W.Label(steps[1], 266, 432, 466)
    local function choose(entry)
        local line, branch, _, count = current()
        if not line and count ~= 0 then return end
        if branch and #line.branches > 1 and line.command and
            line.command ~= (entry.kind == "spell" and "/cast" or "/use") then
            message = "mixedAction"
            refresh()
            return
        end
        update(function(draft)
            local lines = draft.body.lines
            if not lines[selectedLine] then lines[1] = { command = "/cast", branches = {} } end
            local active = lines[selectedLine]
            local chosen = active.branches[selectedBranch]
            if not chosen then
                chosen = Editor.NewBranch(entry.kind)
                active.branches[selectedBranch] = chosen
            end
            Editor.SelectAction(active, chosen, entry)
        end)
    end
    local catalogPager = W.CatalogCards(steps[1], 266, 175, 470, function() refresh() end, choose)
    local catalogColumns = 2
    local catalogLayout
    catalogLayout = W.Button(steps[1], 266, 412, 205, function()
        catalogColumns = catalogColumns == 2 and 1 or 2
        catalogLayout:SetText(catalogColumns == 1 and "1 sloupec" or "2 sloupce")
        catalogPager.SetColumns(catalogColumns)
    end)
    for index, kind in ipairs({ "spell", "item", "slot" }) do
        categories[kind] = W.Button(steps[1], 266 + (index - 1) * 159, 114, 150, function()
            category, catalogPager.page = kind, 1
            message = nil
            refresh()
        end)
    end
    catalogFilter:SetScript("OnTextChanged", function(_, user)
        if user then catalogPager.page = 1; refresh() end
    end)
    catalogFilter:SetScript("OnEnterPressed", function(self) self:ClearFocus(); catalogPager.ChooseFirst() end)

    local targetButtons, conditionButtons = {}, {}
    local function changeGroup(change)
        local _, branch = current()
        if not branch then return end
        update(function(draft)
            local active = draft.body.lines[selectedLine].branches[selectedBranch]
            change(Editor.Group(active, selectedGroup))
        end)
    end
    for index, unit in ipairs(targetChoices) do
        targetButtons[unit] = W.Button(steps[2], 266 + (index - 1) % 2 * 233, 192 + math.floor((index - 1) / 2) * 33,
            226, function() changeGroup(function(group) group.unit = unit ~= "" and unit or nil end) end)
    end
    local targetHint = W.Label(steps[2], 266, 272, 463)
    local targetOverview = W.Label(steps[2], 266, 144, 463)
    for index, predicate in ipairs(conditions) do
        conditionButtons[predicate] = W.Button(steps[3], 266 + (index - 1) % 2 * 233,
            192 + math.floor((index - 1) / 2) * 32, 226, function()
                changeGroup(function(group)
                    local found = false
                    for position = #group.predicates, 1, -1 do
                        local existing = group.predicates[position]
                        if existing == predicate then
                            found = true
                            table.remove(group.predicates, position)
                        elseif (predicate == "help" and existing == "harm") or (predicate == "harm" and existing == "help") then
                            table.remove(group.predicates, position)
                        end
                    end
                    if not found then group.predicates[#group.predicates + 1] = predicate end
                end)
            end)
    end
    local conditionHint = W.Label(steps[3], 266, 328, 463)
    local conditionOverview = W.Label(steps[3], 266, 144, 463)

    local previewPanel = CreateFrame("Frame", nil, steps[4])
    previewPanel:SetAllPoints(steps[4])
    local simulator = studio.CreateSimulator(steps[4], function() refresh() end)
    local simulate = W.Button(steps[4], 423, 485, 194, function()
        simulating, message = not simulating, nil
        refresh()
    end)
    local textBox = W.Box(previewPanel, 266, 127, 466, 105, true)
    local previewLabel = W.Label(previewPanel, 266, 109, 245)
    local previewStatus = W.Label(previewPanel, 517, 109, 215)
    previewStatus:SetJustifyH("RIGHT")
    local counts = W.Label(previewPanel, 266, 238, 466)
    local issueCount = W.Label(previewPanel, 337, 264, 395)
    local issues = W.Label(previewPanel, 266, 291, 466)
    issues:SetSpacing(2)
    local previousIssue = W.Button(previewPanel, 266, 260, 30, function()
        issueIndex = issueIndex - 1
        refresh()
    end)
    local nextIssue = W.Button(previewPanel, 300, 260, 30, function()
        issueIndex = issueIndex + 1
        refresh()
    end)
    previousIssue:SetText("<")
    nextIssue:SetText(">")
    local transfer = W.Label(previewPanel, 266, 392, 466)
    transfer:SetSpacing(2)
    local function selectPreviewText()
        textBox:SetFocus()
        textBox:HighlightText()
        message = "copyHint"
        refresh()
    end
    local copyPreview = W.Button(previewPanel, 266, 358, 170, selectPreviewText)
    local jump = W.Button(previewPanel, 443, 358, 138, function(self)
        local issue = self.issue
        if not issue then return end
        if editor.Get().body.mode == "raw" then
            local text, first = textBox:GetText(), 1
            for _ = 2, issue.line do
                local finish = text:find("\n", first, true)
                if not finish then break end
                first = finish + 1
            end
            local finish = text:find("\n", first, true) or #text + 1
            textBox:SetFocus()
            textBox:SetCursorPosition(first - 1)
            textBox:HighlightText(first - 1, finish - 1)
        else
            selectedLine, selectedBranch, selectedGroup = issue.line, issue.branch or 1, issue.group or 1
            advanced = true
            goTo(issue.code == "unsupported-unit" and 2 or issue.group and 3 or 1)
        end
    end)
    local mode = W.Button(previewPanel, 588, 358, 146, function()
        local body, strings = editor.Get().body, studio.GetStrings()
        if body.mode == "raw" then
            local structured, issue = Compiler.ToStructured(body, Catalog.SpellId, Catalog.SpellName)
            if structured then
                advanced = selectFirstAction(structured) or advanced
                update(function(draft) draft.body = structured end)
            else
                message, conversionIssue = "convertFailed", issue
                refresh()
            end
            return
        end
        StaticPopupDialogs[rawDialog] = {
            text = strings.rawConfirm, button1 = strings.editAsText, button2 = strings.cancel,
            OnShow = studio.ApplyPopupTypeface, OnHide = studio.RestorePopupTypeface,
            OnAccept = function()
                if not editor or editor.Get().body ~= body then return end
                local generated = Compiler.Compile(body, Catalog.SpellName)
                update(function(draft)
                    draft.body = {
                        mode = "raw", text = generated.text or "", sourceLocale = studio.client.locale,
                        structuredBackup = draft.body,
                    }
                end)
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show(rawDialog)
    end)
    textBox:SetScript("OnTextChanged", function(self, user)
        if not user or not editor then return end
        if editor.Get().body.mode == "raw" then
            local input = studio.MacroText.Normalize(self:GetText())
            update(function(draft) draft.body.text = input end, "raw")
        else
            W.SetText(self, self.previewText)
        end
    end)
    textBox:SetScript("OnEditFocusLost", function() if editor then editor.EndEdit() end end)
    title:SetScript("OnTabPressed", function(self)
        self:ClearFocus()
        if step == 1 then catalogFilter:SetFocus() elseif step == 4 and not simulating then textBox:SetFocus() end
    end)
    catalogFilter:SetScript("OnTabPressed", function(self) self:ClearFocus(); title:SetFocus() end)
    textBox:SetScript("OnTabPressed", function(self)
        if editor.Get().body.mode == "structured" then self:ClearFocus(); title:SetFocus() end
    end)

    local saveDescription = W.Label(steps[5], 266, 120, 465)
    local draftCharacter = W.Label(steps[5], 266, 196, 465)
    local saveButton = W.Button(steps[5], 266, 235, 166, save)
    local assignCharacter = W.Button(steps[5], 441, 235, 217, function()
        local character = studio.GetCharacterName()
        if not character or studio.library.issue then return end
        update(function(draft)
            if draft.character == character then
                draft.character = nil
            else
                draft.character = character
            end
        end)
    end)


    local actionIcon = steps[5]:CreateTexture(nil, "ARTWORK")
    actionIcon:SetPoint("TOPLEFT", steps[5], "TOPLEFT", 266, -360)
    actionIcon:SetSize(38, 38)
    actionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    local actionCaption = W.Label(steps[5], 314, 368, 405)
    -- Read-only confirmation; no CreateMacro/EditMacro calls.
    local exportScope = "account"
    local exportHint = W.Label(steps[5], 266, 315, 465)
    local scopeToggle = W.Button(steps[5], 266, 282, 205, function()
        exportScope = exportScope == "account" and "character" or "account"
        refresh()
    end)
    local exportPreview = W.Button(steps[5], 481, 282, 252, function()
        if not editor then return end
        local draft = editor.Get()
        local preview, err = studio.MacroExport.Prepare(draft, exportScope, Catalog.SpellName)
        if not preview then
            local labels = studio.GetStrings()
            exportHint:SetText(labels.exportRejected:format(labels.exportErrors[err] or tostring(err)))
            return
        end
        local strings = studio.GetStrings()
        local selectedScope = exportScope
        StaticPopupDialogs["FMS_EXPORT_PREVIEW"] = {
            text = strings.exportPreviewText:format(
                selectedScope == "account" and strings.accountMacros or strings.characterMacros,
                W.SafeText(preview.name), W.SafeText(preview.text),
                preview.bytes, preview.count, preview.capacity),
            button1 = strings.exportRecheck, button2 = strings.cancel,
            OnShow = studio.ApplyPopupTypeface, OnHide = studio.RestorePopupTypeface,
            OnAccept = function()
                local current, reason = studio.MacroExport.ConfirmPreview(
                    preview, editor and editor.Get(), selectedScope, Catalog.SpellName)
                exportHint:SetText(current and strings.exportReady
                    or strings.exportRejected:format(strings.exportErrors[reason] or tostring(reason)))
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("FMS_EXPORT_PREVIEW")
    end)

    local function renderAction(strings, argument)
        categories.spell:SetText(strings.spellBook)
        categories.item:SetText(strings.bags)
        categories.slot:SetText(strings.trinkets)
        for kind, button in pairs(categories) do
            if kind == category then button:LockHighlight() else button:UnlockHighlight() end
        end
        catalogFilterLabel:SetText(strings.search)
        local entries, state
        if category == "slot" then
            entries = {
                { kind = "slot", token = "13", name = strings.trinket1 },
                { kind = "slot", token = "14", name = strings.trinket2 },
            }
        else
            entries, state = Catalog.Get(category)
        end
        local results, query = {}, W.Lower(catalogFilter:GetText())
        for _, entry in ipairs(entries) do
            if W.Lower(entry.name):find(query, 1, true) then results[#results + 1] = entry end
        end
        catalogPager.Render(results, function(entry) return entry.name end, function(entry)
            if not argument or entry.kind ~= argument.kind then return false end
            if entry.kind == "slot" then return entry.token == argument.token end
            return entry.id == argument.id
        end)
        catalogStatus:SetText(state and strings[state] or #results == 0 and strings.catalogEmpty or "")
        selectionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        selectionName:SetText(argument and W.SafeText(actionName(argument, strings) or strings.noAction) or strings.noAction)
        if argument and argument.kind == "spell" and type(argument.id) == "number"
            and C_Spell and type(C_Spell.GetSpellTexture) == "function" then
            local ok, texture = pcall(C_Spell.GetSpellTexture, argument.id)
            if ok and (type(texture) == "number" or type(texture) == "string") then
                selectionIcon:SetTexture(texture)
            end
        end
    end

    local function renderPreview(strings, draft, preview)
        local raw = draft.body.mode == "raw"
        local visible = raw and draft.body.text or preview.text or ""
        textBox.previewText = visible
        W.SetText(textBox, visible)
        previewLabel:SetText(raw and strings.rawMacro or strings.generatedMacro)
        previewStatus:SetText(preview.canCopy and strings.previewReady or strings.previewBlocked)
        if preview.canCopy then
            previewStatus:SetTextColor(0.65, 0.9, 0.58)
        else
            previewStatus:SetTextColor(1, 0.67, 0.52)
        end
        transfer:SetText(strings.guide.transfer)
        transfer:SetShown(preview.canCopy)
        counts:SetText(preview.characters and strings.previewLength:format(preview.characters, preview.characterLimit, preview.bytes)
            or strings.previewIncomplete)
        if issueBody ~= draft.body then
            issueBody, issueIndex = draft.body, 1
        end
        local total = #preview.diagnostics
        issueIndex = cap(issueIndex, total)
        local issue = preview.diagnostics[issueIndex]
        local detail = strings.branchOrder
        if issue then
            local prefix = issue.severity == "error" and strings.errorPrefix or strings.warningPrefix
            local location = issue.line and strings.lineNumber:format(issue.line) or ""
            if issue.branch then location = location .. strings.branchNumber:format(issue.branch) end
            if issue.group then location = location .. strings.groupNumber:format(issue.group) end
            detail = prefix .. location .. (strings.diagnostic[issue.reason or issue.code] or issue.code)
        end
        issueCount:SetText(total > 0 and strings.issueCount:format(issueIndex, total) or "")
        issueCount:SetPoint("TOPLEFT", total > 1 and 337 or 266, -264)
        previousIssue:SetShown(total > 1)
        nextIssue:SetShown(total > 1)
        previousIssue:SetEnabled(issueIndex > 1)
        nextIssue:SetEnabled(issueIndex < total)
        issues:SetText(detail)
        if issue and issue.severity == "error" then
            issues:SetTextColor(1, 0.58, 0.48)
        else
            issues:SetTextColor(0.95, 0.87, 0.60)
        end
        jump.issue = issue and issue.line and issue or nil
        jump:SetText(not raw and issue and issue.branch and strings.inspectRule or strings.inspectLine)
        jump:SetShown(jump.issue ~= nil)
        mode:SetText(raw and strings.convertToEditor or strings.editAsText)
        copyPreview:SetText(strings.selectMacro)
        copyPreview:SetEnabled(preview.canCopy)
    end

    local function renderSummary(strings, raw, branch, group, branchCount, picked)
        local guide = strings.guide
        local action, target, rules = summarizeBranch(branch, group, branchCount, advanced, strings)
        local values = { action, target, rules }
        summary:SetText(guide.summaryTitle)
        for index, button in ipairs(stepButtons) do
            local title = raw and index == 4 and guide.summaryRaw or guide.summarySteps[index]
            local value = values[index]
            button:SetText(value and ("%d  %s · %s"):format(index, title, value) or ("%d  %s"):format(index, title))
            button:SetShown(not raw or index >= 4)
            button:SetPoint("TOPLEFT", 24, -(111 + (index - (raw and 4 or 1)) * 26))
            button:SetEnabled(index == 1 or index == step or raw or advanced or picked == true)
            if index == step then button:LockHighlight() else button:UnlockHighlight() end
        end
    end

    refresh = function()
        if not editor then return end
        local strings, draft = studio.GetStrings(), editor.Get()
        local guide = strings.guide
        local raw = draft.body.mode == "raw"
        if raw and step < 4 then step = 4 end
        local line, branch, group, lineCount, branchCount, groupCount = current()
        local argument = branch and branch.argument
        local picked = argument and (argument.id ~= nil
            or (argument.kind == "slot" or argument.kind == "name") and argument.token ~= "")
        local guidedGroups = not advanced and groupCount > 1

        libraryButton:SetText(strings.library)
        titleLabel:SetText(strings.draftTitle)
        W.SetText(title, draft.title)
        undo:SetText(strings.undo)
        redo:SetText(strings.redo)
        undo:SetEnabled(editor.CanUndo())
        redo:SetEnabled(editor.CanRedo())
        stepTitle:SetText(strings.stepTitle:format(step, guide.steps[step]))
        progress:SetValue(step)
        local compact = Compiler.Compile(draft.body, Catalog.SpellName)
        miniTitle:SetText(strings.generatedMacro)
        local firstLine = type(compact.text) == "string" and compact.text:match("[^\r\n]+") or ""
        miniText:SetText(W.SafeText(firstLine or ""))
        back:SetText(strings.back)
        back:SetEnabled(step > (raw and 4 or 1))
        nextStep:SetText(strings.nextStep)
        nextStep:SetEnabled(step < 5 and (step ~= 1 or advanced or picked == true))
        local note = message and strings[message] or ""
        if message == "convertFailed" and conversionIssue then
            local reason = conversionIssue.name and strings.conversionSpell:format(W.SafeText(conversionIssue.name))
                or strings.diagnostic[conversionIssue.code]
            if reason then
                local location = conversionIssue.line and strings.lineNumber:format(conversionIssue.line) or ""
                note = strings.conversionReason:format(location .. reason)
            end
        end
        feedback:SetText(note)
        renderSummary(strings, raw, branch, group, branchCount, picked)
        outline:SetShown(advanced and not raw)
        groupPanel:SetShown(advanced and not raw and (step == 2 or step == 3))
        guidePanel:SetShown(step ~= 5 and (raw or not advanced))
        guideTitle:SetText(step == 4 and guide.behavior or guide.howTo)
        guideText:SetText(step == 4 and describeMacro(draft.body, strings) or guide.lessons[step])
        showAdvanced:SetShown(not raw)
        showAdvanced:SetText(advanced and guide.simple or guide.advanced)
        for index, page in ipairs(steps) do page:SetShown(index == step) end

        if not raw then
            local command = line and (line.command or line.directive) or ""
            lineNav.Render(strings.lineNav:format(lineCount > 0 and selectedLine or 0, lineCount, command),
                selectedLine, lineCount, true)
            branchNav.Render(strings.branchNav:format(branchCount > 0 and selectedBranch or 0, branchCount),
                selectedBranch, branchCount, line ~= nil)
            tooltip:SetText(strings.toggleTooltip)
        end
        if step == 1 then
            renderAction(strings, argument)
        elseif step == 2 or step == 3 then
            groupNav.Render(strings.groupNav:format(groupCount > 0 and selectedGroup or 0, groupCount),
                selectedGroup, groupCount, branch ~= nil)
            local rules = guidedGroups and describeGroups(branch.groups, strings) or ""
            targetOverview:SetText(rules)
            conditionOverview:SetText(rules)
            targetHint:SetText(guidedGroups and guide.prepared or advanced and branch and strings.targetHint or "")
            conditionHint:SetText(guidedGroups and guide.prepared or advanced and branch and strings.conditionHint or "")
            for unit, button in pairs(targetButtons) do
                button:SetText(strings.targets[unit])
                button:SetShown(not guidedGroups)
                button:SetEnabled(branch ~= nil)
                if unit == (group and group.unit or "") then button:LockHighlight() else button:UnlockHighlight() end
            end
            local active = {}
            for _, predicate in ipairs(group and group.predicates or {}) do active[predicate] = true end
            for predicate, button in pairs(conditionButtons) do
                button:SetText(strings.conditions[predicate])
                button:SetShown(not guidedGroups)
                button:SetEnabled(branch ~= nil)
                if active[predicate] then button:LockHighlight() else button:UnlockHighlight() end
            end
        else
            local preview = Compiler.Compile(draft.body, Catalog.SpellName)
            if step == 4 then
                simulator.panel:SetShown(simulating)
                previewPanel:SetShown(not simulating)
                simulate:SetText(simulating and strings.simulator.back or strings.simulator.open)
                simulate:SetEnabled(simulating or preview.canCopy)
                if simulating then
                    simulator.Render(preview, strings)
                else
                    renderPreview(strings, draft, preview)
                end
            else
                saveDescription:SetText(studio.library.issue and strings.storageInvalid
                    or preview.canCopy and guide.lessons[5] or strings.saveIncomplete)
                local character = studio.GetCharacterName()
                local assigned = draft.character and W.SafeText(draft.character) or strings.unassignedCharacter
                draftCharacter:SetText(strings.draftCharacter:format(assigned))
                assignCharacter:SetText(character and draft.character == character
                    and strings.clearCharacter or strings.assignCharacter)
                assignCharacter:SetEnabled(character ~= nil and not studio.library.issue)
                saveButton:SetText(strings.saveDraft)
                saveButton:SetEnabled(not studio.library.issue)
                scopeToggle:SetText(exportScope == "account" and strings.accountMacros or strings.characterMacros)
                exportPreview:SetText(strings.exportPreviewButton)
                exportPreview:SetEnabled(preview.canCopy)
                exportHint:SetText(strings.exportReadOnly)
                actionCaption:SetText(W.SafeText(draft.title ~= "" and draft.title or strings.untitledDraft))
                actionIcon:SetTexture(selectionIcon:GetTexture() or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end

    function view.Start(draft, raw, starter, options)
        editor = Editor.Open(draft, raw, studio.client.locale, starter)
        local body = editor.Get().body
        step = (body.mode == "raw" or starter and starter.action or options and options.preview) and 4 or 1
        local complex = selectFirstAction(body)
        advanced = not starter and complex
        simulating = false
        exportScope = "account"
        simulator.Reset()
        conversionIssue = options and options.conversionIssue
        category, message = "spell", conversionIssue and "convertFailed" or nil
        catalogPager.page = 1
        catalogLayout:SetText(catalogColumns == 1 and "1 sloupec" or "2 sloupce")
        W.SetText(catalogFilter, "")
        frame:Show()
        refresh()
        if raw and not draft then textBox:SetFocus() end
    end

    function view.SetCompact(compact)
        W.Reflow(frame, compact, "wizard")
        local desired = compact and 1 or 2
        if catalogColumns ~= desired then
            catalogColumns = desired
            catalogLayout:SetText(desired == 1 and "1 sloupec" or "2 sloupce")
            catalogPager.SetColumns(desired)
        end
    end
    function view.IsOpen() return editor ~= nil end
    function view.Refresh() refresh() end
    return view
end
