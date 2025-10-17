-- GoldLedger: Analytics UI (v1.6 – with Fixed Minimap Button)
------------------------------------------------------------
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger

local frame, scroll, listParent, totalRow, minimapButton
local summaryRows, historyRows = {}, {}
local currentTab = GoldLedgerDB and GoldLedgerDB.settings and GoldLedgerDB.settings.lastTab or "summary"

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function fmtTime(ts)
    local d = date("*t", ts)
    return string.format("%04d-%02d-%02d %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
end

local function calcGPH(cd)
    if not cd or not cd.session then return "0g/h", "0g/h" end
    local now = time()
    local sesDur = max(1, now - (cd.session.start or now))
    local totalDur = max(1, now - (cd.firstSeen or now))
    local sesEarn = (cd.session.earned or 0) - (cd.session.spent or 0)
    local totalEarn = (cd.earned or 0) - (cd.spent or 0)
    local sesRate = (sesEarn / sesDur) * 3600
    local totalRate = (totalEarn / totalDur) * 3600
    return string.format("%s/h", addon:FormatMoney(sesRate)), string.format("%s/h", addon:FormatMoney(totalRate))
end

------------------------------------------------------------
-- Frame Creation
------------------------------------------------------------
local function CreateMainFrame()
    if frame then return end

    frame = CreateFrame("Frame", "GoldLedgerUI_Frame", UIParent)
    frame:SetSize(460, 420)
    frame:SetPoint("CENTER")
    frame:SetResizable(true)
    frame:SetMinResize(320, 240)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("GoldLedger")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Tabs
    frame.summaryTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.summaryTab:SetSize(100, 24)
    frame.summaryTab:SetPoint("TOPLEFT", 20, -36)
    frame.summaryTab:SetText("Summary")

    frame.historyTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyTab:SetSize(100, 24)
    frame.historyTab:SetPoint("LEFT", frame.summaryTab, "RIGHT", 6, 0)
    frame.historyTab:SetText("History")

    frame.summaryTab:SetScript("OnClick", function()
        currentTab = "summary"
        _G.GoldLedgerUI_Refresh()
    end)
    frame.historyTab:SetScript("OnClick", function()
        currentTab = "history"
        _G.GoldLedgerUI_Refresh()
    end)

    frame.totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.totalText:SetPoint("TOPLEFT", 16, -70)
    frame.sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.sessionText:SetPoint("TOPLEFT", 16, -90)

    scroll = CreateFrame("ScrollFrame", "GoldLedgerScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -120)
    scroll:SetPoint("BOTTOMRIGHT", -36, 36)

    listParent = CreateFrame("Frame", nil, scroll)
    listParent:SetSize(1, 1)
    scroll:SetScrollChild(listParent)

    -- Headers
    local headers = {
        { text = "Character", width = 260 },
        { text = "Gold (Earned / Spent)", width = 160 },
    }
    local x = 16
    for _, h in ipairs(headers) do
        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", x, -105)
        t:SetWidth(h.width)
        t:SetText(h.text)
        x = x + h.width + 20
    end

    -- Resize handle
    local resize = CreateFrame("Frame", nil, frame)
    resize:SetPoint("BOTTOMRIGHT", -4, 4)
    resize:SetSize(16, 16)
    resize.texture = resize:CreateTexture(nil, "OVERLAY")
    resize.texture:SetAllPoints()
    resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:EnableMouse(true)
    resize:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
end

------------------------------------------------------------
-- Minimap Button (fixed)
------------------------------------------------------------
local function CreateMinimapButton()
    if minimapButton then return end

    GoldLedgerDB.settings = GoldLedgerDB.settings or {}
    if type(GoldLedgerDB.settings.minimapPos) ~= "number" then
        GoldLedgerDB.settings.minimapPos = 45
    end

    minimapButton = CreateFrame("Button", "GoldLedger_MinimapButton", Minimap)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    minimapButton:SetSize(32, 32)
    minimapButton:SetMovable(true)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01") -- visible in 3.3.5
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            _G.GoldLedgerUI_Toggle()
        elseif button == "RightButton" then
            GoldLedgerDB.settings.minimapHidden = not GoldLedgerDB.settings.minimapHidden
            if GoldLedgerDB.settings.minimapHidden then minimapButton:Hide() else minimapButton:Show() end
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffFFD700GoldLedger|r")
        GameTooltip:AddLine("Left-click: Toggle UI")
        GameTooltip:AddLine("Right-click: Hide/Show icon")
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local pos = math.deg(math.atan2(py / scale - my, px / scale - mx))
            GoldLedgerDB.settings.minimapPos = pos

            local rad = math.rad(pos)
            local radius = (Minimap:GetWidth() / 2) + 6
            self:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(rad), radius * math.sin(rad))
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local pos = tonumber(GoldLedgerDB.settings.minimapPos) or 45
    pos = math.rad(pos)
    local radius = (Minimap:GetWidth() / 2) + 6
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(pos), radius * math.sin(pos))

    if GoldLedgerDB.settings.minimapHidden then minimapButton:Hide() end
end

------------------------------------------------------------
-- Row Factories
------------------------------------------------------------
local function CreateSummaryRow(i)
    local row = CreateFrame("Frame", nil, listParent)
    row:SetSize(420, 20)
    if i == 1 then
        row:SetPoint("TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", summaryRows[i - 1], "BOTTOMLEFT", 0, -4)
    end

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(260)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.value:SetWidth(160)

    return row
end

local function CreateHistoryRow(i)
    local line = CreateFrame("Frame", nil, listParent)
    line:SetSize(400, 18)
    if i == 1 then
        line:SetPoint("TOPLEFT", 0, 0)
    else
        line:SetPoint("TOPLEFT", historyRows[i - 1], "BOTTOMLEFT", 0, -4)
    end
    line.txt = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.txt:SetPoint("LEFT", 4, 0)
    return line
end

------------------------------------------------------------
-- Refresh Functions
------------------------------------------------------------
local function RefreshSummary()
    local total = addon:GetTotals()
    local playerKey = addon:GetCharKey()
    local playerData = GoldLedgerDB.characters[playerKey]
    local session = playerData and playerData.session or { earned = 0, spent = 0, start = time() }

    -- clear older lines
    frame.totalText:SetText("")
    frame.sessionText:SetText("")

    -- build nice block text
    local totalBlock = string.format(
        "|cffffff00Total Gold:|r %s  |cff999999(%d chars)|r\n" ..
        "|cff00ff00Earned:|r %s   |cffff5555Spent:|r %s",
        addon:FormatMoney(total.gold), total.chars,
        addon:FormatMoney(total.earned), addon:FormatMoney(total.spent)
    )

    local gphS, gphL = calcGPH(playerData)
    local sessionBlock = string.format(
        "|cffffff00Session – %s|r\n" ..
        "Net: %s    |cffFFD700GPH:|r %s (S)  %s (L)",
        playerKey:gsub(" - Warcraft Reborn", ""),
        addon:FormatMoney((session.earned or 0) - (session.spent or 0)),
        gphS, gphL
    )

    frame.totalText:SetText(totalBlock)
    frame.sessionText:SetText(sessionBlock)

    -- position cleanly
    frame.totalText:ClearAllPoints()
    frame.totalText:SetPoint("TOPLEFT", 16, -65)
    frame.sessionText:ClearAllPoints()
    frame.sessionText:SetPoint("TOPLEFT", 16, -110)

    -- create row list
    local items = {}
    for k, d in addon:IterChars() do
        items[#items + 1] = { key = k, gold = d.gold, earned = d.earned, spent = d.spent }
    end
    table.sort(items, function(a, b) return a.gold > b.gold end)

    for i = #summaryRows + 1, #items do
        local row = CreateFrame("Frame", nil, listParent)
        row:SetSize(400, 18)
        if i == 1 then
            row:SetPoint("TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", summaryRows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
        else
            row.bg:SetColorTexture(0, 0, 0, 0.3)
        end
        row.bg:SetAllPoints()

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetWidth(220)

        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.value:SetWidth(160)

        summaryRows[i] = row
    end

    for i = #items + 1, #summaryRows do summaryRows[i]:Hide() end

    for i, it in ipairs(items) do
        local r = summaryRows[i]
        r:Show()
        r.name:SetText("|cffFFD700" .. it.key:gsub(" - Warcraft Reborn", "") .. "|r")
        r.value:SetText(string.format("%s  |cff00ff00(+%s)|r  |cffff5555(-%s)|r",
            addon:FormatMoney(it.gold),
            addon:FormatMoney(it.earned),
            addon:FormatMoney(it.spent)))
    end
end



local function RefreshHistory()
    local cd = addon:GetCharData()
    local hist = cd.history or {}
    frame.totalText:SetText("|cffFFD700Character:|r " .. addon:GetCharKey())
    frame.sessionText:SetText("Daily Summary View")

    local daily, items = {}, {}
    for _, h in ipairs(hist) do
        local day = date("%Y-%m-%d", h.t)
        daily[day] = daily[day] or { gold = h.gold, first = h, last = h }
        daily[day].first = h
        daily[day].last = daily[day].last or h
    end

    for d, v in pairs(daily) do
        local diff = (v.first.gold or 0) - (v.last.gold or 0)
        items[#items + 1] = { day = d, gold = v.gold, diff = diff }
    end
    table.sort(items, function(a, b) return a.day > b.day end)

    for i = #historyRows + 1, #items do historyRows[i] = CreateHistoryRow(i) end
    for i = #items + 1, #historyRows do historyRows[i]:Hide() end

    for i, it in ipairs(items) do
        local r = historyRows[i]
        r:Show()
        local col = it.diff > 0 and "|cff00ff00" or it.diff < 0 and "|cffff5555" or "|cffffffff"
        r.txt:SetText(string.format("%s  %s  %s%+dg|r",
            it.day, addon:FormatMoney(it.gold), col, math.floor(it.diff / 10000)))
    end
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function _G.GoldLedgerUI_Refresh()
    if not frame or not frame:IsShown() then return end
    for _, r in ipairs(summaryRows) do r:Hide() end
    for _, r in ipairs(historyRows) do r:Hide() end
    if currentTab == "summary" then RefreshSummary() else RefreshHistory() end
    if GoldLedgerDB and GoldLedgerDB.settings then
        GoldLedgerDB.settings.lastTab = currentTab
    end
end

function _G.GoldLedgerUI_Toggle()
    if not frame then CreateMainFrame() end
    if not minimapButton then CreateMinimapButton() end
    if frame:IsShown() then frame:Hide() else
        frame:Show()
        _G.GoldLedgerUI_Refresh()
    end
end
