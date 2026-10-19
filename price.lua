local TIP = TurnInPlanner

TIP.Price = {}

local Price = TIP.Price

local function sumAuctionQuantity(units)
    local total = 0
    local index
    for index = 1, getn(units) do
        total = total + units[index].quantity
    end
    return total
end

local function copyAuctionUnits(units)
    local result = {}
    local index
    for index = 1, getn(units) do
        result[index] = {
            quantity = units[index].quantity,
            buyoutPrice = units[index].buyoutPrice,
            unitPrice = units[index].unitPrice,
        }
    end
    return result
end

local function makeOption(rule, turnInCount, totalCost, buyQuantity, auctionQuantity, historyQuantity)
    return {
        itemId = rule.itemId,
        itemName = TIP:GetItemName(rule),
        needPerTurnIn = rule.itemsPerTurnIn,
        gainPerTurnIn = rule.gainPerTurnIn,
        turnInCount = turnInCount,
        gain = turnInCount * rule.gainPerTurnIn,
        buyQuantity = buyQuantity,
        auctionQuantity = auctionQuantity,
        historyQuantity = historyQuantity,
        totalCost = totalCost,
        singleCount = rule.gainPerTurnIn == 1 and turnInCount or 0,
        rule = rule,
    }
end

function Price:BuildRulePricing(rule, source, maxTarget, allowHistory)
    local auctionUnits = copyAuctionUnits(source.auctionUnits or {})
    local historyUnitPrice = allowHistory and source.historyUnitPrice or nil
    local requiredTurnIns = ceil(maxTarget / rule.gainPerTurnIn)
    local auctionTurnIns = floor(sumAuctionQuantity(auctionUnits) / rule.itemsPerTurnIn)
    local options = {
        makeOption(rule, 0, 0, 0, 0, 0),
    }
    local ranking = {
        itemId = rule.itemId,
        itemName = TIP:GetItemName(rule),
        firstBatchCost = nil,
        unitGainCost = nil,
        auctionTurnIns = auctionTurnIns,
        auctionGain = auctionTurnIns * rule.gainPerTurnIn,
        estimated = nil,
        source = TIP.L.RankSourceAuction,
    }

    table.sort(auctionUnits, function(a, b)
        if a.unitPrice == b.unitPrice then
            if a.quantity == b.quantity then
                return a.buyoutPrice < b.buyoutPrice
            end
            return a.quantity < b.quantity
        end
        return a.unitPrice < b.unitPrice
    end)

    local cumulativeQty = 0
    local cumulativeCost = 0
    local cumulativeAuctionQty = 0
    local nextTurnIn = 1
    local lotIndex

    for lotIndex = 1, getn(auctionUnits) do
        local lot = auctionUnits[lotIndex]
        cumulativeQty = cumulativeQty + lot.quantity
        cumulativeAuctionQty = cumulativeAuctionQty + lot.quantity
        cumulativeCost = cumulativeCost + lot.buyoutPrice

        while nextTurnIn <= requiredTurnIns and cumulativeQty >= (nextTurnIn * rule.itemsPerTurnIn) do
            tinsert(options, makeOption(rule, nextTurnIn, cumulativeCost, cumulativeQty, cumulativeAuctionQty, 0))
            nextTurnIn = nextTurnIn + 1
        end
    end

    if historyUnitPrice then
        while nextTurnIn <= requiredTurnIns do
            local neededQty = (nextTurnIn * rule.itemsPerTurnIn) - cumulativeQty
            cumulativeQty = cumulativeQty + neededQty
            cumulativeCost = cumulativeCost + (neededQty * historyUnitPrice)
            tinsert(options, makeOption(rule, nextTurnIn, cumulativeCost, cumulativeQty, cumulativeAuctionQty, cumulativeQty - cumulativeAuctionQty))
            nextTurnIn = nextTurnIn + 1
        end
    end

    if options[2] then
        ranking.firstBatchCost = options[2].totalCost
        ranking.unitGainCost = options[2].totalCost / rule.gainPerTurnIn
        ranking.estimated = options[2].historyQuantity > 0
        if options[2].historyQuantity > 0 and options[2].auctionQuantity > 0 then
            ranking.source = TIP.L.RankSourceEstimate
        elseif options[2].historyQuantity > 0 then
            ranking.source = TIP.L.RankSourceHistory
        end
    end

    return {
        rule = rule,
        options = options,
        ranking = ranking,
    }
end

function Price:BuildDatasetPricing(dataset, targetValue, scanData, allowHistory)
    local rulePricings = {}
    local rankings = {}
    local maxTarget = targetValue + dataset.maxGainPerTurnIn - 1
    local index

    for index = 1, getn(dataset.rules) do
        local rule = dataset.rules[index]
        local source = scanData[rule.itemId] or {
            itemId = rule.itemId,
            itemName = TIP:GetItemName(rule),
            historyUnitPrice = TIP:GetHistoryUnitPrice(rule.itemId),
            auctionUnits = {},
        }

        local rulePricing = self:BuildRulePricing(rule, source, maxTarget, allowHistory)
        tinsert(rulePricings, rulePricing)
        if rulePricing.ranking and rulePricing.ranking.firstBatchCost then
            tinsert(rankings, rulePricing.ranking)
        end
    end

    table.sort(rankings, function(a, b)
        if a.unitGainCost == b.unitGainCost then
            if a.firstBatchCost == b.firstBatchCost then
                return a.itemName < b.itemName
            end
            return a.firstBatchCost < b.firstBatchCost
        end
        return a.unitGainCost < b.unitGainCost
    end)

    return {
        rulePricings = rulePricings,
        rankings = rankings,
    }
end
