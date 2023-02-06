armedVehicleControls = {
	fire 				= "lmb",
	sniperMode 			= "rmb",
	changeWeapons		= "r",
	changeTurretGroup	= "t",
	changeAmmunition	= "f",
	deploySmoke			= "g",
	toggle_Searchlight =  "l",
	deployExtinguisher = "q",
}

armedVehicleControlsOrder = {
	[1] 			="fire",
	[2] 			= "sniperMode",
	[3] 			= "changeWeapons",
	[4]				= "changeAmmunition",
	[5]				= "deploySmoke",
	[6]			="toggle_Searchlight",
	[7]				= "deployExtinguisher"
}

armedVehicleControls_arty = {
	fire 				= "lmb",
	Arty_cam 			= "rmb",
	left	= "a",
	right	= "d",
	up			= "w",
	down  =  "s",
}

armedVehicleControlsOrder_arty = {
	[1] 			="fire",
	[2] 			= "Arty_cam",
	[3] 			= "left",
	[4]				= "right",
	[5]				= "up",
	[6]			="down",
}




function loadCustomControls()
	for key, value in pairs(armedVehicleControls) do 
		
		if GetString("savegame.mod.controls."..key)~="" then
			armedVehicleControls[key] =  GetString("savegame.mod.controls."..key)
		end
	end

end