import 'package:flutter/material.dart';
import 'trading_rulebook_screen.dart';
import 'trading_constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        primaryColor: C.gold,
        fontFamily: 'Segoe UI', // Fallback to system if not found
        colorScheme: const ColorScheme.dark(
          primary: C.gold,
          secondary: C.gold,
          surface: C.card,
        ),
        useMaterial3: true,
      ),
      home: const TradingRulebookScreen(),
    );
  }
}
