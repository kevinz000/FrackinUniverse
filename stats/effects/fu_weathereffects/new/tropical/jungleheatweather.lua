require("/scripts/vec2.lua")

function init()
	self.timerRadioMessage = 0  -- initial delay for secondary radiomessages

	-- Environment Configuration --
	--base values
	self.effectCutoff = config.getParameter("effectCutoff",0)
	self.effectCutoffValue = config.getParameter("effectCutoffValue",0)
	self.baseRate = config.getParameter("baseRate",0)
	self.baseDmg = config.getParameter("baseDmgPerTick",0)
	self.baseDebuff = config.getParameter("baseDebuffPerTick",0)
	self.biomeTemp = config.getParameter("biomeTemp",0)

	--timers

	self.biomeTimer = self.baseRate
	self.biomeTimer2 = (self.baseRate * (1 + status.stat("physicalResistance",0)) *10)

	--conditionals

	self.windLevel =  world.windLevel(mcontroller.position())        -- is there wind? we note that too
	self.biomeThreshold = config.getParameter("biomeThreshold",0)    -- base Modifier (tier)
	self.biomeNight = config.getParameter("biomeNight",0)            -- is this effect worse at night? how much?
	self.situationPenalty = config.getParameter("situationPenalty",0)-- situational modifiers are seldom applied...but provided if needed
	self.liquidPenalty = config.getParameter("liquidPenalty",0)      -- does liquid make things worse? how much?

	checkEffectValid()

	script.setUpdateDelta(5)
end

--[[ Helper function to determine if weather effect applies to an entity ]]--
function isEntityAffected()
	-- if not a player, or world type is "unknown" (???) then return false --
	if ((world.entityType(entity.id()) ~= "player") or
	world.type()=="unknown") then
		return false
	end
	-- if player has immunity stat or sufficient resistance, return false --
	if (status.statPositive("biomeheatImmunity") or
	status.statPositive("ffextremeheatImmunity") or
	(status.stat("fireResistance",0) >= self.effectCutoffValue) or
	(status.stat("physicalResistance",0) >= self.effectCutoffValue))then
		return false
	end
	-- otherwise, return true
	return true
end

--[[ Check if weather effect is still applicable, and handle visual effects ]]--
function checkEffectValid()
	-- remove visual effect if no longer affected
	if not isEntityAffected() then
		deactivateVisualEffects()
		effect.expire()
	-- add visual effect and display warning (if not yet shown)
	else
		activateVisualEffects()
		if not self.usedIntro and self.timerRadioMessage <= 0 then
			world.sendEntityMessage(entity.id(), "queueRadioMessage", "ffbiomejungle", 1.0) -- send player a warning
			self.usedIntro = 1
			self.timerRadioMessage = 20
		end
	end
end

-- *******************Damage effects
function setEffectDamage()
	return ( ( self.baseDmg ) *  (1 -status.stat("physicalResistance",0) ) * self.biomeThreshold  )
end

function setEffectDebuff()
	return ( ( ( self.baseDebuff) * self.biomeTemp ) * (1 -status.stat("physicalResistance",0) * self.biomeThreshold) )
end

function setEffectTime()
	return (  self.baseRate *  math.min(   1 - math.min( status.stat("physicalResistance",0) ),0.6))
end

-- ******** Applied bonuses and penalties
function setNightPenalty()
	if (self.biomeNight > 1) then
		self.baseDmg = self.baseDmg + self.biomeNight
		self.baseDebuff = self.baseDebuff + self.biomeNight
	end
end

function setSituationPenalty()
	if (self.situationPenalty > 1) then
		self.baseDmg = self.baseDmg + self.situationPenalty
		self.baseDebuff = self.baseDebuff + self.situationPenalty
	end
end

function setLiquidPenalty()
	if (self.liquidPenalty > 1) then
		self.baseDmg = self.baseDmg * 2
		self.baseDebuff = self.baseDebuff + self.liquidPenalty
	end
end

function setWindPenalty()
	self.windLevel =  world.windLevel(mcontroller.position())
	if (self.windLevel > 1) then
		self.biomeThreshold = self.biomeThreshold + (self.windlevel / 100)
	end
end

-- ********************************

--**** Other functions
function getLight()
	local position = mcontroller.position()
	position[1] = math.floor(position[1])
	position[2] = math.floor(position[2])
	local lightLevel = world.lightLevel(position)
	lightLevel = math.floor(lightLevel * 100)
	return lightLevel
end

function daytimeCheck()
	return world.timeOfDay() < 0.5 -- true if daytime
end

function undergroundCheck()
	return world.underground(mcontroller.position())
end


function isDry()
	local mouthPosition = vec2.add(mcontroller.position(), status.statusProperty("mouthPosition"))
	return not world.liquidAt(mouthPosition)
end

function hungerLevel()
	if status.isResource("food") then
		return status.resource("food")
	else
		return 50
	end
end

function toHex(num)
	local hex = string.format("%X", math.floor(num + 0.5))
	if num < 16 then hex = "0"..hex end
	return hex
end

--**** Alert the player
function activateVisualEffects()
	effect.setParentDirectives("fade=ff7600=0.05")
	--animator.setParticleEmitterOffsetRegion("firebreath", mcontroller.boundBox())
	--animator.setParticleEmitterActive("firebreath", true)
end

function deactivateVisualEffects()
	effect.setParentDirectives("fade=ff7600=0.0")
	--animator.setParticleEmitterActive("firebreath", false)
end


function makeAlert()
	world.spawnProjectile("fireinvis",mcontroller.position(),entity.id(),directionTo,false,{power = 0,damageTeam = sourceDamageTeam})
	animator.playSound("bolt")
end



function update(dt)
	checkEffectValid()
	--self.biomeTimer = self.biomeTimer - dt
	--self.biomeTimer2 = self.biomeTimer2 - dt
	self.timerRadioMessage = self.timerRadioMessage - dt

	--set the base stats
	self.baseRate = config.getParameter("baseRate",0)
	self.baseDmg = config.getParameter("baseDmgPerTick",0)
	self.baseDebuff = config.getParameter("baseDebuffPerTick",0)
	self.biomeTemp = config.getParameter("biomeTemp",0)
	self.biomeThreshold = config.getParameter("biomeThreshold",0)
	self.biomeNight = config.getParameter("biomeNight",0)
	self.situationPenalty = config.getParameter("situationPenalty",0)
	self.liquidPenalty = config.getParameter("liquidPenalty",0)

	self.baseRate = setEffectTime()
	self.damageApply = setEffectDamage()
	self.debuffApply = setEffectDebuff()

	-- environment checks
	local daytime = daytimeCheck()
	local underground = undergroundCheck()
	local lightLevel = getLight()
	local dry = isDry()

	if isEntityAffected() then
		-- Jungle heat is reduced while in certain liquids.
		if not dry and (
			(mcontroller.liquidId()== 1) or
			(mcontroller.liquidId()== 6) or
			(mcontroller.liquidId()== 58) or
			(mcontroller.liquidId()== 12)
		) then
			setLiquidPenalty()
			if (self.timerRadioMessage <= 0) then
				if not self.usedWater then
					world.sendEntityMessage(entity.id(), "queueRadioMessage", "ffbiomejunglewater", 1.0) -- send player a warning
					self.timerRadioMessage = 60
					self.usedWater = 1
				end
			end
		end
		-- Set damage totals with modifiers.
		self.damageApply = setEffectDamage()
		self.debuffApply = setEffectDebuff()
		-- Apply health drain.
		status.modifyResource("health", -self.damageApply * dt)
		-- If at low health, penalise movement.
		--[[TODO: It would help to have some kind of warning message when this happens.]]--
		if (status.resource("health")) <= (status.stat("maxHealth")/3) then
			self.modifier = math.max(status.stat("physicalResistance",0), 0.4)
			mcontroller.controlModifiers({
				airJumpModifier = self.modifier,
				speedModifier = self.modifier
			})
		end
	end --isEntityAffected()
end

function uninit()

end
