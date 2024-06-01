fx_version('cerulean')
game('gta5')
lua54 'on'


description 'Gang Builder Script by RORO'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    "src/RMenu.lua",
    "src/menu/RageUI.lua",
    "src/menu/Menu.lua",
    "src/menu/MenuController.lua",
    "src/components/*.lua",
    "src/menu/elements/*.lua",
    "src/menu/items/*.lua",
    "src/menu/panels/*.lua",
    "src/menu/windows/*.lua",

    "client/cl_garage.lua",
    "client/cl_function.lua",
    "client/cl_pound.lua",
    'client/client.lua',
    'config.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory',
    'ox_lib',
    'okokTextUI',
    'okokNotify'
}

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

shared_script '@es_extended/imports.lua'

