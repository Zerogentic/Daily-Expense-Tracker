import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/txn_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionTitle('Categories'),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text('Tap a category to rename it or change its icon and colour.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          for (final income in [false, true]) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(income ? 'INCOME' : 'EXPENSES',
                  style: const TextStyle(
                      fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final c in income ? incomeCategories : expenseCategories)
                    ListTile(
                      leading: CategoryIcon(c, size: 36),
                      title: Text(c.label),
                      subtitle: c.custom
                          ? const Text('Your category', style: TextStyle(color: AppColors.muted, fontSize: 12))
                          : (categoryOverrides.containsKey(c.key)
                              ? const Text('Edited', style: TextStyle(color: AppColors.muted, fontSize: 12))
                              : null),
                      onTap: () => createCategory(context, income: income, existing: c),
                      trailing: c.custom
                          ? IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
                              onPressed: () async {
                                final ok = await confirm(
                                  context,
                                  'Delete ${c.label}?',
                                  'Its transactions move to ${c.income ? 'Other income' : 'Other'}.',
                                );
                                if (ok) await state.deleteCategory(c);
                              },
                            )
                          : const Icon(Icons.edit_rounded, color: AppColors.muted, size: 20),
                    ),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline_rounded,
                        color: income ? AppColors.receive : AppColors.accent),
                    title: Text(income ? 'New income category' : 'New expense category'),
                    onTap: () => createCategory(context, income: income),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SectionTitle('Your data'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.bad),
              title: const Text('Delete all data', style: TextStyle(color: AppColors.bad)),
              subtitle: const Text('Transactions, budgets, bills and settings',
                  style: TextStyle(color: AppColors.muted)),
              onTap: () async {
                final ok = await confirm(
                  context,
                  'Delete everything?',
                  'All transactions, budgets and bills on this phone will be erased. This cannot be undone.',
                  action: 'Delete all',
                );
                if (ok) {
                  await state.clearAll();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text('Daily Expense Tracker · version 1.0 · Zero gentic',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
