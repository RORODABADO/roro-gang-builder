ESX = nil
local playerGang = nil
local factionChests = {}

Citizen.CreateThread(function()
    while ESX == nil do
        ESX = exports["es_extended"]:getSharedObject()
        Citizen.Wait(0)
    end

    if ESX.IsPlayerLoaded() then

		ESX.PlayerData = ESX.GetPlayerData()

    end

    ESX.TriggerServerCallback('gangbuilder:getPlayerGang', function(gang)
        playerGang = gang
    end)

    ESX.TriggerServerCallback('gangbuilder:getFactionChests', function(chests)
        factionChests = chests
    end)


end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setFaction', function(faction)
    ESX.PlayerData.faction = faction
end)



-- Register the boss menu
lib.registerMenu({
    id = 'gang_menu',
    title = 'Gang Menu',
    position = 'top-right',
    options = {
        {label = 'Dépôt d\'argent propre', description = 'Déposer de l\'argent propre dans le coffre du gang'},
        {label = 'Retrait d\'argent propre', description = 'Retirer de l\'argent propre du coffre du gang'},
        {label = 'Dépôt d\'argent sale', description = 'Déposer de l\'argent sale dans le coffre du gang'},
        {label = 'Retrait d\'argent sale', description = 'Retirer de l\'argent sale du coffre du gang'},
        {label = 'Coffre', description = 'Déposer/Récuper des objets'},
        --{label = 'Gestion du Gang', description = 'Gestion du Gang'}
    }
}, function(selected)
    if selected == 1 then
        if ESX.PlayerData.faction.grade_name == 'boss' then 
            OpenDepositMoneyMenu('society')
        else 
            exports['okokNotify']:Alert("Gang Menu", "Vous devez être le chef du gang pour effectuer cette action", 5000, 'error')
        end

    elseif selected == 2 then
        if ESX.PlayerData.faction.grade_name == 'boss' then 
            OpenWithdrawMoneyMenu('society')
        else 
            exports['okokNotify']:Alert("Gang Menu", "Vous devez être le chef du gang pour effectuer cette action", 5000, 'error')
        end

    elseif selected == 3 then
        if ESX.PlayerData.faction.grade_name == 'boss' then 
            OpenDepositMoneyMenu('society_black')
        else 
            exports['okokNotify']:Alert("Gang Menu", "Vous devez être le chef du gang pour effectuer cette action", 5000, 'error')
        end

    elseif selected == 4 then
        if ESX.PlayerData.faction.grade_name == 'boss' then 
            OpenWithdrawMoneyMenu('society_black')
        else 
            exports['okokNotify']:Alert("Gang Menu", "Vous devez être le chef du gang pour effectuer cette action", 5000, 'error')
        end

    elseif selected == 5 then
        if ESX.PlayerData.faction.name then
            --exports.ox_inventory:openInventory('stash', 'society_' .. ESX.PlayerData.faction.name)
            exports.ox_inventory:openInventory('stash', ESX.PlayerData.faction.name)
        else
            exports['okokNotify']:Alert("Gang Menu", "Vous n'êtes pas dans un gang.", 5000, 'error')
        end

    -- elseif selected == 6 then 
    --     if ESX.PlayerData.faction.name then
    --         if ESX.PlayerData.faction.grade_name == 'boss' then
    --         -- TriggerEvent('esx_society:openBossMenu', playerGang, function (menu)
    --         -- end, {wash = false})
    --         else 
    --             exports['okokNotify']:Alert("Gang Menu", "Vous devez être le chef du gang pour effectuer cette action", 5000, 'error')
    --         end 
    --     else 
    --         exports['okokNotify']:Alert("Gang Menu", "Vous n'êtes pas dans un gang.", 5000, 'error')
    --     end

    
    end
end)


local shown = false
local inDistance = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closestChestDistance = nil

        for _, chest in pairs(factionChests) do
            local chestCoords = json.decode(chest.coords)
            local distance = Vdist(playerCoords, chestCoords.x, chestCoords.y, chestCoords.z)

            if closestChestDistance == nil or distance < closestChestDistance then
                closestChestDistance = distance
            end

            if distance < 10.0 then
                DrawMarker(Config.MarkerTypeCoffre, chestCoords.x, chestCoords.y, chestCoords.z, 0.0, 0.0, 0.0, 0.0,0.0,0.0, Config.MarkerSizeLargeurCoffre, Config.MarkerSizeEpaisseurCoffre, Config.MarkerSizeHauteurCoffre, 204, 0, 0, Config.MarkerOpaciteCoffre, Config.MarkerSauteCoffre, true, p19, Config.MarkerTourneCoffre)  

                if distance < 1.5 then

                    if IsControlJustReleased(0, 38) then -- 38 is E key
                        if ESX.PlayerData.faction.name and ESX.PlayerData.faction.name == chest.faction_name then
                            lib.showMenu('gang_menu')
                            
                            --UpdateAccountBalances()
                        else
                            --ESX.ShowNotification('You cannot access this chest.')
                            exports['okokNotify']:Alert("Gang", "Vous ne pouvez pas accéder à ce coffre.", 5000, 'error')
                        end
                    end
                end
            end
        end

        if closestChestDistance then
            inDistance = closestChestDistance <= 1.5
        else
            inDistance = false
        end

        if not shown and inDistance then
            exports['okokTextUI']:Open('[E] Ouvrir le coffre du gang', 'darkred', 'right', true)
            shown = true
        elseif shown and not inDistance then
            exports['okokTextUI']:Close()
            shown = false
        end
    end
end)


RegisterCommand('creategang', function()
    ESX.TriggerServerCallback('gangbuilder:getPlayerGroup', function(group)
        if group == 'superadmin' or group == 'admin' or group == 'mod' then
            OpenGangMenu()
        else
            --ESX.ShowNotification('Vous n'avez pas le droit d'accéder à ce menu.')
            exports['okokNotify']:Alert("Gang", "Vous n'avez pas le droit d'accéder à ce menu.", 5000, 'error')
        end
    end)
end, false)

function OpenGangMenu()
    local name = ''
    local label = ''
    local startmoney = ''
    local startdirtymoney = ''
    local slotscoffre = ''
    local poidcoffre = ''
    local grades = {}
    local coords = {}
    local garageEntryCoords = nil
    local garageExitCoords = nil

    local input = lib.inputDialog('Gang Informations', {
        { type = 'input', label = 'Entrer le Nom du Gang (en minuscule)', icon = 'pen', required = true },
        { type = 'input', label = 'Entrer le Label du Gang (première lettre en majuscule)', icon = 'pen', required = true },
        { type = 'number', label = 'Argent de départ', icon = 'dollar-sign', description = 'Minimum 10 $', required = true, min = 10, max = 100000 },
        { type = 'number', label = 'Argent Sale de départ', icon = 'dollar-sign', description = 'Minimum 10 $', required = true, min = 10, max = 100000 },
        { type = 'number', label = 'Nombre de slots dans le coffre', icon = 'pen', description = 'Minimum 50', required = true, min = 50, max = 100 },
        { type = 'number', label = 'Poids max du coffre', icon = 'pen', description = 'Minimum 200 KG', required = true, min = 200, max = 1000 }
    })

    if not input or #input < 4 then
        exports['okokNotify']:Alert("Gang", "Entrée non valide. Opération annulée.", 5000, 'error')
        return
    end

    name = input[1]
    label = input[2]
    startmoney = tonumber(input[3])
    startdirtymoney = tonumber(input[4])
    slotscoffre = tonumber(input[5])
    poidcoffre = tonumber(input[6]) * 1000

    AddGrade(name, grades, function()
        exports['okokTextUI']:Open('[Entrer] Pour confirmer les coordonnées du coffre du gang', 'darkred', 'right', true)

        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(0)
                if IsControlJustReleased(0, 191) then -- 191 is the Enter key
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z}
                    exports['okokTextUI']:Close()

                    exports['okokNotify']:Alert("Gang", "Coordonnées du coffre définies. Maintenant, définissez les coordonnées d'entrée du garage.", 5000, 'info')
                    
                    -- Set garage entry coordinates
                    exports['okokTextUI']:Open('[Entrer] Pour confirmer les coordonnées d\'entrer du garage', 'darkred', 'right', true)
                    while true do
                        Citizen.Wait(0)
                        if IsControlJustReleased(0, 191) then -- 191 is the Enter key
                            playerCoords = GetEntityCoords(playerPed)
                            garageEntryCoords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z}
                            exports['okokTextUI']:Close()
                            exports['okokNotify']:Alert("Gang", "Coordonnées d'entrée du garage définies. Maintenant, définissez les coordonnées de sortie du garage.", 5000, 'info')
                            break
                        end
                    end

                    -- Set garage exit coordinates
                    exports['okokTextUI']:Open('[Entrer] Pour confirmer les coordonnées de sortie du garage', 'darkred', 'right', true)
                    while true do
                        Citizen.Wait(0)
                        if IsControlJustReleased(0, 191) then -- 191 is the Enter key
                            playerCoords = GetEntityCoords(playerPed)
                            garageExitCoords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z}
                            exports['okokTextUI']:Close()
                            exports['okokNotify']:Alert("Gang", "Coordonnées de sortie du garage définies. Création du gang en cours...", 5000, 'info')
                            break
                        end
                    end

                    TriggerServerEvent('gangbuilder:createGang', name, label, grades, coords, startmoney, startdirtymoney, garageEntryCoords, garageExitCoords, slotscoffre, poidcoffre)
                    break
                end
            end
        end)
    end)
end

function AddGrade(gangName, grades, cb)
    local grade = {
        name = '',
        label = '',
        salary = 0,
        skin_male = {},
        skin_female = {}
    }

    local input = lib.inputDialog('Grade Information', {
        { type = 'input', label = 'Saisir le nom du grade en minuscule (ou taper « done » pour terminer)', description = 'Le dernier grade créer doit être "boss" !!!', icon = 'pen' },
        { type = 'input', label = 'Saisir le Label grade (première lettre en majuscule)', icon = 'pen' }, 
        { type = 'number', label = 'Saisir le salaire du Grade', icon = 'dollar-sign', description = 'Minimum 1 $', min = 1, max = 100000 }
    })

    if not input or #input < 0 then
        --ESX.ShowNotification('Invalid input. Operation cancelled.')
        exports['okokNotify']:Alert("Gang", "Entrée non valide. Opération annulée.", 5000, 'error')
        return
    end

    if input[1] == 'done' then
        cb()
        return
    end

    grade.name = input[1]
    grade.label = input[2]
    grade.salary = tonumber(input[3])

    if not grade.salary then
        --ESX.ShowNotification('Invalid salary. Operation cancelled.')
        exports['okokNotify']:Alert("Gang", "Salaire non valide. Opération annulée.", 5000, 'error')
        return
    end

    -- For simplicity, we'll skip the skin input process. In a real scenario, you could add additional dialogs to input JSON data for skin_male and skin_female.
    table.insert(grades, grade)
    AddGrade(gangName, grades, cb)
end


local factions = {}

RegisterCommand('deletegang', function()
    ESX.TriggerServerCallback('gangbuilder:getPlayerGroup', function(group)
        if group == 'superadmin' or group == 'admin' or group == 'mod' then
            ESX.TriggerServerCallback('gangbuilder:getAllFaction', function(result)
                factions = result
                OpenDeleteGangMenu()
            end)
        else
            --ESX.ShowNotification('You do not have permission to access this menu.')
            exports['okokNotify']:Alert("Gang", "Vous n'avez pas le droit d'accéder à ce menu.", 5000, 'error')
        end
    end)
end, false)

function OpenDeleteGangMenu()
    local factionOptions = {}
    for i=1, #factions, 1 do
        table.insert(factionOptions, { value = factions[i].name, label = factions[i].label })
    end

    local input = lib.inputDialog('Supprimer un Gang', {
        {
            type = 'select',
            label = 'Sélectionner un Gang à supprimer',
            options = factionOptions,
            required = true,
            placeholder = 'Choisir un gang'
        }
    })

    if not input or not input[1] then
        --ESX.ShowNotification('Invalid input. Operation cancelled.')
        exports['okokNotify']:Alert("Gang", "Entrée non valide. Opération annulée.", 5000, 'error')
        return
    end

    local selectedName = input[1]

    local confirmInput = lib.inputDialog('Confirmer la suppression', {
        {
            type = 'select',
            label = 'Êtes-vous sûr de vouloir supprimer le Gang: ' .. selectedName .. ' ? (Les joueurs qui sont dans le gang passeront en "nofaction")',
            options = {
                { value = 'yes', label = 'Oui' },
                { value = 'No', label = 'Non' }
            },
            required = true,
            placeholder = 'Choisir une option'
        }
    })

    if not confirmInput or not confirmInput[1] then
        --ESX.ShowNotification('Invalid input. Operation cancelled.')
        exports['okokNotify']:Alert("Gang", "Entrée non valide. Opération annulée.", 5000, 'error')
        return
    end

    if confirmInput[1] == 'yes' then
        TriggerServerEvent('gangbuilder:deleteFaction', selectedName)
    else
        --ESX.ShowNotification('Operation cancelled.')
        exports['okokNotify']:Alert("Gang", "Opération annulée.", 5000, 'error')
    end
end


-- Function to open the deposit money menu
function OpenDepositMoneyMenu(accountgang)
    local inputLabel = accountgang == 'society' and 'Dépôt d\'argent propre' or 'Dépôt d\'argent sale'
    local input = lib.inputDialog(inputLabel, {
        {label = 'Montant :', type = 'number', placeholder = 'Amount'}
    })

    if input and tonumber(input[1]) > 0 then
        TriggerServerEvent('gangbuilder:depositMoney', accountgang, tonumber(input[1]))
    end
end

-- Function to open the withdraw money menu
function OpenWithdrawMoneyMenu(accountgang)
    local inputLabel = accountgang == 'society' and 'Retrait d\'argent propre' or 'Retrait d\'argent sale'
    local input = lib.inputDialog(inputLabel, {
        {label = 'Montant :', type = 'number', placeholder = 'Amount'}
    })

    if input and tonumber(input[1]) > 0 then
        TriggerServerEvent('gangbuilder:withdrawMoney', accountgang, tonumber(input[1]))
    end
end


-----------FONCTION GARAGE-----------------
function SetGarageEntryCoords()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    garageEntryCoords = {x = coords.x, y = coords.y, z = coords.z}
    exports['okokNotify']:Alert("Garage", "Coordonnées d'entrée du garage définies.", 5000, 'info')
end

function SetGarageExitCoords()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    garageExitCoords = {x = coords.x, y = coords.y, z = coords.z}
    exports['okokNotify']:Alert("Garage", "Coordonnées de sortie du garage définies.", 5000, 'info')
end

function SaveGarageCoords()
    if garageEntryCoords and garageExitCoords then
        TriggerServerEvent('gangbuilder:saveGarageCoords', playerGang, garageEntryCoords, garageExitCoords)
    else
        exports['okokNotify']:Alert("Garage", "Veuillez définir les coordonnées d'entrée et de sortie du garage avant de les enregistrer.", 5000, 'error')
    end
end






