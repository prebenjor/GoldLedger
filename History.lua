-- GoldLedger: History view (simple timeline list)
local addon = GoldLedger

local histFrame, histScroll, histParent, lines = nil, nil, nil, {}

local function CreateHistory()
    if histFrame then return end
    histFrame = CreateFrame("Frame", "GoldLedgerHistoryFrame", UIParent)
    histFrame:SetSize(420, 360)
    histFrame:SetPoint("CENTER", 460, 0)
    histFrame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
                            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
                            tile=true, tileSize=32, edgeSize=32,
                            insets={left=8,right=8,top=8,bottom=8}})
    histFrame:SetMovable(true)
    histFrame:EnableMouse(true)
    histFrame:RegisterForDrag("LeftButton")
    histFrame:SetScript("OnDragStart", histFrame.StartMoving)
    histFrame:SetScript("OnDragStop", histFrame.StopMovingOrSizing)
    histFrame:Hide()

    local title = histFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("GoldLedger - History")

    local close = CreateFrame("Button", nil, histFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local desc = histFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    desc:SetPoint("TOPLEFT", 16, -40)
    desc:SetText("Recent snapshots (newest first).")

    histScroll = CreateFrame("ScrollFrame", "GoldLedgerHistScroll", histFrame, "UIPanelScrollFrameTemplate")
    histScroll:SetPoint("TOPLEFT", 16, -60)
    histScroll:SetPoint("BOTTOMRIGHT", -36, 16)

    histParent = CreateFrame("Frame", nil, histScroll)
    histParent:SetSize(1, 1)
    histScroll:SetScrollChild(histParent)
end

local function CreateLine(i)
    local line = CreateFrame("Frame", nil, histParent)
    line:SetSize(360, 18)
    if i == 1 then
        line:SetPoint("TOPLEFT", 0, 0)
    else
        line:SetPoint("TOPLEFT", lines[i-1], "BOTTOMLEFT", 0, -6)
    end
    line.txt = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.txt:SetPoint("LEFT", 0, 0)
    line.txt:SetJustifyH("LEFT")
    return line
end

local function fmtTime(ts)
    local d = date("*t", ts)
    return string.format("%04d-%02d-%02d %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
end

function GoldLedgerHistory_Refresh()
    if not histFrame or not histFrame:IsShown() then return end
    for i=1,#lines do lines[i]:Hide() end

    local cd = addon:GetCharData()
    local hist = cd and cd.history or {}
    local items = {}
    for i=1,#hist do items[i] = hist[i] end
    table.sort(items, function(a,b) return (a.t or 0) > (b.t or 0) end)

    local need = #items
    for i = #lines+1, need do lines[i] = CreateLine(i) end
    for i = need+1, #lines do lines[i]:Hide() end

    for i, it in ipairs(items) do
        local ln = lines[i]; ln:Show()
        local reason = it.reason and (" ("..it.reason..")") or ""
        ln.txt:SetText(string.format("%s  -  %s%s",
            fmtTime(it.t or 0), addon:FormatMoney(it.gold or 0), reason))
    end
    histParent:SetHeight(need * 24)
end

function GoldLedgerHistory_Show()
    if not histFrame then CreateHistory() end
    if histFrame:IsShown() then histFrame:Hide() else histFrame:Show(); GoldLedgerHistory_Refresh() end
end
