#include "common.lua"
--This is the maximum time in seconds before aborting a path query
--Increasing this will handle more complex scenarios
MAX_THINK_TIME = 3

#TODO: more generic implementation of waiting

PATH_DEBUG = false
lastPath = {}
waitingAI = queue()
recalc = false
waitingCount = 0
curAI = nil
startBody = nil
endBody = nil

function queuePath(ai)
	waitingCount = waitingCount + 1
	waitingAI.push(ai)
	local ret = waitingAI.peakFirst()
	if (PATH_DEBUG) then
		DebugWatch("Waiting:", waitingCount)
		DebugPrint(waitingCount)
	end
end

function dequeuePath()
	waitingCount = waitingCount - 1
	return waitingAI.pop()
end

--This function retrieves the most recent path and stores it in lastPath
function retrievePath(ref)
	lastPath = {}
	local length=GetPathLength()
	local l=0
	while l < length do
		lastPath[#lastPath+1] = GetPathPoint(l)
		l = l + 0.2
	end
end


--This function will draw the content of lastPath as a line
function drawMovementPath(pathPoints)
	if (pathPoints) then
		if (PATH_DEBUG) then
			DebugWatch("All points", #pathPoints)
		end
		for i=1, #pathPoints-1 do
			DrawLine(pathPoints[i], pathPoints[i+1])
		end
	end
end

function getPathParams()
	curAI = waitingAI.peakFirst()
	if (curAI) then
		startBody =  GetVehicleBody(curAI.id)
		goalBody = 	GetVehicleBody(curAI.behaviors.target.id)
		if (PATH_DEBUG)then
			DebugWatch("Watching", curAI.id)
			DebugPrint(startBody)
			DebugPrint(goalBody)
		end
		recalc = true
		retrievePath()
	else
		if (curAI) then
			if (PATH_DEBUG)then
				DebugPrint("Next up:"..curAI.id)
			end
		end
	end
end

function pathTick(dt)	
	recalc = false
	local state = GetPathState()
	--DebugWatch("pathfinding:", state)
	
	if state == "idle" then
		getPathParams()
	elseif state == "done" then
		--Path finding system has completed a path query
		--Store the result and start a new query.
		if (curAI) then
			if (PATH_DEBUG)then
				DebugWatch("Served: ", curAI.id)
			end
			retrievePath(curAI.behaviors.move_path)
			curAI.behaviors.move_path = deepcopy(lastPath)
			curAI.behaviors.path_recalced = true
			curAI = nil
			startBody = nil
			goalBody = nil
			dequeuePath()
		end
		getPathParams()
		recalc = true
		failed = false
	elseif state == "fail" then
		--Path finding system has failed to find a valid path
		--It is still possible to retrieve a result (path to closest point found)
		--Store the result and start a new query.
		if (curAI) then
			if (PATH_DEBUG)then
				DebugWatch("Path Failed: ", curAI.id)
			end
			--curAI.behaviors.move_path = deepcopy(lastPath)
			curAI = nil
			startBody = nil
			goalBody = nil
			dequeuePath()
		end
		AbortPath()
		getPathParams()
		failed = true
	else
		--Path finding system is currently busy. If it has been thinking for more than the 
		--allowed time, abort current query and store the best result
		thinkTime = thinkTime + dt
		if thinkTime > MAX_THINK_TIME then
			AbortPath()
			recalc = true
			failed = true
			retrievePath(curAI.behaviors.move_path)
		end
	end

	if recalc then
		--Compute path from startPos to goalPos but exclude startBody and goalBody from the query.
		--Set the maximum path length to 100 and let any point within 0.5 meters to the goal point
		--count as a valid path.
		local startPos = GetBodyTransform(startBody).pos
		local goalPos = GetBodyTransform(goalBody).pos
		if (PATH_DEBUG)then
			DebugWatch("StartPos", startPos)
			DebugCross(startPos,1,1,0)
			DebugWatch("GoalPos", goalPos)
			DebugCross(goalPos,0,1,1)
		end
		QueryRejectBody(startBody)
		QueryRejectBody(goalBody)
		QueryPath(startPos, goalPos, 50, 4)
		thinkTime = 0
	end

	--Draw last computed path and a red cross at the end of it in case it didn't reach the goal.
	if failed then
		if (PATH_DEBUG)then
			DebugCross(lastPath[#lastPath], 1, 0, 0)
			DebugWatch("Failed",lastPath[#lastPath])
		end
	end
end



