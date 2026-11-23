import 'package:flutter/material.dart';

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
    final subtitle = [
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
            Text(
              '${txn.isExpense ? '−' : '+'}${money(txn.amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: txn.excluded ? AppColors.muted : (txn.isExpense ? AppColors.spend : AppColors.receive),
                decoration: txn.excluded ? TextDecoration.lineThrough : null,
              ),
            ),
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

/// Dialog for creating a category; returns the new key, or null if cancelled.
Future<String?> createCategory(BuildContext context, {required bool income}) async {
  final name = TextEditingController();
  var iconIndex = 0;
  var colorIndex = 0;
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
                Text(income ? 'New income category' : 'New expense category',
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
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Create category'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (created != true) return null;
  return state.addCategory(name.text.trim(), income: income, iconIndex: iconIndex, colorIndex: colorIndex);
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
            Text(
              '${txn.isExpense ? '−' : '+'}${money(txn.amount)}',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: txn.isExpense ? AppColors.spend : AppColors.receive,
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
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
