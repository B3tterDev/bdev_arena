-- ============================================================
--  UIClass  (Client-side OOP)
--  จัดการ NUI (HTML UI) ทั้งหมด
-- ============================================================

---@class UIClass
UIClass = {}
UIClass.__index = UIClass

function UIClass:New()
    local obj = setmetatable({}, UIClass)
    obj.isOpen = false
    return obj
end

--- เปิด/ปิด NUI
---@param show boolean
function UIClass:SetVisible(show)
    self.isOpen = show
    SetNuiFocus(show, show)
    SendNUIMessage({ action = 'setVisible', visible = show })
end

--- ส่งข้อมูล state ไปอัพเดท UI
---@param data table
function UIClass:UpdateState(data)
    SendNUIMessage({ action = 'updateState', data = data })
end

--- แสดง Notification
---@param msg  string
---@param type string  'success'|'error'|'warning'|'info'
function UIClass:Notify(msg, type)
    SendNUIMessage({ action = 'notify', message = msg, notifType = type or 'info' })
end

--- แสดง Countdown ของ Round
---@param seconds number
function UIClass:StartCountdown(seconds)
    SendNUIMessage({ action = 'countdown', seconds = seconds })
end

--- แสดงผลสรุปเกม
---@param data table
function UIClass:ShowResult(data)
    SendNUIMessage({ action = 'showResult', data = data })
end

--- ซ่อน Result
function UIClass:HideResult()
    SendNUIMessage({ action = 'hideResult' })
end

--- อัพ Streak ของตัวเอง
---@param streak number
function UIClass:UpdateStreak(streak)
    SendNUIMessage({ action = 'updateStreak', streak = streak })
end

--- แสดง Round Info
---@param round   number
---@param total   number
---@param scores  table
function UIClass:ShowRoundInfo(round, total, scores)
    SendNUIMessage({
        action = 'roundInfo',
        round  = round,
        total  = total,
        scores = scores,
    })
end
