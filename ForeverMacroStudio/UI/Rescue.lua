local _, studio = ...
local window

local function createWindow()
    local frame = CreateFrame("Frame", "ForeverMacroStudioRescueFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(560, 385)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()
    studio.ApplyTypeface(frame.TitleText)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -40)
    scroll:SetPoint("BOTTOMRIGHT", -34, 18)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    studio.ApplyTypeface(edit)
    edit:SetWidth(508)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(frame.export)
            self:HighlightText()
        end
    end)
    frame:SetScript("OnHide", function() edit:ClearFocus() end)
    scroll:SetScrollChild(edit)

    frame.EditBox = edit
    tinsert(UISpecialFrames, frame:GetName())
    return frame
end

function studio.ShowRescue(strings, text)
    window = window or createWindow()
    window.export = text
    window.TitleText:SetText(strings.rescueTitle)
    window.EditBox:SetText(text)
    window:Show()
    window.EditBox:SetFocus()
    window.EditBox:HighlightText()
end
