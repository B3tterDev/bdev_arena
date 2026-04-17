fx_version 'cerulean'
game 'gta5'

name 'bdev_arena'
description 'FiveM Arena - 2 Team Battle System (OOP + ox_lib)'
version '1.1.0'
author 'bdev'

-- ============================================================
--  DEPENDENCIES
-- ============================================================
dependencies {
    'ox_lib',
}

-- ============================================================
--  SHARED
-- ============================================================
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/utils.lua',
}

-- ============================================================
--  CLIENT
-- ============================================================
client_scripts {
    'client/arena_class.lua',
    'client/player_class.lua',
    'client/ui_class.lua',
    'client/main.lua',
}

-- ============================================================
--  SERVER
-- ============================================================
server_scripts {
    'server/arena_manager.lua',
    'server/bank_class.lua',
    'server/main.lua',
}

-- ============================================================
--  NUI  (เฉพาะ HUD + Result Overlay)
-- ============================================================
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/ui.js',
}
