-- ============================================================
--  UTILS  (shared helper functions)
-- ============================================================

Utils = {}

--- Format number เป็นรูปแบบ 1,000,000
---@param n number
---@return string
function Utils.FormatMoney(n)
    local s = tostring(math.floor(n))
    local result = ''
    local count = 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i ~= 1 then
            result = ',' .. result
        end
    end
    return '$' .. result
end

--- ตรวจสอบว่าพิกัดอยู่ในวงกลมหรือไม่
---@param point vector3
---@param center vector3
---@param radius number
---@return boolean
function Utils.IsInZone(point, center, radius)
    local dx = point.x - center.x
    local dy = point.y - center.y
    local dz = point.z - center.z
    return math.sqrt(dx*dx + dy*dy + dz*dz) <= radius
end

--- ดึงชื่อทีมตาม id
---@param teamId string
---@return string
function Utils.GetTeamLabel(teamId)
    local t = Config.Teams[teamId]
    return t and t.label or 'ไม่ทราบ'
end

--- ดึงสีทีมตาม id
---@param teamId string
---@return string hex color
function Utils.GetTeamColor(teamId)
    local t = Config.Teams[teamId]
    return t and t.color or '#ffffff'
end
