local addonName, studio = ...
local typeface = ("Interface\\AddOns\\%s\\Fonts\\SourceSans3-Regular.ttf"):format(addonName)
local buttonStates = { "Normal", "Highlight", "Disabled" }
local buttonFonts, buttonFontCount = {}, 0
local popupFonts = {}

function studio.ApplyTypeface(widget)
    local _, height, flags = widget:GetFont()
    widget:SetFont(typeface, height, flags or "")
end

function studio.ApplyButtonTypeface(button)
    for _, state in ipairs(buttonStates) do
        local original = button["Get" .. state .. "FontObject"](button)
        if original then
            local font = buttonFonts[original]
            if not font then
                buttonFontCount = buttonFontCount + 1
                font = CreateFont(addonName .. "ButtonFont" .. buttonFontCount)
                font:SetFontObject(original)
                studio.ApplyTypeface(font)
                buttonFonts[original] = font
            end
            button["Set" .. state .. "FontObject"](button, font)
        end
    end
end

function studio.ApplyPopupTypeface(dialog)
    if popupFonts[dialog] then return end
    local text = dialog:GetTextFontString()
    local path, height, flags = text:GetFont()
    local original = { text = text, path = path, height = height, flags = flags, buttons = {} }
    popupFonts[dialog] = original
    studio.ApplyTypeface(text)
    for index = 1, 3 do
        local button = dialog:GetButton(index)
        if button and button:IsShown() then
            local fonts = {}
            for _, state in ipairs(buttonStates) do
                fonts[state] = button["Get" .. state .. "FontObject"](button)
            end
            original.buttons[button] = fonts
            studio.ApplyButtonTypeface(button)
        end
    end
end

function studio.RestorePopupTypeface(dialog)
    local original = popupFonts[dialog]
    if not original then return end
    popupFonts[dialog] = nil
    original.text:SetFont(original.path, original.height, original.flags or "")
    for button, fonts in pairs(original.buttons) do
        for state, font in pairs(fonts) do
            button["Set" .. state .. "FontObject"](button, font)
        end
    end
end
