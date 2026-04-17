-- ============================================================
--  SERVER MAIN  —  Event Handlers + Framework Init
-- ============================================================

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local Arena = ArenaManager:New()

-- ============================================================
--  HOST CLAIMING  (คนแรกเดินเข้าวง)
-- ============================================================

-- Client แจ้งว่าเดินเข้า zone ขณะ state == idle
RegisterNetEvent('arena:claimHost', function(teamId)
    local src = source
    local ok, msg = Arena:ClaimHost(src, teamId)
    TriggerClientEvent('arena:claimHostResult', src, { success = ok, message = msg })
end)

-- Host ออกจาก zone ก่อนตั้ง Bet → คืน idle
RegisterNetEvent('arena:cancelClaim', function()
    local src = source
    Arena:CancelClaim(src)
end)

-- Host ส่งราคาเดิมพันหลัง inputDialog
RegisterNetEvent('arena:setHostBet', function(betAmount)
    local src = source
    local ok, msg = Arena:SetHostBet(src, betAmount)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

-- ============================================================
--  JOIN / START / REJOIN / RESET
-- ============================================================

RegisterNetEvent('arena:joinTeam', function(teamId)
    local src = source
    local ok, msg = Arena:JoinTeam(src, teamId)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

RegisterNetEvent('arena:startGame', function()
    local src = source
    local ok, msg = Arena:StartGame(src)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

RegisterNetEvent('arena:playerDied', function(killerId)
    local src = source
    Arena:OnPlayerDied(src, killerId)
end)

RegisterNetEvent('arena:rejoin', function(teamId)
    local src = source
    local ok, msg = Arena:Rejoin(src, teamId)
    TriggerClientEvent('arena:response', src, { success = ok, message = msg })
end)

RegisterNetEvent('arena:reset', function()
    local src = source
    if Arena.host == src or IsPlayerAceAllowed(tostring(src), 'arena.admin') then
        Arena:Reset()
        TriggerClientEvent('arena:response', src, { success = true, message = 'Arena ถูก reset แล้ว' })
    else
        TriggerClientEvent('arena:response', src, { success = false, message = 'เฉพาะ Host หรือ Admin เท่านั้น' })
    end
end)

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
        print('[ARENA] Admin reset by ' .. tostring(source))
    end
end, false)

-- ============================================================
--  DISCONNECT CLEANUP
-- ============================================================
AddEventHandler('playerDropped', function()
    local src = source

    -- ถ้า host หลุดตอน claiming → คืน idle
    if Arena.host == src then
        if Arena.state == 'claiming' then
            Arena:CancelClaim(src)
        else
            print('[ARENA] Host disconnected — resetting arena')
            Arena:Reset()
        end
        return
    end

    -- ผู้เล่นทั่วไปหลุด
    local teamId = Arena:_GetTeamOf(src)
    if teamId then
        Arena:_RemoveFromTeam(src)
        if Arena.state == 'playing' then
            Arena:_CheckRoundEnd()
        end
        Arena:_BroadcastState()
        print(string.format('[ARENA] Player %d dropped from team %s', src, teamId))
    end
end)

print('[ARENA] Server loaded (v1.1 — first-enter host).')
