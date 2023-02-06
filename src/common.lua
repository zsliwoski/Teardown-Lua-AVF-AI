


function clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end




function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

utils = {

	contains = function(set,key)
		return set[key] ~= nil
		-- body
	end,

-- catchBadPos = function (x)
-- 	if(x.x)
-- end,

 getLoc = function(x )
	return	"X "..
	x[1]..
	"\nY"..
	x[2]..
	"\nZ"..
	x[3]
	-- body
end,

randomFloat = function (lower, greater)
    return lower + math.random()  * (greater - lower);
end,

printRot = function(x)

	SetString("hud.notification",
	"X "..
	x[2]..
	"\nY"..
	x[3]..
	"\nZ"..
	x[4]
	) -- this prints the rotation top center of the screen  

end, 

printStr = function (x)
	SetString("hud.notification",x)
end,

explodeTable = function(x)
	local testString = ""
	for key,value in pairs(x) do
		testString = testString..key.." | "..value.."\n"
	end
	return testString
end,

sign = function(x)
   if x<0 then
     return -1
   elseif x>0 then
     return 1
   else
     return 0
   end
end

}

function VecSqrLength (a)
	return (a[1] * a[1]) + (a[3] * a[3])
end

function queue()
	local out = {}
	local first, last = 0, -1
	out.push = function(item)
	  last = last + 1
	  out[last] = item
	end

	out.peakFirst = function()
		local value = out[first]
		return value
	end
	out.peakLast = function()
		local value = out[last]
		return value
	end
	
	out.pop = function()
	  if first <= last then
		local value = out[first]
		out[first] = nil
		first = first + 1
		return value
	  end
	end
	out.iterator = function()
	  return function()
		return out.pop()
	  end
	end
	setmetatable(out, {
	  __len = function()
		return (last-first+1)
	  end,
	})
	return out
  end
