--#region COMMON CODE 01

--#region Constants
local ADDON_NAME = "AutoFight"
local GIDEON = "Gideon Godiva"
local GALILEI = "Galilei Godiva"
local DORIAN = "Dorian Delafield"
local HADARA = "Hadara Hazelwood"
local ELODIE = "Elodie Enwarin"
local FREYA = "Freya Fiori"
local JERICAH = "Jericah Jacarei"
local NEVIRA = "Nevira Pendragon"
local KRIN = "Krin Delvinay"
local NISSA = "Nissa Forbus"
local ANYA = "Anya Romaine"
local MINA = "Mina Copperton"
local KARRIE = "Karrie Lumin"
local CROWN_TRI_POTION = "Crown Tri-Restoration Potion"
--#endregion

--#region Local copies

local VK1 = LibPixelControl.VK_1
local VK2 = LibPixelControl.VK_2
local VK3 = LibPixelControl.VK_3
local VK4 = LibPixelControl.VK_4
local VK5 = LibPixelControl.VK_5
local VKE = LibPixelControl.VK_E
local VKQ = LibPixelControl.VK_Q
local VKR = LibPixelControl.VK_R
local VKX = LibPixelControl.VK_X
local VKF9 = LibPixelControl.VK_F9
local VKF10 = LibPixelControl.VK_F10
local VMLeft = LibPixelControl.VM_BTN_LEFT
local VMRight = LibPixelControl.VM_BTN_RIGHT

local Blocking = IsBlockActive
local Now = GetGameTimeMilliseconds
local Mounted = IsMounted
local Print = d
local Werewolf = IsWerewolf

local GetUnitName = GetUnitName

local function FormatString(inputString)
	return ZO_CachedStrFormat("<<C:1>>",inputString)
end

--#endregion

--#region Info variables
local CharName
local BlockCost = 2160 -- default until overwritten by character-specific code
local BlockMitigation = 0.50 -- default until overwritten by character-specific code
local InMeleeRange = false
local SynergyName
local TargetName
--#endregion

--#region Common info functions
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
local function WerewolfPowerPct()
	local current, max, effectiveMax = GetUnitPower('player', POWERTYPE_WEREWOLF)
	return ((current/max)*100)
end
local function QuickslotName()
	return GetSlotName(GetCurrentQuickslot())
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
	return DoesUnitExist('reticleover') and not IsUnitDead('reticleover') and GetUnitType('reticleover') ~= 1 and (TargetName=="Storm Atronach" or TargetName=="Lightning Aspect" or (GetUnitReaction('reticleover') == UNIT_REACTION_HOSTILE and IsUnitInCombat('reticleover')))
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
local function RollDodgeCost()
	if IHave("Dodge Fatigue") then return 4872
	else return 3654 end
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
local function InteractVerb()
	local action, _, _, _, _ = GetGameCameraInteractableActionInfo()
	return action
end
local function InteractName()
	local _, interactableName, _, _, _ = GetGameCameraInteractableActionInfo()
	return interactableName
end
--#endregion

--#region Healer functions
local function LowestGroupHealthPercent()
	local GroupSize = GetGroupSize()
	local LowestGroupHealthPercent = 1.00
	if GroupSize > 0 then
		for i = 1, GroupSize do
			local unitTag = GetGroupUnitTagByIndex(i)
			local currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
			local HpPercent = currentHp / maxHp
			if HpPercent < LowestGroupHealthPercent and IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 and not DoesUnitHaveResurrectPending(unitTag) then
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
			if HpPercent < LowestGroupHealthPercent and not UnitHasRegen(unitTag) and IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 and not DoesUnitHaveResurrectPending(unitTag) then
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
local function SomeoneCouldUseRegen()
	local GroupSize = GetGroupSize()
	local unitTag
	if GroupSize > 0 then
		local GroupMembersWithPlentyOfRegen = 0
		local GroupMembersInSupportRange = 0
		for i = 1, GroupSize do
			unitTag = GetGroupUnitTagByIndex(i)
			if IsUnitInGroupSupportRange(unitTag) and not IsUnitDead(unitTag) and GetUnitType(unitTag) == 1 and not DoesUnitHaveResurrectPending(unitTag) then
				GroupMembersInSupportRange = GroupMembersInSupportRange + 1
				if not UnitHasRegen(unitTag) then return true end
				if UnitHasBuffTimeLeft(unitTag,"Radiating Regeneration",5000) then
				GroupMembersWithPlentyOfRegen = GroupMembersWithPlentyOfRegen + 1 end
			end
		end
		return (GroupMembersWithPlentyOfRegen < 3 and GroupMembersWithPlentyOfRegen < GroupMembersInSupportRange)
	else return (not UnitHasBuffTimeLeft("player","Radiating Regeneration",5000)) end
end

local function QuickslotIsReady()
	local timeRemaining, _, global, _ = GetSlotCooldownInfo(GetCurrentQuickslot())
	local potionsAvailable = GetSlotItemCount(GetCurrentQuickslot())
	if potionsAvailable==nil then return false end
	if timeRemaining==0 and global and potionsAvailable > 0 then
		return true
	else
		return false
	end
end

local function ActiveBar()
	local barNum = GetActiveWeaponPairInfo()
	return barNum
end

--#endregion

 --#region Tank functions
local function TargetCouldBeTaunted()
	return (TargetIsHostileNpc() and not UnitHasBuffTimeLeft("reticleover","Taunt",2000))
end
local function TargetShouldBeTaunted()
	return (TargetCouldBeTaunted() and (TargetIsBoss() or (Stamina()>50 and TargetIsMoreThanTrash()) or (Stamina()>90) ))
end
--#endregion

--#region Actions
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
local function RollDodge()
	EndBlock()
	EndHeavyAttack()
	Press(VKF10)
end
local function LightAttack()
	EndBlock()
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
local function BreakFree()
	EndBlock()
	EndHeavyAttack()
	Press(VKF9)
end
local function DoInteract()
	EndBlock()
	EndHeavyAttack()
	Press(VKE)
end
local function DoSynergy()
	Press(VKX)
end
local function DoQuickslot()
	Press(VKQ)
end
local function BlockInProgress()
	return (WeAreHolding[VMRight])
end
local function DoNothing()
	EndHeavyAttack()
	EndBlock()
end

--#endregion

--#region Attack Begin Blocking
local ABB = { } -- Attack Begin Blocking, saved variable
local IncomingAttacksBySourceUnitId = { }
local LAG_THAT_IS_TOO_QUICK_TO_BLOCK = 120
local BLOCK_TEST_THRESHOLD = 5
local function InitializeABBDataStructures()
	ABB.MaxRecordedDamagePerAbilitySynId = ABB.MaxRecordedDamagePerAbilitySynId or { }
	ABB.MinRecordedLagPerAbilitySynId = ABB.MinRecordedLagPerAbilitySynId or { }
	ABB.MaxRecordedLagPerAbilitySynId = ABB.MaxRecordedLagPerAbilitySynId or { }
	ABB.CanBeBlockedPerAbilitySynId = ABB.CanBeBlockedPerAbilitySynId or { }
	ABB.BlockTestsPerAbilitySynId = ABB.BlockTestsPerAbilitySynId or { }
end
local function CleanIncomingAttacksTable()
	for key, value in pairs(IncomingAttacksBySourceUnitId) do
		if value.Timestamp > Now() + 5000 then IncomingAttacksBySourceUnitId[key] = nil end	
	end
end
local function IncomingAttackIsAboutToHit(attack)
	local minRecordedLag = ABB.MinRecordedLagPerAbilitySynId[attack.AbilitySynId]
	if minRecordedLag == nil or minRecordedLag < LAG_THAT_IS_TOO_QUICK_TO_BLOCK then return false end
	local maxRecordedLag = ABB.MaxRecordedLagPerAbilitySynId[attack.AbilitySynId]
	if maxRecordedLag == nil then return false end
	local now = Now()
	local incomingAttackETA = attack.Timestamp + minRecordedLag
	local incomingAttackETR = attack.Timestamp + maxRecordedLag
	return (incomingAttackETA-300 < now and incomingAttackETR+300 > now)
end
local THAT_IS_BLOCKABLE = 1
local function WorstIncomingAttack(mustBeBlockable)
	local keyOfWorstAttack
	local biggestDamage = -1
	for key, value in pairs(IncomingAttacksBySourceUnitId) do
		local damageBeingExamined = ABB.MaxRecordedDamagePerAbilitySynId[value.AbilitySynId] or 0
		if damageBeingExamined > biggestDamage and IncomingAttackIsAboutToHit(value) and (mustBeBlockable == nil or ABB.CanBeBlockedPerAbilitySynId[value.AbilitySynId] == true) then
			keyOfWorstAttack = key
			biggestDamage = damageBeingExamined
		end
	end
	if keyOfWorstAttack == nil then return nil
	else return IncomingAttacksBySourceUnitId[keyOfWorstAttack]
	end
end
local function OnEventCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceNameRaw, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	local sourceName = FormatString(sourceNameRaw)
	local abilitySynId = sourceName.."__"..abilityName
	if targetType==COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then
		local now = Now()
		if result==ACTION_RESULT_BEGIN then
			IncomingAttacksBySourceUnitId[sourceUnitId] = {
				AbilityId = abilityId,
				AbilityName = abilityName,
				SourceName = sourceName,
				AbilitySynId = abilitySynId,
				Timestamp = now }
		elseif result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_BLOCKED_DAMAGE then
			local correspondingIncomingAttack = IncomingAttacksBySourceUnitId[sourceUnitId]
			if (correspondingIncomingAttack ~= nil and correspondingIncomingAttack.AbilitySynId==abilitySynId) then
				local Lag = (now - correspondingIncomingAttack.Timestamp)
				if nil==ABB.MinRecordedLagPerAbilitySynId[abilitySynId] or ABB.MinRecordedLagPerAbilitySynId[abilitySynId]>Lag then ABB.MinRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				if nil==ABB.MaxRecordedLagPerAbilitySynId[abilitySynId] or ABB.MaxRecordedLagPerAbilitySynId[abilitySynId]<Lag then ABB.MaxRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				IncomingAttacksBySourceUnitId[sourceUnitId] = nil
			end
			if result==ACTION_RESULT_DAMAGE then
				if ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId]==nil or hitValue > ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] then
					ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] = hitValue
					-- Print("AutoFight: new max damage recorded for: "..abilitySynId)
				end
			elseif result==ACTION_RESULT_BLOCKED_DAMAGE then
				if ABB.CanBeBlockedPerAbilitySynId[abilitySynId] ~= true then
					ABB.CanBeBlockedPerAbilitySynId[abilitySynId] = true
					-- d("AutoFight: learned to block: "..abilitySynId)
				end
			end
		end
	end
end
local Stunned = false
local function OnEventStunStateChanged(_,StunState)
	Stunned = StunState
end
local function ShouldBlock()
	local worstIncomingAttack = WorstIncomingAttack(THAT_IS_BLOCKABLE)
	if worstIncomingAttack == nil then return false end
	if not (ABB.CanBeBlockedPerAbilitySynId[worstIncomingAttack.AbilitySynId] == true) then return false end
	local predictedDamage = ABB.MaxRecordedDamagePerAbilitySynId[worstIncomingAttack.AbilitySynId]
	if predictedDamage == nil then return false end
	return (StaminaPoints()>BlockCost and ((predictedDamage*BlockMitigation)/HealthPoints())>(BlockCost/StaminaPoints()))
end
local function ShouldRollDodge()
	local worstIncomingAttack = WorstIncomingAttack()
	if worstIncomingAttack == nil then return false end
	local predictedDamage = ABB.MaxRecordedDamagePerAbilitySynId[worstIncomingAttack.AbilitySynId]
	if predictedDamage == nil then return false end
	local rollDodgeCost = RollDodgeCost()
	if (StaminaPoints()>rollDodgeCost and (predictedDamage/HealthPoints())>(rollDodgeCost/StaminaPoints())) then
		Print("Roll dodged "..worstIncomingAttack.AbilitySynId)
		return true
	else
		return false
	end
end
local function MustRollDodge()
	local worstIncomingAttack = WorstIncomingAttack()
	if worstIncomingAttack == nil then return false end
	local predictedDamage = ABB.MaxRecordedDamagePerAbilitySynId[worstIncomingAttack.AbilitySynId]
	if predictedDamage == nil then return false end
	if ( StaminaPoints()>RollDodgeCost() and predictedDamage>HealthPoints() ) then
		Print("Roll dodged "..worstIncomingAttack.AbilitySynId)
		return true
	else
		return false
	end
end
--#endregion

--#region Key Bindings
ZO_CreateStringId("SI_BINDING_NAME_InMeleeRange", "InMeleeRange")
function KeyBindInMeleeRangeYes()
	InMeleeRange = true
end
function KeyBindInMeleeRangeNo()
	InMeleeRange = false
end
--#endregion

--#region AutoFight standard inserts
local function AutoFightShouldNotAct()
	return (not IsUnitInCombat('player') or IsReticleHidden() or IsUnitSwimming('player') or IsUnitDead('player') or Mounted() or IHave("Bestial Transformation") or IHave("Skeevaton") or InteractName()=="Cage of Torment" or IsUnitBeingResurrected("reticleover"))
end
-- these are bits of logic that are common across all characters and need to be inserted at specific points (for example: after healing, but before attacking)

local function TopPriorityAutoFight()
	SynergyName = GetSynergyInfo()
	TargetName = GetUnitName("reticleover")
	if DoesUnitHaveResurrectPending("player") then DoInteract()
	elseif TargetName == "Avatar of the Hist" then LightAttack()
	elseif SynergyName == "Brazier" then DoSynergy()
	elseif SynergyName == "Atronach's Light" then DoSynergy()
	elseif AutoFightShouldNotAct() then DoNothing()
	elseif Stunned then BreakFree()
	elseif SynergyName == "Flesh Grenade" and TargetName == "Inmate" then DoSynergy()
	elseif InteractName() == "Daedric Alter" then DoInteract()
	elseif MustRollDodge() then RollDodge()
	else return false --signals to the caller that this function did NOT take an action; the caller function will continue down its elseif sequence
	end
	return true --signals to caller that this function did take an action and the caller function should not override that
end

local function PreAttackAutoFight()
	if TargetName == "Inmate" or SynergyName == "Flesh Grenade" then DoNothing()
	elseif TargetName == "Argonian Wranglers" then DoNothing()
	elseif SynergyName == "Gravity Crush" then DoSynergy()
	elseif SynergyName == "Combustion" then DoSynergy()
	elseif SynergyName == "Grave Robber" then DoSynergy()
	elseif SynergyName == "Pure Agony" then DoSynergy()
	elseif SynergyName == "Ignite" then DoSynergy()
	elseif SynergyName == "Charged Lightning" then DoSynergy()
	elseif SynergyName == "Conduit" then DoSynergy()
	elseif SynergyName == "Radiate" then DoSynergy()
	elseif SynergyName == "Shackle" then DoSynergy()
	elseif TargetName == "Plane Meld Rift" then LightAttack()
	elseif (Health() < 50 or Magicka() < 40 or Stamina() < 50) and QuickslotName() == CROWN_TRI_POTION and QuickslotIsReady() then DoQuickslot()
	elseif ShouldBlock() then Block()
	elseif not Blocking() and ShouldRollDodge() then RollDodge()
	else return false --signals to the caller that this function did NOT take an action; the caller function will continue down its elseif sequence
	end
	return true --signals to caller that this function did take an action and the caller function should not override that
end

--#endregion

--#endregion

--#region CHARACTER-SPECIFIC CODE 01

local BlockCostPerChar = {}
local BlockMitigationPerChar = {}
local AutoFight = {}

BlockCostPerChar[GIDEON] = 2020
AutoFight[GIDEON] = function ()
	if TopPriorityAutoFight() then
	elseif Magicka()<15 and not Blocking() then HeavyAttack()
	elseif LowestGroupHealthPercent()<40 then UseAbility(1)
	elseif LowestGroupHealthPercent()<70 and Magicka()>70 then UseAbility(1)
	elseif LowestGroupHealthPercentWithoutRegen()<80 then UseAbility(2)
	elseif PreAttackAutoFight() then
	-- elseif UltimateReady() and TargetIsHostileNpc() then UseUltimate()
	elseif LowestGroupHealthPercentWithoutRegen()<90 then WeaveAbility(2)
	-- elseif InMeleeRange and Magicka()>80 then WeaveAbility(5)
	elseif TargetIsHostileNpc and Magicka()>99 then WeaveAbility(5)
	elseif SomeoneCouldUseRegen() and Magicka()>50 then WeaveAbility(2)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[DORIAN] = nil
AutoFight[DORIAN] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 80 and Magicka() > 80 then WeaveAbility(4)
	elseif Health() < 60 and Magicka() > 40 then UseAbility(4)
	elseif Health() < 40 and Magicka() > 25 then UseAbility(4)
	elseif PreAttackAutoFight() then
	elseif UltimateReady() then UseUltimate()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[JERICAH] = 1120
AutoFight[JERICAH] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 40 and TargetIsHostileNpc() and MagickaPoints() > 3000 then UseAbility(4)
	elseif Health() < 50 and TargetIsHostileNpc() and MagickaPoints() > 3000 then WeaveAbility(4)
	elseif PreAttackAutoFight() then
	elseif TargetShouldBeTaunted() and ActiveBar()==1 and StaminaPoints()>1500 then WeaveAbility(2)
	elseif ActiveBar()==2 and not IHave("Skeletal Archer") and StaminaPoints()>4000 then WeaveAbility(5)
	elseif ActiveBar()==2 and not IHave("Blighted Blastbones") and StaminaPoints()>5000 then WeaveAbility(2)
	elseif not IHave("Major Resolve") and ActiveBar()==1 and MagickaPoints()>2500 then WeaveAbility(3)
	elseif not IHave("Minor Protection") and ActiveBar()==1 and MagickaPoints()>4000 then WeaveAbility(5)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and ActiveBar()==1 and Stamina()>90 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and ActiveBar()==2 and Stamina()>40 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	elseif not IHave("Major Resolve") and MagickaPoints()>2500 then WeaveAbility(3)
	else DoNothing()
	end
end

BlockCostPerChar[GALILEI] = nil
AutoFight[GALILEI] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif Health() < 60 then WeaveAbility(4)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif ActiveBar()==1 and TargetIsHostileNpc() and not TargetHas("Minor Vulnerability") and Magicka() > 25 then WeaveAbility(3)
	elseif ActiveBar()==2 and TargetIsHostileNpc() and not TargetHas("Poison Injection") and Stamina() > 40 then WeaveAbility(3)
	elseif ActiveBar()==2 and TargetIsHostileNpc() and not TargetHas("Acid Spray") and Stamina() > 40 then WeaveAbility(2)
	elseif TargetIsHostileNpc() and Stamina() > 40 then WeaveAbility(1)
	elseif TargetIsHostileNpc() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[ELODIE] = 1943
AutoFight[ELODIE] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and Magicka()>15 then WeaveAbility(1)
	elseif not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[HADARA] = 2012
AutoFight[HADARA] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif Magicka() < 20 then HeavyAttack()
	elseif not IHave("Summon Twilight Matriarch") then UseAbility(4)
	elseif LowestGroupHealthPercent()<40 then UseAbility(4)
	elseif not IHave("Summon Volatile Familiar") then WeaveAbility(2)
	elseif VolatilePulseReady() then WeaveAbility(2)
	elseif not IHave("Major Sorcery") then WeaveAbility(3)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() then WeaveAbility(1)
	else DoNothing()
	end
end

BlockCostPerChar[FREYA] = nil
AutoFight[FREYA] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 60 and StaminaPoints() > 4000 then UseAbility(4)
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif not IHave("Molten Armaments") and MagickaPoints() > 10000 and TargetIsHostileNpc() then WeaveAbility(3)
	elseif not IHave("Flames of Oblivion") and MagickaPoints() > 10000 and TargetIsHostileNpc() then WeaveAbility(5)
	elseif ActiveBar()==2 and TargetIsHostileNpc() and not TargetHas("Poison Injection") and Stamina() > 40 then WeaveAbility(2)
	elseif TargetIsHostileNpc() and StaminaPoints() > 10000 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[KARRIE] = 1619
AutoFight[KARRIE] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif Health() < 60 and not IHave("Leeching Strikes") then WeaveAbility(5)
	elseif TargetIsHostileNpc() and not Blocking() and Stamina() > 50 then LightAttack()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[MINA] = 1369
AutoFight[MINA] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif TargetShouldBeTaunted() then WeaveAbility(2)
	elseif UltimateReady() and TargetIsHostileNpc() and InMeleeRange then UseUltimate()
	elseif InMeleeRange and Magicka() > 20 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[ANYA] = nil
AutoFight[ANYA] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif not IHave("Skeletal Archer") and Stamina() > 50 then WeaveAbility(4)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[KRIN] = 1068
AutoFight[KRIN] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif TargetShouldBeTaunted() then WeaveAbility(4)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	-- elseif not IHave("Summon Unstable Clannfear") then WeaveAbility(5)
	-- elseif not IHave("Summon Twilight Matriarch") then WeaveAbility(2)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

BlockCostPerChar[NISSA] = nil
AutoFight[NISSA] = function ()
	if TopPriorityAutoFight() then
	elseif Health()<60 and not IHave("Resolving Vigor") and StaminaPoints()>3000 then WeaveAbility(4)
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif Stamina()<60 then HeavyAttack()
	elseif TargetIsHostileNpc() and not TargetHas("Poison Injection") then WeaveAbility(2)
	elseif TargetIsHostileNpc() and not TargetHas("Acid Spray") then WeaveAbility(3)
	elseif TargetIsHostileNpc() then WeaveAbility(1)
	else DoNothing()
	end
end

BlockCostPerChar["TEMPLATE"] = nil
BlockMitigationPerChar["TEMPLATE"] = nil
AutoFight["TEMPLATE"] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 80 then UseAbility(1)
	elseif PreAttackAutoFight() then
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

--#endregion

--#region COMMON CODE 02

local function InitializeVariables()
	BlockCost = BlockCostPerChar[CharName] or BlockCost
	BlockMitigation = BlockMitigationPerChar[CharName] or BlockMitigation
	ABB = ZO_SavedVars:NewAccountWide("ABB",1)
	InitializeABBDataStructures()
end

local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		CharName = GetUnitName("player")
		if AutoFight[CharName] ~= nil then -- don't bother registering for events if I haven't written an AutoFight function for the current character
			InitializeVariables()
			EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 100, AutoFight[CharName]) -- register the character-specific AutoFight function to be called every 100ms
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnEventCombatEvent)
			EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_STUNNED_STATE_CHANGED, OnEventStunStateChanged)
		end
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

--#endregion

