-- GoldLedger: Tracker  (handles PLAYER_MONEY deltas)

-- --- SAFE BOOTSTRAP ---
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger
-- -----------------------

local prevMoney
local prevChar

function addon:OnMoneyChanged(reason)
    local cd = addon.GetCharData and addon:GetCharData()
    if not cd then return end

    local key = addon.GetCharKey and addon:GetCharKey()
    if key ~= prevChar then
        prevChar = key
        prevMoney = nil
    end

    local now = GetMoney()
    if not prevMoney then
        prevMoney = cd.lastGold or now
    end

    cd.session = cd.session or { start = time(), earned = 0, spent = 0, startGold = prevMoney }

    local diff = now - prevMoney
    if diff ~= 0 then
        if diff > 0 then
            cd.earned = (cd.earned or 0) + diff
            cd.session.earned = (cd.session.earned or 0) + diff
        else
            local spent = -diff
            cd.spent = (cd.spent or 0) + spent
            cd.session.spent = (cd.session.spent or 0) + spent
        end
        cd.gold = now
        cd.lastGold = now
        cd.lastSeen = time()

        if addon._PushHistorySnapshot then addon:_PushHistorySnapshot(reason, now, diff) end
        if _G.GoldLedgerUI_Refresh then _G.GoldLedgerUI_Refresh() end
        if _G.GoldLedgerHistory_Refresh then _G.GoldLedgerHistory_Refresh() end
        if addon.UpdateLDB then addon:UpdateLDB() end
    else
        cd.lastGold = now
    end

    prevMoney = now
end
