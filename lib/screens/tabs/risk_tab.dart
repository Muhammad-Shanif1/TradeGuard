import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../trading_constants.dart';
import '../../trading_models.dart';
import '../../trading_widgets.dart';

class RiskTab extends StatefulWidget {
  final AccountSettings account;
  final TradingLimits limits;
  final double currentBalance;
  final List<Trade> trades;
  final bool isKillSwitchActive;
  final Function(AccountSettings, TradingLimits) onSaveSettings;
  final Function(double, {bool isAdj, String? notes}) onAddAdjustment;

  const RiskTab({
    super.key,
    required this.account,
    required this.limits,
    required this.currentBalance,
    required this.trades,
    required this.isKillSwitchActive,
    required this.onSaveSettings,
    required this.onAddAdjustment,
  });

  @override
  State<RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends State<RiskTab> {
  final TextEditingController _calcRiskController = TextEditingController();
  final TextEditingController _calcStopController = TextEditingController();
  final TextEditingController _acInitController = TextEditingController();
  final TextEditingController _acTargetController = TextEditingController();
  final TextEditingController _acBreachController = TextEditingController();
  final TextEditingController _acSetBalController = TextEditingController();

  double? _calcLots;
  double? _calcActualRisk;

  @override
  void initState() {
    super.initState();
    _acInitController.text = widget.account.initialBalance.toString();
    _acTargetController.text = widget.account.targetBalance.toString();
    _acBreachController.text = widget.account.breachBalance.toString();
  }

  @override
  void dispose() {
    _calcRiskController.dispose();
    _calcStopController.dispose();
    _acInitController.dispose();
    _acTargetController.dispose();
    _acBreachController.dispose();
    _acSetBalController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _computeStats() {
    final journalTrades = widget.trades.where((t) => !t.isAdjustment).toList();
    final today = DateTime.now();
    final todayTrades = journalTrades.where((t) => 
      t.timestamp.day == today.day && 
      t.timestamp.month == today.month && 
      t.timestamp.year == today.year
    ).toList();
    
    final todayPnl = todayTrades.fold(0.0, (sum, t) => sum + t.pnl);
    final todayLoss = todayTrades.where((t) => t.pnl < 0).fold(0.0, (sum, t) => sum + t.pnl.abs());

    return {
      'todayPnl': todayPnl,
      'todayTradesCount': todayTrades.length,
      'todayLoss': todayLoss,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats();
    final zone = _getZoneInfo(widget.currentBalance);
    final drawdownUsed = (stats['todayLoss'] / widget.limits.riskPerTrade).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('ACCOUNT ZONE'),
                const SizedBox(height: 12),
                _buildZoneMeter(widget.currentBalance),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: zone['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: zone['color'].withOpacity(0.3)),
                  ),
                  child: Text(zone['lbl'], style: TextStyle(fontSize: 12, color: zone['color'], fontWeight: FontWeight.w600)),
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
                const TradingLabel('ACCOUNT SETUP', color: C.gold),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInputCol('START BALANCE (\$)', _acInitController)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildInputCol('TARGET (\$)', _acTargetController)),
                  ],
                ),
                const SizedBox(height: 9),
                _buildInputCol('BREACH / MIN BALANCE (\$)', _acBreachController),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final newAccount = AccountSettings(
                      initialBalance: double.tryParse(_acInitController.text) ?? widget.account.initialBalance,
                      targetBalance: double.tryParse(_acTargetController.text) ?? widget.account.targetBalance,
                      breachBalance: double.tryParse(_acBreachController.text) ?? widget.account.breachBalance,
                    );
                    widget.onSaveSettings(newAccount, widget.limits);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account settings synced to cloud!')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('APPLY ACCOUNT SETUP'),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(color: C.border)),
                const TradingLabel('SET CURRENT BALANCE DIRECTLY (\$)', fontSize: 8),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _acSetBalController, decoration: _inputDeco('Override current balance'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 7),
                    ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(_acSetBalController.text);
                        if (val != null) {
                          final diff = val - widget.currentBalance;
                          widget.onAddAdjustment(diff, notes: 'Manual balance adjustment to \$${val.toStringAsFixed(2)}');
                          _acSetBalController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('SET'),
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
                const TradingLabel('TRADING LIMITS', color: C.gold),
                const SizedBox(height: 10),
                _buildLimitRow('🎯 Daily Profit Target', '\$', (val) => widget.limits.profitTarget = val, widget.limits.profitTarget),
                _buildLimitRow('🚫 Max Loss Per Trade', '\$', (val) => widget.limits.riskPerTrade = val, widget.limits.riskPerTrade),
                _buildLimitRow('🔄 Max Trades Per Day', '#', (val) => widget.limits.maxTrades = val.toInt(), widget.limits.maxTrades.toDouble()),
                _buildLimitRow('📈 Max Drawdown %', '%', (val) => widget.limits.maxDrawdownPct = val, widget.limits.maxDrawdownPct),
                _buildLimitRow('📅 Daily Loss Limit %', '%', (val) => widget.limits.dailyDrawdownPct = val, widget.limits.dailyDrawdownPct),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    widget.onSaveSettings(widget.account, widget.limits);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limits synced to cloud!')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('SAVE LIMITS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('POSITION SIZE CALCULATOR', color: C.purple),
                const SizedBox(height: 2),
                const Text('For XAU/USD · 1 point = \$1 move · \$100/point/lot', style: TextStyle(fontSize: 11, color: C.muted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInputCol('RISK AMOUNT (\$)', _calcRiskController)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildInputCol('STOP LOSS (pts)', _calcStopController)),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    final r = double.tryParse(_calcRiskController.text);
                    final s = double.tryParse(_calcStopController.text);
                    if (r != null && s != null && s > 0) {
                      setState(() {
                        _calcLots = math.max(0.01, (r / (s * 100) * 100).round() / 100);
                        _calcActualRisk = _calcLots! * s * 100;
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: C.sub, side: const BorderSide(color: C.border), minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  child: const Text('CALCULATE', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (_calcLots != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [C.gold2, Colors.transparent]),
                      border: Border.all(color: C.gold.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const TradingLabel('RECOMMENDED LOT SIZE'),
                        Text(_calcLots!.toStringAsFixed(2), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: C.gold, letterSpacing: -1)),
                        Text('\$${_calcRiskController.text} risk · ${_calcStopController.text}pt stop', style: const TextStyle(fontSize: 11, color: C.sub)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: StatBox(label: '\$ AT RISK', value: '\$${_calcActualRisk!.toStringAsFixed(2)}', valueColor: C.red)),
                            const SizedBox(width: 7),
                            Expanded(child: StatBox(label: 'TARGET R:R', value: '${(widget.limits.profitTarget / (double.tryParse(_calcRiskController.text) ?? 1)).toStringAsFixed(1)}R', valueColor: C.gold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('TODAY\'S RISK TRACKER'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'TODAY P&L', value: '\$${stats['todayPnl'].toStringAsFixed(2)}', valueColor: stats['todayPnl'] >= 0 ? C.green : C.red)),
                    const SizedBox(width: 8),
                    Expanded(child: StatBox(label: 'TRADES USED', value: '${stats['todayTradesCount']} / ${widget.limits.maxTrades}', valueColor: C.gold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DAILY LOSS LIMIT USED', style: TextStyle(fontSize: 10, color: C.muted)),
                    Text('\$${stats['todayLoss'].toStringAsFixed(0)} / \$${widget.limits.riskPerTrade.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: drawdownUsed,
                    backgroundColor: C.border,
                    valueColor: AlwaysStoppedAnimation(drawdownUsed >= 0.8 ? C.red : (drawdownUsed >= 0.5 ? C.gold : C.green)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCol(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradingLabel(label, fontSize: 8),
        const SizedBox(height: 4),
        TextField(controller: controller, style: const TextStyle(fontSize: 13), decoration: _inputDeco(''), keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildLimitRow(String label, String unit, Function(double) onSave, double current) {
    final controller = TextEditingController(text: current.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.deep, borderRadius: BorderRadius.circular(9)),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: C.sub, height: 1.3))),
            Row(
              children: [
                Text(unit, style: const TextStyle(fontSize: 11, color: C.muted)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 68,
                  height: 30,
                  child: TextField(
                    controller: controller,
                    onChanged: (val) => onSave(double.tryParse(val) ?? current),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: C.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: C.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: C.gold)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMeter(double bal) {
    final pos = ((bal - widget.account.breachBalance) / (widget.account.targetBalance - widget.account.breachBalance)).clamp(0.0, 1.0);
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: const LinearGradient(colors: [C.red, C.red, Colors.orange, C.gold, Colors.lightGreen, C.green], stops: [0, 0.16, 0.26, 0.52, 0.8, 1]),
              ),
            ),
            LayoutBuilder(builder: (context, constraints) {
              return Positioned(
                left: pos * constraints.maxWidth,
                child: Container(
                  width: 18,
                  height: 24,
                  transform: Matrix4.translationValues(-9, -5, 0),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(5), border: Border.all(color: _getZoneInfo(bal)['color'], width: 3)),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\$${widget.account.breachBalance.toInt()} MIN', style: const TextStyle(fontSize: 9, color: C.red)),
            Text('\$${widget.account.targetBalance.toInt()} TGT', style: const TextStyle(fontSize: 9, color: C.green)),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _getZoneInfo(double b) {
    final r = widget.account.targetBalance - widget.account.breachBalance;
    if (b <= widget.account.breachBalance) return {'color': C.red, 'lbl': '⚠ BREACHED — Stop trading now', 'badge': 'BREACHED'};
    if (b < widget.account.breachBalance + r * 0.2) return {'color': C.red, 'lbl': '⚠ DANGER ZONE — Extreme caution', 'badge': 'DANGER'};
    if (b < widget.account.breachBalance + r * 0.45) return {'color': Colors.orange, 'lbl': '⚠ WARNING ZONE — Be very careful', 'badge': 'WARNING'};
    if (b < widget.account.breachBalance + r * 0.75) return {'color': C.gold, 'lbl': '⚡ RECOVERY ZONE — Stay disciplined', 'badge': 'RECOVERY'};
    if (b < widget.account.targetBalance) return {'color': C.green, 'lbl': '🎯 FINAL PUSH — Almost there!', 'badge': 'FINAL PUSH'};
    return {'color': C.green, 'lbl': '✓ TARGET REACHED — Account recovered!', 'badge': 'RECOVERED'};
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
