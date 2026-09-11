import 'package:flutter/material.dart';
import '../../trading_constants.dart';
import '../../trading_widgets.dart';

class LockoutTab extends StatelessWidget {
  final bool isKillSwitchActive;
  final Duration remainingLockoutTime;

  const LockoutTab({
    super.key,
    required this.isKillSwitchActive,
    required this.remainingLockoutTime,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(
            isKillSwitchActive ? Icons.lock_clock : Icons.lock_open,
            size: 80,
            color: isKillSwitchActive ? C.red : C.green,
          ),
          const SizedBox(height: 24),
          Text(
            isKillSwitchActive ? 'KILL SWITCH ACTIVE' : 'SYSTEM UNLOCKED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isKillSwitchActive ? C.red : C.green,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isKillSwitchActive 
              ? 'You have hit 2 losses today. To protect your capital, all trading functions are disabled for 6 hours.'
              : 'Trading functions are fully enabled. Remember to follow your rules and maintain discipline.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: C.sub, height: 1.5),
          ),
          const SizedBox(height: 40),
          if (isKillSwitchActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: C.deep,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.red.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const TradingLabel('TIME REMAINING UNTIL UNLOCK', color: C.muted, fontSize: 10),
                  const SizedBox(height: 12),
                  Text(
                    _formatDuration(remainingLockoutTime),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: C.text,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: C.deep,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.green.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, color: C.green, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'SAFE TO TRADE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          TradingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TradingLabel('LOCKOUT RULES'),
                const SizedBox(height: 12),
                _buildLockoutRule('Trigger', '2 losing trades in a single calendar day.'),
                _buildLockoutRule('Duration', 'Exactly 6 hours from the 2nd loss.'),
                _buildLockoutRule('Scope', 'Quick Logs, Journal Logs, and Stat modifications are disabled.'),
                _buildLockoutRule('Goal', 'Prevent revenge trading and protect your emotional capital.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutRule(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: C.sub, height: 1.4),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(color: C.text, fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
