import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/split_widgets.dart';
import '../widgets/txn_widgets.dart';

/// Everyone you split with, and who owes whom.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final owedToYou = state.people.fold<double>(0, (s, p) => s + (state.balanceOf(p) > 0 ? state.balanceOf(p) : 0));
    final youOwe = state.people.fold<double>(0, (s, p) => s + (state.balanceOf(p) < 0 ? -state.balanceOf(p) : 0));
    final people = state.people.toList()
      ..sort((a, b) => state.balanceOf(b).abs().compareTo(state.balanceOf(a).abs()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Panel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(child: _Total(label: 'Friends owe you', value: owedToYou, color: AppColors.receive)),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(child: _Total(label: 'You owe', value: youOwe, color: AppColors.spend)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: () => askNewPerson(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add person'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendPaidScreen())),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Friend paid'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (people.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              'To split a bill, open the expense and tap "Split this expense". '
              'If a friend paid for you, tap "Friend paid".',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final p in people)
                  ListTile(
                    leading: _Avatar(p.name),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: _BalanceText(balance: state.balanceOf(p), name: p.name),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(personId: p.id!))),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(money(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.accent.withValues(alpha: 0.18),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
    );
  }
}

class _BalanceText extends StatelessWidget {
  const _BalanceText({required this.balance, required this.name});

  final double balance;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (balance.abs() < 0.005) {
      return const Text('All settled', style: TextStyle(color: AppColors.muted));
    }
    return Text(
      balance > 0 ? 'Owes you ${money(balance)}' : 'You owe ${money(-balance)}',
      style: TextStyle(color: balance > 0 ? AppColors.receive : AppColors.spend, fontWeight: FontWeight.w600),
    );
  }
}

/// One friend: balance, settle up, remind, and every shared item.
class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(personId);
    if (person == null) return const Scaffold();
    final balance = state.balanceOf(person);
    final entries = state.entriesOf(person);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(person.name),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirm(
                context,
                'Delete ${person.name}?',
                'Their shares are removed, so split expenses count fully as yours again.',
              );
              if (ok && context.mounted) {
                Navigator.pop(context);
                await state.deletePerson(person);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  balance.abs() < 0.005 ? 'All settled' : (balance > 0 ? '${person.name} owes you' : 'You owe ${person.name}'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  money(balance.abs()),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: balance.abs() < 0.005 ? AppColors.text : (balance > 0 ? AppColors.receive : AppColors.spend),
                  ),
                ),
                if (balance.abs() >= 0.005) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (balance > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                            onPressed: () => remind(context, person),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Remind'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => settleUpFlow(context, person),
                          icon: const Icon(Icons.handshake_rounded, size: 18),
                          label: const Text('Settle up'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('History'),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: Text('Nothing shared yet.', style: TextStyle(color: AppColors.muted))),
            )
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final e in entries)
                    ListTile(
                      leading: Icon(
                        switch (e.kind) {
                          LedgerKind.split => Icons.call_split_rounded,
                          LedgerKind.paidForMe => Icons.receipt_long_rounded,
                          LedgerKind.settle => Icons.handshake_rounded,
                        },
                        color: AppColors.muted,
                      ),
                      title: Text(e.note.isEmpty ? 'Shared expense' : e.note,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${dayMonth(e.date)} · ${_kindLabel(e.kind, person.name)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      trailing: Text(
                        '${e.amount > 0 ? '+' : '−'}${money(e.amount.abs())}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: e.amount > 0 ? AppColors.receive : AppColors.spend),
                      ),
                      onTap: () {
                        final t = e.txnId == null ? null : state.txnById(e.txnId!);
                        if (t != null) showTxnDetails(context, t);
                      },
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 12, 6, 0),
            child: Text('+ means they owe you more, − means you owe them more (or they paid you back).',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

String _kindLabel(LedgerKind kind, String name) => switch (kind) {
      LedgerKind.split => 'You paid, split',
      LedgerKind.paidForMe => '$name paid',
      LedgerKind.settle => 'Settle-up',
    };
