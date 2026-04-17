-- ============================================================
--  ArenaClass  (Client-side OOP)
--  จัดการ State + ox_lib Poly Zone + Blip
-- ============================================================

---@class ArenaClass
ArenaClass = {}
ArenaClass.__index = ArenaClass

function ArenaClass:New()
    local obj = setmetatable({}, ArenaClass)
    obj.state       = 'idle'
    obj.myTeam      = nil
    obj.isHost      = false
    obj.betAmount   = 0
    obj.round       = 0
    obj.scores      = { red = 0, blue = 0 }
    obj.streaks     = {}
    obj.inArena     = false
    obj.hostId      = nil
    obj.teamRed     = {}
    obj.teamBlue    = {}
    obj._zoneRed    = nil   -- ox_lib zone handle
    obj._zoneBlue   = nil
    obj._blipRed    = nil
    obj._blipBlue   = nil
    obj._blipArena  = nil
    return obj
end

-- ============================================================
--  STATE
-- ============================================================

--- อัพเดทสถานะจาก server
---@param data table
function ArenaClass:ApplyState(data)
    self.state     = data.state or 'idle'
    self.betAmount = data.betAmount or 0
    self.round     = data.round or 0
    self.scores    = data.scores or { red = 0, blue = 0 }
    self.streaks   = data.streaks or {}
    self.hostId    = data.host
    self.teamRed   = data.teamRed  or {}
    self.teamBlue  = data.teamBlue or {}

    local myId = GetPlayerServerId(PlayerId())
    self.myTeam = nil
    for _, sid in ipairs(self.teamRed)  do if sid == myId then self.myTeam = 'red'  break end end
    for _, sid in ipairs(self.teamBlue) do if sid == myId then self.myTeam = 'blue' break end end
    self.isHost = (self.hostId == myId)
end

--- ดึง snapshot state ปัจจุบัน
---@return table
function ArenaClass:GetSnapshot()
    return {
        state     = self.state,
        betAmount = self.betAmount,
        round     = self.round,
        scores    = self.scores,
        streaks   = self.streaks,
        isHost    = self.isHost,
        myTeam    = self.myTeam,
        teamRed   = self.teamRed,
        teamBlue  = self.teamBlue,
        host      = self.hostId,
    }
end

-- ============================================================
--  SPAWN / EJECT
-- ============================================================

--- Spawn ผู้เล่นเข้าวง
---@param teamId string
function ArenaClass:SpawnToArena(teamId)
    local spawn = Config.SpawnPoints[teamId]
    if not spawn then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    self.inArena = true
    -- Invincible 3 วิ grace period
    SetEntityInvincible(ped, true)
    SetTimeout(3000, function() SetEntityInvincible(ped, false) end)
end

--- เด้งออกจากวง → teleport ไปจุดกลาง
function ArenaClass:EjectFromArena()
    self.inArena = false
    local ped    = PlayerPedId()
    local ep     = Config.EjectPoint
    SetEntityCoords(ped, ep.x, ep.y, ep.z, false, false, false, true)
    self.myTeam = nil
end

-- ============================================================
--  OX_LIB POLY ZONES
-- ============================================================

--- สร้าง Poly Zone สำหรับทั้ง 2 Lobby ด้วย ox_lib
---@param onEnterRed  function
---@param onExitRed   function
---@param onEnterBlue function
---@param onExitBlue  function
function ArenaClass:CreateZones(onEnterRed, onExitRed, onEnterBlue, onExitBlue)
    -- Red Lobby Zone
    self._zoneRed = lib.zones.poly({
        points    = Config.RedLobby.points,
        thickness = Config.RedLobby.thickness,
        onEnter   = function() if onEnterRed then onEnterRed() end end,
        onExit    = function() if onExitRed  then onExitRed()  end end,
    })

    -- Blue Lobby Zone
    self._zoneBlue = lib.zones.poly({
        points    = Config.BlueLobby.points,
        thickness = Config.BlueLobby.thickness,
        onEnter   = function() if onEnterBlue then onEnterBlue() end end,
        onExit    = function() if onExitBlue  then onExitBlue()  end end,
    })
end

--- ลบ Zone ทั้งหมด
function ArenaClass:RemoveZones()
    if self._zoneRed  then self._zoneRed:remove()  self._zoneRed  = nil end
    if self._zoneBlue then self._zoneBlue:remove() self._zoneBlue = nil end
end

-- ============================================================
--  BLIPS
-- ============================================================

function ArenaClass:DrawBlips()
    -- Red Lobby blip
    if not self._blipRed then
        local pts = Config.RedLobby.points
        local cx  = (pts[1].x + pts[3].x) / 2
        local cy  = (pts[1].y + pts[3].y) / 2
        local cz  = pts[1].z
        self._blipRed = AddBlipForCoord(cx, cy, cz)
        SetBlipSprite(self._blipRed, 418)
        SetBlipColour(self._blipRed, 1)   -- red
        SetBlipScale(self._blipRed, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Arena Lobby — ทีมแดง')
        EndTextCommandSetBlipName(self._blipRed)
    end

    -- Blue Lobby blip
    if not self._blipBlue then
        local pts = Config.BlueLobby.points
        local cx  = (pts[1].x + pts[3].x) / 2
        local cy  = (pts[1].y + pts[3].y) / 2
        local cz  = pts[1].z
        self._blipBlue = AddBlipForCoord(cx, cy, cz)
        SetBlipSprite(self._blipBlue, 418)
        SetBlipColour(self._blipBlue, 3)   -- blue
        SetBlipScale(self._blipBlue, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Arena Lobby — ทีมน้ำเงิน')
        EndTextCommandSetBlipName(self._blipBlue)
    end

    -- Arena blip
    if not self._blipArena then
        self._blipArena = AddBlipForCoord(
            Config.ArenaCenter.x, Config.ArenaCenter.y, Config.ArenaCenter.z)
        SetBlipSprite(self._blipArena, 161)
        SetBlipColour(self._blipArena, 49)  -- yellow
        SetBlipScale(self._blipArena, 0.9)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Arena')
        EndTextCommandSetBlipName(self._blipArena)
    end
end

function ArenaClass:RemoveBlips()
    if self._blipRed   then RemoveBlip(self._blipRed)   self._blipRed   = nil end
    if self._blipBlue  then RemoveBlip(self._blipBlue)  self._blipBlue  = nil end
    if self._blipArena then RemoveBlip(self._blipArena) self._blipArena = nil end
end
