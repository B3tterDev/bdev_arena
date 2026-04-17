-- ============================================================
--  ArenaManager  (OOP Server-side)
--  จัดการ Lobby / Round / Score / State ทั้งหมด
-- ============================================================

---@class ArenaManager
ArenaManager = {}
ArenaManager.__index = ArenaManager

-- สถานะของ Arena
local STATE = {
    IDLE    = 'idle',      -- รอ Host
    LOBBY   = 'lobby',     -- รอผู้เล่นเข้า
    READY   = 'ready',     -- ผู้เล่นครบ รอ Host กด Start
    PLAYING = 'playing',   -- กำลังแข่ง
    ENDED   = 'ended',     -- จบเกม
}

--- สร้าง instance ใหม่
---@return ArenaManager
function ArenaManager:New()
    local obj = setmetatable({}, ArenaManager)
    obj.state       = STATE.IDLE
    obj.host        = nil          -- serverId ของ Host
    obj.hostTeam    = nil          -- 'red' | 'blue'
    obj.betAmount   = Config.DefaultBet
    obj.teams       = { red = {}, blue = {} }
    obj.round       = 0
    obj.scores      = { red = 0, blue = 0 }
    obj.streaks     = {}           -- { [serverId] = streak }
    obj.bank        = BankClass:New()
    obj.roundTimer  = nil
    return obj
end

-- ============================================================
--  INTERNAL HELPERS
-- ============================================================

function ArenaManager:_GetTeamOf(serverId)
    for tid, members in pairs(self.teams) do
        for _, sid in ipairs(members) do
            if sid == serverId then return tid end
        end
    end
    return nil
end

function ArenaManager:_TeamCount(teamId)
    return #self.teams[teamId]
end

function ArenaManager:_RemoveFromTeam(serverId)
    for tid, members in pairs(self.teams) do
        for i, sid in ipairs(members) do
            if sid == serverId then
                table.remove(members, i)
                return tid
            end
        end
    end
end

function ArenaManager:_AllPlayersReady()
    return #self.teams.red == Config.MaxPlayersPerTeam
        and #self.teams.blue == Config.MaxPlayersPerTeam
end

function ArenaManager:_BroadcastState()
    local data = {
        state      = self.state,
        host       = self.host,
        hostTeam   = self.hostTeam,
        betAmount  = self.betAmount,
        teamRed    = self.teams.red,
        teamBlue   = self.teams.blue,
        round      = self.round,
        scores     = self.scores,
        streaks    = self.streaks,
        pool       = self.bank:GetPool(),
    }
    TriggerClientEvent('arena:stateUpdate', -1, data)
end

function ArenaManager:_StopRoundTimer()
    if self.roundTimer then
        clearTimeout(self.roundTimer)
        self.roundTimer = nil
    end
end

-- ============================================================
--  PUBLIC API
-- ============================================================

--- Host กดสร้าง Lobby
---@param serverId number
---@param teamId   string
---@param betAmount number
---@return boolean, string
function ArenaManager:CreateLobby(serverId, teamId, betAmount)
    if self.state ~= STATE.IDLE then
        return false, 'มีเกมกำลังดำเนินอยู่'
    end
    if not Config.Teams[teamId] then
        return false, 'ไม่พบทีมที่ระบุ'
    end
    if betAmount < Config.MinBet or betAmount > Config.MaxBet then
        return false, string.format('เดิมพันต้องอยู่ระหว่าง %s - %s',
            Utils.FormatMoney(Config.MinBet), Utils.FormatMoney(Config.MaxBet))
    end

    self.state     = STATE.LOBBY
    self.host      = serverId
    self.hostTeam  = teamId
    self.betAmount = betAmount
    self.teams     = { red = {}, blue = {} }
    self.round     = 0
    self.scores    = { red = 0, blue = 0 }
    self.streaks   = {}
    self.bank      = BankClass:New()

    -- Host Join อัตโนมัติ
    self:JoinTeam(serverId, teamId, true)
    print(string.format('[ARENA] Lobby created by player %d (team: %s, bet: $%d)', serverId, teamId, betAmount))
    return true, 'สร้าง Lobby สำเร็จ'
end

--- ผู้เล่นเข้าร่วมทีม
---@param serverId number
---@param teamId   string
---@param isHost   boolean|nil
---@return boolean, string
function ArenaManager:JoinTeam(serverId, teamId, isHost)
    if self.state ~= STATE.LOBBY then
        return false, 'ไม่สามารถเข้าร่วมได้ในขณะนี้'
    end
    if not Config.Teams[teamId] then
        return false, 'ไม่พบทีมที่ระบุ'
    end
    if self:_GetTeamOf(serverId) then
        return false, 'คุณอยู่ในทีมแล้ว'
    end
    if self:_TeamCount(teamId) >= Config.MaxPlayersPerTeam then
        return false, string.format('%s เต็มแล้ว (%d/%d)',
            Utils.GetTeamLabel(teamId), Config.MaxPlayersPerTeam, Config.MaxPlayersPerTeam)
    end

    -- หักเงิน (ยกเว้น host ถ้าหักไปแล้ว) — ทุกคนโดน หัก ณ จุด join
    local ok = self.bank:Deduct(serverId, self.betAmount)
    if not ok then
        return false, string.format('เงินไม่พอ ต้องการ %s', Utils.FormatMoney(self.betAmount))
    end

    table.insert(self.teams[teamId], serverId)
    self.streaks[serverId] = 0

    -- เช็คว่าครบหรือยัง
    if self:_AllPlayersReady() then
        self.state = STATE.READY
    end

    self:_BroadcastState()
    print(string.format('[ARENA] Player %d joined team %s (%d/%d)',
        serverId, teamId, self:_TeamCount(teamId), Config.MaxPlayersPerTeam))
    return true, string.format('เข้าร่วม %s สำเร็จ!', Utils.GetTeamLabel(teamId))
end

--- Host กด Start
---@param serverId number
---@return boolean, string
function ArenaManager:StartGame(serverId)
    if self.state ~= STATE.READY then
        return false, 'ยังไม่พร้อมเริ่ม (ผู้เล่นไม่ครบ?)'
    end
    if serverId ~= self.host then
        return false, 'เฉพาะ Host เท่านั้นที่กด Start ได้'
    end

    self.state = STATE.PLAYING
    self.round = 1
    self:_BroadcastState()
    self:_StartRound()
    print('[ARENA] Game started!')
    return true, 'เกมเริ่มแล้ว!'
end

--- เริ่ม Round ปัจจุบัน
function ArenaManager:_StartRound()
    self:_StopRoundTimer()

    -- เรียก client spawn ผู้เล่น
    for _, sid in ipairs(self.teams.red) do
        TriggerClientEvent('arena:spawnInArena', sid, 'red', self.round)
    end
    for _, sid in ipairs(self.teams.blue) do
        TriggerClientEvent('arena:spawnInArena', sid, 'blue', self.round)
    end

    TriggerClientEvent('arena:roundStart', -1, {
        round     = self.round,
        duration  = Config.RoundDuration,
        scores    = self.scores,
        streaks   = self.streaks,
    })
    print(string.format('[ARENA] Round %d/%d started', self.round, Config.TotalRounds))

    -- ตั้ง Timer หมดเวลา
    self.roundTimer = setTimeout(Config.RoundDuration * 1000, function()
        self:_OnRoundTimeout()
    end)
end

--- เมื่อผู้เล่นตาย
---@param deadId    number  serverId ผู้ตาย
---@param killerId  number  serverId ผู้ฆ่า
function ArenaManager:OnPlayerDied(deadId, killerId)
    if self.state ~= STATE.PLAYING then return end

    local deadTeam   = self:_GetTeamOf(deadId)
    local killerTeam = self:_GetTeamOf(killerId)

    if not deadTeam then return end

    -- อัพ Streak ผู้ชนะ
    if killerId and killerTeam and killerTeam ~= deadTeam then
        self.streaks[killerId] = (self.streaks[killerId] or 0) + 1
        local killerStreak = self.streaks[killerId]
        TriggerClientEvent('arena:streakUpdate', killerId, killerStreak)
        print(string.format('[ARENA] Player %d streak: %d', killerId, killerStreak))
    end

    -- รีเซ็ต Streak ผู้ตาย
    self.streaks[deadId] = 0

    -- เด้ง ผู้ตายออกจากวง
    TriggerClientEvent('arena:eliminated', deadId, { reason = 'eliminated' })

    -- ลบออกจากทีม (ต้อง rejoin ใหม่)
    self:_RemoveFromTeam(deadId)

    -- ตรวจเช็ค Round จบหรือยัง
    self:_CheckRoundEnd()
end

--- ตรวจสอบว่า Round จบหรือยัง (ทีมใดทีมหนึ่งหมดผู้เล่น)
function ArenaManager:_CheckRoundEnd()
    local redAlive  = #self.teams.red
    local blueAlive = #self.teams.blue

    if redAlive == 0 and blueAlive == 0 then
        -- เสมอ ไม่บวกแต้ม
        self:_EndRound(nil)
    elseif redAlive == 0 then
        self.scores.blue = self.scores.blue + 1
        self:_EndRound('blue')
    elseif blueAlive == 0 then
        self.scores.red = self.scores.red + 1
        self:_EndRound('red')
    end
    -- ยังมีผู้เล่นทั้งสองทีม → เล่นต่อ
end

--- เมื่อ Round หมดเวลา
function ArenaManager:_OnRoundTimeout()
    local redAlive  = #self.teams.red
    local blueAlive = #self.teams.blue

    if redAlive > blueAlive then
        self.scores.red = self.scores.red + 1
        self:_EndRound('red')
    elseif blueAlive > redAlive then
        self.scores.blue = self.scores.blue + 1
        self:_EndRound('blue')
    else
        self:_EndRound(nil) -- เสมอ
    end
end

--- จบ Round
---@param winnerTeam string|nil
function ArenaManager:_EndRound(winnerTeam)
    self:_StopRoundTimer()

    local label = winnerTeam and Utils.GetTeamLabel(winnerTeam) or 'เสมอ'
    print(string.format('[ARENA] Round %d ended — Winner: %s (Red:%d Blue:%d)',
        self.round, label, self.scores.red, self.scores.blue))

    TriggerClientEvent('arena:roundEnd', -1, {
        round       = self.round,
        winnerTeam  = winnerTeam,
        scores      = self.scores,
        streaks     = self.streaks,
    })

    -- รีเซ็ตทีมให้กลับมา (ผู้ที่รอดจาก Round ไม่ต้อง rejoin)
    -- ผู้ที่ถูกเด้งออกไปแล้วจะต้องกด rejoin ใหม่เอง
    -- ไม่มีการล้างทีมที่เหลืออยู่ — ผู้ชนะอยู่ในสนามต่อ

    if self.round >= Config.TotalRounds then
        -- หน่วงเล็กน้อยแล้วจบเกม
        setTimeout(5000, function()
            self:_EndGame()
        end)
    else
        -- รอผู้แพ้ Rejoin แล้วเริ่ม Round ถัดไป
        setTimeout(10000, function()
            self.round = self.round + 1
            self.state = STATE.LOBBY  -- เปิดให้ rejoin

            -- เช็คทันทีว่าครบหรือเปล่า (กรณีผู้ชนะเต็มทีมอยู่แล้ว)
            if self:_AllPlayersReady() then
                self.state = STATE.READY
            end
            self:_BroadcastState()
            TriggerClientEvent('arena:waitingForRejoin', -1, { round = self.round })
        end)
    end
end

--- ผู้แพ้กด Rejoin กลับเข้าวง
---@param serverId number
---@param teamId   string
---@return boolean, string
function ArenaManager:Rejoin(serverId, teamId)
    if self.state ~= STATE.LOBBY then
        return false, 'ยังไม่เปิดให้ Rejoin'
    end
    if self:_GetTeamOf(serverId) then
        return false, 'คุณยังอยู่ในทีม'
    end
    if self:_TeamCount(teamId) >= Config.MaxPlayersPerTeam then
        return false, string.format('%s เต็มแล้ว', Utils.GetTeamLabel(teamId))
    end

    -- หักเงินรอบใหม่
    local ok = self.bank:Deduct(serverId, self.betAmount)
    if not ok then
        return false, string.format('เงินไม่พอ Rejoin ต้องการ %s', Utils.FormatMoney(self.betAmount))
    end

    table.insert(self.teams[teamId], serverId)
    self.streaks[serverId] = 0  -- รีเซ็ต Streak

    if self:_AllPlayersReady() then
        self.state = STATE.READY
        -- auto-start ถ้ามี host ยังอยู่
        if self.host and self:_GetTeamOf(self.host) then
            self:StartGame(self.host)
        end
    end

    self:_BroadcastState()
    return true, 'Rejoin สำเร็จ! Streak ถูกรีเซ็ต'
end

--- จบเกม
function ArenaManager:_EndGame()
    self.state = STATE.ENDED

    -- ตัดสิน Winner Team
    local winnerTeam
    if self.scores.red > self.scores.blue then
        winnerTeam = 'red'
    elseif self.scores.blue > self.scores.red then
        winnerTeam = 'blue'
    else
        winnerTeam = nil -- เสมอ
    end

    -- แจกเงิน
    local winnerIds = {}
    if winnerTeam then
        winnerIds = self.teams[winnerTeam]
    end

    if #winnerIds > 0 then
        self.bank:Distribute(winnerIds)
    else
        self.bank:RefundAll()
    end

    -- สรุปผล broadcast
    TriggerClientEvent('arena:gameEnd', -1, {
        winnerTeam = winnerTeam,
        scores     = self.scores,
        streaks    = self.streaks,
        pool       = self.bank:GetPool(),
    })

    print(string.format('[ARENA] Game ended! Winner: %s (Red:%d Blue:%d)',
        winnerTeam or 'Draw', self.scores.red, self.scores.blue))

    -- Reset หลัง 15 วิ
    setTimeout(15000, function()
        self:Reset()
    end)
end

--- ยกเลิก / Reset
function ArenaManager:Reset()
    self:_StopRoundTimer()
    if self.bank then
        self.bank:RefundAll()
    end
    self.state     = STATE.IDLE
    self.host      = nil
    self.hostTeam  = nil
    self.betAmount = Config.DefaultBet
    self.teams     = { red = {}, blue = {} }
    self.round     = 0
    self.scores    = { red = 0, blue = 0 }
    self.streaks   = {}
    self.bank      = BankClass:New()
    self.roundTimer = nil
    TriggerClientEvent('arena:stateUpdate', -1, { state = STATE.IDLE })
    print('[ARENA] Arena reset.')
end

--- Get สถานะปัจจุบัน
---@return table
function ArenaManager:GetState()
    return {
        state      = self.state,
        host       = self.host,
        hostTeam   = self.hostTeam,
        betAmount  = self.betAmount,
        teamRed    = self.teams.red,
        teamBlue   = self.teams.blue,
        round      = self.round,
        scores     = self.scores,
        streaks    = self.streaks,
        pool       = self.bank:GetPool(),
    }
end
