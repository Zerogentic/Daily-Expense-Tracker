import 'package:expensetracker/format.dart';
import 'package:expensetracker/models.dart';
import 'package:expensetracker/services/categorizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Indian rupee formatting', () {
    expect(money(123456), '₹1,23,456');
    expect(money(1234.5), '₹1,234.50');
    expect(moneyShort(12500), '₹12.5k');
    expect(moneyShort(250000), '₹2.5L');
  });

  test('Suggests categories from the payee name', () {
    String cat(String m) => Categorizer.categorize(merchant: m, text: '', type: TxnType.debit);
    expect(cat('Swiggy'), 'food');
    expect(cat('Uber'), 'transport');
    expect(cat('BigBasket'), 'groceries');
    expect(cat('Netflix'), 'entertainment');
    expect(cat('Random shop'), 'other');
  });

  test('A category the user picked wins over keywords', () {
    expect(
      Categorizer.categorize(merchant: 'Swiggy', text: '', type: TxnType.debit, rules: {'swiggy': 'groceries'}),
      'groceries',
    );
  });

  test('Bills fall on the last day in short months', () {
    const bill = Bill(name: 'Rent', amount: 15000, dueDay: 31);
    expect(bill.dueDateIn(DateTime(2026, 2)).day, 28);
    expect(bill.dueDateIn(DateTime(2026, 3)).day, 31);
  });
  test('Past transactions decide the category, if it fits the direction', () {
    // Swiggy would be food by keyword, but the user files it under groceries.
    expect(
      Categorizer.categorize(merchant: 'Swiggy', text: '', type: TxnType.debit, history: {'swiggy': 'groceries'}),
      'groceries',
    );
    // History beats an older "Update all" rule.
    expect(
      Categorizer.categorize(
          merchant: 'Raju', text: '', type: TxnType.debit, rules: {'raju': 'rent'}, history: {'raju': 'health'}),
      'health',
    );
    // An expense category is never applied to money coming in.
    expect(
      Categorizer.categorize(merchant: 'Raju', text: '', type: TxnType.credit, history: {'raju': 'rent'}),
      'income',
    );
  });

  test('Uncategorised transactions show as Unknown', () {
    expect(categoryFor('other').label, 'Unknown');
    expect(categoryFor('income').label, 'Unknown');
    expect(categoryFor('misc').label, 'Other');
    expect(categoryFor('no-such-category').label, 'Unknown');
  });
  test('Refund links survive a save and load', () {
    const link = RefundLink(id: 7, expenseId: 1, incomeId: 2, amount: 499.5);
    final back = RefundLink.fromMap(link.toMap());
    expect([back.id, back.expenseId, back.incomeId, back.amount], [7, 1, 2, 499.5]);
  });
  test('Investments count as savings, not spending or income', () {
    final sip = Txn(amount: 5000, type: TxnType.debit, category: 'investments', date: DateTime(2026, 11, 5));
    expect(sip.countsAsSpend, isFalse);
    expect(sip.countsAsSaving, isTrue);
    final back = Txn(amount: 20000, type: TxnType.credit, category: 'redemption', date: DateTime(2026, 11, 20));
    expect(back.countsAsIncome, isFalse);
    expect(back.countsAsWithdrawal, isTrue);
    expect(
        Categorizer.categorize(merchant: '', text: 'Rs 5,000 debited from A/c XX1234 towards SIP ICCL NACH', type: TxnType.debit),
        'investments');
    expect(Categorizer.categorize(merchant: '', text: 'Rs 10,000 debited for PPF deposit', type: TxnType.debit), 'deposits');
    expect(Categorizer.categorize(merchant: 'Groww', text: '', type: TxnType.credit), 'redemption');
    expect(Categorizer.categorize(merchant: '', text: 'FD 1234 matured, Rs 1,05,000 credited', type: TxnType.credit),
        'redemption');
    // Ordinary spending and income are unchanged.
    expect(Categorizer.categorize(merchant: 'Swiggy', text: '', type: TxnType.debit), 'food');
    expect(Categorizer.categorize(merchant: '', text: 'NEFT SALARY ACME', type: TxnType.credit), 'salary');
  });
}
