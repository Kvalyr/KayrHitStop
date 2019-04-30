-- --------------------------------------------------------------------------------------------------------------------------------
-- Hitstop
-- ----------------------------------------------------------------	
local KLib = _G["KLib"]
local KayrHitStop = _G["KayrHitStop"]
local KHS = KayrHitStop

-- --------------------------------------------------------------------------------------------------------------------------------
-- HitSound
-- ----------------------------------------------------------------	

local flashFrame
local function CreateFlashFrame()
    if flashFrame or KHS.flashFrame then return end
    flashFrame = KLib:CreateFrame_Simple("KHS_HitFlash", WorldFrame, nil)
    flashFrame:SetPoint("CENTER")
    flashFrame:SetAllPoints()
    flashFrame:EnableMouse(false)
    KLib:CreateBackdrop(flashFrame, KLib.TestBackdropTable_NoBorder, {0.5,0,0,0.85}, KLib.Colors.None)     
    KHS.flashFrame = flashFrame
    flashFrame:Hide()
    return flashFrame
end

local function flashFadeOut(flashFrame)
    flashFrame:FadeHide(0.5)
end

local function flashFadeIn(flashFrame)
    KLib:Fade(true, flashFrame, 0.1, 0.025, 0, flashFadeOut)
end

function KayrHitStop.HitFlash()
    flashFrame = flashFrame or CreateFlashFrame()
    flashFadeIn(flashFrame)
end