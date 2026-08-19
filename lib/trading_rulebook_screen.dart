import 'package:flutter/material.dart';
import 'trading_constants.dart';
import 'trading_models.dart';
import 'trading_widgets.dart';
import 'dart:math' as math;

class TradingRulebookScreen extends StatefulWidget {
  const TradingRulebookScreen({super.key});

  @override
  State<TradingRulebookScreen> createState() => _TradingRulebookScreenState();
}

class _TradingRulebookScreenState extends State<TradingRulebookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _playbookSubTab = 0; // 0: Checklist, 1: Rulebook

  // State
  AccountSettings account = AccountSettings();
  TradingLimits limits = TradingLimits();
  double currentBalance = 9808.0;
  List<Trade> trades = [];
  Map<String, bool> checklistState = {};
  Map<String, bool> rulebookState = {};

  // Controllers
  final TextEditingController _pnlController = TextEditingController();
  final TextEditingController _journalPnlController = TextEditingController();
  final TextEditingController _journalLotsController = TextEditingController();
  final TextEditingController _journalNotesController = TextEditingController();
  final TextEditingController _calcRiskController = TextEditingController();
  final TextEditingController _calcStopController = TextEditingController();
  final TextEditingController _acInitController = TextEditingController();
  final TextEditingController _acTargetController = TextEditingController();
  final TextEditingController _acBreachController = TextEditingController();
  final TextEditingController _acSetBalController = TextEditingController();

  // Journal Form State
  String? _selectedDir;
  String? _selectedSetup;
  String? _selectedEmo;
  String _journalFilter = 'all';

  // Calc Output
  double? _calcLots;
  double? _calcActualRisk;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);
    _tabController.addListener(() => setState(() {}));
    
    // Sync controllers
    _acInitController.text = account.initialBalance.toString();
    _acTargetController.text = account.targetBalance.toString();
    _acBreachController.text = account.breachBalance.toString();

    // Initialize checklist state
    final ckGroups = TradingContent.getChecklistGroups(limits.riskPerTrade, limits.profitTarget, limits.maxTrades);
    for (var group in ckGroups) {
      for (var item in group['items']) {
        checklistState[item['id']] = false;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pnlController.dispose();
    _journalPnlController.dispose();
    _journalLotsController.dispose();
    _journalNotesController.dispose();
    _calcRiskController.dispose();
    _calcStopController.dispose();
    _acInitController.dispose();
    _acTargetController.dispose();
    _acBreachController.dispose();
    _acSetBalController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _addTrade(double pnl, {String? dir, String? setup, String? emo, String? notes, String? lots, bool isAdj = false}) {
    setState(() {
      currentBalance = (currentBalance + pnl);
      trades.insert(
        0,
        Trade(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pnl: pnl,
          balance: currentBalance,
          timestamp: DateTime.now(),
          direction: dir,
          setup: setup,
          emotion: emo,
          notes: notes,
          lots: lots,
          isAdjustment: isAdj,
        ),
      );
      if (trades.length > 100) trades.removeLast();
    });
  }

  void _deleteTrade(String id) {
    setState(() {
      trades.removeWhere((t) => t.id == id);
      _recalculateBalance();
    });
  }

  void _recalculateBalance() {
    double b = account.initialBalance;
    final reversedTrades = trades.reversed.toList();
    for (var t in reversedTrades) {
      b = (b + t.pnl);
      // We can't easily update the 'balance' field inside the Trade objects because they are final
      // In a real app we'd map to new objects, but for now we'll just update currentBalance
    }
    currentBalance = b;
  }

  bool get _isKillSwitchActive {
    final today = DateTime.now();
    final todayLosses = trades.where((t) => 
      !t.isAdjustment && 
      t.timestamp.day == today.day && 
      t.timestamp.month == today.month && 
      t.timestamp.year == today.year &&
      t.pnl < 0
    ).length;
    return todayLosses >= 2;
  }

  double _getWeeklyLoss() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return trades.where((t) => 
      !t.isAdjustment && 
      t.timestamp.isAfter(startOfDay) &&
      t.pnl < 0
    ).fold(0.0, (sum, t) => sum + t.pnl.abs());
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

  Map<String, dynamic> _computeStats() {
    final journalTrades = trades.where((t) => !t.isAdjustment).toList();
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
    final todayLoss = todayTrades.where((t) => t.pnl < 0).fold(0.0, (sum, t) => sum + t.pnl.abs());

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
      'todayPnl': todayPnl,
      'todayTradesCount': todayTrades.length,
      'todayLoss': todayLoss,
      'streak': streak,
      'streakType': streakType,
      'totalWin': totalWin,
      'totalLoss': totalLoss,
    };
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeTab(),
                  _buildJournalTab(),
                  _buildRiskTab(),
                  _buildPlaybookTab(),
                  _buildStatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final toRecover = math.max(0.0, account.targetBalance - currentBalance);
    final progress = ((currentBalance - account.initialBalance) / (account.targetBalance - account.initialBalance)).clamp(0.0, 1.0);
    
    final zone = _getZoneInfo(currentBalance);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.bg2, Color(0xFF111128)],
        ),
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TradingLabel('TRADEGUARD · XAU/USD', color: C.gold),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: zone['color'].withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  zone['badge'],
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: zone['color'], letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${currentBalance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: zone['color'],
            ),
          ),
          Text(
            currentBalance >= account.targetBalance 
              ? '✓ Target reached! Account recovered.'
              : 'Need +\$${toRecover.toStringAsFixed(2)} to reach \$${account.targetBalance.toStringAsFixed(2)} target',
            style: const TextStyle(fontSize: 11, color: C.sub),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECOVERY PROGRESS', style: TextStyle(fontSize: 9, color: C.muted)),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: C.gold, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: C.border,
              valueColor: AlwaysStoppedAnimation(Color.lerp(C.gold, C.green, progress)!),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['HOME', 'JOURNAL', 'RISK', 'PLAYBOOK', 'STATS'];
    return Container(
      height: 45,
      decoration: const BoxDecoration(
        color: C.bg2,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: C.gold,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: C.gold,
        unselectedLabelColor: C.muted,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // --- TAB PANES ---

  Widget _buildHomeTab() {
    final stats = _computeStats();
    final todayRem = math.max(0.0, limits.profitTarget - stats['todayPnl']);
    final equityData = [account.initialBalance, ...trades.reversed.map((t) => t.balance)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session Stats Bar
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

          // Key Metrics Grid
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

          // Weekly Limit
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('WEEKLY LOSS LIMIT', color: C.sub),
                    Text('\$${_getWeeklyLoss().toStringAsFixed(0)} / \$${limits.weeklyLossLimit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: C.text)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildWeeklySegment(0.34, C.green, _getWeeklyLoss() / limits.weeklyLossLimit),
                    const SizedBox(width: 4),
                    _buildWeeklySegment(0.33, C.gold, _getWeeklyLoss() / limits.weeklyLossLimit, offset: 0.34),
                    const SizedBox(width: 4),
                    _buildWeeklySegment(0.33, C.red, _getWeeklyLoss() / limits.weeklyLossLimit, offset: 0.67),
                  ],
                ),
                if (_getWeeklyLoss() >= limits.weeklyLossLimit)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('⚠ WEEKLY LOSS LIMIT BREACHED', style: TextStyle(color: C.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick Log
          TradingCard(
            borderColor: C.gold.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('QUICK LOG', color: C.gold),
                const SizedBox(height: 8),
                if (_isKillSwitchActive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: C.red2, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.red)),
                    child: const Text('KILL SWITCH ACTIVE: 2 losses today. Trading disabled.', style: TextStyle(color: C.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  children: [
                    Expanded(child: _buildQuickBigButton('+\$${limits.profitTarget.toInt()} WIN', C.green, () => _addTrade(limits.profitTarget))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildQuickBigButton('-\$${limits.riskPerTrade.toInt()} LOSS', C.red, () => _addTrade(-limits.riskPerTrade))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildQuickSmallButton('+\$15', C.gold, () => _addTrade(15))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton('+\$10', C.gold, () => _addTrade(10))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton('+\$20', C.green, () => _addTrade(20))),
                    const SizedBox(width: 5),
                    Expanded(child: _buildQuickSmallButton('-\$15', C.red, () => _addTrade(-15))),
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
                      onPressed: _isKillSwitchActive ? null : () {
                        final val = double.tryParse(_pnlController.text);
                        if (val != null) {
                          _addTrade(val);
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

          // Equity Curve
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('EQUITY CURVE'),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  color: C.deep,
                  child: MiniEquityChart(data: equityData, target: account.targetBalance, breach: account.breachBalance),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('— Balance  — Target  — Min', style: TextStyle(fontSize: 9, color: C.muted)),
                    Text('${trades.length} trades', style: const TextStyle(fontSize: 9, color: C.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Recent Trades
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('RECENT TRADES'),
                const SizedBox(height: 8),
                if (trades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text("No trades yet.\nLog your first trade above.", textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13))),
                  )
                else
                  ...trades.take(3).map((t) => _buildTradeListItem(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalTab() {
    final filteredTrades = trades.where((t) {
      if (_journalFilter == 'win') return !t.isAdjustment && t.pnl > 0;
      if (_journalFilter == 'loss') return !t.isAdjustment && t.pnl < 0;
      if (_journalFilter == 'adj') return t.isAdjustment;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Log Trade Form
          TradingCard(
            borderColor: C.gold.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('LOG TRADE', color: C.gold),
                const SizedBox(height: 10),
                const TradingLabel('DIRECTION', fontSize: 8),
                const SizedBox(height: 6),
                ToggleRow(
                  items: const [
                    {'id': 'BUY', 'label': '▲ BUY / LONG', 'activeColor': C.green, 'activeBgColor': Color(0x2622C55E)},
                    {'id': 'SELL', 'label': '▼ SELL / SHORT', 'activeColor': C.red, 'activeBgColor': Color(0x26EF4444)},
                  ],
                  selectedId: _selectedDir,
                  onSelected: (val) => setState(() => _selectedDir = _selectedDir == val ? null : val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TradingLabel('P&L (\$)', fontSize: 8),
                          const SizedBox(height: 5),
                          TextField(controller: _journalPnlController, decoration: _inputDeco('e.g. 30 or -20'), keyboardType: const TextInputType.numberWithOptions(signed: true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TradingLabel('LOT SIZE', fontSize: 8),
                          const SizedBox(height: 5),
                          TextField(controller: _journalLotsController, decoration: _inputDeco('0.01'), keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const TradingLabel('SETUP TYPE', fontSize: 8),
                const SizedBox(height: 6),
                PillSelector(options: TradingContent.setupTypes, selected: _selectedSetup, onSelected: (val) => setState(() => _selectedSetup = _selectedSetup == val ? null : val)),
                const SizedBox(height: 10),
                const TradingLabel('MENTAL STATE', fontSize: 8),
                const SizedBox(height: 6),
                ToggleRow(
                  items: TradingContent.emotions.map((e) => {'id': e['id'], 'label': '${e['icon']} ${e['label']}'}).toList(),
                  selectedId: _selectedEmo,
                  onSelected: (val) => setState(() => _selectedEmo = _selectedEmo == val ? null : val),
                  activeColor: C.blue,
                  activeBgColor: C.blue2,
                ),
                const SizedBox(height: 10),
                const TradingLabel('NOTES (OPTIONAL)', fontSize: 8),
                const SizedBox(height: 5),
                TextField(controller: _journalNotesController, maxLines: 2, decoration: _inputDeco('Setup description...')),
                const SizedBox(height: 12),
                if (_isKillSwitchActive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: C.red2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.red),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.block, color: C.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('KILL SWITCH ACTIVE: 2 LOSSES TODAY. STOP TRADING.', style: TextStyle(color: C.red, fontSize: 10, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isKillSwitchActive ? null : () {
                    final pnl = double.tryParse(_journalPnlController.text);
                    if (pnl != null) {
                      _addTrade(pnl, dir: _selectedDir, setup: _selectedSetup, emo: _selectedEmo, notes: _journalNotesController.text, lots: _journalLotsController.text);
                      _journalPnlController.clear();
                      _journalLotsController.clear();
                      _journalNotesController.clear();
                      setState(() {
                        _selectedDir = null;
                        _selectedSetup = null;
                        _selectedEmo = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trade logged!'), duration: Duration(seconds: 1)));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('LOG TRADE', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // History
          TradingCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('TRADE HISTORY'),
                    TextButton(onPressed: () => setState(() => trades.clear()), child: const Text('CLEAR ALL', style: TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
                Row(
                  children: [
                    _buildFilterPill('ALL', 'all'),
                    _buildFilterPill('WINS', 'win'),
                    _buildFilterPill('LOSSES', 'loss'),
                    _buildFilterPill('ADJ', 'adj'),
                  ],
                ),
                const SizedBox(height: 10),
                if (filteredTrades.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text("No trades yet.", style: TextStyle(color: C.muted)))
                else
                  ...filteredTrades.map((t) => _buildTradeListItem(t, showDelete: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskTab() {
    final stats = _computeStats();
    final zone = _getZoneInfo(currentBalance);
    final drawdownUsed = (stats['todayLoss'] / limits.riskPerTrade).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account Zone
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('ACCOUNT ZONE'),
                const SizedBox(height: 12),
                _buildZoneMeter(currentBalance),
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

          // Setup
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
                    setState(() {
                      account.initialBalance = double.tryParse(_acInitController.text) ?? account.initialBalance;
                      account.targetBalance = double.tryParse(_acTargetController.text) ?? account.targetBalance;
                      account.breachBalance = double.tryParse(_acBreachController.text) ?? account.breachBalance;
                      _recalculateBalance();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account settings updated!')));
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
                          final diff = val - currentBalance;
                          _addTrade(diff, isAdj: true, notes: 'Manual balance adjustment to \$${val.toStringAsFixed(2)}');
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

          // Limits
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('TRADING LIMITS', color: C.gold),
                const SizedBox(height: 10),
                _buildLimitRow('🎯 Daily Profit Target', '\$', (val) => limits.profitTarget = val, limits.profitTarget),
                _buildLimitRow('🚫 Max Loss Per Trade', '\$', (val) => limits.riskPerTrade = val, limits.riskPerTrade),
                _buildLimitRow('🔄 Max Trades Per Day', '#', (val) => limits.maxTrades = val.toInt(), limits.maxTrades.toDouble()),
                _buildLimitRow('📈 Max Drawdown %', '%', (val) => limits.maxDrawdownPct = val, limits.maxDrawdownPct),
                _buildLimitRow('📅 Daily Loss Limit %', '%', (val) => limits.dailyDrawdownPct = val, limits.dailyDrawdownPct),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('SAVE LIMITS'),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: C.border)),
                const TradingLabel('CURRENT LIMITS'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatBox(label: 'PROFIT TGT', value: '\$${limits.profitTarget.toStringAsFixed(0)}', valueColor: C.green)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'MAX LOSS', value: '\$${limits.riskPerTrade.toStringAsFixed(0)}', valueColor: C.red)),
                    const SizedBox(width: 7),
                    Expanded(child: StatBox(label: 'MAX TRADES', value: limits.maxTrades.toString(), valueColor: C.gold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Calculator
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
                            Expanded(child: StatBox(label: 'TARGET R:R', value: '${(limits.profitTarget / (double.tryParse(_calcRiskController.text) ?? 1)).toStringAsFixed(1)}R', valueColor: C.gold)),
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

          // Today's Tracker
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
                    Expanded(child: StatBox(label: 'TRADES USED', value: '${stats['todayTradesCount']} / ${limits.maxTrades}', valueColor: C.gold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DAILY LOSS LIMIT USED', style: TextStyle(fontSize: 10, color: C.muted)),
                    Text('\$${stats['todayLoss'].toStringAsFixed(0)} / \$${limits.riskPerTrade.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
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

  Widget _buildPlaybookTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: C.deep, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(child: _buildSubTabBtn('PRE-TRADE CHECKLIST', 0)),
                Expanded(child: _buildSubTabBtn('RULEBOOK', 1)),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _playbookSubTab,
            children: [
              _buildChecklistSubTab(),
              _buildRulebookSubTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSubTab() {
    final ckGroups = TradingContent.getChecklistGroups(limits.riskPerTrade, limits.profitTarget, limits.maxTrades);
    int total = 0;
    int checked = 0;
    for (var g in ckGroups) {
      for (var i in g['items']) {
        total++;
        if (checklistState[i['id']] == true) checked++;
      }
    }
    final all = checked == total;
    final pct = (checked / total);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: all ? Color(0x2622C55E) : (checked == 0 ? C.card : Color(0x26EF4444)),
              border: Border.all(color: (all ? C.green : (checked == 0 ? C.border : C.red)).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TradingLabel(all ? 'READY TO TRADE' : (checked == 0 ? 'START CHECKLIST' : 'NOT READY YET'), color: all ? C.green : (checked == 0 ? C.muted : C.red)),
                    Text('$checked / $total confirmed', style: const TextStyle(fontSize: 13, color: C.sub)),
                  ],
                ),
                Text(all ? '✓' : '${(pct * 100).round()}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: all ? C.green : C.muted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: pct, backgroundColor: C.border, valueColor: AlwaysStoppedAnimation(all ? C.green : C.gold), minHeight: 6),
          ),
          const SizedBox(height: 10),
          ...ckGroups.map((g) => _buildChecklistGroup(g)),
          if (all)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Color(0x2622C55E), border: Border.all(color: Color(0x6622C55E)), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text('✓', style: TextStyle(fontSize: 22)),
                  const Text('All clear. You may enter the trade.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.green)),
                  Text('Target \$${limits.profitTarget.toInt()} · Risk \$${limits.riskPerTrade.toInt()} · Risk-free at +\$20', style: const TextStyle(fontSize: 11, color: C.sub)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => checklistState.updateAll((k, v) => false)),
            style: OutlinedButton.styleFrom(foregroundColor: C.sub, side: const BorderSide(color: C.border), minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: const Text('RESET CHECKLIST'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRulebookSubTab() {
    int total = 0;
    int checked = 0;
    for (var g in TradingContent.rulebookSections) {
      for (var r in g['rules']) {
        total++;
        final id = '${g['category']}_${g['rules'].indexOf(r)}';
        if (rulebookState[id] == true) checked++;
      }
    }
    final pct = (checked / total);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradingCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('RULES REVIEWED'),
                    Text('$checked of $total', style: const TextStyle(fontSize: 11, color: C.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: pct, backgroundColor: C.border, valueColor: const AlwaysStoppedAnimation(C.blue), minHeight: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...TradingContent.rulebookSections.map((g) => _buildRuleGroup(g)),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () => setState(() => rulebookState.updateAll((k, v) => false)),
            style: OutlinedButton.styleFrom(foregroundColor: C.sub, side: const BorderSide(color: C.border), minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: const Text('UNCHECK ALL RULES'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final stats = _computeStats();
    final journalTrades = trades.where((t) => !t.isAdjustment).toList();
    
    // Detailed metrics
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
          // Performance Overview
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

          // Equity Curve
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

          // Win/Loss Breakdown
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

          // Setup Performance
          _buildPerformanceGroup('SETUP PERFORMANCE', journalTrades, (t) => t.setup),
          const SizedBox(height: 10),

          // Emotion Performance
          _buildPerformanceGroup('EMOTION PERFORMANCE', journalTrades, (t) => t.emotion),
          const SizedBox(height: 10),

          // Recovery Progress
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

          // Trade Calendar
          TradingCard(
            child: TradeCalendar(dailyPnl: _getDailyPnl()),
          ),
        ],
      ),
    );
  }

  // --- SUB-WIDGETS & HELPERS ---

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

  Widget _buildQuickBigButton(String text, Color color, VoidCallback onTap) {
    bool active = !_isKillSwitchActive;
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

  Widget _buildQuickSmallButton(String text, Color color, VoidCallback onTap) {
    bool active = !_isKillSwitchActive;
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

  Widget _buildTradeListItem(Trade t, {bool showDelete = false}) {
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
      child: Stack(
        children: [
          Column(
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
                  if (t.emotion != null) Text(TradingContent.emotions.firstWhere((e) => e['id'] == t.emotion)['icon'] ?? '', style: const TextStyle(fontSize: 13)),
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
          if (showDelete)
            Positioned(
              top: -5,
              right: -5,
              child: IconButton(icon: const Icon(Icons.close, size: 16, color: C.muted), onPressed: () => _deleteTrade(t.id)),
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

  Widget _buildFilterPill(String label, String filter) {
    final active = _journalFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _journalFilter = filter),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? C.gold2 : C.deep,
            border: Border.all(color: active ? C.gold : C.border),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? C.gold : C.muted)),
        ),
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

  Widget _buildSubTabBtn(String label, int index) {
    final active = _playbookSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _playbookSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? C.card2 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? C.gold : C.muted, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildChecklistGroup(Map<String, dynamic> group) {
    final color = group['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), border: Border(bottom: BorderSide(color: color.withOpacity(0.25)))),
            child: TradingLabel(group['category'], color: color),
          ),
          ...group['items'].map((item) {
            final done = checklistState[item['id']] == true;
            return InkWell(
              onTap: () => setState(() => checklistState[item['id']] = !done),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: done ? color : C.border, width: 2), color: done ? color.withOpacity(0.2) : Colors.transparent),
                      alignment: Alignment.center,
                      child: done ? Icon(Icons.check, size: 12, color: color) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item['text'], style: TextStyle(fontSize: 12, color: done ? C.muted : C.sub, decoration: done ? TextDecoration.lineThrough : null, height: 1.5))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRuleGroup(Map<String, dynamic> group) {
    final color = group['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), border: Border(bottom: BorderSide(color: color.withOpacity(0.25)))),
            child: TradingLabel(group['category'], color: color),
          ),
          ...group['rules'].map((rule) {
            final id = '${group['category']}_${group['rules'].indexOf(rule)}';
            final done = rulebookState[id] == true;
            return InkWell(
              onTap: () => setState(() => rulebookState[id] = !done),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: done ? color : C.border, width: 2), color: done ? color.withOpacity(0.2) : Colors.transparent),
                      alignment: Alignment.center,
                      child: done ? Icon(Icons.check, size: 12, color: color) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rule, style: TextStyle(fontSize: 12, color: done ? C.muted : C.sub, decoration: done ? TextDecoration.lineThrough : null, height: 1.5))),
                  ],
                ),
              ),
            );
          }),
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

  Widget _buildZoneMeter(double bal) {
    final pos = ((bal - account.breachBalance) / (account.targetBalance - account.breachBalance)).clamp(0.0, 1.0);
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
            Positioned(
              left: pos * 350, // Approximation
              child: Container(
                width: 18,
                height: 24,
                transform: Matrix4.translationValues(-9, -5, 0),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(5), border: Border.all(color: _getZoneInfo(bal)['color'], width: 3)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\$${account.breachBalance.toInt()} MIN', style: const TextStyle(fontSize: 9, color: C.red)),
            Text('\$${account.targetBalance.toInt()} TGT', style: const TextStyle(fontSize: 9, color: C.green)),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _getZoneInfo(double b) {
    final r = account.targetBalance - account.breachBalance;
    if (b <= account.breachBalance) return {'color': C.red, 'lbl': '⚠ BREACHED — Stop trading now', 'badge': 'BREACHED'};
    if (b < account.breachBalance + r * 0.2) return {'color': C.red, 'lbl': '⚠ DANGER ZONE — Extreme caution', 'badge': 'DANGER'};
    if (b < account.breachBalance + r * 0.45) return {'color': Colors.orange, 'lbl': '⚠ WARNING ZONE — Be very careful', 'badge': 'WARNING'};
    if (b < account.breachBalance + r * 0.75) return {'color': C.gold, 'lbl': '⚡ RECOVERY ZONE — Stay disciplined', 'badge': 'RECOVERY'};
    if (b < account.targetBalance) return {'color': C.green, 'lbl': '🎯 FINAL PUSH — Almost there!', 'badge': 'FINAL PUSH'};
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
