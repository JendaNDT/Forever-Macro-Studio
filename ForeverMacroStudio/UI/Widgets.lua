local _, studio = ...
local Widgets = {}
studio.Widgets = Widgets

function Widgets.Label(parent, x, y, width, large)
    local text = parent:CreateFontString(nil, "ARTWORK", large and "GameFontNormalLarge" or "GameFontHighlight")
    studio.ApplyTypeface(text)
    text:SetPoint("TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end

function Widgets.Button(parent, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    studio.ApplyButtonTypeface(button)
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, -y)
    button:SetScript("OnClick", action)
    return button
end

function Widgets.Box(parent, x, y, width, height, multiline)
    local holder = parent
    if multiline then
        holder = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        holder:SetSize(width - 20, height)
        holder:SetPoint("TOPLEFT", x, -y)
        local background = holder:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(holder)
        background:SetColorTexture(0, 0, 0, 0.45)
    end
    local template
    if not multiline then template = "InputBoxTemplate" end
    local edit = CreateFrame("EditBox", nil, holder, template)
    if multiline then
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(width - 22)
        edit:SetTextInsets(4, 4, 2, 2)
        holder:SetScrollChild(edit)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
            local top, scroll = -y, holder:GetVerticalScroll()
            local bottom = top + cursorHeight
            if top < scroll then
                holder:SetVerticalScroll(math.max(0, top))
            elseif bottom > scroll + height then
                holder:SetVerticalScroll(math.min(holder:GetVerticalScrollRange(), bottom - height))
            end
        end)
    else
        edit:SetSize(width, height)
        edit:SetPoint("TOPLEFT", x, -y)
    end
    edit:SetAutoFocus(false)
    studio.ApplyTypeface(edit)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    return edit, holder
end

function Widgets.SetText(edit, value)
    if edit:GetText() ~= value then edit:SetText(value) end
end

function Widgets.SafeText(text)
    return (text:gsub("|", "||"):gsub("[%c]", " "))
end

local accented = {
    ["Á"]="á", ["Č"]="č", ["Ď"]="ď", ["É"]="é", ["Ě"]="ě", ["Í"]="í", ["Ň"]="ň", ["Ó"]="ó",
    ["Ř"]="ř", ["Š"]="š", ["Ť"]="ť", ["Ú"]="ú", ["Ů"]="ů", ["Ý"]="ý", ["Ž"]="ž",
}

function Widgets.Lower(text)
    return (text:lower():gsub("[\194-\223][\128-\191]", accented))
end

function Widgets.Pager(parent, x, y, width, rowCount, refresh, choose)
    local pager = { page = 1 }
    local rows = {}
    for index = 1, rowCount do
        rows[index] = Widgets.Button(parent, x, y + (index - 1) * 27, width, function(self)
            if self.entry then choose(self.entry) end
        end)
        local label = rows[index]:GetFontString()
        label:SetWordWrap(false)
        label:SetMaxLines(1)
    end
    local navY = y + rowCount * 27 + 2
    local previous = Widgets.Button(parent, x, navY, 36, function()
        pager.page = pager.page - 1
        refresh()
    end)
    local nextPage = Widgets.Button(parent, x + width - 36, navY, 36, function()
        pager.page = pager.page + 1
        refresh()
    end)
    previous:SetText("<")
    nextPage:SetText(">")
    local indicator = Widgets.Label(parent, x + 46, navY + 4, width - 92)
    indicator:SetJustifyH("CENTER")

    function pager.Render(entries, label, selected)
        local pages = math.max(1, math.ceil(#entries / rowCount))
        pager.page = math.max(1, math.min(pager.page, pages))
        local offset = (pager.page - 1) * rowCount
        for index, row in ipairs(rows) do
            local entry = entries[offset + index]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then row:SetText(Widgets.SafeText(label(entry))) end
            if entry and selected and selected(entry) then row:LockHighlight() else row:UnlockHighlight() end
        end
        previous:SetEnabled(pager.page > 1)
        nextPage:SetEnabled(pager.page < pages)
        indicator:SetText(("%d / %d"):format(pager.page, pages))
    end

    function pager.ChooseFirst()
        if rows[1].entry then choose(rows[1].entry) end
    end

    return pager
end
