import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/activity_screen.dart';
import 'screens/add_txn_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/people_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/home_screen.dart';
import 'services/db.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final db = await AppDb.open();
  final state = AppState(db);
  await state.load();
  runApp(AppScope(state: state, child: const MoneyApp()));
}

class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _titles = ['Overview', 'Activity', 'Budgets', 'Bills', 'People'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onSeeAll: () => setState(() => _tab = 1),
        onOpenBudgets: () => setState(() => _tab = 2),
        onOpenBills: () => setState(() => _tab = 3),
      ),
      const ActivityScreen(),
      const BudgetsScreen(),
      const BillsScreen(),
      const PeopleScreen(),
    ];

    return Scaffold(
      appBar: _tab == 0
          ? null
          : AppBar(
              backgroundColor: AppColors.bg,
              surfaceTintColor: Colors.transparent,
              title: Text(_titles[_tab],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      floatingActionButton: _tab <= 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTxnScreen())),
              icon: const Icon(Icons.add_rounded, size: 26),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.2),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline_rounded), selectedIcon: Icon(Icons.pie_chart_rounded), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Bills'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group_rounded), label: 'People'),
        ],
      ),
    );
  }
}
