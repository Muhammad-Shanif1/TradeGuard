import 'package:cloud_firestore/cloud_firestore.dart';

class Trade {
  final String id;
  final double pnl;
  final double balance;
  final DateTime timestamp;
  final String? direction;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pnl': pnl,
      'balance': balance,
      'timestamp': timestamp,
      'direction': direction,
      'setup': setup,
      'emotion': emotion,
      'notes': notes,
      'lots': lots,
      'isAdjustment': isAdjustment,
    };
  }

  factory Trade.fromMap(Map<String, dynamic> map) {
    return Trade(
      id: map['id']?.toString() ?? '',
      pnl: (map['pnl'] ?? 0.0) is num ? (map['pnl'] as num).toDouble() : 0.0,
      balance: (map['balance'] ?? 0.0) is num ? (map['balance'] as num).toDouble() : 0.0,
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      direction: map['direction']?.toString(),
      setup: map['setup']?.toString(),
      emotion: map['emotion']?.toString(),
      notes: map['notes']?.toString(),
      lots: map['lots']?.toString(),
      isAdjustment: map['isAdjustment'] == true,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'profitTarget': profitTarget,
      'riskPerTrade': riskPerTrade,
      'maxTrades': maxTrades,
      'maxDrawdownPct': maxDrawdownPct,
      'dailyDrawdownPct': dailyDrawdownPct,
      'weeklyLossLimit': weeklyLossLimit,
    };
  }

  factory TradingLimits.fromMap(Map<String, dynamic> map) {
    return TradingLimits(
      profitTarget: (map['profitTarget'] ?? 30.0) is num ? (map['profitTarget'] as num).toDouble() : 30.0,
      riskPerTrade: (map['riskPerTrade'] ?? 20.0) is num ? (map['riskPerTrade'] as num).toDouble() : 20.0,
      maxTrades: (map['maxTrades'] ?? 2) is int ? (map['maxTrades'] as int) : 2,
      maxDrawdownPct: (map['maxDrawdownPct'] ?? 6.0) is num ? (map['maxDrawdownPct'] as num).toDouble() : 6.0,
      dailyDrawdownPct: (map['dailyDrawdownPct'] ?? 3.0) is num ? (map['dailyDrawdownPct'] as num).toDouble() : 3.0,
      weeklyLossLimit: (map['weeklyLossLimit'] ?? 100.0) is num ? (map['weeklyLossLimit'] as num).toDouble() : 100.0,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'initialBalance': initialBalance,
      'targetBalance': targetBalance,
      'breachBalance': breachBalance,
    };
  }

  factory AccountSettings.fromMap(Map<String, dynamic> map) {
    return AccountSettings(
      initialBalance: (map['initialBalance'] ?? 9808.0) is num ? (map['initialBalance'] as num).toDouble() : 9808.0,
      targetBalance: (map['targetBalance'] ?? 10000.0) is num ? (map['targetBalance'] as num).toDouble() : 10000.0,
      breachBalance: (map['breachBalance'] ?? 9400.0) is num ? (map['breachBalance'] as num).toDouble() : 9400.0,
    );
  }
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
