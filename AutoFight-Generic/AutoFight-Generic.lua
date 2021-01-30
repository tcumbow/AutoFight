local ADDON_VERSION = "1.1"
local ADDON_AUTHOR = "Tom Cumbow"
local ADDON_NAME = "AutoFight-Generic"

local MyHealth
local MyMaxHealth
local MyHealthPercent
local MyMagicka
local MyMaxMagicka
local MyMagickaPercent
local MyStamina
local MyMaxStamina
local MyStaminaPercent

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

local function TargetShouldBeTaunted()
	if (not DoesUnitExist('reticleover') or IsUnitDead('reticleover') or GetUnitType('reticleover') == 1 or GetUnitReaction('reticleover') ~= UNIT_REACTION_HOSTILE or GetUnitDifficulty("reticleover") < 3) then
		local numAuras = GetNumBuffs('reticleover')
		if (numAuras > 0) then
			for i = 1, numAuras do
				local name, _, _, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo('reticleover', i)
				if name=="Taunt" then
					return false
				end
			end
		end
		return true
	else
		return false
	end

end

local LowestGroupHealthPercentWithoutRegen
local LowestGroupHealthPercentWithRegen
local LowestGroupHealthPercent
local function UpdateLowestGroupHealth()
	local GroupSize = GetGroupSize()
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

local MajorSorcery
local function UpdateBuffs()
	MajorSorcery = false
	local numBuffs = GetNumBuffs("player")
	if numBuffs > 0 then
		for i = 1, numBuffs do
			local name, _, endTime, _, _, _, _, _, _, _, id, _ = GetUnitBuffInfo("player", i)
			if name=="Major Sorcery" then
				MajorSorcery = true
			end
		end
	end
end

local function AutoFightMain()
	if not IsUnitInCombat('player') then return end
	if IsReticleHidden() or IsUnitSwimming('player') then return end

	UpdateLowestGroupHealth()
	MyHealth, MyMaxHealth = GetUnitPower('player', POWERTYPE_HEALTH)
	MyHealthPercent = MyHealth/MyMaxHealth
	MyMagicka, MyMaxMagicka = GetUnitPower('player', POWERTYPE_MAGICKA)
	MyMagickaPercent = MyMagicka/MyMaxMagicka
	MyStamina, MyMaxStamina = GetUnitPower('player', POWERTYPE_STAMINA)
	MyStaminaPercent = MyStamina/MyMaxStamina
	UpdateBuffs()

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

	-- Buffs


	-- Light Attacks
	elseif DoesUnitExist('reticleover') and GetUnitReaction('reticleover') == UNIT_REACTION_HOSTILE and not IsUnitDead('reticleover') and not IsBlockActive() then
		LibPixelControl.SetIndOnFor(LibPixelControl.VM_BTN_LEFT,50)

	end

end

local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		if string.find(GetUnitName("player"),"Generic") then
			EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 100, AutoFightMain)
		end
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
