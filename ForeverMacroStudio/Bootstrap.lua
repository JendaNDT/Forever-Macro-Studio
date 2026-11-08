local addonName, studio = ...

local function printCompilerPreview(strings)
    local body = { mode = "structured", lines = {
        { directive = "#showtooltip", branches = {} },
        { command = "/use", branches = {
            { groups = { { predicates = { "mod:shift" } } }, argument = { kind = "slot", token = "13" } },
            { groups = { { predicates = {} } }, argument = { kind = "slot", token = "14" } },
        } },
    } }
    local preview = studio.Compiler.Compile(body)
    if not preview.canCopy then return print(strings.compilerPreviewFailed) end
    print(strings.compilerPreview:format(preview.characters, preview.characterLimit, preview.bytes))
    for line in preview.text:gmatch("[^\n]+") do print(line) end
end

local function onCommand(message)
    local command, rest = message:match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" then return studio.ToggleWindow() end

    local strings = studio.GetStrings()
    if command == "debug" and rest == "compiler" then return printCompilerPreview(strings) end
    if command == "debug" and rest == "" then
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
        print("Forever Macro Studio " .. version)
        for _, line in ipairs(studio.GetStatusLines(strings)) do print(line) end
        return
    end
    if command == "probe" then
        local probe = SlashCmdList.FMS_E00_PROBE
        if probe then return probe(rest) end
        return print(strings.probeUnavailable)
    end
    if command == "rescue" and rest == "" then
        local text = studio.library.RescueText()
        if text then return studio.ShowRescue(strings, text) end
        return print(strings.rescueEmpty)
    end
    print(strings.help)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(frame, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        frame:UnregisterEvent(event)
        local library, root = studio.OpenLibrary(ForeverMacroStudioDB, time)
        if root then ForeverMacroStudioDB = root end
        studio.library = library
        studio.preferences = library.preferences
        studio.client = studio.ReadClient()

        SLASH_FOREVER_MACRO_STUDIO1 = "/fms"
        SlashCmdList.FOREVER_MACRO_STUDIO = onCommand
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        for _, catalogEvent in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }) do
            frame:RegisterEvent(catalogEvent)
        end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if studio.Catalog.Invalidate(event, arg1, arg2) then studio.RefreshWindow() end
        end)
        return
    end
    studio.Catalog.Invalidate(event, arg1, arg2)
    studio.RefreshWindow()
end)
