ESX = exports["es_extended"]:getSharedObject()

local garageEntrances = {}  -- Tableau pour stocker les coordonnées des entrées de garage
local garageExits = {} -- Tableau pour stocker les coordonnées de sortie de garage

-- Récupération des coordonnées des entrées de garage au démarrage du script
ESX.TriggerServerCallback('dpr_core:getGarageEntranceCoords', function(coords)
    garageEntrances = coords
end)

-- Récupération des coordonnées de sorties de garage au démarrage du script
ESX.TriggerServerCallback('dpr_core:getGarageExitCoords', function(coords)
    garageExits = coords
end)

function SpawnVehicle(vehicle, plate)
    x,y,z = table.unpack(GetEntityCoords(GetPlayerPed(-1),true))

	ESX.Game.SpawnVehicle(vehicle.model, {
		x = x,
		y = y,
		z = z 
	}, GetEntityHeading(PlayerPedId()), function(callback_vehicle)
		ESX.Game.SetVehicleProperties(callback_vehicle, vehicle)
		SetVehRadioStation(callback_vehicle, "OFF")
		SetVehicleFixed(callback_vehicle)
		SetVehicleDeformationFixed(callback_vehicle)
		SetVehicleUndriveable(callback_vehicle, false)
		SetVehicleEngineOn(callback_vehicle, true, true)
		--SetVehicleEngineHealth(callback_vehicle, 0) -- Might not be needed
		--SetVehicleBodyHealth(callback_vehicle, 0) -- Might not be needed
		TaskWarpPedIntoVehicle(GetPlayerPed(-1), callback_vehicle, -1)
	end)
	TriggerServerEvent('dpr_core:breakVehicleSpawn', plate, false)
end

function ReturnVehicle()
	local playerPed  = GetPlayerPed(-1)
	if IsPedInAnyVehicle(playerPed,  false) then
		local playerPed    = GetPlayerPed(-1)
		local coords       = GetEntityCoords(playerPed)
		local vehicle      = GetVehiclePedIsIn(playerPed, false)
		local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
		local current 	   = GetPlayersLastVehicle(GetPlayerPed(-1), true)
		local engineHealth = GetVehicleEngineHealth(current)
		local plate        = vehicleProps.plate

		ESX.TriggerServerCallback('dpr_core:returnVehicle', function(valid)
			if valid then
                BreakReturnVehicle(vehicle, vehicleProps)
			else
				ESX.ShowNotification('Tu ne peux pas garer ce véhicule')
			end
		end, vehicleProps)
	else
		ESX.ShowNotification('Il n`y a pas de véhicule à ranger dans le garage.')
	end
end

function BreakReturnVehicle(vehicle, vehicleProps)
	ESX.Game.DeleteVehicle(vehicle)
	TriggerServerEvent('dpr_core:breakVehicleSpawn', vehicleProps.plate, true)
	ESX.ShowNotification("Tu viens de ranger ton ~r~véhicule ~s~!")
end

--Garage
CreateThread(function()
    while true do
		local wait = 750

			for k in pairs(garageEntrances) do
			local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
			local pos = garageEntrances
			local dist = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, pos[k].x, pos[k].y, pos[k].z)

			if dist <= Config.MarkerDistance then
				wait = 1
				DrawMarker(Config.MarkerType, pos[k].x, pos[k].y, pos[k].z, 0.0, 0.0, 0.0, 0.0,0.0,0.0, Config.MarkerSizeLargeur, Config.MarkerSizeEpaisseur, Config.MarkerSizeHauteur, 3, 252, 65, Config.MarkerOpacite, Config.MarkerSaute, true, p19, Config.MarkerTourne)  

				if dist <= 2.0 then
				wait = 1
					Visual.Subtitle(Config.TextGarage, 1) 
					if IsControlJustPressed(1,51) then
						ESX.TriggerServerCallback('dpr_core:vehiclelist', function(ownedCars)
                            Garage.vehiclelist = ownedCars
                        end)
						OpenMenuGarage()
					end
				end
			end
    	end
	Wait(wait)
	end
end)



-- Fourrière 
Citizen.CreateThread(function()
    while true do
		local wait = 750

			for k in pairs(Config.Positions.Pound) do
			local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
			local pos = Config.Positions.Pound
			local dist = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, pos[k].x, pos[k].y, pos[k].z)

			if dist <= Config.MarkerDistance then
				wait = 0
				DrawMarker(Config.MarkerType, pos[k].x, pos[k].y, pos[k].z, 0.0, 0.0, 0.0, 0.0,0.0,0.0, Config.MarkerSizeLargeur, Config.MarkerSizeEpaisseur, Config.MarkerSizeHauteur, 252, 157, 3, Config.MarkerOpacite, Config.MarkerSaute, true, p19, Config.MarkerTourne)  

				if dist <= 2.0 then
				wait = 0
					Visual.Subtitle(Config.TextPound, 1) 
					if IsControlJustPressed(1,51) then
						ESX.TriggerServerCallback('dpr_core:vehiclelistfourriere', function(ownedCars)
                            Pound.poundlist = ownedCars
                        end)
						OpenMenuPound()
					end
				end
			end
    	end
	Wait(wait)
	end
end)

-- Ranger 
Citizen.CreateThread(function()
    while true do
		local wait = 750

			for k in pairs(garageExits) do
			local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
			local pos = garageExits
			local dist = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, pos[k].x, pos[k].y, pos[k].z)

			if dist <= Config.MarkerDistance then
                wait = 1
                DrawMarker(Config.MarkerType, pos[k].x, pos[k].y, pos[k].z, 0.0, 0.0, 0.0, 0.0,0.0,0.0, Config.MarkerSizeLargeur, Config.MarkerSizeEpaisseur, Config.MarkerSizeHauteur, 252, 3, 3, Config.MarkerOpacite, Config.MarkerSaute, true, p19, Config.MarkerTourne)  

				if dist <= 2.0 then
				wait = 1
					Visual.Subtitle(Config.TextReturn, 1) 
					if IsControlJustPressed(1,51) then
						ReturnVehicle()
					end
				end
			end
    	end
	Wait(wait)
	end
end)


Citizen.CreateThread(function()
    if Config.Blip then
        for k, v in pairs(Config.Positions.Garage) do
            local blip = AddBlipForCoord(v.x, v.y, v.z)

            SetBlipSprite(blip, 473)
            SetBlipScale (blip, 0.7)
            SetBlipColour(blip, 2)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Garage')
            EndTextCommandSetBlipName(blip)
        end

		for k, v in pairs(Config.Positions.Pound) do
            local blip = AddBlipForCoord(v.x, v.y, v.z)

            SetBlipSprite(blip, 477)
            SetBlipScale (blip, 0.7)
            SetBlipColour(blip, 9)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Fourrière')
            EndTextCommandSetBlipName(blip)
        end
    end
end)