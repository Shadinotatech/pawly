import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../report.dart';
import '../theme.dart';
import '../util.dart';
import 'expenses_screen.dart';
import 'forms.dart';
import 'pet_form.dart';
import 'pro_screen.dart';
import 'weight_chart.dart';
import 'widgets.dart';

Future<void> openPetDetail(BuildContext context, Pet pet) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id)),
    );

class PetDetailScreen extends StatefulWidget {
  const PetDetailScreen({super.key, required this.petId});
  final String petId;

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

const _tabs = ['Overview', 'Vaccines', 'Medicine', 'Care', 'Weight', 'Vet'];

class _PetDetailScreenState extends State<PetDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _making = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _add(Pet pet, int tab) {
    switch (tab) {
      case 1:
        openVaccineForm(context, pet);
      case 2:
        openMedicationForm(context, pet);
      case 3:
        openCareForm(context, pet);
      case 4:
        openWeightForm(context, pet);
      case 5:
        openVisitForm(context, pet);
    }
  }

  Future<void> _report(Pet pet) async {
    final store = StoreScope.read(context);
    if (!store.isPro) {
      openPro(context, reason: 'Share a clean PDF of ${pet.name}\'s records with your vet, sitter or boarding with Pro.');
      return;
    }
    setState(() => _making = true);
    try {
      await sharePetReport(store, pet);
    } catch (e) {
      if (mounted) toast(context, 'Could not create the report.');
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  Future<void> _deletePet(Pet pet) async {
    final ok = await confirm(context, 'Delete ${pet.name}?',
        'All records and reminders for ${pet.name} will be deleted. This cannot be undone.');
    if (!ok || !mounted) return;
    final store = StoreScope.read(context);
    Navigator.of(context).pop();
    await store.deletePet(pet.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pet = store.petById(widget.petId);
    if (pet == null) return const Scaffold(body: SizedBox.shrink());
    const addLabels = ['', 'Add vaccine', 'Add medicine', 'Add care task', 'Add weight', 'Add visit'];

    return Scaffold(
      floatingActionButton: _tab.index == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(pet, _tab.index),
              icon: const Icon(Icons.add),
              label: Text(addLabels[_tab.index]),
            ),
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 268,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: inner ? Text(pet.name) : null,
            actions: [
              IconButton(
                tooltip: 'Health report (PDF)',
                icon: _making
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _making ? null : () => _report(pet),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit pet',
                onPressed: () => openPetForm(context, pet: pet),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _deletePet(pet);
                  if (v == 'costs') openExpenses(context, petId: pet.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'costs', child: Text('Spending')),
                  PopupMenuItem(value: 'delete', child: Text('Delete pet')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _PetHero(pet: pet),
            ),
            bottom: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final t in _tabs) Tab(text: t)],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _Overview(pet: pet, onAdd: (i) => _add(pet, i), onTab: _tab.animateTo, onReport: () => _report(pet)),
            _VaccineList(pet: pet),
            _MedList(pet: pet),
            _CareList(pet: pet),
            _WeightTab(pet: pet),
            _VisitList(pet: pet),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- hero

class _PetHero extends StatelessWidget {
  const _PetHero({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final color = petColorOf(pet);
    final dark = theme.brightness == Brightness.dark;
    final weights = store.weightsFor(pet.id);
    final chips = <(IconData, String)>[
      (Icons.pets, pet.breed.isNotEmpty ? pet.breed : speciesLabel(pet.species)),
      if (pet.birthDate != null) (Icons.cake_outlined, ageText(pet.birthDate)),
      if (weights.isNotEmpty) (Icons.monitor_weight_outlined, fmtWeight(weights.last.weightKg, store.settings.useLb)),
      if (pet.sex.isNotEmpty) (pet.sex == 'male' ? Icons.male : Icons.female, pet.sex == 'male' ? 'Male' : 'Female'),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: dark ? 0.32 : 0.28), theme.colorScheme.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 92, 20, 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetAvatar(pet: pet, radius: 46),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final ch in chips)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: PawlyColors.of(context).card.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(ch.$1, size: 14, color: PawlyColors.of(context).muted),
                        const SizedBox(width: 4),
                        Text(ch.$2, style: theme.textTheme.labelMedium),
                      ]),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Overview

class _Overview extends StatelessWidget {
  const _Overview({required this.pet, required this.onAdd, required this.onTab, required this.onReport});
  final Pet pet;
  final void Function(int tab) onAdd;
  final void Function(int tab) onTab;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final now = DateTime.now();

    final upcoming = <(String, DateTime, IconData, int)>[
      for (final v in store.dueVaccines(petId: pet.id))
        ('${v.name} vaccine', v.nextDueDate!, Icons.vaccines_outlined, 1),
      for (final cTask in store.careFor(pet.id)) (cTask.displayName, cTask.nextDate, Icons.event_repeat, 3),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final meds = store.medsFor(pet.id).where((m) => m.isActiveOn(now)).toList();
    final spent = store.spentInMonth(now, petId: pet.id);

    final quick = [
      (Icons.vaccines_outlined, 'Vaccine', 1, Brand.petColors[1]),
      (Icons.medication_outlined, 'Medicine', 2, Brand.petColors[2]),
      (Icons.event_repeat, 'Care', 3, Brand.petColors[5]),
      (Icons.monitor_weight_outlined, 'Weight', 4, Brand.petColors[4]),
      (Icons.local_hospital_outlined, 'Vet', 5, Brand.petColors[3]),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          for (final q in quick)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onAdd(q.$3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    IconBubble(q.$1, color: q.$4, size: 46),
                    const SizedBox(height: 6),
                    Text(q.$2, style: theme.textTheme.labelMedium),
                  ]),
                ),
              ),
            ),
        ]),
        const SectionHeader('Coming up', padding: EdgeInsets.fromLTRB(4, 16, 0, 8)),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: (upcoming.isEmpty && meds.isEmpty)
              ? const ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Nothing scheduled'),
                  subtitle: Text('Add a vaccine due date, medicine or repeat care.'),
                )
              : Column(children: [
                  for (final m in meds)
                    ListTile(
                      leading: IconBubble(Icons.medication_outlined, color: Brand.petColors[2]),
                      title: Text(m.name),
                      subtitle: Text(
                          '${m.reminderMinutes.map(fmtMinutes).join(', ')}${m.endDate == null ? ' · ongoing' : ' · until ${fmtShortDate(m.endDate!)}'}'),
                      onTap: () => onTab(2),
                    ),
                  for (final u in upcoming.take(6))
                    ListTile(
                      leading: IconBubble(u.$3, color: u.$4 == 1 ? Brand.petColors[1] : Brand.petColors[5]),
                      title: Text(u.$1),
                      subtitle: Text(fmtDate(u.$2)),
                      trailing: Text(relativeDay(u.$2),
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: dateOnly(u.$2).isBefore(dateOnly(now)) ? c.overdue : null)),
                      onTap: () => onTab(u.$4),
                    ),
                ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Panel(
              onTap: () => openExpenses(context, petId: pet.id),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconBubble(Icons.account_balance_wallet_outlined, color: Brand.petColors[0]),
                const SizedBox(height: 10),
                Text(fmtMoney(spent, store.settings.currency), style: theme.textTheme.titleLarge),
                Text('spent this month', style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              onTap: onReport,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconBubble(Icons.picture_as_pdf_outlined, color: Brand.petColors[3]),
                  const Spacer(),
                  if (!store.isPro) const ProBadge(small: true),
                ]),
                const SizedBox(height: 10),
                Text('Health report', style: theme.textTheme.titleMedium),
                Text('PDF for your vet', style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
        ]),
        if (pet.microchip.isNotEmpty || pet.notes.isNotEmpty || pet.adoptionDate != null) ...[
          const SectionHeader('About', padding: EdgeInsets.fromLTRB(4, 16, 0, 8)),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (pet.birthDate != null) _kv(context, 'Birthday', fmtDate(pet.birthDate!)),
              if (pet.adoptionDate != null) _kv(context, 'Adopted', fmtDate(pet.adoptionDate!)),
              if (pet.microchip.isNotEmpty) _kv(context, 'Microchip', pet.microchip),
              if (pet.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(pet.notes, style: theme.textTheme.bodyMedium),
              ],
            ]),
          ),
        ],
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

Widget _emptyTab(BuildContext context, IconData icon, String title, String message) => ListView(
      children: [
        const SizedBox(height: 24),
        EmptyState(icon: icon, title: title, message: message),
      ],
    );

Widget _listPanel(List<Widget> rows) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(indent: 72),
              rows[i],
            ],
          ]),
        ),
      ],
    );

// ---------------------------------------------------------------- Vaccines

class _VaccineList extends StatelessWidget {
  const _VaccineList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = PawlyColors.of(context);
    final list = store.vaccinesFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab(context, Icons.vaccines_outlined, 'No vaccines yet',
          'Record a vaccine and set the next due date. Pawly reminds you 3 days before.');
    }
    final dueIds = store.dueVaccines(petId: pet.id).map((v) => v.id).toSet();
    return _listPanel([
      for (final v in list)
        Builder(builder: (context) {
          final isDue = dueIds.contains(v.id) && v.nextDueDate != null;
          final isLate = isDue && dateOnly(v.nextDueDate!).isBefore(dateOnly(DateTime.now()));
          return ListTile(
            leading: IconBubble(Icons.vaccines_outlined,
                color: !isDue ? c.muted : isLate ? c.overdue : Brand.petColors[1]),
            title: Text(v.name),
            subtitle: Text([
              'Given ${fmtDate(v.givenDate)}',
              if (isDue) 'Next ${fmtDate(v.nextDueDate!)} · ${relativeDay(v.nextDueDate!)}',
            ].join('\n')),
            isThreeLine: isDue,
            trailing: isDue
                ? TextButton(
                    onPressed: () => openVaccineForm(context, pet, renewOf: v),
                    child: const Text('Renew'))
                : null,
            onTap: () => openVaccineForm(context, pet, vaccine: v),
          );
        }),
    ]);
  }
}

// ---------------------------------------------------------------- Medicine

class _MedList extends StatelessWidget {
  const _MedList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final list = store.medsFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab(context, Icons.medication_outlined, 'No medicines',
          'Add a medicine with reminder times and Pawly alerts you for every dose.');
    }
    final today = dateOnly(DateTime.now());
    final score = store.adherence(petId: pet.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        if (store.isPro)
          Panel(
            child: Row(children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: score ?? 0,
                    strokeWidth: 6,
                    color: c.done,
                    backgroundColor: c.cardBorder,
                  ),
                  Text(score == null ? '-' : '${(score * 100).round()}%',
                      style: theme.textTheme.labelMedium),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('On-time score', style: theme.textTheme.titleMedium),
                  Text(score == null
                      ? 'Shows how many doses were marked given in the last 30 days.'
                      : 'Doses marked given in the last 30 days.',
                      style: theme.textTheme.bodySmall),
                ]),
              ),
            ]),
          )
        else
          ProLockedCard(
            icon: Icons.fact_check_outlined,
            title: 'Dose history',
            message: 'See the share of doses given on time over the last 30 days.',
            onUnlock: () => openPro(context),
          ),
        const SizedBox(height: 12),
        for (final m in list) ...[
          Panel(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(
                leading: IconBubble(Icons.medication_outlined,
                    color: m.isActiveOn(today) ? Brand.petColors[2] : c.muted),
                title: Text(m.name),
                subtitle: Text([
                  if (m.dose.isNotEmpty) m.dose,
                  m.endDate == null
                      ? 'Ongoing'
                      : '${fmtShortDate(m.startDate)} to ${fmtShortDate(m.endDate!)}',
                  if (!m.isActiveOn(today)) 'not today',
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openMedicationForm(context, pet, medication: m),
              ),
              if (m.isActiveOn(today))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final t in m.reminderMinutes)
                      Builder(builder: (context) {
                        final at = today.add(Duration(minutes: t));
                        final given = store.isDoseGiven(m.id, at);
                        return FilterChip(
                          avatar: Icon(given ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 18, color: given ? c.done : c.muted),
                          label: Text(fmtMinutes(t)),
                          selected: given,
                          selectedColor: c.done.withValues(alpha: 0.16),
                          onSelected: (_) => store.toggleDose(m, at),
                        );
                      }),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Care

class _CareList extends StatelessWidget {
  const _CareList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = PawlyColors.of(context);
    final list = store.careFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab(context, Icons.event_repeat, 'No repeat care',
          'Add flea treatment, deworming, grooming or any task that repeats.');
    }
    return _listPanel([
      for (final t in list)
        ListTile(
          leading: IconBubble(Icons.event_repeat,
              color: dateOnly(t.nextDate).isBefore(dateOnly(DateTime.now())) ? c.overdue : Brand.petColors[5]),
          title: Text(t.displayName),
          subtitle: Text('Every ${t.repeatEveryDays} days · ${relativeDay(t.nextDate)}'),
          trailing: TextButton(
            onPressed: () {
              store.completeCare(t);
              toast(context, 'Done. Next on ${fmtDate(t.nextDate)}.');
            },
            child: const Text('Done'),
          ),
          onTap: () => openCareForm(context, pet, care: t),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- Weight

class _WeightTab extends StatelessWidget {
  const _WeightTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final list = store.weightsFor(pet.id);
    final useLb = store.settings.useLb;
    if (list.isEmpty) {
      return _emptyTab(context, Icons.monitor_weight_outlined, 'No weights yet',
          'Weigh your pet every few weeks to spot changes early.');
    }
    final latest = list.last;
    String change = '';
    Color? changeColor;
    if (list.length >= 2) {
      final diff = latest.weightKg - list[list.length - 2].weightKg;
      final d = useLb ? kgToLb(diff) : diff;
      change = '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} ${useLb ? 'lb' : 'kg'} since last time';
      changeColor = d.abs() < 0.01 ? c.muted : (d > 0 ? Brand.petColors[2] : c.done);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmtWeight(latest.weightKg, useLb), style: theme.textTheme.headlineMedium),
            if (change.isNotEmpty)
              Text(change, style: theme.textTheme.bodySmall?.copyWith(color: changeColor, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            WeightChart(entries: list, useLb: useLb, color: petColorOf(pet)),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(indent: 16),
              Builder(builder: (context) {
                final w = list[list.length - 1 - i];
                return ListTile(
                  title: Text(fmtWeight(w.weightKg, useLb)),
                  trailing: Text(fmtDate(w.date), style: theme.textTheme.bodySmall),
                  onTap: () => openWeightForm(context, pet, entry: w),
                );
              }),
            ],
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Vet visits

class _VisitList extends StatelessWidget {
  const _VisitList({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.visitsFor(pet.id);
    if (list.isEmpty) {
      return _emptyTab(context, Icons.local_hospital_outlined, 'No vet visits',
          'Keep notes from every visit: reason, advice and cost.');
    }
    final cur = store.settings.currency;
    return _listPanel([
      for (final v in list)
        ListTile(
          leading: IconBubble(Icons.local_hospital_outlined, color: Brand.petColors[3]),
          title: Text(v.reason),
          subtitle: Text([
            fmtDate(v.date),
            if (v.vetName.isNotEmpty) v.vetName,
          ].join(' · ')),
          trailing: v.cost == null ? null : Text(fmtMoney(v.cost!, cur), style: Theme.of(context).textTheme.titleSmall),
          onTap: () => openVisitForm(context, pet, visit: v),
        ),
    ]);
  }
}
