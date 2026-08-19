class Trade {
  final String id;
  final double pnl;
  final double balance;
  final DateTime timestamp;
  final String? direction; // BUY, SELL
  final String? setup;
  final String? emotion;
  final String? notes;
  final String? lots;
  final bool isAdjustment;

  Trade({
    required this.id,
    required this.pnl,
    required this.balance,
    required this.timestamp,
    this.direction,
    this.setup,
    this.emotion,
    this.notes,
    this.lots,
    this.isAdjustment = false,
  });
}

class TradingLimits {
  double profitTarget;
  double riskPerTrade;
  int maxTrades;
  double maxDrawdownPct;
  double dailyDrawdownPct;
  double weeklyLossLimit;

  TradingLimits({
    this.profitTarget = 30.0,
    this.riskPerTrade = 20.0,
    this.maxTrades = 2,
    this.maxDrawdownPct = 6.0,
    this.dailyDrawdownPct = 3.0,
    this.weeklyLossLimit = 100.0,
  });
}

class AccountSettings {
  double initialBalance;
  double targetBalance;
  double breachBalance;

  AccountSettings({
    this.initialBalance = 9808.0,
    this.targetBalance = 10000.0,
    this.breachBalance = 9400.0,
  });
}

class ChecklistItem {
  final String id;
  final String text;
  bool isChecked;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });
}

class ChecklistGroup {
  final String category;
  final dynamic color;
  final List<ChecklistItem> items;

  ChecklistGroup({
    required this.category,
    required this.color,
    required this.items,
  });
}
