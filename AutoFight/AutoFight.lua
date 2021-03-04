-- START COMMON CODE 01

-- start local copies

-- end local copies

local function Health()
	local MyHealth, MyMaxHealth = GetUnitPower('player', POWERTYPE_HEALTH)
	return ((MyHealth/MyMaxHealth)*100)
end
local function Magicka()
	local MyMagicka, MyMaxMagicka = GetUnitPower('player', POWERTYPE_MAGICKA)
	return ((MyMagicka/MyMaxMagicka)*100)
end
local function Stamina()
	local MyStamina, MyMaxStamina = GetUnitPower('player', POWERTYPE_STAMINA)
	return ((MyStamina/MyMaxStamina)*100)
end
local function UltimateReady()
end
local function UnitHasRegen(unitTag)
	local numBuffs = GetNumBuffs(unitTag)
	if numBuffs > 0 then
		for i = 1, numBuffs do
			local name, _, _, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo(unitTag, i)
			if name=="Rapid Regeneration" or name=="Radiating Regeneration" then
				return true
			end
		end
	end
	return false
end
local function TargetIsHostileNpc()
	return DoesUnitExist('reticleover') and not IsUnitDead('reticleover') and GetUnitType('reticleover') ~= 1 and GetUnitReaction('reticleover') == UNIT_REACTION_HOSTILE
end
local function TargetHas(buffName)
	local numAuras = GetNumBuffs('reticleover')
	if (numAuras > 0) then
		for i = 1, numAuras do
			local name, _, _, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo('reticleover', i)
			if name==buffName then
				return true
			end
		end
	end
	return false
end
local function IHave(buffName)
	local numAuras = GetNumBuffs('player')
	if (numAuras > 0) then
		for i = 1, numAuras do
			local name, _, _, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo('reticleover', i)
			if name==buffName then
				return true
			end
		end
	end
	return false
end
local function TargetIsBoss()
	return (GetUnitDifficulty("reticleover") < 3)
end
local function TargetCouldBeTaunted()
	return (TargetIsHostileNpc() and TargetHas("Taunt"))
end
local function TargetShouldBeTaunted()
	return (TargetCouldBeTaunted() and TargetIsBoss())
end
local function AutoFightShouldNotAct()
	return (not IsUnitInCombat('player') or IsReticleHidden() or IsUnitSwimming('player') or IHave("Bestial Transformation"))
end

-- END COMMON CODE 01

-- START LEGACY CODE


local function UltimateCost()
	return GetAbilityCost(GetSlotBoundId(8))
end

local LowestGroupHealthPercentWithoutRegen
local LowestGroupHealthPercentWithRegen
local LowestGroupHealthPercent
local GroupSize = 0
local function UpdateLowestGroupHealth()
	GroupSize = GetGroupSize()
	LowestGroupHealthPercentWithoutRegen = 1.00
	LowestGroupHealthPercentWithRegen = 1.00
	LowestGroupHealthPercent = 1.00

	if GroupSize > 0 then
		for i = 1, GroupSize do
			local unitTag = GetGroupUnitTagByIndex(i)
			local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
			local HpPercent = currentHp / maxHp
			local HasRegen = UnitHasRegen(unitTag)
			local InHealingRange = IsUnitInGroupSupportRange(unitTag)
			local IsAlive = not IsUnitDead(unitTag)
			local IsPlayer = GetUnitType(unitTag) == 1
			if HpPercent < LowestGroupHealthPercent and InHealingRange and IsAlive and IsPlayer then
				LowestGroupHealthPercent = HpPercent
			end
			if HpPercent < LowestGroupHealthPercentWithoutRegen and HasRegen == false and InHealingRange and IsAlive and IsPlayer then
				LowestGroupHealthPercentWithoutRegen = HpPercent
			elseif HpPercent < LowestGroupHealthPercentWithRegen and HasRegen and InHealingRange and IsAlive and IsPlayer then
				LowestGroupHealthPercentWithRegen = HpPercent
			end
		end
	else
		local unitTag = "player"
		local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
		local HpPercent = currentHp / maxHp
		LowestGroupHealthPercent = HpPercent
		local HasRegen = UnitHasRegen(unitTag)
		if HasRegen == false then
			LowestGroupHealthPercentWithoutRegen = HpPercent
		elseif HasRegen then
			LowestGroupHealthPercentWithRegen = HpPercent
		end
	end
end

UpdateLowestGroupHealth()

	-- Core Healing
	if LowestGroupHealthPercent < 0.40 and MyMagicka > 3500 then
		LibPixelControl.SetIndOnFor(LibPixelControl.VK_1,50)
	elseif LowestGroupHealthPercentWithoutRegen < 0.90 and MyMagicka > 3500 then
		LibPixelControl.SetIndOnFor(LibPixelControl.VK_2,50)

	-- Proactive Healing
	elseif LowestGroupHealthPercent < 0.60 and MyMagicka > 20000 then
		LibPixelControl.SetIndOnFor(LibPixelControl.VK_1,50)
	elseif LowestGroupHealthPercent < 0.80 and MyMagickaPercent > 0.90 then
		LibPixelControl.SetIndOnFor(LibPixelControl.VK_1,50)

	-- Light Attacks
	elseif DoesUnitExist('reticleover') and GetUnitReaction('reticleover') == UNIT_REACTION_HOSTILE and not IsUnitDead('reticleover') and not IsBlockActive() then
		LibPixelControl.SetIndOnFor(LibPixelControl.VM_BTN_LEFT,50)

	end

-- END LEGACY CODE

-- START CHARACTER-SPECIFIC CODE 01

local CharacterFirstName = "Generic"

local function AutoFightMain()
	if AutoFightShouldNotAct() then return end
	
end

-- END CHARACTER-SPECIFIC CODE 01

-- START COMMON CODE 02

local ADDON_NAME = "AutoFight-"..CharacterFirstName
local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		if string.find(GetUnitName("player"),CharacterFirstName) then
			EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 100, AutoFightMain)
		end
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- END COMMON CODE 02

