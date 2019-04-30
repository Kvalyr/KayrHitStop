--[[
	-- --------------------------------------------------------------------------------------------------------------------------------
	-- KayrHitStop - 
	-- --------------------------------------------------------------------------------------------------------------------------------
]]--
	-- --------------------------------------------------------------------------------------------------------------------------------
	-- Namespace & Function Libraries
	-- --------------------------------------------------------------------------------------------------------------------------------
	local addon, ns = ...
	local KLib = ns.KLib
	local i, _
	
	-- Global-scope addon frame for event handling and external access
	local version = { major = 0.1, minor = 0.1}
	local KLversion = {major = 0.5, minor = 44 }
	local addonName = "KayrHitStop"
	local addonPrefix = "KHS"
	local author = "Kvalyr"
	local KayrHitStop = KLib:CreateAddon(addonName, addonPrefix, version, KLversion, nil, nil, author)--, savedVarsString, savedVarsPerCharString)	
    local KHS = KayrHitStop
    KayrHitStop.debugMode = true

	if not KLib:IsAddonRegistered(addonName) then return end
	KayrHitStop:SetAddonSite("http://KayrHitStop.kvalyr.com/")
	
	-- --------------------------------------------------------------------------------------------------------------------------------
	-- Setup() - Called by KLib when PLAYER_LOGIN fires (only once)
	-- ----------------------------------------------------------------		
	function KayrHitStop:Setup()
		if KayrHitStop.ConfigValid then
			KayrHitStop.cfgScheme = KayrHitStop:RegisterScheme("KHS_Scheme_Config", KayrHitStop.Cfg.general, KayrHitStop_SavedVariables, nil, nil) -- No SVPC
			KayrHitStop.cfgScheme:NewElement("enableHitStop", true, KayrHitStop.UpdateConfigvalues, "class", "class")
            KayrHitStop.cfgScheme:NewElement("hitStopCritsOnly", false, KayrHitStop.UpdateConfigvalues, "class", "class")

            KayrHitStop.cfgScheme:NewElement("enableHitFlash", true, KayrHitStop.UpdateConfigvalues, "class", "class")
            KayrHitStop.cfgScheme:NewElement("hitFlashCritsOnly", false, KayrHitStop.UpdateConfigvalues, "class", "class")

            KayrHitStop.cfgScheme:NewElement("enableHitSound", true, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("hitSoundCritsOnly", true, KayrHitStop.UpdateConfigvalues, "class", "class")
			
			KayrHitStop.cfgScheme:NewElement("ignoreAoE", false, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("meleeOnly", false, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("spellBookOnly", true, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("AutoAttackHitSound", false, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("AutoAttackHitStop", false, KayrHitStop.UpdateConfigvalues, "class", "class")
			KayrHitStop.cfgScheme:NewElement("AutoAttackHitFlash", false, KayrHitStop.UpdateConfigvalues, "class", "class")
			
			-- HitStop duration is adjusted for framerate below 60fps between <minimumHitFrameRateMultiplier> and 1.0
			KayrHitStop.cfgScheme:NewElement("minimumHitFrameRateMultiplier", 0.25, KayrHitStop.UpdateConfigvalues, "class", "class")
			
			-- Hitstop Duration multiplier for players that attack faster (Arms, Frost, Feral, Rogue, etc.)
			KayrHitStop.cfgScheme:NewElement("fastAttackCoefficient", 0.75, KayrHitStop.UpdateConfigvalues, "class", "class")
            
            -- Hitstop duration multiplier for attacks/spells that land sooner (Attacks that use the spceial attack animation, such as Death Strike)
            KayrHitStop.cfgScheme:NewElement("specialAttackCoefficient", 0.75, KayrHitStop.UpdateConfigvalues, "class", "class")
			 
			-- Attack speeds faster than this are considered for fastAttackCoefficient
			KayrHitStop.cfgScheme:NewElement("fastAttackThreshold", 1.75, KayrHitStop.UpdateConfigvalues, "class", "class")
			 
			-- Length of time in seconds that the hitstop lasts for. Anything above 200ms feels bad.
			KayrHitStop.cfgScheme:NewElement("baseHitstopDuration", 0.015, KayrHitStop.UpdateConfigvalues, "class", "class")
			 
			-- Length of time in seconds from receipt of combat log event to triggering the hitstop. Combat log events occur before the player animates their hit. This value is a very rough way to sync the hitstop with the on-screen action.
			KayrHitStop.cfgScheme:NewElement("baseHitstopDelay", 0.04, KayrHitStop.UpdateConfigvalues, "class", "class")
			
			return true
		else
			self:PrintError("Config is invalid")
			return false
		end
		return true
	end
	
	-- --------------------------------------------------------------------------------------------------------------------------------
	-- Run() - Called by KLib when PLAYER_ENTERING_WORLD fires (only once)
	-- ----------------------------------------------------------------		
	function KayrHitStop:Run()
		KayrHitStop.hasRun = true
		KayrHitStop.UpdateConfigvalues(KayrHitStop.cfgScheme)
		KayrHitStop:AddEventFunc("COMBAT_LOG_EVENT_UNFILTERED")
        KayrHitStop.ready = true
        KayrHitStop.firstHitDone = false
	end
	
	-- --------------------------------------------------------------------------------------------------------------------------------
	-- Update
	-- ----------------------------------------------------------------		
	function KayrHitStop:Update(event, ...)
		--if not KayrHitStop.ready then return end
	end

	-- --------------------------------------------------------------------------------------------------------------------------------
	-- COMBAT_LOG_EVENT_UNFILTERED
	-- ----------------------------------------------------------------		
    function KayrHitStop:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
        if not KayrHitStop.ready or event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end

		local timestamp, event_type, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, 
        spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = CombatLogGetCurrentEventInfo()
        
		-- Filter by caster - We only care about the player's actions
		if sourceName ~= UnitName("player") then return end

        -- Ignore stuff affecting self
        if sourceGUID == destGUID then return end        
        
		-- Filter by event. Don't do anything if hitStopEvents hasn't been initialized yet, otherwise we could end up spewing an error for every combat log event. That would be bad.
		if not KayrHitStop.hitStopEvents then return end
		if not KayrHitStop.hitStopEvents[event_type] then 
			--KayrHitStop:Debug("HitStop skipped event:", event_type, spellName)
			return 
		end

        --KayrHitStop:Debug("HitStop event:", event_type, spellName)
        --[[
        KayrHitStop:Debug(
            "HitStop event:", timestamp, event_type, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, 
            destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
        )
        --]]--
        
		-- Filter out spells that are too spammy or don't feel right with hitstops
        if KayrHitStop.ignoredSpells and KayrHitStop.ignoredSpells[spellName] then 
            KayrHitStop:Debug("Skipping ignored spell:", spellName)
            return 
        end

		-- Filter out any spells/abilities that aren't in the spellbook. This is a handy way to filter out named procs from trinkets/azerite-powers, etc.
		-- TODO: Memoize this cfg var instead of querying cfgScheme on each event
		if KayrHitStop.cfgScheme:Get("spellBookOnly") and not (GetSpellBookItemInfo(spellName) or IsTalentSpell(spellName)) then
			KayrHitStop:Debug("Skipping non-spellbook ability:", spellName)
			return
		end		
		
		-- Melee only (Unreliable check)
		local _, _, _, castTime, minRange, maxRange = GetSpellInfo(spellID)
		if meleeOnly and (minRange ~= 0 or maxRange ~= 0) then 
			KayrHitStop:Debug("HitStop skipped non-melee:", event_type, spellName)
			return 
		end

		-- Non-AoE only
		-- AoE/Untargeted spells return nil for IsSpellInRange. Unreliable check, some other spells do too. :(
		if ignoreAoE and not KayrHitStop:tobool(IsSpellInRange(spellName)) then 
			KayrHitStop:Debug("HitStop skipped AoE:", event_type, spellName)
			return
        end
        
        -- Ensure we pull the cfg values from the live scheme
        if not KayrHitStop.firstHitDone then
            KayrHitStop.UpdateConfigvalues(KayrHitStop.cfgScheme)
        end

		KayrHitStop:HitStop(timestamp, event_type, critical, spellName)
	end
