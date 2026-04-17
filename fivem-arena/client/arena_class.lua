-- ============================================================
--  ArenaClass  (Client-side OOP)
--  เก็บ state ของ arena ฝั่ง client และ logic เกี่ยวกับ zone
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
    obj.lobbyBlip   = nil
    obj.arenaBlip   = nil
    obj._lobbyZoneThread = nil
    return obj
end

--- อัพเดทสถานะจาก server
---@param data table
function ArenaClass:ApplyState(data)
    self.state     = data.state or 'idle'
    self.betAmount = data.betAmount or 0
    self.round     = data.round or 0
    self.scores    = data.scores or { red = 0, blue = 0 }
    self.streaks   = data.streaks or {}

    -- ตรวจว่า player นี้อยู่ทีมไหน
    local myId = GetPlayerServerId(PlayerId())
    self.myTeam = nil
    if data.teamRed then
        for _, sid in ipairs(data.teamRed) do
            if sid == myId then self.myTeam = 'red' break end
        end
    end
    if not self.myTeam and data.teamBlue then
        for _, sid in ipairs(data.teamBlue) do
            if sid == myId then self.myTeam = 'blue' break end
        end
    end
    self.isHost = (data.host == myId)
end

--- Spawn ผู้เล่นเข้าวง
---@param teamId string
function ArenaClass:SpawnToArena(teamId)
    local spawn = Config.SpawnPoints[teamId]
    if not spawn then return end

    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    self.inArena = true

    -- เปิด Invincibility ชั่วคราว 3 วิ
    SetEntityInvincible(ped, true)
    SetTimeout(3000, function()
        SetEntityInvincible(ped, false)
    end)
end

--- เด้งออกจากวง (ผู้แพ้)
function ArenaClass:EjectFromArena()
    self.inArena = false
    local ped    = PlayerPedId()
    -- Teleport ไปจุด Lobby
    SetEntityCoords(ped,
        Config.LobbyCenter.x,
        Config.LobbyCenter.y,
        Config.LobbyCenter.z,
        false, false, false, true)
    self.myTeam = nil
end

--- วาด Blip วง Arena + Lobby
function ArenaClass:DrawBlips()
    -- Lobby blip
    if not self.lobbyBlip then
        self.lobbyBlip = AddBlipForCoord(Config.LobbyCenter.x, Config.LobbyCenter.y, Config.LobbyCenter.z)
        SetBlipSprite(self.lobbyBlip, 418)
        SetBlipColour(self.lobbyBlip, 5)
        SetBlipScale(self.lobbyBlip, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Arena Lobby')
        EndTextCommandSetBlipName(self.lobbyBlip)
    end
    -- Arena blip
    if not self.arenaBlip then
        self.arenaBlip = AddBlipForCoord(Config.ArenaCenter.x, Config.ArenaCenter.y, Config.ArenaCenter.z)
        SetBlipSprite(self.arenaBlip, 161)
        SetBlipColour(self.arenaBlip, 1)
        SetBlipScale(self.arenaBlip, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Arena')
        EndTextCommandSetBlipName(self.arenaBlip)
    end
end

--- ลบ Blip
function ArenaClass:RemoveBlips()
    if self.lobbyBlip then RemoveBlip(self.lobbyBlip) self.lobbyBlip = nil end
    if self.arenaBlip  then RemoveBlip(self.arenaBlip)  self.arenaBlip  = nil end
end

--- ตรวจว่าผู้เล่นอยู่ใน Lobby Zone หรือไม่
---@return boolean
function ArenaClass:IsInLobbyZone()
    local ped   = PlayerPedId()
    local coord = GetEntityCoords(ped)
    return Utils.IsInZone(coord, Config.LobbyCenter, Config.LobbyRadius)
end

--- ตรวจว่าผู้เล่นอยู่ใน Arena Zone หรือไม่
---@return boolean
function ArenaClass:IsInArenaZone()
    local ped   = PlayerPedId()
    local coord = GetEntityCoords(ped)
    return Utils.IsInZone(coord, Config.ArenaCenter, Config.ArenaRadius)
end
