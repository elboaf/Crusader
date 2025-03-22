-- Addon Name
local addonName, addon = "Crusader", {}
local inCombat = false

local lastCleanseTime = 0
local cleanseCooldown = 5 -- Cooldown duration in seconds
local kingsMode = 0 -- 0 = off, 1 = kings mode
local salvationMode = 0 -- 0 = mana-specific mode, 1 = salvation mode
local sancMode = 0 -- 0 = off, 1 = on
local lightMode = 0 -- 0 = off, 1 = on



-- Spell Names
local HAMMER_OF_WRATH = "Hammer of Wrath" -- New spell
local BLESSING_OF_MIGHT = "Blessing of Might"
local BLESSING_OF_WISDOM = "Blessing of Wisdom"
local BLESSING_OF_SANCTUARY = "Blessing of Sanctuary"
local BLESSING_OF_SALVATION = "Blessing of Salvation"
local BLESSING_OF_KINGS = "Blessing of Kings"
local DEVOTION_AURA = "Devotion Aura"
local RIGHTEOUS_FURY = "Righteous Fury"
local SEAL_OF_COMMAND = "Seal of Command"
local HOLY_SHIELD = "Holy Shield"
local BULWARK = "Bulwark of the Righteous"
local SEAL_OF_RIGHTEOUSNESS = "Seal of Righteousness"
local SEAL_OF_MODE = SEAL_OF_RIGHTEOUSNESS -- Default to Seal of Command
local SEAL_OF_WISDOM = "Seal of Wisdom"
local SEAL_OF_LIGHT = "Seal of Light"
local JUDGEMENT = "Judgement"
local CRUSADER_STRIKE = "Crusader Strike"
local CONSECRATION = "Consecration"
local HOLY_STRIKE = "Holy Strike"
local HAND_OF_PROTECTION = "Hand of Protection"
local LAY_ON_HANDS = "Lay on Hands(Rank 3)"
local DISPEL = "Cleanse"
local FREEDOM = "Hand of Freedom"
local FLASH_OF_LIGHT = "Flash of Light"
local strikeWeave = 0
local threatmode = 1
local hammertime = false
local protmode = 1 -- 0 = normal, 1 = prot mode
local blessingsEnabled = true -- Default to true, meaning blessings are enabled

-- Throttle variables for Judgement
local sealOfCommandCastTime = 0
local judgementThrottleDuration = 25 -- 20 seconds throttle

-- Debuff Lists
local DEBUFFS_TO_DISPEL = {
    "Nature_Regenerate",
    "HarmUndead",
    "CallofBone",
    "CorrosiveBreath",
    "NullifyDisease",
    "Poison",
    "CreepingPlague",
    "ShadowWordPain",
    "Polymorph",
    "Immolation",
    "Sleep",
    "FrostNova",
    "FlameShock",
    "ThunderClap",
    "Nature_Sleep",
    "StrangleVines",
    "Slow",
    "AbominationExplosion",
    "Shadow_Teleport",
    "Shaman_Hex",
    "SummonImp",
    "Taunt",
    "AnimateDead",
    "Shadow_Cripple",
    "FrostArmor",
    "Shadow_Possession",
    "SummonWaterElemental",
    "Nature_Cyclone",
    "GolemThunderClap",
    -- Add more debuff names here as ne,eeded
}

local DEBUFFS_TO_FREEDOM = {
    "snare",
    "ShockWave",
    "CriticalStrike",
    -- Add more debuff names here as needed
}

local SpellTextureToName = {
    ["RighteousnessAura"] = "Seal of Wisdom",          -- Partial texture path for Seal of Wisdom
    ["LightningShield"] = "Blessing of Sanctuary",     -- Partial texture path for Blessing of Sanctuary
    ["DevotionAura"] = "Devotion Aura",                -- Partial texture path for Devotion Aura
    ["SealOfFury"] = "Righteous Fury",                 -- Partial texture path for Righteous Fury
    ["ThunderBolt"] = "Seal of Righteousness",         -- Partial texture path for Seal of Righteousness
    ["HealingAura"] = "Seal of Light",         -- Partial texture path for Seal of Righteousness
    ["SealOfSalvation"] = "Blessing of Salvation",     -- Partial texture path for Blessing of Salvation
    ["FistOfJustice"] = "Blessing of Might",           -- Partial texture path for Blessing of Might
    ["BlessingOfProtection"] = "Holy Shield",          -- Partial texture path for Holy Shield
    ["SealOfWisdom"] = "Blessing of Wisdom",
    ["Magic_MageArmor"] = "Blessing of Kings",
    -- Add more mappings here as needed

    -- Greater Blessings
    ["GreaterBlessingofSanctuary"] = "Greater Blessing of Sanctuary",  -- Partial texture path for Greater Blessing of Sanctuary
    ["GreaterBlessingofSalvation"] = "Greater Blessing of Salvation",  -- Partial texture path for Greater Blessing of Salvation
    ["Holy_GreaterBlessingofKings"] = "Greater Blessing of Might",        -- Partial texture path for Greater Blessing of Might
    ["GreaterBlessingofWisdom"] = "Greater Blessing of Wisdom",        -- Partial texture path for Greater Blessing of Wisdom
    ["Magic_GreaterBlessingofKings"] = "Greater Blessing of Kings",        -- Partial texture path for Greater Blessing of Kings
}


-- Add a table to map classes to their respective blessings
local CLASS_TO_BLESSING = {
    ["WARRIOR"] = BLESSING_OF_KINGS,
    ["PALADIN"] = BLESSING_OF_KINGS, -- Paladins might prefer Might or Kings depending on build
    ["HUNTER"] = BLESSING_OF_MIGHT,
    ["ROGUE"] = BLESSING_OF_MIGHT,
    ["PRIEST"] = BLESSING_OF_WISDOM,
    ["SHAMAN"] = BLESSING_OF_KINGS,
    ["MAGE"] = BLESSING_OF_KINGS,
    ["WARLOCK"] = BLESSING_OF_KINGS,
    ["DRUID"] = BLESSING_OF_KINGS, -- Druids might prefer Wisdom or Kings depending on role
}



-- Table to track combat events
local combatEvents = {}
local combatTimeout = 5 -- Time in seconds to consider an enemy out of combat
local attackInterval = 2 -- Average attack interval in seconds

local function IterateGroupMembers(callback)
    -- Check party members (party1 to party4)
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) then
            callback(partyMember)
        end
    end

    -- Check raid members (raid1 to raid40) if in a raid
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local raidMember = "raid" .. i
            if UnitExists(raidMember) then
                callback(raidMember)
            end
        end
    end
end


local function GetBlessingForUnit(unit)
    local _, classToken = UnitClass(unit)
    classToken = string.upper(classToken) -- Ensure it matches the table keys
    local blessing = CLASS_TO_BLESSING[classToken] or BLESSING_OF_KINGS
    --DEFAULT_CHAT_FRAME:AddMessage("Class for unit " .. UnitName(unit) .. ": " .. classToken)
    --DEFAULT_CHAT_FRAME:AddMessage("Assigned blessing: " .. (blessing or "None (defaulting to Kings)"))
    return blessing
end

-- Function to handle combat events from chat messages
local function HandleCombatChatMessage(event, message)
    -- Track all incoming attacks (enemies attacking you)
    if event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" or
       event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or
       event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_CRITS" then
        local enemyName = strmatch(message, "(.+) hits you") or
                          strmatch(message, "(.+) crits you") or
                          strmatch(message, "(.+) misses you") or
                          strmatch(message, "(.+) attacks. You parry")
        if enemyName then
            --DEFAULT_CHAT_FRAME:AddMessage("Enemy attacked the player: " .. enemyName)
            if not combatEvents[enemyName] then
                -- Initialize the enemy's data if it doesn't exist
                combatEvents[enemyName] = { count = 1, lastAttackTime = GetTime() }
            else
                local currentTime = GetTime()
                local timeSinceLastAttack = currentTime - combatEvents[enemyName].lastAttackTime

                -- If the time since the last attack is less than the attack interval, increment the count
                if timeSinceLastAttack < attackInterval then
                    combatEvents[enemyName].count = combatEvents[enemyName].count + 1
                else
                    -- Reset the count if the attack is outside the attack interval
                    combatEvents[enemyName].count = 1
                end
                combatEvents[enemyName].lastAttackTime = currentTime
            end
        end
    end
end

-- Function to update combat events and count active enemies
local function UpdateCombatEvents()
    local currentTime = GetTime()
    local activeEnemies = 0

    for enemyName, data in pairs(combatEvents) do
        if currentTime - data.lastAttackTime > combatTimeout then
            -- Remove the enemy if they haven't attacked within the timeout
            combatEvents[enemyName] = nil
        else
            -- Add the inferred count for this enemy name
            activeEnemies = activeEnemies + data.count
        end
    end

   -- DEFAULT_CHAT_FRAME:AddMessage("Active enemies: " .. activeEnemies)
    return activeEnemies
end

-- Register chat combat events
local frame = CreateFrame("Frame")
DEFAULT_CHAT_FRAME:AddMessage("Frame created successfully.")
frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
frame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
DEFAULT_CHAT_FRAME:AddMessage("Events registered successfully.")
frame:SetScript("OnEvent", function()
HandleCombatChatMessage(event, arg1)
end
)

frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Player enters combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Player exits combat

-- Function to find a spell ID by name
local function FindSpellID(spellName)
    for i = 1, 180 do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if name and strfind(name, spellName) then
            return i
        end
    end
    return nil
end

-- Function to check if a spell is ready
local function IsSpellReady(spellName)
    local spellID = FindSpellID(spellName)
    if spellID then
        local start, duration = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
        return start == 0 and duration <= 1.5 -- Cooldown is ready
    end
    return false
end

-- Function to cast Consecration if in combat with 3 or more enemies
local function CastConsecrationIfNeeded()
    local activeEnemies = UpdateCombatEvents()
    if activeEnemies >= 3 and IsSpellReady(CONSECRATION) then
        --DEFAULT_CHAT_FRAME:AddMessage("Casting Consecration.")
        CastSpellByName(CONSECRATION)
    end
end

-- Function to check if a unit is a mana user
local function IsManaUser(unit)
    local powerType = UnitPowerType(unit)
    return powerType == 0 -- 0 = Mana, 1 = Rage, 2 = Focus, 3 = Energy
end

-- Function to check if a unit has any of the debuffs in the list
local function HasDebuff(unit, debuffList)
    for i = 1, 16 do
        local name = UnitDebuff(unit, i)
        if name then
            for _, debuff in ipairs(debuffList) do
                if strfind(name, debuff) then
                    return true
                end
            end
        end
    end
    return false
end

local function HasBuff(unit, buffName)
    for i = 1, 32 do
        local texture = UnitBuff(unit, i)
        if texture then
            -- Look up the spell name using the texture name
            for texturePath, spellName in pairs(SpellTextureToName) do
                if strfind(texture, texturePath) then
                    -- Check if the buff name matches either the regular or greater version
                    if spellName == buffName or spellName == "Greater " .. buffName then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function AlwaysSanc()
    -- Check if the player has either "Blessing of Sanctuary" or "Greater Blessing of Sanctuary"
    if not HasBuff("player", BLESSING_OF_SANCTUARY) then
        CastSpellByName(BLESSING_OF_SANCTUARY)
        SpellTargetUnit("player")
    end
end


local function ApplyPlayerBuffs()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100
    if manaPercentage < 75 then
        manaLow = 1
    end
    if manaPercentage >= 95 then
        manaLow = 0
    end

    -- Apply seals regardless of whether blessings are enabled
    -- Check and apply Seal of Command (always, even in combat)
    if lightMode == 0 and not HasBuff("player", SEAL_OF_MODE) and manaLow == 0 then
        CastSpellByName(SEAL_OF_MODE)
        SpellTargetUnit("player")
        sealOfCommandCastTime = GetTime() -- Record the time the seal was cast
    end

    -- Check and apply Seal of Wisdom if mana is below 50%
    if not HasBuff("player", SEAL_OF_WISDOM) and manaLow == 1 and lightMode == 0 then
        CastSpellByName(SEAL_OF_WISDOM)
        SpellTargetUnit("player")
    end

    if lightMode == 1 and not HasBuff("player", SEAL_OF_LIGHT) then
        CastSpellByName(SEAL_OF_LIGHT)
        SpellTargetUnit("player")
    end

    -- Only apply blessings if blessings are enabled
    if not blessingsEnabled then
        return -- Exit if blessings are disabled
    end

    -- Only apply other buffs if out of combat
    if not UnitAffectingCombat("player") or manaPercentage > 85 then
        -- Check and apply Blessing of Might or Blessing of Sanctuary based on protmode
        if protmode == 0 then
            if not HasBuff("player", BLESSING_OF_MIGHT) then
                CastSpellByName(BLESSING_OF_MIGHT)
                SpellTargetUnit("player")
            end
        else
            if not HasBuff("player", BLESSING_OF_SANCTUARY) then
                CastSpellByName(BLESSING_OF_SANCTUARY)
                SpellTargetUnit("player")
            end
        end

        -- Check and apply Devotion Aura
        if not HasBuff("player", DEVOTION_AURA) then
            CastSpellByName(DEVOTION_AURA)
            SpellTargetUnit("player")
        end

        -- Check and apply Righteous Fury
        if threatmode == 1 then
            if not HasBuff("player", RIGHTEOUS_FURY) then
                CastSpellByName(RIGHTEOUS_FURY)
                SpellTargetUnit("player")
            end
        end
    end
end

local function ApplyPartyBuffs()
    if not blessingsEnabled then
        return -- Exit if blessings are disabled
    end

    -- Only apply buffs if out of combat
    if not UnitAffectingCombat("player") then
        IterateGroupMembers(function(unit)
            if not UnitIsUnit(unit, "player") then
                if salvationMode == 1 then
                    -- Apply Blessing of Salvation to all group members in salvation mode
                    if not HasBuff(unit, BLESSING_OF_SALVATION) then
                        CastSpellByName(BLESSING_OF_SALVATION)
                        SpellTargetUnit(unit)
                    end
                elseif kingsMode == 1 then
                    -- Apply Blessing of Kings to all group members in kings mode
                    if not HasBuff(unit, BLESSING_OF_KINGS) then
                        CastSpellByName(BLESSING_OF_KINGS)
                        SpellTargetUnit(unit)
                    end
                else
                    -- Get the appropriate blessing for the unit's class
                    local blessing = GetBlessingForUnit(unit)
                    if not HasBuff(unit, blessing) then
                        CastSpellByName(blessing)
                        SpellTargetUnit(unit)
                    end
                end
            end
        end)
    end
end


local function CastHammerOfWrath()
    local activeEnemies = UpdateCombatEvents()
    local target = "target"
    if hammertime then
        if activeEnemies <= 2 and IsSpellReady(HAMMER_OF_WRATH) then
            if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                local targetHealth = UnitHealth(target) / UnitHealthMax(target) * 100
                if targetHealth <= 20 and IsSpellReady(HAMMER_OF_WRATH) then
                    --DEFAULT_CHAT_FRAME:AddMessage("Casting Hammer of Wrath.")
                    CastSpellByName(HAMMER_OF_WRATH)
                end
            end
        end
    end
end

local function CheckTargetsTarget()
    local target = "target"
    if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
        local targetsTarget = target .. "target" -- Get your target's target
        if UnitExists(targetsTarget) then
            -- Check if your target is not targeting you
            if not UnitIsUnit(targetsTarget, "player") then
                -- Check if Hand of Reckoning is ready
                if IsSpellReady("Hand of Reckoning") then
             --       DEFAULT_CHAT_FRAME:AddMessage("Casting Hand of Reckoning to taunt the target.")
                    -- CastSpellByName("Hand of Reckoning")
                end
            end
        end
    end
end

-- Function to check and cast abilities
local function CastAbilities()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100
    local selfHealth = UnitHealth("player") / UnitHealthMax("player") * 100

    -- Check if target exists and is attackable
    local target = "target"
    if not UnitExists(target) or not UnitCanAttack("player", target) then
        return -- Exit if there is no target or the target is not attackable
    end

    -- Check if the target is Undead and Exorcism is ready
    local creatureType = UnitCreatureType(target)
    if (creatureType == "Undead" or creatureType == "Demon") and IsSpellReady("Exorcism") then
        CastSpellByName("Exorcism")
        return -- Exit after casting Exorcism to prioritize it
    end

    -- Check if the current seal (SEAL_OF_MODE) is active and throttle Judgement
    if HasBuff("player", SEAL_OF_MODE) then
        local currentTime = GetTime()
        if currentTime - sealOfCommandCastTime < judgementThrottleDuration then
            -- Do not cast Judgement if the seal was cast within the last 20 seconds
        else
            -- Cast Judgement if the throttle duration has passed
            if IsSpellReady(JUDGEMENT) then
                CastSpellByName(JUDGEMENT)
            end
        end
    end

    -- Check if Seal of Wisdom is active and target does not have Judgement of Wisdom (debuff)
    if HasBuff("player", SEAL_OF_WISDOM) then
        if not buffed("Judgement of Wisdom", target) then
            if IsSpellReady(JUDGEMENT) then
                CastSpellByName(JUDGEMENT)
            end
        end
    end

    if HasBuff("player", SEAL_OF_LIGHT) then
        if not buffed("Judgement of Light", target) then
            if IsSpellReady(JUDGEMENT) then
                CastSpellByName(JUDGEMENT)
            end
        end
    end


    -- Cast Crusader Strike and Holy Strike in an alternating fashion
    if strikeWeave == 1 and IsSpellReady(CRUSADER_STRIKE) then
        CastSpellByName(CRUSADER_STRIKE)
        strikeWeave = 0
    elseif strikeWeave == 0 and IsSpellReady(HOLY_STRIKE) then
        CastSpellByName(HOLY_STRIKE)
        strikeWeave = 1
    end

    -- Cast Holy Shield only if in combat
    if protmode == 1 and UnitAffectingCombat("player") then
        if ((HasBuff("player", SEAL_OF_WISDOM) and buffed("Judgement of Wisdom", target)) or HasBuff("player", SEAL_OF_RIGHTEOUSNESS)) then
            if IsSpellReady(HOLY_SHIELD) then
             CastSpellByName(HOLY_SHIELD)
            end
        end
        if IsSpellReady(BULWARK) then
            if selfHealth <= 30 then
                CastSpellByName(BULWARK)
            end
        end
    end

    -- Cast Consecration if in combat with 3 or more enemies
    CastConsecrationIfNeeded()

    -- Cast Hammer of Wrath if the target has 20% or less health
    CastHammerOfWrath()
end

local function CheckPartyHealth()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100
    local currentTime = GetTime()

    -- Priority 1: Check for "Shaman_Hex" or "Polymorph" on group members (excluding self) and cleanse immediately
    IterateGroupMembers(function(unit)
        if not UnitIsUnit(unit, "player") then
            if HasDebuff(unit, {"Shaman_Hex", "Polymorph", "Shadow_Possession", "Nature_Sleep"}) and manaPercentage > 5 then
                -- Bypass the cleanse cooldown throttle for "Shaman_Hex" and "Polymorph"
                CastSpellByName(DISPEL)
                SpellTargetUnit(unit)
                lastCleanseTime = currentTime -- Update the last cleanse time
                return -- Exit the function immediately after cleansing
            end
        end
    end)

    -- Priority 2: Check for snares and cast Hand of Freedom
    if HasDebuff("player", DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
        CastSpellByName(FREEDOM)
        SpellTargetUnit("player")
        return
    end

    -- Priority 3: Check group members for snares and cast Hand of Freedom
    IterateGroupMembers(function(unit)
        if HasDebuff(unit, DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
            CastSpellByName(FREEDOM)
            SpellTargetUnit(unit)
            return
        end
    end)

    -- Priority 4: Check self for low health and cast Lay on Hands
    local selfHealth = UnitHealth("player") / UnitHealthMax("player") * 100
    if selfHealth <= 10 and UnitAffectingCombat("player") then
        CastSpellByName(LAY_ON_HANDS)
        SpellTargetUnit("player")
        return
    end

    -- Priority 5: Check for other debuffs and cast Purify if needed (with cooldown throttle)
    if HasDebuff("player", DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
        if currentTime - lastCleanseTime >= cleanseCooldown then
            CastSpellByName(DISPEL)
            SpellTargetUnit("player")
            lastCleanseTime = currentTime -- Update the last cleanse time
            return
        end
    end

    -- Priority 6: Check group members for other debuffs and low health
    IterateGroupMembers(function(unit)
        local health = UnitHealth(unit) / UnitHealthMax(unit) * 100

        -- Cast Lay on Hands if health is below 10%
        if health <= 10 and UnitAffectingCombat(unit) then
            CastSpellByName(LAY_ON_HANDS)
            SpellTargetUnit(unit)
            return
        end

        -- Cast Consecration if health is below 60% and in combat
        if health <= 60 and UnitAffectingCombat("player") and manaPercentage >= 95 and IsSpellReady(CONSECRATION) then
            CastSpellByName(CONSECRATION)
        end

        -- Check for other debuffs and cast Purify if needed (with cooldown throttle)
        if HasDebuff(unit, DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
            if currentTime - lastCleanseTime >= cleanseCooldown then
                CastSpellByName(DISPEL)
                SpellTargetUnit(unit)
                lastCleanseTime = currentTime -- Update the last cleanse time
                return
            end
        end

        -- Cast Hand of Protection if health is below 20% (excluding self)
        if health <= 20 and not UnitIsUnit(unit, "player") then
            CastSpellByName(HAND_OF_PROTECTION)
            SpellTargetUnit(unit)
            return
        end
    end)
end

-- Function to heal myself and party members when out of combat and health is below 90%
local function HealOutOfCombat()
    -- Only heal if out of combat
    if not UnitAffectingCombat("player") then
        -- Check self first
        local selfHealth = UnitHealth("player") / UnitHealthMax("player") * 100
        if selfHealth <= 50 and IsSpellReady(FLASH_OF_LIGHT) then
            CastSpellByName(FLASH_OF_LIGHT)
            SpellTargetUnit("player")
            return
        end

        -- Check party members
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) then
                local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100
                if health <= 50 and IsSpellReady(FLASH_OF_LIGHT) then
                    CastSpellByName(FLASH_OF_LIGHT)
                    SpellTargetUnit(partyMember)
                    return
                end
            end
        end
    end
end

-- Function to toggle threatmode
local function ToggleThreatMode()
    if threatmode == 0 then
        threatmode = 1
    else
        threatmode = 0
    end
end

local function ToggleProtMode()
    if protmode == 0 then
        protmode = 1
        threatmode = 1
        SEAL_OF_MODE = SEAL_OF_RIGHTEOUSNESS -- Use Seal of Righteousness in protection mode
    else
        protmode = 0
        SEAL_OF_MODE = SEAL_OF_COMMAND -- Use Seal of Command in normal mode
    end
end

local function ToggleSalvationMode()
    if salvationMode == 0 then
        salvationMode = 1
        kingsMode = 0 -- Disable Kings Mode
        DEFAULT_CHAT_FRAME:AddMessage("Salvation Mode is now enabled. Kings Mode is disabled.")
    else
        salvationMode = 0
        DEFAULT_CHAT_FRAME:AddMessage("Salvation Mode is now disabled.")
    end
end

local function ToggleKingsMode()
    if kingsMode == 0 then
        kingsMode = 1
        salvationMode = 0 -- Disable Salvation Mode
        DEFAULT_CHAT_FRAME:AddMessage("Kings Mode is now enabled. Salvation Mode is disabled.")
    else
        kingsMode = 0
        DEFAULT_CHAT_FRAME:AddMessage("Kings Mode is now disabled.")
    end
end

local function ToggleSancMode()
    if sancMode == 0 then
        sancMode = 1
        DEFAULT_CHAT_FRAME:AddMessage("Sanc Mode is now enabled.")
    else
        sancMode = 0
        DEFAULT_CHAT_FRAME:AddMessage("Sanc Mode is now disabled.")
    end
end

local function ToggleLightMode()
    if lightMode == 0 then
        lightMode = 1
        DEFAULT_CHAT_FRAME:AddMessage("Light Mode is now enabled.")
    else
        lightMode = 0
        DEFAULT_CHAT_FRAME:AddMessage("Light Mode is now disabled.")
    end
end

-- Register slash command to toggle Light Mode
SLASH_CRUSADERLIGHT1 = "/crusader-light"
SlashCmdList["CRUSADERLIGHT"] = function()
    ToggleLightMode()
end

-- Register slash commands
SLASH_CRUSADER1 = "/crusader"
SlashCmdList["CRUSADER"] = function()
        CheckPartyHealth()
        ApplyPartyBuffs()
        ApplyPlayerBuffs()
        CastAbilities()
        HealOutOfCombat()
        CheckTargetsTarget() -- Check your target's target and cast Hand of Reckoning if needed
    -- Apply Sanc Mode if enabled
        if sancMode == 1 then
        AlwaysSanc()
    end
end

SLASH_CRUSADERTHREAT1 = "/crusaderthreat"
SlashCmdList["CRUSADERTHREAT"] = function()
    ToggleThreatMode()
end

SLASH_CRUSADERPROT1 = "/crusader-prot"
SlashCmdList["CRUSADERPROT"] = function()
    ToggleProtMode()
end

SLASH_CRUSADERSALV1 = "/crusader-salv"
SlashCmdList["CRUSADERSALV"] = function()
    ToggleSalvationMode()
end

SLASH_CRUSADERKINGS1 = "/crusader-kings"
SlashCmdList["CRUSADERKINGS"] = function()
    ToggleKingsMode()
end

SLASH_CRUSADERSANC1 = "/crusader-sanc"
SlashCmdList["CRUSADERSANC"] = function()
    ToggleSancMode()
end

-- Function to toggle blessings
local function ToggleBlessings()
    blessingsEnabled = not blessingsEnabled
    if blessingsEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("Blessings are now enabled.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Blessings are now disabled.")
    end
end

-- Register slash command to toggle blessings
SLASH_CRUSADERBLESSINGS1 = "/crusader-blessings"
SlashCmdList["CRUSADERBLESSINGS"] = function()
    ToggleBlessings()
end