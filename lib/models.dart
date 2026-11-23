import 'package:flutter/material.dart';

enum TxnType { debit, credit }

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

  bool get isExpense => type == TxnType.debit;
  bool get countsAsSpend => isExpense && !excluded;
  bool get countsAsIncome => !isExpense && !excluded;
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
      );
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
  const Category(this.key, this.label, this.icon, this.color, {this.income = false, this.custom = false});

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool income;
  final bool custom;
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
  Category('other', 'Other', Icons.category_rounded, Color(0xFF9CA3AF)),
  Category('salary', 'Salary', Icons.work_rounded, Color(0xFF34D399), income: true),
  Category('refund', 'Refunds & cashback', Icons.replay_rounded, Color(0xFF22D3EE), income: true),
  Category('income', 'Other income', Icons.savings_rounded, Color(0xFF4ADE80), income: true),
  Category('transfers_in', 'Transfers in', Icons.swap_horiz_rounded, Color(0xFF7DD3FC), income: true),
];

/// Categories the user created; loaded from the database at startup.
final List<Category> customCategories = [];

Category customCategoryFromMap(Map<String, Object?> m) {
  final iconIndex = (m['icon'] as int).clamp(0, categoryIconChoices.length - 1);
  final colorIndex = (m['color'] as int).clamp(0, categoryColorChoices.length - 1);
  return Category(
    m['key'] as String,
    m['label'] as String,
    categoryIconChoices[iconIndex],
    categoryColorChoices[colorIndex],
    income: (m['income'] as int) == 1,
    custom: true,
  );
}

List<Category> get categories => [...builtInCategories, ...customCategories];
List<Category> get expenseCategories => categories.where((c) => !c.income).toList();
List<Category> get incomeCategories => categories.where((c) => c.income).toList();

Category categoryFor(String key) => categories.firstWhere(
      (c) => c.key == key,
      orElse: () => builtInCategories.firstWhere((c) => c.key == 'other'),
    );
