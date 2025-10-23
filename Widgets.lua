-- GoldLedger: UI component helpers powered by LibStub
local LibStub = _G.LibStub

if not LibStub then
    local registry, versions = {}, {}
    LibStub = {}
    function LibStub:NewLibrary(major, minor)
        assert(type(major) == "string", "Bad argument #1 to NewLibrary")
        assert(type(minor) == "number", "Bad argument #2 to NewLibrary")
        local old = versions[major]
        if old and old >= minor then return nil end
        versions[major] = minor
        registry[major] = registry[major] or {}
        return registry[major]
    end
    function LibStub:GetLibrary(major, silent)
        local lib = registry[major]
        if not lib and not silent then
            error(("Library %q does not exist."):format(tostring(major)), 2)
        end
        return lib, versions[major]
    end
    _G.LibStub = LibStub
end

local MAJOR, MINOR = "GoldLedgerWidgets-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib._frameCounter = lib._frameCounter or 0

local unpack = unpack or table.unpack

local backdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

local function CreateFrameWithBackdrop(frameType, name, parent, inherits)
    if backdropTemplate then
        if inherits and inherits ~= "" then
            inherits = inherits .. "," .. backdropTemplate
        else
            inherits = backdropTemplate
        end
    end
    return CreateFrame(frameType, name, parent, inherits)
end

local defaultDialogBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local defaultCardBackdrop = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function lib:CreateDialog(name, parent, opts)
    opts = opts or {}
    local frame = CreateFrameWithBackdrop("Frame", name, parent, opts.inherits)
    frame:SetSize(opts.width or 460, opts.height or 420)
    frame:SetPoint(opts.point or "CENTER", opts.xOfs or 0, opts.yOfs or 0)
    frame:SetResizable(opts.resizable ~= false)
    frame:SetMinResize(opts.minWidth or 320, opts.minHeight or 240)
    frame:SetBackdrop(opts.backdrop or defaultDialogBackdrop)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", opts.titleFont or "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(opts.title or name or "")

    local close
    if opts.noCloseButton ~= true then
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
    end

    if opts.resizable ~= false then
        local handle = CreateFrame("Frame", nil, frame)
        handle:SetPoint("BOTTOMRIGHT", -4, 4)
        handle:SetSize(16, 16)
        local tex = handle:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        handle:EnableMouse(true)
        handle:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
        end)
        handle:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
        end)
        frame.ResizeHandle = handle
    end

    return frame, title, close
end

function lib:CreateCard(parent, opts)
    opts = opts or {}
    local card = CreateFrameWithBackdrop("Frame", nil, parent, opts.inherits)
    card:SetBackdrop(opts.backdrop or defaultCardBackdrop)
    local r, g, b, a = unpack(opts.backdropColor or { 0, 0, 0, 0.8 })
    card:SetBackdropColor(r, g, b, a)
    local br, bg, bb, ba = unpack(opts.backdropBorderColor or { 0.2, 0.2, 0.2, 1 })
    card:SetBackdropBorderColor(br, bg, bb, ba)
    return card
end

function lib:CreateTabButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, 24)
    button:SetText(label or "Tab")
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlight")

    local selectedBG = button:CreateTexture(nil, "BACKGROUND")
    selectedBG:SetAllPoints()
    selectedBG:SetColorTexture(1, 0.85, 0.1, 0.18)
    button._selectedBG = selectedBG

    function button:SetSelected(selected)
        self._selected = selected and true or false
        if self._selectedBG then
            self._selectedBG:SetShown(self._selected)
        end
        local fs = self:GetFontString()
        if fs then
            if self._selected then
                fs:SetTextColor(1, 1, 0.3)
            else
                fs:SetTextColor(1, 0.82, 0)
            end
        end
    end

    button:SetSelected(false)
    return button
end

function lib:CreateScrollList(parent, name)
    lib._frameCounter = lib._frameCounter + 1
    name = name or ("GoldLedgerScroll" .. lib._frameCounter)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    if scroll.SetClipsChildren then
        scroll:SetClipsChildren(true)
    end

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)

    local scrollbar = _G[name .. "ScrollBar"]
    if scrollbar then
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, -16)
        scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 16)
    end

    return scroll, child
end

function lib:CreateRow(parent, width, height, opts)
    opts = opts or {}
    local frameType = opts.interactive == false and "Frame" or "Button"
    local row = CreateFrame(frameType, nil, parent)
    row:SetSize(width or 400, height or 20)
    row._cells = {}
    row._padding = opts.padding or 10
    row._spacing = opts.spacing or 12

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    local bgColor = opts.backgroundColor
    if bgColor then
        row.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    else
        row.bg:SetColorTexture(0, 0, 0, 0.18)
    end
    row.bg:SetAllPoints()

    if frameType == "Button" then
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, opts.highlightAlpha or 0.08)
        highlight:Hide()
        row._highlight = highlight
        row:HookScript("OnEnter", function(self)
            if self._highlight then self._highlight:Show() end
        end)
        row:HookScript("OnLeave", function(self)
            if self._highlight then self._highlight:Hide() end
        end)
    end

    function row:SetStripe(isAlternate)
        if isAlternate then
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.45)
        else
            row.bg:SetColorTexture(0.04, 0.04, 0.04, 0.35)
        end
    end

    function row:AddCell(width, font, justify)
        local cell = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        cell:SetJustifyH(justify or "LEFT")
        cell:SetHeight(height or 20)
        local index = #row._cells + 1
        if index == 1 then
            cell:SetPoint("LEFT", row, "LEFT", row._padding, 0)
        else
            local previous = row._cells[index - 1]
            cell:SetPoint("LEFT", previous, "RIGHT", row._spacing, 0)
        end
        if width then
            cell:SetWidth(width)
        end
        row._cells[index] = cell
        return cell
    end

    return row
end

function lib:AttachTooltip(frame, provider)
    if type(provider) ~= "function" then return end
    frame:HookScript("OnEnter", function(self)
        local info = provider(self)
        if not info then return end
        local anchor = info.anchor or "ANCHOR_LEFT"
        GameTooltip:SetOwner(self, anchor)
        GameTooltip:ClearLines()
        if info.title then
            GameTooltip:AddLine(info.title)
        end
        if info.lines then
            for _, line in ipairs(info.lines) do
                GameTooltip:AddLine(line)
            end
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        if GameTooltip:IsShown() then
            GameTooltip:Hide()
        end
    end)
end

function lib:CreateMinimapButton(name, opts)
    opts = opts or {}
    local parent = opts.parent or _G.Minimap
    local button = CreateFrame("Button", name, parent)
    button:SetFrameStrata(opts.frameStrata or "MEDIUM")
    button:SetFrameLevel((parent and parent:GetFrameLevel() or 0) + (opts.frameLevelOffset or 10))
    button:SetSize(opts.size or 32, opts.size or 32)
    button:SetMovable(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("AnyUp")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(opts.iconSize or 20, opts.iconSize or 20)
    icon:SetPoint("CENTER")
    button.Icon = icon

    local function getAngle()
        if opts.getPosition then
            return opts.getPosition()
        end
        return opts.position
    end

    function button:UpdatePosition(angle)
        if angle then
            opts.position = angle
            if opts.onPositionChanged then
                opts.onPositionChanged(angle)
            end
        else
            angle = getAngle()
        end
        angle = tonumber(angle) or 45
        local radius = ((parent and parent:GetWidth() or 140) / 2) + (opts.radiusOffset or 6)
        local rad = math.rad(angle)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
    end

    function button:RefreshVisibility()
        local hidden = opts.isHidden and opts.isHidden()
        if hidden then
            self:Hide()
        else
            self:Show()
        end
        return hidden
    end

    button:HookScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(btn)
            local mx, my = parent:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            btn:UpdatePosition(angle)
        end)
    end)

    button:HookScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if opts.onPositionChanged then
            opts.onPositionChanged(getAngle())
        end
    end)

    if opts.tooltipProvider then
        lib:AttachTooltip(button, opts.tooltipProvider)
    end

    return button
end

return lib
