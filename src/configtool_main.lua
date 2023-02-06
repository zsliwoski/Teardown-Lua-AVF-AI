
laserSprite = LoadSprite("gfx/laser.png")
muzzleflash = LoadSprite("gfx/glare.png")
aiCurEnabled = false
aiCurDefState = 0
function configtool_init()
    RegisterTool("avfconfigtool", "AVF AI Config", "MOD/vox/avf_config.vox")
    SetBool("game.tool.avfconfigtool.enabled", true)
    shapeVoxelLimit = 1000000

    velocity = 0

	recoilTimer = 0
	driftH = 0
	driftV = 0
  
    shakex = 0
    shakey = 0
    shakez = 0

    cooldownTimer = 0 

    BeamSound = LoadLoop("MOD/snd/loop.ogg")
    PewSound = LoadSound("MOD/snd/pew.ogg")

    fireTime = 0
end

function rnd(mi, ma)
return mi + (ma-mi)*(math.random(0, 1000000)/1000000.0)
end

function GetAimPos(long)
	local ct = GetCameraTransform()
	local basedist = 100
	if long then basedist = 100 end
	local forwardPos = TransformToParentPoint(ct, Vec(0, 0, -basedist))
    local direction = VecSub(forwardPos, ct.pos)
    local distance = VecLength(direction)
	local direction = VecNormalize(direction)
	local hit, hitDistance = QueryRaycast(ct.pos, direction, distance)
	if hit then
		forwardPos = TransformToParentPoint(ct, Vec(0, 0, -hitDistance))
		distance = hitDistance
	end
	return forwardPos, hit, distance
end

function update(dt)
	if GetString("game.player.tool") == "avfconfigtool" then
		if cooldownTimer > 0 then
			cooldownTimer = cooldownTimer - dt
		end
	end
end

function laserBeam()
	local ct = GetCameraTransform()
	aimpos, hit, distance = GetAimPos()

	local direction = VecSub(aimpos, origin)
	local origin = TransformToParentPoint(ct, Vec(0.3, -1.0, -0.4))
	local lasertrans = Transform(origin,QuatLookAt(origin,aimpos))
	lasertrans.rot = QuatRotateQuat(lasertrans.rot,QuatEuler(driftV,driftH,0))
	local laserdir = TransformToParentVec(lasertrans,Vec(0,0,-1))
	local driftH = driftH + rndFloat(-1,1.2)*1
	local driftV = driftV + rndFloat(-1.4,1.6)*1
	local lp = TransformToParentPoint(ct, Vec(0.3, 0, -1.4))
	
	QueryRequire("physical")
	laserpos = TransformToParentPoint(lasertrans,Vec(0,0,-100))
	local laserhit, laserdist, shape = QueryRaycast(origin,laserdir,100)
	if laserhit then
		laserpos = TransformToParentPoint(lasertrans,Vec(0,0,-laserdist))
	end

	PointLight(laserpos,1,0.5,0.1, 10)
	PlayLoop(BeamSound,origin,3) 

	--laser sprite
        local origin = TransformToParentPoint(ct, Vec(0.82, -0.55, -2.45))
	local t = Transform(VecLerp(origin,laserpos,0.5))
	local xAx = VecNormalize(VecSub(laserpos, origin))
	local zAx = VecNormalize(VecSub(origin, GetCameraTransform().pos))
	t.rot = QuatAlignXZ(xAx, zAx)
	local dist = VecDist(origin,laserpos)
	DrawSprite(laserSprite, t, dist, 0.1+math.random()*0.07, 8, 6, 4, 1, true, true)
	DrawSprite(laserSprite, t, dist, 0.5, 1.0, 0.6, 0.2, 1, true, true)
	
         --holed body
	
	QueryRequire("physical") --dynamic optional
	local mi = VecAdd(laserpos,Vec(-4,-4,-4))
	local ma = VecAdd(laserpos,Vec(4,4,4))
	local bodies = QueryAabbBodies(mi, ma)	
	--loop through bodies
	for i,body in ipairs(bodies) do
		--compute body center and dist
		local bmi,bma = GetBodyBounds(body)
		local bc = VecLerp(bmi,bma,0.5) --get center
		local dir = VecSub(bc, laserpos)
		local dist = VecLength(dir)
		dir = VecScale(dir,1/dist)
		local mass = GetBodyMass(body)--get mass
		
		--dir forward
		dir = VecLerp(dir,TransformToParentVec(lasertrans,Vec(0,0,-100)),0.8)
		dir = VecNormalize(dir)
		
		local massScale = 1 - math.min(mass/(170),1)
		local distScale = 1 - math.min(dist/(4),1)^(1/3)
		local force = math.min(8*mass,4500)*distScale
		local add = VecScale(dir,force)
		
	end

	--glare sprite
	local rnd = math.random()*3/4+1
	DrawSprite(muzzleflash,{pos=origin,rot=GetCameraTransform().rot},4.3*rnd,4.3*rnd,1,0.6,0.3,1,0.3,1,0.1,false,true)
end

function rndFloat(mi, ma)
	return mi + (ma-mi)*(math.random(0, 1000000)/1000000.0)
end

function VecDist(a,b)
	return VecLength(VecSub(a,b))
end

function random(min, max)
	return math.random() * (max - min) + min
end

function randomVec(t)
	return Vec(random(-t, t), random(-t, t), random(-t, t))
end 

function configtool_tick(dt)
    if GetString("game.player.tool") == "avfconfigtool" and GetPlayerVehicle() == 0 then
		if InputPressed("rmb") then
			laserBeam()
			SetTeam(1)
          	PlaySound(PewSound,GetCameraTransform().pos, 1.5)
        end
		if InputPressed("lmb") then
			laserBeam()
			SetTeam(0)
			PlaySound(PewSound,GetCameraTransform().pos, 1.5)
		end
		if InputPressed("q") then
			aiCurEnabled = not aiCurEnabled
			SetBool("level.avf.aienabled", aiCurEnabled)
		end

		if InputPressed("z") then
			--TODO: change this logic to cycle to Patrol state
			if (aiCurDefState == 1) then
				aiCurDefState = 0
			else
				aiCurDefState = 1
			end
		end

		GetTeam()

		local t = Transform()
		t.pos = Vec(0.3+shakex, -1.0+shakey, -0.40+shakez) --change the last three values to change vhere bullets originate left/right, up/down, forward,back
		t.rot = QuatEuler(-3, 0, 0)
		SetToolTransform(t)
    end
end

function GetVehicleFromCenter()
	local cam = GetPlayerCameraTransform()
	local dir = TransformToParentVec(cam, Vec(0, 0, -1))
	local hit, dist, norm, sh = QueryRaycast(cam.pos, dir, 50)
	local bod = GetShapeBody(sh)
	local hitVehicle = GetBodyVehicle(bod)
	return hitVehicle, hit, dist, bod
end

function GetTeam()
	local hitVeh, hit, dist, bodyH = GetVehicleFromCenter()
	if (hitVeh ~= nil and hitVeh ~= 0) then	
		local isAI = HasTag(bodyH,"avf_ai")
		--DebugWatch(""..bodyH.."", isAI)	
		if (isAI) then
			local ret = tonumber(GetTagValue(bodyH, "avf_ai"))
			DrawBodyHighlight(bodyH,0.1)
			if (ret == 0) then
				DrawBodyOutline(bodyH,1,0,0,0.5)
			elseif (ret == 1) then
				DrawBodyOutline(bodyH,0,0,1,0.5)
			elseif (ret == 2) then
				DrawBodyOutline(bodyH,0,1,0,0.5)
			end
		else
			DrawBodyHighlight(bodyH,0.3)
		end
	end
end

--TODO: CHANGE THIS TO APPLY ALL AI PARAMS
function SetTeam(side)
	local hitVeh, hit, dist, bodyHandle = GetVehicleFromCenter()
	if (hitVeh ~= nil) then		
		local sideID = side
		SetTag(bodyHandle, "avf_ai", ""..sideID.."")
		local ret = GetTagValue(bodyHandle, "avf_ai")
		SetInt("level.avf.newid", bodyHandle)
		SetInt("level.avf.newside", sideID)
		SetInt("level.avf.newmovemode", aiCurDefState) --TODO make this an argument
		SetBool("level.avf.aichanged", true)
	end
end
function configtool_draw()

	if GetString("game.player.tool") == "avfconfigtool" and GetPlayerVehicle() == 0 then
		UiPush()
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle());
			UiImage("circle/crosshair-dot.png")
		UiPop()
		UiPush()
			UiAlign("center")
			UiTranslate(UiCenter(), UiHeight()-80)
			UiFont("regular.ttf", 30)
			UiText("LMB - OPFOR || RMB - BLUFOR", true)
		UiPop()
		UiPush()
			UiAlign("left")
			UiAlign("top")
			UiTranslate(40, 40)
			local aiEnableText = ""
			if (aiCurEnabled) then
				aiEnableText = "ENABLED"
				UiTextOutline(0, 1, 0, 1, 0.2)
			else
				aiEnableText = "DISABLED"
				UiTextOutline(1, 0, 0, 1, 0.2)
			end
			UiFont("regular.ttf", 30)
			UiText("Q - Enable AI : "..aiEnableText,true)
			UiTextOutline(0, 0, 0, 0, 0)

			local aiDefaultBehaviorText = ""
			if (aiCurDefState == 0) then
				aiDefaultBehaviorText = "PURSUE"
			elseif (aiCurDefState == 1) then
				aiDefaultBehaviorText = "GUARD"
			end
			UiText("Z - Target Movement Behavior : "..aiDefaultBehaviorText,true)
		UiPop()
    end

	
end