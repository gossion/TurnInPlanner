local TIP = TurnInPlanner

TIP.Solver = {}

local Solver = TIP.Solver

local function isBetterState(candidateCost, candidateKinds, currentState)
    if not currentState then
        return true
    end
    if candidateCost < currentState.cost then
        return true
    end
    if candidateCost == currentState.cost and candidateKinds < currentState.kindCount then
        return true
    end
    return false
end

local function isBetterStateForStrategy(strategy, candidate, currentState)
    if not currentState then
        return true
    end

    if strategy == "bulk20" then
        if candidate.turnInCount < currentState.turnInCount then
            return true
        end
        if candidate.turnInCount == currentState.turnInCount then
            if candidate.cost < currentState.cost then
                return true
            end
            if candidate.cost == currentState.cost and candidate.kindCount < currentState.kindCount then
                return true
            end
        end
        return false
    elseif strategy == "single1" then
        if candidate.singleCount > currentState.singleCount then
            return true
        end
        if candidate.singleCount == currentState.singleCount then
            if candidate.cost < currentState.cost then
                return true
            end
            if candidate.cost == currentState.cost and candidate.kindCount < currentState.kindCount then
                return true
            end
        end
        return false
    end

    return isBetterState(candidate.cost, candidate.kindCount, currentState)
end

local function isBetterFinalState(strategy, targetValue, candidateT, candidateState, bestT, bestState)
    if not bestState then
        return true
    end

    if strategy == "bulk20" then
        if candidateState.turnInCount < bestState.turnInCount then
            return true
        end
        if candidateState.turnInCount == bestState.turnInCount then
            if candidateState.cost < bestState.cost then
                return true
            end
            if candidateState.cost == bestState.cost then
                if (candidateT - targetValue) < (bestT - targetValue) then
                    return true
                end
                if (candidateT - targetValue) == (bestT - targetValue) and candidateState.kindCount < bestState.kindCount then
                    return true
                end
            end
        end
        return false
    elseif strategy == "single1" then
        if candidateState.singleCount > bestState.singleCount then
            return true
        end
        if candidateState.singleCount == bestState.singleCount then
            if candidateState.cost < bestState.cost then
                return true
            end
            if candidateState.cost == bestState.cost then
                if (candidateT - targetValue) < (bestT - targetValue) then
                    return true
                end
                if (candidateT - targetValue) == (bestT - targetValue) and candidateState.kindCount < bestState.kindCount then
                    return true
                end
            end
        end
        return false
    end

    if candidateState.cost < bestState.cost then
        return true
    end
    if candidateState.cost == bestState.cost then
        if (candidateT - targetValue) < (bestT - targetValue) then
            return true
        end
        if (candidateT - targetValue) == (bestT - targetValue) and candidateState.kindCount < bestState.kindCount then
            return true
        end
    end
    return false
end

function Solver:SolveDataset(dataset, targetValue, pricing, strategy)
    strategy = strategy or "cheapest"
    local maxTarget = targetValue + dataset.maxGainPerTurnIn - 1
    local states = {}
    local pricingIndex

    states[0] = {
        cost = 0,
        kindCount = 0,
        turnInCount = 0,
        singleCount = 0,
        prev = nil,
        option = nil,
    }

    for pricingIndex = 1, getn(pricing.rulePricings) do
        local rulePricing = pricing.rulePricings[pricingIndex]
        local nextStates = {}
        local t

        for t = 0, maxTarget do
            local baseState = states[t]
            if baseState then
                local optionIndex
                for optionIndex = 1, getn(rulePricing.options) do
                    local option = rulePricing.options[optionIndex]
                    local newT = t + option.gain
                    if newT <= maxTarget then
                        local candidateState = {
                            cost = baseState.cost + option.totalCost,
                            kindCount = baseState.kindCount + (option.turnInCount > 0 and 1 or 0),
                            turnInCount = baseState.turnInCount + option.turnInCount,
                            singleCount = baseState.singleCount + option.singleCount,
                            prev = baseState,
                            option = option.turnInCount > 0 and option or nil,
                        }

                        if isBetterStateForStrategy(strategy, candidateState, nextStates[newT]) then
                            nextStates[newT] = candidateState
                        end
                    end
                end
            end
        end

        states = nextStates
    end

    local bestT = nil
    local t
    for t = targetValue, maxTarget do
        local state = states[t]
        if state and isBetterFinalState(strategy, targetValue, t, state, bestT, bestT and states[bestT] or nil) then
            bestT = t
        end
    end

    if not bestT then
        return nil, pricing.rankings
    end

    local rows = {}
    local state = states[bestT]
    while state do
        if state.option then
            tinsert(rows, {
                itemId = state.option.itemId,
                itemName = state.option.itemName,
                needPerTurnIn = state.option.needPerTurnIn,
                gainPerTurnIn = state.option.gainPerTurnIn,
                buyQuantity = state.option.buyQuantity,
                turnInCount = state.option.turnInCount,
                auctionQuantity = state.option.auctionQuantity,
                historyQuantity = state.option.historyQuantity,
                totalCost = state.option.totalCost,
            })
        end
        state = state.prev
    end

    table.sort(rows, function(a, b)
        if a.totalCost == b.totalCost then
            return a.itemName < b.itemName
        end
        return a.totalCost > b.totalCost
    end)

    local totalCost = 0
    local totalTurnIns = 0
    local rowIndex
    for rowIndex = 1, getn(rows) do
        totalCost = totalCost + rows[rowIndex].totalCost
        totalTurnIns = totalTurnIns + rows[rowIndex].turnInCount
    end

    return {
        targetValue = targetValue,
        totalGain = bestT,
        overshoot = bestT - targetValue,
        totalCost = totalCost,
        unitCost = totalCost / bestT,
        kindCount = getn(rows),
        turnInCount = totalTurnIns,
        rows = rows,
    }, pricing.rankings
end
