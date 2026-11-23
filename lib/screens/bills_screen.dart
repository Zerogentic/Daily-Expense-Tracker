import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/txn_widgets.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final unpaid = state.unpaidBillsThisMonth;
    final paid = state.bills.where((b) => b.isPaidFor(thisMonth)).toList();
    final dueTotal = unpaid.fold<double>(0, (s, b) => s + b.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Panel(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Still due in ${monthTitle(thisMonth)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(money(dueTotal),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(
                      state.bills.isEmpty
                          ? 'Add rent, EMIs, recharges and subscriptions'
                          : '${unpaid.length} unpaid · ${paid.length} paid',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => editBill(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add bill'),
              ),
            ],
          ),
        ),
        if (unpaid.isNotEmpty) ...[
          const SectionTitle('Upcoming'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [for (final b in unpaid) _BillTile(bill: b, paid: false)]),
          ),
        ],
        if (paid.isNotEmpty) ...[
          const SectionTitle('Paid this month'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [for (final b in paid) _BillTile(bill: b, paid: true)]),
          ),
        ],
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill, required this.paid});

  final Bill bill;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = bill.dueDateIn(DateTime(now.year, now.month));
    final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
    final String status;
    final Color color;
    if (paid) {
      status = 'Paid ${dayMonth(bill.lastPaid!)}';
      color = AppColors.good;
    } else if (days < 0) {
      status = 'Overdue · was due ${dayMonth(due)}';
      color = AppColors.bad;
    } else if (days == 0) {
      status = 'Due today';
      color = AppColors.warn;
    } else {
      status = 'Due ${dayMonth(due)} · in $days day${days == 1 ? '' : 's'}';
      color = days <= 3 ? AppColors.warn : AppColors.muted;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _actions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CategoryIcon(categoryFor(bill.category), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(status, style: TextStyle(fontSize: 12.5, color: color)),
                ],
              ),
            ),
            Text(money(bill.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final state = AppScope.read(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!paid)
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: AppColors.good),
                title: const Text('Mark as paid'),
                subtitle: const Text('Also adds it to this month\'s expenses'),
                onTap: () => Navigator.pop(ctx, 'paid'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit bill'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.bad),
              title: const Text('Delete bill'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'paid':
        await state.markBillPaid(bill);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${bill.name} marked as paid.')));
        }
      case 'edit':
        await editBill(context, existing: bill);
      case 'delete':
        if (await confirm(context, 'Delete ${bill.name}?', 'Past payments stay in your transactions.')) {
          await state.deleteBill(bill);
        }
    }
  }
}

Future<void> editBill(BuildContext context, {Bill? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final amount = TextEditingController(text: existing == null ? '' : existing.amount.toStringAsFixed(0));
  var dueDay = existing?.dueDay ?? DateTime.now().day;
  var category = existing?.category ?? 'bills';

  final saved = await showModalBottomSheet<Bill>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add a bill' : 'Edit bill',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: fieldDecoration('Name', hint: 'e.g. Rent, KSEB, Netflix, Car EMI'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration('Amount').copyWith(prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: dueDay,
                    dropdownColor: AppColors.surface2,
                    decoration: fieldDecoration('Due every month on'),
                    items: [
                      for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Day $d')),
                    ],
                    onChanged: (v) => setSheet(() => dueDay = v ?? dueDay),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final key = await pickCategory(ctx, income: false, selected: category);
                      if (key != null) setSheet(() => category = key);
                    },
                    child: InputDecorator(
                      decoration: fieldDecoration('Category'),
                      child: Text(categoryFor(category).label,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                final a = double.tryParse(amount.text) ?? 0;
                if (name.text.trim().isEmpty || a <= 0) return;
                Navigator.pop(
                  ctx,
                  Bill(
                    id: existing?.id,
                    name: name.text.trim(),
                    amount: a,
                    dueDay: dueDay,
                    category: category,
                    lastPaid: existing?.lastPaid,
                  ),
                );
              },
              child: const Text('Save bill'),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved != null && context.mounted) {
    await AppScope.read(context).saveBill(saved);
  }
}
