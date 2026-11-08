local _, studio = ...
local Simulator = {}
studio.Simulator = Simulator

Simulator.states = { "none", "friendly", "hostile", "neutral", "deadFriendly", "deadHostile" }
Simulator.modifiers = { "mod:shift", "mod:ctrl", "mod:alt" }
local states = {
    none = { nodead = true },
    friendly = { exists = true, help = true, nodead = true },
    hostile = { exists = true, harm = true, nodead = true },
    neutral = { exists = true, nodead = true },
    deadFriendly = { exists = true, help = true },
    deadHostile = { exists = true, harm = true },
}

local function matches(group, scenario)
    local unit = group.unit or "target"
    local state = unit == "player" and states.friendly or states[scenario[unit]] or states.none
    for _, predicate in ipairs(group.predicates) do
        if not state[predicate] and not scenario.modifiers[predicate] then return false end
    end
    return true
end

local function choose(parsed, scenario)
    for index, branch in ipairs(parsed.branches) do
        if #branch.groups == 0 then return branch.value, index end
        for groupIndex, group in ipairs(branch.groups) do
            if matches(group, scenario) then return branch.value, index, groupIndex, group end
        end
    end
end

function Simulator.Evaluate(text, scenario)
    local results, line = {}, 0
    for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line + 1
        local content = studio.MacroText.Trim(rawLine)
        if content ~= "" then
            local parsed = studio.MacroSyntax.ParseLine(content)
            if parsed and (parsed.command == "/cast" or parsed.command == "/use") then
                local value, branch, groupIndex, group = choose(parsed, scenario)
                results[#results + 1] = {
                    line = line, command = parsed.command, value = value, branch = branch,
                    groupIndex = groupIndex, group = group,
                }
            end
        end
    end
    return results
end
