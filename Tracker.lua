-- GoldLedger: Tracker  (handles PLAYER_MONEY deltas)

-- --- SAFE BOOTSTRAP ---
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger
-- -----------------------

local prevMoney = 0

function addon:OnMoneyChanged()
    local cd = addon.GetCharData and addon:GetCharData()
    if not cd then return end

    local now = GetMoney()
    if prevMoney == 0 then
        prevMoney = now
        return
    end

    local diff = now - prevMoney
    if diff ~= 0 then
        if diff > 0 then
            cd.earned = (cd.earned or 0) + diff
            if cd.session then cd.session.earned = (cd.session.earned or 0) + diff end
        else
            local spent = -diff
            cd.spent = (cd.spent or 0) + spent
            if cd.session then cd.session.spent = (cd.session.spent or 0) + spent end
        end
        cd.gold = now
        cd.lastSeen = time()

        if addon._PushHistorySnapshot then addon:_PushHistorySnapshot() end
        if _G.GoldLedgerUI_Refresh then _G.GoldLedgerUI_Refresh() end
        if _G.GoldLedgerHistory_Refresh then _G.GoldLedgerHistory_Refresh() end
        if addon.UpdateLDB then addon:UpdateLDB() end
    end

    prevMoney = now
end
