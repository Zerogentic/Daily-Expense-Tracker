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
          const SectionTitle('Your categories'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final c in customCategories)
                  ListTile(
                    leading: CategoryIcon(c, size: 36),
                    title: Text(c.label),
                    subtitle: Text(c.income ? 'Income' : 'Expense', style: const TextStyle(color: AppColors.muted)),
                    trailing: IconButton(
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
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                  title: const Text('New expense category'),
                  onTap: () => createCategory(context, income: false),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.good),
                  title: const Text('New income category'),
                  onTap: () => createCategory(context, income: true),
                ),
              ],
            ),
          ),
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
