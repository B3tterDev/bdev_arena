fx_version 'cerulean'
game 'gta5'

name 'bdev_arena'
description 'FiveM Arena - 2 Team Battle System (OOP)'
version '1.0.0'
author 'bdev'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/arena_class.lua',
    'client/player_class.lua',
    'client/ui_class.lua',
    'client/main.lua',
}

server_scripts {
    'server/arena_manager.lua',
    'server/bank_class.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/ui.js',
}
