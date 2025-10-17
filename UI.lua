-- GoldLedger: Analytics UI (v1.7 – Library-driven components)
------------------------------------------------------------
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger

local LibStub = _G.LibStub
local Widgets = LibStub and LibStub("GoldLedgerWidgets-1.0")
if not Widgets then
    error("GoldLedgerWidgets-1.0 is required by GoldLedger")
end

local max, abs = math.max, math.abs

local frame, scroll, listParent, minimapButton
local summaryRows, historyRows = {}, {}
local currentTab = GoldLedgerDB and GoldLedgerDB.settings and GoldLedgerDB.settings.lastTab or "summary"

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function CleanName(key)
    return (key or ""):gsub(" - Warcraft Reborn", "")
end

local function FormatSignedMoney(amount)
    local value = addon:FormatMoney(abs(amount or 0))
    if not amount or amount == 0 then
        return value
    elseif amount > 0 then
        return "+" .. value
    else
        return "-" .. value
    end
end

local function UpdateListHeight(rows)
    if not listParent then return end
    local shown, rowHeight = 0, 20
    for _, row in ipairs(rows) do
        if row:IsShown() then
            shown = shown + 1
            rowHeight = row:GetHeight() or rowHeight
        end
    end
    local spacing = 4
    local totalHeight = shown > 0 and (shown * rowHeight + (shown - 1) * spacing) or rowHeight
    listParent:SetHeight(totalHeight)
    if scroll and scroll.UpdateScrollChildRect then
        scroll:UpdateScrollChildRect()
    end
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
-- UI Construction
------------------------------------------------------------
local function CreateMainFrame()
    if frame then return end

    frame = Widgets:CreateDialog("GoldLedgerUI_Frame", UIParent, {
        title = "GoldLedger",
        width = 500,
        height = 460,
        minWidth = 360,
        minHeight = 260,
    })

    local function selectTab(tab)
        currentTab = tab
        _G.GoldLedgerUI_Refresh()
    end

    frame.summaryTab = Widgets:CreateTabButton(frame, "Summary", 120)
    frame.summaryTab:SetPoint("TOPLEFT", 18, -38)
    frame.summaryTab:SetScript("OnClick", function()
        selectTab("summary")
    end)

    frame.historyTab = Widgets:CreateTabButton(frame, "History", 120)
    frame.historyTab:SetPoint("LEFT", frame.summaryTab, "RIGHT", 8, 0)
    frame.historyTab:SetScript("OnClick", function()
        selectTab("history")
    end)

    frame.infoCard = Widgets:CreateCard(frame, { backdropColor = { 0, 0, 0, 0.85 } })
    frame.infoCard:SetPoint("TOPLEFT", 16, -72)
    frame.infoCard:SetPoint("TOPRIGHT", -16, -72)
    frame.infoCard:SetHeight(96)

    frame.totalText = frame.infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.totalText:SetPoint("TOPLEFT", 14, -12)
    frame.totalText:SetPoint("TOPRIGHT", -14, -12)
    frame.totalText:SetJustifyH("LEFT")

    frame.sessionText = frame.infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sessionText:SetPoint("TOPLEFT", frame.totalText, "BOTTOMLEFT", 0, -8)
    frame.sessionText:SetPoint("TOPRIGHT", frame.totalText, "BOTTOMRIGHT", 0, -8)
    frame.sessionText:SetJustifyH("LEFT")

    frame.headerAnchor = CreateFrame("Frame", nil, frame)
    frame.headerAnchor:SetPoint("TOPLEFT", frame.infoCard, "BOTTOMLEFT", 0, -10)
    frame.headerAnchor:SetPoint("TOPRIGHT", frame.infoCard, "BOTTOMRIGHT", 0, -10)
    frame.headerAnchor:SetHeight(18)

    frame.headers = {}
    frame.headers.summary = Widgets:CreateRow(frame, 420, 18, {
        interactive = false,
        padding = 14,
        spacing = 40,
        backgroundColor = { 0.08, 0.08, 0.08, 0.75 },
    })
    frame.headers.summary:SetPoint("TOPLEFT", frame.headerAnchor, "TOPLEFT")
    frame.headers.summary:SetPoint("TOPRIGHT", frame.headerAnchor, "TOPRIGHT")
    frame.headers.summary:AddCell(260, "GameFontHighlightSmall"):SetText("Character")
    frame.headers.summary:AddCell(160, "GameFontHighlightSmall", "RIGHT"):SetText("Balance / Flow")

    frame.headers.history = Widgets:CreateRow(frame, 420, 18, {
        interactive = false,
        padding = 14,
        spacing = 40,
        backgroundColor = { 0.08, 0.08, 0.08, 0.75 },
    })
    frame.headers.history:SetPoint("TOPLEFT", frame.headerAnchor, "TOPLEFT")
    frame.headers.history:SetPoint("TOPRIGHT", frame.headerAnchor, "TOPRIGHT")
    frame.headers.history:AddCell(150, "GameFontHighlightSmall"):SetText("Day")
    frame.headers.history:AddCell(140, "GameFontHighlightSmall"):SetText("Balance")
    frame.headers.history:AddCell(120, "GameFontHighlightSmall", "RIGHT"):SetText("Net Change")
    frame.headers.history:Hide()

    scroll, listParent = Widgets:CreateScrollList(frame, "GoldLedgerScroll")
    scroll:SetPoint("TOPLEFT", frame.headerAnchor, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 32)

    listParent:SetPoint("TOPLEFT", 0, 0)
    listParent:SetPoint("TOPRIGHT", 0, 0)

    frame.summaryTab:SetSelected(currentTab == "summary")
    frame.historyTab:SetSelected(currentTab == "history")
    frame.headers.summary:SetShown(currentTab == "summary")
    frame.headers.history:SetShown(currentTab == "history")
end

------------------------------------------------------------
-- Row Factories
------------------------------------------------------------
local function AcquireSummaryRow(index)
    if summaryRows[index] then return summaryRows[index] end

    local row = Widgets:CreateRow(listParent, listParent:GetWidth(), 24, { padding = 14 })
    row:SetHeight(24)
    if index == 1 then
        row:SetPoint("TOPLEFT", listParent, "TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", listParent, "TOPRIGHT", 0, 0)
    else
        row:SetPoint("TOPLEFT", summaryRows[index - 1], "BOTTOMLEFT", 0, -4)
        row:SetPoint("TOPRIGHT", summaryRows[index - 1], "BOTTOMRIGHT", 0, -4)
    end

    row.name = row:AddCell(260, "GameFontHighlight")
    row.value = row:AddCell(160, "GameFontHighlightSmall", "RIGHT")

    Widgets:AttachTooltip(row, function(self)
        local data = self.tooltipData
        if not data then return end
        local net = (data.earned or 0) - (data.spent or 0)
        local netColor = net > 0 and "|cff00ff00" or net < 0 and "|cffff5555" or "|cffffffff"
        local netText = addon:FormatMoney(abs(net))
        if net > 0 then
            netText = "+" .. netText
        elseif net < 0 then
            netText = "-" .. netText
        end

        local lines = {
            ("|cff999999Balance|r %s"):format(addon:FormatMoney(data.gold or 0)),
            ("|cff00ff00Earned|r %s"):format(addon:FormatMoney(data.earned or 0)),
            ("|cffff5555Spent|r %s"):format(addon:FormatMoney(data.spent or 0)),
        }

        if data.sessionNet and data.sessionNet ~= 0 then
            local sessionColor = data.sessionNet > 0 and "|cff00ff00" or "|cffff5555"
            local sessionText = addon:FormatMoney(abs(data.sessionNet))
            sessionText = (data.sessionNet > 0 and "+" or "-") .. sessionText
            table.insert(lines, ("|cffFFD700Session Net|r %s%s|r"):format(sessionColor, sessionText))
        end

        table.insert(lines, ("|cffFFFFFFLifetime Net|r %s%s|r"):format(netColor, netText))

        return {
            title = string.format("|cffFFD700%s|r", data.displayName or data.key or ""),
            lines = lines,
        }
    end)

    summaryRows[index] = row
    return row
end

local function AcquireHistoryRow(index)
    if historyRows[index] then return historyRows[index] end

    local row = Widgets:CreateRow(listParent, listParent:GetWidth(), 22, { padding = 14 })
    row:SetHeight(22)
    if index == 1 then
        row:SetPoint("TOPLEFT", listParent, "TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", listParent, "TOPRIGHT", 0, 0)
    else
        row:SetPoint("TOPLEFT", historyRows[index - 1], "BOTTOMLEFT", 0, -4)
        row:SetPoint("TOPRIGHT", historyRows[index - 1], "BOTTOMRIGHT", 0, -4)
    end

    row.day = row:AddCell(150, "GameFontHighlightSmall")
    row.balance = row:AddCell(140, "GameFontHighlightSmall")
    row.change = row:AddCell(120, "GameFontHighlightSmall", "RIGHT")

    Widgets:AttachTooltip(row, function(self)
        local data = self.tooltipData
        if not data then return end
        local diff = data.diff or 0
        local diffColor = diff > 0 and "|cff00ff00" or diff < 0 and "|cffff5555" or "|cffffffff"
        local prefix = diff > 0 and "+" or diff < 0 and "-" or ""
        local netText = addon:FormatMoney(abs(diff))

        return {
            title = string.format("|cffFFD700%s|r", data.day or ""),
            lines = {
                ("Open: %s"):format(addon:FormatMoney(data.open or 0)),
                ("Close: %s"):format(addon:FormatMoney(data.close or data.gold or 0)),
                ("Net: %s%s|r"):format(diffColor, prefix .. netText),
            },
        }
    end)

    historyRows[index] = row
    return row
end

------------------------------------------------------------
-- Refresh Functions
------------------------------------------------------------
local function RefreshSummary()
    local total = addon:GetTotals()
    local playerKey = addon:GetCharKey()
    local playerData = addon:GetCharData(playerKey)
    local session = playerData and playerData.session or { earned = 0, spent = 0, start = time() }

    local totalLines = {
        ("|cffFFD700Total Gold:|r %s"):format(addon:FormatMoney(total.gold)),
        ("|cff00ff00Earned:|r %s   |cffff5555Spent:|r %s"):format(addon:FormatMoney(total.earned), addon:FormatMoney(total.spent)),
        ("|cff999999Tracked Characters:|r %d"):format(total.chars or 0),
    }
    frame.totalText:SetText(table.concat(totalLines, "\n"))

    local sessionNet = (session.earned or 0) - (session.spent or 0)
    local gphSession, gphLifetime = calcGPH(playerData)
    frame.sessionText:SetText(string.format(
        "|cffFFD700%s|r\nSession Net: %s   |cffFFD700GPH:|r %s (session) / %s (lifetime)",
        CleanName(playerKey),
        FormatSignedMoney(sessionNet),
        gphSession,
        gphLifetime
    ))

    local items = {}
    for key, data in addon:IterChars() do
        local entry = {
            key = key,
            displayName = CleanName(key),
            gold = data.gold or 0,
            earned = data.earned or 0,
            spent = data.spent or 0,
            sessionEarned = data.session and data.session.earned or 0,
            sessionSpent = data.session and data.session.spent or 0,
        }
        entry.sessionNet = entry.sessionEarned - entry.sessionSpent
        table.insert(items, entry)
    end

    table.sort(items, function(a, b)
        if a.gold == b.gold then
            return a.displayName < b.displayName
        end
        return a.gold > b.gold
    end)

    for i = #summaryRows + 1, #items do
        AcquireSummaryRow(i)
    end
    for i = #items + 1, #summaryRows do
        summaryRows[i]:Hide()
    end

    for i, entry in ipairs(items) do
        local row = summaryRows[i]
        row:SetStripe(i % 2 == 0)
        row:Show()
        local nameText = entry.displayName
        if entry.key == playerKey then
            nameText = string.format("|cffFFD700%s|r", nameText)
        end
        row.name:SetText(nameText)
        row.value:SetText(string.format("%s  |cff00ff00(+%s)|r  |cffff5555(-%s)|r",
            addon:FormatMoney(entry.gold),
            addon:FormatMoney(entry.earned),
            addon:FormatMoney(entry.spent)
        ))
        row.tooltipData = entry
    end

    UpdateListHeight(summaryRows)
end

local function RefreshHistory()
    local cd = addon:GetCharData()
    local hist = cd.history or {}

    local daily, items = {}, {}
    for _, h in ipairs(hist) do
        if h.t then
            local day = date("%Y-%m-%d", h.t)
            local bucket = daily[day]
            if not bucket then
                bucket = { first = h, last = h }
                daily[day] = bucket
            end
            if not bucket.first or (h.t < (bucket.first.t or h.t)) then
                bucket.first = h
            end
            if not bucket.last or (h.t > (bucket.last.t or h.t)) then
                bucket.last = h
            end
        end
    end

    for d, info in pairs(daily) do
        local firstGold = info.first and info.first.gold or 0
        local lastGold = info.last and info.last.gold or firstGold
        local diff = lastGold - firstGold
        table.insert(items, {
            day = d,
            gold = lastGold,
            open = firstGold,
            close = lastGold,
            diff = diff,
        })
    end

    table.sort(items, function(a, b)
        return a.day > b.day
    end)

    local daysTracked = #items
    local totalNet = 0
    for _, info in ipairs(items) do
        totalNet = totalNet + (info.diff or 0)
    end

    local name = CleanName(addon:GetCharKey())
    if daysTracked > 0 then
        local latest = items[1]
        frame.totalText:SetText(string.format("|cffFFD700%s|r — %s\n|cff999999Tracked days:|r %d",
            name,
            addon:FormatMoney(latest.gold or 0),
            daysTracked
        ))
        frame.sessionText:SetText(string.format("|cff999999Net change across history:|r %s", FormatSignedMoney(totalNet)))
    else
        frame.totalText:SetText(string.format("|cffFFD700%s|r", name))
        frame.sessionText:SetText("|cffaaaaaaNo gold history captured yet.|r")
    end

    for i = #historyRows + 1, #items do
        AcquireHistoryRow(i)
    end
    for i = #items + 1, #historyRows do
        historyRows[i]:Hide()
    end

    for i, info in ipairs(items) do
        local row = historyRows[i]
        row:SetStripe(i % 2 == 0)
        row:Show()
        local diffColor = info.diff > 0 and "|cff00ff00" or info.diff < 0 and "|cffff5555" or "|cffffffff"
        local prefix = info.diff > 0 and "+" or info.diff < 0 and "-" or ""
        local diffText = addon:FormatMoney(abs(info.diff or 0))
        row.day:SetText(info.day)
        row.balance:SetText(addon:FormatMoney(info.gold or 0))
        row.change:SetText(string.format("%s%s|r", diffColor, prefix .. diffText))
        row.tooltipData = info
    end

    UpdateListHeight(historyRows)
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function _G.GoldLedgerUI_Refresh()
    if not frame or not frame:IsShown() then return end

    if frame.summaryTab and frame.summaryTab.SetSelected then
        frame.summaryTab:SetSelected(currentTab == "summary")
    end
    if frame.historyTab and frame.historyTab.SetSelected then
        frame.historyTab:SetSelected(currentTab == "history")
    end
    if frame.headers then
        if frame.headers.summary then frame.headers.summary:SetShown(currentTab == "summary") end
        if frame.headers.history then frame.headers.history:SetShown(currentTab == "history") end
    end

    for _, row in ipairs(summaryRows) do row:Hide() end
    for _, row in ipairs(historyRows) do row:Hide() end

    if currentTab == "summary" then
        RefreshSummary()
    else
        RefreshHistory()
    end

    if GoldLedgerDB and GoldLedgerDB.settings then
        GoldLedgerDB.settings.lastTab = currentTab
    end
end

local function CreateMinimapButton()
    if minimapButton then return end

    GoldLedgerDB.settings = GoldLedgerDB.settings or {}
    local settings = GoldLedgerDB.settings
    if type(settings.minimapPos) ~= "number" then
        settings.minimapPos = 45
    end

    minimapButton = Widgets:CreateMinimapButton("GoldLedger_MinimapButton", {
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        getPosition = function()
            return settings.minimapPos
        end,
        onPositionChanged = function(angle)
            settings.minimapPos = angle
        end,
        isHidden = function()
            return settings.minimapHidden
        end,
        tooltipProvider = function()
            local hidden = settings.minimapHidden
            return {
                title = "|cffFFD700GoldLedger|r",
                lines = {
                    "Left-click: Toggle UI",
                    hidden and "Right-click: Show icon" or "Right-click: Hide icon",
                },
            }
        end,
    })

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            _G.GoldLedgerUI_Toggle()
        elseif button == "RightButton" then
            settings.minimapHidden = not settings.minimapHidden
            minimapButton:RefreshVisibility()
        end
    end)

    minimapButton:RefreshVisibility()
    minimapButton:UpdatePosition()
end

function _G.GoldLedgerUI_Toggle()
    if not frame then CreateMainFrame() end
    if not minimapButton then CreateMinimapButton() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        _G.GoldLedgerUI_Refresh()
    end
end
