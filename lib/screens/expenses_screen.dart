import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../util.dart';
import 'forms.dart';
import 'pro_screen.dart';
import 'widgets.dart';

Future<void> openExpenses(BuildContext context, {String? petId}) =>
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExpensesScreen(petId: petId)));

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.petId});
  final String? petId;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _petId;

  @override
  void initState() {
    super.initState();
    _petId = widget.petId;
  }

  Future<void> _add() async {
    final store = StoreScope.read(context);
    Pet? pet = _petId == null ? null : store.petById(_petId!);
    if (pet == null) {
      if (store.pets.length == 1) {
        pet = store.pets.first;
      } else {
        pet = await showModalBottomSheet<Pet>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final p in store.pets)
                ListTile(
                  leading: PetAvatar(pet: p, radius: 18),
                  title: Text(p.name),
                  onTap: () => Navigator.pop(c, p),
                ),
            ]),
          ),
        );
      }
    }
    if (pet != null && mounted) await openExpenseForm(context, pet);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final cur = store.settings.currency;
    final now = DateTime.now();
    final list = store.expensesFor(_petId);
    final thisMonth = store.spentInMonth(now, petId: _petId);
    final yearTotal = list
        .where((e) => e.date.year == now.year)
        .fold(0.0, (s, e) => s + e.amount);

    // Last 6 months.
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final monthTotals = [for (final m in months) store.spentInMonth(m, petId: _petId)];

    // Category totals for this year.
    final byCat = <ExpenseCategory, double>{};
    for (final e in list.where((e) => e.date.year == now.year)) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Spending')),
      floatingActionButton: store.pets.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (store.pets.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All pets'),
                      selected: _petId == null,
                      onSelected: (_) => setState(() => _petId = null),
                    ),
                  ),
                  for (final p in store.pets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: petColorOf(p), radius: 6),
                        label: Text(p.name),
                        selected: _petId == p.id,
                        onSelected: (_) => setState(() => _petId = p.id),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(child: _Stat(label: 'This month', value: fmtMoney(thisMonth, cur))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'This year', value: fmtMoney(yearTotal, cur))),
            ]),
          ),
          const SectionHeader('Insights'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: store.isPro
                ? Column(children: [
                    Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Last 6 months', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 14),
                        _MonthBars(months: months, totals: monthTotals, currency: cur),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('By category this year', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 10),
                        if (cats.isEmpty)
                          Text('No expenses this year yet.', style: theme.textTheme.bodySmall),
                        for (final e in cats)
                          _CategoryBar(
                            cat: e.key,
                            amount: e.value,
                            share: yearTotal == 0 ? 0 : e.value / yearTotal,
                            currency: cur,
                          ),
                      ]),
                    ),
                  ])
                : ProLockedCard(
                    icon: Icons.insights_outlined,
                    title: 'Spending insights',
                    message: 'See a 6-month chart and where your money goes by category.',
                    onUnlock: () => openPro(context),
                  ),
          ),
          const SectionHeader('All expenses'),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Panel(
                child: Text('No expenses yet. Tap "Add expense" to log food, vet bills and more.',
                    style: theme.textTheme.bodyMedium),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Panel(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    Builder(builder: (context) {
                      final e = list[i];
                      final pet = store.petById(e.petId);
                      return ListTile(
                        leading: IconBubble(expenseIcon(e.category),
                            color: pet == null ? c.muted : petColorOf(pet)),
                        title: Text(e.note.isEmpty ? e.category.label : e.note),
                        subtitle: Text('${pet?.name ?? ''} · ${fmtDate(e.date)}'),
                        trailing: Text(fmtMoney(e.amount, cur), style: theme.textTheme.titleSmall),
                        onTap: pet == null ? null : () => openExpenseForm(context, pet, expense: e),
                      );
                    }),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.headlineSmall)),
      ]),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.months, required this.totals, required this.currency});
  final List<DateTime> months;
  final List<double> totals;
  final String currency;

  static const _names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = totals.fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < months.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (totals[i] > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(fmtMoney(totals[i], currency),
                            style: theme.textTheme.labelSmall),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: max == 0 ? 4 : 4 + 96 * totals[i] / max,
                      decoration: BoxDecoration(
                        color: i == months.length - 1
                            ? Brand.marigold
                            : theme.colorScheme.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_names[months[i].month - 1], style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.cat, required this.amount, required this.share, required this.currency});
  final ExpenseCategory cat;
  final double amount;
  final double share;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final color = Brand.petColor(cat.index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(expenseIcon(cat), size: 18, color: c.muted),
        const SizedBox(width: 10),
        SizedBox(width: 96, child: Text(cat.label, style: theme.textTheme.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 10,
              color: color,
              backgroundColor: c.cardBorder,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(fmtMoney(amount, currency), style: theme.textTheme.labelMedium),
      ]),
    );
  }
}
