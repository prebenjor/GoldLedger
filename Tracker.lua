-- GoldLedger: Tracker  (handles PLAYER_MONEY deltas)

-- --- SAFE BOOTSTRAP ---
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger
-- -----------------------

local prevMoney
local prevChar

local function getBaseline(cd, now)
    local baseline = cd and cd.lastGold
    local storedGold = cd and cd.gold

    if storedGold ~= nil then
        if baseline == nil or baseline ~= storedGold then
            baseline = storedGold
        end
    end

    if baseline == nil then
        baseline = now
    end

    return baseline
end

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
        prevMoney = getBaseline(cd, now)
    end

    cd.session = cd.session or { start = time(), earned = 0, spent = 0, startGold = prevMoney }
    if not cd.session.startGold then
        cd.session.startGold = prevMoney
    end

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
        cd.gold = now
        cd.lastGold = now
        cd.lastSeen = time()
    end

    prevMoney = now
end
