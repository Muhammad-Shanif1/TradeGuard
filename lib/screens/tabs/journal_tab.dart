import 'package:flutter/material.dart';
import '../../trading_constants.dart';
import '../../trading_models.dart';
import '../../trading_widgets.dart';

class JournalTab extends StatefulWidget {
  final List<Trade> trades;
  final bool isKillSwitchActive;
  final Function(double, {String? dir, String? setup, String? emo, String? notes, String? lots, bool isAdj}) onAddTrade;
  final Function(String) onDeleteTrade;

  const JournalTab({
    super.key,
    required this.trades,
    required this.isKillSwitchActive,
    required this.onAddTrade,
    required this.onDeleteTrade,
  });

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  final TextEditingController _journalPnlController = TextEditingController();
  final TextEditingController _journalLotsController = TextEditingController();
  final TextEditingController _journalNotesController = TextEditingController();
  
  String? _selectedDir;
  String? _selectedSetup;
  String? _selectedEmo;
  String _journalFilter = 'all';

  @override
  void dispose() {
    _journalPnlController.dispose();
    _journalLotsController.dispose();
    _journalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrades = widget.trades.where((t) {
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
                ElevatedButton(
                  onPressed: widget.isKillSwitchActive ? null : () {
                    final pnl = double.tryParse(_journalPnlController.text);
                    if (pnl != null) {
                      widget.onAddTrade(pnl, dir: _selectedDir, setup: _selectedSetup, emo: _selectedEmo, notes: _journalNotesController.text, lots: _journalLotsController.text);
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
          TradingCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TradingLabel('TRADE HISTORY'),
                    // Note: Clear All functionality removed here for safety, or you can implement it via a callback
                  ],
                ),
                const SizedBox(height: 10),
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
          if (showDelete)
            Positioned(
              top: -5,
              right: -5,
              child: IconButton(icon: const Icon(Icons.close, size: 16, color: C.muted), onPressed: () => widget.onDeleteTrade(t.id)),
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
