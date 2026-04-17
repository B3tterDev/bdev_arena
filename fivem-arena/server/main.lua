-- ============================================================
--  SERVER MAIN  —  Event Handlers + Framework Init
-- ============================================================

-- Framework bridge
if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- สร้าง Arena instance
local Arena = ArenaManager:New()

-- ============================================================
--  EVENTS FROM CLIENT
-- ============================================================

-- Host สร้าง Lobby
RegisterNetEvent('arena:createLobby', function(teamId, betAmount)
    local src = source
    local ok, msg = Arena:CreateLobby(src, teamId, betAmount)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

-- ผู้เล่นเข้าร่วมทีม
RegisterNetEvent('arena:joinTeam', function(teamId)
    local src = source
    local ok, msg = Arena:JoinTeam(src, teamId)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

-- Host กด Start
RegisterNetEvent('arena:startGame', function()
    local src = source
    local ok, msg = Arena:StartGame(src)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

-- ผู้เล่นตาย (แจ้งจาก client)
RegisterNetEvent('arena:playerDied', function(killerId)
    local src = source
    Arena:OnPlayerDied(src, killerId)
end)

-- ผู้แพ้ Rejoin
RegisterNetEvent('arena:rejoin', function(teamId)
    local src = source
    local ok, msg = Arena:Rejoin(src, teamId)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

-- Host ยกเลิก / Reset
RegisterNetEvent('arena:reset', function()
    local src = source
    if Arena.host == src or IsPlayerAceAllowed(src, 'arena.admin') then
        Arena:Reset()
        TriggerClientEvent('arena:response', src, { success = true, message = 'Arena ถูก reset แล้ว' })
    else
        TriggerClientEvent('arena:response', src, { success = false, message = 'ไม่มีสิทธิ์ reset' })
    end
end)

-- ผู้เล่น Request สถานะปัจจุบัน
RegisterNetEvent('arena:requestState', function()
    local src = source
    TriggerClientEvent('arena:stateUpdate', src, Arena:GetState())
end)

-- ============================================================
--  ADMIN COMMAND
-- ============================================================
RegisterCommand('arenarest', function(source, args)
    if source == 0 or IsPlayerAceAllowed(tostring(source), 'arena.admin') then
        Arena:Reset()
        print('[ARENA] Admin reset by player ' .. tostring(source))
    end
end, false)

-- ============================================================
--  DISCONNECT CLEANUP
-- ============================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    local teamId = Arena:_GetTeamOf(src)
    if teamId then
        Arena:_RemoveFromTeam(src)
        Arena:_CheckRoundEnd()
        Arena:_BroadcastState()
        print(string.format('[ARENA] Player %d disconnected from team %s', src, teamId))
    end
    -- ถ้า Host หลุด reset
    if Arena.host == src then
        print('[ARENA] Host disconnected — resetting arena')
        Arena:Reset()
    end
end)

print('[ARENA] Server loaded.')
