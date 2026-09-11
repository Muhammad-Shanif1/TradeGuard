import 'package:flutter/material.dart';
import '../../trading_constants.dart';
import '../../trading_models.dart';
import '../../trading_widgets.dart';

class PlaybookTab extends StatefulWidget {
  final TradingLimits limits;
  final Map<String, bool> checklistState;
  final Function(Map<String, bool>) onChecklistChanged;

  const PlaybookTab({
    super.key,
    required this.limits,
    required this.checklistState,
    required this.onChecklistChanged,
  });

  @override
  State<PlaybookTab> createState() => _PlaybookTabState();
}

class _PlaybookTabState extends State<PlaybookTab> {
  int _playbookSubTab = 0; // 0: Checklist, 1: Rulebook
  final Map<String, bool> _rulebookState = {};

  @override
  Widget build(BuildContext context) {
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
    final ckGroups = TradingContent.getChecklistGroups(widget.limits.riskPerTrade, widget.limits.profitTarget, widget.limits.maxTrades);
    int total = 0;
    int checked = 0;
    for (var g in ckGroups) {
      for (var i in g['items']) {
        total++;
        if (widget.checklistState[i['id']] == true) checked++;
      }
    }
    final all = checked == total;
    final pct = total == 0 ? 0.0 : (checked / total);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: all ? const Color(0x2622C55E) : (checked == 0 ? C.card : const Color(0x26EF4444)),
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
              decoration: BoxDecoration(color: const Color(0x2622C55E), border: Border.all(color: const Color(0x6622C55E)), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text('✓', style: TextStyle(fontSize: 22)),
                  const Text('All clear. You may enter the trade.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.green)),
                  Text('Target \$${widget.limits.profitTarget.toInt()} · Risk \$${widget.limits.riskPerTrade.toInt()} · Risk-free at +\$20', style: const TextStyle(fontSize: 11, color: C.sub)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final newState = Map<String, bool>.from(widget.checklistState);
              newState.updateAll((k, v) => false);
              widget.onChecklistChanged(newState);
            },
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
        if (_rulebookState[id] == true) checked++;
      }
    }
    final pct = total == 0 ? 0.0 : (checked / total);

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
            onPressed: () => setState(() => _rulebookState.updateAll((k, v) => false)),
            style: OutlinedButton.styleFrom(foregroundColor: C.sub, side: const BorderSide(color: C.border), minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: const Text('UNCHECK ALL RULES'),
          ),
          const SizedBox(height: 20),
        ],
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
            final done = widget.checklistState[item['id']] == true;
            return InkWell(
              onTap: () {
                final newState = Map<String, bool>.from(widget.checklistState);
                newState[item['id']] = !done;
                widget.onChecklistChanged(newState);
              },
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
            final done = _rulebookState[id] == true;
            return InkWell(
              onTap: () => setState(() => _rulebookState[id] = !done),
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
}
