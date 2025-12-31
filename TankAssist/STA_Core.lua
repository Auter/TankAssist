--[[
    STA_Core.lua
    Core initialization and snap function for TankAssist
    Lua 5.0 compatible, nil-safe
    
    Snap behavior:
    - If "Attempt taunt first" enabled, tries class taunt first
    - If taunt fails (out of range, cooldown, etc), immediately falls back to snap spell
    - "Cast Only" mode: soft retarget (restores original target after cast)
    - "Target + Cast" mode: permanent target change
    
    Supports: Shaman, Druid, Paladin, Warrior
]]

--============================================================================
-- PER-CLASS CONFIGURATION
-- Defines taunt spell and snap spell options for each tank class
--============================================================================

TA_CLASS_CONFIG = {
    SHAMAN = {
        tauntSpell = "Earthshaker Slam",
        snapSpells = {
            "Earth Shock",
            "Stormstrike",
            "Lightning Bolt",
            "Chain Lightning",
            "Stoneclaw Totem",
            "Lightning Strike",
        },
    },
    
    DRUID = {
        tauntSpell = "Growl",
        snapSpells = {
            "Maul",
            "Swipe",
            "Savage Bite",
        },
    },
    
    PALADIN = {
        tauntSpell = "Hand of Reckoning",
        snapSpells = {
            "Holy Strike",
            "Crusader Strike",
            "Judgement",
        },
    },
    
    WARRIOR = {
        tauntSpell = "Taunt",
        snapSpells = {
            "Revenge",
            "Thunder Clap",
            "Shield Slam",
            "Concussion Blow",
            "Sunder Armor",
            "Heroic Strike",
        },
    },
}

--============================================================================
-- GLOBAL TABLES AND ALIASES
--============================================================================

-- Primary addon table
TankAssist = {}
TA = TankAssist

-- Legacy alias for backward compatibility
ShamanTankAssist = TA
STA = TA

TA.initialized = false
TA.inCombat = false
TA.uncontrolledTargets = {}

-- Class detection (populated on init)
TA.playerClass = nil
TA.classConfig = nil
TA.isTankClass = false

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

-- Print helper message (respects hideHelperMessages setting)
function STA:Print(msg)
    if STA_Saved and STA_Saved:Get("hideHelperMessages") then
        return  -- Suppress helper messages
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[TA]|r " .. tostring(msg or ""))
    end
end

function STA:SafeUnitName(unit)
    if not unit then return nil end
    if type(UnitExists) ~= "function" then return nil end
    if not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    if not name or name == "" or name == "Unknown" then return nil end
    return name
end

function STA:IsValidUnit(unit)
    if not unit then return false end
    if type(UnitExists) ~= "function" then return false end
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    return true
end

function STA:GetGroupMembers()
    local members = {}
    local playerName = self:SafeUnitName("player")
    if playerName then
        table.insert(members, {name = playerName, unit = "player"})
    end
    
    local numRaid = 0
    if type(GetNumRaidMembers) == "function" then
        numRaid = GetNumRaidMembers() or 0
    end
    
    if numRaid > 0 then
        for i = 1, 40 do
            if type(GetRaidRosterInfo) == "function" then
                local raidName = GetRaidRosterInfo(i)
                if raidName and raidName ~= "" and raidName ~= playerName then
                    table.insert(members, {name = raidName, unit = "raid" .. i})
                end
            end
        end
    else
        local numParty = 0
        if type(GetNumPartyMembers) == "function" then
            numParty = GetNumPartyMembers() or 0
        end
        for i = 1, numParty do
            local name = self:SafeUnitName("party" .. i)
            if name then
                table.insert(members, {name = name, unit = "party" .. i})
            end
        end
    end
    
    return members
end

--============================================================================
-- SPELL UTILITY FUNCTIONS (1.12 compatible - no IsUsableSpell)
--============================================================================

function STA:FindSpellIndex(spellName)
    if not spellName then return nil end
    
    local spellNameLower = strlower(spellName)
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if strlower(name) == spellNameLower then
            return i
        end
        i = i + 1
        if i > 500 then break end
    end
    return nil
end

function STA:IsSpellKnown(spellName)
    local index = self:FindSpellIndex(spellName)
    if index then
        return true, index
    end
    return false, nil
end

function STA:CanCastSpell(spellName, unit)
    if not spellName then return false end
    
    local spellIndex = self:FindSpellIndex(spellName)
    if not spellIndex then return false end
    
    local start, duration, enabled = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
    if start and duration and duration > 1.5 then
        return false
    end
    
    if unit and UnitExists(unit) then
        local inRange = IsSpellInRange(spellName, unit)
        if inRange == 0 then
            return false
        end
    end
    
    return true
end

--============================================================================
-- INITIALIZATION
--============================================================================

function STA:Initialize()
    if self.initialized then return end
    
    -- Detect player class and configure
    local _, playerClass = UnitClass("player")
    TA.playerClass = playerClass
    TA.classConfig = TA_CLASS_CONFIG and TA_CLASS_CONFIG[playerClass] or nil
    TA.isTankClass = (TA.classConfig ~= nil)
    
    -- Short-circuit if not a supported tank class
    if not TA.isTankClass then
        -- Addon is dormant for this class
        return
    end
    
    self.initialized = true
    
    STA_Saved:Initialize()
    
    -- Initialize combat module (may be nil if file failed to load)
    if STA_Combat and STA_Combat.Initialize then
        STA_Combat:Initialize()
    end
    
    -- Initialize UI module
    if STA_UI and STA_UI.Initialize then
        STA_UI:Initialize()
    end
    
    BINDING_HEADER_SHAMANTANKASSIST = "TankAssist"
    BINDING_HEADER_TANKASSIST = "TankAssist"
    BINDING_NAME_STA_SNAP = "Snap Attention Key"
    BINDING_NAME_TA_SNAP = "Snap Attention Key"
    
    self:Print("Loaded. Type /ta or /sta to open options.")
end

--============================================================================
-- EVENT HANDLING
--============================================================================

local function OnEvent()
    local e = event
    
    if e == "PLAYER_LOGIN" or e == "VARIABLES_LOADED" then
        STA:Initialize()
        
    elseif e == "PLAYER_ENTERING_WORLD" then
        if not STA.initialized then
            STA:Initialize()
        end
        if STA_UI and STA_UI.RefreshProtectedList then
            STA_UI:RefreshProtectedList()
        end
        
    elseif e == "PLAYER_REGEN_DISABLED" then
        STA.inCombat = true
        if STA_UI and STA_UI.OnCombatStart then
            STA_UI:OnCombatStart()
        end
        
    elseif e == "PLAYER_REGEN_ENABLED" then
        STA.inCombat = false
        STA.uncontrolledTargets = {}
        if STA_UI and STA_UI.OnCombatEnd then
            STA_UI:OnCombatEnd()
        end
        
    elseif e == "PARTY_MEMBERS_CHANGED" or e == "RAID_ROSTER_UPDATE" then
        if STA_UI and STA_UI.RefreshProtectedList then
            STA_UI:RefreshProtectedList()
        end
    end
end

--============================================================================
-- SNAP FUNCTION
-- Single-press behavior: tries taunt first, if it fails, immediately casts
-- the fallback spell. No delays, no second press required.
--============================================================================

function STA_Snap()
    -- Guard: not in combat
    if not STA.inCombat then
        STA:Print("Not in combat.")
        return
    end
    
    -- Force update uncontrolled targets
    if STA_Combat and STA_Combat.UpdateUncontrolledTargets then
        STA_Combat:UpdateUncontrolledTargets()
    end
    
    -- Get best target
    local target = nil
    if STA_Combat and STA_Combat.GetBestSnapTarget then
        target = STA_Combat:GetBestSnapTarget()
    end
    
    -- Guard: no valid target
    if not target then
        STA:Print("No valid targets.")
        return
    end
    
    if not target.unit or not UnitExists(target.unit) then
        STA:Print("No valid targets.")
        return
    end
    
    local action = STA_Saved:Get("snapAction") or "targetcast"
    local attemptTaunt = STA_Saved:Get("attemptTauntFirst")
    local configuredSpell = STA_Saved:Get("snapSpell")
    
    -- Get taunt spell from class config (defaults to Earthshaker Slam for backward compat)
    local tauntSpell = "Earthshaker Slam"
    if TA.classConfig and TA.classConfig.tauntSpell then
        tauntSpell = TA.classConfig.tauntSpell
    end
    
    -- Check if we can use taunt
    local canTaunt = false
    if attemptTaunt then
        canTaunt = STA:CanCastSpell(tauntSpell, target.unit)
    end
    
    -- Determine the snap spell (fallback)
    local snapSpell = nil
    if configuredSpell and configuredSpell ~= "none" and configuredSpell ~= "" then
        if STA:IsSpellKnown(configuredSpell) then
            snapSpell = configuredSpell
        end
    end
    
    ----------------------------------------------------------
    -- TARGET ONLY MODE
    ----------------------------------------------------------
    if action == "targetonly" then
        TargetUnit(target.unit)
        if STA_Saved:Get("markWithSkull") then
            SetRaidTarget("target", 8)
        end
        return
    end
    
    ----------------------------------------------------------
    -- CAST ONLY MODE (soft retarget - restore original)
    -- Immediate behavior: taunt OR fallback, then restore target
    ----------------------------------------------------------
    if action == "castonly" then
        local hadPreviousTarget = UnitExists("target")
        local previousTargetName = nil
        if hadPreviousTarget then
            previousTargetName = UnitName("target")
        end
        
        TargetUnit(target.unit)
        
        -- Try taunt first, if it fails use fallback spell immediately
        if canTaunt then
            CastSpellByName(tauntSpell)
        elseif snapSpell then
            CastSpellByName(snapSpell)
        end
        
        -- Restore original target
        if hadPreviousTarget and previousTargetName then
            TargetLastTarget()
            if UnitName("target") ~= previousTargetName then
                TargetByName(previousTargetName, true)
            end
        elseif not hadPreviousTarget then
            ClearTarget()
        end
        
        return
    end
    
    ----------------------------------------------------------
    -- TARGET + CAST MODE (permanent target change)
    -- Immediate behavior: taunt OR fallback spell
    ----------------------------------------------------------
    TargetUnit(target.unit)
    
    if STA_Saved:Get("markWithSkull") then
        SetRaidTarget("target", 8)
    end
    
    -- Try taunt first, if it fails use fallback spell immediately
    if canTaunt then
        CastSpellByName(tauntSpell)
    elseif snapSpell then
        CastSpellByName(snapSpell)
    end
end

-- Alias for TankAssist naming
TA_Snap = STA_Snap

--============================================================================
-- SLASH COMMANDS
--============================================================================

-- Shared handler for all slash commands
local function HandleSlashCommand(msg)
    msg = strlower(msg or "")
    if msg == "reset" then
        STA_Saved:Reset()
        STA:Print("Settings reset. Reloading...")
        ReloadUI()
    elseif msg == "lock" then
        STA_Saved:Set("hudLocked", true)
        if STA_UI and STA_UI.UpdateHUDLock then
            STA_UI:UpdateHUDLock()
        end
        STA:Print("HUD locked.")
    elseif msg == "unlock" then
        STA_Saved:Set("hudLocked", false)
        if STA_UI and STA_UI.UpdateHUDLock then
            STA_UI:UpdateHUDLock()
        end
        STA:Print("HUD unlocked.")
    else
        if STA_UI and STA_UI.ToggleOptions then
            STA_UI:ToggleOptions()
        end
    end
end

-- Original STA commands (kept for backward compatibility)
SLASH_SHAMANTANKASSIST1 = "/sta"
SLASH_SHAMANTANKASSIST2 = "/shamantankassist"
SlashCmdList["SHAMANTANKASSIST"] = HandleSlashCommand

-- New TankAssist commands
SLASH_TANKASSIST1 = "/ta"
SLASH_TANKASSIST2 = "/tankassist"
SlashCmdList["TANKASSIST"] = HandleSlashCommand

--============================================================================
-- EVENT FRAME
--============================================================================

local eventFrame = CreateFrame("Frame", "STA_EventFrame", UIParent)
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
