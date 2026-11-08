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
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
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
function methods:HighlightText() self.highlightedText = self.text end
function methods:SetScrollChild(child) self.child = child end
for _, name in ipairs({
    "SetAllPoints", "SetFrameStrata", "SetScale", "SetJustifyH", "SetSpacing", "SetWordWrap",
    "SetMaxLines", "SetMultiLine", "SetAutoFocus", "SetTextInsets", "SetTextColor", "SetCursorPosition", "SetColorTexture",
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
function InCombatLockdown() return false end
function time() return 100 end
function CreateMacro() error("Wizard must not create WoW macros") end
function EditMacro() error("Wizard must not edit WoW macros") end
function DeleteMacro() error("Wizard must not delete WoW macros") end
C_AddOns = { GetAddOnMetadata = function() return "0.4.2" end }
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
local function clickAt(label, x, y)
    local control = assert(visible("Button", function(frame)
        return frame.text == label and frame.point and frame.point[2] == x and frame.point[3] == -y
    end))
    assert(control.enabled)
    control:OnClick()
end
local function editAt(x, y)
    return assert(visible("EditBox", function(frame)
        return frame.point and frame.point[2] == x and frame.point[3] == -y
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
fms("")
click("Create macro")
assert(not button("Next").enabled)
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
click("Next")
click("Self")
click("Next")
click("Alive")
click("Undo")
click("Redo")
click("Next")
local expected = "#showtooltip\n/cast [@player,nodead] Léčení"
assert(rawBox():GetText() == expected)
click("Select macro text")
assert(rawBox().highlightedText == expected)
click("Next")
click("Save draft")
assert(studio.library.Count() == 1)
assert(studio.library.Get("draft-1").revision == 1)
click("Draft library")

click("Sebeobnova")
for _ = 1, 3 do click("Next") end
assert(rawBox():GetText() == expected)
click("Edit as text")
assert(popup.OnAccept)
respond("OnAccept")
assert(rawBox():GetText() == expected)
click("Next")
click("Save draft")
assert(studio.library.Get("draft-1").body.structuredBackup.mode == "structured")
click("Draft library")
click("Sebeobnova")
click("Visual editor")
assert(rawBox():GetText() == expected)
click("Next")
click("Save draft")
assert(studio.library.Get("draft-1").body.mode == "structured")
assert(studio.library.Get("draft-1").revision == 3)
click("Draft library")

click("Paste macro text")
enter(rawBox(), "/run print('unchecked')")
assert(not button("Select macro text").enabled)
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
clickAt("+", 90, 170)
click("Strikes")
clickAt("↑", 156, 170)
clickAt("+", 90, 110)
click("Trinket slots")
click("First trinket (13)")
clickAt("↑", 156, 110)
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
        local shiftName = shiftId and studio.MacroText.Trim((preset.names:match("/(.+)$")))
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
click("Class macros")
assert(button("Apply damage over time").enabled)
clickAt(">", 700, 73)
assert(not button("Heal an ally").enabled)
clickAt("<", 472, 73)
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
bookSpells[2] = { spellID = 20252, name = "Intercept" }
events:OnEvent("SPELLS_CHANGED")
click("Charge or intercept")
assert(rawBox():GetText() == "#showtooltip\n/cast [mod:shift] Intercept; Charge")
assert(visible("FontString", function(frame) return frame.text == "Press normally for Charge. Hold Shift for Intercept." end))
click("Draft library")

assert(#studio.Presets.professions == 12)
click("Professions")
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
clickAt("<", 472, 399)
bagItems = { 42, 1251, 2581 }
events:OnEvent("BAG_UPDATE_DELAYED")
click("Bandage under the pointer")
assert(rawBox():GetText() == "#showtooltip\n/use [@mouseover,help,nodead][@target,help,nodead][@player] item:2581")
click("Draft library")

click("Language: Automatic")
assert(button("Obvaz pod kurzorem").enabled)
click("Vložit text")
enter(rawBox(), "/cast Fear")
click("Knihovna návrhů")
assert(popup.text == "Uložit změny návrhu?" and popup.button2 == "Pokračovat v úpravách")
respond("OnAlt")

print("E04: wizard, examples, class and profession presets, round trip, and popup typography passed")
