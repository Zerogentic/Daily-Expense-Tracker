import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/txn_widgets.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final m = state.month;
    final spent = state.spentIn(m);
    final total = state.totalBudget;

    final cats = expenseCategories.where((c) => !c.saving).toList()
      ..sort((a, b) {
        final ab = state.budgets.containsKey(a.key) ? 0 : 1;
        final bb = state.budgets.containsKey(b.key) ? 0 : 1;
        if (ab != bb) return ab.compareTo(bb);
        return state.spentInCategory(m, b.key).compareTo(state.spentInCategory(m, a.key));
      });

    final attention = cats.where((c) {
      final limit = state.budgets[c.key];
      return limit != null && state.spentInCategory(m, c.key) >= limit * 0.8;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Panel(
          onTap: () => _editBudget(context, AppState.totalBudgetKey, 'Monthly budget', total),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              RingProgress(
                value: total == null ? 0 : spent / total,
                color: total == null ? AppColors.accent : usageColor(spent / total),
                size: 84,
                stroke: 9,
                child: Text(total == null ? '—' : '${(spent / total * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly budget · ${monthShort(m)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(total == null ? 'Not set' : money(total),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(
                      total == null
                          ? 'Tap to set a limit for the whole month'
                          : '${money(spent)} spent so far',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: AppColors.muted, size: 20),
            ],
          ),
        ),
        if (attention > 0) ...[
          const SizedBox(height: 12),
          Panel(
            color: AppColors.warn.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$attention budget${attention == 1 ? ' is' : 's are'} at 80% or more this month.',
                    style: const TextStyle(color: AppColors.text),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SectionTitle('By category'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final c in cats)
                _BudgetRow(
                  category: c,
                  spent: state.spentInCategory(m, c.key),
                  limit: state.budgets[c.key],
                  onTap: () => _editBudget(context, c.key, c.label, state.budgets[c.key]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editBudget(BuildContext context, String key, String label, double? current) async {
    final controller = TextEditingController(text: current == null ? '' : current.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: fieldDecoration('Monthly limit', hint: 'e.g. 5000').copyWith(prefixText: '₹ '),
        ),
        actions: [
          if (current != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 0.0), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await AppScope.read(context).setBudget(key, result);
    }
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.category, required this.spent, required this.limit, required this.onTap});

  final Category category;
  final double spent;
  final double? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = limit;
    final fraction = l == null || l <= 0 ? 0.0 : spent / l;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CategoryIcon(category, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(category.label,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      Text(
                        l == null ? money(spent) : '${money(spent)} / ${money(l)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (l == null)
                    const Text('No limit · tap to set one',
                        style: TextStyle(fontSize: 12, color: AppColors.muted))
                  else
                    UsageBar(fraction: fraction, color: usageColor(fraction)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
