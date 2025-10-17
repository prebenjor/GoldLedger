-- GoldLedger: LibDataBroker support (safe bootstrap)
local addon = _G.GoldLedger
if not addon then
  addon = {}
  _G.GoldLedger = addon
end

local LibStub = _G.LibStub
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
local dataObj


function addon:InitLDB()
    if not ldb then return end
    if dataObj then return end
    dataObj = ldb:NewDataObject("GoldLedger", {
        type = "data source",
        text = "0g",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        OnClick = function(frame, button)
            if button == "LeftButton" then
                if GoldLedgerUI_Toggle then GoldLedgerUI_Toggle() end
            else
                if GoldLedgerHistory_Show then GoldLedgerHistory_Show() end
            end
        end,
        OnTooltipShow = function(tt)
            if not tt or not tt.AddLine then return end
            tt:AddLine("GoldLedger")
            local t = addon:GetTotals()
            tt:AddLine(("Total: %s"):format(addon:FormatMoney(t.gold)))
            for key, data in addon:IterChars() do
                tt:AddLine(("- %s: %s"):format(key, addon:FormatMoney(data.gold or 0)))
            end
            tt:AddLine(" ")
            tt:AddLine("|cffaaaaaaLeft-click: Toggle UI|r")
            tt:AddLine("|cffaaaaaaRight-click: History|r")
        end,
    })
    addon:UpdateLDB()
end

function addon:UpdateLDB()
    if not dataObj then return end
    local t = addon:GetTotals()
    local g = math.floor((t.gold or 0) / 10000)
    dataObj.text = string.format("%dg", g)
end
