TurnInPlanner = {}

local TIP = TurnInPlanner

TIP.state = {
    datasetId = "dmf",
    strategy = "cheapest",
    auctionOpen = false,
    scanInProgress = false,
    hasAuctionSnapshot = false,
    scanData = {},
    solution = nil,
    rankings = nil,
    statusText = "",
    lastError = nil,
}

local eventFrame = CreateFrame("Frame")

local function round(value)
    if not value then
        return 0
    end
    return floor(value + 0.5)
end

function TIP:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TurnInPlanner|r " .. message)
    end
end

function TIP:GetDB()
    if not TurnInPlannerDB then
        TurnInPlannerDB = {}
    end
    return TurnInPlannerDB
end

function TIP:InitDB()
    local db = self:GetDB()
    if db.datasetId == nil then
        db.datasetId = "dmf"
    end
    if db.selectedTargetIndex == nil then
        db.selectedTargetIndex = 1
    end
    if db.strategy == nil then
        db.strategy = "cheapest"
    end
    if db.customTarget == nil then
        db.customTarget = ""
    end
    if db.windowX == nil then
        db.windowX = 0
    end
    if db.windowY == nil then
        db.windowY = 0
    end
    if db.windowShown == nil then
        db.windowShown = false
    end
end

function TIP:GetDataset()
    if not self.Datasets then
        return nil
    end
    return self.Datasets[self.state.datasetId]
end

function TIP:GetSelectedTargetIndex()
    return self:GetDB().selectedTargetIndex or 1
end

function TIP:GetStrategy()
    return self:GetDB().strategy or "cheapest"
end

function TIP:SetStrategy(strategy)
    self:GetDB().strategy = strategy or "cheapest"
    self.state.strategy = self:GetStrategy()
    self:RecalculatePlan()
end

function TIP:SetSelectedTargetIndex(index)
    local dataset = self:GetDataset()
    if not dataset then
        return
    end
    index = max(1, min(index, getn(dataset.targets)))
    self:GetDB().selectedTargetIndex = index
    self:RecalculatePlan()
end

function TIP:GetCustomTarget()
    local text = self:GetDB().customTarget or ""
    if self.UI and self.UI.customTargetEdit then
        text = self.UI.customTargetEdit:GetText() or text
    end
    text = gsub(text, "%s+", "")
    if text == "" then
        return nil
    end
    local value = tonumber(text)
    if value and value > 0 then
        return floor(value)
    end
    return nil
end

function TIP:GetActiveTargetValue()
    local customTarget = self:GetCustomTarget()
    if customTarget then
        return customTarget, self.L.CustomTargetLabel
    end

    local dataset = self:GetDataset()
    if not dataset then
        return nil, nil
    end

    local target = dataset.targets[self:GetSelectedTargetIndex()]
    if not target then
        return nil, nil
    end

    return target.value, target.name
end

function TIP:GetItemIdFromLink(link)
    if not link then
        return nil
    end
    local _, _, itemId = string.find(link, "item:(%d+)")
    if itemId then
        return tonumber(itemId)
    end
    return nil
end

function TIP:GetItemName(rule)
    local itemName = GetItemInfo("item:" .. rule.itemId)
    if itemName then
        return itemName
    end
    return rule.itemName
end

function TIP:MoneyToString(value)
    value = round(value)
    local gold = floor(value / 10000)
    local silver = floor(mod(value, 10000) / 100)
    local copper = mod(value, 100)
    return format("%dg %ds %dc", gold, silver, copper)
end

function TIP:FormatUnitCost(value)
    if not value then
        return self.L.Unknown
    end
    return self:MoneyToString(value)
end

function TIP:IsAuctionOpen()
    return self.state.auctionOpen
end

function TIP:IsAuxAvailable()
    return self:GetHistoryModule() ~= nil
end

function TIP:GetHistoryModule()
    if self._historyModuleChecked then
        return self._historyModule
    end

    self._historyModuleChecked = true
    self._historyModule = nil

    if type(require) == "function" then
        local ok, historyModule = pcall(function()
            return require("aux.core.history")
        end)
        if ok and historyModule and historyModule.value then
            self._historyModule = historyModule
        end
    end

    return self._historyModule
end

function TIP:GetHistoryUnitPrice(itemId)
    local historyModule = self:GetHistoryModule()
    if not historyModule then
        return nil
    end

    local ok, value = pcall(function()
        return historyModule.value(itemId .. ":0")
    end)

    if ok and value and value > 0 then
        return tonumber(value)
    end

    return nil
end

function TIP:SetStatus(text)
    self.state.statusText = text or ""
    if self.UI and self.UI.UpdateStatus then
        self.UI:UpdateStatus()
    end
end

function TIP:GetStatusText()
    return self.state.statusText or ""
end

function TIP:GetModeStatusText()
    if self.state.scanInProgress then
        return self.L.StatusScanning
    end
    if self:IsAuctionOpen() then
        if self:IsAuxAvailable() then
            return self.L.StatusAuctionReady
        end
        return self.L.StatusAuctionNoHistory
    end
    if self:IsAuxAvailable() then
        return self.L.StatusHistoryOnly
    end
    return self.L.StatusNoAux
end

function TIP:BuildEmptyScanData(dataset)
    local scanData = {}
    local index
    for index = 1, getn(dataset.rules) do
        local rule = dataset.rules[index]
        scanData[rule.itemId] = {
            itemId = rule.itemId,
            itemName = self:GetItemName(rule),
            historyUnitPrice = self:GetHistoryUnitPrice(rule.itemId),
            auctionUnits = {},
        }
    end
    return scanData
end

function TIP:RefreshCurrentAuction()
    local dataset = self:GetDataset()
    if not dataset then
        return
    end

    if not self:IsAuctionOpen() then
        self:SetStatus(self.L.StatusAuctionClosed)
        if self.UI then
            self.UI:Render()
        end
        return
    end

    self.state.scanInProgress = true
    self.state.solution = nil
    self.state.rankings = nil
    self:SetStatus(self.L.StatusScanning)

    self.Scan:Begin(dataset, function(success, message)
        self.state.scanInProgress = false
        if success then
            self.state.hasAuctionSnapshot = true
            self:SetStatus(self.L.StatusScanComplete)
            self:RecalculatePlan()
        else
            self:SetStatus(message or self.L.StatusScanFailed)
            if self.UI then
                self.UI:Render()
            end
        end
    end)

    if self.UI then
        self.UI:Render()
    end
end

function TIP:RecalculatePlan()
    local dataset = self:GetDataset()
    if not dataset then
        return
    end

    local db = self:GetDB()
    if self.UI and self.UI.customTargetEdit then
        db.customTarget = self.UI.customTargetEdit:GetText() or db.customTarget
    end

    local targetValue, targetLabel = self:GetActiveTargetValue()
    if not targetValue or targetValue <= 0 then
        self.state.solution = nil
        self.state.rankings = nil
        self:SetStatus(self.L.InvalidTarget)
        if self.UI then
            self.UI:Render()
        end
        return
    end

    local scanData = self.state.scanData
    local hasScanData = scanData and next(scanData)
    local allowHistory = not self:IsAuctionOpen()

    if not hasScanData and allowHistory then
        scanData = self:BuildEmptyScanData(dataset)
    end

    if self:IsAuctionOpen() and not hasScanData then
        self.state.solution = nil
        self.state.rankings = nil
        self.state.targetValue = targetValue
        self.state.targetLabel = targetLabel
        self:SetStatus(self.L.StatusNeedAuctionScan)
        if self.UI then
            self.UI:Render()
        end
        return
    end

    local pricing = self.Price:BuildDatasetPricing(dataset, targetValue, scanData, allowHistory)
    local solution, rankings = self.Solver:SolveDataset(dataset, targetValue, pricing, self:GetStrategy())

    self.state.solution = solution
    self.state.rankings = rankings
    self.state.targetValue = targetValue
    self.state.targetLabel = targetLabel

    if solution then
        if self:IsAuctionOpen() then
            self:SetStatus(self:GetModeStatusText())
        else
            self:SetStatus(self.L.StatusHistoryOnly)
        end
    else
        self:SetStatus(self.L.NoPlanFound)
    end

    if self.UI then
        self.UI:Render()
    end
end

function TIP:Toggle()
    if not self.UI then
        return
    end
    if self.UI.frame:IsShown() then
        self.UI.frame:Hide()
        self:GetDB().windowShown = false
    else
        self.UI.frame:Show()
        self:GetDB().windowShown = true
        self.UI:Render()
    end
end

function TIP:RegisterSlashCommands()
    SLASH_TURNINPLANNER1 = "/tip"
    SLASH_TURNINPLANNER2 = "/turnin"
    SlashCmdList["TURNINPLANNER"] = function()
        TIP:Toggle()
    end
end

function TIP:Initialize()
    self:InitDB()
    self.state.datasetId = self:GetDB().datasetId
    self.state.strategy = self:GetStrategy()
    self:RegisterSlashCommands()
    self:SetStatus(self:GetModeStatusText())

    if self.UI then
        self.UI:Initialize()
        if self:GetDB().windowShown then
            self.UI.frame:Show()
            self.UI:Render()
        end
    end

    self:RecalculatePlan()
end

function TIP:OnEvent(frameEvent)
    if frameEvent == "ADDON_LOADED" then
        if arg1 == "TurnInPlanner" then
            self:Initialize()
        end
    elseif frameEvent == "PLAYER_LOGIN" then
        self:SetStatus(self:GetModeStatusText())
        if self.UI then
            self.UI:Render()
        end
    elseif frameEvent == "AUCTION_HOUSE_SHOW" then
        self.state.auctionOpen = true
        self.state.hasAuctionSnapshot = false
        self.state.scanData = {}
        self:SetStatus(self:GetModeStatusText())
        if self.UI then
            self.UI:Render()
        end
    elseif frameEvent == "AUCTION_HOUSE_CLOSED" then
        self.state.auctionOpen = false
        if self.Scan then
            self.Scan:Abort(self.L.StatusAuctionClosed)
        end
        self:SetStatus(self:GetModeStatusText())
        if self.UI then
            self.UI:Render()
        end
    elseif frameEvent == "AUCTION_ITEM_LIST_UPDATE" then
        if self.Scan then
            self.Scan:OnAuctionUpdate()
        end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:SetScript("OnEvent", function()
    TIP:OnEvent(event)
end)
