import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'txn_widgets.dart';

/// On a transaction page: who it was split with, who paid it, or which
/// debt it settled.
class PeopleSection extends StatelessWidget {
  const PeopleSection({super.key, required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final entries = state.ledgerFor(txn);
    final splits = entries.where((e) => e.kind == LedgerKind.split).toList();
    final paidBy = entries.where((e) => e.kind == LedgerKind.paidForMe).toList();
    final settles = entries.where((e) => e.kind == LedgerKind.settle).toList();
    if (!txn.isExpense && settles.isEmpty) return const SizedBox.shrink();
    if (txn.isExpense && txn.isSaving) return const SizedBox.shrink();

    String name(LedgerEntry e) => state.personById(e.personId)?.name ?? 'Someone';
    Widget line(String text, String amount, Color color, {VoidCallback? onRemove}) => Row(
          children: [
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.text)),
            ),
            Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                onPressed: onRemove,
              )
            else
              const SizedBox(width: 12),
          ],
        );

    final List<Widget> body;
    if (paidBy.isNotEmpty) {
      body = [
        for (final e in paidBy) line('Paid by ${name(e)} · you owe your share', money(-e.amount), AppColors.spend),
      ];
    } else if (settles.isNotEmpty) {
      body = [
        for (final e in settles)
          line(e.amount < 0 ? 'Settle-up from ${name(e)}' : 'Settle-up to ${name(e)}', money(e.amount.abs()),
              AppColors.text,
              onRemove: () => state.deleteEntry(e)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            txn.isExpense ? 'Not counted as spending.' : 'Not counted as income.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
      ];
    } else {
      final theirs = splits.fold<double>(0, (s, e) => s + e.amount);
      body = [
        if (splits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Text('Shared this with friends? Split it so only your share counts.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          )
        else ...[
          line('You', money((txn.amount - theirs).clamp(0, double.infinity).toDouble()), AppColors.text),
          for (final e in splits) line(name(e), money(e.amount), AppColors.receive),
        ],
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SplitScreen(txn: txn))),
          icon: Icon(splits.isEmpty ? Icons.call_split_rounded : Icons.edit_rounded, size: 18),
          label: Text(splits.isEmpty ? 'Split this expense' : 'Change split'),
        ),
      ];
    }

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
                Icon(Icons.group_rounded, size: 18, color: AppColors.accent),
                SizedBox(width: 8),
                Text('Shared with friends', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
              ],
            ),
            const SizedBox(height: 4),
            ...body,
          ],
        ),
      ),
    );
  }
}

/// Splits an expense between you and friends, equally or by amount.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key, required this.txn});

  final Txn txn;

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final Set<int> _selected = {};
  final Map<int, TextEditingController> _amounts = {};
  bool _equal = true;
  bool _includeMe = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    final existing = state.ledgerFor(widget.txn).where((e) => e.kind == LedgerKind.split).toList();
    for (final e in existing) {
      _selected.add(e.personId);
      _amounts[e.personId] = TextEditingController(text: _fmt(e.amount));
    }
    if (existing.isNotEmpty) {
      final shares = equalShares(widget.txn.amount, existing.length + 1);
      _equal = existing.every((e) => (e.amount - shares.first).abs() < 0.011);
    }
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Each friend's share, by person id.
  Map<int, double> _shares() {
    final ids = _selected.toList();
    if (_equal) {
      final shares = equalShares(widget.txn.amount, ids.length + (_includeMe ? 1 : 0));
      return {for (var i = 0; i < ids.length; i++) ids.elementAt(i): shares.elementAt(i)};
    }
    return {for (final id in ids) id: double.tryParse(_amounts[id]?.text.trim() ?? '') ?? 0};
  }

  Future<void> _addPerson() async {
    final person = await askNewPerson(context);
    if (person?.id == null) return;
    setState(() {
      _selected.add(person!.id!);
      _amounts[person.id!] = TextEditingController();
    });
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    final shares = _shares();
    final total = shares.values.fold<double>(0, (s, v) => s + v);
    if (shares.isEmpty) {
      setState(() => _error = 'Pick at least one friend.');
      return;
    }
    if (shares.values.any((v) => v <= 0)) {
      setState(() => _error = 'Every friend needs an amount above zero.');
      return;
    }
    if (total > widget.txn.amount + 0.005) {
      setState(() => _error = 'Friends\' shares add up to more than ${money(widget.txn.amount)}.');
      return;
    }
    await state.splitExpense(widget.txn, shares);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final shares = _shares();
    final theirs = shares.values.fold<double>(0, (s, v) => s + v);
    final mine = widget.txn.amount - theirs;
    final hasSplit = state.ledgerFor(widget.txn).any((e) => e.kind == LedgerKind.split);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text('Split ${money(widget.txn.amount)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(widget.txn.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text(dayHeader(widget.txn.date), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          const Text('Who shared it?', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in state.people)
                FilterChip(
                  label: Text(p.name),
                  selected: _selected.contains(p.id),
                  onSelected: (on) => setState(() {
                    _error = null;
                    if (on) {
                      _selected.add(p.id!);
                      _amounts.putIfAbsent(p.id!, () => TextEditingController());
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.accent),
                label: const Text('Add person'),
                onPressed: _addPerson,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  value: _equal,
                  activeThumbColor: AppColors.accent,
                  title: const Text('Split equally'),
                  subtitle: const Text('Turn off to type each person\'s amount',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  onChanged: (v) => setState(() {
                    _error = null;
                    if (!v) {
                      for (final e in _shares().entries) {
                        _amounts[e.key]?.text = _fmt(e.value);
                      }
                    }
                    _equal = v;
                  }),
                ),
                if (_equal)
                  SwitchListTile(
                    value: _includeMe,
                    activeThumbColor: AppColors.accent,
                    title: const Text('Include me'),
                    subtitle: const Text('Turn off if you paid entirely for them',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    onChanged: (v) => setState(() => _includeMe = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_selected.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final id in _selected)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(state.personById(id)?.name ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                          ),
                          if (_equal)
                            Text(money(shares[id] ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.receive))
                          else
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _amounts[id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                onChanged: (_) => setState(() => _error = null),
                                textAlign: TextAlign.right,
                                decoration: fieldDecoration('Amount').copyWith(prefixText: '₹ '),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Divider(color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Your share (counts as your spending)',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                        ),
                        Text(money(mine < 0 ? 0 : mine),
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: mine < -0.005 ? AppColors.bad : AppColors.text)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.bad)),
            ),
          if (hasSplit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await state.removeSplit(widget.txn);
                  nav.pop();
                },
                icon: const Icon(Icons.call_merge_rounded, color: AppColors.bad),
                label: const Text('Remove split', style: TextStyle(color: AppColors.bad)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save split', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// Asks for a friend's name and adds them.
Future<Person?> askNewPerson(BuildContext context) async {
  final state = AppScope.read(context);
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Add a person'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: fieldDecoration('Name', hint: 'e.g. Ravi'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty) return null;
  return state.addPerson(name.trim());
}

/// Amount dialog with an upper limit.
Future<double?> askAmount(BuildContext context, {required String title, required String intro, required double max}) {
  String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final controller = TextEditingController(text: fmt(max));
  String? error;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(intro, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: fieldDecoration('Amount').copyWith(prefixText: '₹ ', errorText: error),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v <= 0) {
                setDialog(() => error = 'Enter an amount');
                return;
              }
              if (v > max + 0.005) {
                setDialog(() => error = 'Can be at most ${money(max)}');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Records money that settles part or all of what's owed with [person]:
/// a payment already in your transactions, or cash.
Future<void> settleUpFlow(BuildContext context, Person person) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final balance = state.balanceOf(person);
  if (balance.abs() < 0.005) return;
  final theyPaid = balance > 0;
  final candidates = state.settleCandidates(person, theyPaid: theyPaid);

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Settle up',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              theyPaid
                  ? '${person.name} owes you ${money(balance)}. Pick the payment they sent you.'
                  : 'You owe ${person.name} ${money(-balance)}. Pick the payment you sent them.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
          ),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text(
                theyPaid ? 'No money received lately to link.' : 'No payments made lately to link.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
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
                      subtitle: Text(dayHeader(c.date), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      trailing: Text('${theyPaid ? '+' : '−'}${money(state.netAmount(c))}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: theyPaid ? AppColors.receive : AppColors.spend)),
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
              onPressed: () => Navigator.pop(ctx, 'cash'),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Paid in cash or elsewhere'),
            ),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final via = picked is Txn ? picked : null;
  final available = via == null ? balance.abs() : state.netAmount(via);
  final max = available < balance.abs() ? available : balance.abs();
  final amount = await askAmount(
    context,
    title: 'Settle-up amount',
    intro: theyPaid ? 'How much of this was ${person.name} paying you back?' : 'How much of this paid ${person.name} back?',
    max: max,
  );
  if (amount == null) return;
  await state.settle(person, amount, theyPaid: theyPaid, via: via);
  final left = state.balanceOf(person);
  messenger.showSnackBar(SnackBar(
    content: Text(left.abs() < 0.005
        ? 'All settled with ${person.name}.'
        : (left > 0 ? '${person.name} still owes you ${money(left)}.' : 'You still owe ${person.name} ${money(-left)}.')),
  ));
}

/// Records an expense a friend paid for you: your share counts as your
/// spending, and you owe it to them.
class FriendPaidScreen extends StatefulWidget {
  const FriendPaidScreen({super.key, this.person});

  final Person? person;

  @override
  State<FriendPaidScreen> createState() => _FriendPaidScreenState();
}

class _FriendPaidScreenState extends State<FriendPaidScreen> {
  final _what = TextEditingController();
  final _amount = TextEditingController();
  int? _personId;
  String _category = 'food';
  bool _categoryTouched = false;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _personId = widget.person?.id;
    _what.addListener(() {
      if (_categoryTouched || _what.text.trim().isEmpty) return;
      final guess = AppScope.read(context).suggestCategory(merchant: _what.text.trim(), type: TxnType.debit);
      if (guess != 'other') setState(() => _category = guess);
    });
  }

  @override
  void dispose() {
    _what.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    final share = double.tryParse(_amount.text.trim());
    final person = _personId == null ? null : state.personById(_personId!);
    if (person == null) {
      setState(() => _error = 'Pick who paid.');
      return;
    }
    if (share == null || share <= 0) {
      setState(() => _error = 'Enter your share.');
      return;
    }
    await state.friendPaid(
      person: person,
      share: share,
      merchant: _what.text.trim().isEmpty ? 'Paid by ${person.name}' : _what.text.trim(),
      category: _category,
      date: _date,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('A friend paid for me'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const Text('Who paid?', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in state.people)
                ChoiceChip(
                  label: Text(p.name),
                  selected: _personId == p.id,
                  onSelected: (_) => setState(() {
                    _personId = p.id;
                    _error = null;
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.accent),
                label: const Text('Add person'),
                onPressed: () async {
                  final p = await askNewPerson(context);
                  if (p != null) setState(() => _personId = p.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _what,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDecoration('What for', hint: 'e.g. Dinner, Movie tickets'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => setState(() => _error = null),
            decoration: fieldDecoration('Your share', hint: 'What you owe them').copyWith(prefixText: '₹ '),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
            },
            child: InputDecorator(
              decoration: fieldDecoration('Date'),
              child: Text(dayHeader(_date), style: const TextStyle(color: AppColors.text)),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final key = await pickCategory(context, income: false, selected: _category);
              if (key != null) {
                setState(() {
                  _category = key;
                  _categoryTouched = true;
                });
              }
            },
            child: InputDecorator(
              decoration: fieldDecoration('Category'),
              child: Row(
                children: [
                  CategoryIcon(categoryFor(_category), size: 28),
                  const SizedBox(width: 10),
                  Text(categoryFor(_category).label, style: const TextStyle(color: AppColors.text)),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.bad)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// Opens the phone's share sheet (WhatsApp, SMS…) with a friendly reminder.
Future<void> remind(BuildContext context, Person person) async {
  final text = AppScope.read(context).reminderText(person);
  await Share.share(text);
}
