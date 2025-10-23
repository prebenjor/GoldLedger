-- GoldLedger: Core (v1.5 Analytics Edition)
------------------------------------------------------------
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger

GoldLedgerDB = GoldLedgerDB or {}

------------------------------------------------------------
-- Utility
------------------------------------------------------------
local function GetCharKey()
    local name, realm = UnitName("player"), GetRealmName()
    return realm .. "-" .. name
end

function addon:FormatMoney(amount)
    if not amount then return "0g" end

    local negative = amount < 0
    local copper = math.floor(math.abs(amount) + 0.5)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRemainder = copper % 100

    local formatted = string.format("%dg %ds %dc", gold, silver, copperRemainder)
    if negative and copper > 0 then
        formatted = "-" .. formatted
    end

    return formatted
end

------------------------------------------------------------
-- History helpers
------------------------------------------------------------
function addon:_PushHistorySnapshot(reason, newGold, diff)
    local cd = self:GetCharData()
    if not cd then return end

    cd.history = cd.history or {}
    cd.history[#cd.history + 1] = {
        t = time(),
        gold = newGold or cd.gold or GetMoney(),
        reason = reason,
        diff = diff,
    }
end

------------------------------------------------------------
-- DB Init
------------------------------------------------------------
function addon:InitDB()
    GoldLedgerDB.characters = GoldLedgerDB.characters or {}

    local now = GetMoney()
    local function ensureSession(data, baseline)
        data.session = data.session or { start = time(), earned = 0, spent = 0, startGold = baseline }
        data.session.start = data.session.start or time()
        data.session.earned = data.session.earned or 0
        data.session.spent = data.session.spent or 0
        data.session.startGold = data.session.startGold or baseline
    end

    -- Normalize existing records so stale lastGold values don't create false gains.
    for _, data in pairs(GoldLedgerDB.characters) do
        if type(data) == "table" then
            data.gold = data.gold or 0
            if data.lastGold == nil or data.lastGold ~= data.gold then
                data.lastGold = data.gold or 0
            end
            data.earned = data.earned or 0
            data.spent = data.spent or 0
            ensureSession(data, data.lastGold)
            data.history = data.history or {}
            data.firstSeen = data.firstSeen or time()
            data.lastSeen = data.lastSeen or time()
        end
    end

    local key = GetCharKey()
    local char = GoldLedgerDB.characters[key]
    if not char then
        char = {
            gold = now,
            earned = 0,
            spent = 0,
            firstSeen = time(),
            lastSeen = time(),
            lastGold = now,
            session = { start = time(), earned = 0, spent = 0, startGold = now },
            history = {},
        }
        GoldLedgerDB.characters[key] = char
    else
        char.gold = char.gold or now
        char.earned = char.earned or 0
        char.spent = char.spent or 0
        char.firstSeen = char.firstSeen or time()
        char.lastSeen = time()
        char.lastGold = char.lastGold or char.gold or now
        ensureSession(char, char.lastGold)
        char.history = char.history or {}
    end

    GoldLedgerDB.settings = GoldLedgerDB.settings or {
        lastTab = "summary",
        minimapPos = nil
    }

    self.playerKey = key
end

function addon:GetCharKey() return self.playerKey end
function addon:GetCharData(key) return GoldLedgerDB.characters[key or self.playerKey] end
function addon:IterChars() return pairs(GoldLedgerDB.characters or {}) end

------------------------------------------------------------
-- Totals
------------------------------------------------------------
function addon:GetTotals()
    local total = { gold = 0, earned = 0, spent = 0, chars = 0 }
    for _, d in self:IterChars() do
        total.gold = total.gold + (d.gold or 0)
        total.earned = total.earned + (d.earned or 0)
        total.spent = total.spent + (d.spent or 0)
        total.chars = total.chars + 1
    end
    return total
end

------------------------------------------------------------
-- Event Handlers
------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("MAIL_INBOX_UPDATE")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("PLAYER_TRADE_MONEY")

local function RecordEvent(reason)
    if addon.OnMoneyChanged then
        addon:OnMoneyChanged(reason)
        return
    end

    local cd = addon:GetCharData()
    if not cd then return end
    local nowGold = GetMoney()
    if not cd.lastGold then cd.lastGold = nowGold end
    cd.session = cd.session or { start = time(), earned = 0, spent = 0, startGold = cd.lastGold }
    if nowGold ~= cd.lastGold then
        local diff = nowGold - cd.lastGold
        if diff > 0 then
            cd.earned = (cd.earned or 0) + diff
            cd.session.earned = (cd.session.earned or 0) + diff
        else
            cd.spent = (cd.spent or 0) - diff
            cd.session.spent = (cd.session.spent or 0) - diff
        end
        cd.gold = nowGold
        cd.lastGold = nowGold
        cd.lastSeen = time()
        addon:_PushHistorySnapshot(reason, nowGold, diff)

        if _G.GoldLedgerUI_Refresh then _G.GoldLedgerUI_Refresh() end
        if _G.GoldLedgerHistory_Refresh then _G.GoldLedgerHistory_Refresh() end
        if addon.UpdateLDB then addon:UpdateLDB() end
    end
end

f:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGIN" then
        addon:InitDB()
        if addon.InitLDB then addon:InitLDB() end
        RecordEvent("Login")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[GoldLedger]|r Loaded. Use /gold ui")
    elseif e == "PLAYER_MONEY" then
        RecordEvent("Misc")
    elseif e == "MAIL_INBOX_UPDATE" then
        RecordEvent("Mail")
    elseif e == "MERCHANT_SHOW" then
        RecordEvent("Vendor")
    elseif e == "LOOT_OPENED" then
        RecordEvent("Loot")
    elseif e == "PLAYER_TRADE_MONEY" then
        RecordEvent("Trade")
    elseif e == "PLAYER_LOGOUT" then
        RecordEvent("Logout")
    end
end)

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------
SLASH_GOLDLEDGER1 = "/gold"
SlashCmdList["GOLDLEDGER"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "ui" or msg == "show" then
        if _G.GoldLedgerUI_Toggle then _G.GoldLedgerUI_Toggle() end
    elseif msg == "history" then
        if _G.GoldLedgerUI_Toggle then
            _G.GoldLedgerUI_Toggle()
            GoldLedgerDB.settings.lastTab = "history"
        end
    elseif msg == "reset" then
        local cd = addon:GetCharData()
        cd.session = { start = time(), earned = 0, spent = 0, startGold = GetMoney() }
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[GoldLedger]|r Session reset.")
    else
        addon:PrintSummary()
    end
end

function addon:PrintSummary()
    local total = self:GetTotals()
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700== Gold Summary ==")
    for k, d in self:IterChars() do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffff00%s|r: %s (Earned %s / Spent %s)",
            k, self:FormatMoney(d.gold), self:FormatMoney(d.earned), self:FormatMoney(d.spent)))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %s  (E %s / S %s)",
        self:FormatMoney(total.gold), self:FormatMoney(total.earned), self:FormatMoney(total.spent)))
end
