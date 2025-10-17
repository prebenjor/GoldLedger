-- GoldLedger: Analytics UI (v1.6 – with Fixed Minimap Button)
------------------------------------------------------------
if not _G.GoldLedger then _G.GoldLedger = {} end
local addon = _G.GoldLedger

local frame, scroll, listParent, totalRow, minimapButton
local summaryRows, historyRows = {}, {}
local currentTab = GoldLedgerDB and GoldLedgerDB.settings and GoldLedgerDB.settings.lastTab or "summary"

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local function UpdateTabVisualState()
    if not frame then return end
    local tabs = {
        { btn = frame.summaryTab, key = "summary" },
        { btn = frame.historyTab, key = "history" },
    }

    for _, tab in ipairs(tabs) do
        if tab.btn then
            local isActive = currentTab == tab.key
            tab.btn.isActive = isActive
            if tab.btn.bg then
                if isActive then
                    tab.btn.bg:SetVertexColor(0.32, 0.24, 0.05, 0.95)
                else
                    tab.btn.bg:SetVertexColor(0.08, 0.08, 0.08, 0.85)
                end
            end
            if tab.btn.underline then
                tab.btn.underline:SetShown(isActive)
            end
            if isActive then
                tab.btn:SetNormalFontObject(GameFontHighlight)
            else
                tab.btn:SetNormalFontObject(GameFontHighlightSmall)
            end
        end
    end
end

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
    frame:SetSize(480, 440)
    frame:SetPoint("CENTER")
    frame:SetResizable(true)
    frame:SetMinResize(340, 260)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 10, right = 10, top = 10, bottom = 10 }
    })
    frame:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.header = frame:CreateTexture(nil, "BACKGROUND")
    frame.header:SetPoint("TOPLEFT", 12, -12)
    frame.header:SetPoint("TOPRIGHT", -12, -12)
    frame.header:SetHeight(64)
    frame.header:SetTexture(WHITE_TEXTURE)
    frame.header:SetGradientAlpha("VERTICAL", 0.28, 0.22, 0.08, 0.95, 0.12, 0.09, 0.03, 0.85)

    frame.inner = frame:CreateTexture(nil, "BACKGROUND")
    frame.inner:SetPoint("TOPLEFT", 12, -82)
    frame.inner:SetPoint("BOTTOMRIGHT", -12, 16)
    frame.inner:SetTexture(WHITE_TEXTURE)
    frame.inner:SetVertexColor(0.02, 0.02, 0.02, 0.85)

    frame.innerBorder = frame:CreateTexture(nil, "BORDER")
    frame.innerBorder:SetPoint("TOPLEFT", frame.inner, -1, 1)
    frame.innerBorder:SetPoint("BOTTOMRIGHT", frame.inner, 1, -1)
    frame.innerBorder:SetTexture(WHITE_TEXTURE)
    frame.innerBorder:SetVertexColor(0.07, 0.07, 0.07, 1)

    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_03")
    frame.logo:SetSize(40, 40)
    frame.logo:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 10, -12)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame.logo, "TOPRIGHT", 10, -6)
    title:SetText("GoldLedger")
    title:SetJustifyH("LEFT")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    frame.subtitle:SetText("Gold & token insights at a glance")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    frame.headerDivider = frame:CreateTexture(nil, "ARTWORK")
    frame.headerDivider:SetTexture(WHITE_TEXTURE)
    frame.headerDivider:SetVertexColor(1, 0.82, 0, 0.4)
    frame.headerDivider:SetPoint("TOPLEFT", frame.inner, "TOPLEFT", 6, 12)
    frame.headerDivider:SetPoint("TOPRIGHT", frame.inner, "TOPRIGHT", -6, 12)
    frame.headerDivider:SetHeight(1)

    -- Tabs
    frame.summaryTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.summaryTab:SetSize(110, 26)
    frame.summaryTab:SetPoint("TOPLEFT", frame.inner, "TOPLEFT", 6, 18)
    frame.summaryTab:SetText("Summary")

    frame.historyTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyTab:SetSize(110, 26)
    frame.historyTab:SetPoint("LEFT", frame.summaryTab, "RIGHT", 8, 0)
    frame.historyTab:SetText("History")

    local function SkinTab(tab)
        tab:SetNormalTexture(nil)
        tab:SetPushedTexture(nil)
        tab:SetDisabledTexture(nil)
        tab:SetNormalFontObject(GameFontHighlightSmall)
        tab:SetHighlightTexture(WHITE_TEXTURE)
        tab:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.2)
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetTexture(WHITE_TEXTURE)
        tab.bg:SetVertexColor(0.08, 0.08, 0.08, 0.85)
        tab.bg:SetAllPoints()
        tab.underline = tab:CreateTexture(nil, "OVERLAY")
        tab.underline:SetTexture(WHITE_TEXTURE)
        tab.underline:SetPoint("BOTTOMLEFT", 4, 0)
        tab.underline:SetPoint("BOTTOMRIGHT", -4, 0)
        tab.underline:SetHeight(2)
        tab.underline:SetVertexColor(1, 0.82, 0, 0.7)
        tab:HookScript("OnEnter", function(self)
            if not self.isActive then
                self.bg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
            end
        end)
        tab:HookScript("OnLeave", function(self)
            if not self.isActive then
                self.bg:SetVertexColor(0.08, 0.08, 0.08, 0.85)
            end
        end)
    end

    SkinTab(frame.summaryTab)
    SkinTab(frame.historyTab)

    frame.summaryTab:SetScript("OnClick", function()
        currentTab = "summary"
        _G.GoldLedgerUI_Refresh()
        UpdateTabVisualState()
    end)
    frame.historyTab:SetScript("OnClick", function()
        currentTab = "history"
        _G.GoldLedgerUI_Refresh()
        UpdateTabVisualState()
    end)

    frame.totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.totalText:SetPoint("TOPLEFT", frame.inner, "TOPLEFT", 10, -8)
    frame.totalText:SetWidth(380)
    frame.totalText:SetJustifyH("LEFT")
    frame.sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sessionText:SetPoint("TOPLEFT", frame.totalText, "BOTTOMLEFT", 0, -8)
    frame.sessionText:SetWidth(380)
    frame.sessionText:SetJustifyH("LEFT")
    frame.sessionText:SetTextColor(0.85, 0.85, 0.85)

    frame.infoDivider = frame:CreateTexture(nil, "ARTWORK")
    frame.infoDivider:SetTexture(WHITE_TEXTURE)
    frame.infoDivider:SetVertexColor(1, 0.82, 0, 0.25)
    frame.infoDivider:SetPoint("TOPLEFT", frame.sessionText, "BOTTOMLEFT", -4, -6)
    frame.infoDivider:SetPoint("TOPRIGHT", frame.sessionText, "BOTTOMRIGHT", 8, -6)
    frame.infoDivider:SetHeight(1)

    scroll = CreateFrame("ScrollFrame", "GoldLedgerScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame.inner, "TOPLEFT", 6, -90)
    scroll:SetPoint("BOTTOMRIGHT", frame.inner, "BOTTOMRIGHT", -24, 6)

    listParent = CreateFrame("Frame", nil, scroll)
    listParent:SetSize(1, 1)
    scroll:SetScrollChild(listParent)

    frame.listBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.listBg:SetPoint("TOPLEFT", scroll, -8, 8)
    frame.listBg:SetPoint("BOTTOMRIGHT", scroll, 22, -8)
    frame.listBg:SetTexture(WHITE_TEXTURE)
    frame.listBg:SetVertexColor(0.04, 0.04, 0.04, 0.85)

    frame.listBorder = frame:CreateTexture(nil, "BORDER")
    frame.listBorder:SetPoint("TOPLEFT", frame.listBg, -1, 1)
    frame.listBorder:SetPoint("BOTTOMRIGHT", frame.listBg, 1, -1)
    frame.listBorder:SetTexture(WHITE_TEXTURE)
    frame.listBorder:SetVertexColor(0.1, 0.1, 0.1, 1)

    frame.footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.footerText:SetPoint("BOTTOMLEFT", frame.inner, "BOTTOMLEFT", 4, 4)
    frame.footerText:SetText("|cff999999Tip: Right-click the minimap coin to hide the icon.|r")

    -- Headers
    local headers = {
        { text = "Character", width = 260 },
        { text = "Gold (Earned / Spent)", width = 160 },
    }
    local x = 20
    for _, h in ipairs(headers) do
        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", frame.listBg, "TOPLEFT", x - 12, -8)
        t:SetWidth(h.width)
        t:SetText(h.text)
        t:SetTextColor(1, 0.82, 0)
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

    UpdateTabVisualState()
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
    row:SetSize(420, 22)
    if i == 1 then
        row:SetPoint("TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", summaryRows[i - 1], "BOTTOMLEFT", 0, -4)
    end

    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE_TEXTURE)
    row.bg:SetVertexColor(0.05, 0.05, 0.05, 0.65)
    row.bg:SetAllPoints()

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetTexture(WHITE_TEXTURE)
    row.stripe:SetAllPoints()
    row.stripe:SetVertexColor(0.08, 0.08, 0.08, 0.55)
    row.stripe:Hide()

    row.highlight = row:CreateTexture(nil, "OVERLAY")
    row.highlight:SetTexture(WHITE_TEXTURE)
    row.highlight:SetVertexColor(1, 0.82, 0, 0.2)
    row.highlight:SetAllPoints()
    row.highlight:SetAlpha(0)

    row:SetScript("OnEnter", function(self)
        self.highlight:SetAlpha(0.35)
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:SetAlpha(0)
    end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 10, 0)
    row.name:SetWidth(260)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.value:SetWidth(160)

    return row
end

local function CreateHistoryRow(i)
    local line = CreateFrame("Frame", nil, listParent)
    line:SetSize(400, 20)
    if i == 1 then
        line:SetPoint("TOPLEFT", 0, 0)
    else
        line:SetPoint("TOPLEFT", historyRows[i - 1], "BOTTOMLEFT", 0, -4)
    end
    line:EnableMouse(true)

    line.bg = line:CreateTexture(nil, "BACKGROUND")
    line.bg:SetTexture(WHITE_TEXTURE)
    line.bg:SetVertexColor(0.04, 0.04, 0.04, 0.6)
    line.bg:SetAllPoints()

    line.highlight = line:CreateTexture(nil, "OVERLAY")
    line.highlight:SetTexture(WHITE_TEXTURE)
    line.highlight:SetVertexColor(0.5, 0.42, 0.13, 0.25)
    line.highlight:SetAllPoints()
    line.highlight:SetAlpha(0)

    line:SetScript("OnEnter", function(self)
        self.highlight:SetAlpha(0.35)
    end)
    line:SetScript("OnLeave", function(self)
        self.highlight:SetAlpha(0)
    end)

    line.txt = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.txt:SetPoint("LEFT", 10, 0)
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
        "|TInterface\\Icons\\INV_Misc_Coin_01:18:18:0:0|t |cffffff00Total Gold|r  %s  |cff999999(%d chars)|r\n" ..
        "|TInterface\\Icons\\INV_Misc_Bag_10:16:16:0:0|t |cff00ff00Earned:|r %s    |TInterface\\Icons\\INV_Misc_Coin_10:16:16:0:0|t |cffff5555Spent:|r %s",
        addon:FormatMoney(total.gold), total.chars,
        addon:FormatMoney(total.earned), addon:FormatMoney(total.spent)
    )

    local gphS, gphL = calcGPH(playerData)
    local sessionBlock = string.format(
        "|TInterface\\Icons\\INV_Misc_Coin_04:18:18:0:0|t |cffffff00Session – %s|r\n" ..
        "|cffFFD700Net:|r %s    |cffFFD700GPH:|r %s (S)  %s (L)",
        playerKey:gsub(" - Warcraft Reborn", ""),
        addon:FormatMoney((session.earned or 0) - (session.spent or 0)),
        gphS, gphL
    )

    frame.totalText:SetText(totalBlock)
    frame.sessionText:SetText(sessionBlock)

    -- position cleanly
    frame.totalText:ClearAllPoints()
    frame.totalText:SetPoint("TOPLEFT", frame.inner, "TOPLEFT", 10, -8)
    frame.sessionText:ClearAllPoints()
    frame.sessionText:SetPoint("TOPLEFT", frame.totalText, "BOTTOMLEFT", 0, -8)

    -- create row list
    local items = {}
    for k, d in addon:IterChars() do
        items[#items + 1] = { key = k, gold = d.gold, earned = d.earned, spent = d.spent }
    end
    table.sort(items, function(a, b) return a.gold > b.gold end)

    for i = #summaryRows + 1, #items do summaryRows[i] = CreateSummaryRow(i) end

    for i = #items + 1, #summaryRows do summaryRows[i]:Hide() end

    for i, it in ipairs(items) do
        local r = summaryRows[i]
        r:Show()
        if r.stripe then
            if i % 2 == 0 then
                r.stripe:Show()
            else
                r.stripe:Hide()
            end
        end
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
    frame.totalText:SetText("|TInterface\\Icons\\INV_Misc_Bag_10:18:18:0:0|t |cffFFD700Character:|r " .. addon:GetCharKey())
    frame.sessionText:SetText("|cffFFD700Daily Summary View|r")

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
            bucket.gold = bucket.last.gold or h.gold
        end
    end

    for d, v in pairs(daily) do
        local firstGold = v.first and v.first.gold or 0
        local lastGold = v.last and v.last.gold or firstGold
        local diff = lastGold - firstGold
        items[#items + 1] = { day = d, gold = lastGold, diff = diff }
    end
    table.sort(items, function(a, b) return a.day > b.day end)

    for i = #historyRows + 1, #items do historyRows[i] = CreateHistoryRow(i) end
    for i = #items + 1, #historyRows do historyRows[i]:Hide() end

    for i, it in ipairs(items) do
        local r = historyRows[i]
        r:Show()
        if i % 2 == 0 then
            r.bg:SetVertexColor(0.05, 0.05, 0.05, 0.55)
        else
            r.bg:SetVertexColor(0.04, 0.04, 0.04, 0.6)
        end
        local col = it.diff > 0 and "|cff00ff00" or it.diff < 0 and "|cffff5555" or "|cffffffff"
        local diffText = addon:FormatMoney(math.abs(it.diff))
        if it.diff >= 0 then
            diffText = "+" .. diffText
        else
            diffText = "-" .. diffText
        end
        r.txt:SetText(string.format("%s  %s  %s%s|r",
            it.day, addon:FormatMoney(it.gold), col, diffText))
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
        UpdateTabVisualState()
        _G.GoldLedgerUI_Refresh()
    end
end
