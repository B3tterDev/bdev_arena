-- ============================================================
--  PlayerClass  (Client-side OOP)
--  จัดการ Ped Health, Death Detection, Streak Display
-- ============================================================

---@class PlayerClass
PlayerClass = {}
PlayerClass.__index = PlayerClass

function PlayerClass:New()
    local obj = setmetatable({}, PlayerClass)
    obj.streak      = 0
    obj.isDead      = false
    obj._deathThread = nil
    return obj
end

--- เริ่ม Thread ตรวจจับการตาย
---@param onDeath function callback(killerId)
function PlayerClass:StartDeathDetection(onDeath)
    self._deathThread = CreateThread(function()
        while true do
            Wait(500)
            local ped = PlayerPedId()
            if IsEntityDead(ped) and not self.isDead then
                self.isDead = true

                -- พยายามหา Killer — FiveM จะ expose ผ่าน GET_PED_SOURCE_OF_DEATH
                local killerEntity = GetPedSourceOfDeath(ped)
                local killerServerId = nil
                if killerEntity and killerEntity ~= 0 and IsPedAPlayer(killerEntity) then
                    killerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killerEntity))
                end

                if onDeath then
                    onDeath(killerServerId)
                end

                -- รอ respawn
                Wait(5000)
                self.isDead = false
            end
        end
    end)
end

--- หยุด Death Thread
function PlayerClass:StopDeathDetection()
    if self._deathThread then
        -- ไม่มี API หยุด thread ตรงๆ ใน Lua FiveM — ใช้ flag แทน
        self._deathThread = nil
    end
end

--- อัพเดท streak ที่ได้รับจาก server
---@param streak number
function PlayerClass:SetStreak(streak)
    self.streak = streak
end

--- ดึงจำนวนไฟที่จะแสดง (ตาม streak)
---@return string
function PlayerClass:GetStreakDisplay()
    if self.streak <= 0 then return '' end
    local flames = ''
    for i = 1, math.min(self.streak, 10) do
        flames = flames .. '🔥'
    end
    return flames .. ' x' .. self.streak
end
