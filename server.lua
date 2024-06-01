ESX = exports["es_extended"]:getSharedObject()
local ox_inventory = exports.ox_inventory

local function registerSociety(name, label)
    TriggerEvent('esx_society:registerSociety', name, label, 'society_' .. name, 'society_' .. name, 'society_' .. name, {type = 'private'})
end

-- Event handler to register all societies at server start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        MySQL.Async.fetchAll('SELECT name, label FROM factions', {}, function(factions)
            for _, faction in ipairs(factions) do
                registerSociety(faction.name, faction.label)
            end
            print('All societies registered successfully.')
        end)
    end
end)

ESX.RegisterServerCallback('gangbuilder:getPlayerGroup', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        cb(xPlayer.getGroup())
    else
        cb(nil)
    end
end)

ESX.RegisterServerCallback('gangbuilder:getPlayerGang', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        cb(xPlayer.faction.name) -- Assuming `job` is used to store gang info. Adjust if needed.
    else
        cb(nil)
    end
end)

ESX.RegisterServerCallback('gangbuilder:getFactionChests', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM `faction_chests`', {}, function(result)
        cb(result)
    end)
end)

ESX.RegisterServerCallback('gangbuilder:getAllFaction', function(source, cb)
    MySQL.Async.fetchAll('SELECT name, label FROM `factions` WHERE name != "nofaction"', {}, function(result)
        cb(result)
    end)
end)

RegisterServerEvent('gangbuilder:createGang')
AddEventHandler('gangbuilder:createGang', function(name, label, grades, coords, startmoney, startdirtymoney, garageEntryCoords, garageExitCoords, slotscoffre, poidcoffre)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local success_sql_insert = false

    MySQL.Async.execute('INSERT INTO `factions` (name, label) VALUES (@name, @label)', {
        ['@name'] = name,
        ['@label'] = label
    }, function(rowsChanged)
        if rowsChanged > 0 then
            for gradeIndex, grade in ipairs(grades) do
                MySQL.Async.execute('INSERT INTO `faction_grades` (faction_name, grade, name, label, salary, skin_male, skin_female) VALUES (@faction_name, @grade, @name, @label, @salary, @skin_male, @skin_female)', {
                    ['@faction_name'] = name,
                    ['@grade'] = gradeIndex - 1,
                    ['@name'] = grade.name,
                    ['@label'] = grade.label,
                    ['@salary'] = grade.salary or 0,
                    ['@skin_male'] = json.encode(grade.skin_male or {}),
                    ['@skin_female'] = json.encode(grade.skin_female or {})
                })
            end

            -- Ajout du coffre
            MySQL.Async.execute('INSERT INTO `faction_chests` (faction_name, coords) VALUES (@faction_name, @coords)', {
                ['@faction_name'] = name,
                ['@coords'] = json.encode(coords)
            })

            MySQL.Async.execute('INSERT INTO `faction_garage` (faction_name, coordsgarageentrer, coordsgaragesortir) VALUES (@faction_name, @coordsgarageentrer, @coordsgaragesortir)', {
                ['@faction_name'] = name,
                ['@coordsgarageentrer'] = json.encode(garageEntryCoords),
                ['@coordsgaragesortir'] = json.encode(garageExitCoords)
            })

            -- Ajouter les comptes de la société
            MySQL.Async.execute('INSERT INTO `addon_account` (name, label, shared) VALUES (@name, @label, @shared)', {
                ['@name'] = 'society_' .. name,
                ['@label'] = label,
                ['@shared'] = 1
            })

            -- Ajouter les comptes argent sale de la société
            MySQL.Async.execute('INSERT INTO `addon_account` (name, label, shared) VALUES (@name, @label, @shared)', {
                ['@name'] = 'society_' .. name .. '_black',
                ['@label'] = label .. ' Black',
                ['@shared'] = 1
            })

            -- Ajouter les comptes argent sale de la société
            MySQL.Async.execute('INSERT INTO `addon_account_data` (account_name, money) VALUES (@account_name, @money)', {
                ['@account_name'] = 'society_' .. name,
                ['@money'] = startmoney
            })

            -- Ajouter les comptes argent sale de la société
            MySQL.Async.execute('INSERT INTO `addon_account_data` (account_name, money) VALUES (@account_name, @money)', {
                ['@account_name'] = 'society_' .. name .. '_black',
                ['@money'] = startdirtymoney
            })


            MySQL.Async.execute('INSERT INTO `addon_inventory` (name, label, shared) VALUES (@name, @label, @shared)', {
                ['@name'] = 'society_' .. name,
                ['@label'] = label,
                ['@shared'] = 1
            })

            MySQL.Async.execute('INSERT INTO `datastore` (name, label, shared) VALUES (@name, @label, @shared)', {
                ['@name'] = 'society_' .. name,
                ['@label'] = label,
                ['@shared'] = 1
            })

            ------Creation du coffre----------------------
            ox_inventory:RegisterStash(name, label, slotscoffre, poidcoffre, false, name)

            success_sql_insert = true
        end

        if success_sql_insert then 
            xPlayer.showNotification('Gang et coffre créés avec succès !')
            ESX.RefreshFactions()
            
            -- Envoi du log au Discord
            local poidcoffrereel = poidcoffre / 1000
            local playerName = GetPlayerName(xPlayer.source)
            local logMessage = string.format(
                '```diff\n+ Un gang a été créé :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Nom du Gang]: %s\n[Label]: %s\n[Argent de départ]: %d\n[Argent sale de départ]: %d\n[Nombre de slots dans le coffre]: %d\n[Poids du coffre]: %d\n```',
                playerName,
                os.date('%Y-%m-%d %H:%M:%S'),
                name,
                label,
                startmoney,
                startdirtymoney,
                slotscoffre,
                poidcoffrereel
            )
            TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookCreationGang)

        else 
            xPlayer.showNotification("Échec de la création d'un gang.")
        end
    end)
end)




RegisterNetEvent('gangbuilder:deleteFaction')
AddEventHandler('gangbuilder:deleteFaction', function(factionName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local success_sql_delete = false

    -- Vérifier les permissions du joueur
    if xPlayer and (xPlayer.getGroup() == 'superadmin' or xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'mod') then
        -- Supprimer le gang et ses données associées dans la base de données
        MySQL.Async.execute('DELETE FROM `factions` WHERE `name` = @name', {['@name'] = factionName}, function(rowsChanged)
            if rowsChanged > 0 then
                MySQL.Async.execute('DELETE FROM `faction_grades` WHERE `faction_name` = @name', {['@name'] = factionName}, function()
                    MySQL.Async.execute('DELETE FROM `faction_chests` WHERE `faction_name` = @name', {['@name'] = factionName}, function()
                        MySQL.Async.execute('DELETE FROM `faction_garage` WHERE `faction_name` = @name', {['@name'] = factionName}, function()
                            MySQL.Async.execute('DELETE FROM `addon_account` WHERE `name` = @name', {['@name'] = 'society_' .. factionName}, function()
                                MySQL.Async.execute('DELETE FROM `addon_account` WHERE `name` = @name', {['@name'] = 'society_' .. factionName .. '_black'}, function()
                                    MySQL.Async.execute('DELETE FROM `addon_account_data` WHERE `account_name` = @name', {['@name'] = 'society_' .. factionName}, function()
                                        MySQL.Async.execute('DELETE FROM `addon_account_data` WHERE `account_name` = @name', {['@name'] = 'society_' .. factionName .. '_black'}, function()
                                            MySQL.Async.execute('DELETE FROM `addon_inventory` WHERE `name` = @name', {['@name'] = 'society_' .. factionName}, function()
                                                MySQL.Async.execute('DELETE FROM `datastore` WHERE `name` = @name', {['@name'] = 'society_' .. factionName}, function()
                                                    success_sql_delete = true
                                                    -- -- Mettre à jour tous les joueurs ayant la colonne faction différente de 'nofaction'
                                                    -- MySQL.Async.fetchAll('SELECT * FROM users WHERE faction = @faction', {['@faction'] = factionName}, function(users)
                                                    --     for _, user in ipairs(users) do
                                                    --         MySQL.Async.execute('UPDATE users SET faction = @faction WHERE identifier = @identifier', {['@faction'] = 'nofaction', ['@identifier'] = user.identifier})
                                                    --     end
                                                    -- end)
                                                end)
                                            end)
                                        end)
                                    end) 
                                end)
                            end)
                        end)
                    end)
                end)
            end
        end)
        
        -- Envoyer une notification appropriée au joueur
        if not success_sql_delete then 
            TriggerClientEvent('okokNotify:Alert', source, "Delete Faction", "Gang supprimée avec succès.", 5000, 'success')
            -- Envoi du log au Discord
            local playerName = GetPlayerName(xPlayer.source)
            local logMessage = string.format(
                '```diff\n- Un gang a été suprimmer :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Nom du Gang]: %s\n```',
                playerName,
                os.date('%Y-%m-%d %H:%M:%S'),
                factionName
            )
            TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookSuppressionGang)
        else 
            TriggerClientEvent('okokNotify:Alert', source, "Delete Faction", "Gang non trouvée.", 5000, 'error')
        end
    else
        TriggerClientEvent('okokNotify:Alert', source, "Delete Faction", "Vous n'êtes pas autorisé à effectuer cette action.", 5000, 'error')
    end
end)


RegisterNetEvent('gangbuilder:depositMoney')
AddEventHandler('gangbuilder:depositMoney', function(account, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local factionName = xPlayer.faction.name
    local gangAccount = 'society_' .. factionName
    local gangAccountBlack = gangAccount .. '_black'

    if account == 'society' then
        if xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            TriggerEvent('esx_addonaccount:getSharedAccount', gangAccount, function(account)
                if account then
                    account.addMoney(amount)
                    TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "L'argent propre a été déposé avec succès.", 5000, 'success')

                    -- Envoi du log au Discord
                    local playerName = GetPlayerName(xPlayer.source)
                    local logMessage = string.format(
                        '```diff\n+ Un joueur à déposé de l\'argent dans un gang :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Montant]: %d\n[Gang]: %s\n[Compte]: %s\n```',
                        playerName,
                        os.date('%d-%m-%Y %H:%M:%S'),
                        amount,
                        gangAccount,
                        'Argent'
                    )
                    TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookArgent)
                end
            end)
        else
            TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Vous n'avez pas assez d'argent propre.", 5000, 'error')
        end
    elseif account == 'society_black' then
        if xPlayer.getAccount('black_money').money >= amount then
            xPlayer.removeAccountMoney('black_money', amount)
            TriggerEvent('esx_addonaccount:getSharedAccount', gangAccountBlack, function(account)
                if account then
                    account.addMoney(amount)
                    TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "L'argent sale a été déposé avec succès.", 5000, 'success')

                    -- Envoi du log au Discord
                    local playerName = GetPlayerName(xPlayer.source)
                    local logMessage = string.format(
                        '```diff\n+ Un joueur à déposé de l\'argent Sale dans un gang :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Montant]: %d\n[Gang]: %s\n[Compte]: %s\n```',
                        playerName,
                        os.date('%d-%m-%Y %H:%M:%S'),
                        amount,
                        gangAccountBlack,
                        'Argent Sale'
                    )
                    TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookArgent)
                end
            end)
        else
            TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Vous n'avez pas assez d'argent sale.", 5000, 'error')
        end
    end
end)


RegisterNetEvent('gangbuilder:withdrawMoney')
AddEventHandler('gangbuilder:withdrawMoney', function(account, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local gangMoneyAccount = 'society_' .. xPlayer.faction.name

    if account == 'society' then
        TriggerEvent('esx_addonaccount:getSharedAccount', gangMoneyAccount, function(account)
            if account and account.money >= amount then
                account.removeMoney(amount)
                xPlayer.addMoney(amount)
                TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Retrait d'argent propre réussi.", 5000, 'success')
                -- Envoi du log au Discord
                local playerName = GetPlayerName(xPlayer.source)
                local logMessage = string.format(
                    '```diff\n- Un joueur à retiré de l\'argent d\'un gang :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Montant]: %d\n[Gang]: %s\n[Compte]: %s\n```',
                        playerName,
                        os.date('%d-%m-%Y %H:%M:%S'),
                        amount,
                        gangMoneyAccount,
                        'Argent'
                )
                TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookArgent)
            else
                TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Le gang n'a pas assez d'argent.", 5000, 'error')
            end
        end)
    elseif account == 'society_black' then
        local blackMoneyAccount = gangMoneyAccount .. '_black'
        TriggerEvent('esx_addonaccount:getSharedAccount', blackMoneyAccount, function(account)
            if account and account.money >= amount then
                account.removeMoney(amount)
                xPlayer.addAccountMoney('black_money', amount)
                TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Retrait d'argent sale propre réussi.", 5000, 'success')
                -- Envoi du log au Discord
                local playerName = GetPlayerName(xPlayer.source)
                local logMessage = string.format(
                    '```diff\n- Un joueur à retiré de l\'argent Sale d\'un gang :\n```\n```css\n[Joueur]: %s\n[Date]: %s\n[Montant]: %d\n[Gang]: %s\n[Compte]: %s\n```',
                    playerName,
                    os.date('%d-%m-%Y %H:%M:%S'),
                    amount,
                    blackMoneyAccount,
                    'Argent Sale'
                )
                TriggerEvent('toDiscordGangBuilder', logMessage, Config.WebhookArgent)
            else
                TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Le gang n'a pas assez d'argent sale.", 5000, 'error')
            end
        end)
    else
        TriggerClientEvent('okokNotify:Alert', source, "Gang Menu", "Invalid account.", 5000, 'error')
    end
end)


--------------GARAGE------------------

ESX.RegisterServerCallback('dpr_core:vehiclelistfourriere', function(source, cb)
	local ownedCars = {}
	local xPlayer = ESX.GetPlayerFromId(source)
		MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND Type = @Type AND `stored` = @stored', { -- job = NULL
			['@owner'] = xPlayer.identifier,
			['@Type'] = 'car',
			['@stored'] = false
		}, function(data)
			for _,v in pairs(data) do
				local vehicle = json.decode(v.vehicle)
				table.insert(ownedCars, {vehicle = vehicle, stored = v.stored, plate = v.plate})
			end
			cb(ownedCars)
		end)
end)

ESX.RegisterServerCallback('dpr_core:vehiclelist', function(source, cb)
	local ownedCars = {}
	local xPlayer = ESX.GetPlayerFromId(source)
		MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND Type = @Type AND `stored` = @stored', { -- job = NULL
			['@owner'] = xPlayer.identifier,
			['@Type'] = 'car',
			['@stored'] = true
		}, function(data)
			for _,v in pairs(data) do
				local vehicle = json.decode(v.vehicle)
				table.insert(ownedCars, {vehicle = vehicle, stored = v.stored, plate = v.plate})
			end
			cb(ownedCars)
		end)
end)

RegisterServerEvent('dpr_core:breakVehicleSpawn')
AddEventHandler('dpr_core:breakVehicleSpawn', function(plate, state)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE owned_vehicles SET `stored` = @stored WHERE plate = @plate', {
		['@stored'] = state,
		['@plate'] = plate
	}, function(rowsChanged)
		if rowsChanged == 0 then
			print(('esx_advancedgarage: %s exploited the garage!'):format(xPlayer.identifier))
		end
	end)
end)

ESX.RegisterServerCallback('dpr_core:returnVehicle', function (source, cb, vehicleProps)
	local ownedCars = {}
	local vehplate = vehicleProps.plate:match("^%s*(.-)%s*$")
	local vehiclemodel = vehicleProps.model
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND @plate = plate', {
		['@owner'] = xPlayer.identifier,
		['@plate'] = vehicleProps.plate
	}, function (result)
		if result[1] ~= nil then
			local originalvehprops = json.decode(result[1].vehicle)
			if originalvehprops.model == vehiclemodel then
				MySQL.Async.execute('UPDATE owned_vehicles SET vehicle = @vehicle WHERE owner = @owner AND plate = @plate', {
					['@owner'] = xPlayer.identifier,
					['@vehicle'] = json.encode(vehicleProps),
					['@plate'] = vehicleProps.plate
				}, function (rowsChanged)
					if rowsChanged == 0 then
						print(('dpr_core : tente de ranger un véhicule non à lui '):format(xPlayer.identifier))
					end
					cb(true)
				end)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)
end)

ESX.RegisterServerCallback('dpr_core:achat', function(source, cb)
    local _src = source
	local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.getMoney() >= 200 then
        xPlayer.removeMoney(200)
        TriggerClientEvent('esx:showNotification', _src, "Vous avez payer ~r~200 $ ~s~!")
        cb(true)
    else
        TriggerClientEvent('esx:showNotification', _src, "~r~Vous n'avez pas suffisament d'argent !")
        cb(false)
    end
end)

ESX.RegisterServerCallback('dpr_core:getGarageEntranceCoords', function(source, cb)
    MySQL.Async.fetchAll('SELECT coordsgarageentrer FROM faction_garage', {}, function(positions)
        local garageEntrances = {}
        for _, pos in ipairs(positions) do
            local coords = json.decode(pos.coordsgarageentrer)
            table.insert(garageEntrances, coords)
        end
        cb(garageEntrances)
    end)
end)

ESX.RegisterServerCallback('dpr_core:getGarageExitCoords', function(source, cb)
    MySQL.Async.fetchAll('SELECT coordsgaragesortir FROM faction_garage', {}, function(positions)
        local garageExits = {}
        for _, pos in ipairs(positions) do
            local coords = json.decode(pos.coordsgaragesortir)
            table.insert(garageExits, coords)
        end
        cb(garageExits)
    end)
end)


--------------Logs---------------Weebook----------------------------

function sendLogs(message, webhook)
    if message == nil or message == '' then return false end
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ content = message }), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent('toDiscordGangBuilder')
AddEventHandler('toDiscordGangBuilder', function(message, webhook)
    sendLogs(message, webhook)
end)



