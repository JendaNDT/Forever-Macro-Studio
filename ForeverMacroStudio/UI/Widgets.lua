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


-- Two-column visual catalog; 6 entries per page, with icons and keyboard-friendly buttons.
function Widgets.CatalogCards(parent, x, y, width, refresh, choose)
    local pager = { page = 1 }
    local rows = {}
    local cardWidth = math.floor((width - 10) / 2)
    local fallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    for index = 1, 6 do
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local button = Widgets.Button(parent, x + col * (cardWidth + 10), y + row * 60, cardWidth,
            function(self) if self.entry then choose(self.entry) end end)
        button:SetHeight(54)
        local label = button:GetFontString()
        label:ClearAllPoints()
        label:SetPoint("LEFT", button, "LEFT", 50, 0)
        label:SetWidth(cardWidth - 56)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetMaxLines(2)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", button, "LEFT", 8, 0)
        icon:SetSize(36, 36)
        rows[index] = { button = button, icon = icon }
    end
    local navY = y + 185
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

    function pager.SetColumns(value)
        local columns = value == 1 and 1 or 2
        local cardWidth = math.floor((width - (columns - 1) * 10) / columns)
        for index, card in ipairs(rows) do
            local col = (index - 1) % columns
            local line = math.floor((index - 1) / columns)
            card.button:ClearAllPoints()
            card.button:SetPoint("TOPLEFT", parent, "TOPLEFT", x + col * (cardWidth + 10), -(y + line * (columns == 1 and 30 or 60)))
            card.button:SetSize(cardWidth, columns == 1 and 28 or 54)
            card.button:GetFontString():SetWidth(cardWidth - (columns == 1 and 42 or 56))
            card.icon:SetSize(columns == 1 and 22 or 36, columns == 1 and 22 or 36)
        end
        pager.page = 1
        refresh()
    end

    function pager.Render(entries, label, selected)
        local pages = math.max(1, math.ceil(#entries / 6))
        pager.page = math.max(1, math.min(pager.page, pages))
        local offset = (pager.page - 1) * 6
        for index, card in ipairs(rows) do
            local entry = entries[offset + index]
            card.button.entry = entry
            card.button:SetShown(entry ~= nil)
            if entry then
                card.button:SetText(Widgets.SafeText(label(entry)))
                local texture = entry.icon
                if entry.kind == "spell" and type(entry.id) == "number"
                    and C_Spell and type(C_Spell.GetSpellTexture) == "function" then
                    local ok, result = pcall(C_Spell.GetSpellTexture, entry.id)
                    if ok and (type(result) == "number" or type(result) == "string") then texture = result end
                elseif entry.kind == "item" and type(entry.id) == "number"
                    and C_Item and type(C_Item.GetItemIconByID) == "function" then
                    local ok, result = pcall(C_Item.GetItemIconByID, entry.id)
                    if ok and (type(result) == "number" or type(result) == "string") then texture = result end
                end
                card.icon:SetTexture(texture or fallback)
                if selected and selected(entry) then card.button:LockHighlight()
                else card.button:UnlockHighlight() end
            end
        end
        previous:SetEnabled(pager.page > 1)
        nextPage:SetEnabled(pager.page < pages)
        indicator:SetText(("%d / %d"):format(pager.page, pages))
    end

    function pager.ChooseFirst()
        if rows[1].button.entry then choose(rows[1].button.entry) end
    end
    return pager
end

-- Reflow anchored controls between wide and stacked layouts.
-- Original anchors are retained so switching modes never accumulates offsets.
local originalAnchors = setmetatable({}, { __mode = "k" })
function Widgets.Reflow(root, compact, kind)
    local function visit(container)
        local function reposition(region)
            if not region.GetNumPoints or region:GetNumPoints() ~= 1 then return end
            local point, relative, relativePoint, x, y = region:GetPoint(1)
            if point ~= "TOPLEFT" or relative ~= container or type(x) ~= "number" or type(y) ~= "number" then return end
            local base = originalAnchors[region]
            if not base then
                base = { x = x, y = y }
                originalAnchors[region] = base
            end
            local nx, ny = base.x, base.y
            if compact then
                if kind == "wizard" then
                    if base.y <= -80 and base.x >= 250 then nx, ny = base.x - 242, base.y - 430 end
                    if base.y <= -480 and base.x < 250 then ny = base.y - 430 end
                    if base.x < 250 and base.y <= -455 and base.y > -480 then ny = base.y - 430 end
                elseif kind == "library" then
                    if base.x >= 455 then nx, ny = base.x - 448, base.y - 430 end
                    if base.y <= -480 and base.x < 455 then ny = base.y - 430 end
                end
            end
            if nx ~= x or ny ~= y then
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", container, "TOPLEFT", nx, ny)
            end
        end
        local regions = { container:GetRegions() }
        for _, region in ipairs(regions) do reposition(region) end
        local children = { container:GetChildren() }
        for _, child in ipairs(children) do
            reposition(child)
            visit(child)
        end
    end
    visit(root)
end
function Widgets.Pager(parent, x, y, width, rowCount, refresh, choose, sideActions)
    local pager = { page = 1 }
    local rows, actions = {}, {}
    sideActions = sideActions or {}
    local rowWidth = width
    for _, action in ipairs(sideActions) do rowWidth = rowWidth - action.width - 5 end
    for index = 1, rowCount do
        local rowY = y + (index - 1) * 27
        local row = Widgets.Button(parent, x, rowY, rowWidth, function(self)
            if self.entry then choose(self.entry) end
        end)
        rows[index] = row
        local label = row:GetFontString()
        label:SetWordWrap(false)
        label:SetMaxLines(1)
        actions[index] = {}
        local actionX = x + rowWidth + 5
        for actionIndex, action in ipairs(sideActions) do
            actions[index][actionIndex] = Widgets.Button(parent, actionX, rowY, action.width, function()
                if row.entry then action.choose(row.entry) end
            end)
            actionX = actionX + action.width + 5
        end
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

    function pager.Render(entries, label, selected, actionsEnabled)
        local pages = math.max(1, math.ceil(#entries / rowCount))
        pager.page = math.max(1, math.min(pager.page, pages))
        local offset = (pager.page - 1) * rowCount
        for index, row in ipairs(rows) do
            local entry = entries[offset + index]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then row:SetText(Widgets.SafeText(label(entry))) end
            if entry and selected and selected(entry) then row:LockHighlight() else row:UnlockHighlight() end
            for actionIndex, button in ipairs(actions[index]) do
                button:SetShown(entry ~= nil)
                if entry then button:SetText(sideActions[actionIndex].label(entry)) end
                button:SetEnabled(actionsEnabled == true)
            end
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
