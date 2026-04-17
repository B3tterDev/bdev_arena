-- ============================================================
--  UIClass  (Client-side OOP)
--  ox_lib notify + NUI สำหรับ HUD / Result overlay เท่านั้น
-- ============================================================

---@class UIClass
UIClass = {}
UIClass.__index = UIClass

function UIClass:New()
    local obj = setmetatable({}, UIClass)
    obj.hudVisible = false
    return obj
end

-- ============================================================
--  NOTIFY  (ox_lib)
-- ============================================================

--- แสดง notification ผ่าน ox_lib
---@param msg   string
---@param ntype string  'success'|'error'|'warning'|'inform'
---@param title string|nil
function UIClass:Notify(msg, ntype, title)
    -- Map เพื่อให้ตรง ox_lib type
    local typeMap = {
        success = 'success',
        error   = 'error',
        warning = 'warning',
        info    = 'inform',
        inform  = 'inform',
    }
    lib.notify({
        title       = title or 'Arena',
        description = msg,
        type        = typeMap[ntype] or 'inform',
        duration    = 5000,
    })
end

-- ============================================================
--  HUD  (NUI overlay — Score / Round / Countdown / Streak)
-- ============================================================

--- แสดง / อัพเดท HUD Score
---@param round  number
---@param total  number
---@param scores table
function UIClass:ShowRoundInfo(round, total, scores)
    self.hudVisible = true
    SendNUIMessage({
        action = 'roundInfo',
        round  = round,
        total  = total,
        scores = scores,
    })
end

--- เริ่ม Countdown บน HUD
---@param seconds number
function UIClass:StartCountdown(seconds)
    SendNUIMessage({ action = 'countdown', seconds = seconds })
end

--- อัพเดท Streak บน HUD
---@param streak number
function UIClass:UpdateStreak(streak)
    SendNUIMessage({ action = 'updateStreak', streak = streak })
end

--- ซ่อน HUD
function UIClass:HideHUD()
    self.hudVisible = false
    SendNUIMessage({ action = 'hideHUD' })
end

-- ============================================================
--  RESULT OVERLAY  (NUI)
-- ============================================================

--- แสดง Result overlay หลังจบเกม
---@param data table
function UIClass:ShowResult(data)
    SendNUIMessage({ action = 'showResult', data = data })
end

--- ซ่อน Result overlay
function UIClass:HideResult()
    SendNUIMessage({ action = 'hideResult' })
end
