#include "common.lua"
#include "pathfinding.lua"

--[[
**********************************************************************
*
* FILEHEADER: Elboydo's Armed Vehicles Framework (AVF) 
*
* AUTHORS: Z-Dev, Elboydo
*
* FILENAME :        AiComponent.lua             
*
* DESCRIPTION :
*       File that manages AI operations and teams 
*
*		Controls here manage AI aiming, weapon systems and other behaviors
*		
*
]]

AVF_ai = {
	OPFOR = 0,
	BLUFOR = 1,
	INDEP = 2,
	
	--Defining engagement modes
	M_ATTACK = 0,
	M_GUARD = 1,
	M_PATROL = 2,

	vehicles = {

	},

	bluForAI = {


	},
	opForAI = {


	},
	indepAI = {


	},
	templateVehicle = {
		id = nil,
		teamIndex = nil,
		info = nil, 
		features = nil, 
		side = nil,
		range = 100,
		precision = 1,
		persistance = 0.3,
		health = 1.0,
		dead = false,
		behaviors = {
			default_movement = M_ATTACK, --Defines what we default to. Can be configured
			--state = "safe",
			last_spotted = 0,
			spotted_memory = 20,
			move_path = nil,
			next_path_time = 0, -- in seconds
			wait_path = false,
			last_path_index = 1,
			path_recalced = false,
			los = false,
			move_target = nil, -- where we drive to
			target = nil,
		},
	},
	path_requeue_cooldown_base = 30, --how long in seconds before ai requeues for a target path
	min_vehicle_health = 0.7 --referring to the global config in main
}




function AVF_ai:initAi()

	index = #self.vehicles+1
 	self.vehicles[index] = deepcopy(self.templateVehicle)
 	self.vehicles[index].id = vehicle.id
 	self.vehicles[index].info = vehicle
 	self.vehicles[index].features = vehicleFeatures
 	local side = tonumber(GetTagValue(vehicle.id,"avf_ai"))
 	self.vehicles[index].side = side

	if(side) then 
	 	if(side == self.OPFOR) then
			self.vehicles[index].teamIndex=#self.opForAI+1
	 		self.opForAI[#self.opForAI+1] = index
	 	elseif(side == self.BLUFOR) then  
			self.vehicles[index].teamIndex=#self.bluForAI+1
	 		self.bluForAI[#self.bluForAI+1] = index
	 	elseif(side == self.INDEP) then 
			self.vehicles[index].teamIndex=#self.indepAI+1
	 		self.indepAI[#self.indepAI+1] = index
	 	end
	 end

 end

 --- function that operates through ai behaviors
 function AVF_ai:aiTick(dt)
	local playerVehicle = GetPlayerVehicle()
	pathTick(dt)
	--TODO: implement a timer to check this for optimization
	local newAiDetected = GetBool("level.avf.aichanged")
	if (newAiDetected) then
		SetBool("level.avf.aichanged", false)
		self:registerChange()
	end

	--Check that AI is not enabled
	local aiEnabled = GetBool("level.avf.aienabled")
	if (aiEnabled == false)then
		--Stop all currently aiming joints
		for key,ai in ipairs(self.vehicles) do
			if (ai ~= nil and ai ~= -1 and ai.id ~= playerVehicle) then
				self:stopAim(ai)
			end
		end
		return
	end

 	for key,ai in ipairs(self.vehicles) do
		if (ai ~= nil and ai ~= -1 and ai.id ~= playerVehicle) then
			vehicle = ai.info
			vehicleFeatures = ai.features

			if (ai.health < self.min_vehicle_health and ai.dead ~= true) then
				--JUST DIED
				self:onDeath(ai)
			elseif (ai.dead ~= true) then
				--CURRENTLY ALIVE
				ai.health = GetVehicleHealth(vehicle.id)
				if (ai.behaviors.target == nil or ai.behaviors.target.dead) then
					--CURRENT TARGET IS DEAD OR NON EXISTENT
					self:stopAim(ai)
					ai.behaviors.target = self:targetSelection(ai)
				else
					if (ai.behaviors.target.dead) then
						--CURRENT TARGET IS DEAD OR NON EXISTENT
						ai.behaviors.target = nil
						ai.behaviors.move_path = nil
					else
						--HAS TARGET TO FIGHT
						if(DEBUG_AI) then 
							DebugWatch(""..ai.id.." ", ai.behaviors.target)
						end
						self:handleTimers(ai,dt)
						self:checkPathing(ai)
						self:weaponAiming(ai,ai.behaviors.target)
						self:combatMovement(ai)
					end
				end
			end
 		end
	end
end

function AVF_ai:handleTimers(ai,dt)
	if (ai.behaviors.next_path_time > 0) then
		ai.behaviors.next_path_time = ai.behaviors.next_path_time - dt
	end
end

function AVF_ai:checkPathing(ai)
	if (ai.behaviors.target and ai.behaviors.wait_path ~= true and ai.behaviors.next_path_time <= 0) then
		ai.behaviors.next_path_time = self.path_requeue_cooldown_base
		ai.behaviors.wait_path = true
		queuePath(ai)
		if(DEBUG_AI) then
			DebugPrint("Path Queued for: "..ai.id)
		end
	end
	if (ai.behaviors.move_path) then
		ai.behaviors.wait_path = false
		if(DEBUG_AI) then
			drawMovementPath(ai.behaviors.move_path)
			DebugWatch(ai.id, "HAS PATH")
		end
	else
		if(DEBUG_AI) then
			DebugWatch(ai.id, "NO PATH")
		end
	end
end

function AVF_ai:dynamicInit(vehicleDict,vehicleFeatures,team,movemode)
	index = #self.vehicles+1
	self.vehicles[index] = deepcopy(self.templateVehicle)
	self.vehicles[index].id = vehicleDict.id
	self.vehicles[index].info = vehicleDict
	self.vehicles[index].features = vehicleFeatures
	local side = tonumber(GetTagValue(vehicleDict.id,"avf_ai"))
	self.vehicles[index].side = team
	self.vehicles[index].behaviors.default_movement = movemode

	if(team) then 
		if(team == self.OPFOR) then
		self.vehicles[index].teamIndex=#self.opForAI+1
			self.opForAI[#self.opForAI+1] = index
		elseif(team == self.BLUFOR) then  
		self.vehicles[index].teamIndex=#self.bluForAI+1
			self.bluForAI[#self.bluForAI+1] = index
		elseif(team == self.INDEP) then 
		self.vehicles[index].teamIndex=#self.indepAI+1
			self.indepAI[#self.indepAI+1] = index
		end
	end
end

function AVF_ai:reInit(ai,team)
	index = #self.vehicles+1
	self.vehicles[index] = ai
	ai.side = team

	if(team) then 
		if(team == self.OPFOR) then
		self.vehicles[index].teamIndex=#self.opForAI+1
			self.opForAI[#self.opForAI+1] = index
		elseif(team == self.BLUFOR) then  
		self.vehicles[index].teamIndex=#self.bluForAI+1
			self.bluForAI[#self.bluForAI+1] = index
		elseif(team == self.INDEP) then 
		self.vehicles[index].teamIndex=#self.indepAI+1
			self.indepAI[#self.indepAI+1] = index
		end
	end
end

function AVF_ai:switchAITeam(ai,toTeam)
	--TODO: clear target (reset memory?)
	self:clearRegistration(ai)
	self:reInit(ai, toTeam)
end

function AVF_ai:registerChange()
	--Get registry vars
	local bodyHandle = GetInt("level.avf.newid")
	local vehicleHandle = GetBodyVehicle(bodyHandle)
	local vehicleSide = GetInt("level.avf.newside")
	local aiMovementMode = GetInt("level.avf.newmovemode")
	local foundAI = nil

	--Check if we already registered this one
	if (vehicleHandle and vehicleHandle ~= 0) then
		for index, ai in ipairs(self.vehicles) do
			if (ai ~= nil and ai ~= -1) then
				if ai.id == vehicleHandle then
					foundAI = ai
				end
			end
		end

		if (foundAI) then
			foundAI.behaviors.default_movement = aiMovementMode
			--Ai already registered, check team
			if (foundAI.side == vehicleSide) then
				if(DEBUG_AI) then 
					DebugPrint("No changes...")
				end
			else
				--Do list magic to move our vehicle to one of the other lists
				self:switchAITeam(foundAI, vehicleSide)
			end
		else
			--go through default registration
			if(DEBUG_AI) then 
				DebugPrint("New Entry: "..vehicleHandle.." Team: "..vehicleSide.." ")
			end

			local vInfo = {
				id = vehicleHandle,
				}
			local vFeatures = defaultVehicleFeatures
			for index, avf_vehicle in ipairs(vehicles) do
				if avf_vehicle.vehicle.id == vehicleHandle then
					vFeatures = avf_vehicle.vehicleFeatures
				end
			end
			self:dynamicInit(vInfo, vFeatures, vehicleSide, aiMovementMode)
		end
	end
end

--TODO: Fix this to deregister properly, currently items are not reordered
--Maintaining a short list will provide a speed up with target acquisition
function AVF_ai:clearRegistration(ai)
	if (ai.side == self.OPFOR) then
		local vIndex = self.opForAI[ai.teamIndex]
		self.vehicles[vIndex] = -1
		self.opForAI[ai.teamIndex] = -1
	elseif(ai.side == self.BLUFOR) then
		local vIndex = self.bluForAI[ai.teamIndex]
		self.vehicles[vIndex] = -1
		self.bluForAI[ai.teamIndex] = -1
	elseif (ai.side == self.INDEP) then
		local vIndex = self.indepAI[ai.teamIndex]
		self.vehicles[vIndex] = -1
		self.indepAI[ai.teamIndex] = -1
	end
end

function AVF_ai:onDeath(ai)
	if(DEBUG_AI) then 
		DebugPrint("BOOM! Deregister: "..ai.id.."")
	end

	ai.dead = true
	self:clearRegistration(ai)
end

function AVF_ai:targetSelection(ai)
	local closestTarget = nil
	local closestDistance = 1000000

	if(ai.side~=self.OPFOR) then 
		for _,enemy in ipairs(self.opForAI) do 
			if (enemy) then
				if(DEBUG_AI) then 
					DebugWatch("Blufor target: ", self.vehicles[enemy].id)
				end
				local enemyVehicle = self.vehicles[enemy]
				if (enemyVehicle ~= nil and enemyVehicle.dead ~= true) then
					hitVehicle, distance = self:canSee(ai, enemyVehicle)
					if (hitVehicle and distance < closestDistance) then
						closestTarget = enemyVehicle
						closestDistance = distance
					end
				end
			end
		end
	end 

	if(ai.side~=self.BLUFOR) then 
		for _,enemy in ipairs(self.bluForAI) do 
			if (enemy) then
				if(DEBUG_AI) then 
					DebugWatch("Opfor target: ", self.vehicles[enemy].id)
				end
				local enemyVehicle = self.vehicles[enemy]
				if (enemyVehicle ~= nil) then
					hitVehicle, distance = self:canSee(ai, enemyVehicle)
					if (hitVehicle and distance < closestDistance) then
						closestTarget = enemyVehicle
						closestDistance = distance
					end
				end
			end
		end
	end 
	--DebugWatch("Closest Target: ", enemyVehicle)
	--DebugWatch("Target Distance: ", closestDistance)
	--DebugWatch("side: ",ai.side)
	return closestTarget
end

--TODO: Call this on a timer every 0.2 seconds. Avoiding expensive raycasts optimizes performance
--TODO: Currently only calls on vehicles, could be tweaked to check generic transform (i.e. player)
function AVF_ai:canSee(ai, target)
	if (target == nil)then
		return false, 10000
	end
	local commanderPos = GetVehicleTransform(target.id)
	local ourPos = GetVehicleTransform(ai.id)
	
	if(DEBUG_AI) then 
		DebugWatch(""..target.id.." Center of mass...", GetBodyCenterOfMass(GetVehicleBody(target.id)))
	end

	ourPos.pos = TransformToParentPoint(ourPos,Vec(0,5,0))
	local targVbod = GetVehicleBody(target.id)
	
	--Try to get target's center of mass. 
	--TODO: Inconsistent, might make sense to get center of bounding box
	local w = TransformToParentPoint(commanderPos, GetBodyCenterOfMass(targVbod))
	if(DEBUG_AI) then 
		--show our sight in white, show the target to shoot in red
		DebugCross(ourPos.pos, 1, 1, 1)
		DebugCross(w, 1, 0, 0)
	end
	local fwdPos = VecSub(w,ourPos.pos)
	local dir = VecNormalize(fwdPos)

	QueryRejectVehicle(ai.id)
	--TODO: add configuration for ai sight distance
	local hit, dist,normal, shape = QueryRaycast(ourPos.pos, dir, 800)

	--DebugWatch("Shape: ", shape)
	--DebugWatch("HIT: ", hit)
	--DebugWatch("DIR:", dir)
	--DebugWatch("Targ: ", target.id)

	local hitVehicle = false
	local vBody = GetVehicleBody(target.id)
	local shapeBody = GetShapeBody(shape)
	--DebugLine(ourPos.pos,VecAdd(ourPos.pos,VecScale(dir,100)),1,1,1)
	
	--Check if we hit a vehicle
	if (GetBodyVehicle(shapeBody) == GetBodyVehicle(vBody)) then
		hitVehicle = true
	end

	--Didn't hit a vehicle, might've hit a turret/jointed piece on a vehicle
	if (hitVehicle == false)then
		local jointedBodies = GetJointedBodies(vBody)
		for i=1, #jointedBodies do
			if (jointedBodies[i]==shapeBody)then
				hitVehicle=true
			end
		end
	end

	return hitVehicle,dist
end

function AVF_ai:getNextPathTarget(ai,aiPos)
	local retPos = nil
	if (ai.behaviors.move_path) then
		local pathLength = #ai.behaviors.move_path
		if (ai.behaviors.path_recalced) then
			ai.behaviors.path_recalced = false
			ai.behaviors.last_path_index = 1
		end
		local fwd = VecSub(ai.behaviors.move_path[ai.behaviors.last_path_index],aiPos)
		if (ai.behaviors.last_path_index < pathLength) then
			if (VecSqrLength(fwd) < 10) then
				ai.behaviors.last_path_index = ai.behaviors.last_path_index + 1
			end
			retPos = ai.behaviors.move_path[ai.behaviors.last_path_index]
		end
		if(DEBUG_AI) then
			DebugWatch("Length "..ai.id, VecSqrLength(fwd))	
		end
	end
	return retPos
end

--TODO: Switch preferred range/driving state based on tank health
--TODO: Clean this up to be shorter and more reusable
function AVF_ai:combatMovement(ai)
	local targ = ai.behaviors.target
	if (targ == nil) then
		return
	end
	local ourPos = GetVehicleTransform(ai.id)
	local targetPos = GetVehicleTransform(targ.id).pos
	local vehicleBody = GetVehicleBody(ai.id)
	local vehicleVelocity = GetBodyVelocity(vehicleBody)
	local pathPos = self:getNextPathTarget(ai,VecAdd(ourPos.pos,vehicleVelocity))
	
	local directTarget = true
	
	if (pathPos) then
		directTarget = false
		targetPos = pathPos
		if(DEBUG_AI) then
			DebugWatch("Path position "..ai.id, pathPos)	
			DebugCross(pathPos,1,1,0)
		end
	end

	local fwd = VecSub(targetPos,ourPos.pos)

	if(DEBUG_AI) then 
		DebugWatch("Drive Dist: ", VecLength(fwd))
	end
	--Only move to target if we are pursue mode
	if (ai.behaviors.default_movement == 0) then
		if (ai.behaviors.los ~= true) then
			self:driveDir(ai, ourPos, fwd, 8)
		else
			self:driveDir(ai, ourPos, fwd, 15)
		end
	end
end

function AVF_ai:driveDir(ai, aiTransform, direction, tolerance)
	if (VecSqrLength(direction) > (tolerance * tolerance)) then
		local localDir = TransformToLocalVec(aiTransform,direction)
		localDir = VecNormalize(localDir)
		--ensure we're driving if we're not close enough
		if (localDir[3] < 0.4) then
			localDir[3] = -0.4
		end
		if(DEBUG_AI) then 
			DebugWatch("Drive direction: ", localDir)
		end
		DriveVehicle(ai.id, -localDir[3], -localDir[1], false)
	else
		DriveVehicle(ai.id, 0, 0, true)
	end
end

function AVF_ai:stopAim(ai)
	for key,gunGroup in pairs(ai.features.weapons) do
		for key2,gun in ipairs(gunGroup) do
			if(gun.base_turret) then 
				SetJointMotor(gun.turretJoint,0)
			end
			SetJointMotor(gun.gunJoint,0)
			gun.persistance = ai.persistance
			gun.firing = false
		end
	end			
end

function AVF_ai:weaponAiming(ai)
	local targ = ai.behaviors.target

	--target doesn't exist
	if (targ == nil)then
		return
	end

	--shooting at a teammate
	if (targ.side == ai.side) then
		ai.behaviors.target = nil
		return
	end

	local targetPos = GetVehicleTransform(targ.id)

	targetPos.pos = TransformToParentPoint(targetPos, GetBodyCenterOfMass(GetVehicleBody(targ.id)))
	local target_vel =  GetBodyVelocity(GetVehicleBody(targ.id))

	local hitVehicle, dist = self:canSee(ai,targ)

	local ourPos = GetVehicleTransform(ai.id)
	ourPos.pos = TransformToParentPoint(ourPos,Vec(0,3,0))
	local fwdPos = VecSub(targetPos.pos,ourPos.pos)
	
	if(hitVehicle or ai.behaviors.last_spotted>0) then
		if(not hitVehicle) then 
			ai.behaviors.last_spotted =  ai.behaviors.last_spotted - GetTimeStep()
			ai.behaviors.los = false
		else
			ai.behaviors.los = true
			ai.behaviors.last_spotted =  ai.behaviors.spotted_memory
		end
		if (ai.behaviors.last_spotted < 0.1) then
			ai.behaviors.los = false
			ai.behaviors.target = nil
		else
			self:gunAiming(ai,targetPos,target_vel,fwdPos)
		end
	end
	return hitVehicle
end

function AVF_ai:gunAiming(ai,targetPos,target_vel,fwdPos)
	if(DEBUG_AI) then 
		DebugWatch("Aiming at... ", targetPos)
		DebugWatch("AIM:... ", fwdPos)	
		DebugWatch("VEL:... ", target_vel)
	end

	for key,gunGroup in pairs(vehicleFeatures.weapons) do
		-- utils.printStr(#gunGroup)
			for key2,gun in ipairs(gunGroup) do

				-- vehicleFeatures.weapons[group][index].turretJoint = turretJoint
				-- vehicleFeatures.weapons[group][index].base_turret = attatchedShape


				local previouslyAimed = gun.aimed

				if(DEBUG_AI) then 
					DebugWatch("pre aim",targetPos)
				end

				local target_dist_modifier,time_to_impact = get_target_range(gun,fwdPos)
				local predicted_target_pos =  TransformCopy(targetPos)
				predicted_target_pos.pos = VecAdd(predicted_target_pos.pos,VecScale(target_vel,time_to_impact*(math.random(75,200)/100))) 
				if(gun.base_turret) then 
					self:turretRotatation(ai,gun.base_turret,gun.turretJoint,predicted_target_pos)
				end
				targetPos.pos[2] = targetPos.pos[2]+ target_dist_modifier
				if(DEBUG_AI) then
					DebugWatch("post aim",targetPos)
				end
				self:gunLaying(ai,gun,targetPos)	
				if(not gun.reloading and gun.persistance ~= nil and gun.persistance>0) then 
					-- DebugWatch("gun firing",gun.persistance)
					if(not gun.aimed and (previouslyAimed or (gun.persistance and gun.persistance>0))) then 
						gun.persistance = gun.persistance - GetTimeStep()
					end
					
				 	if(gun.persistance>0) then 
				 		self:gunFiring(gun)
				 	elseif(gun.firing) then
				 		self:gunFiring(gun)
				 		gun.firing = false
				 	end
				end


				-- test_player_damage(gun)
			end
	end			

end


function get_target_range(gun,fwdPos)
		local shellType = gun.magazines[gun.loadedMagazine].CfgAmmo
		if(DEBUG_AI) then
			DebugWatch("vel",shellType.velocity)
		end
		local time_to_impact = VecLength(fwdPos)/shellType.velocity
		if(DEBUG_AI) then
			DebugWatch("dist",VecLength(fwdPos))
			DebugWatch("tti",time_to_impact)
		end
		local target_dist_modifier = 
					math.max(
						0,
						time_to_impact
							*math.abs(globalConfig.gravity[2]*.25))
		if(shellType.gravityCoef~= nil) then 
			target_dist_modifier = target_dist_modifier * shellType.gravityCoef
		end
		if(DEBUG_AI) then
			DebugWatch("target dist modifier",target_dist_modifier)
		end
		local uncertainty = (math.random(-250,200)/100) * (VecLength(fwdPos)/100)
		target_dist_modifier = target_dist_modifier + uncertainty

		if(DEBUG_AI) then
			DebugWatch("final target dist ",target_dist_modifier) 
		end
		return target_dist_modifier,time_to_impact

end

---- must handle multiple guns
---- if gun angle up > 0 then gun goes down and vice versa, with bias to control
function AVF_ai:gunLaying(ai,gun,targetPos)
	local up = self:gunAngle(0,0,-1,gun,targetPos)
	local down = self:gunAngle(0,0,1	,gun,targetPos)
	local left = self:gunAngle(1,0,0,gun,targetPos)
	local right = self:gunAngle(-1,0,0	,gun,targetPos)
	local forward = self:gunAngle(0,-1,0	,gun,targetPos)
	local bias = 0.1
	gun.aimed = false

	local dir = 0
	if(up < down-bias*0.1)then  -- and up-bias*.5>0) then 
		dir = -1
	elseif(up > down+bias*0.2 )then  --and down-bias*.5>0) then
		dir = 1
	end
	if(left >right-bias and left<right+bias and forward-bias <0) then 

		gun.persistance = ai.persistance
		gun.aimed = true
		gun.firing = true
		

	end 

	--bias = bias * math.random(-1,1)/5
	SetJointMotor(gun.gunJoint, dir*bias)
	
end

function AVF_ai:gunFiring(gun)
	dt = GetTimeStep()
	
	local firing = false
	if(gun.persistance<=0)then
		
		if( not gun.reloading and gun.tailOffSound and gun.rapidFire)then
			local cannonLoc = GetShapeWorldTransform(gun.id)
			PlaySound(gun.tailOffSound, cannonLoc.pos, 5)
			gun.rapidFire = false
		end
	else 
		firing = true
	end

	
	if( not gun.reloading and not (IsJointBroken(gun.gunJoint)or (gun.turretJoint and IsJointBroken(gun.turretJoint))  ))then	---not IsShapeBroken(gun.id) and
		if(not gun.magazines[gun.loadedMagazine].outOfAmmo and gun.magazines[gun.loadedMagazine].magazinesAmmo[gun.magazines[gun.loadedMagazine].currentMagazine]) then
			local currentMagazine = gun.magazines[gun.loadedMagazine].magazinesAmmo[gun.magazines[gun.loadedMagazine].currentMagazine]
			if(currentMagazine.AmmoCount > 0) then  
			    if( gun.loopSoundFile)then
			    	if not gun.rapidFire then
			    		
			    		gun.rapidFire = true

			    	end
					local cannonLoc = GetShapeWorldTransform(gun.id)

					PlayLoop(gun.loopSoundFile, cannonLoc.pos, 5)
					
				end
				
				if (gun.timeToFire <=0) then
				 	if (firing) then
				 		
				 		if (gun.cycleTime < dt) then
				 			local firePerFrame =1
				 		
				 			firePerFrame = (math.floor((dt/gun.cycleTime)+0.5))
					 		for i =1, firePerFrame do 
								fireControl(dt,gun)
								
								currentMagazine.AmmoCount =currentMagazine.AmmoCount -1
								if(currentMagazine.AmmoCount <= 0) then
									break
								end
							end
							
						else
								
							fireControl(dt,gun)

							
							currentMagazine.AmmoCount =currentMagazine.AmmoCount -1

						end
						if(currentMagazine.AmmoCount <= 0) then
							reloadGun(gun)
							
							
						end
						
					end
				elseif (gun.timeToFire) then
					gun.timeToFire = gun.timeToFire - dt
				end

			end

		end
	end

end



function AVF_ai:turretRotatation(ai,turret,turretJoint,targetPos)

	if(turret)then 
		local turret = turret.id
		local forward = self:turretAngle(0,0,1,turret,targetPos)
		local left 	  = self:turretAngle(-1,0,0,turret,targetPos)
		local right   = self:turretAngle(1,0,0,turret,targetPos)

		local bias = 0.05 * ai.precision
		bias = bias * math.random(-1,1)
		if(forward<(1-bias)) then
			if(left>right+bias) then
				SetJointMotor(turretJoint, 0.1+1*left)
			elseif(right>left+bias) then
				SetJointMotor(turretJoint, -0.1+(-1*right))
			else
				SetJointMotor(turretJoint, 0)
			end
		else
			SetJointMotor(turretJoint, 0)
		end 

	end
end

function AVF_ai:turretAngle(x,y,z,turret,targetPos)

	local turretTransform = GetShapeWorldTransform(turret)
	turretTransform=GetShapeWorldTransform(vehicleFeatures.commanderPos) 
	local fwdPos = targetPos.pos
	local toPlayer = VecNormalize(VecSub(turretTransform.pos,fwdPos))
	local forward = TransformToParentVec(turretTransform, Vec(x,  y, z))
	local orientationFactor = clamp(VecDot(forward, toPlayer) * 0.7 + 0.3, 0.0, 1.0)
	
	return orientationFactor
end


function AVF_ai:gunAngle(x,y,z,gun,targetPos)

	local gunTransform = GetShapeWorldTransform(gun.id)
	 
	local fwdPos = targetPos.pos
	
	---fwdPos = {fwdPos[1],fwdPos[3],fwdPos[2]}
	local toPlayer = VecNormalize(VecSub(gunTransform.pos,fwdPos))
	local forward = TransformToParentVec(gunTransform, Vec(x,  y, z))
	local orientationFactor = clamp(VecDot(forward, toPlayer) * 0.7 + 0.3, 0.0, 1.0)
	-- DebugLine(gunTransform.pos,fwdPos,1,0,0,1)
	return orientationFactor
end