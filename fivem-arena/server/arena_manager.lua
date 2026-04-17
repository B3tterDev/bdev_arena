-- ============================================================
--  ArenaManager  (OOP Server-side)
--  จัดการ Lobby / Round / Score / State ทั้งหมด
-- ============================================================

---@class ArenaManager
ArenaManager = {}
ArenaManager.__index = ArenaManager

-- ============================================================
--  STATE MACHINE
--  idle → claiming → lobby → ready → playing → ended → idle
-- ============================================================
local STATE = {
    IDLE     = 'idle',      -- ไม่มีใครในวง
    CLAIMING = 'claiming',  -- คนแรกเดินเข้า รอตั้ง Bet
    LOBBY    = 'lobby',     -- Host ตั้ง Bet แล้ว รอผู้เล่น
    READY    = 'ready',     -- ผู้เล่นครบ รอ Host กด Start
    PLAYING  = 'playing',   -- กำลังแข่ง
    ENDED    = 'ended',     -- จบเกม
}

-- ============================================================
--  CONSTRUCTOR
-- ============================================================
function ArenaManager:New()
    local obj = setmetatable({}, ArenaManager)
    obj.state      = STATE.IDLE
    obj.host       = nil       -- serverId ของ Host
    obj.hostName   = nil       -- ชื่อ Host
    obj.hostTeam   = nil       -- 'red' | 'blue'
    obj.betAmount  = 0
    obj.teams      = { red = {}, blue = {} }
    obj.round      = 0
    obj.scores     = { red = 0, blue = 0 }
    obj.streaks    = {}
    obj.bank       = BankClass:New()
    obj.roundTimer = nil
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
    return #(self.teams[teamId] or {})
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
    return #self.teams.red  == Config.MaxPlayersPerTeam
       and #self.teams.blue == Config.MaxPlayersPerTeam
end

function ArenaManager:_BroadcastState()
    TriggerClientEvent('arena:stateUpdate', -1, self:GetState())
end

function ArenaManager:_StopRoundTimer()
    if self.roundTimer then
        clearTimeout(self.roundTimer)
        self.roundTimer = nil
    end
end

-- ============================================================
--  HOST CLAIMING  (คนแรกเดินเข้าวง)
-- ============================================================

--- คนแรกที่เดินเข้าวงใดวงหนึ่ง claim เป็น Host ทันที
---@param serverId number
---@param teamId   string  'red' | 'blue'
---@return boolean, string
function ArenaManager:ClaimHost(serverId, teamId)
    -- ยอมรับเฉพาะตอน IDLE
    if self.state ~= STATE.IDLE then
        return false, 'มีผู้เล่นอยู่ในห้องแล้ว'
    end
    if not Config.Teams[teamId] then
        return false, 'ทีมไม่ถูกต้อง'
    end

    self.state    = STATE.CLAIMING
    self.host     = serverId
    self.hostName = GetPlayerName(serverId) or ('Player ' .. serverId)
    self.hostTeam = teamId

    self:_BroadcastState()
    print(string.format('[ARENA] Player %d (%s) claimed host — team: %s',
        serverId, self.hostName, teamId))
    return true, 'คุณเป็น Host! กรุณาตั้งราคาเดิมพัน'
end

--- Host ยกเลิก (ออกจากวงก่อนตั้ง Bet)
---@param serverId number
function ArenaManager:CancelClaim(serverId)
    if self.state ~= STATE.CLAIMING then return end
    if serverId ~= self.host         then return end

    self.state    = STATE.IDLE
    self.host     = nil
    self.hostName = nil
    self.hostTeam = nil
    self:_BroadcastState()
    print(string.format('[ARENA] Player %d cancelled host claim', serverId))
end

-- ============================================================
--  SET BET  (Host ตั้งราคาหลัง claim)
-- ============================================================

--- Host กรอก Bet จาก inputDialog
---@param serverId  number
---@param betAmount number
---@return boolean, string
function ArenaManager:SetHostBet(serverId, betAmount)
    if self.state ~= STATE.CLAIMING then
        return false, 'ไม่อยู่ในสถานะตั้งเดิมพัน'
    end
    if serverId ~= self.host then
        return false, 'เฉพาะ Host เท่านั้นที่ตั้งเดิมพันได้'
    end
    if betAmount < Config.MinBet or betAmount > Config.MaxBet then
        return false, string.format('เดิมพันต้องอยู่ระหว่าง %s – %s',
            Utils.FormatMoney(Config.MinBet), Utils.FormatMoney(Config.MaxBet))
    end

    -- เปลี่ยนเป็น LOBBY
    self.betAmount = betAmount
    self.teams     = { red = {}, blue = {} }
    self.round     = 0
    self.scores    = { red = 0, blue = 0 }
    self.streaks   = {}
    self.bank      = BankClass:New()
    self.state     = STATE.LOBBY

    -- Host join ทีมของตัวเองอัตโนมัติ (หักเงินด้วย)
    local ok, msg = self:JoinTeam(serverId, self.hostTeam, true)
    if not ok then
        -- เงินไม่พอ reset
        self.state    = STATE.IDLE
        self.host     = nil
        self.hostName = nil
        self.hostTeam = nil
        self:_BroadcastState()
        return false, msg
    end

    print(string.format('[ARENA] Lobby open — Host: %s | Team: %s | Bet: $%d',
        self.hostName, self.hostTeam, betAmount))
    return true, string.format('เปิด Lobby! เดิมพัน %s', Utils.FormatMoney(betAmount))
end

-- ============================================================
--  JOIN TEAM
-- ============================================================

--- ผู้เล่นเข้าร่วมทีม (หักเงินทันที)
---@param serverId number
---@param teamId   string
---@param skipStateCheck boolean|nil  ใช้ใน JoinTeam ที่เรียกจาก SetHostBet
---@return boolean, string
function ArenaManager:JoinTeam(serverId, teamId, skipStateCheck)
    if not skipStateCheck and self.state ~= STATE.LOBBY then
        return false, 'ไม่สามารถเข้าร่วมได้ในขณะนี้'
    end
    if not Config.Teams[teamId] then
        return false, 'ทีมไม่ถูกต้อง'
    end
    if self:_GetTeamOf(serverId) then
        return false, 'คุณอยู่ในทีมแล้ว'
    end
    if self:_TeamCount(teamId) >= Config.MaxPlayersPerTeam then
        return false, string.format('%s เต็มแล้ว (%d/%d)',
            Utils.GetTeamLabel(teamId), Config.MaxPlayersPerTeam, Config.MaxPlayersPerTeam)
    end

    local ok = self.bank:Deduct(serverId, self.betAmount)
    if not ok then
        return false, string.format('เงินไม่พอ ต้องการ %s', Utils.FormatMoney(self.betAmount))
    end

    table.insert(self.teams[teamId], serverId)
    self.streaks[serverId] = 0

    if self:_AllPlayersReady() then
        self.state = STATE.READY
    end

    self:_BroadcastState()
    print(string.format('[ARENA] Player %d joined team %s (%d/%d)',
        serverId, teamId, self:_TeamCount(teamId), Config.MaxPlayersPerTeam))
    return true, string.format('เข้าร่วม %s สำเร็จ!', Utils.GetTeamLabel(teamId))
end

-- ============================================================
--  START GAME  (Host only)
-- ============================================================

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

-- ============================================================
--  ROUND LOGIC
-- ============================================================

function ArenaManager:_StartRound()
    self:_StopRoundTimer()

    for _, sid in ipairs(self.teams.red) do
        TriggerClientEvent('arena:spawnInArena', sid, 'red', self.round)
    end
    for _, sid in ipairs(self.teams.blue) do
        TriggerClientEvent('arena:spawnInArena', sid, 'blue', self.round)
    end

    TriggerClientEvent('arena:roundStart', -1, {
        round    = self.round,
        duration = Config.RoundDuration,
        scores   = self.scores,
        streaks  = self.streaks,
    })
    print(string.format('[ARENA] Round %d/%d started', self.round, Config.TotalRounds))

    self.roundTimer = setTimeout(Config.RoundDuration * 1000, function()
        self:_OnRoundTimeout()
    end)
end

--- ผู้เล่นตาย
---@param deadId   number
---@param killerId number|nil
function ArenaManager:OnPlayerDied(deadId, killerId)
    if self.state ~= STATE.PLAYING then return end

    local deadTeam   = self:_GetTeamOf(deadId)
    if not deadTeam then return end

    -- Streak ผู้ฆ่า
    if killerId and killerId ~= deadId then
        local killerTeam = self:_GetTeamOf(killerId)
        if killerTeam and killerTeam ~= deadTeam then
            self.streaks[killerId] = (self.streaks[killerId] or 0) + 1
            TriggerClientEvent('arena:streakUpdate', killerId, self.streaks[killerId])
            print(string.format('[ARENA] Player %d streak: %d', killerId, self.streaks[killerId]))
        end
    end

    -- รีเซ็ต Streak ผู้ตาย
    self.streaks[deadId] = 0

    -- เด้งออก
    TriggerClientEvent('arena:eliminated', deadId, {})
    self:_RemoveFromTeam(deadId)
    self:_CheckRoundEnd()
end

function ArenaManager:_CheckRoundEnd()
    local r = #self.teams.red
    local b = #self.teams.blue

    if r == 0 and b == 0 then
        self:_EndRound(nil)
    elseif r == 0 then
        self.scores.blue = self.scores.blue + 1
        self:_EndRound('blue')
    elseif b == 0 then
        self.scores.red = self.scores.red + 1
        self:_EndRound('red')
    end
end

function ArenaManager:_OnRoundTimeout()
    local r = #self.teams.red
    local b = #self.teams.blue
    if     r > b then self.scores.red  = self.scores.red  + 1; self:_EndRound('red')
    elseif b > r then self.scores.blue = self.scores.blue + 1; self:_EndRound('blue')
    else               self:_EndRound(nil)
    end
end

---@param winnerTeam string|nil
function ArenaManager:_EndRound(winnerTeam)
    self:_StopRoundTimer()
    local label = winnerTeam and Utils.GetTeamLabel(winnerTeam) or 'เสมอ'
    print(string.format('[ARENA] Round %d ended — %s (🔴%d 🔵%d)',
        self.round, label, self.scores.red, self.scores.blue))

    TriggerClientEvent('arena:roundEnd', -1, {
        round      = self.round,
        winnerTeam = winnerTeam,
        scores     = self.scores,
        streaks    = self.streaks,
    })

    if self.round >= Config.TotalRounds then
        setTimeout(5000, function() self:_EndGame() end)
    else
        setTimeout(10000, function()
            self.round = self.round + 1
            self.state = STATE.LOBBY
            if self:_AllPlayersReady() then
                self.state = STATE.READY
            end
            self:_BroadcastState()
            TriggerClientEvent('arena:waitingForRejoin', -1, { round = self.round })
        end)
    end
end

-- ============================================================
--  REJOIN  (ผู้แพ้ rejoin หลัง round จบ)
-- ============================================================

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

    local ok = self.bank:Deduct(serverId, self.betAmount)
    if not ok then
        return false, string.format('เงินไม่พอ Rejoin ต้องการ %s', Utils.FormatMoney(self.betAmount))
    end

    table.insert(self.teams[teamId], serverId)
    self.streaks[serverId] = 0

    if self:_AllPlayersReady() then
        self.state = STATE.READY
        if self.host and self:_GetTeamOf(self.host) then
            self:StartGame(self.host)
        end
    end

    self:_BroadcastState()
    return true, 'Rejoin สำเร็จ! Streak รีเซ็ต'
end

-- ============================================================
--  END GAME
-- ============================================================

function ArenaManager:_EndGame()
    self.state = STATE.ENDED

    local winnerTeam
    if     self.scores.red  > self.scores.blue then winnerTeam = 'red'
    elseif self.scores.blue > self.scores.red  then winnerTeam = 'blue'
    end

    local winnerIds = winnerTeam and self.teams[winnerTeam] or {}
    if #winnerIds > 0 then
        self.bank:Distribute(winnerIds)
    else
        self.bank:RefundAll()
    end

    TriggerClientEvent('arena:gameEnd', -1, {
        winnerTeam = winnerTeam,
        scores     = self.scores,
        streaks    = self.streaks,
        pool       = self.bank:GetPool(),
    })

    print(string.format('[ARENA] Game ended! Winner: %s (🔴%d 🔵%d)',
        winnerTeam or 'Draw', self.scores.red, self.scores.blue))

    setTimeout(15000, function() self:Reset() end)
end

-- ============================================================
--  RESET
-- ============================================================

function ArenaManager:Reset()
    self:_StopRoundTimer()
    if self.bank then self.bank:RefundAll() end
    self.state     = STATE.IDLE
    self.host      = nil
    self.hostName  = nil
    self.hostTeam  = nil
    self.betAmount = 0
    self.teams     = { red = {}, blue = {} }
    self.round     = 0
    self.scores    = { red = 0, blue = 0 }
    self.streaks   = {}
    self.bank      = BankClass:New()
    self.roundTimer = nil
    self:_BroadcastState()
    print('[ARENA] Arena reset.')
end

-- ============================================================
--  GET STATE  (snapshot สำหรับส่ง client)
-- ============================================================

function ArenaManager:GetState()
    return {
        state     = self.state,
        host      = self.host,
        hostName  = self.hostName,
        hostTeam  = self.hostTeam,
        betAmount = self.betAmount,
        teamRed   = self.teams.red,
        teamBlue  = self.teams.blue,
        round     = self.round,
        scores    = self.scores,
        streaks   = self.streaks,
        pool      = self.bank:GetPool(),
    }
end
