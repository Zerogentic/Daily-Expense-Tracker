import 'package:flutter/material.dart';

enum TxnType { debit, credit }

const _monthNames = [
  ['jan', 'january'], ['feb', 'february'], ['mar', 'march'], ['apr', 'april'], ['may salary', 'salary may', 'salary for may'], ['jun', 'june'],
  ['jul', 'july'], ['aug', 'august'], ['sep', 'sept', 'september'], ['oct', 'october'], ['nov', 'november'],
  ['dec', 'december'],
];

/// Salary credited in the last 5 days of a month, or from the 15th onward
/// with the next month named in the message ("Sep salary"), pays for the
/// next month, so it counts there. Salary on the 1st-3rd already does.
bool salaryCountsNextMonth(Txn t) {
  if (t.isExpense || t.category != 'salary') return false;
  final day = t.date.day;
  final daysInMonth = DateTime(t.date.year, t.date.month + 1, 0).day;
  if (day > daysInMonth - 5) return true;
  if (day < 15) return false;
  final next = DateTime(t.date.year, t.date.month + 1);
  final text = '${t.merchant} ${t.note} ${t.raw ?? ''}'.toLowerCase();
  return _monthNames.elementAt(next.month - 1).any((n) => RegExp('(?<![a-z])$n(?![a-z])').hasMatch(text));
}

class Txn {
  const Txn({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.merchant = '',
    this.note = '',
    this.account = '',
    required this.date,
    this.source = 'manual',
    this.sourceRef,
    this.raw,
    this.excluded = false,
    this.countMonth,
  });

  final int? id;
  final double amount;
  final TxnType type;
  final String category;
  final String merchant;
  final String note;
  final String account;
  final DateTime date;

  /// 'manual' or 'sms'.
  final String source;
  final String? sourceRef;
  final String? raw;

  /// Marked by the user as "not an expense" (or not income): kept, but left out of totals.
  final bool excluded;

  /// Month the user chose for this transaction to count in, as yyyymm
  /// (e.g. 202609); null means the automatic rule decides.
  final int? countMonth;

  /// The month this transaction counts in. Usually the month it happened,
  /// but salary paid in the last days of a month counts toward the next one.
  DateTime get budgetMonth {
    final chosen = countMonth;
    if (chosen != null) return DateTime(chosen ~/ 100, chosen % 100);
    if (salaryCountsNextMonth(this)) return DateTime(date.year, date.month + 1);
    return DateTime(date.year, date.month);
  }

  bool get isExpense => type == TxnType.debit;
  /// In a savings category (investments, deposits, or money back from them).
  bool get isSaving => categoryFor(category).saving;

  /// Spending: money out that isn't savings.
  bool get countsAsSpend => isExpense && !excluded && !isSaving;

  /// Money put into savings and investments.
  bool get countsAsSaving => isExpense && !excluded && isSaving;

  /// Money taken back out of savings (redemptions, matured deposits); not income.
  bool get countsAsWithdrawal => !isExpense && !excluded && isSaving;
  bool get countsAsIncome => !isExpense && !excluded && !isSaving;
  bool get fromSms => source == 'sms';

  String get title {
    if (merchant.isNotEmpty) return merchant;
    return categoryFor(category).label;
  }

  Txn copyWith({
    int? id,
    double? amount,
    TxnType? type,
    String? category,
    String? merchant,
    String? note,
    String? account,
    DateTime? date,
    bool? excluded,
    int? countMonth,
    bool clearCountMonth = false,
  }) {
    return Txn(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      account: account ?? this.account,
      date: date ?? this.date,
      source: source,
      sourceRef: sourceRef,
      raw: raw,
      excluded: excluded ?? this.excluded,
      countMonth: clearCountMonth ? null : (countMonth ?? this.countMonth),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'type': type == TxnType.credit ? 'credit' : 'debit',
        'category': category,
        'merchant': merchant,
        'note': note,
        'account': account,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'source_ref': sourceRef,
        'raw': raw,
        'excluded': excluded ? 1 : 0,
        'count_month': countMonth,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] == 'credit' ? TxnType.credit : TxnType.debit,
        category: m['category'] as String,
        merchant: (m['merchant'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        account: (m['account'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        source: (m['source'] as String?) ?? 'manual',
        sourceRef: m['source_ref'] as String?,
        raw: m['raw'] as String?,
        excluded: ((m['excluded'] as int?) ?? 0) == 1,
        countMonth: m['count_month'] as int?,
      );
}

/// Part (or all) of an income transaction counted as a refund of an expense.
class RefundLink {
  const RefundLink({this.id, required this.expenseId, required this.incomeId, required this.amount});

  final int? id;
  final int expenseId;
  final int incomeId;
  final double amount;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'expense_id': expenseId,
        'income_id': incomeId,
        'amount': amount,
      };

  factory RefundLink.fromMap(Map<String, Object?> m) => RefundLink(
        id: m['id'] as int?,
        expenseId: m['expense_id'] as int,
        incomeId: m['income_id'] as int,
        amount: (m['amount'] as num).toDouble(),
      );
}

/// Someone you split money with.
class Person {
  const Person({this.id, required this.name});

  final int? id;
  final String name;

  factory Person.fromMap(Map<String, Object?> m) => Person(id: m['id'] as int?, name: m['name'] as String);
}

enum LedgerKind {
  /// You paid; they owe you their share.
  split,

  /// They paid; you owe them your share.
  paidForMe,

  /// Money that paid back what was owed.
  settle,
}

/// One change to what you and a person owe each other.
class LedgerEntry {
  const LedgerEntry({
    this.id,
    required this.personId,
    required this.amount,
    this.txnId,
    required this.kind,
    required this.date,
    this.note = '',
  });

  final int? id;
  final int personId;

  /// Positive: they owe you more. Negative: you owe them more, or they paid you back.
  final double amount;

  /// The expense that was split, the expense they paid, or the payment that settled it.
  final int? txnId;
  final LedgerKind kind;
  final DateTime date;
  final String note;

  LedgerEntry withId(int newId) =>
      LedgerEntry(id: newId, personId: personId, amount: amount, txnId: txnId, kind: kind, date: date, note: note);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'person_id': personId,
        'amount': amount,
        'txn_id': txnId,
        'kind': kind.name,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        id: m['id'] as int?,
        personId: m['person_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        txnId: m['txn_id'] as int?,
        kind: LedgerKind.values.byName(m['kind'] as String),
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: (m['note'] as String?) ?? '',
      );
}

/// [total] split into [count] equal shares, to the paisa; the last share takes the rounding.
List<double> equalShares(double total, int count) {
  if (count <= 0) return const [];
  final each = (total / count * 100).floor() / 100;
  return [
    for (var i = 0; i < count; i++)
      i == count - 1 ? double.parse((total - each * (count - 1)).toStringAsFixed(2)) : each,
  ];
}

class Bill {
  const Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.category = 'bills',
    this.lastPaid,
  });

  final int? id;
  final String name;
  final double amount;

  /// Day of the month the bill is due (1-31).
  final int dueDay;
  final String category;
  final DateTime? lastPaid;

  bool isPaidFor(DateTime month) =>
      lastPaid != null && lastPaid!.year == month.year && lastPaid!.month == month.month;

  /// Due date inside [month], clamped to the month's last day.
  DateTime dueDateIn(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, dueDay.clamp(1, lastDay));
  }

  Bill copyWith({String? name, double? amount, int? dueDay, String? category, DateTime? lastPaid}) => Bill(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dueDay: dueDay ?? this.dueDay,
        category: category ?? this.category,
        lastPaid: lastPaid ?? this.lastPaid,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'due_day': dueDay,
        'category': category,
        'last_paid': lastPaid?.millisecondsSinceEpoch,
      };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as int?,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        dueDay: m['due_day'] as int,
        category: (m['category'] as String?) ?? 'bills',
        lastPaid: m['last_paid'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['last_paid'] as int),
      );
}

class Category {
  const Category(this.key, this.label, this.icon, this.color,
      {this.income = false, this.custom = false, this.saving = false});

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool income;
  final bool custom;

  /// Savings, not spending or income: investments, deposits, and money back from them.
  final bool saving;

  /// Expenses, Investments (money in or out) or Income.
  CategoryGroup get group => saving ? CategoryGroup.investment : (income ? CategoryGroup.income : CategoryGroup.expense);
}

/// Icons offered for new categories. Stored by index so release builds can
/// keep shrinking the icon font.
const List<IconData> categoryIconChoices = [
  Icons.category_rounded,
  Icons.pets_rounded,
  Icons.child_care_rounded,
  Icons.fitness_center_rounded,
  Icons.spa_rounded,
  Icons.checkroom_rounded,
  Icons.card_giftcard_rounded,
  Icons.volunteer_activism_rounded,
  Icons.local_cafe_rounded,
  Icons.local_bar_rounded,
  Icons.sports_esports_rounded,
  Icons.build_rounded,
  Icons.cleaning_services_rounded,
  Icons.devices_rounded,
  Icons.two_wheeler_rounded,
  Icons.local_hospital_rounded,
  Icons.family_restroom_rounded,
  Icons.business_center_rounded,
  Icons.savings_rounded,
  Icons.trending_up_rounded,
  Icons.church_rounded,
  Icons.celebration_rounded,
  Icons.park_rounded,
  Icons.wifi_rounded,
  // Icons of the built-in categories, so they can be kept or swapped when editing.
  Icons.restaurant_rounded,
  Icons.shopping_basket_rounded,
  Icons.directions_car_rounded,
  Icons.local_gas_station_rounded,
  Icons.shopping_bag_rounded,
  Icons.receipt_long_rounded,
  Icons.home_rounded,
  Icons.movie_rounded,
  Icons.favorite_rounded,
  Icons.flight_rounded,
  Icons.school_rounded,
  Icons.account_balance_rounded,
  Icons.payments_rounded,
  Icons.swap_horiz_rounded,
  Icons.credit_card_rounded,
  Icons.work_rounded,
  Icons.replay_rounded,
  Icons.help_outline_rounded,
  Icons.trending_up_rounded,
  Icons.account_balance_wallet_rounded,
  Icons.lock_clock_rounded,
  Icons.percent_rounded,
];

const List<Color> categoryColorChoices = [
  Color(0xFF2F7BFF),
  Color(0xFF22D3EE),
  Color(0xFF34D399),
  Color(0xFFA3E635),
  Color(0xFFFACC15),
  Color(0xFFFB923C),
  Color(0xFFF87171),
  Color(0xFFF472B6),
  Color(0xFFC084FC),
  Color(0xFF94A3B8),
  // Colours of the built-in categories.
  Color(0xFFFF8A4C),
  Color(0xFF4ADE80),
  Color(0xFF60A5FA),
  Color(0xFFF59E0B),
  Color(0xFFE879F9),
  Color(0xFF38BDF8),
  Color(0xFFA78BFA),
  Color(0xFF2DD4BF),
  Color(0xFF86EFAC),
  Color(0xFF7DD3FC),
  Color(0xFF9CA3AF),
  Color(0xFF818CF8),
  Color(0xFFA8A29E),
  Color(0xFFA3E635),
];

const List<Category> builtInCategories = [
  Category('food', 'Food & dining', Icons.restaurant_rounded, Color(0xFFFF8A4C)),
  Category('groceries', 'Groceries', Icons.shopping_basket_rounded, Color(0xFF4ADE80)),
  Category('transport', 'Transport', Icons.directions_car_rounded, Color(0xFF60A5FA)),
  Category('fuel', 'Fuel', Icons.local_gas_station_rounded, Color(0xFFF59E0B)),
  Category('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFFE879F9)),
  Category('bills', 'Bills & recharges', Icons.receipt_long_rounded, Color(0xFF38BDF8)),
  Category('rent', 'Rent', Icons.home_rounded, Color(0xFFA78BFA)),
  Category('entertainment', 'Entertainment', Icons.movie_rounded, Color(0xFFF472B6)),
  Category('health', 'Health', Icons.favorite_rounded, Color(0xFFF87171)),
  Category('travel', 'Travel', Icons.flight_rounded, Color(0xFF2DD4BF)),
  Category('education', 'Education', Icons.school_rounded, Color(0xFFFACC15)),
  Category('emi', 'EMI & loans', Icons.account_balance_rounded, Color(0xFF94A3B8)),
  Category('cash', 'Cash withdrawal', Icons.payments_rounded, Color(0xFF86EFAC)),
  Category('transfers', 'Transfers', Icons.swap_horiz_rounded, Color(0xFF7DD3FC)),
  Category('card_payment', 'Card bill payment', Icons.credit_card_rounded, Color(0xFF818CF8)),
  Category('misc', 'Other', Icons.category_rounded, Color(0xFFA8A29E)),
  // Not categorised yet: the app couldn't tell and the user hasn't picked one.
  Category('investments', 'Mutual funds & stocks', Icons.trending_up_rounded, Color(0xFF2F7BFF), saving: true),
  Category('deposits', 'FD, RD & PPF', Icons.lock_clock_rounded, Color(0xFF22D3EE), saving: true),
  Category('other', 'Unknown', Icons.help_outline_rounded, Color(0xFF9CA3AF)),
  Category('salary', 'Salary', Icons.work_rounded, Color(0xFF34D399), income: true),
  Category('refund', 'Refunds & cashback', Icons.replay_rounded, Color(0xFF22D3EE), income: true),
  Category('misc_income', 'Other income', Icons.savings_rounded, Color(0xFF4ADE80), income: true),
  // Real returns you earned: income.
  Category('returns', 'Dividends & interest', Icons.percent_rounded, Color(0xFFA3E635), income: true),
  // Your own money coming back from investments: not income.
  Category('redemption', 'Withdrawals & redemptions', Icons.account_balance_wallet_rounded, Color(0xFF22D3EE),
      income: true, saving: true),
  // Money in that isn't categorised yet.
  Category('income', 'Unknown', Icons.help_outline_rounded, Color(0xFF9CA3AF), income: true),
  Category('transfers_in', 'Transfers in', Icons.swap_horiz_rounded, Color(0xFF7DD3FC), income: true),
];

/// Categories the user created; loaded from the database at startup.
final List<Category> customCategories = [];

/// Built-in categories the user renamed or restyled, by key.
final Map<String, Category> categoryOverrides = {};

bool isBuiltInCategory(String key) => builtInCategories.any((c) => c.key == key);

Category customCategoryFromMap(Map<String, Object?> m) {
  final iconIndex = (m['icon'] as int).clamp(0, categoryIconChoices.length - 1);
  final colorIndex = (m['color'] as int).clamp(0, categoryColorChoices.length - 1);
  return Category(
    m['key'] as String,
    m['label'] as String,
    categoryIconChoices[iconIndex],
    categoryColorChoices[colorIndex],
    income: (m['income'] as int) == 1,
    custom: !isBuiltInCategory(m['key'] as String),
    saving: ((m['saving'] as int?) ?? 0) == 1,
  );
}

List<Category> get categories => [
      for (final c in builtInCategories) categoryOverrides[c.key] ?? c,
      ...customCategories,
    ];
/// The three groups categories are shown in.
enum CategoryGroup { expense, investment, income }

extension CategoryGroupTitle on CategoryGroup {
  String get title => switch (this) {
        CategoryGroup.expense => 'Expenses',
        CategoryGroup.investment => 'Investments',
        CategoryGroup.income => 'Income',
      };
}

/// Categories in one group, e.g. everything under Investments.
List<Category> categoriesIn(CategoryGroup group) => categories.where((c) => c.group == group).toList();

/// Every category for money going out (expenses and money put into investments).
List<Category> get expenseCategories => categories.where((c) => !c.income).toList();
List<Category> get incomeCategories => categories.where((c) => c.income).toList();

Category categoryFor(String key) => categories.firstWhere(
      (c) => c.key == key,
      orElse: () => builtInCategories.firstWhere((c) => c.key == 'other'),
    );
