import 'package:expensetracker/models.dart';
import 'package:expensetracker/services/db.dart';
import 'package:expensetracker/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a realistic month and checks every number the dashboard shows.
void main() {
  late AppState state;
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);
  DateTime day(int d) => DateTime(now.year, now.month, d, 10);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    state = AppState(await AppDb.open());
    await state.load();
    await state.clearAll();
  });

  Future<Txn> add(String payee, double amount, TxnType type, String category, DateTime date) async {
    await state.addTxn(Txn(amount: amount, type: type, category: category, merchant: payee, date: date));
    return state.txns.firstWhere((t) => t.merchant == payee && t.amount == amount && t.date == date);
  }

  test('Dashboard totals add up', () async {
    await add('Acme Ltd', 50000, TxnType.credit, 'salary', day(1));
    await add('Swiggy', 500, TxnType.debit, 'food', day(2));
    final amazon = await add('Amazon', 2000, TxnType.debit, 'shopping', day(2));
    final uber = await add('Uber', 400, TxnType.debit, 'transport', day(3));
    final friend = await add('Ravi', 300, TxnType.credit, 'misc_income', day(4));
    await add('ICCL SIP', 5000, TxnType.debit, 'investments', day(5));
    await add('Groww', 1000, TxnType.credit, 'redemption', day(5));
    final self = await add('Me HDFC', 10000, TxnType.debit, 'transfers', day(5));
    final lastMonthBuy = await add('Flipkart', 1000, TxnType.debit, 'shopping', DateTime(lastMonth.year, lastMonth.month, 20, 10));
    final flipkartRefund = await add('Flipkart', 1000, TxnType.credit, 'refund', day(3));

    await state.setExcluded(self, true); // transfer between own accounts
    await state.addManualRefund(amazon, amount: 2000, date: day(6)); // full refund, added by hand
    await state.linkRefund(uber, friend, 100); // partial: ₹100 of Ravi's ₹300 refunds the Uber ride
    await state.linkRefund(lastMonthBuy, flipkartRefund, 1000); // refund arrives the month after

    // Spent: Swiggy 500 + Amazon 0 (refunded) + Uber 300 (400 - 100). Not the SIP, not the self-transfer.
    expect(state.spentIn(month), 800);
    // Received: salary 50,000 + the ₹200 of Ravi's money that isn't a refund.
    // Not the Flipkart refund, the manual Amazon refund, or the Groww redemption.
    expect(state.receivedIn(month), 50200);
    expect(state.savedIn(month), 5000);
    expect(state.withdrawnIn(month), 1000);
    expect(state.netSavedIn(month), 4000);
    expect(state.savingsRate(month), closeTo(4000 / 50200, 1e-9));
    // Left over on the dashboard = received - spent - net invested.
    expect(state.receivedIn(month) - state.spentIn(month) - state.netSavedIn(month), 45400);

    // "Where it went" adds up to Spent, and fully refunded categories drop out.
    final byCategory = Map.fromEntries(state.spendByCategory(month));
    expect(byCategory, {'food': 500.0, 'transport': 300.0});
    expect(byCategory.values.fold<double>(0, (a, b) => a + b), state.spentIn(month));
    expect(state.spentInCategory(month, 'shopping'), 0);
    expect(state.biggestExpense(month)?.merchant, 'Swiggy');

    // The refund comes off the month of the purchase.
    expect(state.spentIn(lastMonth), 0);

    // What each transaction shows.
    expect(state.netAmount(amazon), 0);
    expect(state.netAmount(uber), 300);
    expect(state.netAmount(friend), 200);
  });

  test('Unlinking a refund puts the totals back', () async {
    final shoes = await add('Myntra', 3000, TxnType.debit, 'shopping', day(2));
    final back = await add('Myntra', 3000, TxnType.credit, 'refund', day(4));
    await state.linkRefund(shoes, back, 3000);
    expect(state.spentIn(month), 0);
    expect(state.receivedIn(month), 0);
    await state.unlinkRefund(state.refundsOf(shoes).single.$2);
    expect(state.spentIn(month), 3000);
    expect(state.receivedIn(month), 3000);
  });

  test('Investments that were switched off count once moved to a savings category', () async {
    final sip = await add('Zerodha Coin', 3000, TxnType.debit, 'other', day(2));
    await state.setExcluded(sip, true);
    expect(state.savedIn(month), 0);
    await state.setCategory(sip, 'investments');
    expect(state.savedIn(month), 3000);
    expect(state.spentIn(month), 0);
  });

  test('Each dashboard tab lists every category and adds up to its total', () async {
    await add('Acme Ltd', 60000, TxnType.credit, 'salary', day(1));
    await add('Ravi', 2000, TxnType.credit, 'misc_income', day(2));
    for (final c in ['food', 'groceries', 'transport', 'fuel', 'shopping', 'bills', 'rent', 'health']) {
      await add('Shop $c', 100, TxnType.debit, c, day(3));
    }
    await add('ICCL SIP', 5000, TxnType.debit, 'investments', day(5));
    await add('Bank FD', 10000, TxnType.debit, 'deposits', day(5));
    await add('Groww', 1500, TxnType.credit, 'redemption', day(6));

    final spent = state.breakdown(month, Segment.spent);
    expect(spent.length, 8); // all categories, not just the top six
    expect(spent.fold<double>(0, (s, e) => s + e.value), state.spentIn(month));

    final invested = Map.fromEntries(state.breakdown(month, Segment.invested));
    expect(invested, {'deposits': 10000.0, 'investments': 5000.0, 'redemption': -1500.0});
    expect(invested.values.fold<double>(0, (s, v) => s + v), state.netSavedIn(month));

    final income = state.breakdown(month, Segment.income);
    expect(income.map((e) => e.key), ['salary', 'misc_income']);
    expect(income.fold<double>(0, (s, e) => s + e.value), state.receivedIn(month));
  });

  test('Categories sit in three groups, and returns are income', () async {
    expect(categoryFor('investments').group, CategoryGroup.investment);
    expect(categoryFor('deposits').group, CategoryGroup.investment);
    expect(categoryFor('redemption').group, CategoryGroup.investment);
    expect(categoryFor('returns').group, CategoryGroup.income);
    expect(categoryFor('food').group, CategoryGroup.expense);
    expect(categoriesIn(CategoryGroup.expense).any((c) => c.saving), isFalse);

    await add('HDFC MF', 800, TxnType.credit, 'returns', day(2));
    await add('Groww', 20000, TxnType.credit, 'redemption', day(2));
    expect(state.receivedIn(month), 800); // the dividend is income, the redemption is not
    expect(state.withdrawnIn(month), 20000);
  });

  test('Month-end salary counts toward the next month', () async {
    Txn salary(DateTime d, {String note = ''}) =>
        Txn(amount: 90000, type: TxnType.credit, category: 'salary', merchant: 'Acme', note: note, date: d);
    expect(salary(DateTime(2026, 8, 30)).budgetMonth, DateTime(2026, 9)); // 'Aug salary' paid on 30 Aug
    expect(salary(DateTime(2026, 8, 27)).budgetMonth, DateTime(2026, 9));
    expect(salary(DateTime(2026, 2, 25)).budgetMonth, DateTime(2026, 3)); // last 5 days of a short month
    expect(salary(DateTime(2026, 8, 20)).budgetMonth, DateTime(2026, 8));
    expect(salary(DateTime(2026, 8, 20), note: 'Sep salary advance').budgetMonth, DateTime(2026, 9));
    expect(salary(DateTime(2026, 9, 1)).budgetMonth, DateTime(2026, 9));
    expect(salary(DateTime(2026, 12, 30)).budgetMonth, DateTime(2027, 1));
    // Only salary moves.
    expect(Txn(amount: 500, type: TxnType.credit, category: 'misc_income', date: DateTime(2026, 8, 30)).budgetMonth,
        DateTime(2026, 8));
    expect(Txn(amount: 500, type: TxnType.debit, category: 'rent', date: DateTime(2026, 8, 30)).budgetMonth,
        DateTime(2026, 8));

    final aug = DateTime(2026, 8), sep = DateTime(2026, 9);
    final paid = await add('Acme Payroll', 90000, TxnType.credit, 'salary', DateTime(2026, 8, 30, 10));
    expect(state.receivedIn(aug), 0);
    expect(state.receivedIn(sep), 90000);
    // The user can keep it in August instead.
    await state.setCountMonth(paid, aug);
    expect(state.receivedIn(aug), 90000);
    expect(state.receivedIn(sep), 0);
  });
}
