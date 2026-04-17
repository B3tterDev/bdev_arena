-- ============================================================
--  CLIENT MAIN  —  Entry point + ox_lib Context Menus + Events
-- ============================================================

local Arena  = ArenaClass:New()
local Player = PlayerClass:New()
local UI     = UIClass:New()

-- ============================================================
--  BOOT
-- ============================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Arena:DrawBlips()
    TriggerServerEvent('arena:requestState')

    -- สร้าง Poly Zones ด้วย ox_lib
    Arena:CreateZones(
        function() OnEnterZone('red')  end,  -- onEnterRed
        function() OnExitZone('red')   end,  -- onExitRed
        function() OnEnterZone('blue') end,  -- onEnterBlue
        function() OnExitZone('blue')  end   -- onExitBlue
    )
    print('[ARENA] Client loaded — first-enter = host.')
end)

-- ============================================================
--  ZONE ENTER  (ตรรกะหลักทั้งหมดอยู่ที่นี่)
-- ============================================================

---@param teamId string
function OnEnterZone(teamId)
    local s = Arena.state

    if s == 'idle' then
        -- ============================================
        -- คนแรกที่เดินเข้า → claim host ทันที
        -- ============================================
        TriggerServerEvent('arena:claimHost', teamId)
        -- รอ result จาก server ใน 'arena:claimHostResult'

    elseif s == 'claiming' then
        -- มีคนกำลัง claim อยู่
        if Arena.isHost then
            -- host กลับเข้า zone (เช่น เดินออกแล้วเข้าใหม่) → เปิด dialog อีกครั้ง
            ShowBetDialog()
        else
            UI:Notify(
                string.format('รอ %s ตั้งราคาเดิมพัน...', Arena.hostName or 'Host'),
                'warning'
            )
        end

    elseif s == 'lobby' or s == 'ready' then
        ShowLobbyMenu(teamId)

    elseif s == 'playing' then
        if Arena.myTeam then
            -- ผู้แพ้กลับมา Rejoin
            ShowRejoinMenu()
        else
            UI:Notify('เกมกำลังดำเนินอยู่ รอ Round ถัดไป', 'inform')
        end
    end
end

---@param teamId string
function OnExitZone(teamId)
    -- ถ้า host ออกระหว่าง claiming ก่อนตั้ง Bet → cancel
    if Arena.state == 'claiming' and Arena.isHost then
        TriggerServerEvent('arena:cancelClaim')
    end
    lib.hideContext()
end

-- ============================================================
--  SERVER → เราถูก claim เป็น Host สำเร็จ
-- ============================================================
RegisterNetEvent('arena:claimHostResult', function(data)
    if data.success then
        -- แสดง dialog ตั้ง Bet ทันที
        Arena.isHost = true
        Arena.state  = 'claiming'
        ShowBetDialog()
    else
        UI:Notify(data.message, 'error')
    end
end)

-- ============================================================
--  BET DIALOG  (เฉพาะ Host หลัง claim)
-- ============================================================

function ShowBetDialog()
    -- สร้าง hint ตัวเลือกแนะนำ
    local hints = {}
    for _, v in ipairs(Config.BetAmounts) do
        hints[#hints + 1] = Utils.FormatMoney(v)
    end

    local teamLabel = Utils.GetTeamLabel(Arena.hostTeam or 'red')
    local input = lib.inputDialog(
        string.format('👑 Host — %s | ตั้งราคาเดิมพัน', teamLabel),
        {
            {
                type        = 'number',
                label       = string.format('ราคา (%s – %s)',
                    Utils.FormatMoney(Config.MinBet), Utils.FormatMoney(Config.MaxBet)),
                description = 'แนะนำ: ' .. table.concat(hints, ' | '),
                default     = Config.DefaultBet,
                min         = Config.MinBet,
                max         = Config.MaxBet,
                required    = true,
            },
        }
    )

    if not input or not input[1] then
        -- กด Cancel → บอก server ว่าไม่เอา
        TriggerServerEvent('arena:cancelClaim')
        return
    end

    local bet = math.floor(tonumber(input[1]) or Config.DefaultBet)
    TriggerServerEvent('arena:setHostBet', bet)
end

-- ============================================================
--  LOBBY MENU  (ผู้เล่นทั่วไปเดินเข้า zone หลัง Lobby เปิด)
-- ============================================================

---@param teamId string
function ShowLobbyMenu(teamId)
    local s        = Arena.state
    local isHost   = Arena.isHost
    local isReady  = s == 'ready'
    local redCount  = #Arena.teamRed
    local blueCount = #Arena.teamBlue
    local count    = (teamId == 'red') and redCount or blueCount
    local full     = count >= Config.MaxPlayersPerTeam
    local opts     = {}

    -- ข้อมูล Host + Bet
    opts[#opts+1] = {
        title    = string.format('👑 Host: %s (%s)',
            Arena.hostName or '?', Utils.GetTeamLabel(Arena.hostTeam or '')),
        description = string.format('เดิมพัน: %s', Utils.FormatMoney(Arena.betAmount)),
        icon     = 'crown',
        disabled = true,
    }

    -- แสดงจำนวนทีม
    opts[#opts+1] = {
        title    = string.format('🔴 %d/5   🔵 %d/5', redCount, blueCount),
        icon     = 'users',
        disabled = true,
    }

    -- ปุ่ม Join (เฉพาะคนที่ยังไม่ได้เข้าทีม)
    if not Arena.myTeam then
        opts[#opts+1] = {
            title       = full
                and string.format('❌ %s เต็มแล้ว', Utils.GetTeamLabel(teamId))
                or  string.format('⚔️ เข้าร่วม%s', Utils.GetTeamLabel(teamId)),
            description = not full
                and string.format('หักเงิน %s ทันที', Utils.FormatMoney(Arena.betAmount))
                or  'ลองทีมอื่น',
            icon     = full and 'xmark' or 'right-to-bracket',
            disabled = full,
            onSelect = function()
                if not full then TriggerServerEvent('arena:joinTeam', teamId) end
            end,
        }
    else
        opts[#opts+1] = {
            title    = string.format('✅ คุณอยู่%sแล้ว', Utils.GetTeamLabel(Arena.myTeam)),
            icon     = 'check',
            disabled = true,
        }
    end

    -- Host controls
    if isHost then
        opts[#opts+1] = {
            title       = isReady and '▶ START GAME' or '⏳ รอผู้เล่นครบ...',
            description = isReady
                and 'กด Start เริ่มการแข่งขัน!'
                or  string.format('รออีก %d คน',
                    (Config.MaxPlayersPerTeam - redCount) + (Config.MaxPlayersPerTeam - blueCount)),
            icon     = 'play',
            disabled = not isReady,
            onSelect = function()
                if isReady then TriggerServerEvent('arena:startGame') end
            end,
        }
        opts[#opts+1] = {
            title    = '↩ ยกเลิก / Reset',
            icon     = 'rotate-left',
            onSelect = function() ResetArenaConfirm() end,
        }
    end

    local menuId = 'arena_lobby_' .. teamId
    lib.registerContext({ id = menuId, title =
        (teamId == 'red') and '🔴 Arena — ทีมแดง' or '🔵 Arena — ทีมน้ำเงิน',
        options = opts })
    lib.showContext(menuId)
end

-- ============================================================
--  REJOIN MENU  (หลังถูกกำจัด)
-- ============================================================

function ShowRejoinMenu()
    lib.registerContext({
        id    = 'arena_rejoin_dyn',
        title = '❌ คุณถูกกำจัด — Rejoin',
        options = {
            {
                title       = '🔴 Rejoin ทีมแดง',
                description = string.format('หักเงิน %s | Streak รีเซ็ต',
                    Utils.FormatMoney(Arena.betAmount)),
                icon        = 'rotate-right',
                onSelect    = function() TriggerServerEvent('arena:rejoin', 'red') end,
            },
            {
                title       = '🔵 Rejoin ทีมน้ำเงิน',
                description = string.format('หักเงิน %s | Streak รีเซ็ต',
                    Utils.FormatMoney(Arena.betAmount)),
                icon        = 'rotate-right',
                onSelect    = function() TriggerServerEvent('arena:rejoin', 'blue') end,
            },
        },
    })
    lib.showContext('arena_rejoin_dyn')
end

-- ============================================================
--  RESET CONFIRM
-- ============================================================
function ResetArenaConfirm()
    local confirmed = lib.alertDialog({
        header  = 'ยืนยันการ Reset',
        content = 'ยกเลิกเกมและคืนเงินให้ทุกคน?',
        cancel  = true,
    })
    if confirmed == 'confirm' then
        TriggerServerEvent('arena:reset')
    end
end

-- ============================================================
--  SERVER EVENTS
-- ============================================================

-- State Update (broadcast ทุกครั้ง)
RegisterNetEvent('arena:stateUpdate', function(data)
    local prevState  = Arena.state
    local prevIsHost = Arena.isHost

    Arena:ApplyState(data)

    -- ถ้าเพิ่ง transition จาก claiming → lobby และฉันเป็น host
    -- (server ส่ง state=lobby มา) → ไม่ต้องทำอะไรพิเศษ เพราะ host join อัตโนมัติแล้ว
end)

-- Response จาก action ต่างๆ
RegisterNetEvent('arena:response', function(data)
    UI:Notify(data.message, data.success and 'success' or 'error')
end)

-- Spawn เข้าวง
RegisterNetEvent('arena:spawnInArena', function(teamId, round)
    Arena:SpawnToArena(teamId)
    lib.hideContext()
    UI:ShowRoundInfo(round, Config.TotalRounds, Arena.scores)

    Player:StartDeathDetection(function(killerId)
        TriggerServerEvent('arena:playerDied', killerId)
        Arena:EjectFromArena()
        UI:Notify('คุณถูกกำจัด! เดินกลับ Lobby เพื่อ Rejoin', 'error')
        ShowRejoinMenu()
    end)
end)

-- ถูกกำจัดโดย server
RegisterNetEvent('arena:eliminated', function(data)
    Arena:EjectFromArena()
    Player:StopDeathDetection()
    UI:Notify('คุณถูกกำจัด! เดินกลับ Lobby เพื่อ Rejoin', 'error')
    ShowRejoinMenu()
end)

-- Round เริ่ม
RegisterNetEvent('arena:roundStart', function(data)
    Arena.round  = data.round
    Arena.scores = data.scores
    lib.hideContext()
    UI:ShowRoundInfo(data.round, Config.TotalRounds, data.scores)
    UI:StartCountdown(data.duration)
    UI:Notify(string.format('Round %d/%d เริ่มแล้ว!', data.round, Config.TotalRounds), 'inform')
end)

-- Round จบ
RegisterNetEvent('arena:roundEnd', function(data)
    Arena.scores = data.scores
    UI:ShowRoundInfo(data.round, Config.TotalRounds, data.scores)
    local winLabel = data.winnerTeam and Utils.GetTeamLabel(data.winnerTeam) or 'เสมอ'
    UI:Notify(
        string.format('Round %d จบ — %s (🔴%d - %d🔵)',
            data.round, winLabel, data.scores.red, data.scores.blue),
        'inform'
    )
end)

-- รอ Rejoin
RegisterNetEvent('arena:waitingForRejoin', function(data)
    UI:Notify(
        string.format('Round %d — เดินกลับ Lobby เพื่อ Rejoin', data.round),
        'warning'
    )
end)

-- จบเกม
RegisterNetEvent('arena:gameEnd', function(data)
    Player:StopDeathDetection()
    Arena:EjectFromArena()
    lib.hideContext()
    UI:HideHUD()
    UI:ShowResult(data)
    SetTimeout(8000, function() UI:HideResult() end)
end)

-- Streak
RegisterNetEvent('arena:streakUpdate', function(streak)
    Player:SetStreak(streak)
    UI:UpdateStreak(streak)
end)

-- Notify ทั่วไป
RegisterNetEvent('arena:notify', function(msg, ntype)
    UI:Notify(msg, ntype)
end)
