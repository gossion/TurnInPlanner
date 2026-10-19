local TIP = TurnInPlanner

TIP.Datasets = {}

local dmf = {
    id = "dmf",
    name = TIP.L.DatasetDMF,
    unitLabel = TIP.L.DatasetUnitLabel,
    maxGainPerTurnIn = 20,
    targets = {
        { name = TIP.L.TargetOrb, value = 1200 },
        { name = TIP.L.TargetAmulet, value = 1200 },
        { name = TIP.L.TargetGreaterPrize, value = 40 },
        { name = TIP.L.TargetLesserPrize, value = 12 },
        { name = TIP.L.TargetMinorPrize, value = 5 },
        { name = TIP.L.TargetBox, value = 50 },
    },
    rules = {
        { itemId = 4363, itemName = "铜质调节器", itemsPerTurnIn = 5, gainPerTurnIn = 1, category = "工程", label = "工程" },
        { itemId = 4375, itemName = "高速青铜齿轮", itemsPerTurnIn = 7, gainPerTurnIn = 4, category = "工程", label = "工程" },
        { itemId = 9313, itemName = "绿色烟火", itemsPerTurnIn = 36, gainPerTurnIn = 8, category = "工程", label = "工程" },
        { itemId = 11590, itemName = "机械修理包", itemsPerTurnIn = 6, gainPerTurnIn = 12, category = "工程", label = "工程" },
        { itemId = 15994, itemName = "瑟银零件", itemsPerTurnIn = 8, gainPerTurnIn = 20, category = "工程", label = "工程" },
        { itemId = 4582, itemName = "柔软的狼尾", itemsPerTurnIn = 60, gainPerTurnIn = 5, category = "灰色物品", label = "灰色物品" },
        { itemId = 5117, itemName = "鲜艳的羽毛", itemsPerTurnIn = 60, gainPerTurnIn = 12, category = "灰色物品", label = "灰色物品" },
        { itemId = 5134, itemName = "毛茸茸的小爪子", itemsPerTurnIn = 40, gainPerTurnIn = 1, category = "灰色物品", label = "灰色物品" },
        { itemId = 11404, itemName = "邪恶蝙蝠眼", itemsPerTurnIn = 10, gainPerTurnIn = 20, category = "灰色物品", label = "灰色物品" },
        { itemId = 11407, itemName = "破损的熊皮", itemsPerTurnIn = 40, gainPerTurnIn = 4, category = "灰色物品", label = "灰色物品" },
        { itemId = 19933, itemName = "发光的蝎血", itemsPerTurnIn = 10, gainPerTurnIn = 20, category = "灰色物品", label = "灰色物品" },
        { itemId = 2309, itemName = "雕花皮外套", itemsPerTurnIn = 3, gainPerTurnIn = 1, category = "制皮", label = "制皮" },
        { itemId = 2314, itemName = "韧化皮甲", itemsPerTurnIn = 3, gainPerTurnIn = 4, category = "制皮", label = "制皮" },
        { itemId = 5739, itemName = "野人护腿", itemsPerTurnIn = 3, gainPerTurnIn = 8, category = "制皮", label = "制皮" },
        { itemId = 8185, itemName = "龟壳护腕", itemsPerTurnIn = 3, gainPerTurnIn = 12, category = "制皮", label = "制皮" },
        { itemId = 15564, itemName = "重型护甲片", itemsPerTurnIn = 8, gainPerTurnIn = 20, category = "制皮", label = "制皮" },
        { itemId = 3240, itemName = "粗制平衡石", itemsPerTurnIn = 10, gainPerTurnIn = 1, category = "锻造", label = "锻造" },
        { itemId = 3486, itemName = "重砂轮", itemsPerTurnIn = 7, gainPerTurnIn = 4, category = "锻造", label = "锻造" },
        { itemId = 3835, itemName = "绿铁护腕", itemsPerTurnIn = 3, gainPerTurnIn = 8, category = "锻造", label = "锻造" },
        { itemId = 7945, itemName = "巨型黑色锤", itemsPerTurnIn = 1, gainPerTurnIn = 12, category = "锻造", label = "锻造" },
        { itemId = 12644, itemName = "致密砂轮", itemsPerTurnIn = 7, gainPerTurnIn = 20, category = "锻造", label = "锻造" },
    }
}

local index
for index = 1, getn(dmf.rules) do
    dmf.rules[index].bitValue = 2 ^ (index - 1)
end

TIP.Datasets[dmf.id] = dmf
