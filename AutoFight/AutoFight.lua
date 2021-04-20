-- #region COMMON CODE 01

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

-- #region start local copies

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
local VMLeft = LibPixelControl.VM_BTN_LEFT
local VMRight = LibPixelControl.VM_BTN_RIGHT

local Blocking = IsBlockActive
local Now = GetGameTimeMilliseconds
local Mounted = IsMounted
local Print = d

local GetUnitName = GetUnitName

-- #endregion local copies

local CharName
local BlockCost = 2160 -- default until overwritten by character-specific code
local InMeleeRange = false
local SynergyName
local TargetName

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
	return DoesUnitExist('reticleover') and not IsUnitDead('reticleover') and GetUnitType('reticleover') ~= 1 and GetUnitReaction('reticleover') == UNIT_REACTION_HOSTILE and IsUnitInCombat('reticleover')
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
	return (TargetCouldBeTaunted() and (TargetIsBoss() or (Stamina()>50 and TargetIsMoreThanTrash()) or (Stamina()>90) ))
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
	return (not IsUnitInCombat('player') or IsReticleHidden() or IsUnitSwimming('player') or IsUnitDead('player') or Mounted() or IHave("Bestial Transformation") or IHave("Skeevaton") or InteractName()=="Cage of Torment" or IsUnitBeingResurrected("reticleover"))
end
-- #region Healer functions
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

-- #endregion

-- #region Actions
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

-- #endregion

-- #region Attack Begin Blocking
local ABB = { } -- Attack Begin Blocking, saved variable
local IncomingAttackETA = 0
local IncomingAttackETR = 0
local IncomingAttackPredictedDamage = 1
local IncomingAttackAbilitySynId = 0
local IncomingAttackIsNotBlockTested = false
local IncomingAttackSourceUnitId = 0
local IncomingAttackBeginTimestamp = 0
local LAG_THAT_IS_TOO_QUICK_TO_BLOCK = 120
local BLOCK_TEST_THRESHOLD = 5
local function InitializeABBDataStructures()
	ABB.MaxRecordedDamagePerAbilitySynId = ABB.MaxRecordedDamagePerAbilitySynId or { }
	ABB.MinRecordedLagPerAbilitySynId = ABB.MinRecordedLagPerAbilitySynId or { }
	ABB.MaxRecordedLagPerAbilitySynId = ABB.MaxRecordedLagPerAbilitySynId or { }
	ABB.CanBeBlockedPerAbilitySynId = ABB.CanBeBlockedPerAbilitySynId or { }
	ABB.BlockTestsPerAbilitySynId = ABB.BlockTestsPerAbilitySynId or { }
end
local function AttackIncoming()
	return (IncomingAttackETA-300<Now() and IncomingAttackETR+300>Now())
end
local function OnEventCombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	local abilitySynId = sourceName.." "..abilityName
	if targetType==COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then
		if result==ACTION_RESULT_BEGIN then
			if (ABB.CanBeBlockedPerAbilitySynId[abilitySynId] or nil==ABB.BlockTestsPerAbilitySynId[abilitySynId] or ABB.BlockTestsPerAbilitySynId[abilitySynId]<BLOCK_TEST_THRESHOLD) then
				if (nil==ABB.MinRecordedLagPerAbilitySynId[abilitySynId] or ABB.MinRecordedLagPerAbilitySynId[abilitySynId] > LAG_THAT_IS_TOO_QUICK_TO_BLOCK) then
					if ((not AttackIncoming()) or (abilitySynId~=IncomingAttackAbilitySynId and nil~=ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] and IncomingAttackPredictedDamage < ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId])) then
						IncomingAttackBeginTimestamp = Now()
						if nil~=ABB.MinRecordedLagPerAbilitySynId[abilitySynId] then IncomingAttackETA = Now()+ABB.MinRecordedLagPerAbilitySynId[abilitySynId]
						else IncomingAttackETA = Now() end
						if nil~=ABB.MaxRecordedLagPerAbilitySynId[abilitySynId] then IncomingAttackETR = Now()+ABB.MaxRecordedLagPerAbilitySynId[abilitySynId]
						else IncomingAttackETR = Now()+5000 end -- max duration assumption
						if nil~=ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] then IncomingAttackPredictedDamage = ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId]
						else IncomingAttackPredictedDamage = 1 end
						IncomingAttackAbilitySynId = abilitySynId
						IncomingAttackSourceUnitId = sourceUnitId
						IncomingAttackIsNotBlockTested = ((ABB.CanBeBlockedPerAbilitySynId[abilitySynId]~=true) and (nil==ABB.BlockTestsPerAbilitySynId[abilitySynId] or ABB.BlockTestsPerAbilitySynId[abilitySynId]<BLOCK_TEST_THRESHOLD))
						if nil==ABB.BlockTestsPerAbilitySynId[abilitySynId] then ABB.BlockTestsPerAbilitySynId[abilitySynId] = 1
						else ABB.BlockTestsPerAbilitySynId[abilitySynId] = ABB.BlockTestsPerAbilitySynId[abilitySynId] + 1 end
					end
				else
					-- d("too fast: "..abilitySynId.." "..ABB.MinRecordedLagPerAbilitySynId[abilitySynId])
				end
			else
				-- d("can't be blocked: "..abilitySynId)
			end
		elseif result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_BLOCKED_DAMAGE then
			if (IncomingAttackETR+500>Now() and IncomingAttackSourceUnitId==sourceUnitId and IncomingAttackAbilitySynId==abilitySynId) then
				local Lag = Now()-IncomingAttackBeginTimestamp
				if nil==ABB.MinRecordedLagPerAbilitySynId[abilitySynId] or ABB.MinRecordedLagPerAbilitySynId[abilitySynId]>Lag then ABB.MinRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				if nil==ABB.MaxRecordedLagPerAbilitySynId[abilitySynId] or ABB.MaxRecordedLagPerAbilitySynId[abilitySynId]<Lag then ABB.MaxRecordedLagPerAbilitySynId[abilitySynId]=Lag end
				IncomingAttackETR = 0
			end
		end
		if result==ACTION_RESULT_DAMAGE then
			if ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId]==nil or hitValue > ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] then ABB.MaxRecordedDamagePerAbilitySynId[abilitySynId] = hitValue end
		elseif result==ACTION_RESULT_BLOCKED_DAMAGE then
			-- d("blocked: "..abilitySynId)
			if ABB.CanBeBlockedPerAbilitySynId[abilitySynId] ~= true then
				ABB.CanBeBlockedPerAbilitySynId[abilitySynId] = true
				d("AutoFight: learned to block: "..abilitySynId)
			end
		end
	end
end
local Stunned = false
local function OnEventStunStateChanged(_,StunState)
	Stunned = StunState
end
local function ShouldBlock()
	return (AttackIncoming() and StaminaPoints()>BlockCost and (IncomingAttackIsNotBlockTested or (IncomingAttackPredictedDamage/HealthPoints())>(BlockCost/StaminaPoints())))
end
-- #endregion

-- #region Key Bindings
ZO_CreateStringId("SI_BINDING_NAME_InMeleeRange", "InMeleeRange")
function KeyBindInMeleeRangeYes()
	InMeleeRange = true
end
function KeyBindInMeleeRangeNo()
	InMeleeRange = false
end
-- #endregion

-- #region AutoFight standard inserts
-- these are bits of logic that are common across all characters and need to be inserted at specific points (for example: after healing, but before attacking)

local function TopPriorityAutoFight()
	SynergyName = GetSynergyInfo()
	TargetName = GetUnitName("reticleover")
	if DoesUnitHaveResurrectPending("player") then DoInteract()
	elseif AutoFightShouldNotAct() then DoNothing()
	elseif Stunned then BreakFree()
	elseif SynergyName == "Flesh Grenade" and TargetName == "Inmate" then DoSynergy()
	elseif InteractName() == "Daedric Alter" then DoInteract()
	else return false --signals to the caller that this function did NOT take an action; the caller function will continue down its elseif sequence
	end
	return true --signals to caller that this function did take an action and the caller function should not override that
end

local function PreAttackAutoFight()
	if TargetName == "Inmate" or SynergyName == "Flesh Grenade" then DoNothing()
	elseif TargetName=="Lightning Aspect" then DoNothing()
	elseif SynergyName == "Gravity Crush" then DoSynergy()
	elseif SynergyName == "Combustion" then DoSynergy()
	elseif TargetName == "Plane Meld Rift" then LightAttack()
	elseif (Health() < 50 or Magicka() < 15) and QuickslotName() == CROWN_TRI_POTION and QuickslotIsReady() then DoQuickslot()
	else return false --signals to the caller that this function did NOT take an action; the caller function will continue down its elseif sequence
	end
	return true --signals to caller that this function did take an action and the caller function should not override that
end

-- #endregion

-- #endregion COMMON CODE 01

-- #region CHARACTER-SPECIFIC CODE 01

local BlockCostPerChar = {
	[GIDEON] = 2020,
	[GALILEI] = nil,
	[DORIAN] = nil,
	[GALILEI] = nil,
	[HADARA] = 2012,
	[ELODIE] = 1943,
	[FREYA] = nil,
	[JERICAH] = 1120,
	[NEVIRA] = nil,
	[KRIN] = 1068,
	[NISSA] = nil,
	[ANYA] = nil,
	[MINA] = nil,
	[KARRIE] = 1619,
}

local AutoFight = {}

AutoFight[GIDEON] = function ()
	if TopPriorityAutoFight() then
	elseif Magicka()<15 and not Blocking() then HeavyAttack()
	elseif LowestGroupHealthPercent()<40 then UseAbility(1)
	elseif LowestGroupHealthPercent()<70 and Magicka()>70 then UseAbility(1)
	elseif LowestGroupHealthPercentWithoutRegen()<80 then UseAbility(2)
	elseif ShouldBlock() then Block()
	elseif PreAttackAutoFight() then
	-- elseif UltimateReady() and TargetIsHostileNpc() then UseUltimate()
	elseif LowestGroupHealthPercentWithoutRegen()<90 then WeaveAbility(2)
	elseif InMeleeRange and Magicka()>80 then WeaveAbility(5)
	elseif SomeoneCouldUseRegen() and Magicka()>50 then WeaveAbility(2)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[DORIAN] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 80 and Magicka() > 80 then WeaveAbility(4)
	elseif Health() < 60 and Magicka() > 40 then UseAbility(4)
	elseif Health() < 40 and Magicka() > 25 then UseAbility(4)
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() then UseUltimate()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[JERICAH] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 40 and TargetIsHostileNpc() and MagickaPoints() > 3000 then UseAbility(4)
	elseif Health() < 50 and TargetIsHostileNpc() and MagickaPoints() > 3000 then WeaveAbility(4)
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif TargetShouldBeTaunted() and StaminaPoints()>1500 then WeaveAbility(2)
	elseif not IHave("Major Resolve") and MagickaPoints()>2500 then WeaveAbility(3)
	elseif not IHave("Minor Protection") and MagickaPoints()>4000 then WeaveAbility(5)
	elseif TargetIsHostileNpc() and Stamina()>90 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and (not Blocking()) and (not BlockInProgress()) then HeavyAttack() -- do we really need BlockInProgress?
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[GALILEI] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif Health() < 60 then WeaveAbility(4)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and not TargetHas("Minor Vulnerability") and Magicka() > 25 then WeaveAbility(3)
	elseif TargetIsHostileNpc() and Stamina() > 40 then WeaveAbility(1)
	elseif TargetIsHostileNpc() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[ELODIE] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and Magicka()>15 then WeaveAbility(1)
	elseif not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[HADARA] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
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

AutoFight[FREYA] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 60 and StaminaPoints() > 4000 then UseAbility(4)
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif not IHave("Molten Armaments") and MagickaPoints() > 10000 and TargetIsHostileNpc() then WeaveAbility(3)
	elseif not IHave("Flames of Oblivion") and MagickaPoints() > 10000 and TargetIsHostileNpc() then WeaveAbility(5)
	elseif TargetIsHostileNpc() and StaminaPoints() > 10000 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[KARRIE] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif Health() < 60 and not IHave("Leeching Strikes") then WeaveAbility(5)
	elseif TargetIsHostileNpc() and not Blocking() and Stamina() > 50 then LightAttack()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[MINA] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 50 and MagickaPoints() > 4000 then UseAbility(5)
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif InMeleeRange and Magicka() > 20 then WeaveAbility(1)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[ANYA] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif not IHave("Skeletal Archer") and Stamina() > 50 then WeaveAbility(4)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight[KRIN] = function ()
	if TopPriorityAutoFight() then
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif TargetShouldBeTaunted() then WeaveAbility(4)
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	-- elseif not IHave("Summon Unstable Clannfear") then WeaveAbility(5)
	-- elseif not IHave("Summon Twilight Matriarch") then WeaveAbility(2)
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

AutoFight["TEMPLATE"] = function ()
	if TopPriorityAutoFight() then
	elseif Health() < 80 then UseAbility(1)
	elseif PreAttackAutoFight() then
	elseif ShouldBlock() then Block()
	elseif UltimateReady() and TargetIsHostileNpc() and TargetIsMoreThanTrash() then UseUltimate()
	elseif TargetIsHostileNpc() and not Blocking() then HeavyAttack()
	else DoNothing()
	end
end

-- #endregion CHARACTER-SPECIFIC CODE 01

-- #region COMMON CODE 02

local function InitializeVariables()
	BlockCost = BlockCostPerChar[CharName] or BlockCost
	ABB = ZO_SavedVars:NewAccountWide("ABB",0)
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

-- #endregion COMMON CODE 02

