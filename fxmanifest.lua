

fx_version 'cerulean'
game 'gta5'

author 'Metromods'
description 'Resource Gathering System for Fancy'
version '1.0.0'

shared_scripts {
    '@17th-base/shared/locale.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'