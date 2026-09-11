import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../trading_constants.dart';
import '../../trading_models.dart';
import '../../trading_widgets.dart';

class HomeTab extends StatefulWidget {
  final AccountSettings account;
  final TradingLimits limits;
  final double currentBalance;
  final List<Trade> trades;
  final bool isKillSwitchActive;
  final Function(double, {String? dir, String? setup, String? emo, String? notes, String? lots, bool isAdj}) onAddTrade;

  const HomeTab({
    super.key,
    required this.account,
    required this.limits,
    required this.currentBalance,
    required this.trades,
    required this.isKillSwitchActive,
    required this.onAddTrade,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _pnlController = TextEditingController();

  @override
  void dispose() {
    _pnlController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _computeStats() {
    final journalTrades = widget.trades.where((t) => !t.isAdjustment).toList();
    final wins = journalTrades.where((t) => t.pnl > 0).toList();
    final losses = journalTrades.where((t) => t.pnl < 0).toList();
    
    final totalWin = wins.fold(0.0, (sum, t) => sum + t.pnl);
    final totalLoss = losses.fold(0.0, (sum, t) => sum + t.pnl.abs());
    
    final wr = journalTrades.isEmpty ? 0.0 : (wins.length / journalTrades.length) * 100;
    final pf = totalLoss == 0 ? (totalWin > 0 ? 999.0 : 0.0) : totalWin / totalLoss;
    
    final today = DateTime.now();
    final todayTrades = journalTrades.where((t) => 
      t.timestamp.day == today.day && 
      t.timestamp.month == today.month && 
      t.timestamp.year == today.year
    ).toList();
    
    final todayPnl = todayTrades.fold(0.0, (sum, t) => sum + t.pnl);
    
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
      'winRate': wr,
      'profitFactor': pf,
      'todayPnl': todayPnl,
      'todayTradesCount': todayTrades.length,
      'streak': streak,
      'streakType': streakType,
      'totalWin': totalWin,
      'totalLoss': totalLoss,
      'totalTrades': journalTrades.length,
    };
  }

  double _getWeeklyLoss() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    double weeklyNet = widget.trades.where((t) => 
      !t.isAdjustment && 
      t.timestamp.isAfter(startOfDay)
    ).fold(0.0, (sum, t) => sum + t.pnl);

    return weeklyNet < 0 ? weeklyNet.abs() : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats();
    final todayRem = math.max(0.0, widget.limits.profitTarget - stats['todayPnl']);
    final equityData = [widget.account.initialBalance, ...widget.trades.reversed.map((t) => t.balance)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradingCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                _buildSessCol('\$${stats['todayPnl'].toStringAsFixed(2)}', 'TODAY P&L', stats['todayPnl'] > 0 ? C.green : (stats['todayPnl'] < 0 ? C.red : C.sub)),
                _buildSessCol(stats['todayTradesCount'].toString(), 'TRADES', C.text),
                _buildSessCol('${stats['streak']}x', stats['streakType'] == 'win' ? 'WIN STREAK' : 'LOSS STREAK', stats['streakType'] == 'win' ? C.green : C.red),
                _buildSessCol(todayRem <= 0 ? 'DONE ✓' : '\$${todayRem.toStringAsFixed(0)}', 'TO TARGET', todayRem <= 0 ? C.green : C.gold, last: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatBox(label: 'WIN RATE', value: '${stats['winRate'].toStringAsFixed(0)}%', valueColor: stats['winRate'] >= 50 ? C.green : C.red)),
              const SizedBox(width: 8),
              Expanded(child: StatBox(label: 'PROFIT FACTOR', value: stats['profitFactor'] > 10 ? '∞' : stats['profitFactor'].toStringAsFixed(2), valueColor: stats['profitFactor'] >= 1.5 ? C.green : C.gold)),
              const SizedBox(width: 8),
              Expanded(child: StatBox(label: 'AVG WIN', value: '\$${(stats['totalTrades'] > 0 ? stats['totalWin'] / math.max(1, stats['totalTrades']) : 0).toStringAsFixed(0)}', valueColor: C.green)),
            ],
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('WEEKLY LOSS LIMIT', color: C.sub),
                    Text('\$${_getWeeklyLoss().toStringAsFixed(0)} / \$${widget.limits.weeklyLossLimit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: C.text)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildWeeklySegment(0.34, C.green, _getWeeklyLoss() / widget.limits.weeklyLossLimit),
                    const SizedBox(width: 4),
                    _buildWeeklySegment(0.33, C.gold, _getWeeklyLoss() / widget.limits.weeklyLossLimit, offset: 0.34),
                    const SizedBox(width: 4),
                    _buildWeeklySegment(0.33, C.red, _getWeeklyLoss() / widget.limits.weeklyLossLimit, offset: 0.67),
                  ],
                ),
                if (_getWeeklyLoss() >= widget.limits.weeklyLossLimit)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('⚠ WEEKLY LOSS LIMIT BREACHED', style: TextStyle(color: C.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            borderColor: C.gold.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('QUICK LOG', color: C.gold),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildQuickBigButton(context, '+\$${widget.limits.profitTarget.toInt()} WIN', C.green, () => widget.onAddTrade(widget.limits.profitTarget))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildQuickBigButton(context, '-\$${widget.limits.riskPerTrade.toInt()} LOSS', C.red, () => widget.onAddTrade(-widget.limits.riskPerTrade))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildQuickSmallButton(context, '+\$15', C.gold, () => widget.onAddTrade(15))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton(context, '+\$10', C.gold, () => widget.onAddTrade(10))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton(context, '+\$20', C.green, () => widget.onAddTrade(20))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton(context, '-\$15', C.red, () => widget.onAddTrade(-15))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pnlController,
                        style: const TextStyle(fontSize: 13, color: C.text),
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        decoration: _inputDeco('Custom P&L (e.g. 25 or -18)'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    ElevatedButton(
                      onPressed: widget.isKillSwitchActive ? null : () {
                        final val = double.tryParse(_pnlController.text);
                        if (val != null) {
                          widget.onAddTrade(val);
                          _pnlController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('ADD'),
                    ),
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
                const TradingLabel('EQUITY CURVE'),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  color: C.deep,
                  child: MiniEquityChart(data: equityData, target: widget.account.targetBalance, breach: widget.account.breachBalance),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('— Balance  — Target  — Min', style: TextStyle(fontSize: 9, color: C.muted)),
                    Text('${widget.trades.length} trades', style: const TextStyle(fontSize: 9, color: C.muted)),
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
                const TradingLabel('RECENT TRADES'),
                const SizedBox(height: 8),
                if (widget.trades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text("No trades yet.\nLog your first trade above.", textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13))),
                  )
                else
                  ...widget.trades.take(3).map((t) => _buildTradeListItem(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessCol(String val, String lbl, Color color, {bool last = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(border: last ? null : const Border(right: BorderSide(color: C.border))),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(lbl, style: const TextStyle(fontSize: 8, color: C.muted, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySegment(double weight, Color color, double progress, {double offset = 0}) {
    double segmentProgress = (progress - offset) / weight;
    segmentProgress = segmentProgress.clamp(0.0, 1.0);
    
    return Expanded(
      flex: (weight * 100).toInt(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: segmentProgress,
          backgroundColor: C.border,
          valueColor: AlwaysStoppedAnimation(color.withOpacity(segmentProgress > 0 ? 1.0 : 0.3)),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildQuickBigButton(BuildContext context, String text, Color color, VoidCallback onTap) {
    bool active = !widget.isKillSwitchActive;
    return InkWell(
      onTap: active ? () {
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text logged'), duration: const Duration(seconds: 1)));
      } : null,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ),
    );
  }

  Widget _buildQuickSmallButton(BuildContext context, String text, Color color, VoidCallback onTap) {
    bool active = !widget.isKillSwitchActive;
    return InkWell(
      onTap: active ? () {
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text logged'), duration: const Duration(seconds: 1)));
      } : null,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: C.deep, border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildTradeListItem(Trade t) {
    final color = t.pnl > 0 ? C.green : (t.pnl < 0 ? C.red : C.muted);
    final borderColor = t.isAdjustment ? C.purple : color;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: C.deep,
        borderRadius: BorderRadius.circular(11),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.pnl >= 0 ? "+" : "−"}\$${t.pnl.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1)),
                  const SizedBox(height: 2),
                  Text('→ Balance: \$${t.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: C.muted)),
                ],
              ),
              Text('${t.timestamp.day}/${t.timestamp.month} ${t.timestamp.hour}:${t.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: C.muted)),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            children: [
              if (t.direction != null) _buildBadge(t.direction!, t.direction == 'BUY' ? C.green : C.red),
              if (t.setup != null) _buildBadge(t.setup!, C.blue),
              if (t.emotion != null) Text(TradingContent.emotions.firstWhere((e) => e['id'] == t.emotion, orElse: () => {'icon': ''})['icon'] ?? '', style: const TextStyle(fontSize: 13)),
              if (t.isAdjustment) _buildBadge('ADJ', C.purple),
            ],
          ),
          if (t.notes != null && t.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.notes!, style: const TextStyle(fontSize: 11, color: C.sub, fontStyle: FontStyle.italic, height: 1.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: C.muted, fontSize: 13),
      filled: true,
      fillColor: C.deep,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: C.gold)),
    );
  }
}
