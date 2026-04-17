-- ============================================================
--  CLIENT MAIN  —  Entry point, Event Handlers, Zone Loop
-- ============================================================

-- สร้าง instance
local Arena  = ArenaClass:New()
local Player = PlayerClass:New()
local UI     = UIClass:New()

-- Blip + Zone thread
local zoneThread = nil
local countdownThread = nil

-- ============================================================
--  BOOT
-- ============================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Arena:DrawBlips()
    TriggerServerEvent('arena:requestState')
    StartZoneLoop()
    print('[ARENA] Client loaded.')
end)

-- ============================================================
--  ZONE LOOP — แสดง Help text เมื่ออยู่ใน Lobby Zone
-- ============================================================
function StartZoneLoop()
    if zoneThread then return end
    zoneThread = CreateThread(function()
        while true do
            Wait(0)
            local inLobby = Arena:IsInLobbyZone()
            if inLobby then
                -- แสดง HelpText
                local txt = '[~b~E~w~] เปิดเมนู Arena'
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(txt)
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustPressed(0, Config.KeyOpenMenu) then
                    if not UI.isOpen then
                        UI:SetVisible(true)
                        UI:UpdateState(Arena:GetState and Arena:GetState() or {
                            state      = Arena.state,
                            round      = Arena.round,
                            scores     = Arena.scores,
                            streaks    = Arena.streaks,
                            betAmount  = Arena.betAmount,
                            isHost     = Arena.isHost,
                            myTeam     = Arena.myTeam,
                        })
                    end
                end
            end
        end
    end)
end

-- ============================================================
--  NUI CALLBACKS  (จาก HTML UI)
-- ============================================================

-- ปิด UI
RegisterNUICallback('closeUI', function(data, cb)
    UI:SetVisible(false)
    cb('ok')
end)

-- Host สร้าง Lobby
RegisterNUICallback('createLobby', function(data, cb)
    local teamId    = data.teamId
    local betAmount = tonumber(data.betAmount) or Config.DefaultBet
    TriggerServerEvent('arena:createLobby', teamId, betAmount)
    cb('ok')
end)

-- Join ทีม
RegisterNUICallback('joinTeam', function(data, cb)
    local teamId = data.teamId
    TriggerServerEvent('arena:joinTeam', teamId)
    cb('ok')
end)

-- Host กด Start
RegisterNUICallback('startGame', function(data, cb)
    TriggerServerEvent('arena:startGame')
    cb('ok')
end)

-- Rejoin หลังแพ้
RegisterNUICallback('rejoin', function(data, cb)
    local teamId = data.teamId or Arena.myTeam or 'red'
    TriggerServerEvent('arena:rejoin', teamId)
    cb('ok')
end)

-- Host Reset
RegisterNUICallback('resetArena', function(data, cb)
    TriggerServerEvent('arena:reset')
    cb('ok')
end)

-- ============================================================
--  SERVER EVENTS
-- ============================================================

-- อัพเดทสถานะ
RegisterNetEvent('arena:stateUpdate', function(data)
    Arena:ApplyState(data)
    if UI.isOpen then
        -- รวม isHost และ myTeam ลงใน data
        data.isHost = Arena.isHost
        data.myTeam = Arena.myTeam
        UI:UpdateState(data)
    end
end)

-- Response จาก Action
RegisterNetEvent('arena:response', function(data)
    local ntype = data.success and 'success' or 'error'
    UI:Notify(data.message, ntype)
end)

-- Spawn เข้าวง
RegisterNetEvent('arena:spawnInArena', function(teamId, round)
    Arena:SpawnToArena(teamId)
    UI:ShowRoundInfo(round, Config.TotalRounds, Arena.scores)
    Player:StartDeathDetection(function(killerId)
        TriggerServerEvent('arena:playerDied', killerId)
        Arena:EjectFromArena()
        UI:Notify('คุณถูกกำจัด! กด Rejoin เพื่อกลับเข้าวง', 'error')
        -- เปิด UI Rejoin
        UI:SetVisible(true)
        SendNUIMessage({ action = 'showRejoin', teamId = teamId })
    end)
end)

-- ถูกกำจัด (ถ้า server บอกตรงๆ)
RegisterNetEvent('arena:eliminated', function(data)
    Arena:EjectFromArena()
    Player:StopDeathDetection()
    UI:Notify('คุณถูกกำจัด! รอ Rejoin', 'error')
end)

-- Round เริ่ม
RegisterNetEvent('arena:roundStart', function(data)
    Arena.round  = data.round
    Arena.scores = data.scores
    UI:ShowRoundInfo(data.round, Config.TotalRounds, data.scores)
    UI:StartCountdown(data.duration)
    UI:Notify(string.format('Round %d/%d เริ่มแล้ว!', data.round, Config.TotalRounds), 'info')
end)

-- Round จบ
RegisterNetEvent('arena:roundEnd', function(data)
    Arena.scores = data.scores
    local winLabel = data.winnerTeam and Utils.GetTeamLabel(data.winnerTeam) or 'เสมอ'
    UI:Notify(string.format('Round %d จบแล้ว — ผู้ชนะ: %s', data.round, winLabel), 'info')
    UI:ShowRoundInfo(data.round, Config.TotalRounds, data.scores)
end)

-- รอ Rejoin ก่อน Round ถัดไป
RegisterNetEvent('arena:waitingForRejoin', function(data)
    UI:Notify(string.format('รอผู้เล่น Rejoin สำหรับ Round %d...', data.round), 'warning')
end)

-- จบเกม
RegisterNetEvent('arena:gameEnd', function(data)
    Player:StopDeathDetection()
    Arena:EjectFromArena()
    UI:ShowResult(data)
    -- เด้งออกเกม (ปิด UI หลัง 8 วิ)
    SetTimeout(8000, function()
        UI:HideResult()
        UI:SetVisible(false)
    end)
end)

-- Streak อัพเดท
RegisterNetEvent('arena:streakUpdate', function(streak)
    Player:SetStreak(streak)
    UI:UpdateStreak(streak)
end)

-- Notify ทั่วไป
RegisterNetEvent('arena:notify', function(msg, ntype)
    UI:Notify(msg, ntype)
end)
