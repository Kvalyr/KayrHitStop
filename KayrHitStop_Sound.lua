-- --------------------------------------------------------------------------------------------------------------------------------
-- HitSound
-- ----------------------------------------------------------------	
local impact_sounds = {}
impact_sounds[1] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_01.ogg"
impact_sounds[2] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_02.ogg"
impact_sounds[3] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_03.ogg"
impact_sounds[4] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_04.ogg"
impact_sounds[5] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_05.ogg"
impact_sounds[6] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_06.ogg"
impact_sounds[7] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_07.ogg"
impact_sounds[8] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_08.ogg"
impact_sounds[9] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_09.ogg"
impact_sounds[10] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_CombatRevamp_10.ogg"
local num_impact_sounds = KLib:TabSize(impact_sounds)

local impact_sounds_crit = {}
impact_sounds_crit[1] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_Crit_CombatRevamp_01.ogg"
impact_sounds_crit[2] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_Crit_CombatRevamp_02.ogg"
impact_sounds_crit[3] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_Crit_CombatRevamp_03.ogg"
impact_sounds_crit[4] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_Crit_CombatRevamp_04.ogg"
impact_sounds_crit[5] = "Sound\\Item\\Weapons\\Axe2H\\2H_Axe_HitFlesh_Crit_CombatRevamp_05.ogg"
local num_impact_sounds_crit = KLib:TabSize(impact_sounds_crit)


-- --------------------------------------------------------------------------------------------------------------------------------
-- SoundTest
-- ----------------------------------------------------------------	
function KayrHitStop:SoundTest()
	for k, v in pairs(impact_sounds) do
		KLib:Con(v)
		C_Timer.After(1 * k, function() KayrHitStop.HitSound(k) end)
	end
end


-- --------------------------------------------------------------------------------------------------------------------------------
-- HitSound
-- ----------------------------------------------------------------	
function KayrHitStop.HitSound(soundIndex)
	soundIndex = soundIndex or math.random(num_impact_sounds)
	PlaySoundFile(impact_sounds[soundIndex], "SFX")
end

-- --------------------------------------------------------------------------------------------------------------------------------
-- HitSound_Crit
-- ----------------------------------------------------------------	
function KayrHitStop.HitSound_Crit(soundIndex)
	soundIndex = soundIndex or math.random(num_impact_sounds_crit)
	PlaySoundFile(impact_sounds_crit[soundIndex], "SFX")
end
