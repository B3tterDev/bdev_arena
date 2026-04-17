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
    RegisterContextMenus()
    Arena:CreateZones(
        -- onEnterRed
        function() ShowLobbyMenu('red') end,
        -- onExitRed
        function() lib.hideContext() end,
        -- onEnterBlue
        function() ShowLobbyMenu('blue') end,
        -- onExitBlue
        function() lib.hideContext() end
    )
    print('[ARENA] Client loaded (ox_lib mode).')
end)

-- ============================================================
--  OX_LIB CONTEXT MENUS
-- ============================================================

--- ลงทะเบียน Context Menus ทั้งหมด (เรียก 1 ครั้งตอนเริ่ม)
function RegisterContextMenus()
    -- เมนูหลักสำหรับ Red Lobby
    lib.registerContext({
        id    = 'arena_red_lobby',
        title = '🔴 ทีมแดง — Arena Lobby',
        options = {
            {
                title       = '👑 สร้าง Lobby (Host)',
                description = 'ตั้งราคาเดิมพันและเปิด Lobby',
                icon        = 'crown',
                onSelect    = function() OpenCreateLobbyDialog('red') end,
            },
            {
                title       = '⚔️ เข้าร่วมทีมแดง',
                description = 'หักเงินเดิมพันทันที',
                icon        = 'right-to-bracket',
                onSelect    = function() TriggerServerEvent('arena:joinTeam', 'red') end,
            },
            {
                title       = '▶ Start Game',
                description = 'เฉพาะ Host (ผู้เล่นครบแล้ว)',
                icon        = 'play',
                onSelect    = function() TriggerServerEvent('arena:startGame') end,
            },
            {
                title       = '↩ ยกเลิก / Reset',
                description = 'เฉพาะ Host',
                icon        = 'rotate-left',
                onSelect    = function() ResetArenaConfirm() end,
            },
        },
    })

    -- เมนูหลักสำหรับ Blue Lobby
    lib.registerContext({
        id    = 'arena_blue_lobby',
        title = '🔵 ทีมน้ำเงิน — Arena Lobby',
        options = {
            {
                title       = '👑 สร้าง Lobby (Host)',
                description = 'ตั้งราคาเดิมพันและเปิด Lobby',
                icon        = 'crown',
                onSelect    = function() OpenCreateLobbyDialog('blue') end,
            },
            {
                title       = '⚔️ เข้าร่วมทีมน้ำเงิน',
                description = 'หักเงินเดิมพันทันที',
                icon        = 'right-to-bracket',
                onSelect    = function() TriggerServerEvent('arena:joinTeam', 'blue') end,
            },
            {
                title       = '▶ Start Game',
                description = 'เฉพาะ Host (ผู้เล่นครบแล้ว)',
                icon        = 'play',
                onSelect    = function() TriggerServerEvent('arena:startGame') end,
            },
            {
                title       = '↩ ยกเลิก / Reset',
                description = 'เฉพาะ Host',
                icon        = 'rotate-left',
                onSelect    = function() ResetArenaConfirm() end,
            },
        },
    })

    -- เมนู Rejoin (หลังถูกกำจัด)
    lib.registerContext({
        id    = 'arena_rejoin',
        title = '❌ คุณถูกกำจัด — Rejoin',
        options = {
            {
                title       = '🔴 Rejoin ทีมแดง',
                description = 'หักเงินเดิมพันอีกครั้ง | Streak รีเซ็ต',
                icon        = 'rotate-right',
                onSelect    = function() TriggerServerEvent('arena:rejoin', 'red') end,
            },
            {
                title       = '🔵 Rejoin ทีมน้ำเงิน',
                description = 'หักเงินเดิมพันอีกครั้ง | Streak รีเซ็ต',
                icon        = 'rotate-right',
                onSelect    = function() TriggerServerEvent('arena:rejoin', 'blue') end,
            },
        },
    })
end

-- ============================================================
--  SHOW LOBBY MENU — Dynamic (ปรับตาม state)
-- ============================================================

---@param teamId string 'red'|'blue'
function ShowLobbyMenu(teamId)
    local s       = Arena.state
    local myId    = GetPlayerServerId(PlayerId())
    local isInTeam = Arena.myTeam ~= nil
    local isHost  = Arena.isHost
    local isReady = s == 'ready'

    -- สร้าง options แบบ dynamic ตาม state
    local opts = {}

    if s == 'idle' then
        -- ยังไม่มี Lobby — แสดงแค่ปุ่มสร้าง
        opts[#opts+1] = {
            title       = '👑 สร้าง Lobby (Host)',
            description = string.format('ตั้งราคาเดิมพัน — คุณจะเป็น %s',
                Utils.GetTeamLabel(teamId)),
            icon        = 'crown',
            onSelect    = function() OpenCreateLobbyDialog(teamId) end,
        }
    elseif s == 'lobby' or s == 'ready' then
        local redCount  = #Arena.teamRed
        local blueCount = #Arena.teamBlue

        if not isInTeam then
            -- Join ทีมที่อยู่ใน Zone ของตัวเอง
            local count = (teamId == 'red') and redCount or blueCount
            local full  = count >= Config.MaxPlayersPerTeam
            opts[#opts+1] = {
                title       = full
                    and string.format('❌ %s เต็มแล้ว (%d/5)', Utils.GetTeamLabel(teamId), count)
                    or  string.format('⚔️ เข้าร่วม%s (%d/5)', Utils.GetTeamLabel(teamId), count),
                description = not full
                    and string.format('เดิมพัน: %s | หักเงินทันที', Utils.FormatMoney(Arena.betAmount))
                    or  'ไม่สามารถเข้าร่วมได้',
                icon        = full and 'xmark' or 'right-to-bracket',
                disabled    = full,
                onSelect    = function()
                    if not full then TriggerServerEvent('arena:joinTeam', teamId) end
                end,
            }
        else
            -- อยู่ทีมแล้ว
            opts[#opts+1] = {
                title       = string.format('✅ คุณอยู่%sแล้ว', Utils.GetTeamLabel(Arena.myTeam)),
                icon        = 'check',
                disabled    = true,
            }
        end

        -- แสดงสถานะทีม
        opts[#opts+1] = {
            title       = string.format('🔴 ทีมแดง: %d/5   🔵 ทีมน้ำเงิน: %d/5', redCount, blueCount),
            icon        = 'users',
            disabled    = true,
        }

        -- Host controls
        if isHost then
            opts[#opts+1] = {
                title       = isReady and '▶ START GAME' or '⏳ รอผู้เล่นครบ...',
                description = not isReady
                    and string.format('ต้องการอีก %d คน',
                        (Config.MaxPlayersPerTeam - #Arena.teamRed) +
                        (Config.MaxPlayersPerTeam - #Arena.teamBlue))
                    or 'ผู้เล่นครบแล้ว! กด Start ได้เลย',
                icon        = 'play',
                disabled    = not isReady,
                onSelect    = function()
                    if isReady then TriggerServerEvent('arena:startGame') end
                end,
            }
            opts[#opts+1] = {
                title       = '↩ ยกเลิก / Reset',
                icon        = 'rotate-left',
                onSelect    = function() ResetArenaConfirm() end,
            }
        end
    elseif s == 'playing' then
        opts[#opts+1] = {
            title    = '⚔️ เกมกำลังดำเนินอยู่',
            description = string.format('Round %d/%d | 🔴 %d - %d 🔵',
                Arena.round, Config.TotalRounds,
                Arena.scores.red, Arena.scores.blue),
            icon     = 'swords',
            disabled = true,
        }
    end

    -- Register + Show context ทุกครั้งที่เปิด (เพื่อ options เป็น dynamic)
    local menuId = 'arena_' .. teamId .. '_dynamic'
    lib.registerContext({
        id      = menuId,
        title   = (teamId == 'red') and '🔴 ทีมแดง — Arena Lobby'
                                     or '🔵 ทีมน้ำเงิน — Arena Lobby',
        options = opts,
    })
    lib.showContext(menuId)
end

-- ============================================================
--  CREATE LOBBY — lib.inputDialog
-- ============================================================

---@param teamId string
function OpenCreateLobbyDialog(teamId)
    -- สร้าง bet options label
    local betStr = table.concat((function()
        local t = {}
        for _, v in ipairs(Config.BetAmounts) do
            t[#t+1] = Utils.FormatMoney(v)
        end
        return t
    end)(), ' | ')

    local input = lib.inputDialog(
        string.format('สร้าง Lobby — %s', Utils.GetTeamLabel(teamId)),
        {
            {
                type        = 'number',
                label       = string.format('ราคาเดิมพัน (Min: %s | Max: %s)',
                    Utils.FormatMoney(Config.MinBet), Utils.FormatMoney(Config.MaxBet)),
                description = 'ตัวเลือกแนะนำ: ' .. betStr,
                default     = Config.DefaultBet,
                min         = Config.MinBet,
                max         = Config.MaxBet,
                required    = true,
            },
        }
    )

    if not input or not input[1] then return end

    local bet = math.floor(tonumber(input[1]) or Config.DefaultBet)
    TriggerServerEvent('arena:createLobby', teamId, bet)
end

-- ============================================================
--  RESET CONFIRM — lib.alertDialog
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
--  SERVER EVENT HANDLERS
-- ============================================================

-- State Update
RegisterNetEvent('arena:stateUpdate', function(data)
    Arena:ApplyState(data)
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
        UI:Notify('คุณถูกกำจัด! เดินกลับ Lobby เพื่อ Rejoin', 'error')
        -- แสดงเมนู Rejoin ทันที
        lib.showContext('arena_rejoin')
    end)
end)

-- ถูกกำจัดโดย server
RegisterNetEvent('arena:eliminated', function(data)
    Arena:EjectFromArena()
    Player:StopDeathDetection()
    UI:Notify('คุณถูกกำจัด! เดินกลับ Lobby เพื่อ Rejoin', 'error')
    lib.showContext('arena_rejoin')
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
    local winLabel = data.winnerTeam and Utils.GetTeamLabel(data.winnerTeam) or 'เสมอ'
    UI:ShowRoundInfo(data.round, Config.TotalRounds, data.scores)
    UI:Notify(
        string.format('Round %d จบ — ผู้ชนะ: %s (🔴 %d - %d 🔵)',
            data.round, winLabel, data.scores.red, data.scores.blue),
        'inform'
    )
end)

-- รอ Rejoin
RegisterNetEvent('arena:waitingForRejoin', function(data)
    UI:Notify(
        string.format('Round %d — รอผู้เล่น Rejoin (เดินเข้า Lobby)', data.round),
        'warning'
    )
end)

-- จบเกม
RegisterNetEvent('arena:gameEnd', function(data)
    Player:StopDeathDetection()
    Arena:EjectFromArena()
    UI:HideHUD()
    UI:ShowResult(data)
    -- ปิด result หลัง 8 วิ
    SetTimeout(8000, function()
        UI:HideResult()
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
