import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../screens/add_txn_screen.dart';
import '../state.dart';
import '../theme.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 42});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(category.icon, color: category.color, size: size * 0.5),
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(txn.category);
    final state = AppScope.of(context);
    final refunded = txn.isExpense ? state.refundedFor(txn) : 0.0;
    final subtitle = [
      if (refunded > 0)
        refunded >= txn.amount - 0.005 ? 'Fully refunded' : 'Refunded ${money(refunded)}',
      if (!txn.isExpense && state.usedAsRefund(txn) > 0 && txn.category != 'refund') 'Refund',
      if (txn.excluded) 'Not counted',
      cat.label,
      if (txn.account.isNotEmpty) txn.account,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showTxnDetails(context, txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CategoryIcon(cat),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 1.5),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (txn.isExpense ? AppColors.spend : AppColors.receive).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        txn.isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
                        size: 11,
                        color: txn.isExpense ? AppColors.spend : AppColors.receive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Builder(builder: (context) {
              final net = state.netAmount(txn);
              final reduced = net < txn.amount - 0.005;
              final gone = txn.excluded || net <= 0;
              final sign = txn.isExpense ? '−' : '+';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sign${money(gone ? txn.amount : net)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: gone
                          ? AppColors.muted
                          : (txn.isSaving ? AppColors.accent : (txn.isExpense ? AppColors.spend : AppColors.receive)),
                      decoration: gone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (reduced && !gone)
                    Text(
                      money(txn.amount),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted, decoration: TextDecoration.lineThrough),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Grid of categories in a bottom sheet; returns the chosen key.
Future<String?> pickCategory(BuildContext context, {required bool income, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    builder: (ctx) {
      Future<void> addNew() async {
        final key = await createCategory(ctx, income: income);
        if (key != null && ctx.mounted) Navigator.pop(ctx, key);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Choose a category',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.16),
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: addNew,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('New category', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Center(
                  child: CategoryGrid(
                    categories: income ? incomeCategories : expenseCategories,
                    selected: selected,
                    onSelected: (key) => Navigator.pop(ctx, key),
                    onAdd: addNew,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.categories, required this.onSelected, this.selected, this.onAdd});

  final List<Category> categories;
  final ValueChanged<String> onSelected;
  final String? selected;

  /// Shows a "New" tile that creates a category.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 14,
      children: [
        for (final c in categories)
          SizedBox(
            width: 76,
            child: GestureDetector(
              onTap: () => onSelected(c.key),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected == c.key ? c.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CategoryIcon(c, size: 48),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: selected == c.key ? AppColors.text : AppColors.muted,
                      fontWeight: selected == c.key ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (onAdd != null)
          SizedBox(
            width: 76,
            child: GestureDetector(
              onTap: onAdd,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(height: 6),
                  const Text('New',
                      style: TextStyle(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sheet for creating a category, or editing [existing]; returns its key, or null if cancelled.
Future<String?> createCategory(BuildContext context, {required bool income, Category? existing}) async {
  final name = TextEditingController(text: existing?.label ?? '');
  var iconIndex = existing == null ? 0 : categoryIconChoices.indexOf(existing.icon);
  var colorIndex = existing == null ? 0 : categoryColorChoices.indexOf(existing.color);
  if (iconIndex < 0) iconIndex = 0;
  if (colorIndex < 0) colorIndex = 0;
  var reset = false;
  var saving = existing?.saving ?? false;
  final canReset = existing != null && !existing.custom && categoryOverrides.containsKey(existing.key);
  final state = AppScope.read(context);

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final color = categoryColorChoices[colorIndex];
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing != null ? 'Edit category' : (income ? 'New income category' : 'New expense category'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(categoryIconChoices[iconIndex], color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: fieldDecoration('Name', hint: income ? 'e.g. Freelance' : 'e.g. Pets, Gym, Gifts'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Icon', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < categoryIconChoices.length; i++)
                      GestureDetector(
                        onTap: () => setSheet(() => iconIndex = i),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: i == iconIndex ? color.withValues(alpha: 0.2) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: i == iconIndex ? color : Colors.transparent, width: 1.5),
                          ),
                          child: Icon(categoryIconChoices[i],
                              size: 22, color: i == iconIndex ? color : AppColors.muted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Colour', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < categoryColorChoices.length; i++)
                      GestureDetector(
                        onTap: () => setSheet(() => colorIndex = i),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: categoryColorChoices[i],
                            shape: BoxShape.circle,
                            border: Border.all(color: i == colorIndex ? AppColors.text : Colors.transparent, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Material(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    value: saving,
                    activeThumbColor: AppColors.accent,
                    title: Text(income ? 'Money back from savings' : 'Counts as savings'),
                    subtitle: Text(
                      income
                          ? 'Redemptions, matured deposits. Not counted as income.'
                          : 'Investments, deposits. Not counted as spending or in budgets.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    onChanged: (v) => setSheet(() => saving = v),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: Text(existing != null ? 'Save changes' : 'Create category'),
                ),
                if (canReset) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      reset = true;
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('Reset to original name and icon'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
  if (reset && existing != null) {
    await state.resetCategory(existing);
    return existing.key;
  }
  if (created != true) return null;
  if (existing != null) {
    await state.updateCategory(existing,
        label: name.text.trim(), iconIndex: iconIndex, colorIndex: colorIndex, saving: saving);
    return existing.key;
  }
  return state.addCategory(name.text.trim(),
      income: income, iconIndex: iconIndex, colorIndex: colorIndex, saving: saving);
}

Future<void> showTxnDetails(BuildContext context, Txn txn) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (ctx) => _TxnDetails(txnId: txn.id),
  );
}

class _TxnDetails extends StatelessWidget {
  const _TxnDetails({required this.txnId});

  final int? txnId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final found = state.txns.where((t) => t.id == txnId);
    if (found.isEmpty) return const SizedBox(height: 120);
    final txn = found.first;
    final cat = categoryFor(txn.category);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(cat, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(txn.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text('${dayHeader(txn.date)}, ${timeOfDay(txn.date)}',
                          style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Builder(builder: (context) {
              final net = state.netAmount(txn);
              final gone = net <= 0;
              return Text(
                '${txn.isExpense ? '−' : '+'}${money(gone ? txn.amount : net)}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: gone
                      ? AppColors.muted
                      : (txn.isSaving ? AppColors.accent : (txn.isExpense ? AppColors.spend : AppColors.receive)),
                  decoration: gone ? TextDecoration.lineThrough : null,
                ),
              );
            }),
            if (state.netAmount(txn) < txn.amount - 0.005)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  txn.isExpense
                      ? 'Paid ${money(txn.amount)} · ${money(state.refundedFor(txn))} refunded'
                      : 'Received ${money(txn.amount)} · ${money(state.usedAsRefund(txn))} counted as refund',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            _row(txn.isExpense ? 'Paid to' : 'From', txn.merchant.isEmpty ? 'Not added' : txn.merchant,
                action: txn.merchant.isEmpty ? 'Add name' : 'Rename',
                onAction: () => renamePayee(context, txn)),
            _row('Category', cat.label, action: 'Change', onAction: () async {
              final key = await pickCategory(context, income: !txn.isExpense, selected: txn.category);
              if (key != null && key != txn.category && context.mounted) {
                await changeCategory(context, txn, key);
              }
            }),
            if (txn.account.isNotEmpty) _row('Account', txn.account),
            const SizedBox(height: 4),
            Material(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                value: !txn.excluded,
                activeThumbColor: AppColors.accent,
                title: Text(txn.isExpense ? 'Count as an expense' : 'Count as income'),
                subtitle: Text(
                  txn.excluded
                      ? 'Left out of totals and budgets'
                      : 'Turn off for transfers between your accounts, investments and similar',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                onChanged: (on) => state.setExcluded(txn, !on),
              ),
            ),
            const SizedBox(height: 4),
            if (txn.note.isNotEmpty) _row('Note', txn.note),
            if (txn.isExpense) _RefundsSection(txn: txn),
            if (!txn.isExpense && state.refundedExpensesOf(txn).isNotEmpty) _RefundOfSection(txn: txn),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bad,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final ok = await confirm(context, 'Delete this transaction?', 'This cannot be undone.');
                      if (ok) {
                        await state.deleteTxn(txn);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => AddTxnScreen(existing: txn)));
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Changes a transaction's category, then offers to move other transactions
/// from the same merchant too, and remembers the choice for next time.
Future<void> changeCategory(BuildContext context, Txn txn, String category) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final label = categoryFor(category).label;
  await state.setCategory(txn, category);
  if (txn.merchant.isEmpty) return;

  final similar = state.similarTxns(txn).where((t) => t.category != category).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (similar.isEmpty) {
    await state.rememberCategory(txn.merchant, category);
    messenger.showSnackBar(SnackBar(content: Text('Got it. ${txn.merchant} will be $label from now on.')));
    return;
  }
  if (!context.mounted) return;

  final total = similar.fold<double>(0, (s, t) => s + t.amount);
  final applyAll = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Update similar transactions?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found ${similar.length} other transaction${similar.length == 1 ? '' : 's'} from ${txn.merchant} '
            '(${money(total)} in total). Move ${similar.length == 1 ? 'it' : 'them'} to $label too?',
            style: const TextStyle(color: AppColors.text, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final t in similar.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CategoryIcon(categoryFor(t.category), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${dayMonth(t.date)} · ${categoryFor(t.category).label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                  Text(money(t.amount),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.isExpense ? AppColors.spend : AppColors.receive)),
                ],
              ),
            ),
          if (similar.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('and ${similar.length - 4} more',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Just this one')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Update all ${similar.length + 1}'),
        ),
      ],
    ),
  );

  if (applyAll == true) {
    await state.applyCategory(similar, category);
    await state.rememberCategory(txn.merchant, category);
    messenger.showSnackBar(SnackBar(
      content: Text('Moved ${similar.length + 1} transactions to $label. New ${txn.merchant} payments will go there too.'),
    ));
  }
}

/// Asks for a payee name, then offers to use it for every transaction with
/// the same payee.
Future<void> renamePayee(BuildContext context, Txn txn) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController(text: txn.merchant);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(txn.isExpense ? 'Who did you pay?' : 'Who paid you?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration('Name', hint: 'e.g. Raju (plumber), Landlord, Milk'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;

  final others = txn.merchant.isEmpty ? <Txn>[] : state.similarTxnsAnyDirection(txn);
  var all = false;
  if (others.isNotEmpty) {
    all = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Rename the others too?'),
            content: Text(
              '${others.length} other transaction${others.length == 1 ? '' : 's'} also show "${txn.merchant}". '
              'Rename ${others.length == 1 ? 'it' : 'them'} to "${name.trim()}" as well?',
              style: const TextStyle(color: AppColors.text, height: 1.4),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Just this one')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Rename all ${others.length + 1}')),
            ],
          ),
        ) ??
        false;
  } else if (txn.merchant.isNotEmpty) {
    all = true;
  }
  await state.renamePayee(txn, name, all: all);
  messenger.showSnackBar(SnackBar(content: Text('Saved as ${name.trim()}.')));
}

// ---------------- Refunds ----------------

class _RefundsSection extends StatelessWidget {
  const _RefundsSection({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final links = state.refundsOf(txn);
    final refunded = state.refundedFor(txn);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.replay_rounded, size: 18, color: AppColors.receive),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Refunds', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                if (refunded > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('You paid ${money(state.remainingToRefund(txn))}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (links.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Text('Got money back for this? Link the refund so it comes off your spending.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
            for (final (income, link) in links)
              Row(
                children: [
                  Expanded(
                    child: Text('${dayMonth(income.date)} · ${income.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.text)),
                  ),
                  Text('+${money(link.amount)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.receive)),
                  IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off_rounded, size: 18, color: AppColors.muted),
                    onPressed: () => state.unlinkRefund(link),
                  ),
                ],
              ),
            if (state.remainingToRefund(txn) > 0)
              TextButton.icon(
                onPressed: () => linkRefundFlow(context, txn),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(links.isEmpty ? 'Link a refund' : 'Link another refund'),
              ),
          ],
        ),
      ),
    );
  }
}

/// On an income: which expenses it refunds, and how much still counts as income.
class _RefundOfSection extends StatelessWidget {
  const _RefundOfSection({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final links = state.refundedExpensesOf(txn);
    final left = state.availableToLink(txn);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.replay_rounded, size: 18, color: AppColors.receive),
                SizedBox(width: 8),
                Text('Refund for', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
              ],
            ),
            for (final (expense, link) in links)
              Row(
                children: [
                  Expanded(
                    child: Text('${dayMonth(expense.date)} · ${expense.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.text)),
                  ),
                  Text(money(link.amount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                  IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off_rounded, size: 18, color: AppColors.muted),
                    onPressed: () => state.unlinkRefund(link),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
              child: Text(
                left > 0 ? '${money(left)} of this still counts as income.' : 'None of this counts as income.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick income from the 90 days after [expense] (or add one by
/// hand) and link it, fully or partly, as a refund.
Future<void> linkRefundFlow(BuildContext context, Txn expense) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final candidates = state.refundCandidates(expense);
  final until = expense.date.add(const Duration(days: 90));

  final picked = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Link a refund',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Money you received from ${dayMonth(expense.date)} to ${dayMonth(until)}. '
              'Pick the one that refunded ${expense.title} (${money(expense.amount)}).',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
          ),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text('No money received in that period is available to link.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final c in candidates)
                    ListTile(
                      leading: CategoryIcon(categoryFor(c.category), size: 36),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          dayHeader(c.date),
                          if (state.usedAsRefund(c) > 0) '${money(state.availableToLink(c))} available',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      trailing: Text('+${money(c.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.receive)),
                      onTap: () => Navigator.pop(ctx, c),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () => Navigator.pop(ctx, 'manual'),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Add a refund manually'),
            ),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final remaining = state.remainingToRefund(expense);
  if (picked is Txn) {
    final available = state.availableToLink(picked);
    final max = available < remaining ? available : remaining;
    final result = await _refundDialog(context,
        max: max,
        intro: '${picked.title} sent you ${money(picked.amount)} on ${dayMonth(picked.date)}. '
            'How much of it was a refund for ${expense.title}?');
    if (result == null) return;
    await state.linkRefund(expense, picked, result.amount);
    messenger.showSnackBar(SnackBar(content: Text('Linked a ${money(result.amount)} refund.')));
  } else {
    final result = await _refundDialog(context,
        max: remaining,
        manual: true,
        firstDate: expense.date,
        intro: 'Record money you got back for ${expense.title}. It is added to Activity as a refund.');
    if (result == null) return;
    await state.addManualRefund(expense, amount: result.amount, date: result.date, note: result.note);
    messenger.showSnackBar(SnackBar(content: Text('Added a ${money(result.amount)} refund.')));
  }
}

/// Amount (and for a manual refund, date and note) of a refund.
Future<({double amount, DateTime date, String note})?> _refundDialog(
  BuildContext context, {
  required double max,
  required String intro,
  bool manual = false,
  DateTime? firstDate,
}) {
  String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final amount = TextEditingController(text: fmt(max));
  final note = TextEditingController();
  final now = DateTime.now();
  var date = now;
  String? error;

  return showDialog<({double amount, DateTime date, String note})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(manual ? 'Add a refund' : 'Refund amount'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(intro, style: const TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: fieldDecoration('Refund amount').copyWith(
                  prefixText: '₹ ',
                  helperText: 'Up to ${money(max)}. Lower it for a partial refund.',
                  errorText: error,
                ),
              ),
              if (manual) ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final first = firstDate ?? DateTime(2015);
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date.isBefore(first) ? first : date,
                      firstDate: DateTime(first.year, first.month, first.day),
                      lastDate: now,
                    );
                    if (picked != null) setDialog(() => date = DateTime(picked.year, picked.month, picked.day, 12));
                  },
                  child: InputDecorator(
                    decoration: fieldDecoration('Date received'),
                    child: Text(dayHeader(date), style: const TextStyle(color: AppColors.text)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: fieldDecoration('Note (optional)', hint: 'e.g. Cash back from shop'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amount.text.trim());
              if (v == null || v <= 0) {
                setDialog(() => error = 'Enter an amount');
                return;
              }
              if (v > max + 0.005) {
                setDialog(() => error = 'Can be at most ${money(max)}');
                return;
              }
              Navigator.pop(ctx, (amount: v, date: date, note: note.text));
            },
            child: Text(manual ? 'Add refund' : 'Link refund'),
          ),
        ],
      ),
    ),
  );
}
