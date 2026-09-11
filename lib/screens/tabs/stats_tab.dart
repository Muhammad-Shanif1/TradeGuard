import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../trading_constants.dart';
import '../../trading_models.dart';
import '../../trading_widgets.dart';

class StatsTab extends StatelessWidget {
  final AccountSettings account;
  final TradingLimits limits;
  final double currentBalance;
  final List<Trade> trades;

  const StatsTab({
    super.key,
    required this.account,
    required this.limits,
    required this.currentBalance,
    required this.trades,
  });

  Map<String, dynamic> _computeStats() {
    final journalTrades = trades.where((t) => !t.isAdjustment).toList();
    final wins = journalTrades.where((t) => t.pnl > 0).toList();
    final losses = journalTrades.where((t) => t.pnl < 0).toList();
    
    final totalWin = wins.fold(0.0, (sum, t) => sum + t.pnl);
    final totalLoss = losses.fold(0.0, (sum, t) => sum + t.pnl.abs());
    
    final wr = journalTrades.isEmpty ? 0.0 : (wins.length / journalTrades.length) * 100;
    final pf = totalLoss == 0 ? (totalWin > 0 ? 999.0 : 0.0) : totalWin / totalLoss;
    
    int streak = 0;
    String? streakType;
    if (journalTrades.isNotEmpty) {
      streakType = journalTrades.first.pnl > 0 ? 'win' : 'loss';
      for (var t in journalTrades) {
        final type = t.pnl > 0 ? 'win' : 'loss';
        if (type == streakType) {
          streak++;
        } else {
          break;
        }
      }
    }

    return {
      'totalTrades': journalTrades.length,
      'winRate': wr,
      'profitFactor': pf,
      'streak': streak,
      'streakType': streakType,
      'totalWin': totalWin,
      'totalLoss': totalLoss,
    };
  }

  Map<DateTime, double> _getDailyPnl() {
    final Map<DateTime, double> map = {};
    for (var t in trades) {
      if (t.isAdjustment) continue;
      final date = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      map[date] = (map[date] ?? 0.0) + t.pnl;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats();
    final journalTrades = trades.where((t) => !t.isAdjustment).toList();
    
    final netPnl = stats['totalWin'] - stats['totalLoss'];
    final wins = journalTrades.where((t) => t.pnl > 0).toList();
    final losses = journalTrades.where((t) => t.pnl < 0).toList();
    final avgWin = wins.isEmpty ? 0.0 : stats['totalWin'] / wins.length;
    final avgLoss = losses.isEmpty ? 0.0 : stats['totalLoss'] / losses.length;
    final ev = journalTrades.isEmpty ? 0.0 : (stats['winRate'] / 100 * avgWin) - ((1 - stats['winRate'] / 100) * avgLoss);
    
    final best = journalTrades.isEmpty ? 0.0 : journalTrades.map((t) => t.pnl).reduce(math.max);
    final worst = journalTrades.isEmpty ? 0.0 : journalTrades.map((t) => t.pnl).reduce(math.min);

    final equityData = [account.initialBalance, ...trades.reversed.map((t) => t.balance)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('PERFORMANCE OVERVIEW'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'WIN RATE', value: '${stats['winRate'].toStringAsFixed(0)}%', valueColor: stats['winRate'] >= 50 ? C.green : C.red)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'TOTAL TRADES', value: stats['totalTrades'].toString())),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'PROFIT FACTOR', value: stats['profitFactor'] > 10 ? '∞' : stats['profitFactor'].toStringAsFixed(2), valueColor: stats['profitFactor'] >= 1 ? C.green : C.red)),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'AVG WIN', value: '+\$${avgWin.toStringAsFixed(0)}', valueColor: C.green)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'AVG LOSS', value: '-\$${avgLoss.toStringAsFixed(0)}', valueColor: C.red)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'EXP VALUE', value: (ev >= 0 ? '+' : '') + '\$${ev.toStringAsFixed(2)}', valueColor: ev >= 0 ? C.green : C.red)),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'BEST TRADE', value: '+\$${best.toStringAsFixed(0)}', valueColor: C.green)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'WORST TRADE', value: (worst < 0 ? '-' : '') + '\$${worst.abs().toStringAsFixed(0)}', valueColor: C.red)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'STREAK', value: '${stats['streak']}x', valueColor: stats['streakType'] == 'win' ? C.green : C.red)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('EQUITY CURVE'),
                    Text('Net P&L: ${(netPnl >= 0 ? '+' : '')}\$${netPnl.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: C.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  color: C.deep,
                  child: MiniEquityChart(data: equityData, target: account.targetBalance, breach: account.breachBalance),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('WIN / LOSS BREAKDOWN'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'WINNING TRADES', value: wins.length.toString(), valueColor: C.green)),
                    const SizedBox(width: 8),
                    Expanded(child: StatBox(label: 'LOSING TRADES', value: losses.length.toString(), valueColor: C.red)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(value: stats['winRate'] / 100, backgroundColor: C.red, valueColor: const AlwaysStoppedAnimation(C.green)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const TradingLabel('TOTAL WON', fontSize: 8), Text('+\$${stats['totalWin'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.green))])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const TradingLabel('TOTAL LOST', fontSize: 8), Text('-\$${stats['totalLoss'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.red))])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildPerformanceGroup('SETUP PERFORMANCE', journalTrades, (t) => t.setup),
          const SizedBox(height: 10),
          _buildPerformanceGroup('EMOTION PERFORMANCE', journalTrades, (t) => t.emotion),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('ACCOUNT RECOVERY'),
                const SizedBox(height: 8),
                _buildPerfRow('Starting Balance', '\$${account.initialBalance.toStringAsFixed(2)}'),
                _buildPerfRow('Current Balance', '\$${currentBalance.toStringAsFixed(2)}'),
                _buildPerfRow('Target Balance', '\$${account.targetBalance.toStringAsFixed(2)}', valColor: C.green),
                _buildPerfRow('Recovered Amount', '+\$${(math.max(0.0, currentBalance - account.initialBalance)).toStringAsFixed(2)}', valColor: C.green),
                _buildPerfRow('Remaining to Target', '\$${(math.max(0.0, account.targetBalance - currentBalance)).toStringAsFixed(2)}', valColor: C.red),
                _buildPerfRow('Recovery Progress', '${((currentBalance - account.initialBalance) / (account.targetBalance - account.initialBalance) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%', valColor: C.gold),
                _buildPerfRow('Days to Target (est.)', currentBalance >= account.targetBalance ? 'Done ✓' : '~${(math.max(0.0, account.targetBalance - currentBalance) / limits.profitTarget).ceil()} days', valColor: C.gold),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: TradeCalendar(dailyPnl: _getDailyPnl()),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceGroup(String label, List<Trade> trades, String? Function(Trade) getVal) {
    final map = <String, Map<String, dynamic>>{};
    for (var t in trades) {
      final val = getVal(t);
      if (val == null) continue;
      if (!map.containsKey(val)) map[val] = {'w': 0, 'l': 0, 'pnl': 0.0};
      map[val]!['pnl'] += t.pnl;
      if (t.pnl > 0) map[val]!['w']++; else map[val]!['l']++;
    }
    
    final sorted = map.entries.toList()..sort((a, b) => b.value['pnl'].compareTo(a.value['pnl']));

    return TradingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TradingLabel(label),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const Center(child: Text("No data yet", style: TextStyle(color: C.muted, fontSize: 13)))
          else
            ...sorted.map((e) {
              final wr = (e.value['w'] / (e.value['w'] + e.value['l']) * 100).round();
              return _buildPerfRow(
                '${e.key} (${e.value['w'] + e.value['l']} trades · $wr% WR)',
                (e.value['pnl'] >= 0 ? '+' : '') + '\$${e.value['pnl'].toStringAsFixed(0)}',
                valColor: e.value['pnl'] >= 0 ? C.green : C.red,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPerfRow(String lbl, String val, {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lbl, style: const TextStyle(fontSize: 12, color: C.sub)),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valColor ?? C.text)),
        ],
      ),
    );
  }
}
