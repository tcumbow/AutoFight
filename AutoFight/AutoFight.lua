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
local RoundUp = math.ceil
local RoundDown = math.floor

-- end local copies

local SvWarningTypes = { }
local WarningInstances = { }

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
local WarningInstances = WarningInstances or { }
local ThreatProfilePerWarningAbilitySynId = { } --each "ThreatProfile" is a table that consists of these keys: "CanBeBlocked","PredictedDamage","CausesStagger","TriedBlocking","MinDmgLag","MaxDmgLag"
local ThreatProfilePerWarningId = { }
local LAG_THAT_IS_TOO_QUICK_TO_BLOCK = 120
local ASSUMED_MAX_LAG_OF_WARNING = 5000
local BlockCost = 2160
local function ShouldBlock()
	local now = Now()
	local threat
	local DmgETA
	local DmgETR
	local StagETA
	local StagETR
	if StaminaPoints()<BlockCost then return false end
	for key, value in pairs(WarningInstances) do
		threat = ThreatProfilePerWarningAbilitySynId[value.AbilitySynId] or { }
		DmgETA = (threat.MinDmgLag or 0) + value.Timestamp - 300
		DmgETR = (threat.MaxDmgLag or ASSUMED_MAX_LAG_OF_WARNING) + value.Timestamp + 300
		StagETA = (threat.MinStagLag or 0) + value.Timestamp - 300
		StagETR = (threat.MaxStagLag or ASSUMED_MAX_LAG_OF_WARNING) + value.Timestamp + 300
		if now > DmgETR and now > StagETR then WarningInstances[key] = nil
		else
			if threat.CanBeBlocked ~= false then
				if threat.CausesStagger then
					if (threat.MinStagLag or 1000) > LAG_THAT_IS_TOO_QUICK_TO_BLOCK then
						if now > StagETA and now < StagETR then
							d("PREVENTING STAGGER "..value.AbilitySynId)
							return true
						end
					else d("TOO QUICK TO PREVENT STAGGER "..value.AbilitySynId)
					end
				elseif (threat.MinDmgLag or 1000) > LAG_THAT_IS_TOO_QUICK_TO_BLOCK then
					if now > DmgETA and now < DmgETR then
						if ((threat.PredictedDamage or 10000)/HealthPoints())>(BlockCost/StaminaPoints()) then
							return true
						else d("Not Worth The Stamina: "..value.AbilitySynId)
						end
					end
				-- else d("TOO QUICK "..value.AbilitySynId)
				end
			else d("CANNOT BLOCK "..value.AbilitySynId)
			end
		end
	end
	return false

	-- taminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())) then Block()
	-- return (IncomingAttackETA-300<Now() and IncomingAttackETR+300>Now())
end
local function CleanUpWarningInstances()
	local now = Now()
	if WarningInstances.CeBegin == nil then return end
	for key, value in pairs(WarningInstances.CeBegin) do
		if value ~= nil then
			for key2, value2 in pairs(value) do
				if key2~=nil and now > key2+ASSUMED_MAX_LAG_OF_WARNING then WarningInstances.CeBegin[key][key2] = nil end
			end
		end
	end
end
local function Lag2Wid(lag)
	return (RoundDown(lag/100)),(RoundUp(lag/100))
end
local function Wid2Lag(wid)
	return wid*100
end

local function OnEventCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	if targetType==COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then

		--enrich data
		local now = Now()
		local abilitySynId = sourceName.." "..abilityName
		local sourceSynId = sourceName.." "..sourceUnitId
		CleanUpWarningInstances()
		
		if result==ACTION_RESULT_BEGIN then
			local warningTypeId = "CeBegin "..abilityId
			--record warning information for later use
			WarningInstances.CeBegin[sourceSynId] = WarningInstances.CeBegin[sourceSynId] or { }
			WarningInstances.CeBegin[sourceSynId][now] = abilityId
			SvWarningTypes[warningTypeId] = SvWarningTypes[warningTypeId] or { }
			SvWarningTypes[warningTypeId].TotInsts = (SvWarningTypes[warningTypeId].TotInsts or 0) + 1
		elseif result==ACTION_RESULT_DAMAGE then
			if WarningInstances.CeBegin[sourceSynId] ~= nil then
				for warningTimestamp, warningAbilityId in pairs(WarningInstances.CeBegin[sourceSynId]) do
					local lag = now-warningTimestamp
					local wid1, wid2 = Lag2Wid(lag)
					local warningTypeId = "CeBegin "..warningAbilityId
					SvWarningTypes[warningTypeId] = SvWarningTypes[warningTypeId] or { }
					SvWarningTypes[warningTypeId][wid1] = SvWarningTypes[warningTypeId][wid1] or { }
					SvWarningTypes[warningTypeId][wid2] = SvWarningTypes[warningTypeId][wid2] or { }
					SvWarningTypes[warningTypeId][wid1].DmgInsts = (SvWarningTypes[warningTypeId][wid1].DmgInsts or 0) + 1
					SvWarningTypes[warningTypeId][wid2].DmgInsts = (SvWarningTypes[warningTypeId][wid2].DmgInsts or 0) + 1
					SvWarningTypes[warningTypeId][wid1].DmgAccum = (SvWarningTypes[warningTypeId][wid1].DmgAccum or 0) + hitValue
					SvWarningTypes[warningTypeId][wid2].DmgAccum = (SvWarningTypes[warningTypeId][wid2].DmgAccum or 0) + hitValue
				end
			end
		end
	end
end

--Suggested Logic Examples (for function AutoFightMain below)
--[Smart Blocking]: elseif AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())) then Block()

-- END COMMON CODE 01

-- START CHARACTER-SPECIFIC CODE 01

local CharacterFirstName = "Gideon"
BlockCost = 2160

local function SomeoneCouldUseRegen()
	local GroupSize = GetGroupSize()
	local unitTag
	if GroupSize > 0 then
		local GroupMembersWithPlentyOfRegen = 0
		local GroupMembersInSupportRange = 0
		for i = 1, GroupSize do
			unitTag = GetGroupUnitTagByIndex(i)
			if IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 then
				GroupMembersInSupportRange = GroupMembersInSupportRange + 1
				if not UnitHasRegen(unitTag) then return true end
				if UnitHasBuffTimeLeft(unitTag,"Radiating Regeneration",5000) then
				GroupMembersWithPlentyOfRegen = GroupMembersWithPlentyOfRegen + 1 end
			end
		end
		return (GroupMembersWithPlentyOfRegen < 3 and GroupMembersWithPlentyOfRegen < GroupMembersInSupportRange)
	else return (not UnitHasBuffTimeLeft("player","Radiating Regeneration",5000)) end
end

local function AutoFightMain()
	if AutoFightShouldNotAct() then DoNothing()
	elseif Magicka()<15 and not Blocking() then HeavyAttack()
	elseif LowestGroupHealthPercent()<40 then UseAbility(1)
	elseif LowestGroupHealthPercent()<70 and Magicka()>70 then UseAbility(1)
	elseif LowestGroupHealthPercentWithoutRegen()<80 then UseAbility(2)
	-- elseif ShouldBlock() then Block()
	-- elseif LowestGroupHealthPercentWithoutRegen()<90 then WeaveAbility(2)
	-- elseif not IHave("Minor Sorcery") and TargetIsHostileNpc() and Magicka()>80 then WeaveAbility(5)
	-- elseif UltimateReady() and TargetIsBoss() then UseUltimate()
	-- elseif not TargetHas("Minor Magickasteal") and TargetIsHostileNpc() then WeaveAbility(3)
	-- elseif not IHave("Major Resolve") then WeaveAbility(5)
	-- elseif SomeoneCouldUseRegen() and Magicka()>50 then WeaveAbility(2)
	-- elseif TargetIsHostileNpc() and not TargetHas("Minor Lifesteal") then WeaveAbility(5)
	-- elseif Magicka()>99 then WeaveAbility(5)
	-- elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

-- END CHARACTER-SPECIFIC CODE 01

-- START COMMON CODE 02

local ADDON_NAME = "AutoFight-"..CharacterFirstName
local function RegisterStuff()
	d("AutoFight started")
	EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 100, AutoFightMain)
	-- EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."blarg", 1000, ReciteThreats)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnEventCombatEvent)
	EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end
local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		if string.find(GetUnitName("player"),CharacterFirstName) then
			SvWarningTypes = ZO_SavedVars:NewCharacterIdSettings("AutoFightWarningTypes",3)
			WarningInstances = WarningInstances or { }
			WarningInstances.CeBegin = WarningInstances.CeBegin or { }
			SvWarningTypes = SvWarningTypes or { }
			zo_callLater(RegisterStuff,20000)
		end
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- END COMMON CODE 02

