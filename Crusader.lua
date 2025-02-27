-- Addon Name
local addonName, addon = "Crusader", {}

-- Spell Names
local HAMMER_OF_WRATH = "Hammer of Wrath" -- New spell
local BLESSING_OF_MIGHT = "Blessing of Might"
local BLESSING_OF_WISDOM = "Blessing of Wisdom"
local DEVOTION_AURA = "Devotion Aura"
local RIGHTEOUS_FURY = "Righteous Fury"
local SEAL_OF_COMMAND = "Seal of Command"
local SEAL_OF_WISDOM = "Seal of Wisdom"
local JUDGEMENT = "Judgement"
local CRUSADER_STRIKE = "Crusader Strike"
local CONSECRATION = "Consecration"
local HOLY_STRIKE = "Holy Strike"
local HAND_OF_PROTECTION = "Hand of Protection"
local LAY_ON_HANDS = "Lay on Hands(Rank 2)"
local DISPEL = "Cleanse"
local FREEDOM = "Hand of Freedom"
local FLASH_OF_LIGHT = "Flash of Light"
local strikeWeave = 0
local threatmode = 1

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
    -- Add more debuff names here as needed
}

local DEBUFFS_TO_FREEDOM = {
    "snare",
    "ShockWave",
    -- Add more debuff names here as needed
}



-- Table to track combat events
local combatEvents = {}
local combatTimeout = 5 -- Time in seconds to consider an enemy out of combat
local attackInterval = 2 -- Average attack interval in seconds

local function CastHammerOfWrath()
    local target = "target"
    if UnitExists(target) and UnitCanAttack("player", target) then
        local targetHealth = UnitHealth(target) / UnitHealthMax(target) * 100
        if targetHealth <= 20 and IsSpellReady(HAMMER_OF_WRATH) then
            DEFAULT_CHAT_FRAME:AddMessage("Casting Hammer of Wrath.")
            CastSpellByName(HAMMER_OF_WRATH)
        end
    end
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

-- Function to check if a unit has a specific buff
local function HasBuff(unit, buffName)
    for i = 1, 16 do
        local name = UnitBuff(unit, i)
        if name and strfind(name, buffName) then
            return true
        end
    end
    return false
end

-- Function to apply buffs to the player
local function ApplyPlayerBuffs()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100
    if manaPercentage < 40 then
        manaLow = 1
    end
    if manaPercentage >= 95 then
        manaLow = 0
    end

    -- Check and apply Seal of Command (always, even in combat)
    if not buffed(SEAL_OF_COMMAND, "player") and manaLow == 0 then
        CastSpellByName(SEAL_OF_COMMAND)
        SpellTargetUnit("player")
        sealOfCommandCastTime = GetTime() -- Record the time Seal of Command was cast
    end

    -- Check and apply Seal of Wisdom if mana is below 50%
    if not buffed(SEAL_OF_WISDOM, "player") and manaLow == 1 then
        CastSpellByName(SEAL_OF_WISDOM)
        SpellTargetUnit("player")
    end

    -- Only apply other buffs if out of combat
    if not UnitAffectingCombat("player") then
        -- Check and apply Blessing of Might
        if not buffed(BLESSING_OF_MIGHT, "player") then
            CastSpellByName(BLESSING_OF_MIGHT)
            SpellTargetUnit("player")
        end

        -- Check and apply Devotion Aura
        if not buffed(DEVOTION_AURA, "player") then
            CastSpellByName(DEVOTION_AURA)
            SpellTargetUnit("player")
        end

        -- Check and apply Righteous Fury
        if threatmode == 1 then
            if not buffed(RIGHTEOUS_FURY, "player") then
                CastSpellByName(RIGHTEOUS_FURY)
                SpellTargetUnit("player")
            end
        else
        end
    end
end

-- Function to apply buffs to party members
local function ApplyPartyBuffs()
    -- Only apply buffs if out of combat
    if not UnitAffectingCombat("player") then
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsUnit(partyMember, "player") then
                if IsManaUser(partyMember) then
                    -- Apply Blessing of Wisdom to mana users
                    if not buffed(BLESSING_OF_WISDOM, partyMember) then
                        CastSpellByName(BLESSING_OF_WISDOM)
                        SpellTargetUnit(partyMember)
                    end
                else
                    -- Apply Blessing of Might to non-mana users
                    if not buffed(BLESSING_OF_MIGHT, partyMember) then
                        CastSpellByName(BLESSING_OF_MIGHT)
                        SpellTargetUnit(partyMember)
                    end
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

    -- Check if target exists and is attackable
    local target = "target"
    if not UnitExists(target) or not UnitCanAttack("player", target) then
        return -- Exit if there is no target or the target is not attackable
    end

    -- Check if the target is Undead and Exorcism is ready
    local creatureType = UnitCreatureType(target)
    if creatureType == "Undead" and IsSpellReady("Exorcism") then
        CastSpellByName("Exorcism")
        return -- Exit after casting Exorcism to prioritize it
    end

    -- Check if Seal of Command is active and throttle Judgement
    if buffed(SEAL_OF_COMMAND, "player") then
        local currentTime = GetTime()
        if currentTime - sealOfCommandCastTime < judgementThrottleDuration then
            -- Do not cast Judgement if Seal of Command was cast within the last 20 seconds
        else
            -- Cast Judgement if the throttle duration has passed
            if IsSpellReady(JUDGEMENT) then
                CastSpellByName(JUDGEMENT)
            end
        end
    end

    -- Check if Seal of Wisdom is active and target does not have Judgement of Wisdom (debuff)
    if buffed(SEAL_OF_WISDOM, "player") then
        if not buffed("Judgement of Wisdom", target) then
            if IsSpellReady(JUDGEMENT) then
                CastSpellByName(JUDGEMENT)
            end
        end
    else
        -- Cast Judgement on cooldown if Seal of Wisdom is not active
        if IsSpellReady(JUDGEMENT) then
            CastSpellByName(JUDGEMENT)
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

    -- Cast Consecration if in combat with 3 or more enemies
    CastConsecrationIfNeeded()

    -- Cast Hammer of Wrath if the target has 20% or less health
    CastHammerOfWrath()
end

-- Function to check party health and cast emergency spells
local function CheckPartyHealth()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100

    -- Check for snares and cast Hand of Freedom first (highest priority)
    if HasDebuff("player", DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
        CastSpellByName(FREEDOM)
        SpellTargetUnit("player")
        return
    end

    -- Check party members for snares and cast Hand of Freedom first (highest priority)
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) then
            if HasDebuff(partyMember, DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
                CastSpellByName(FREEDOM)
                SpellTargetUnit(partyMember)
                return
            end
        end
    end

    -- Check self first for other debuffs and low health
    local selfHealth = UnitHealth("player") / UnitHealthMax("player") * 100
    if selfHealth <= 10 then
        CastSpellByName(LAY_ON_HANDS)
        SpellTargetUnit("player")
        return
    end

    -- Check for other debuffs and cast Purify if needed
    if HasDebuff("player", DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
        CastSpellByName(DISPEL)
        SpellTargetUnit("player")
        return
    end

    -- Check party members for other debuffs and low health
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) then
            local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100

            -- Cast Lay on Hands if health is below 10%
            if health <= 10 then
                CastSpellByName(LAY_ON_HANDS)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Consecration if health is below 90% and in combat
            if health <= 60 and UnitAffectingCombat("player") and manaPercentage >= 95 and IsSpellReady(CONSECRATION) then
                CastSpellByName(CONSECRATION)
            end

            -- Check for other debuffs and cast Purify if needed
            if HasDebuff(partyMember, DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
                CastSpellByName(DISPEL)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Hand of Protection if health is below 20% (excluding self)
            if health <= 20 and not UnitIsUnit(partyMember, "player") then
                CastSpellByName(HAND_OF_PROTECTION)
                SpellTargetUnit(partyMember)
                return
            end
        end
    end
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




-- Register slash commands
SLASH_CRUSADER1 = "/crusader"
SlashCmdList["CRUSADER"] = function()
    if not buffed("Bladestorm", "Player") then
        ApplyPlayerBuffs()
        ApplyPartyBuffs()
        CheckPartyHealth()
        CastAbilities()
        HealOutOfCombat()
    end
end

SLASH_CRUSADERTHREAT1 = "/crusaderthreat"
SlashCmdList["CRUSADERTHREAT"] = function()
    ToggleThreatMode()
end