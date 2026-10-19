local TIP = TurnInPlanner

TIP.Scan = {}

local Scan = TIP.Scan

function Scan:EnsureFrame()
    if self.frame then
        return
    end

    self.frame = CreateFrame("Frame")
    self.frame:Hide()
    self.frame:SetScript("OnUpdate", function()
        Scan:OnUpdate(arg1 or 0)
    end)
end

function Scan:Begin(dataset, callback)
    self:EnsureFrame()

    self.active = true
    self.dataset = dataset
    self.callback = callback
    self.queue = {}
    self.queueIndex = 1
    self.currentPage = 0
    self.phase = "submit"
    self.lastAuctionUpdate = nil
    self.timeoutAt = nil
    self.results = TIP:BuildEmptyScanData(dataset)

    local index
    for index = 1, getn(dataset.rules) do
        self.queue[index] = dataset.rules[index]
    end

    self.frame:Show()
end

function Scan:Finish(success, message)
    local callback = self.callback
    self.active = false
    self.phase = nil
    self.dataset = nil
    self.queue = nil
    self.queueIndex = nil
    self.currentPage = nil
    self.lastAuctionUpdate = nil
    self.timeoutAt = nil
    self.callback = nil

    if self.frame then
        self.frame:Hide()
    end

    if success then
        local itemId, data
        for itemId, data in pairs(self.results) do
            table.sort(data.auctionUnits, function(a, b)
                if a.unitPrice == b.unitPrice then
                    return a.quantity < b.quantity
                end
                return a.unitPrice < b.unitPrice
            end)
        end
        TIP.state.scanData = self.results
    end

    if callback then
        callback(success, message)
    end
end

function Scan:Abort(message)
    if not self.active then
        return
    end
    self:Finish(false, message)
end

function Scan:AdvanceRule()
    self.queueIndex = self.queueIndex + 1
    self.currentPage = 0
    self.phase = "submit"
    self.lastAuctionUpdate = nil
    self.timeoutAt = nil

    if self.queueIndex > getn(self.queue) then
        self:Finish(true)
    end
end

function Scan:SubmitCurrentQuery()
    local rule = self.queue[self.queueIndex]
    if not rule then
        self:Finish(true)
        return
    end

    QueryAuctionItems(rule.itemName, nil, nil, nil, nil, nil, self.currentPage, nil, nil)
    self.phase = "await"
    self.lastAuctionUpdate = nil
    self.timeoutAt = GetTime() + 4

    TIP:SetStatus(format("%s %s (%d/%d)", TIP.L.StatusScanning, TIP:GetItemName(rule), self.queueIndex, getn(self.queue)))
end

function Scan:CollectCurrentPage()
    local rule = self.queue[self.queueIndex]
    if not rule then
        self:Finish(true)
        return
    end

    local _, totalAuctions = GetNumAuctionItems("list")
    local totalPages = 0
    if totalAuctions and totalAuctions > 0 then
        totalPages = ceil(totalAuctions / 50)
    end

    local index
    for index = 1, 50 do
        local name, _, count, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", index)
        if name and buyoutPrice and buyoutPrice > 0 and count and count > 0 then
            local link = GetAuctionItemLink("list", index)
            local itemId = TIP:GetItemIdFromLink(link)
            if itemId == rule.itemId then
                tinsert(self.results[rule.itemId].auctionUnits, {
                    quantity = count,
                    buyoutPrice = buyoutPrice,
                    unitPrice = buyoutPrice / count,
                })
            end
        end
    end

    if totalPages > 0 and (self.currentPage + 1) < totalPages then
        self.currentPage = self.currentPage + 1
        self.phase = "submit"
        self.lastAuctionUpdate = nil
        self.timeoutAt = nil
        return
    end

    self:AdvanceRule()
end

function Scan:OnAuctionUpdate()
    if self.active and self.phase == "await" then
        self.lastAuctionUpdate = GetTime()
    end
end

function Scan:OnUpdate()
    if not self.active then
        return
    end

    if not TIP:IsAuctionOpen() then
        self:Abort(TIP.L.StatusAuctionClosed)
        return
    end

    if self.phase == "submit" then
        if CanSendAuctionQuery() then
            self:SubmitCurrentQuery()
        end
        return
    end

    if self.phase ~= "await" then
        return
    end

    local now = GetTime()

    if self.lastAuctionUpdate and (now - self.lastAuctionUpdate) > 0.35 then
        self:CollectCurrentPage()
        return
    end

    if self.timeoutAt and now > self.timeoutAt then
        if self.lastAuctionUpdate then
            self:CollectCurrentPage()
        else
            self:AdvanceRule()
        end
    end
end
