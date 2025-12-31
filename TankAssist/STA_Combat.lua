--[[
    STA_Combat.lua
    Combat scanning and uncontrolled target detection for TankAssist
    Lua 5.0 compatible, nil-safe
    
    Enemy detection uses only real unitIDs from target chains:
    - Player: target, targettarget, targettargettarget
    - Party/Raid: partyX/raidX + their target chains
    - Pets: player pet, party/raid pets + their target chains
    
    No nameplate scanning, no threat APIs, no combat log parsing.
    Every HUD entry is backed by a valid unitID.
]]

STA_Combat = {}

local UPDATE_INTERVAL = 0.25
local updateTimer = 0

-- SuperWoW detection flag (used only for distance calculation, not discovery)
STA_Combat.hasSuperWoW = false

--============================================================================
-- INITIALIZATION
--============================================================================

function STA_Combat:Initialize()
    local frame = CreateFrame("Frame", "STA_CombatFrame", UIParent)
    frame:SetScript("OnUpdate", function()
        STA_Combat:OnUpdate(arg1)
    end)
    self.frame = frame
    
    -- Detect SuperWoW for distance calculation only
    self:DetectSuperWoW()
end

--============================================================================
-- SUPERWOW DETECTION
-- Only used for precise distance calculation (prefer nearest/furthest)
-- NOT used for enemy discovery
--============================================================================

function STA_Combat:DetectSuperWoW()
    if type(UnitXP) == "function" then
        local px = UnitXP("player", "x")
        if px and type(px) == "number" then
            self.hasSuperWoW = true
        end
    end
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function STA_Combat:OnUpdate(elapsed)
    if not STA or not STA.inCombat then return end
    
    updateTimer = updateTimer + (elapsed or 0.016)
    if updateTimer < UPDATE_INTERVAL then return end
    updateTimer = 0
    
    self:UpdateUncontrolledTargets()
    
    if STA_UI and STA_UI.RefreshHUD then
        STA_UI:RefreshHUD()
    end
end

--============================================================================
-- CC DETECTION
--============================================================================

function STA_Combat:HasCC(unit)
    if not unit then return false end
    if not UnitExists(unit) then return false end
    
    for i = 1, 16 do
        local texture = UnitDebuff(unit, i)
        if not texture then break end
        
        local texLower = strlower(texture)
        if strfind(texLower, "polymorph") then return true end
        if strfind(texLower, "sap") then return true end
        if strfind(texLower, "hex") then return true end
        if strfind(texLower, "sleep") then return true end
        if strfind(texLower, "hibernate") then return true end
        if strfind(texLower, "shackle") then return true end
    end
    
    return false
end

--============================================================================
-- HEALER DETECTION
--============================================================================

function STA_Combat:IsHealer(unit)
    if not unit then return false end
    if not UnitExists(unit) then return false end
    
    local _, class = UnitClass(unit)
    if not class then return false end
    
    local healerClasses = {PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true}
    if healerClasses[class] then
        local maxMana = UnitManaMax(unit)
        if maxMana and maxMana > 0 then
            return true
        end
    end
    
    return false
end

--============================================================================
-- DISTANCE ESTIMATION
-- Uses SuperWoW UnitXP for precise distance if available
-- Falls back to CheckInteractDistance otherwise
--============================================================================

function STA_Combat:GetDistance(unit)
    if not unit then return 100 end
    if not UnitExists(unit) then return 100 end
    
    -- Try SuperWoW precise distance first
    if self.hasSuperWoW then
        local dist = self:GetSuperWoWDistance(unit)
        if dist then return dist end
    end
    
    -- Fallback to interact distance estimation
    if CheckInteractDistance(unit, 3) then return 5 end
    if CheckInteractDistance(unit, 2) then return 10 end
    if CheckInteractDistance(unit, 1) then return 20 end
    return 40
end

function STA_Combat:GetSuperWoWDistance(unit)
    if not self.hasSuperWoW then return nil end
    if not unit or not UnitExists(unit) then return nil end
    
    local px = UnitXP("player", "x")
    local py = UnitXP("player", "y")
    local pz = UnitXP("player", "z")
    local ux = UnitXP(unit, "x")
    local uy = UnitXP(unit, "y")
    local uz = UnitXP(unit, "z")
    
    if not px or not py or not pz then return nil end
    if not ux or not uy or not uz then return nil end
    
    local dx = ux - px
    local dy = uy - py
    local dz = uz - pz
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

--============================================================================
-- ENEMY COLLECTION
-- Discovers enemies using ONLY real unitIDs from target chains.
-- No nameplates, no combat log, no threat APIs.
-- Each enemy is deduplicated using UnitIsUnit().
--============================================================================

function STA_Combat:CollectEnemyUnits()
    local units = {}
    
    -- Check if unit is already collected using UnitIsUnit
    local function isAlreadyCollected(checkUnit)
        for _, existingUnit in ipairs(units) do
            if UnitIsUnit(checkUnit, existingUnit) then
                return true
            end
        end
        return false
    end
    
    -- Add enemy unit if valid (hostile, alive, in combat)
    local function addEnemyUnit(unitId)
        if not unitId then return end
        if not UnitExists(unitId) then return end
        
        -- Must have a name
        local name = UnitName(unitId)
        if not name or name == "" then return end
        
        -- Must be hostile
        if not UnitCanAttack("player", unitId) then return end
        
        -- Must be alive
        if UnitIsDead(unitId) then return end
        
        -- Must be in combat
        if not UnitAffectingCombat(unitId) then return end
        
        -- Deduplicate using UnitIsUnit
        if isAlreadyCollected(unitId) then return end
        
        table.insert(units, unitId)
    end
    
    -- Scan a base unit's target chain (up to 3 levels deep)
    local function scanTargetChain(baseUnit)
        if not baseUnit then return end
        if not UnitExists(baseUnit) then return end
        
        local t1 = baseUnit .. "target"
        local t2 = t1 .. "target"
        local t3 = t2 .. "target"
        
        addEnemyUnit(t1)
        if UnitExists(t1) then
            addEnemyUnit(t2)
            if UnitExists(t2) then
                addEnemyUnit(t3)
            end
        end
    end
    
    ------------------------------------------------------------------
    -- PLAYER TARGET CHAIN
    ------------------------------------------------------------------
    scanTargetChain("player")
    
    ------------------------------------------------------------------
    -- PLAYER PET TARGET CHAIN
    ------------------------------------------------------------------
    if UnitExists("pet") then
        scanTargetChain("pet")
    end
    
    ------------------------------------------------------------------
    -- PARTY/RAID MEMBER TARGET CHAINS
    ------------------------------------------------------------------
    local numRaid = 0
    if type(GetNumRaidMembers) == "function" then
        numRaid = GetNumRaidMembers() or 0
    end
    
    if numRaid > 0 then
        -- In a raid
        for i = 1, 40 do
            local raidUnit = "raid" .. i
            if UnitExists(raidUnit) and not UnitIsUnit(raidUnit, "player") then
                scanTargetChain(raidUnit)
                
                -- Raid member's pet
                local raidPet = raidUnit .. "pet"
                if UnitExists(raidPet) then
                    scanTargetChain(raidPet)
                end
            end
        end
    else
        -- In a party
        local numParty = 0
        if type(GetNumPartyMembers) == "function" then
            numParty = GetNumPartyMembers() or 0
        end
        
        for i = 1, numParty do
            local partyUnit = "party" .. i
            if UnitExists(partyUnit) then
                scanTargetChain(partyUnit)
                
                -- Party member's pet
                local partyPet = partyUnit .. "pet"
                if UnitExists(partyPet) then
                    scanTargetChain(partyPet)
                end
            end
        end
    end
    
    return units
end

--============================================================================
-- CHECK IF UNIT IS A PARTY OR RAID MEMBER (including pets)
--============================================================================

function STA_Combat:IsPartyOrRaidMember(unit)
    if not unit then return false end
    if not UnitExists(unit) then return false end
    
    -- Check player
    if UnitIsUnit(unit, "player") then
        return true
    end
    
    -- Check player pet
    if UnitExists("pet") and UnitIsUnit(unit, "pet") then
        return true
    end
    
    -- Get group counts
    local numParty = 0
    local numRaid = 0
    if type(GetNumPartyMembers) == "function" then
        numParty = GetNumPartyMembers() or 0
    end
    if type(GetNumRaidMembers) == "function" then
        numRaid = GetNumRaidMembers() or 0
    end
    
    -- Check party members and their pets
    for i = 1, numParty do
        local partyUnit = "party" .. i
        if UnitIsUnit(unit, partyUnit) then
            return true
        end
        local partyPet = partyUnit .. "pet"
        if UnitExists(partyPet) and UnitIsUnit(unit, partyPet) then
            return true
        end
    end
    
    -- Check raid members and their pets
    for i = 1, numRaid do
        local raidUnit = "raid" .. i
        if UnitIsUnit(unit, raidUnit) then
            return true
        end
        local raidPet = raidUnit .. "pet"
        if UnitExists(raidPet) and UnitIsUnit(unit, raidPet) then
            return true
        end
    end
    
    return false
end

--============================================================================
-- CHECK IF ENEMY IS UNCONTROLLED
-- An enemy is "uncontrolled" if:
--   1. It exists and has a valid target
--   2. It is NOT targeting itself
--   3. It is NOT targeting the player (we have aggro = controlled)
--   4. It IS targeting a party/raid member or their pet
--   5. That target is NOT on the protected list
--   6. The enemy is not CC'd (if respectCC option is enabled)
--============================================================================

function STA_Combat:IsUncontrolled(unit)
    if not unit then return false end
    if not UnitExists(unit) then return false end
    
    -- Enemy must have a target we can see
    local targetUnit = unit .. "target"
    if not UnitExists(targetUnit) then
        return false
    end
    
    -- Skip if targeting itself (casters sometimes do this)
    if UnitIsUnit(unit, targetUnit) then
        return false
    end
    
    -- Skip if targeting player (we have aggro = controlled)
    if UnitIsUnit(targetUnit, "player") then
        return false
    end
    
    -- Must be targeting a party/raid member or their pet
    if not self:IsPartyOrRaidMember(targetUnit) then
        return false
    end
    
    -- Get target name for protected check
    local targetName = UnitName(targetUnit)
    if not targetName or targetName == "" then
        return false
    end
    
    -- Skip if targeting a protected player
    if STA_Saved and STA_Saved.IsProtected and STA_Saved:IsProtected(targetName) then
        return false
    end
    
    -- Skip if CC'd and respectCC option is enabled
    if STA_Saved and STA_Saved.Get and STA_Saved:Get("respectCC") then
        if self:HasCC(unit) then
            return false
        end
    end
    
    return true
end

--============================================================================
-- UPDATE UNCONTROLLED TARGETS LIST
-- This is the SINGLE SOURCE OF TRUTH for HUD display and snap targeting
--============================================================================

function STA_Combat:UpdateUncontrolledTargets()
    local results = {}
    
    local enemies = self:CollectEnemyUnits()
    if not enemies then
        if STA then STA.uncontrolledTargets = results end
        return
    end
    
    for _, unit in ipairs(enemies) do
        if self:IsUncontrolled(unit) then
            local targetUnit = unit .. "target"
            local enemyName = UnitName(unit) or "Unknown"
            local targetName = UnitName(targetUnit) or "Unknown"
            
            table.insert(results, {
                unit = unit,
                name = enemyName,
                targetName = targetName,
                targetUnit = targetUnit,
                isHealerTarget = self:IsHealer(targetUnit),
                distance = self:GetDistance(unit),
            })
        end
    end
    
    if STA then STA.uncontrolledTargets = results end
end

--============================================================================
-- GET BEST SNAP TARGET
-- Priority logic (mutually exclusive):
--   1. If preferFurthestEnemy enabled: pick enemy with maximum distance
--   2. Else if preferNearest enabled: pick enemy with minimum distance
--   3. Else fallback: return first available enemy
--============================================================================

function STA_Combat:GetBestSnapTarget()
    if not STA then return nil end
    local targets = STA.uncontrolledTargets
    if not targets or table.getn(targets) == 0 then return nil end
    
    local preferFurthest = STA_Saved and STA_Saved:Get("preferFurthestEnemy")
    local preferNearest = STA_Saved and STA_Saved:Get("preferNearest")
    
    local best = nil
    local bestDist = nil
    
    for _, entry in ipairs(targets) do
        if entry and entry.unit and UnitExists(entry.unit) then
            local dist = entry.distance or 40
            
            if preferFurthest then
                if not bestDist or dist > bestDist then
                    bestDist = dist
                    best = entry
                end
            elseif preferNearest then
                if not bestDist or dist < bestDist then
                    bestDist = dist
                    best = entry
                end
            else
                -- First valid target
                if not best then
                    best = entry
                end
            end
        end
    end
    
    return best
end
