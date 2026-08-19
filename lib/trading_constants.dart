import 'package:flutter/material.dart';

class C {
  static const Color bg = Color(0xFF080810);
  static const Color bg2 = Color(0xFF0D0D1A);
  static const Color card = Color(0xFF111120);
  static const Color card2 = Color(0xFF161628);
  static const Color deep = Color(0xFF0A0A16);
  
  static const Color gold = Color(0xFFF0B429);
  static const Color gold2 = Color(0x26F0B429);
  
  static const Color red = Color(0xFFEF4444);
  static const Color red2 = Color(0x26EF4444);
  
  static const Color green = Color(0xFF22C55E);
  static const Color green2 = Color(0x2622C55E);
  
  static const Color blue = Color(0xFF6366F1);
  static const Color blue2 = Color(0x266366F1);
  
  static const Color purple = Color(0xFFA855F7);
  static const Color purple2 = Color(0x26A855F7);
  
  static const Color text = Color(0xFFF0F0F8);
  static const Color sub = Color(0xFF9090A8);
  static const Color muted = Color(0xFF505068);
  static const Color border = Color(0xFF1E1E32);
}

class TradingContent {
  static const List<String> setupTypes = ['S/R', 'Breakout', 'Trend', 'Reversal', 'Range', 'Other'];
  static const List<Map<String, String>> emotions = [
    {'id': 'calm', 'label': 'Calm', 'icon': '😌'},
    {'id': 'neutral', 'label': 'Neutral', 'icon': '😐'},
    {'id': 'anxious', 'label': 'Anxious', 'icon': '😟'},
    {'id': 'fomo', 'label': 'FOMO', 'icon': '😡'},
  ];

  static const List<Map<String, dynamic>> rulebookSections = [
    {
      'category': 'BEFORE THE TRADE',
      'color': C.gold,
      'rules': [
        'No trade without a clear named setup. If you cannot name it — do not enter.',
        'Entry price, stop loss, and take profit ALL decided before entering.',
        'Know the exact price where you will move stop to breakeven (+\$20 profit).',
        'Never enter because another trader entered. You are intraday, not a scalper.',
        'Check: is there a valid support/resistance? Am I forgetting a breakout?',
        'Ask: am I trading this setup, or am I chasing movement?'
      ],
    },
    {
      'category': 'DURING THE TRADE',
      'color': C.green,
      'rules': [
        'Never move stop loss deeper into loss. Never.',
        'Trade hits +\$20 profit → move stop to breakeven immediately. No exceptions.',
        'Trade reverses after +\$20 → close at \$10–\$15. Do not wait for full target.',
        'Trade continues past +\$20 → hold for full profit target.',
        'Never let a +\$20 profit reverse to \$0 or negative. Book the partial.',
        'Never add to a losing position under any circumstances.'
      ],
    },
    {
      'category': 'AFTER THE TRADE',
      'color': C.blue,
      'rules': [
        'Hit daily profit target? Platform closed. Done. Log the trade.',
        'Partial win (\$10–\$15)? Also a win. Platform closed. Log it.',
        'Took a loss? Platform closed. No revenge trade. Log it.',
        'Never take a 3rd trade to recover from two bad days.',
        'Log every trade with setup, emotion, and notes.',
        'A zero-trade day is not failure. Log it as discipline.'
      ],
    },
    {
      'category': 'NEVER DO THESE',
      'color': C.red,
      'rules': [
        'Never increase lot size after a loss to recover faster.',
        'Never trade out of boredom or FOMO. No setup = no trade.',
        'Never follow scalpers. You are an intraday trader.',
        'Never hold a losing trade past your stop loss.',
        'Never trade when mentally exhausted or emotionally triggered.',
        'Never let a winning trade reverse back to zero or negative.',
        'Never ignore your daily loss limit for any reason.'
      ],
    },
    {
      'category': 'COMPOUNDING MINDSET',
      'color': C.gold,
      'rules': [
        'Daily target × 20 trading days = consistent monthly growth.',
        'A \$15 partial win beats chasing \$30 and giving it all back.',
        'Small consistent wins protect the account. Greed breaches it.',
        'One good trade per day is enough. Quality over quantity.',
        'The goal right now is discipline. Profit follows discipline.',
        'You are building a habit, not just making money.'
      ],
    },
  ];

  static List<Map<String, dynamic>> getChecklistGroups(double risk, double profit, int maxTrades) {
    return [
      {
        'category': 'SETUP & ANALYSIS',
        'color': C.gold,
        'items': [
          {'id': 's1', 'text': 'I can clearly name this setup — not just "it looks good"'},
          {'id': 's2', 'text': 'This is MY analysis — not because another trader entered'},
          {'id': 's3', 'text': 'I have identified a valid support or resistance level'},
          {'id': 's4', 'text': 'I have checked for a breakout — am I trading the right direction?'},
          {'id': 's5', 'text': 'This matches my intraday timeframe, not a scalp entry'}
        ],
      },
      {
        'category': 'TRADE PLAN',
        'color': C.blue,
        'items': [
          {'id': 'p1', 'text': 'Entry price decided before I open the trade'},
          {'id': 'p2', 'text': 'Stop loss placed — max loss within my \$$risk limit'},
          {'id': 'p3', 'text': 'Take profit target set at \$$profit'},
          {'id': 'p4', 'text': 'I know the exact price where I move stop to breakeven (+\$20)'},
          {'id': 'p5', 'text': 'If trade reverses after +\$20, I will close at \$10–\$15 immediately'}
        ],
      },
      {
        'category': 'POSITION & SIZING',
        'color': C.green,
        'items': [
          {'id': 'z1', 'text': 'Lot size is 0.01 (or 0.02 only if this is an A+ setup)'},
          {'id': 'z2', 'text': 'I am NOT increasing lot size to recover a previous loss'},
          {'id': 'z3', 'text': 'Risk on this trade does not exceed my \$$risk max per trade'}
        ],
      },
      {
        'category': 'ACCOUNT STATUS',
        'color': C.gold,
        'items': [
          {'id': 'a1', 'text': 'I have NOT already hit my daily profit target today (\$$profit)'},
          {'id': 'a2', 'text': 'I have NOT already hit my daily loss limit today (\$$risk)'},
          {'id': 'a3', 'text': 'This is trade #1 or #2 today — I am within my max $maxTrades trades/day'}
        ],
      },
      {
        'category': 'MENTAL STATE',
        'color': C.red,
        'items': [
          {'id': 'm1', 'text': 'I am NOT in revenge mode from a previous loss'},
          {'id': 'm2', 'text': 'I am NOT mentally exhausted or emotionally triggered'},
          {'id': 'm3', 'text': 'I am NOT entering because of FOMO or boredom'},
          {'id': 'm4', 'text': 'I am NOT chasing a move that has already happened'}
        ],
      },
    ];
  }
}
