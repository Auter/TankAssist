--[[
    STA_UI.lua
    User interface for TankAssist
    Lua 5.0 compatible, nil-safe
    
    CRITICAL RULES:
    - Every SetPoint MUST have valid parent frame
    - Never pass nil as relativeTo
    - ClearAllPoints before repositioning
    - All widgets inside main frame bounds
]]

STA_UI = {}

-- Local frame references
local optionsFrame = nil
local hudFrame = nil
local hudEntries = {}
local protectedContainer = nil

-- Colors
local COLOR_TITLE = {1, 0.82, 0}
local COLOR_HEADER = {1, 0.82, 0}
local COLOR_NORMAL = {1, 1, 1}
local COLOR_PROTECTED = {0.4, 0.7, 1}
local COLOR_DANGER = {1, 0.3, 0.3}       -- Red for enemy names
local COLOR_FRIENDLY = {0.3, 1, 0.3}     -- Green for friendly names
local COLOR_WARNING = {1, 0.82, 0}
local COLOR_DIM = {0.5, 0.5, 0.5}
local COLOR_SUPERWOW = {0.3, 1, 0.3}     -- Green for SuperWoW note

-- Backdrop templates
local BACKDROP_MAIN = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4},
}

local BACKDROP_INNER = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = {left = 2, right = 2, top = 2, bottom = 2},
}

--============================================================================
-- INITIALIZATION
--============================================================================

function STA_UI:Initialize()
    self:CreateOptionsFrame()
    self:CreateHUD()
end

--============================================================================
-- OPTIONS FRAME
--============================================================================

function STA_UI:CreateOptionsFrame()
    -- Main frame - increased height to fit all content
    local frame = CreateFrame("Frame", "STA_OptionsFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(650)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop(BACKDROP_MAIN)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    optionsFrame = frame
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("TankAssist")
    title:SetTextColor(unpack(COLOR_TITLE))
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() STA_UI:ToggleOptions() end)
    
    -- Track vertical position for layout
    local yPos = -40
    local leftMargin = 20
    local contentWidth = 355
    
    ------------------------------------------
    -- PROTECTED PLAYERS SECTION (Flow Layout with Scroll)
    ------------------------------------------
    yPos = self:AddSectionHeader(frame, "Protected Players", yPos, leftMargin)
    
    -- Description
    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:ClearAllPoints()
    desc:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin, yPos)
    desc:SetWidth(contentWidth)
    desc:SetJustifyH("LEFT")
    desc:SetText("Enemies targeting these players are ignored. Click to toggle:")
    desc:SetTextColor(0.7, 0.7, 0.7)
    yPos = yPos - 14
    
    -- Protected players container (outer frame with backdrop)
    local PROT_BOX_HEIGHT = 80
    local protCont = CreateFrame("Frame", "STA_ProtectedContainer", frame)
    protCont:ClearAllPoints()
    protCont:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin, yPos)
    protCont:SetWidth(contentWidth)
    protCont:SetHeight(PROT_BOX_HEIGHT)
    protCont:SetBackdrop(BACKDROP_INNER)
    protCont:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    protCont:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    protectedContainer = protCont
    
    -- Create scroll frame inside container
    local scrollFrame = CreateFrame("ScrollFrame", "STA_ProtectedScrollFrame", protCont)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", protCont, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", protCont, "BOTTOMRIGHT", -20, 4)
    
    -- Content frame that holds all the name buttons (will be sized dynamically)
    local scrollChild = CreateFrame("Frame", "STA_ProtectedScrollChild", scrollFrame)
    scrollChild:SetWidth(contentWidth - 28)
    scrollChild:SetHeight(1) -- Set dynamically based on content
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Create scrollbar
    local scrollBar = CreateFrame("Slider", "STA_ProtectedScrollBar", protCont)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", protCont, "TOPRIGHT", -4, -6)
    scrollBar:SetPoint("BOTTOMRIGHT", protCont, "BOTTOMRIGHT", -4, 6)
    scrollBar:SetWidth(12)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    
    -- Scrollbar background
    local scrollBg = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBg:SetAllPoints(scrollBar)
    scrollBg:SetTexture(0, 0, 0, 0.3)
    
    -- Link scrollbar to scroll frame
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    
    -- Mouse wheel scrolling on the container
    protCont:EnableMouseWheel(true)
    protCont:SetScript("OnMouseWheel", function()
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = scrollBar:GetMinMaxValues()
        local _, max = scrollBar:GetMinMaxValues()
        local step = 20 -- pixels per scroll
        
        local newScroll = current - (arg1 * step)
        if newScroll < 0 then newScroll = 0 end
        if newScroll > max then newScroll = max end
        
        scrollFrame:SetVerticalScroll(newScroll)
        scrollBar:SetValue(newScroll)
    end)
    
    -- Store references for RefreshProtectedList
    self.protectedScrollFrame = scrollFrame
    self.protectedScrollChild = scrollChild
    self.protectedScrollBar = scrollBar
    self.protectedNameButtons = {} -- Pool of reusable name buttons
    
    yPos = yPos - (PROT_BOX_HEIGHT + 5)
    
    ------------------------------------------
    -- HUD OPTIONS SECTION (renamed from "Uncontrolled Targets HUD")
    ------------------------------------------
    yPos = self:AddSectionHeader(frame, "HUD Options", yPos, leftMargin)
    
    yPos = self:AddCheckbox(frame, "Lock HUD position", yPos, leftMargin,
        function() return STA_Saved:Get("hudLocked") end,
        function(v) STA_Saved:Set("hudLocked", v); STA_UI:UpdateHUDLock() end)
    
    yPos = self:AddCheckbox(frame, "Show HUD while configuring", yPos, leftMargin,
        function() return STA_Saved:Get("showHUDWhileConfiguring") end,
        function(v)
            STA_Saved:Set("showHUDWhileConfiguring", v)
            STA_UI:UpdateHUDVisibility()
        end)
    
    -- Moved from Safety Options: Hide HUD out of combat
    yPos = self:AddCheckbox(frame, "Hide HUD out of combat", yPos, leftMargin,
        function() return STA_Saved:Get("hideHUDOutOfCombat") end,
        function(v)
            STA_Saved:Set("hideHUDOutOfCombat", v)
            STA_UI:UpdateHUDVisibility()
        end)
    
    yPos = self:AddSlider(frame, "HUD Scale", yPos, leftMargin, 0.5, 2.0, 0.1,
        function() return STA_Saved:Get("hudScale") end,
        function(v) STA_Saved:Set("hudScale", v); STA_UI:ApplyHUDScale() end)
    
    yPos = self:AddSlider(frame, "Font Size", yPos, leftMargin, 8, 18, 1,
        function() return STA_Saved:Get("hudFontSize") end,
        function(v) STA_Saved:Set("hudFontSize", v) end)
    
    ------------------------------------------
    -- SNAP KEY SECTION
    ------------------------------------------
    yPos = self:AddSectionHeader(frame, "Snap Attention Key", yPos, leftMargin)
    
    yPos = self:AddDropdown(frame, "Action:", yPos, leftMargin, 155,
        {
            {value = "targetcast", label = "Target + Cast"},
            {value = "targetonly", label = "Target Only"},
            {value = "castonly", label = "Cast Only (keep target)"},
        },
        function() return STA_Saved:Get("snapAction") end,
        function(v) STA_Saved:Set("snapAction", v) end)
    
    -- Build spell dropdown from class config
    -- Show all class spells - validation happens at cast time via CanCastSpell
    -- This avoids timing issues with spellbook not being ready during UI creation
    local spellOptions = {{value = "none", label = "No Spell"}}
    if TA and TA.classConfig and TA.classConfig.snapSpells then
        for _, spellName in ipairs(TA.classConfig.snapSpells) do
            table.insert(spellOptions, {value = spellName, label = spellName})
        end
    end
    
    yPos = self:AddDropdown(frame, "Spell:", yPos, leftMargin, 155,
        spellOptions,
        function() return STA_Saved:Get("snapSpell") end,
        function(v) STA_Saved:Set("snapSpell", v) end)
    
    yPos = self:AddCheckbox(frame, "Attempt to taunt before snapping", yPos, leftMargin,
        function() return STA_Saved:Get("attemptTauntFirst") end,
        function(v) STA_Saved:Set("attemptTauntFirst", v) end)
    
    -- Taunt explanation text (class-neutral wording)
    local tauntDesc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tauntDesc:ClearAllPoints()
    tauntDesc:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin + 24, yPos + 2)
    tauntDesc:SetWidth(contentWidth - 24)
    tauntDesc:SetJustifyH("LEFT")
    tauntDesc:SetText("(Uses your class taunt first if available and in range)")
    tauntDesc:SetTextColor(0.6, 0.6, 0.6)
    yPos = yPos - 12
    
    -- Macro button
    local macroBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    macroBtn:ClearAllPoints()
    macroBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin, yPos)
    macroBtn:SetWidth(120)
    macroBtn:SetHeight(20)
    macroBtn:SetText("Show Macro")
    macroBtn:SetScript("OnClick", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[TankAssist] Macro name:|r TankAssistSnap")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[TankAssist] Macro body:|r /run TA_Snap()")
    end)
    yPos = yPos - 26
    
    ------------------------------------------
    -- TARGET PRIORITY SECTION
    -- Note: "Prefer furthest" and "Prefer nearest" are mutually exclusive
    ------------------------------------------
    yPos = self:AddSectionHeader(frame, "Target Priority", yPos, leftMargin)
    
    -- Store references to checkboxes for mutual exclusivity
    local furthestCheck = nil
    local nearestCheck = nil
    
    -- "Prefer furthest enemy from you" checkbox
    do
        local check = CreateFrame("CheckButton", "STA_CheckFurthest", frame, "UICheckButtonTemplate")
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin, yPos)
        check:SetWidth(24)
        check:SetHeight(24)
        
        local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:ClearAllPoints()
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        text:SetText("Prefer furthest enemy from you")
        text:SetTextColor(unpack(COLOR_NORMAL))
        
        check:SetChecked(STA_Saved:Get("preferFurthestEnemy"))
        
        check:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            STA_Saved:Set("preferFurthestEnemy", checked)
            -- Mutual exclusivity: if enabling furthest, disable nearest
            if checked and nearestCheck then
                STA_Saved:Set("preferNearest", false)
                nearestCheck:SetChecked(false)
            end
        end)
        
        furthestCheck = check
        yPos = yPos - 22
    end
    
    -- SuperWoW note in green
    local swNote = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    swNote:ClearAllPoints()
    swNote:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin + 24, yPos + 2)
    swNote:SetWidth(contentWidth - 24)
    swNote:SetJustifyH("LEFT")
    swNote:SetText("(Requires SuperWoW for precise distance)")
    swNote:SetTextColor(unpack(COLOR_SUPERWOW))
    yPos = yPos - 12
    
    -- "Prefer nearest enemy" checkbox
    do
        local check = CreateFrame("CheckButton", "STA_CheckNearest", frame, "UICheckButtonTemplate")
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", frame, "TOPLEFT", leftMargin, yPos)
        check:SetWidth(24)
        check:SetHeight(24)
        
        local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:ClearAllPoints()
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        text:SetText("Prefer nearest enemy")
        text:SetTextColor(unpack(COLOR_NORMAL))
        
        check:SetChecked(STA_Saved:Get("preferNearest"))
        
        check:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            STA_Saved:Set("preferNearest", checked)
            -- Mutual exclusivity: if enabling nearest, disable furthest
            if checked and furthestCheck then
                STA_Saved:Set("preferFurthestEnemy", false)
                furthestCheck:SetChecked(false)
            end
        end)
        
        nearestCheck = check
        yPos = yPos - 22
    end
    
    ------------------------------------------
    -- OPTIONS SECTION (renamed from "Safety Options")
    ------------------------------------------
    yPos = self:AddSectionHeader(frame, "Options", yPos, leftMargin)
    
    yPos = self:AddCheckbox(frame, "Skip CC'd targets (Poly/Sap/Hex)", yPos, leftMargin,
        function() return STA_Saved:Get("respectCC") end,
        function(v) STA_Saved:Set("respectCC", v) end)
    
    yPos = self:AddCheckbox(frame, "Mark target with Skull", yPos, leftMargin,
        function() return STA_Saved:Get("markWithSkull") end,
        function(v) STA_Saved:Set("markWithSkull", v) end)
    
    yPos = self:AddCheckbox(frame, "Hide helper messages", yPos, leftMargin,
        function() return STA_Saved:Get("hideHelperMessages") end,
        function(v) STA_Saved:Set("hideHelperMessages", v) end)
    
    -- OnShow handler
    frame:SetScript("OnShow", function()
        STA_UI:RefreshProtectedList()
        STA_UI:UpdateHUDVisibility()
    end)
    
    frame:SetScript("OnHide", function()
        STA_UI:UpdateHUDVisibility()
    end)
end

--============================================================================
-- UI HELPER FUNCTIONS - All with safe SetPoint patterns
--============================================================================

function STA_UI:AddSectionHeader(parent, text, yPos, leftMargin)
    if not parent then return yPos end
    
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin - 5, yPos)
    header:SetText(text)
    header:SetTextColor(unpack(COLOR_HEADER))
    
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin - 5, yPos - 12)
    line:SetWidth(360)
    line:SetHeight(1)
    line:SetTexture(1, 0.82, 0, 0.4)
    
    return yPos - 18
end

function STA_UI:AddCheckbox(parent, label, yPos, leftMargin, getFunc, setFunc)
    if not parent then return yPos end
    
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin, yPos)
    check:SetWidth(24)
    check:SetHeight(24)
    
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    text:SetText(label)
    text:SetTextColor(unpack(COLOR_NORMAL))
    
    if getFunc then
        check:SetChecked(getFunc())
    end
    
    check:SetScript("OnClick", function()
        if setFunc then
            setFunc(this:GetChecked() and true or false)
        end
    end)
    
    return yPos - 22
end

function STA_UI:AddSlider(parent, label, yPos, leftMargin, minVal, maxVal, step, getFunc, setFunc)
    if not parent then return yPos end
    
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin, yPos)
    text:SetText(label)
    text:SetTextColor(unpack(COLOR_NORMAL))
    
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:ClearAllPoints()
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin + 80, yPos - 2)
    slider:SetWidth(150)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    -- Note: SetObeyStepOnDrag not available in 1.12, slider will snap to step via OnValueChanged
    
    local valText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valText:ClearAllPoints()
    valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valText:SetTextColor(unpack(COLOR_NORMAL))
    
    if getFunc then
        local val = getFunc()
        slider:SetValue(val)
        valText:SetText(string.format("%.1f", val))
    end
    
    slider:SetScript("OnValueChanged", function()
        local val = this:GetValue()
        -- Manually snap to step for 1.12 compatibility
        local snapped = math.floor(val / step + 0.5) * step
        valText:SetText(string.format("%.1f", snapped))
        if setFunc then setFunc(snapped) end
    end)
    
    -- Hide the default min/max labels
    local regions = {slider:GetRegions()}
    for _, region in ipairs(regions) do
        if region:GetObjectType() == "FontString" then
            region:SetText("")
        end
    end
    
    return yPos - 28
end

function STA_UI:AddDropdown(parent, label, yPos, leftMargin, width, options, getFunc, setFunc)
    if not parent then return yPos end
    if not options then return yPos end
    
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin, yPos)
    text:SetText(label)
    text:SetTextColor(unpack(COLOR_NORMAL))
    
    -- Create unique dropdown name to avoid conflicts
    local dropdownName = "STA_Dropdown_" .. gsub(label, "[^%w]", "")
    local dropdown = CreateFrame("Frame", dropdownName, parent, "UIDropDownMenuTemplate")
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", leftMargin + 45, yPos + 4)
    UIDropDownMenu_SetWidth(width, dropdown)
    
    -- Store options and current value on the dropdown frame itself for safe access
    dropdown.staOptions = options
    dropdown.staGetFunc = getFunc
    dropdown.staSetFunc = setFunc
    dropdown.staCurrentValue = (getFunc and getFunc()) or (options[1] and options[1].value) or ""
    
    local function UpdateDropdownText(dd)
        if not dd or not dd.staOptions then return end
        for _, opt in ipairs(dd.staOptions) do
            if opt and opt.value == dd.staCurrentValue then
                UIDropDownMenu_SetText(opt.label or "", dd)
                return
            end
        end
    end
    
    -- Store update function on dropdown
    dropdown.staUpdateText = UpdateDropdownText
    
    UIDropDownMenu_Initialize(dropdown, function()
        local dd = this:GetParent()
        if not dd or not dd.staOptions then return end
        
        for i, opt in ipairs(dd.staOptions) do
            if opt then
                local info = {}
                info.text = opt.label or ""
                info.value = opt.value
                -- Capture value by creating a closure with the value stored
                local capturedValue = opt.value
                info.func = function()
                    if dd then
                        dd.staCurrentValue = capturedValue
                        if dd.staSetFunc then
                            dd.staSetFunc(capturedValue)
                        end
                        if dd.staUpdateText then
                            dd.staUpdateText(dd)
                        end
                    end
                end
                info.checked = (dd.staCurrentValue == opt.value)
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    
    UpdateDropdownText(dropdown)
    
    return yPos - 28
end

--============================================================================
-- PROTECTED LIST REFRESH (Flow Layout with Scroll)
-- Names are laid out left-to-right, top-to-bottom inside the scroll child.
-- Sorted alphabetically. Click toggles protection.
--============================================================================

function STA_UI:RefreshProtectedList()
    if not protectedContainer then return end
    if not self.protectedScrollChild then return end
    if not self.protectedScrollBar then return end
    
    local scrollChild = self.protectedScrollChild
    local scrollBar = self.protectedScrollBar
    local scrollFrame = self.protectedScrollFrame
    
    -- Hide all existing buttons
    if self.protectedNameButtons then
        for _, btn in ipairs(self.protectedNameButtons) do
            if btn and btn.Hide then btn:Hide() end
        end
    end
    self.protectedNameButtons = self.protectedNameButtons or {}
    
    -- Get group members
    local members = {}
    if STA and STA.GetGroupMembers then
        members = STA:GetGroupMembers()
    end
    
    -- Sort alphabetically by name
    table.sort(members, function(a, b)
        if a and b and a.name and b.name then
            return strlower(a.name) < strlower(b.name)
        end
        return false
    end)
    
    local numMembers = table.getn(members)
    
    -- Layout settings
    local PADDING = 4
    local BUTTON_HEIGHT = 16
    local BUTTON_SPACING_X = 4
    local BUTTON_SPACING_Y = 2
    local MAX_WIDTH = scrollChild:GetWidth() - PADDING
    
    -- Handle solo case
    if numMembers == 0 then
        local btn = self.protectedNameButtons[1]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetHeight(BUTTON_HEIGHT)
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:ClearAllPoints()
            text:SetPoint("LEFT", btn, "LEFT", 0, 0)
            btn.text = text
            self.protectedNameButtons[1] = btn
        end
        
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PADDING, -PADDING)
        btn:SetWidth(MAX_WIDTH)
        btn.memberName = nil
        btn:SetScript("OnClick", nil)
        if btn.text then
            btn.text:SetText("(Solo - no group members)")
            btn.text:SetTextColor(unpack(COLOR_DIM))
        end
        btn:Show()
        
        scrollChild:SetHeight(BUTTON_HEIGHT + PADDING * 2)
        scrollBar:SetMinMaxValues(0, 0)
        scrollBar:Hide()
        return
    end
    
    -- Flow layout: place buttons left-to-right, wrap to next row
    local currentX = PADDING
    local currentY = -PADDING
    local rowHeight = BUTTON_HEIGHT + BUTTON_SPACING_Y
    local maxRowY = currentY
    
    for i, member in ipairs(members) do
        -- Get or create button
        local btn = self.protectedNameButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetHeight(BUTTON_HEIGHT)
            
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:ClearAllPoints()
            text:SetPoint("LEFT", btn, "LEFT", 4, 0)
            text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            text:SetJustifyH("CENTER")
            btn.text = text
            
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            btn:SetScript("OnClick", function()
                if this.memberName then
                    STA_Saved:ToggleProtected(this.memberName)
                    STA_UI:RefreshProtectedList()
                end
            end)
            
            self.protectedNameButtons[i] = btn
        end
        
        -- Set button content
        btn.memberName = member.name
        if btn.text then
            btn.text:SetText(member.name or "?")
            
            local isProtected = STA_Saved:IsProtected(member.name)
            if isProtected then
                btn.text:SetTextColor(unpack(COLOR_PROTECTED))
            else
                btn.text:SetTextColor(unpack(COLOR_NORMAL))
            end
        end
        
        -- Measure text width to size button
        local textWidth = btn.text:GetStringWidth() + 12 -- padding
        if textWidth < 40 then textWidth = 40 end -- minimum width
        if textWidth > MAX_WIDTH then textWidth = MAX_WIDTH end
        btn:SetWidth(textWidth)
        
        -- Check if button fits on current row
        if currentX + textWidth > MAX_WIDTH + PADDING and currentX > PADDING then
            -- Wrap to next row
            currentX = PADDING
            currentY = currentY - rowHeight
        end
        
        -- Position button
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", currentX, currentY)
        btn:Show()
        
        -- Advance X position
        currentX = currentX + textWidth + BUTTON_SPACING_X
        
        -- Track max Y for content height
        if currentY - BUTTON_HEIGHT < maxRowY then
            maxRowY = currentY - BUTTON_HEIGHT
        end
    end
    
    -- Set scroll child height based on content
    local contentHeight = math.abs(maxRowY) + PADDING
    if contentHeight < 1 then contentHeight = 1 end
    scrollChild:SetHeight(contentHeight)
    
    -- Update scrollbar range
    local visibleHeight = scrollFrame:GetHeight()
    local maxScroll = contentHeight - visibleHeight
    if maxScroll < 0 then maxScroll = 0 end
    
    scrollBar:SetMinMaxValues(0, maxScroll)
    if maxScroll > 0 then
        scrollBar:Show()
    else
        scrollBar:Hide()
        scrollBar:SetValue(0)
        scrollFrame:SetVerticalScroll(0)
    end
end

function STA_UI:ToggleOptions()
    if not optionsFrame then return end
    if optionsFrame:IsVisible() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

--============================================================================
-- HUD FRAME
--============================================================================

function STA_UI:CreateHUD()
    local frame = CreateFrame("Frame", "STA_HUDFrame", UIParent)
    frame:SetWidth(280)
    frame:SetHeight(28)
    frame:SetBackdrop(BACKDROP_MAIN)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.88)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    
    local posX = STA_Saved:Get("hudPosX") or 0
    local posY = STA_Saved:Get("hudPosY") or 150
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", posX, posY)
    
    hudFrame = frame
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -6)
    title:SetText("Uncontrolled Targets:")
    title:SetTextColor(unpack(COLOR_TITLE))
    
    self:UpdateHUDLock()
    self:ApplyHUDScale()
end

function STA_UI:UpdateHUDLock()
    if not hudFrame then return end
    
    local locked = STA_Saved:Get("hudLocked")
    
    if locked then
        hudFrame:SetScript("OnDragStart", nil)
        hudFrame:SetScript("OnDragStop", nil)
    else
        hudFrame:SetScript("OnDragStart", function()
            this:StartMoving()
        end)
        hudFrame:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            local _, _, _, x, y = this:GetPoint()
            if x and y then
                STA_Saved:Set("hudPosX", x)
                STA_Saved:Set("hudPosY", y)
            end
        end)
    end
end

function STA_UI:ApplyHUDScale()
    if not hudFrame then return end
    local scale = STA_Saved:Get("hudScale") or 1.0
    hudFrame:SetScale(scale)
end

--============================================================================
-- HUD VISIBILITY CONTROL
--============================================================================

function STA_UI:UpdateHUDVisibility()
    if not hudFrame then return end
    
    local showWhileConfiguring = STA_Saved:Get("showHUDWhileConfiguring")
    local hideOutOfCombat = STA_Saved:Get("hideHUDOutOfCombat")
    local optionsOpen = optionsFrame and optionsFrame:IsVisible()
    
    if STA.inCombat then
        hudFrame:Show()
    elseif showWhileConfiguring and optionsOpen then
        hudFrame:Show()
        self:RefreshHUD()
    elseif hideOutOfCombat then
        hudFrame:Hide()
    else
        hudFrame:Show()
        self:RefreshHUD()
    end
end

function STA_UI:OnCombatStart()
    if hudFrame then
        hudFrame:Show()
    end
end

function STA_UI:OnCombatEnd()
    self:UpdateHUDVisibility()
end

function STA_UI:ShowHUD()
    if hudFrame then hudFrame:Show() end
end

function STA_UI:HideHUD()
    self:UpdateHUDVisibility()
end

--============================================================================
-- HUD DISPLAY REFRESH
-- Format: EnemyName (red) – FriendlyName (green)
--============================================================================

function STA_UI:RefreshHUD()
    if not hudFrame then return end
    if not hudFrame:IsVisible() then return end
    
    local targets = STA.uncontrolledTargets or {}
    local numTargets = table.getn(targets)
    
    -- Hide old entries
    for _, entry in ipairs(hudEntries) do
        if entry and entry.Hide then entry:Hide() end
    end
    
    -- Calculate frame height
    local baseHeight = 24
    local entryHeight = 16
    local totalHeight = baseHeight + math.max(1, numTargets) * entryHeight
    hudFrame:SetHeight(totalHeight)
    
    local fontSize = STA_Saved:Get("hudFontSize") or 12
    
    if numTargets == 0 then
        local entry = self:GetHUDEntry(1, fontSize)
        if entry then
            if entry.enemyText then
                entry.enemyText:SetText("(none)")
                entry.enemyText:SetTextColor(unpack(COLOR_DIM))
            end
            if entry.dashText then entry.dashText:SetText("") end
            if entry.friendlyText then entry.friendlyText:SetText("") end
            entry:Show()
        end
        return
    end
    
    for i, data in ipairs(targets) do
        local entry = self:GetHUDEntry(i, fontSize)
        if entry and data then
            -- Enemy name in RED
            if entry.enemyText then
                entry.enemyText:SetText(data.name or "?")
                entry.enemyText:SetTextColor(unpack(COLOR_DANGER))
            end
            
            -- Dash separator
            if entry.dashText then
                entry.dashText:SetText(" - ")
                entry.dashText:SetTextColor(unpack(COLOR_NORMAL))
            end
            
            -- Friendly target name in GREEN
            if entry.friendlyText then
                entry.friendlyText:SetText(data.targetName or "?")
                entry.friendlyText:SetTextColor(unpack(COLOR_FRIENDLY))
            end
            
            entry:Show()
        end
    end
end

--============================================================================
-- HUD ENTRY CREATION
-- Creates entries with separate text elements for colored display
-- Format: EnemyName (red) - FriendlyName (green)
--============================================================================

function STA_UI:GetHUDEntry(index, fontSize)
    if not hudFrame then return nil end
    if not index then return nil end
    
    if not hudEntries[index] then
        local entry = CreateFrame("Frame", nil, hudFrame)
        entry:SetWidth(260)
        entry:SetHeight(16)
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 10, -20 - ((index - 1) * 16))
        
        -- Enemy name (red)
        local enemyText = entry:CreateFontString(nil, "OVERLAY")
        enemyText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        enemyText:ClearAllPoints()
        enemyText:SetPoint("LEFT", entry, "LEFT", 0, 0)
        enemyText:SetJustifyH("LEFT")
        entry.enemyText = enemyText
        
        -- Dash separator
        local dashText = entry:CreateFontString(nil, "OVERLAY")
        dashText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        dashText:ClearAllPoints()
        dashText:SetPoint("LEFT", enemyText, "RIGHT", 0, 0)
        dashText:SetJustifyH("LEFT")
        entry.dashText = dashText
        
        -- Friendly target name (green)
        local friendlyText = entry:CreateFontString(nil, "OVERLAY")
        friendlyText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        friendlyText:ClearAllPoints()
        friendlyText:SetPoint("LEFT", dashText, "RIGHT", 0, 0)
        friendlyText:SetJustifyH("LEFT")
        entry.friendlyText = friendlyText
        
        hudEntries[index] = entry
    end
    
    local entry = hudEntries[index]
    if entry then
        if entry.enemyText then
            entry.enemyText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        end
        if entry.dashText then
            entry.dashText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        end
        if entry.friendlyText then
            entry.friendlyText:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "")
        end
    end
    
    return entry
end
