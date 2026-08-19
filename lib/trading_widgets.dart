import 'package:flutter/material.dart';
import 'trading_constants.dart';

class TradingLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final double letterSpacing;

  const TradingLabel(this.text, {
    super.key,
    this.color = C.muted,
    this.fontSize = 9,
    this.letterSpacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
        color: color,
      ),
    );
  }
}

class TradingCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const TradingCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? C.border,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool large;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = C.text,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(large ? 12 : 10),
      decoration: BoxDecoration(
        color: C.deep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 24 : 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              color: C.muted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class PillSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String) onSelected;

  const PillSelector({
    super.key,
    required this.options,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? C.gold2 : C.deep,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.gold : C.border),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? C.gold : C.sub,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? selectedId;
  final Function(String) onSelected;
  final Color activeColor;
  final Color activeBgColor;

  const ToggleRow({
    super.key,
    required this.items,
    this.selectedId,
    required this.onSelected,
    this.activeColor = C.blue,
    this.activeBgColor = C.blue2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final isSelected = item['id'] == selectedId;
        final color = isSelected ? (item['activeColor'] ?? activeColor) : C.sub;
        final bgColor = isSelected ? (item['activeBgColor'] ?? activeBgColor) : C.deep;
        final borderColor = isSelected ? color : C.border;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: Text(
                item['label'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MiniEquityChart extends StatelessWidget {
  final List<double> data;
  final double target;
  final double breach;

  const MiniEquityChart({
    super.key,
    required this.data,
    required this.target,
    required this.breach,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No data", style: TextStyle(color: C.muted)));
    }

    return CustomPaint(
      size: const Size(double.infinity, 100),
      painter: ChartPainter(data: data, target: target, breach: breach),
    );
  }
}

class TradeCalendar extends StatelessWidget {
  final Map<DateTime, double> dailyPnl;

  const TradeCalendar({super.key, required this.dailyPnl});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    // Adjust to start from Monday (1)
    int startOffset = firstDayOfMonth.weekday - 1;
    if (startOffset < 0) startOffset = 6;

    final List<Widget> dayWidgets = [];
    
    // Add empty spaces for offset
    for (int i = 0; i < startOffset; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add days of month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final pnl = dailyPnl[DateTime(date.year, date.month, date.day)] ?? 0.0;
      
      Color color = C.deep;
      if (pnl > 0) color = C.green.withOpacity(0.2);
      if (pnl < 0) color = C.red.withOpacity(0.2);

      dayWidgets.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: pnl != 0 ? (pnl > 0 ? C.green : C.red).withOpacity(0.5) : C.border, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(day.toString(), style: const TextStyle(fontSize: 9, color: C.sub)),
              if (pnl != 0)
                Text(
                  (pnl > 0 ? '+' : '') + pnl.toStringAsFixed(0),
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: pnl > 0 ? C.green : C.red),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TradingLabel('TRADE CALENDAR'),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1,
          children: dayWidgets,
        ),
      ],
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> data;
  final double target;
  final double breach;

  ChartPainter({required this.data, required this.target, required this.breach});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = C.gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = C.gold.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final targetPaint = Paint()
      ..color = C.green.withOpacity(0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final breachPaint = Paint()
      ..color = C.red.withOpacity(0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final padding = size.height * 0.1;
    final chartHeight = size.height - padding * 2;
    
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    minVal = minVal < breach ? minVal : breach;
    maxVal = maxVal > target ? maxVal : target;
    
    final range = (maxVal - minVal).abs();
    final scale = range == 0 ? 1.0 : chartHeight / range;

    double getY(double val) => size.height - padding - (val - minVal) * scale;
    double getX(int index) => (index / (data.length - 1)) * size.width;

    final path = Path();
    path.moveTo(getX(0), getY(data[0]));
    for (int i = 1; i < data.length; i++) {
      path.lineTo(getX(i), getY(data[i]));
    }

    // Draw lines for target and breach
    final targetY = getY(target);
    final breachY = getY(breach);
    
    canvas.drawLine(Offset(0, targetY), Offset(size.width, targetY), targetPaint);
    canvas.drawLine(Offset(0, breachY), Offset(size.width, breachY), breachPaint);

    // Draw Fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw Line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
