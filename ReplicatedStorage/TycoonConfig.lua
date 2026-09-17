-- ModuleScript: ReplicatedStorage.TycoonConfig
local TycoonConfig = {}

TycoonConfig.StartingCash = 0

-- PurchaseId on each button must match these keys
TycoonConfig.Purchases = {
	Cell2 = { Cost = 50, Unlock = "Cell2" },
	Cell3 = { Cost = 150, Unlock = "Cell3" },
	Cell4 = { Cost = 400, Unlock = "Cell4" },
	Kitchen = { Cost = 1000, Unlock = "Kitchen" },
}

-- Primary income: Deposit collector
TycoonConfig.CashPerInmate = 10

-- Passive trickle (0 = off; collector is the main cash path to avoid double-income)
TycoonConfig.IncomePerOwnedUnlock = 0
TycoonConfig.IncomeInterval = 1

return TycoonConfig
