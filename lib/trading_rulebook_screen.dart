import 'package:flutter/material.dart';
import 'trading_constants.dart';
import 'trading_models.dart';
import 'trading_widgets.dart';
import 'firebase_service.dart';
import 'screens/tabs/home_tab.dart';
import 'screens/tabs/journal_tab.dart';
import 'screens/tabs/risk_tab.dart';
import 'screens/tabs/playbook_tab.dart';
import 'screens/tabs/stats_tab.dart';
import 'screens/tabs/lockout_tab.dart';
import 'dart:math' as math;
import 'dart:async';

class TradingRulebookScreen extends StatefulWidget {
  const TradingRulebookScreen({super.key});

  @override
  State<TradingRulebookScreen> createState() => _TradingRulebookScreenState();
}

class _TradingRulebookScreenState extends State<TradingRulebookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Firebase
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _tradesSubscription;
  StreamSubscription? _checklistSubscription;

  // State
  AccountSettings account = AccountSettings();
  TradingLimits limits = TradingLimits();
  double currentBalance = 9808.0;
  List<Trade> trades = [];
  Map<String, bool> checklistState = {};
  
  // Optimization: Cached Kill Switch data
  DateTime? _cachedKillSwitchTriggerTime;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: 0);
    _tabController.addListener(() => setState(() {}));
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final settingsData = await _firebaseService.getSettings();
    if (settingsData != null && mounted) {
      setState(() {
        if (settingsData['account'] != null) {
          account = AccountSettings.fromMap(settingsData['account']);
        }
        if (settingsData['limits'] != null) {
          limits = TradingLimits.fromMap(settingsData['limits']);
        }
      });
    }

    _tradesSubscription = _firebaseService.streamTrades().listen((newTrades) {
      if (mounted) {
        setState(() {
          trades = newTrades;
          _recalculateBalance();
          _updateKillSwitchCache();
        });
      }
    });

    _checklistSubscription = _firebaseService.streamChecklist().listen((newState) {
      if (mounted) {
        setState(() {
          checklistState = newState;
        });
      }
    });
  }

  @override
  void dispose() {
    _tradesSubscription?.cancel();
    _checklistSubscription?.cancel();
    _lockoutTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _addTrade(double pnl, {String? dir, String? setup, String? emo, String? notes, String? lots, bool isAdj = false}) {
    if (_isKillSwitchActive && !isAdj) return;

    final newTrade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pnl: pnl,
      balance: currentBalance + pnl,
      timestamp: DateTime.now(),
      direction: dir,
      setup: setup,
      emotion: emo,
      notes: notes,
      lots: lots,
      isAdjustment: isAdj,
    );
    
    _firebaseService.saveTrade(newTrade);
  }

  void _deleteTrade(String id) {
    _firebaseService.deleteTrade(id);
  }

  void _saveSettings(AccountSettings newAccount, TradingLimits newLimits) {
    setState(() {
      account = newAccount;
      limits = newLimits;
      _recalculateBalance();
    });
    _firebaseService.saveSettings(account, limits);
  }

  void _recalculateBalance() {
    double b = account.initialBalance;
    final reversedTrades = trades.reversed.toList();
    for (var t in reversedTrades) {
      b = (b + t.pnl);
    }
    currentBalance = b;
  }

  void _updateKillSwitchCache() {
    // Group trades by day to find the 2nd loss of any day
    Map<String, List<Trade>> tradesByDay = {};
    for (var t in trades) {
      if (t.isAdjustment || t.pnl >= 0) continue;
      String dayKey = "${t.timestamp.year}-${t.timestamp.month}-${t.timestamp.day}";
      tradesByDay.putIfAbsent(dayKey, () => []).add(t);
    }
    
    DateTime? latestTrigger;
    tradesByDay.forEach((day, dayTrades) {
      if (dayTrades.length >= 2) {
        dayTrades.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        DateTime triggerTime = dayTrades[1].timestamp;
        if (latestTrigger == null || triggerTime.isAfter(latestTrigger!)) {
          latestTrigger = triggerTime;
        }
      }
    });
    
    _cachedKillSwitchTriggerTime = latestTrigger;
    
    // Start timer if active
    if (_isKillSwitchActive) {
      _startLockoutTimer();
    } else {
      _lockoutTimer?.cancel();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isKillSwitchActive) {
        timer.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  bool get _isKillSwitchActive {
    if (_cachedKillSwitchTriggerTime == null) return false;
    final now = DateTime.now();
    final lockoutEnd = _cachedKillSwitchTriggerTime!.add(const Duration(hours: 6));
    return now.isBefore(lockoutEnd);
  }

  Duration get _remainingLockoutTime {
    if (_cachedKillSwitchTriggerTime == null) return Duration.zero;
    final lockoutEnd = _cachedKillSwitchTriggerTime!.add(const Duration(hours: 6));
    final remaining = lockoutEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
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
                  HomeTab(
                    account: account,
                    limits: limits,
                    currentBalance: currentBalance,
                    trades: trades,
                    isKillSwitchActive: _isKillSwitchActive,
                    onAddTrade: _addTrade,
                  ),
                  JournalTab(
                    trades: trades,
                    isKillSwitchActive: _isKillSwitchActive,
                    onAddTrade: _addTrade,
                    onDeleteTrade: _deleteTrade,
                  ),
                  RiskTab(
                    account: account,
                    limits: limits,
                    currentBalance: currentBalance,
                    trades: trades,
                    isKillSwitchActive: _isKillSwitchActive,
                    onSaveSettings: _saveSettings,
                    onAddAdjustment: (pnl, {isAdj = true, notes}) => _addTrade(pnl, isAdj: isAdj, notes: notes),
                  ),
                  PlaybookTab(
                    limits: limits,
                    checklistState: checklistState,
                    onChecklistChanged: (newState) {
                      setState(() => checklistState = newState);
                      _firebaseService.saveChecklistState(newState);
                    },
                  ),
                  StatsTab(
                    account: account,
                    limits: limits,
                    currentBalance: currentBalance,
                    trades: trades,
                  ),
                  LockoutTab(
                    isKillSwitchActive: _isKillSwitchActive,
                    remainingLockoutTime: _remainingLockoutTime,
                  ),
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
    final range = account.targetBalance - account.initialBalance;
    final progress = range == 0 ? 0.0 : ((currentBalance - account.initialBalance) / range).clamp(0.0, 1.0);
    
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
              Row(
                children: [
                  const TradingLabel('TRADEGUARD · XAU/USD', color: C.gold),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 14, color: C.muted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await _firebaseService.signOut();
                    },
                  ),
                ],
              ),
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
    final tabs = ['HOME', 'JOURNAL', 'RISK', 'PLAYBOOK', 'STATS', 'LOCKOUT'];
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

  Map<String, dynamic> _getZoneInfo(double b) {
    final r = account.targetBalance - account.breachBalance;
    if (b <= account.breachBalance) return {'color': C.red, 'lbl': '⚠ BREACHED — Stop trading now', 'badge': 'BREACHED'};
    if (b < account.breachBalance + r * 0.2) return {'color': C.red, 'lbl': '⚠ DANGER ZONE — Extreme caution', 'badge': 'DANGER'};
    if (b < account.breachBalance + r * 0.45) return {'color': Colors.orange, 'lbl': '⚠ WARNING ZONE — Be very careful', 'badge': 'WARNING'};
    if (b < account.breachBalance + r * 0.75) return {'color': C.gold, 'lbl': '⚡ RECOVERY ZONE — Stay disciplined', 'badge': 'RECOVERY'};
    if (b < account.targetBalance) return {'color': C.green, 'lbl': '🎯 FINAL PUSH — Almost there!', 'badge': 'FINAL PUSH'};
    return {'color': C.green, 'lbl': '✓ TARGET REACHED — Account recovered!', 'badge': 'RECOVERED'};
  }
}
