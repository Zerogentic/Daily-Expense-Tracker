import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'services/categorizer.dart';
import 'services/db.dart';

class AppState extends ChangeNotifier {
  AppState(this._db);

  final AppDb _db;

  List<Txn> txns = [];
  Map<String, double> budgets = {};
  List<Bill> bills = [];

  /// Categories the user picked per payee; used to suggest a category when adding.
  Map<String, String> rules = {};
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  static const totalBudgetKey = '_total';

  Future<void> load() async {
    await _loadCategories();
    txns = await _db.allTxns();
    await _loadRefunds();
    budgets = await _db.budgets();
    bills = await _db.bills();
    rules = await _db.rules();
    notifyListeners();
  }

  /// Renames a payee on this transaction, or on every transaction with the same payee.
  Future<void> renamePayee(Txn t, String name, {required bool all}) async {
    final oldKey = t.merchant.toLowerCase().trim();
    final newName = name.trim();
    if (newName.isEmpty) return;
    for (var i = 0; i < txns.length; i++) {
      final x = txns[i];
      final match = x.id == t.id || (all && oldKey.isNotEmpty && x.merchant.toLowerCase().trim() == oldKey);
      if (!match || x.merchant == newName) continue;
      final updated = x.copyWith(merchant: newName);
      await _db.updateTxn(updated);
      txns[i] = updated;
    }
    final rule = rules[oldKey];
    if (all && rule != null) await rememberCategory(newName, rule);
    notifyListeners();
  }

  // ---------- Month navigation ----------
  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  void shiftMonth(int delta) {
    final next = DateTime(month.year, month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    month = next;
    notifyListeners();
  }

  // ---------- Refunds ----------
  List<RefundLink> refundLinks = [];
  final Map<int, double> _refundedOf = {};
  final Map<int, double> _usedOf = {};

  Future<void> _loadRefunds() async {
    refundLinks = await _db.refunds();
    _indexRefunds();
  }

  void _indexRefunds() {
    _refundedOf.clear();
    _usedOf.clear();
    final ids = {for (final t in txns) if (t.id != null) t.id!};
    for (final r in refundLinks) {
      if (!ids.contains(r.expenseId) || !ids.contains(r.incomeId)) continue;
      _refundedOf[r.expenseId] = (_refundedOf[r.expenseId] ?? 0) + r.amount;
      _usedOf[r.incomeId] = (_usedOf[r.incomeId] ?? 0) + r.amount;
    }
  }

  /// Total refunded on an expense.
  double refundedFor(Txn t) => t.id == null ? 0 : (_refundedOf[t.id] ?? 0);

  /// How much of an income is counted as refunds.
  double usedAsRefund(Txn t) => t.id == null ? 0 : (_usedOf[t.id] ?? 0);

  /// What a transaction adds to totals. Refunds come off the expense, in the
  /// expense's month, and the refunded part of an income stops counting as income.
  double counted(Txn t) {
    if (t.excluded) return 0;
    final v = t.isExpense ? t.amount - refundedFor(t) : t.amount - usedAsRefund(t);
    return v < 0.005 ? 0 : v;
  }

  /// The amount after refunds: what was really spent, or what still counts as income.
  /// Unlike [counted], it ignores the "Count as an expense" switch.
  double netAmount(Txn t) {
    final v = t.isExpense ? t.amount - refundedFor(t) : t.amount - usedAsRefund(t);
    return v < 0.005 ? 0 : v;
  }

  double remainingToRefund(Txn expense) {
    final v = expense.amount - refundedFor(expense);
    return v < 0.005 ? 0 : v;
  }

  double availableToLink(Txn income) {
    final v = income.amount - usedAsRefund(income);
    return v < 0.005 ? 0 : v;
  }

  Txn? _txnById(int id) {
    for (final t in txns) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Refunds linked to [expense], each with the income it came from.
  List<(Txn, RefundLink)> refundsOf(Txn expense) {
    final out = <(Txn, RefundLink)>[];
    for (final r in refundLinks) {
      if (r.expenseId != expense.id) continue;
      final income = _txnById(r.incomeId);
      if (income != null) out.add((income, r));
    }
    return out;
  }

  /// Expenses that [income] is a refund for.
  List<(Txn, RefundLink)> refundedExpensesOf(Txn income) {
    final out = <(Txn, RefundLink)>[];
    for (final r in refundLinks) {
      if (r.incomeId != income.id) continue;
      final expense = _txnById(r.expenseId);
      if (expense != null) out.add((expense, r));
    }
    return out;
  }

  /// Money received from the expense date up to 90 days later that could be
  /// its refund: counted, not already used up, not already linked to it.
  /// Same payee first, then closest in time.
  List<Txn> refundCandidates(Txn expense) {
    final from = DateTime(expense.date.year, expense.date.month, expense.date.day);
    final to = expense.date.add(const Duration(days: 90));
    final payee = expense.merchant.toLowerCase().trim();
    final linked = {for (final r in refundLinks) if (r.expenseId == expense.id) r.incomeId};
    final list = txns
        .where((t) =>
            !t.isExpense &&
            !t.excluded &&
            t.id != null &&
            !linked.contains(t.id) &&
            !t.date.isBefore(from) &&
            !t.date.isAfter(to) &&
            availableToLink(t) > 0)
        .toList();
    int rank(Txn t) => payee.isNotEmpty && t.merchant.toLowerCase().trim() == payee ? 0 : 1;
    list.sort((a, b) {
      final r = rank(a) - rank(b);
      if (r != 0) return r;
      return a.date.difference(expense.date).abs().compareTo(b.date.difference(expense.date).abs());
    });
    return list;
  }

  Future<void> linkRefund(Txn expense, Txn income, double amount) async {
    if (expense.id == null || income.id == null || amount <= 0) return;
    final link = RefundLink(expenseId: expense.id!, incomeId: income.id!, amount: amount);
    final id = await _db.addRefund(link);
    refundLinks.add(RefundLink(id: id, expenseId: link.expenseId, incomeId: link.incomeId, amount: amount));
    _indexRefunds();
    notifyListeners();
  }

  /// Records a refund that has no matching income: adds it as a refund
  /// income transaction and links it to [expense].
  Future<void> addManualRefund(Txn expense, {required double amount, required DateTime date, String note = ''}) async {
    final income = Txn(
      amount: amount,
      type: TxnType.credit,
      category: 'refund',
      merchant: expense.merchant,
      note: note.trim().isEmpty ? 'Refund for ${expense.title}' : note.trim(),
      date: date,
    );
    final id = await _db.insertTxn(income);
    final saved = income.copyWith(id: id);
    txns.add(saved);
    txns.sort((a, b) => b.date.compareTo(a.date));
    await linkRefund(expense, saved, amount);
  }

  Future<void> unlinkRefund(RefundLink r) async {
    if (r.id != null) await _db.deleteRefund(r.id!);
    refundLinks.removeWhere((x) => x.id == r.id);
    _indexRefunds();
    notifyListeners();
  }

  // ---------- Queries ----------
  List<Txn> txnsIn(DateTime m) =>
      txns.where((t) => t.date.year == m.year && t.date.month == m.month).toList();

  double spentIn(DateTime m) =>
      txnsIn(m).where((t) => t.countsAsSpend).fold(0.0, (sum, t) => sum + counted(t));

  double receivedIn(DateTime m) =>
      txnsIn(m).where((t) => t.countsAsIncome).fold(0.0, (sum, t) => sum + counted(t));

  double spentInCategory(DateTime m, String category) => txnsIn(m)
      .where((t) => t.countsAsSpend && t.category == category)
      .fold(0.0, (sum, t) => sum + counted(t));

  /// Expense categories for the month, largest first.
  List<MapEntry<String, double>> spendByCategory(DateTime m) {
    final totals = <String, double>{};
    for (final t in txnsIn(m)) {
      if (!t.countsAsSpend || counted(t) <= 0) continue;
      totals[t.category] = (totals[t.category] ?? 0) + counted(t);
    }
    final list = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Spending for the [count] months ending at the selected month.
  List<MapEntry<DateTime, double>> spendTrend(int count) {
    return [
      for (var i = count - 1; i >= 0; i--)
        MapEntry(DateTime(month.year, month.month - i), spentIn(DateTime(month.year, month.month - i))),
    ];
  }

  /// Money received for the [count] months ending at the selected month.
  List<double> receivedTrend(int count) => [
        for (var i = count - 1; i >= 0; i--) receivedIn(DateTime(month.year, month.month - i)),
      ];

  /// Largest single expense in the month, if any.
  Txn? biggestExpense(DateTime m) {
    Txn? best;
    for (final t in txnsIn(m)) {
      if (t.countsAsSpend && counted(t) > 0 && (best == null || counted(t) > counted(best))) best = t;
    }
    return best;
  }

  /// Money put into savings and investments in the month.
  double savedIn(DateTime m) => txnsIn(m).where((t) => t.countsAsSaving).fold(0.0, (sum, t) => sum + counted(t));

  /// Money taken back out of savings in the month (redemptions, matured deposits).
  double withdrawnIn(DateTime m) =>
      txnsIn(m).where((t) => t.countsAsWithdrawal).fold(0.0, (sum, t) => sum + counted(t));

  /// Saved minus withdrawn.
  double netSavedIn(DateTime m) => savedIn(m) - withdrawnIn(m);

  /// Share of the month's income that went into savings, or null with no income.
  double? savingsRate(DateTime m) {
    final income = receivedIn(m);
    if (income <= 0) return null;
    return netSavedIn(m) / income;
  }

  /// Money saved for the [count] months ending at the selected month.
  List<double> savedTrend(int count) => [
        for (var i = count - 1; i >= 0; i--) savedIn(DateTime(month.year, month.month - i)),
      ];

  /// Spending divided by days so far (current month) or days in the month.
  double dailyAverage(DateTime m) {
    final now = DateTime.now();
    final days = (m.year == now.year && m.month == now.month) ? now.day : DateTime(m.year, m.month + 1, 0).day;
    return spentIn(m) / days;
  }

  List<MapEntry<String, double>> topMerchants(DateTime m, {int limit = 5}) {
    final totals = <String, double>{};
    for (final t in txnsIn(m)) {
      if (!t.countsAsSpend || t.merchant.isEmpty) continue;
      totals[t.merchant] = (totals[t.merchant] ?? 0) + counted(t);
    }
    final list = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  double? get totalBudget => budgets[totalBudgetKey];

  /// Bills not yet paid this calendar month, soonest first.
  List<Bill> get unpaidBillsThisMonth {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final list = bills.where((b) => !b.isPaidFor(thisMonth)).toList()
      ..sort((a, b) => a.dueDateIn(thisMonth).compareTo(b.dueDateIn(thisMonth)));
    return list;
  }

  // ---------- Transactions ----------
  Future<void> addTxn(Txn t) async {
    final id = await _db.insertTxn(t);
    txns.insert(0, t.copyWith(id: id));
    txns.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> updateTxn(Txn t) async {
    await _db.updateTxn(t);
    final i = txns.indexWhere((x) => x.id == t.id);
    if (i >= 0) txns[i] = t;
    txns.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  /// Changes the category of one transaction only.
  Future<void> setCategory(Txn t, String category) async {
    final i = txns.indexWhere((x) => x.id == t.id);
    final current = i >= 0 ? txns[i] : t;
    await updateTxn(current.copyWith(category: category));
  }

  /// Other transactions from the same merchant and in the same direction.
  List<Txn> similarTxns(Txn t) {
    final key = t.merchant.toLowerCase().trim();
    if (key.isEmpty) return const [];
    return txns
        .where((o) => o.id != t.id && o.type == t.type && o.merchant.toLowerCase().trim() == key)
        .toList();
  }

  /// Other transactions with the same payee name, money in or out.
  List<Txn> similarTxnsAnyDirection(Txn t) {
    final key = t.merchant.toLowerCase().trim();
    if (key.isEmpty) return const [];
    return txns.where((o) => o.id != t.id && o.merchant.toLowerCase().trim() == key).toList();
  }

  /// Moves several transactions to [category] in one go.
  Future<void> applyCategory(List<Txn> list, String category) async {
    final ids = {for (final t in list) t.id};
    for (var i = 0; i < txns.length; i++) {
      final t = txns[i];
      if (!ids.contains(t.id) || t.category == category) continue;
      final updated = t.copyWith(category: category);
      await _db.updateTxn(updated);
      txns[i] = updated;
    }
    notifyListeners();
  }

  /// For each payee, the category used most often in past transactions
  /// (money out or money in separately). Ties go to the most recent one.
  /// Catch-all and not-counted transactions don't vote.
  Map<String, String> learnedCategories(TxnType type) {
    final counts = <String, Map<String, int>>{};
    final latest = <String, Map<String, DateTime>>{};
    for (final t in txns) {
      if (t.type != type || t.excluded || t.merchant.isEmpty) continue;
      if (t.category == 'other' || t.category == 'income') continue;
      final k = t.merchant.toLowerCase().trim();
      final c = counts.putIfAbsent(k, () => {});
      c[t.category] = (c[t.category] ?? 0) + 1;
      final l = latest.putIfAbsent(k, () => {});
      final seen = l[t.category];
      if (seen == null || t.date.isAfter(seen)) l[t.category] = t.date;
    }
    final result = <String, String>{};
    counts.forEach((payee, byCategory) {
      String? best;
      for (final e in byCategory.entries) {
        if (best == null) {
          best = e.key;
          continue;
        }
        final diff = e.value - byCategory[best]!;
        if (diff > 0 || (diff == 0 && latest[payee]![e.key]!.isAfter(latest[payee]![best]!))) best = e.key;
      }
      if (best != null) result[payee] = best;
    });
    return result;
  }

  /// The best category for a new transaction from [merchant].
  String suggestCategory({required String merchant, required TxnType type, String text = '', Map<String, String>? history}) =>
      Categorizer.categorize(
        merchant: merchant,
        text: text,
        type: type,
        rules: rules,
        history: history ?? learnedCategories(type),
      );

  /// New transactions for [merchant] will be suggested [category].
  Future<void> rememberCategory(String merchant, String category) async {
    final key = merchant.toLowerCase().trim();
    if (key.isEmpty) return;
    rules[key] = category;
    await _db.setRule(key, category);
  }

  /// Marks a transaction as "not an expense" (or not income) so totals skip it.
  Future<void> setExcluded(Txn t, bool excluded) => updateTxn(t.copyWith(excluded: excluded));

  // ---------- Categories ----------
  /// Creates a category and returns its key.
  Future<String> addCategory(String label,
      {required bool income, required int iconIndex, required int colorIndex, bool saving = false}) async {
    final key = 'c_${DateTime.now().millisecondsSinceEpoch}';
    await _db.addCategory(key, label, iconIndex, colorIndex, income, saving: saving);
    await _loadCategories();
    notifyListeners();
    return key;
  }

  Future<void> _loadCategories() async {
    final rows = await _db.customCategories();
    customCategories
      ..clear()
      ..addAll(rows.where((c) => c.custom));
    categoryOverrides
      ..clear()
      ..addEntries(rows.where((c) => !c.custom).map((c) => MapEntry(c.key, c)));
  }

  /// Renames or restyles any category, built-in or custom.
  Future<void> updateCategory(Category c,
      {required String label, required int iconIndex, required int colorIndex, bool? saving}) async {
    await _db.saveCategory(c.key, label, iconIndex, colorIndex, c.income, saving: saving ?? c.saving);
    await _loadCategories();
    notifyListeners();
  }

  /// Puts a built-in category back to its original name, icon and colour.
  Future<void> resetCategory(Category c) async {
    await _db.resetCategory(c.key);
    await _loadCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(Category c) async {
    final fallback = c.income ? 'income' : 'other';
    await _db.deleteCategory(c.key, fallback);
    customCategories.removeWhere((x) => x.key == c.key);
    rules.removeWhere((_, v) => v == c.key);
    budgets.remove(c.key);
    txns = await _db.allTxns();
    bills = await _db.bills();
    notifyListeners();
  }

  Future<void> deleteTxn(Txn t) async {
    if (t.id == null) return;
    await _db.deleteTxn(t.id!);
    await _db.deleteRefundsFor(t.id!);
    refundLinks.removeWhere((r) => r.expenseId == t.id || r.incomeId == t.id);
    txns.removeWhere((x) => x.id == t.id);
    _indexRefunds();
    notifyListeners();
  }

  // ---------- Budgets ----------
  Future<void> setBudget(String category, double amount) async {
    await _db.setBudget(category, amount);
    if (amount <= 0) {
      budgets.remove(category);
    } else {
      budgets[category] = amount;
    }
    notifyListeners();
  }

  // ---------- Bills ----------
  Future<void> saveBill(Bill b) async {
    await _db.saveBill(b);
    bills = await _db.bills();
    notifyListeners();
  }

  Future<void> deleteBill(Bill b) async {
    if (b.id == null) return;
    await _db.deleteBill(b.id!);
    bills.removeWhere((x) => x.id == b.id);
    notifyListeners();
  }

  Future<void> markBillPaid(Bill b, {bool addExpense = true}) async {
    final now = DateTime.now();
    await saveBill(b.copyWith(lastPaid: now));
    if (addExpense) {
      await addTxn(Txn(
        amount: b.amount,
        type: TxnType.debit,
        category: b.category,
        merchant: b.name,
        note: 'Bill payment',
        date: now,
      ));
    }
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    txns = [];
    budgets = {};
    bills = [];
    rules = {};
    customCategories.clear();
    categoryOverrides.clear();
    refundLinks = [];
    _indexRefunds();
    notifyListeners();
  }
}

/// Makes [AppState] available to every screen.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
