--[[
    STA_Saved.lua
    Saved variables management for TankAssist
    Lua 5.0 compatible, nil-safe
]]

STA_Saved = {}

local DEFAULTS = {
    protectedPlayers = {},
    hudLocked = false,
    hudScale = 1.0,
    hudFontSize = 12,
    hudPosX = 0,
    hudPosY = 150,
    showHUDWhileConfiguring = false,
    hideHUDOutOfCombat = true,
    hideHelperMessages = false,
    snapAction = "targetcast",
    snapSpell = "none",
    attemptTauntFirst = true,
    preferFurthestEnemy = false,
    preferNearest = true,
    respectCC = true,
    markWithSkull = false,
}

local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function STA_Saved:Initialize()
    -- Migrate from old DB name if needed
    if type(ShamanTankAssistDB) == "table" and type(TankAssistDB) ~= "table" then
        TankAssistDB = DeepCopy(ShamanTankAssistDB)
    end
    
    if type(TankAssistDB) ~= "table" then
        TankAssistDB = {}
    end
    
    for key, defaultValue in pairs(DEFAULTS) do
        if TankAssistDB[key] == nil then
            if type(defaultValue) == "table" then
                TankAssistDB[key] = DeepCopy(defaultValue)
            else
                TankAssistDB[key] = defaultValue
            end
        end
    end
    self:Validate()
end

function STA_Saved:Validate()
    local db = TankAssistDB
    if not db then return end
    
    if type(db.protectedPlayers) ~= "table" then
        db.protectedPlayers = {}
    end
    
    if type(db.hudScale) ~= "number" then
        db.hudScale = 1.0
    else
        db.hudScale = math.max(0.5, math.min(2.0, db.hudScale))
    end
    
    if type(db.hudFontSize) ~= "number" then
        db.hudFontSize = 12
    else
        db.hudFontSize = math.max(8, math.min(18, db.hudFontSize))
    end
    
    local validActions = {targetcast = true, targetonly = true, castonly = true}
    if not validActions[db.snapAction] then
        db.snapAction = "targetcast"
    end
    
    -- Valid spells for all tank classes
    local validSpells = {
        -- Shaman
        ["Earth Shock"] = true,
        ["Stormstrike"] = true,
        ["Lightning Bolt"] = true,
        ["Chain Lightning"] = true,
        ["Stoneclaw Totem"] = true,
        ["Lightning Strike"] = true,
        -- Druid
        ["Maul"] = true,
        ["Swipe"] = true,
        ["Savage Bite"] = true,
        -- Paladin
        ["Holy Strike"] = true,
        ["Crusader Strike"] = true,
        ["Judgement"] = true,
        -- Warrior
        ["Revenge"] = true,
        ["Thunder Clap"] = true,
        ["Shield Slam"] = true,
        ["Concussion Blow"] = true,
        ["Sunder Armor"] = true,
        ["Heroic Strike"] = true,
        -- None option
        ["none"] = true
    }
    if not validSpells[db.snapSpell] then
        db.snapSpell = "none"
    end
    
    local boolKeys = {"hudLocked", "showHUDWhileConfiguring", "hideHUDOutOfCombat", "hideHelperMessages", "attemptTauntFirst", "preferFurthestEnemy", "preferNearest", "respectCC", "markWithSkull"}
    for _, key in ipairs(boolKeys) do
        if type(db[key]) ~= "boolean" then
            db[key] = DEFAULTS[key]
        end
    end
    
    -- Clean up deprecated settings
    db.preferHealerAttackers = nil
    db.preferCasters = nil
end

function STA_Saved:Get(key)
    if not TankAssistDB then return DEFAULTS[key] end
    local value = TankAssistDB[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function STA_Saved:Set(key, value)
    if not TankAssistDB then TankAssistDB = {} end
    TankAssistDB[key] = value
end

function STA_Saved:IsProtected(name)
    if not name then return false end
    local playerName = UnitName("player")
    if playerName and name == playerName then return true end
    local protected = self:Get("protectedPlayers")
    if type(protected) ~= "table" then return false end
    return protected[name] == true
end

function STA_Saved:ToggleProtected(name)
    if not name then return end
    local playerName = UnitName("player")
    if playerName and name == playerName then return end
    if not TankAssistDB then TankAssistDB = {} end
    if type(TankAssistDB.protectedPlayers) ~= "table" then
        TankAssistDB.protectedPlayers = {}
    end
    if TankAssistDB.protectedPlayers[name] then
        TankAssistDB.protectedPlayers[name] = nil
    else
        TankAssistDB.protectedPlayers[name] = true
    end
end

function STA_Saved:Reset()
    TankAssistDB = DeepCopy(DEFAULTS)
end
