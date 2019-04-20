-- --------------------------------------------------------------------------------------------------------------------------------
-- Hitstop
-- ----------------------------------------------------------------	
local KLib = _G["KLib"]
local KayrHitStop = _G["KayrHitStop"]

-- --------------------------------------------------------------------------------------------------------------------------------
-- Config
-- ----------------------------------------------------------------	
local enableHitStop = true
local enableHitSound = true
local hitSoundCritsOnly = true
local ignoreAoE = false
local meleeOnly = false
local spellBookOnly = false
local AutoAttackHitSound = false
local AutoAttackHitStop = false
local fastAttackThreshold = 1.75
local fastAttackCoefficient = 0.75 -- Hitstop Duration multiplier for players that attack faster (Arms, Frost, Feral, Rogue, etc.)
local minimumHitFrameRateMultiplier = 0.5 -- HitStop duration is adjusted for framerate below 60fps between <minimumHitFrameRateMultiplier> and 1.0

local slomoSteps = 10

 -- 80ms feels good, anything up to 200ms works well as a matter of preference
local baseHitstopDuration = 0.075  --0.125

-- 0.04 feels good for fire spells, monk melee, Heart Strike, Death Strike, Worgen Male
local baseHitstopDelay = 0.125 --0.035

-- Callback to update these file-local values from Cfg
function KayrHitStop.UpdateConfigvalues(CfgScheme, element, ...)
	CfgScheme = CfgScheme or KayrHitStop.cfgScheme
	KLib:Con("KayrHitStop.UpdateConfigvalues", KLScheme, element, ...)
	enableHitStop = CfgScheme:Get("enableHitStop")
    enableHitSound = CfgScheme:Get("enableHitSound")
    hitSoundCritsOnly = CfgScheme:Get("hitSoundCritsOnly")
	ignoreAoE = CfgScheme:Get("ignoreAoE")
	meleeOnly = CfgScheme:Get("meleeOnly")
	spellBookOnly = CfgScheme:Get("spellBookOnly")
	AutoAttackHitSound = CfgScheme:Get("AutoAttackHitSound")
	AutoAttackHitStop = CfgScheme:Get("AutoAttackHitStop")
	fastAttackThreshold = CfgScheme:Get("fastAttackThreshold")
	fastAttackCoefficient = CfgScheme:Get("fastAttackCoefficient")
	specialAttackCoefficient = CfgScheme:Get("specialAttackCoefficient")
	minimumHitFrameRateMultiplier = CfgScheme:Get("minimumHitFrameRateMultiplier")
	baseHitstopDuration = CfgScheme:Get("baseHitstopDuration")
	baseHitstopDelay = CfgScheme:Get("baseHitstopDelay")
end

-- --------------------------------------------------------------------------------------------------------------------------------
-- Allowed HitStop Events
-- ----------------------------------------------------------------	
local hitStopEvents = {}
hitStopEvents["SWING_DAMAGE"] = AutoAttackHitStop
hitStopEvents["SPELL_DAMAGE"] = true
KayrHitStop.hitStopEvents = hitStopEvents

-- --------------------------------------------------------------------------------------------------------------------------------
-- Ignored Spells
-- Abilities that don't feel good with hitstops
-- ----------------------------------------------------------------	
local ignoredSpells = {}
-- DK
ignoredSpells["Death and Decay"] = true
ignoredSpells["Defile"] = true
ignoredSpells["Bone Spike Graveyard"] = true
ignoredSpells["Blood Boil"] = true
-- DH
ignoredSpells["Eye Beam"] = true
ignoredSpells["Chaos Nova"] = true
-- Mage
ignoredSpells["Firestorm"] = true
-- Priest
ignoredSpells["Mind Sear"] = true
ignoredSpells["Shadowy Apparition"] = true
KayrHitStop.ignoredSpells = ignoredSpells

-- --------------------------------------------------------------------------------------------------------------------------------
-- Fast Spells
-- Abilities that land faster for some reason
-- ----------------------------------------------------------------	
local fastSpells = {}
-- DK
fastSpells["Death Strike"] = true

local softLocked = false

-- --------------------------------------------------------------------------------------------------------------------------------
-- Stopper Function
-- ----------------------------------------------------------------	
-- currentHitStopDuration gets set by KayrHitStop:HitStop() just before Timer fire.
-- Saves us from creating a closure (for the sake of passing an arg) for each hitstop.
local currentHitStopDuration = baseHitstopDuration  

function KayrHitStop.Stopper(dur_seconds)
	dur_seconds = dur_seconds or currentHitStopDuration or baseHitstopDuration
	local dur = dur_seconds * 1000 -- Milliseconds

    local frameRateCoeff = min(GetFramerate() / 60, 1)  -- Reduce hitstop duration when framerate is below 60
	-- Adjust hitstop duration for current framerate. Longer hitstops feel worse when framerate is already low
	frameRateCoeff = max(frameRateCoeff, minimumHitFrameRateMultiplier) -- No less than 50%
	dur = dur * frameRateCoeff * frameRateCoeff  

    if softLocked then KayrHitStop:Debug("Skipping due to softLock") return end
    KayrHitStop:Debug("Slomo step", dur)

    softLocked = true
	local start = debugprofilestop()
	local stop = start + dur
	local cur = debugprofilestop()
	while cur < stop do
		cur = debugprofilestop()
		if cur >= stop then break end
    end
    softLocked = false
end

function KayrHitStop.SloMoStopper(dur_seconds, steps)
    dur_seconds = dur_seconds or currentHitStopDuration or baseHitstopDuration
    steps = steps or slomoSteps

    local function slomoSteps()
        local i
        for i=1, steps-1 do
            local function stop()
                local slomo_dur_seconds = dur_seconds * (1 - (i / steps))
                KayrHitStop.Stopper(slomo_dur_seconds)
            end
            --C_Timer.After(dur_seconds * i * 1.5, KayrHitStop.Stopper)
            C_Timer.After(dur_seconds * i * 1.5, stop)
        end
    end

    -- Do one long stop then a tail of shorter stops
    local firstStepDur = dur_seconds * (steps * 0.25)
    C_Timer.After(firstStepDur, slomoSteps)
    KayrHitStop.Stopper(firstStepDur)
end

-- --------------------------------------------------------------------------------------------------------------------------------
-- HitStop
-- ----------------------------------------------------------------	
local last_hit_time
function KayrHitStop:HitStop(timestamp, event_type, critical, spellName)
	-- Throttle - No overlapping hitstops
	if last_hit_time and timestamp <= (last_hit_time + baseHitstopDuration) then 
		--KayrHitStop:Debug("Skip due to throttle:", last_hit_time, timestamp, last_hit_time + baseHitstopDuration, spellName)
		return 
	end 
	last_hit_time = timestamp

	local idealWorldLatencyMs = 25 -- Treating 25ms as ideal latency
	local _, _, _, worldLatencyMs = GetNetStats()
	local latencyOffset = (worldLatencyMs - idealWorldLatencyMs) / 1000 -- ms
	
	local hitstopDuration = baseHitstopDuration
	local hitstopDelay = baseHitstopDelay + latencyOffset
	local hitsoundDelay = hitstopDelay * 0.4
    hitStopDelay = max(baseHitstopDelay, idealWorldLatencyMs / 1000)
    

	
	-- Adjust hitstop duration for faster-attacking specs (Dual-Wield, etc.)
	if UnitAttackSpeed("player") <= fastAttackThreshold then
		hitstopDuration = hitstopDuration * fastAttackCoefficient
	end	
    
    -- Shorter delay for spells that land sooner
    if spellName and fastSpells[spellName] then
        KayrHitStop:Debug("Fast spell or swing damage:", spellName, hitstopDelay, hitstopDelay*specialAttackCoefficient)
		hitstopDelay = hitstopDelay * specialAttackCoefficient
		hitsoundDelay = hitstopDelay * ( specialAttackCoefficient * 0.5 )
	end
	-- Shorter hitstops for autoattacks, and different timing
	if event_type == "SWING_DAMAGE" then
		hitstopDuration = hitstopDuration / 2
		hitstopDelay = hitstopDelay * 2
		hitsoundDelay = hitstopDelay * 2
	end

	--KayrHitStop:Con("HitStop: ", timestamp, event_type, hitstopDuration, hitstopDelay, hitsoundDelay, frameRateCoeff)
	
	if enableHitSound and (event_type ~= "SWING_DAMAGE" or AutoAttackHitSound) then
        if not hitSoundCritsOnly then
            C_Timer.After(hitsoundDelay, KayrHitStop.HitSound)
        end
        if critical then
			C_Timer.After(hitsoundDelay, KayrHitStop.HitSound_Crit)
		end
	end

    if enableHitStop and (event_type ~= "SWING_DAMAGE" or AutoAttackHitStop) then
        -- Slomo
        local slomo = true
        if slomo then
            hitstopDuration = hitstopDuration * 5
            hitstopDuration = hitstopDuration / slomoSteps
            -- Set currentHitStopDuration so that KayrHitStop.Stopper can read this value (from outer scope). Saves us from creating a closure here for the sake of passing an arg.
            currentHitStopDuration = hitstopDuration
            C_Timer.After(hitstopDelay, KayrHitStop.SloMoStopper)
        else
            -- Set currentHitStopDuration so that KayrHitStop.Stopper can read this value (from outer scope). Saves us from creating a closure here for the sake of passing an arg.
            currentHitStopDuration = hitstopDuration
            C_Timer.After(hitstopDelay, KayrHitStop.Stopper)
        end
    end
end
