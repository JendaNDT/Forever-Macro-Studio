-- Exercises the wizard through the same buttons and slash command as the addon.
local addon, studio = "ForeverMacroStudio", {}
local frames, globals = {}, {}
local popup, popupDialog, focus
local methods = {}

function methods:SetScript(event, handler) self[event] = handler end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:GetName() return self.name end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:GetNumPoints() return self.point and 1 or 0 end
function methods:GetPoint()
    local anchor, relative, relativePoint, x, y = unpack(self.point)
    if type(relative) == "number" then return anchor, self.parent, anchor, relative, relativePoint end
    return anchor, relative, relativePoint, x, y
end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale = scale end
function methods:SetTexture(texture) self.texture = texture end
function methods:GetTexture() return self.texture end
function methods:SetValue(value) self.value = value end
function methods:GetFont() return self.font or "default.ttf", 12, "" end
function methods:SetFont(path) self.font = path end
function methods:SetFontObject(font) self.fontObject = font end
function methods:SetShown(shown)
    if self.shown == shown then return end
    self.shown = shown
    local script = shown and self.OnShow or not shown and self.OnHide
    if script then script(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(text)
    self.text = text
    if self.OnTextChanged then self:OnTextChanged(false) end
end
function methods:GetText() return self.text or "" end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:LockHighlight() self.highlight = true end
function methods:UnlockHighlight() self.highlight = false end
function methods:SetFocus()
    if focus and focus ~= self then focus:ClearFocus() end
    focus = self
end
function methods:ClearFocus()
    if focus == self then
        focus = nil
        if self.OnEditFocusLost then self:OnEditFocusLost() end
    end
end
function methods:HighlightText(first, last) self.highlightedText = self.text:sub((first or 0) + 1, last) end
function methods:SetScrollChild(child) self.child = child end
local function members(parent, regions)
    local children = {}
    for _, frame in ipairs(frames) do
        local isRegion = frame.kind == "FontString" or frame.kind == "Texture"
        if frame.parent == parent and isRegion == regions then children[#children + 1] = frame end
    end
    return unpack(children)
end
function methods:GetRegions() return members(self, true) end
function methods:GetChildren() return members(self, false) end
for _, name in ipairs({
    "SetAllPoints", "SetFrameStrata", "SetJustifyH", "SetSpacing", "SetWordWrap",
    "SetMaxLines", "SetMultiLine", "SetAutoFocus", "SetTextInsets", "SetTextColor", "SetCursorPosition", "SetColorTexture",
    "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetMovable", "EnableMouse", "RegisterForDrag",
    "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "EnableMouseWheel",
}) do
    methods[name] = function() end
end

local function object(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, shown = true, enabled = true, events = {} },
        { __index = methods })
    frames[#frames + 1] = frame
    if name then globals[name] = frame end
    return frame
end
function methods:CreateFontString() return object("FontString", nil, self) end
function methods:CreateTexture() return object("Texture", nil, self) end
function methods:GetFontString() return self.label end
local stockFonts = {}
for _, state in ipairs({ "Normal", "Highlight", "Disabled" }) do
    stockFonts[state] = object("Font")
    methods["Get" .. state .. "FontObject"] = function(self) return self[state] or stockFonts[state] end
    methods["Set" .. state .. "FontObject"] = function(self, font) self[state] = font end
end
function CreateFont(name) return object("Font", name) end
function CreateFrame(kind, name, parent, template)
    local frame = object(kind, name, parent)
    if template == "BasicFrameTemplateWithInset" then
        frame.TitleText = frame:CreateFontString()
        frame.CloseButton = object("Button", nil, frame)
    elseif kind == "Button" then
        frame.label = frame:CreateFontString()
    end
    return frame
end

UIParent, ChatFontNormal = object("Frame"), object("Font")
UIParent:SetSize(1200, 900)
UISpecialFrames, StaticPopupDialogs, SlashCmdList, tinsert = {}, {}, {}, table.insert
function StaticPopup_Show(id)
    popup = assert(StaticPopupDialogs[id])
    if not popupDialog then
        popupDialog = object("Frame")
        popupDialog.textRegion = popupDialog:CreateFontString()
        popupDialog.buttons = {}
        for index = 1, 3 do popupDialog.buttons[index] = CreateFrame("Button", nil, popupDialog) end
        function popupDialog:GetTextFontString() return self.textRegion end
        function popupDialog:GetButton(index) return self.buttons[index] end
    end
    popupDialog.textRegion:SetText(popup.text)
    for index, control in ipairs(popupDialog.buttons) do
        local label = popup["button" .. index]
        control:SetShown(label ~= nil)
        if label then control:SetText(label) end
    end
    popupDialog:Show()
    if popup.OnShow then popup.OnShow(popupDialog) end
    return popupDialog
end
local function respond(action)
    assert(popupDialog.textRegion.font:find("SourceSans3-Regular.ttf", 1, true))
    for _, control in ipairs(popupDialog.buttons) do
        if control:IsShown() then
            for state, original in pairs(stockFonts) do
                local font = control["Get" .. state .. "FontObject"](control)
                assert(font ~= original and font.font:find("SourceSans3-Regular.ttf", 1, true))
            end
        end
    end
    popup[action](popupDialog)
    popupDialog:Hide()
    if popup.OnHide then popup.OnHide(popupDialog) end
    assert(popupDialog.textRegion.font == "default.ttf")
    for _, control in ipairs(popupDialog.buttons) do
        for state, original in pairs(stockFonts) do
            assert(control["Get" .. state .. "FontObject"](control) == original)
        end
    end
end
function GetBuildInfo() return "1.60.1", "70862", "Nov 6 2026", 16001 end
function GetLocale() return "enUS" end
local playerClass = "WARLOCK"
function UnitClass() return playerClass, playerClass end
local playerName = "Jaina"
function UnitFullName() return playerName, "Example" end
function InCombatLockdown() return false end
function time() return 100 end
function CreateMacro() error("Wizard must not create WoW macros") end
function EditMacro() error("Wizard must not edit WoW macros") end
function DeleteMacro() error("Wizard must not delete WoW macros") end
C_AddOns = { GetAddOnMetadata = function() return "0.4.6" end }
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 4, MAX_CHARACTER_MACROS = 3 } }
local accountMacros = {
    { "Krb", 134400, "#showtooltip Hearthstone\n/use Hearthstone" },
    { "Kouzlo z jiné postavy", 134400, "#showtooltip\n/cast Unknown Spell" },
}
local characterMacros = {}
function GetNumMacros() return #accountMacros, #characterMacros end
function GetMacroInfo(index)
    local macro = index <= 4 and accountMacros[index] or characterMacros[index - 4]
    if macro then return unpack(macro) end
end
Enum = { SpellBookSpellBank = { Player = 0 } }
local bookSpells = {
    { spellID = 35, name = "Léčení" },
    { spellID = 32, name = "Passive", isPassive = true },
    { spellID = 31, name = "Strikes" },
    { spellID = 6213, actionID = 5782, name = "Fear" },
    { spellID = 172, name = "Corruption" },
    { spellID = 710, name = "Banish" },
}
local professionNames = {
    [7620] = "Fishing", [3908] = "Tailoring", [3909] = "Tailoring", [3910] = "Tailoring", [2383] = "Find Herbs",
}
local learnedProfessions = { [7620] = true, [3909] = true }
C_Spell = { GetSpellName = function(id) return professionNames[id] end }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #bookSpells } end,
    GetSpellBookItemInfo = function(index) return bookSpells[index] end,
    IsSpellKnown = function(id) return learnedProfessions[id] == true end,
}
local bagItems = { 42, 42 }
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bagItems or 0 end,
    GetContainerItemID = function(_, slot) return bagItems[slot] end,
}
local itemNames, requests = { [1251] = "Linen Bandage", [2581] = "Heavy Linen Bandage" }, 0
C_Item = {
    GetItemInfo = function(id) return itemNames[id] end,
    RequestLoadItemDataByID = function() requests = requests + 1 end,
}

for file in io.lines(addon .. "/" .. addon .. ".toc") do
    if file:match("%.lua$") then assert(loadfile(addon .. "/" .. file))(addon, studio) end
end
local events = frames[#frames]
events:OnEvent("ADDON_LOADED", addon)

local function visible(kind, predicate)
    for _, frame in ipairs(frames) do
        if frame.kind == kind and frame:IsVisible() and predicate(frame) then return frame end
    end
end
local function button(label)
    return assert(visible("Button", function(frame) return frame.text == label end), label .. " is not visible")
end
local function click(label)
    local control = button(label)
    assert(control.enabled, label .. " is disabled")
    control:OnClick()
end
local function buttonAt(label, x, y)
    return assert(visible("Button", function(frame)
        if frame.text ~= label or not frame.point then return false end
        local _, _, _, left, top = frame:GetPoint()
        return left == x and top == -y
    end))
end
local function clickAt(label, x, y)
    local control = buttonAt(label, x, y)
    assert(control.enabled)
    control:OnClick()
end
local function label(text)
    return visible("FontString", function(frame) return frame.text == text end)
end
local function editAt(x, y)
    return assert(visible("EditBox", function(frame)
        if not frame.point then return false end
        local _, _, _, left, top = frame:GetPoint()
        return left == x and top == -y
    end))
end
local function enter(edit, value)
    edit:SetFocus()
    edit.text = value
    edit:OnTextChanged(true)
end
local function rawBox()
    return assert(visible("EditBox", function(frame) return frame.parent.kind == "ScrollFrame" end))
end

local fms = SlashCmdList.FOREVER_MACRO_STUDIO
local function offset(frame)
    local _, _, _, x, y = frame:GetPoint()
    return x, -y
end
local function resize(width, height)
    UIParent:SetSize(width, height)
    for _, frame in ipairs(frames) do
        if frame.events.DISPLAY_SIZE_CHANGED then frame:OnEvent("DISPLAY_SIZE_CHANGED") end
    end
end
fms("")
assert(button("Examples").highlight)
local window = globals.ForeverMacroStudioFrame
resize(900, 700)
assert(window.width == 550 and window.height == 970 and window.scale * window.height < 700)
local languageX, languageY = offset(button("Language: Automatic"))
local diagnosticsX, diagnosticsY = offset(button(studio.strings.enUS.guide.diagnostics))
assert(languageY == diagnosticsY and languageX + button("Language: Automatic").width < diagnosticsX)
resize(1200, 900)
assert(window.width == 760 and window.height == 530 and window.scale == 1)
click("Create macro")
local firstCard, secondCard = button("Banish"), button("Corruption")
local catalog = firstCard.parent
local firstX, firstY = offset(firstCard)
local secondX, secondY = offset(secondCard)
assert(firstX < secondX and firstY == secondY and offset(catalog) == 266)
resize(900, 700)
assert(button("1 column") and offset(catalog) == 24)
secondX, secondY = offset(secondCard)
assert(secondX == firstX and secondY == firstY + 30)
assert(offset(secondCard) + secondCard.width + offset(catalog) <= window.width)
click("1 column")
assert(button("2 columns") and offset(secondCard) > firstX)
resize(920, 700)
assert(button("2 columns") and offset(catalog) == 24)
click("2 columns")
resize(1200, 900)
assert(button("2 columns") and offset(catalog) == 266 and offset(secondCard) > firstX)
assert(not button("Next").enabled)
assert(button("1  Action · Choose an action").highlight)
assert(not button("2  Target · Default targeting").enabled)
assert(not button("4  Preview").enabled)
assert(not visible("Button", function(frame) return frame.text == "Passive" end))
click("Bags")
assert(requests == 1)
studio.RefreshWindow()
assert(requests == 1)
itemNames[42] = "Healing Potion"
events:OnEvent("ITEM_DATA_LOAD_RESULT", 42, true)
assert(button("Healing Potion"))
click("Spellbook")
click("Léčení")
enter(editAt(174, 43), "Sebeobnova")
click("2  Target · Default targeting")
assert(button("2  Target · Default targeting").highlight)
click("Self")
click("3  Conditions · None")
click("Alive")
assert(button("3  Conditions · Alive").highlight)
click("Undo")
assert(button("3  Conditions · None").highlight)
click("Redo")
click("4  Preview")
local expected = "#showtooltip\n/cast [@player,nodead] Léčení"
assert(rawBox():GetText() == expected)
assert(button("1  Action · Léčení").enabled)
assert(button("2  Target · Self").enabled)
assert(button("4  Preview").highlight)
click("2  Target · Self")
assert(button("Self").highlight)
click("4  Preview")
assert(label("Ready to copy"))
assert(label(studio.strings.enUS.guide.transfer))
click("Select macro text")
assert(rawBox().highlightedText == expected)
click("5  Save")
assert(not label(studio.strings.enUS.guide.transfer))
click("Check export to WoW")
assert(popup.text:find("Account macros", 1, true) and popup.text:find(expected, 1, true))
respond("OnAccept")
assert(label(studio.strings.enUS.exportReady))
click("Account macros")
click("Check export to WoW")
assert(popup.text:find("Character macros", 1, true))
respond("OnAccept")
click("Save draft")
assert(studio.library.Count() == 1)
assert(studio.library.Get("draft-1").revision == 1)
click("Draft library")
clickAt("+", 236, 137)
assert(ForeverMacroStudioDB.preferences.favorites["draft-1"])
click("Favorites only")
assert(button("Sebeobnova") and button("*"))
click("All drafts")

click("Sebeobnova")
for _ = 1, 3 do click("Next") end
assert(rawBox():GetText() == expected)
click("Edit as text")
assert(popup.OnAccept)
respond("OnAccept")
assert(rawBox():GetText() == expected)
assert(button("4  Macro text").highlight)
assert(not visible("Button", function(frame) return frame.text == "1  Action · Léčení" end))
click("5  Save")
click("Save draft")
assert(studio.library.Get("draft-1").body.structuredBackup.mode == "structured")
click("Draft library")
click("Sebeobnova")
click("Visual editor")
assert(rawBox():GetText() == expected)
assert(button("1  Action · Léčení").enabled)
click("Next")
click("Save draft")
assert(studio.library.Get("draft-1").body.mode == "structured")
assert(studio.library.Get("draft-1").revision == 3)
click("Draft library")

click("Paste macro text")
enter(rawBox(), "/run print('unchecked')")
assert(not button("Select macro text").enabled)
assert(label("Cannot copy yet"))
assert(not label(studio.strings.enUS.guide.transfer))
click("Visual editor")
assert(rawBox():GetText() == "/run print('unchecked')")
click("Draft library")
assert(popup.OnCancel and popup.OnAlt)
respond("OnCancel")
assert(rawBox():GetText() == "/run print('unchecked')")
fms("")
respond("OnAlt")
assert(not globals.ForeverMacroStudioFrame:IsShown())
fms("")
click("Paste macro text")
enter(rawBox(), " #showtooltip\r\n\r\n/cast [ @player, nodead ] Léčení ")
click("Visual editor")
assert(rawBox():GetText() == expected)
click("Next")
click("Save draft")
assert(studio.library.Get("draft-2").body.mode == "structured")
click("Draft library")
click("Create macro")
click("Advanced editing")
click("Léčení")
clickAt("+", 90, 326)
click("Strikes")
clickAt("↑", 156, 326)
assert(button("1  Action · Strikes").highlight)
clickAt("+", 90, 268)
click("Trinket slots")
click("First trinket (13)")
clickAt("↑", 156, 268)
for _ = 1, 3 do click("Next") end
assert(rawBox():GetText() == "#showtooltip\n/use 13\n/cast Strikes; Léčení")
local saved = ForeverMacroStudioDB
local reopened = studio.OpenLibrary(saved, time)
assert(reopened.Count() == 2 and reopened.Get("draft-1").title == "Sebeobnova")

click("Draft library")
respond("OnAlt")
click("Cast on yourself")
click("Léčení")
for _ = 1, 3 do click("Next") end
assert(rawBox():GetText() == "#showtooltip\n/cast [@player] Léčení")
click("Draft library")
respond("OnAlt")
click("Help under the pointer")
click("Léčení")
click("Next")
assert(not visible("Button", function(frame) return frame.text == "Self" end))
click("Advanced editing")
assert(button("Self"))
click("Beginner view")
click("Next")
click("Next")
assert(rawBox():GetText() == "#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Léčení")
click("Draft library")
respond("OnAlt")

click("Paste macro text")
local shadowedShift = "#showtooltip\n/cast [] Léčení; [mod:shift] Strikes"
enter(rawBox(), shadowedShift .. "\n/use 20")
assert(label("Issue 1 of 2"))
assert(visible("FontString", function(frame)
    return (frame.text or ""):find("Move the Shift action above it.", 1, true)
end))
clickAt(">", 300, 260)
assert(label("Issue 2 of 2"))
local showLine = button("Show line")
showLine:OnClick()
assert(rawBox().highlightedText == "/use 20")
clickAt("<", 266, 260)
showLine:OnClick()
assert(rawBox().highlightedText == "/cast [] Léčení; [mod:shift] Strikes")
enter(rawBox(), shadowedShift)
click("Visual editor")
assert(label("Issue 1 of 1"))
local showRule = button("Show rule")
showRule:OnClick()
assert(button("1  Action · Strikes").highlight)
assert(label("Branch 2/2"))
clickAt("↑", 156, 326)
click("4  Preview")
assert(rawBox():GetText() == "#showtooltip\n/cast [mod:shift] Strikes; [] Léčení")
assert(not label("Issue 1 of 1"))
click("Draft library")
respond("OnAlt")

assert(#studio.Presets.classes == 9)
for _, class in ipairs(studio.Presets.classes) do
    assert(#studio.Presets.byClass[class] == 5)
    for _, preset in ipairs(studio.Presets.byClass[class]) do
        for _, strings in pairs(studio.strings) do
            assert(strings.guide.roles[preset.role])
        end
        local name = studio.MacroText.Trim((preset.names:match("^[^/]+")))
        local id = preset.spellIds[1]
        local shiftId = preset.shiftSpellIds and preset.shiftSpellIds[1]
        local shiftName = preset.shiftName
        local draft = studio.Editor.Open(nil, false, "enUS", {
            pattern = preset.pattern, action = { kind = "spell", name = name, id = id },
            shiftAction = shiftId and { kind = "spell", name = shiftName, id = shiftId },
        }).Get()
        local compiled = studio.Compiler.Compile(draft.body, function(candidate)
            if candidate == id then return name end
            if candidate == shiftId then return shiftName end
        end)
        assert(compiled.canCopy and compiled.text:find(name, 1, true), class .. ": " .. name)
        if shiftName then
            assert(compiled.text == ("#showtooltip\n/cast [mod:shift] %s; %s"):format(shiftName, name))
        end
    end
end
clickAt("Class macros", 542, 39)
assert(button("Class macros").highlight)
assert(not button("Examples").highlight)
assert(button("Apply damage over time").enabled)
clickAt(">", 700, 106)
assert(not button("Heal an ally").enabled)
click("Available only")
assert(button("Available only").highlight)
assert(button("Apply damage over time").enabled)
assert(not buttonAt(">", 700, 106).enabled)
clickAt(">", 700, 399)
assert(button("Banish a demon or elemental").enabled)
assert(not visible("Button", function(frame) return frame.text == "Breathe underwater" end))
click("Available only")
assert(not button("Available only").highlight)
assert(not button("Heal an ally").enabled)
clickAt("<", 472, 106)
click("Control an enemy")
assert(rawBox():GetText() == "#showtooltip\n/cast [@mouseover,harm,nodead][@target,harm,nodead] Fear")
click("Next")
click("Save draft")
assert(studio.library.Get("draft-3").body.lines[2].branches[1].argument.id == 6213)
click("Draft library")
clickAt(">", 700, 399)
assert(button("Banish a demon or elemental").enabled)
assert(not button("Breathe underwater").enabled)
clickAt(">", 700, 399)
assert(not button("Create a Healthstone").enabled)
assert(not visible("Button", function(frame) return frame.text == "Breathe underwater" end))

playerClass = "WARRIOR"
bookSpells = { { spellID = 100, name = "Charge" } }
events:OnEvent("PLAYER_ENTERING_WORLD")
clickAt(">", 700, 399)
clickAt(">", 700, 399)
assert(not button("Charge or intercept").enabled)
local function cardSays(text)
    return visible("FontString", function(frame) return (frame.text or ""):find(text, 1, true) end)
end
assert(cardSays("You know Charge. Learn Intercept for the Shift action."))
bookSpells = { { spellID = 20252, name = "Intercept" } }
events:OnEvent("SPELLS_CHANGED")
assert(cardSays("You know Intercept for Shift. Learn Charge for a normal press."))
bookSpells = {}
events:OnEvent("SPELLS_CHANGED")
assert(cardSays("Learn Charge for a normal press and Intercept for Shift."))
bookSpells = { { spellID = 100, name = "Charge" } }
events:OnEvent("SPELLS_CHANGED")
click("Available only")
assert(label(studio.strings.enUS.guide.noAvailablePresets))
bookSpells[2] = { spellID = 20252, name = "Intercept" }
events:OnEvent("SPELLS_CHANGED")
assert(not label(studio.strings.enUS.guide.noAvailablePresets))
click("Charge or intercept")
assert(rawBox():GetText() == "#showtooltip\n/cast [mod:shift] Intercept; Charge")
assert(button("1  Action · 2 options").enabled)
assert(label("Press normally for Charge. Hold Shift for Intercept."))
click("Draft library")

assert(#studio.Presets.professions == 12)
clickAt("Professions", 658, 39)
assert(button("Professions").highlight)
assert(button("Cast your fishing line").enabled)
assert(button("Open Tailoring").enabled)
assert(studio.Catalog.KnownSpell({ 3908, 3909 }).id == 3909)
click("Open Tailoring")
assert(rawBox():GetText() == "#showtooltip\n/cast Tailoring")
assert(studio.Catalog.SpellId("Tailoring") == 3909)
learnedProfessions[3909], learnedProfessions[3910] = nil, true
events:OnEvent("SPELLS_CHANGED")
assert(rawBox():GetText() == "#showtooltip\n/cast Tailoring")
assert(studio.Catalog.SpellId("Tailoring") == 3910)
click("Draft library")
clickAt(">", 700, 399)
assert(not button("Bandage under the pointer").enabled)
assert(not button("Track herbs").enabled)
click("Available only")
assert(button("Available only").highlight)
assert(button("Open Tailoring").enabled)
assert(not buttonAt(">", 700, 399).enabled)
bagItems = { 42, 1251, 2581 }
events:OnEvent("BAG_UPDATE_DELAYED")
click("Bandage under the pointer")
assert(rawBox():GetText() == "#showtooltip\n/use [@mouseover,help,nodead][@target,help,nodead][@player] item:2581")
click("Draft library")
clickAt(">", 700, 399)
assert(button("Open Tailoring").enabled)
bagItems = { 42 }
events:OnEvent("BAG_UPDATE_DELAYED")
assert(button("Cast your fishing line").enabled)
assert(button("Open Tailoring").enabled)
assert(not buttonAt("<", 472, 399).enabled)

click("Language: Automatic")
assert(button("Jen dostupná").highlight)
assert(button("Otevřít krejčovství").enabled)
click("Vložit text")
assert(button("4  Text makra").highlight)
enter(rawBox(), "/cast Fear")
click("Knihovna návrhů")
assert(popup.text == "Uložit změny návrhu?" and popup.button2 == "Pokračovat v úpravách")
respond("OnAlt")

clickAt("Upravit kopii", 277, 137)
assert(editAt(174, 43):GetText() == "Kopie – Sebeobnova")
assert(studio.library.Count() == 3)
click("Knihovna návrhů")
respond("OnAlt")
assert(studio.library.Count() == 3)
clickAt("Upravit kopii", 277, 137)
click("2  Cíl · Sebe")
click("Aktuální cíl")
click("5  Uložení")
click("Uložit návrh")
local original = assert(studio.library.Get("draft-1"))
local copied = assert(studio.library.Get("draft-4"))
assert(original.revision == 3 and original.body.lines[2].branches[1].groups[1].unit == "player")
assert(copied.title == "Kopie – Sebeobnova" and copied.revision == 1)
assert(copied.body.lines[2].branches[1].groups[1].unit == "target")

click("Knihovna návrhů")
clickAt("Archivovat", 366, 137)
assert(studio.library.Get("draft-1").archived)
assert(not visible("Button", function(frame) return frame.text == "Sebeobnova" end))
click("Zobrazit archiv")
assert(button("Sebeobnova"))
click("Obnovit")
assert(not studio.library.Get("draft-1").archived)
click("Zobrazit aktivní")

click("Načíst z WoW")
assert(button("Makra účtu").highlight)
click("Krb")
assert(rawBox():GetText() == accountMacros[1][3] and button("Upravit jako text"))
click("5  Uložení")
click("Uložit návrh")
local importedAccount = assert(studio.library.Get("draft-5"))
assert(importedAccount.icon == 134400 and importedAccount.character == nil and importedAccount.body.mode == "structured")
click("Knihovna návrhů")
click("Načíst z WoW")
click("Kouzlo z jiné postavy")
assert(button("4  Text makra").highlight and rawBox():GetText() == accountMacros[2][3])
assert(label("Otevřeno jako text. řádek 2 · Pro „Unknown Spell“ se v knize nenašlo jediné odpovídající kouzlo."))
click("Knihovna návrhů")
respond("OnAlt")

playerName = "Thrall"
click("Načíst z WoW")
click("Makra postavy")
assert(label("V této skupině zatím žádná makra nejsou."))
characterMacros[1] = { "Tretka", 134401, "/use [mod:shift,@mouseover,help,nodead][mod:shift,@target,help,nodead] 13; Hearthstone" }
events:OnEvent("UPDATE_MACROS")
click("Tretka")
click("Zkouška nanečisto")
assert(cardSays("Hearthstone · Výchozí cílení"))
click("Stisknutý Shift")
click("Aktuální cíl · Žádný")
assert(cardSays("13 · Aktuální cíl"))
click("Pod kurzorem · Žádný")
assert(cardSays("13 · Pod kurzorem"))
click("Pod kurzorem · Spojenec")
assert(cardSays("13 · Aktuální cíl"))
click("Zpět do náhledu")
assert(rawBox():GetText() == "/use [@mouseover,mod:shift,help,nodead][@target,mod:shift,help,nodead] 13; Hearthstone")
click("5  Uložení")
click("Uložit návrh")
assert(studio.library.Get("draft-6").character == "Thrall-Example")
click("Knihovna návrhů")
click("Postava · Všechny")
assert(button("Postava · Jaina-Example").highlight and button("Sebeobnova"))
assert(not visible("Button", function(frame) return frame.text == "Tretka" end))
click("Postava · Jaina-Example")
assert(button("Tretka"))
assert(not visible("Button", function(frame) return frame.text == "Krb" end))
click("Postava · Thrall-Example")
assert(button("Krb"))
click("Krb")
click("5  Uložení")
click("Přiřadit této postavě")
assert(label("Přiřazená postava · Thrall-Example"))
click("Uložit návrh")
assert(studio.library.Get("draft-5").character == "Thrall-Example")
click("Odebrat přiřazení")
click("Uložit návrh")
assert(studio.library.Get("draft-5").character == nil)

print("E04: macro import, archive, character filters, simulated targeting, and editor regressions passed")
