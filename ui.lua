local TIP = TurnInPlanner

TIP.UI = {}

local UI = TIP.UI

local function roundValue(value)
    if not value then
        return 0
    end
    return floor(value + 0.5)
end

local function setBackdrop(frame, bgR, bgG, bgB, borderR, borderG, borderB)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    frame:SetBackdropColor(bgR, bgG, bgB, 0.88)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
end

local function createText(parent, size, r, g, b, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, size)
    text:SetTextColor(r or 1, g or 1, b or 1)
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function createButton(name, parent, width, height, label)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(label)
    return button
end

local function createSection(parent, left, top, width, height, title)
    local section = CreateFrame("Frame", nil, parent)
    section:SetWidth(width)
    section:SetHeight(height)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
    setBackdrop(section, 0.08, 0.08, 0.08, 0.28, 0.28, 0.28)

    local label = createText(section, 12, 1, 0.82, 0.2)
    label:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -8)
    label:SetText(title)

    return section
end

local function createRow(parent, columns, yOffset)
    local row = {}
    local index
    for index = 1, getn(columns) do
        local cell = createText(parent, 11, 1, 1, 1)
        cell:SetWidth(columns[index].width)
        cell:SetPoint("TOPLEFT", parent, "TOPLEFT", columns[index].x, yOffset)
        row[index] = cell
    end
    return row
end

function UI:UpdateStatus()
    if not self.frame then
        return
    end
    self.statusValue:SetText(TIP:GetStatusText())
    self.modeValue:SetText(TIP:GetModeStatusText())
end

function UI:UpdateControls()
    if not self.frame then
        return
    end

    if TIP:IsAuctionOpen() and not TIP.state.scanInProgress then
        self.refreshButton:Enable()
    else
        self.refreshButton:Disable()
    end

    if not TIP.state.scanInProgress then
        self.recalculateButton:Enable()
    else
        self.recalculateButton:Disable()
    end
end

function UI:RefreshDropdown()
    local dataset = TIP:GetDataset()
    if not dataset then
        return
    end

    UIDropDownMenu_Initialize(self.targetDropDown, function()
        local index
        for index = 1, getn(dataset.targets) do
            local selectedIndex = index
            local info = {}
            info.text = dataset.targets[selectedIndex].name
            info.func = function()
                UIDropDownMenu_SetSelectedID(UI.targetDropDown, selectedIndex)
                TIP:SetSelectedTargetIndex(selectedIndex)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetWidth(150, self.targetDropDown)
    UIDropDownMenu_SetSelectedID(self.targetDropDown, TIP:GetSelectedTargetIndex())
end

function UI:RefreshStrategyDropdown()
    local options = {
        { id = "cheapest", text = TIP.L.StrategyCheapest },
        { id = "bulk20", text = TIP.L.StrategyBulk20 },
        { id = "single1", text = TIP.L.StrategySingle1 },
    }

    UIDropDownMenu_Initialize(self.strategyDropDown, function()
        local index
        for index = 1, getn(options) do
            local option = options[index]
            local selectedIndex = index
            local selectedId = option.id
            local info = {}
            info.text = option.text
            info.func = function()
                UIDropDownMenu_SetSelectedID(UI.strategyDropDown, selectedIndex)
                TIP:SetStrategy(selectedId)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetWidth(140, self.strategyDropDown)

    local selected = TIP:GetStrategy()
    local index
    for index = 1, getn(options) do
        if options[index].id == selected then
            UIDropDownMenu_SetSelectedID(self.strategyDropDown, index)
            return
        end
    end
    UIDropDownMenu_SetSelectedID(self.strategyDropDown, 1)
end

function UI:RenderSummary()
    local solution = TIP.state.solution
    local dataset = TIP:GetDataset()

    self.summaryTarget:SetText(TIP.L.SummaryTarget .. ": " .. (TIP.state.targetValue or 0) .. " " .. (dataset and dataset.unitLabel or ""))

    if not solution then
        self.summaryAchieved:SetText(TIP.L.SummaryAchieved .. ": " .. TIP.L.NoRows)
        self.summaryOvershoot:SetText(TIP.L.SummaryOvershoot .. ": " .. TIP.L.NoRows)
        self.summaryCost:SetText(TIP.L.SummaryTotalCost .. ": " .. TIP.L.NoRows)
        self.summaryUnitCost:SetText(TIP.L.SummaryUnitCost .. ": " .. TIP.L.NoRows)
        self.summaryKinds:SetText(TIP.L.SummaryKinds .. ": " .. TIP.L.NoRows)
        self.summaryTurnIns:SetText(TIP.L.SummaryTurnIns .. ": " .. TIP.L.NoRows)
        return
    end

    self.summaryAchieved:SetText(TIP.L.SummaryAchieved .. ": " .. solution.totalGain .. " " .. dataset.unitLabel)
    self.summaryOvershoot:SetText(TIP.L.SummaryOvershoot .. ": " .. solution.overshoot .. " " .. dataset.unitLabel)
    self.summaryCost:SetText(TIP.L.SummaryTotalCost .. ": " .. TIP:MoneyToString(solution.totalCost))
    self.summaryUnitCost:SetText(TIP.L.SummaryUnitCost .. ": " .. TIP:MoneyToString(solution.unitCost))
    self.summaryKinds:SetText(TIP.L.SummaryKinds .. ": " .. solution.kindCount)
    self.summaryTurnIns:SetText(TIP.L.SummaryTurnIns .. ": " .. solution.turnInCount)
end

function UI:RenderPlanRows()
    local solution = TIP.state.solution
    local index

    for index = 1, getn(self.planRows) do
        local row = self.planRows[index]
        local data = solution and solution.rows[index]
        if data then
            row[1]:SetText(data.itemName)
            row[2]:SetText(data.needPerTurnIn)
            row[3]:SetText(data.gainPerTurnIn)
            row[4]:SetText(data.buyQuantity)
            row[5]:SetText(data.turnInCount)
            row[6]:SetText(data.auctionQuantity)
            row[7]:SetText(data.historyQuantity)
            row[8]:SetText(TIP:MoneyToString(data.totalCost))
        else
            row[1]:SetText("")
            row[2]:SetText("")
            row[3]:SetText("")
            row[4]:SetText("")
            row[5]:SetText("")
            row[6]:SetText("")
            row[7]:SetText("")
            row[8]:SetText("")
        end
    end
end

function UI:RenderRankingRows()
    local rankings = TIP.state.rankings or {}
    local index

    for index = 1, getn(self.rankRows) do
        local row = self.rankRows[index]
        local data = rankings[index]
        if data then
            row[1]:SetText(data.itemName)
            row[2]:SetText(TIP:MoneyToString(data.firstBatchCost))
            row[3]:SetText(TIP:MoneyToString(data.unitGainCost))
            row[4]:SetText(data.auctionTurnIns)
            row[5]:SetText(data.auctionGain)
            row[6]:SetText(data.source)
        else
            row[1]:SetText("")
            row[2]:SetText("")
            row[3]:SetText("")
            row[4]:SetText("")
            row[5]:SetText("")
            row[6]:SetText("")
        end
    end
end

function UI:Render()
    if not self.frame then
        return
    end

    self:UpdateStatus()
    self:UpdateControls()
    self:RenderSummary()
    self:RenderPlanRows()
    self:RenderRankingRows()
end

function UI:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "TurnInPlannerFrame", UIParent)
    self.frame = frame
    frame:SetWidth(760)
    frame:SetHeight(580)
    frame:SetPoint("CENTER", UIParent, "CENTER", TIP:GetDB().windowX or 0, TIP:GetDB().windowY or 0)
    frame:Hide()
    frame:SetScript("OnShow", function()
        TIP:GetDB().windowShown = true
    end)
    frame:SetScript("OnHide", function()
        TIP:GetDB().windowShown = false
    end)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local centerX = this:GetLeft() + (this:GetWidth() / 2)
        local centerY = this:GetBottom() + (this:GetHeight() / 2)
        TIP:GetDB().windowX = roundValue(centerX - (UIParent:GetWidth() / 2))
        TIP:GetDB().windowY = roundValue(centerY - (UIParent:GetHeight() / 2))
    end)
    setBackdrop(frame, 0.04, 0.04, 0.04, 0.35, 0.35, 0.35)
    tinsert(UISpecialFrames, "TurnInPlannerFrame")

    local title = createText(frame, 15, 1, 0.85, 0.2)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    title:SetText(TIP.L.Title)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)

    local datasetLabel = createText(frame, 12, 0.85, 0.85, 0.85)
    datasetLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    datasetLabel:SetText(TIP.L.DatasetLabel .. ": " .. TIP.L.DatasetDMF)

    local targetLabel = createText(frame, 12, 0.85, 0.85, 0.85)
    targetLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -66)
    targetLabel:SetText(TIP.L.TargetLabel)

    local targetDropDown = CreateFrame("Frame", "TurnInPlannerTargetDropDown", frame, "UIDropDownMenuTemplate")
    self.targetDropDown = targetDropDown
    targetDropDown:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, -78)

    local customLabel = createText(frame, 12, 0.85, 0.85, 0.85)
    customLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -66)
    customLabel:SetText(TIP.L.CustomTargetLabel)

    local customEdit = CreateFrame("EditBox", "TurnInPlannerCustomTargetEdit", frame, "InputBoxTemplate")
    self.customTargetEdit = customEdit
    customEdit:SetAutoFocus(false)
    customEdit:SetWidth(90)
    customEdit:SetHeight(20)
    customEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -84)
    customEdit:SetText(TIP:GetDB().customTarget or "")
    customEdit:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        TIP:GetDB().customTarget = this:GetText() or ""
        TIP:RecalculatePlan()
    end)
    customEdit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)

    local strategyLabel = createText(frame, 12, 0.85, 0.85, 0.85)
    strategyLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -102)
    strategyLabel:SetText(TIP.L.StrategyLabel)

    local strategyDropDown = CreateFrame("Frame", "TurnInPlannerStrategyDropDown", frame, "UIDropDownMenuTemplate")
    self.strategyDropDown = strategyDropDown
    strategyDropDown:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, -114)

    local refreshButton = createButton("TurnInPlannerRefreshButton", frame, 130, 22, TIP.L.RefreshAuction)
    self.refreshButton = refreshButton
    refreshButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 340, -80)
    refreshButton:SetScript("OnClick", function()
        TIP:RefreshCurrentAuction()
    end)

    local recalculateButton = createButton("TurnInPlannerRecalculateButton", frame, 100, 22, TIP.L.Recalculate)
    self.recalculateButton = recalculateButton
    recalculateButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 478, -80)
    recalculateButton:SetScript("OnClick", function()
        TIP:RecalculatePlan()
    end)

    local modeLabel = createText(frame, 12, 0.85, 0.85, 0.85)
    modeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -116)
    modeLabel:SetText(TIP.L.StatusLabel .. ":")

    local modeValue = createText(frame, 12, 0.3, 1, 0.5)
    self.modeValue = modeValue
    modeValue:SetPoint("TOPLEFT", frame, "TOPLEFT", 278, -116)

    local statusValue = createText(frame, 12, 1, 1, 1)
    self.statusValue = statusValue
    statusValue:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -150)
    statusValue:SetWidth(720)
    statusValue:SetText("")

    local summarySection = createSection(frame, 12, -180, 736, 78, TIP.L.SummaryLabel)
    self.summaryTarget = createText(summarySection, 12, 1, 1, 1)
    self.summaryTarget:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 10, -26)
    self.summaryTarget:SetWidth(150)

    self.summaryAchieved = createText(summarySection, 12, 1, 1, 1)
    self.summaryAchieved:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 180, -26)
    self.summaryAchieved:SetWidth(150)

    self.summaryOvershoot = createText(summarySection, 12, 1, 1, 1)
    self.summaryOvershoot:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 350, -26)
    self.summaryOvershoot:SetWidth(150)

    self.summaryCost = createText(summarySection, 12, 1, 1, 1)
    self.summaryCost:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 10, -48)
    self.summaryCost:SetWidth(160)

    self.summaryUnitCost = createText(summarySection, 12, 1, 1, 1)
    self.summaryUnitCost:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 180, -48)
    self.summaryUnitCost:SetWidth(160)

    self.summaryKinds = createText(summarySection, 12, 1, 1, 1)
    self.summaryKinds:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 350, -48)
    self.summaryKinds:SetWidth(140)

    self.summaryTurnIns = createText(summarySection, 12, 1, 1, 1)
    self.summaryTurnIns:SetPoint("TOPLEFT", summarySection, "TOPLEFT", 520, -48)
    self.summaryTurnIns:SetWidth(140)

    local planSection = createSection(frame, 12, -268, 736, 150, TIP.L.PlanLabel)
    local planColumns = {
        { x = 8, width = 140 },
        { x = 150, width = 60 },
        { x = 212, width = 60 },
        { x = 276, width = 80 },
        { x = 360, width = 70 },
        { x = 434, width = 70 },
        { x = 508, width = 70 },
        { x = 582, width = 130 },
    }
    local planHeaders = {
        TIP.L.ColumnItem,
        TIP.L.ColumnNeed,
        TIP.L.ColumnGain,
        TIP.L.ColumnBuy,
        TIP.L.ColumnTurnInCount,
        TIP.L.ColumnAuctionQty,
        TIP.L.ColumnHistoryQty,
        TIP.L.ColumnCost,
    }

    local planHeaderIndex
    for planHeaderIndex = 1, getn(planColumns) do
        local header = createText(planSection, 11, 1, 0.82, 0.2)
        header:SetPoint("TOPLEFT", planSection, "TOPLEFT", planColumns[planHeaderIndex].x, -26)
        header:SetWidth(planColumns[planHeaderIndex].width)
        header:SetText(planHeaders[planHeaderIndex])
    end

    self.planRows = {}
    local rowIndex
    for rowIndex = 1, 8 do
        self.planRows[rowIndex] = createRow(planSection, planColumns, -28 - (rowIndex * 14))
    end

    local rankSection = createSection(frame, 12, -428, 736, 136, TIP.L.RankingLabel)
    local rankColumns = {
        { x = 8, width = 160 },
        { x = 170, width = 110 },
        { x = 282, width = 110 },
        { x = 394, width = 70 },
        { x = 468, width = 70 },
        { x = 542, width = 160 },
    }
    local rankHeaders = {
        TIP.L.RankItem,
        TIP.L.RankFirstBatch,
        TIP.L.RankUnitCost,
        TIP.L.RankAuctionTurnIns,
        TIP.L.RankAuctionGain,
        TIP.L.RankSource,
    }

    local rankHeaderIndex
    for rankHeaderIndex = 1, getn(rankColumns) do
        local header = createText(rankSection, 11, 1, 0.82, 0.2)
        header:SetPoint("TOPLEFT", rankSection, "TOPLEFT", rankColumns[rankHeaderIndex].x, -26)
        header:SetWidth(rankColumns[rankHeaderIndex].width)
        header:SetText(rankHeaders[rankHeaderIndex])
    end

    self.rankRows = {}
    for rowIndex = 1, 7 do
        self.rankRows[rowIndex] = createRow(rankSection, rankColumns, -28 - (rowIndex * 14))
    end

    self:RefreshDropdown()
    self:RefreshStrategyDropdown()
    self:Render()
end
