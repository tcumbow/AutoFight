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
local LastWarningSignPerSourceSynId = { } --each "WarningSign" is a table that consists of two keys: "AbilitySynId" and "Timestamp"
local ThreatPerSourceSynId = { } --each "Threat" is a table that consists of these keys: "ETA","ETR","ThreatProfile" (which itself is a table)
local ThreatProfilePerWarningAbilitySynId = { } --each "ThreatProfile" is a table that consists of these keys: "CanBeBlocked","PredictedDamage","CausesStagger","TriedBlocking","MinLag","MaxLag"
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
local ASSUMED_MAX_LAG_OF_WARNING = 5000
local function AttackIncoming()
	return (IncomingAttackETA-300<Now() and IncomingAttackETR+300>Now())
end
local function OnEventCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	if targetType==COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then
		
		--enrich data
		local now = Now()
		local abilitySynId = sourceName.." "..abilityName
		local sourceSynId = sourceName.." "..sourceUnitId
		
		if result==ACTION_RESULT_BEGIN then

			--record warning information for later use
			if LastWarningSignPerSourceSynId[sourceSynId] == nil then LastWarningSignPerSourceSynId[sourceSynId] = { } end
			LastWarningSignPerSourceSynId[sourceSynId].AbilitySynId = abilitySynId
			LastWarningSignPerSourceSynId[sourceSynId].Timestamp = now

			--identify threats (generate predictions) based on this "begin" event
			local threatProfile = ThreatProfilePerWarningAbilitySynId[abilitySynId] or { }
			ThreatPerSourceSynId[sourceSynId] = ThreatPerSourceSynId[sourceSynId] or { }
			ThreatPerSourceSynId[sourceSynId].ThreatProfile = threatProfile
			if threatProfile.MinLag~=nil then ThreatPerSourceSynId[sourceSynId].ETA = now+threatProfile.MinLag
			else ThreatPerSourceSynId[sourceSynId].ETA = now end
			if threatProfile.MaxLag~=nil then ThreatPerSourceSynId[sourceSynId].ETR = now+threatProfile.MaxLag
			else ThreatPerSourceSynId[sourceSynId].ETR = now+ASSUMED_MAX_LAG_OF_WARNING end

		elseif result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_BLOCKED_DAMAGE or result==ACTION_RESULT_STAGGERED then

			--see if there is a valid corresponding WarningSign...
			local lastWarningSign = LastWarningSignPerSourceSynId[sourceSynId]
			if lastWarningSign ~= nil then
				if lastWarningSign.Timestamp + ASSUMED_MAX_LAG_OF_WARNING > now then
					--...if so, learn about it
					ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId] = ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId] or { }
					local threatProfile = ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId]
					local observedLag = now - lastWarningSign.Timestamp
					if threatProfile.MinLag==nil or observedLag < threatProfile.MinLag then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].MinLag = observedLag end
					if threatProfile.MaxLag==nil or observedLag > threatProfile.MaxLag then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].MaxLag = observedLag end
					if result==ACTION_RESULT_STAGGERED then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].CausesStagger = true
					elseif result==ACTION_RESULT_BLOCKED_DAMAGE then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].CanBeBlocked = true
					elseif result==ACTION_RESULT_DAMAGE then
						if threatProfile.PredictedDamage == nil or hitValue > threatProfile.PredictedDamage then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].PredictedDamage = hitValue end
						if Blocking() and BlockInProgress() then ThreatProfilePerWarningAbilitySynId[lastWarningSign.AbilitySynId].CanBeBlocked = false end
					end
				end
			end

			--delete any threats (predictions) for this sourceSynId, cuz shit has already gone down
			ThreatPerSourceSynId[sourceSynId] = nil

			--delete WarningSign for this sourceSynId, cuz shit has already gone down and we already learned from it
			-- LastWarningSignPerSourceSynId[sourceSynId] = nil

		end
	end
end
local function ReciteThreats()
	d("---------------")
	for key, value in pairs(ThreatPerSourceSynId) do
		d("-------")
		d(key)
		d(value)
	end
end

--Suggested Logic Examples (for function AutoFightMain below)
--[Smart Blocking]: elseif AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())) then Block()

-- END COMMON CODE 01

-- START CHARACTER-SPECIFIC CODE 01

local CharacterFirstName = "Gideon"
local BlockCost = 2160

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
	elseif AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())) then Block()
	elseif LowestGroupHealthPercentWithoutRegen()<90 then WeaveAbility(2)
	-- elseif not IHave("Minor Sorcery") and TargetIsHostileNpc() and Magicka()>80 then WeaveAbility(5)
	elseif UltimateReady() and TargetIsBoss() then UseUltimate()
	-- elseif not TargetHas("Minor Magickasteal") and TargetIsHostileNpc() then WeaveAbility(3)
	-- elseif not IHave("Major Resolve") then WeaveAbility(5)
	elseif SomeoneCouldUseRegen() and Magicka()>50 then WeaveAbility(2)
	-- elseif TargetIsHostileNpc() and not TargetHas("Minor Lifesteal") then WeaveAbility(5)
	elseif Magicka()>99 then WeaveAbility(5)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	elseif AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>0.5*(BlockCost/StaminaPoints())) then Block()
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
			EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."blarg", 1000, ReciteThreats)
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnEventCombatEvent)
		end
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- END COMMON CODE 02

