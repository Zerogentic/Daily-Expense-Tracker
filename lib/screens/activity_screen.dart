import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/txn_widgets.dart';

enum _Filter { all, spent, received }

/// All transactions, grouped by day, with search and filters.
/// Pass [category] and [month] to show a single category for one month.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.category, this.month});

  final String? category;
  final DateTime? month;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _search.text.trim().toLowerCase();
    final m = widget.month;

    final list = state.txns.where((t) {
      if (widget.category != null && t.category != widget.category) return false;
      if (m != null && (t.date.year != m.year || t.date.month != m.month)) return false;
      switch (_filter) {
        case _Filter.spent:
          if (!t.isExpense) return false;
        case _Filter.received:
          if (t.isExpense) return false;
        case _Filter.all:
          break;
      }
      if (q.isEmpty) return true;
      return t.merchant.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          categoryFor(t.category).label.toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(0).contains(q);
    }).toList();

    final total = list.fold<double>(0, (s, t) => s + (t.countsAsSpend ? t.amount : 0));

    // Group by calendar day.
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(day, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (widget.category == null) ...[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: fieldDecoration('Search',
                hint: 'Merchant, note, category or amount',
                prefix: const Icon(Icons.search_rounded, color: AppColors.muted)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', _Filter.all),
                _chip('Spent', _Filter.spent),
                _chip('Received', _Filter.received),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.category != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '${money(total)} across ${list.length} transaction${list.length == 1 ? '' : 's'}'
              '${m != null ? ' in ${monthTitle(m)}' : ''}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text('No transactions here yet.', style: TextStyle(color: AppColors.muted)),
            ),
          ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(dayHeader(entry.key),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.3)),
                ),
                _DayTotal(entry.value),
              ],
            ),
          ),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [for (final t in entry.value) TxnTile(t)]),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        showCheckmark: false,
        selectedColor: AppColors.accent.withValues(alpha: 0.22),
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
        labelStyle: TextStyle(
          color: selected ? AppColors.text : AppColors.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// "−₹1,200  +₹500" for a day: spent in rose, received in green.
class _DayTotal extends StatelessWidget {
  const _DayTotal(this.txns);

  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final out = txns.where((t) => t.countsAsSpend).fold<double>(0, (s, t) => s + t.amount);
    final inn = txns.where((t) => t.countsAsIncome).fold<double>(0, (s, t) => s + t.amount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (out > 0)
          Text('−${money(out)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.spend, fontWeight: FontWeight.w600)),
        if (out > 0 && inn > 0) const SizedBox(width: 10),
        if (inn > 0)
          Text('+${money(inn)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.receive, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
