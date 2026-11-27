import 'dart:io';
import 'dart:typed_data';

import 'package:expensetracker/main.dart';
import 'package:expensetracker/models.dart';
import 'package:expensetracker/services/db.dart';
import 'package:expensetracker/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Renders the main screens on a small phone (360 x 800) with real fonts,
/// so layout problems can be seen. Run with: flutter test test_screens --update-goldens
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    Future<ByteData> bytes() async => ByteData.view(Uint8List.fromList(await f.readAsBytes()).buffer);
    if (RegExp(r'^Roboto-[A-Za-z]+\.ttf$').hasMatch(name)) roboto.addFont(bytes());
    if (name.startsWith('MaterialIcons-Regular')) icons.addFont(bytes());
  }
  await roboto.load();
  await icons.load();
}

void main() {
  late AppState state;
  final now = DateTime.now();
  DateTime day(int d) => DateTime(now.year, now.month, d, 10);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _loadFonts();
  });

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      state = AppState(await AppDb.open());
      await state.load();
      await state.clearAll();
      Future<Txn> add(String p, double a, TxnType t, String c, DateTime d) async {
        await state.addTxn(Txn(amount: a, type: t, category: c, merchant: p, date: d));
        return state.txns.firstWhere((x) => x.merchant == p && x.amount == a && x.date == d);
      }

      await add('Acme Technologies', 85000, TxnType.credit, 'salary', day(1));
      await add('Landlord', 18000, TxnType.debit, 'rent', day(1));
      await add('Swiggy', 486, TxnType.debit, 'food', day(2));
      await add('BigBasket', 2340, TxnType.debit, 'groceries', day(2));
      final amazon = await add('Amazon', 3499, TxnType.debit, 'shopping', day(3));
      await add('Uber', 312, TxnType.debit, 'transport', day(3));
      await add('ICCL SIP', 10000, TxnType.debit, 'investments', day(5));
      await add('KSEB', 1450, TxnType.debit, 'bills', day(6));
      await add('Netflix', 649, TxnType.debit, 'entertainment', day(6));
      await add('+91 98765 43210', 250, TxnType.debit, 'other', day(7));
      await state.addManualRefund(amazon, amount: 1500, date: day(8));
      await state.setBudget(AppState.totalBudgetKey, 40000);
      await state.setBudget('food', 6000);
      final ravi = await state.addPerson('Ravi');
      await state.splitExpense(state.txns.firstWhere((t) => t.merchant == 'BigBasket'), {ravi.id!: 1170});
      final anu = await state.addPerson('Anu');
      await state.friendPaid(person: anu, share: 450, merchant: 'Movie night', category: 'entertainment', date: day(9));
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('Main screens on a small phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(AppScope(state: state, child: const MoneyApp()));
    await shot(tester, '1_overview_top');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await shot(tester, '2_overview_middle');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await shot(tester, '3_overview_bottom');
    await tester.tap(find.text('Activity'));
    await shot(tester, '4_activity');
    await tester.tap(find.text('Budgets'));
    await shot(tester, '5_budgets');
    await tester.tap(find.text('People'));
    await shot(tester, '5b_people');
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amazon').first);
    await shot(tester, '6_refunded_expense');
    await tester.tap(find.text('Change').first);
    await shot(tester, '7_category_picker');
  });
}
