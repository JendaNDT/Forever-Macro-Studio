local _, studio = ...
local W, Simulator = studio.Widgets, studio.Simulator

function studio.CreateSimulator(parent, refresh)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)
    local view = { panel = panel }
    local selection, modifiers, page = {}, {}, 1
    local intro = W.Label(panel, 266, 113, 466)
    local targetButtons, modifierButtons = {}, {}
    for index, unit in ipairs({ "target", "mouseover" }) do
        local selected = unit
        targetButtons[selected] = W.Button(panel, 266 + (index - 1) * 235, 164, 228, function()
            selection[selected] = selection[selected] % #Simulator.states + 1
            refresh()
        end)
    end
    for index, predicate in ipairs(Simulator.modifiers) do
        local modifier = predicate
        modifierButtons[modifier] = W.Button(panel, 266 + (index - 1) * 158, 207, 149, function()
            modifiers[modifier] = not modifiers[modifier]
            refresh()
        end)
    end
    local previous = W.Button(panel, 266, 254, 33, function() page = page - 1; refresh() end)
    local following = W.Button(panel, 699, 254, 33, function() page = page + 1; refresh() end)
    previous:SetText("<")
    following:SetText(">")
    local indicator = W.Label(panel, 308, 258, 380)
    indicator:SetJustifyH("CENTER")
    local outcome = W.Label(panel, 266, 297, 466)
    outcome:SetSpacing(4)
    local boundary = W.Label(panel, 266, 407, 466)

    function view.Reset()
        selection.target, selection.mouseover, modifiers, page = 1, 1, {}, 1
    end

    function view.Render(preview, strings)
        local sim = strings.simulator
        intro:SetText(sim.intro)
        boundary:SetText(sim.boundary)
        local scenario = { modifiers = modifiers }
        for unit, button in pairs(targetButtons) do
            local state = Simulator.states[selection[unit]]
            scenario[unit] = state
            button:SetText(sim.unit:format(strings.targets[unit], sim.states[state]))
        end
        for predicate, button in pairs(modifierButtons) do
            button:SetText(strings.conditions[predicate])
            if modifiers[predicate] then button:LockHighlight() else button:UnlockHighlight() end
        end
        local results = preview.canCopy and Simulator.Evaluate(preview.text, scenario) or {}
        page = math.max(1, math.min(page, #results))
        previous:SetEnabled(page > 1)
        following:SetEnabled(page < #results)
        local result = results[page]
        indicator:SetText(result and sim.position:format(page, #results, result.line) or "")
        if not result then
            outcome:SetText(preview.canCopy and sim.noActions or sim.invalid)
        elseif not result.value then
            outcome:SetText(sim.noMatch)
        else
            local group = result.group
            local action = sim.action:format(W.SafeText(result.value), strings.targets[group and group.unit or ""])
            local conditions = {}
            for _, predicate in ipairs(group and group.predicates or {}) do
                conditions[#conditions + 1] = strings.conditions[predicate]
            end
            local rule = group and sim.group:format(result.branch, result.groupIndex) or sim.branch:format(result.branch)
            local why = #conditions > 0 and sim.match:format(table.concat(conditions, ", ")) or sim.unconditional
            local absent = group and scenario[group.unit] == "none" and "\n" .. sim.absent or ""
            outcome:SetText(action .. "\n" .. rule .. "\n" .. why .. absent)
        end
    end

    view.Reset()
    return view
end
