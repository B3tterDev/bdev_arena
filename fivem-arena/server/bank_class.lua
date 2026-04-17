-- ============================================================
--  BankClass  (จัดการเงินกองกลาง + หักเงิน + แจกเงิน)
-- ============================================================

---@class BankClass
BankClass = {}
BankClass.__index = BankClass

--- สร้าง instance ของ BankClass
---@return BankClass
function BankClass:New()
    local obj = setmetatable({}, BankClass)
    obj.pool       = 0      -- เงินกองกลาง
    obj.ledger     = {}     -- { [serverId] = amount } บันทึกเงินที่หักไป
    return obj
end

--- หักเงินผู้เล่นเข้ากองกลาง
---@param serverId number
---@param amount   number
---@return boolean success
function BankClass:Deduct(serverId, amount)
    local player = GetPlayerFromServerId(serverId)
    if not player then return false end

    local success = false

    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(serverId)
        if xPlayer and xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            success = true
        end
    elseif Config.Framework == 'qbcore' then
        local xPlayer = QBCore.Functions.GetPlayer(serverId)
        if xPlayer and xPlayer.PlayerData.money['cash'] >= amount then
            xPlayer.Functions.RemoveMoney('cash', amount)
            success = true
        end
    else
        -- standalone: ไม่ตรวจเงิน (ทดสอบ)
        success = true
    end

    if success then
        self.pool = self.pool + amount
        self.ledger[serverId] = (self.ledger[serverId] or 0) + amount
        print(string.format('[ARENA] Deducted $%d from player %d | Pool: $%d', amount, serverId, self.pool))
    end

    return success
end

--- แจกเงินทั้งหมดในกองกลางให้ผู้ชนะ (หารเท่าๆกัน)
---@param winnerIds number[] รายการ serverId ผู้ชนะ
function BankClass:Distribute(winnerIds)
    if #winnerIds == 0 or self.pool <= 0 then return end

    local share = math.floor(self.pool / #winnerIds)

    for _, sid in ipairs(winnerIds) do
        if Config.Framework == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(sid)
            if xPlayer then
                xPlayer.addMoney(share)
                print(string.format('[ARENA] Gave $%d to player %d', share, sid))
            end
        elseif Config.Framework == 'qbcore' then
            local xPlayer = QBCore.Functions.GetPlayer(sid)
            if xPlayer then
                xPlayer.Functions.AddMoney('cash', share)
                print(string.format('[ARENA] Gave $%d to player %d', share, sid))
            end
        else
            print(string.format('[ARENA][Standalone] Would give $%d to player %d', share, sid))
        end

        -- แจ้ง client
        TriggerClientEvent('arena:notify', sid,
            string.format('คุณได้รับ %s จากการแข่งขัน!', Utils.FormatMoney(share)),
            'success')
    end

    print(string.format('[ARENA] Pool distributed: $%d to %d winners', self.pool, #winnerIds))
    self.pool   = 0
    self.ledger = {}
end

--- คืนเงินทุกคนในกรณียกเลิก
function BankClass:RefundAll()
    for sid, amount in pairs(self.ledger) do
        if Config.Framework == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(sid)
            if xPlayer then xPlayer.addMoney(amount) end
        elseif Config.Framework == 'qbcore' then
            local xPlayer = QBCore.Functions.GetPlayer(sid)
            if xPlayer then xPlayer.Functions.AddMoney('cash', amount) end
        end
        TriggerClientEvent('arena:notify', sid,
            string.format('เงินเดิมพัน %s ถูกคืนเนื่องจากเกมยกเลิก', Utils.FormatMoney(amount)),
            'warning')
    end
    self.pool   = 0
    self.ledger = {}
    print('[ARENA] All bets refunded.')
end

--- ดูยอดกองกลางปัจจุบัน
---@return number
function BankClass:GetPool()
    return self.pool
end
