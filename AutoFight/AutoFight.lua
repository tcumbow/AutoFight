-- START COMMON CODE 01

-- start local copies

local VK1 = LibPixelControl.VK_1
local VK2 = LibPixelControl.VK_2
local VK3 = LibPixelControl.VK_3
local VK4 = LibPixelControl.VK_4
local VK5 = LibPixelControl.VK_5
local VKR = LibPixelControl.VK_R
local VMLeft = LibPixelControl.VM_BTN_LEFT
local VMRight = LibPixelControl.VM_BTN_RIGHT

local Blocking = IsBlockActive
local Now = GetGameTimeMilliseconds

-- end local copies

local function Health()
	local MyHealth, MyMaxHealth = GetUnitPower('player', POWERTYPE_HEALTH)
	return ((MyHealth/MyMaxHealth)*100)
end
local function HealthPoints()
	local MyHealth, MyMaxHealth = GetUnitPower('player', POWERTYPE_HEALTH)
	return MyHealth
end
local function Magicka()
	local MyMagicka, MyMaxMagicka = GetUnitPower('player', POWERTYPE_MAGICKA)
	return ((MyMagicka/MyMaxMagicka)*100)
end
local function MagickaPoints()
	local MyMagicka, MyMaxMagicka = GetUnitPower('player', POWERTYPE_MAGICKA)
	return MyMagicka
end
local function Stamina()
	local MyStamina, MyMaxStamina = GetUnitPower('player', POWERTYPE_STAMINA)
	return ((MyStamina/MyMaxStamina)*100)
end
local function StaminaPoints()
	local MyStamina, MyMaxStamina = GetUnitPower('player', POWERTYPE_STAMINA)
	return MyStamina
end
local function UltimateReady()
	local MyUltimate, _ = GetUnitPower('player', POWERTYPE_ULTIMATE)
	return (MyUltimate >= GetAbilityCost(GetSlotBoundId(8)))
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
local function UnitHasBuffTimeLeft(unitTag,buff,milliSeconds)
	local numBuffs = GetNumBuffs(unitTag)
	if numBuffs > 0 then
		for i = 1, numBuffs do
			local name, _, endTime, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo(unitTag, i)
			if name==buff then
				local timeLeft = (endTime*1000) - Now()
				return (timeLeft>milliSeconds)
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
			local name, _, _, _, _, _, _, _, _, _, _, _ = GetUnitBuffInfo('player', i)
			if name==buffName then
				return true
			end
		end
	end
	return false
end
local function IHaveId(buffId)
	local numAuras = GetNumBuffs('player')
	if (numAuras > 0) then
		for i = 1, numAuras do
			local _, _, _, _, _, _, _, _, _, _, id, _ = GetUnitBuffInfo('player', i)
			if id==buffId then
				return true
			end
		end
	end
	return false
end
local function VolatilePulseReady()
	return (IHave("Summon Volatile Familiar") and not IHaveId(88933))
end
local function TargetIsBoss()
	return (GetUnitDifficulty("reticleover") >= 3)
end
local function TargetIsMoreThanTrash()
	return (GetUnitDifficulty("reticleover") >= 2)
end
local function TargetCouldBeTaunted()
	return (TargetIsHostileNpc() and not TargetHas("Taunt"))
end
local function TargetShouldBeTaunted()
	return (TargetCouldBeTaunted() and (TargetIsBoss() or (Stamina()>50 and TargetIsMoreThanTrash())))
end
local function TargetName()
	return (GetUnitName('reticleover'))
end
local function InteractVerb()
	local action, _, _, _, _ = GetGameCameraInteractableActionInfo()
	return action
end
local function InteractName()
	local _, interactableName, _, _, _ = GetGameCameraInteractableActionInfo()
	return interactableName
end
local function AutoFightShouldNotAct()
	return (not IsUnitInCombat('player') or IsReticleHidden() or IsUnitSwimming('player') or IHave("Bestial Transformation") or IHave("Skeevaton") or TargetName()=="Plane Meld Rift" or TargetName()=="Lightning Aspect" or InteractName()=="Cage of Torment" or InteractName()=="Daedric Alter")
end
local function LowestGroupHealthPercent()
	local GroupSize = GetGroupSize()
	local LowestGroupHealthPercent = 1.00
	if GroupSize > 0 then
		for i = 1, GroupSize do
			local unitTag = GetGroupUnitTagByIndex(i)
			local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
			local HpPercent = currentHp / maxHp
			if HpPercent < LowestGroupHealthPercent and IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 then
				LowestGroupHealthPercent = HpPercent
			end
		end
	else
		local unitTag = "player"
		local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
		local HpPercent = currentHp / maxHp
		LowestGroupHealthPercent = HpPercent
	end
	return (LowestGroupHealthPercent * 100)
end
local function LowestGroupHealthPercentWithoutRegen()
	local GroupSize = GetGroupSize()
	local LowestGroupHealthPercent = 1.00
	if GroupSize > 0 then
		for i = 1, GroupSize do
			local unitTag = GetGroupUnitTagByIndex(i)
			local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
			local HpPercent = currentHp / maxHp
			if HpPercent < LowestGroupHealthPercent and not UnitHasRegen(unitTag) and IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 then
				LowestGroupHealthPercent = HpPercent
			end
		end
	elseif not UnitHasRegen("player") then
		local unitTag = "player"
		local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
		local HpPercent = currentHp / maxHp
		LowestGroupHealthPercent = HpPercent
	end
	return (LowestGroupHealthPercent * 100)
end

local function Press(key)
	LibPixelControl.SetIndOnFor(key,50)
end
local WeAreHolding = { }
local function Hold(key)
	if not LibPixelControl.IsIndOn(key) then
		LibPixelControl.SetIndOn(key)
		WeAreHolding[key] = true
	end
end
local function Release(key)
	if WeAreHolding[key] and LibPixelControl.IsIndOn(key) then LibPixelControl.SetIndOff(key) end
	WeAreHolding[key] = false
end
local function EndBlock()
	Release(VMRight)
end
local function HeavyAttack()
	EndBlock()
	Hold(VMLeft)
end
local function EndHeavyAttack()
	Release(VMLeft)
end
local function HeavyAttackInProgress()
	return (WeAreHolding[VMLeft])
end
local function LightAttack()
	EndHeavyAttack()
	Press(VMLeft)
end
local function UseAbility(num)
	EndHeavyAttack()
	Press(VK1+num-1)
end
local function UseUltimate()
	EndHeavyAttack()
	Press(VKR)
end
local function WeaveAbility(num)
	Press(VK1+num-1)
end
local function Block()
	EndHeavyAttack()
	Hold(VMRight)
end
local function BlockInProgress()
	return (WeAreHolding[VMRight])
end
local function DoNothing()
	EndHeavyAttack()
	EndBlock()
end
local IncomingAttackETA = 0
local IncomingAttackETR = 0
local IncomingAttackPredictedDamage = 1
local IncomingAttackAbilitySynId = 0
local IncomingAttackIsNotBlockTested = false
local IncomingAttackSourceUnitId = 0
local IncomingAttackBeginTimestamp = 0
local MaxRecordedDamagePerAbilitySynId = { }
local MinRecordedLagPerAbilitySynId = { }
local MaxRecordedLagPerAbilitySynId = { }
local CanBeBlockedPerAbilitySynId = { }
local BlockTestsPerAbilitySynId = { }
local LAG_THAT_IS_TOO_QUICK_TO_BLOCK = 120
local BLOCK_TEST_THRESHOLD = 5
local function AttackIncoming()
	return (IncomingAttackETA-300<Now() and IncomingAttackETR+300>Now())
end
local function OnEventCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	local abilitySynId = sourceName.." "..abilityName
	if targetType==COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then
		if result==ACTION_RESULT_BEGIN then
			if (CanBeBlockedPerAbilitySynId[abilitySynId] or nil==BlockTestsPerAbilitySynId[abilitySynId] or BlockTestsPerAbilitySynId[abilitySynId]<BLOCK_TEST_THRESHOLD) then
				if (nil==MinRecordedLagPerAbilitySynId[abilitySynId] or MinRecordedLagPerAbilitySynId[abilitySynId] > LAG_THAT_IS_TOO_QUICK_TO_BLOCK) then
					if ((not AttackIncoming()) or (abilitySynId~=IncomingAttackAbilitySynId and nil~=MaxRecordedDamagePerAbilitySynId[abilitySynId] and IncomingAttackPredictedDamage < MaxRecordedDamagePerAbilitySynId[abilitySynId])) then
						IncomingAttackBeginTimestamp = Now()
						if nil~=MinRecordedLagPerAbilitySynId[abilitySynId] then IncomingAttackETA = Now()+MinRecordedLagPerAbilitySynId[abilitySynId]
						else IncomingAttackETA = Now() end
						if nil~=MaxRecordedLagPerAbilitySynId[abilitySynId] then IncomingAttackETR = Now()+MaxRecordedLagPerAbilitySynId[abilitySynId]
						else IncomingAttackETR = Now()+5000 end -- max duration assumption
						if nil~=MaxRecordedDamagePerAbilitySynId[abilitySynId] then IncomingAttackPredictedDamage = MaxRecordedDamagePerAbilitySynId[abilitySynId]
						else IncomingAttackPredictedDamage = 1 end
						IncomingAttackAbilitySynId = abilitySynId
						IncomingAttackSourceUnitId = sourceUnitId
						IncomingAttackIsNotBlockTested = ((CanBeBlockedPerAbilitySynId[abilitySynId]~=true) and (nil==BlockTestsPerAbilitySynId[abilitySynId] or BlockTestsPerAbilitySynId[abilitySynId]<BLOCK_TEST_THRESHOLD))
					end
				else
					-- d("too fast: "..abilitySynId.." "..MinRecordedLagPerAbilitySynId[abilitySynId])
				end
			else
				-- d("can't be blocked: "..abilitySynId)
			end
		elseif result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_BLOCKED_DAMAGE then
			if (IncomingAttackETR+500>Now() and IncomingAttackSourceUnitId==sourceUnitId and IncomingAttackAbilitySynId==abilitySynId) then
				local Lag = Now()-IncomingAttackBeginTimestamp
				if nil==MinRecordedLagPerAbilitySynId[abilitySynId] or MinRecordedLagPerAbilitySynId[abilitySynId]>Lag then MinRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				if nil==MaxRecordedLagPerAbilitySynId[abilitySynId] or MaxRecordedLagPerAbilitySynId[abilitySynId]<Lag then MaxRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				IncomingAttackETR = 0
				if IncomingAttackIsNotBlockTested and result==ACTION_RESULT_DAMAGE and Blocking() then
					if nil==BlockTestsPerAbilitySynId[abilitySynId] then BlockTestsPerAbilitySynId[abilitySynId] = 1
					else BlockTestsPerAbilitySynId[abilitySynId] = BlockTestsPerAbilitySynId[abilitySynId] + 1 end
					if BlockTestsPerAbilitySynId[abilitySynId]==BLOCK_TEST_THRESHOLD then d("AutoFight: learned to NOT block: "..abilitySynId) end
				end
			end
		end
		if result==ACTION_RESULT_DAMAGE then
			if MaxRecordedDamagePerAbilitySynId[abilitySynId]==nil or hitValue > MaxRecordedDamagePerAbilitySynId[abilitySynId] then MaxRecordedDamagePerAbilitySynId[abilitySynId] = hitValue end
		elseif result==ACTION_RESULT_BLOCKED_DAMAGE then
			-- d("blocked: "..abilitySynId)
			if CanBeBlockedPerAbilitySynId[abilitySynId] ~= true then
				CanBeBlockedPerAbilitySynId[abilitySynId] = true
				d("AutoFight: learned to block: "..abilitySynId)
			end
		end
	end
end

--Suggested Logic Examples (for function AutoFightMain below)
--[Smart Blocking]: elseif AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())) then Block()

-- END COMMON CODE 01

-- START CHARACTER-SPECIFIC CODE 01

local CharacterFirstName = "Generic"
local BlockCost = 2160

local function AutoFightMain()
	if AutoFightShouldNotAct() then DoNothing()
	elseif UltimateReady() and TargetIsHostileNpc() then UseUltimate()
	else DoNothing()
	end
end

-- END CHARACTER-SPECIFIC CODE 01

-- START COMMON CODE 02

local ADDON_NAME = "AutoFight-"..CharacterFirstName
local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		if string.find(GetUnitName("player"),CharacterFirstName) then
			EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 100, AutoFightMain)
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnEventCombatEvent)
		end
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- END COMMON CODE 02

