import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/txn_widgets.dart';

class AddTxnScreen extends StatefulWidget {
  const AddTxnScreen({super.key, this.existing});

  final Txn? existing;

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  TxnType _type = TxnType.debit;
  String? _category;
  bool _categoryTouched = false;
  DateTime _date = DateTime.now();
  bool _excluded = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : e.amount.toStringAsFixed(2);
      _merchant.text = e.merchant;
      _note.text = e.note;
      _type = e.type;
      _category = e.category;
      _categoryTouched = true;
      _date = e.date;
      _excluded = e.excluded;
    }
    _merchant.addListener(_suggestCategory);
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Suggests a category from the payee name until the user picks one.
  void _suggestCategory() {
    if (_categoryTouched) return;
    final text = _merchant.text.trim();
    if (text.isEmpty) return;
    final guess = AppScope.read(context).suggestCategory(merchant: text, type: _type);
    if (guess != 'other' && guess != 'income' && guess != _category) setState(() => _category = guess);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than zero.')));
      return;
    }
    final category = _category ?? (_type == TxnType.debit ? 'other' : 'income');
    final state = AppScope.read(context);
    final e = widget.existing;
    if (e == null) {
      await state.addTxn(Txn(
        amount: amount,
        type: _type,
        category: category,
        merchant: _merchant.text.trim(),
        note: _note.text.trim(),
        date: _date,
        excluded: _excluded,
      ));
    } else {
      final updated = e.copyWith(
        amount: amount,
        type: _type,
        merchant: _merchant.text.trim(),
        note: _note.text.trim(),
        date: _date,
        excluded: _excluded,
      );
      await state.updateTxn(updated);
      if (category != e.category && mounted) {
        await changeCategory(context, updated, category);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type == TxnType.debit ? AppColors.accent : AppColors.good;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_editing ? 'Edit transaction' : 'Add transaction'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.debit, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(value: TxnType.credit, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (_category != null && categoryFor(_category!).income != (_type == TxnType.credit)) {
                  _category = null;
                  _categoryTouched = false;
                }
              }),
            ),
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 280,
                child: TextField(
                  controller: _amount,
                  autofocus: !_editing,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: accent),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppColors.border),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: fieldDecoration(
                _type == TxnType.debit ? 'Paid to' : 'Received from',
                hint: _type == TxnType.debit ? 'e.g. Swiggy, Rent, Ravi' : 'e.g. Salary, Freelance client',
                prefix: const Icon(Icons.storefront_rounded, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: fieldDecoration('Date',
                    prefix: const Icon(Icons.calendar_today_rounded, color: AppColors.muted)),
                child: Text(dayHeader(_date), style: const TextStyle(color: AppColors.text, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('Note (optional)',
                  prefix: const Icon(Icons.notes_rounded, color: AppColors.muted)),
            ),
            const SizedBox(height: 24),
            const Text('Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 14),
            CategorySections(
              income: _type == TxnType.credit,
              selected: _category,
              onSelected: (k) => setState(() {
                _category = k;
                _categoryTouched = true;
              }),
              onAdd: () async {
                final key = await createCategory(context, income: _type == TxnType.credit);
                if (key != null) {
                  setState(() {
                    _category = key;
                    _categoryTouched = true;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                value: !_excluded,
                activeThumbColor: AppColors.accent,
                title: Text(_type == TxnType.debit ? 'Count as an expense' : 'Count as income'),
                subtitle: const Text('Turn off for self-transfers, investments and similar',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                onChanged: (on) => setState(() => _excluded = !on),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _save,
            child: Text(_editing ? 'Save changes' : 'Save',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
