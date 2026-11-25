import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/txn_widgets.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeAll, required this.onOpenBudgets, required this.onOpenBills});

  final VoidCallback onSeeAll;
  final VoidCallback onOpenBudgets;
  final VoidCallback onOpenBills;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final m = state.month;
    final spent = state.spentIn(m);
    final received = state.receivedIn(m);
    final byCat = state.spendByCategory(m);
    final trend = state.spendTrend(6);
    final inTrend = state.receivedTrend(6);
    final recent = state.txnsIn(m).take(5).toList();
    final bills = state.isCurrentMonth ? state.unpaidBillsThisMonth.take(3).toList() : <Bill>[];

    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _Header(state: state),
          const SizedBox(height: 10),
          _HeroCard(state: state, spent: spent, received: received, onSetBudget: onOpenBudgets),
          const SizedBox(height: 12),
          _Insights(state: state),
          if (bills.isNotEmpty) ...[
            SectionTitle('Bills due', action: 'All bills', onAction: onOpenBills),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [for (final b in bills) _BillRow(bill: b)]),
            ),
          ],
          const SectionTitle('Where it went'),
          if (byCat.isEmpty)
            const Panel(child: _Empty(icon: Icons.donut_large_rounded, text: 'No spending recorded for this month yet.'))
          else
            Panel(
              child: Column(
                children: [
                  _DonutSummary(entries: byCat, total: spent),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 6),
                  for (final e in byCat.take(6))
                    _CategoryRow(
                      category: categoryFor(e.key),
                      amount: e.value,
                      fraction: spent <= 0 ? 0 : e.value / spent,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: AppColors.bg,
                            surfaceTintColor: Colors.transparent,
                            title: Text(categoryFor(e.key).label),
                          ),
                          body: ActivityScreen(category: e.key, month: m),
                        ),
                      )),
                    ),
                ],
              ),
            ),
          const SectionTitle('Cash flow · last 6 months'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    LegendDot(color: AppColors.spend, label: 'Spent'),
                    SizedBox(width: 16),
                    LegendDot(color: AppColors.receive, label: 'Received'),
                    SizedBox(width: 16),
                    LegendDot(color: AppColors.accent, label: 'Invested'),
                  ],
                ),
                const SizedBox(height: 16),
                FlowBars(
                  spent: trend.map((e) => e.value).toList(),
                  received: inTrend,
                  saved: state.savedTrend(6),
                  labels: trend.map((e) => monthShort(e.key)).toList(),
                ),
              ],
            ),
          ),
          SectionTitle('Recent', action: 'See all', onAction: onSeeAll),
          if (recent.isEmpty)
            const Panel(child: _Empty(icon: Icons.add_card_rounded, text: 'Tap Add to record your first expense.'))
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [for (final t in recent) TxnTile(t)]),
            ),
        ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _RoundIcon(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => state.shiftMonth(-1),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        monthTitle(state.month),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _RoundIcon(
                      icon: Icons.chevron_right_rounded,
                      onTap: state.isCurrentMonth ? null : () => state.shiftMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _RoundIcon(
              icon: Icons.settings_rounded,
              size: 42,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap, this.size = 30});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.6, color: enabled ? AppColors.text : AppColors.border),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state, required this.spent, required this.received, required this.onSetBudget});

  final AppState state;
  final double spent;
  final double received;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final b = state.totalBudget;
    final fraction = (b == null || b <= 0) ? 0.0 : spent / b;
    final m = state.month;
    final invested = state.netSavedIn(m);
    final rate = state.savingsRate(m);
    final net = received - spent - invested;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF233765)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A8F), Color(0xFF0F1C40), Color(0xFF0B1226)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent2.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total spent',
                              style: TextStyle(color: Color(0xFFB7C4E6), fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              money(spent),
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (b != null)
                      RingProgress(
                        value: fraction,
                        color: usageColor(fraction),
                        size: 72,
                        stroke: 8,
                        child: Text('${(fraction * 100).round()}%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (b == null)
                  GestureDetector(
                    onTap: onSetBudget,
                    child: const Text('Set a monthly budget →',
                        style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w600)),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: usageColor(fraction),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spent <= b ? '${money(b - spent)} left of ${money(b)} budget' : '${money(spent - b)} over budget',
                    style: TextStyle(
                      fontSize: 13,
                      color: spent <= b ? const Color(0xFFB7C4E6) : AppColors.spend,
                      fontWeight: spent <= b ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _FlowPill(
                        icon: Icons.south_west_rounded,
                        label: 'Received',
                        value: money(received),
                        color: AppColors.receive,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FlowPill(
                        icon: Icons.savings_rounded,
                        label: 'Invested',
                        note: rate == null || rate <= 0 ? null : '${(rate * 100).round()}% of income',
                        value: '${invested < 0 ? '−' : ''}${money(invested.abs())}',
                        color: AppColors.accent2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FlowPill(
                        icon: net < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                        label: 'Left over',
                        value: '${net < 0 ? '−' : '+'}${money(net.abs())}',
                        color: net < 0 ? AppColors.spend : AppColors.receive,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowPill extends StatelessWidget {
  const _FlowPill({required this.icon, required this.label, required this.value, required this.color, this.note});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// Small line under the amount, e.g. "22% of income".
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB7C4E6), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
          SizedBox(
            height: 15,
            child: Text(note ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFFB7C4E6))),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final m = state.month;
    final biggest = state.biggestExpense(m);
    final top = state.topMerchants(m, limit: 1);
    return Row(
      children: [
        Expanded(
          child: _InsightCard(
            icon: Icons.calendar_view_day_rounded,
            color: AppColors.accent,
            label: 'Per day',
            value: money(state.dailyAverage(m).roundToDouble()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InsightCard(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.spend,
            label: 'Biggest',
            value: biggest == null ? '—' : money(state.counted(biggest)),
            detail: biggest?.title,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InsightCard(
            icon: Icons.storefront_rounded,
            color: AppColors.accent2,
            label: 'Top place',
            value: top.isEmpty ? '—' : top.first.key,
            detail: top.isEmpty ? null : money(top.first.value),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.icon, required this.color, required this.label, required this.value, this.detail});

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
          SizedBox(
            height: 16,
            child: Text(detail ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _DonutSummary extends StatelessWidget {
  const _DonutSummary({required this.entries, required this.total});

  final List<MapEntry<String, double>> entries;
  final double total;

  @override
  Widget build(BuildContext context) {
    final top = entries.take(5).toList();
    final rest = entries.skip(5).fold<double>(0, (s, e) => s + e.value);
    final values = [...top.map((e) => e.value), if (rest > 0) rest];
    final colors = [...top.map((e) => categoryFor(e.key).color), if (rest > 0) AppColors.muted];

    return Row(
      children: [
        Donut(
          values: values,
          colors: colors,
          size: 124,
          stroke: 15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${entries.length}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
              Text(entries.length == 1 ? 'category' : 'categories',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(categoryFor(top[i].key).label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.text)),
                      ),
                      Text(total <= 0 ? '' : '${(top[i].value / total * 100).round()}%',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (rest > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Everything else', style: TextStyle(fontSize: 12.5, color: AppColors.text)),
                      ),
                      Text(total <= 0 ? '' : '${(rest / total * 100).round()}%',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = bill.dueDateIn(DateTime(now.year, now.month));
    final today = DateTime(now.year, now.month, now.day);
    final days = due.difference(today).inDays;
    final status = days < 0
        ? 'Overdue by ${-days} day${days == -1 ? '' : 's'}'
        : days == 0
            ? 'Due today'
            : 'Due ${dayMonth(due)}';
    final color = days < 0 ? AppColors.bad : (days <= 3 ? AppColors.warn : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CategoryIcon(categoryFor(bill.category), size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(status, style: TextStyle(fontSize: 12.5, color: color)),
              ],
            ),
          ),
          Text(money(bill.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.spend)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.amount, required this.fraction, required this.onTap});

  final Category category;
  final double amount;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                      Text(money(amount),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  UsageBar(fraction: fraction, color: category.color),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: AppColors.border, size: 36),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
