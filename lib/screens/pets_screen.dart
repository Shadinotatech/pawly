import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'pet_detail.dart';
import 'pet_form.dart';
import 'widgets.dart';

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final pets = store.pets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My pets'),
        actions: [
          if (!store.isPro)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${pets.length} of ${AppStore.freePetLimit} on free',
                    style: theme.textTheme.bodySmall),
              ),
            ),
        ],
      ),
      floatingActionButton: pets.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openPetForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add pet'),
            ),
      body: pets.isEmpty
          ? EmptyState(
              icon: Icons.pets,
              title: 'No pets yet',
              message: 'Add a dog, cat or any pet to start tracking care.',
              action: FilledButton.icon(
                onPressed: () => openPetForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add a pet'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: pets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _PetCard(pet: pets[i]),
            ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final color = petColorOf(pet);
    final now = DateTime.now();
    final weights = store.weightsFor(pet.id);

    DateTime? nextDate;
    String? nextLabel;
    for (final v in store.dueVaccines(petId: pet.id)) {
      if (nextDate == null || v.nextDueDate!.isBefore(nextDate)) {
        nextDate = v.nextDueDate;
        nextLabel = '${v.name} vaccine';
      }
    }
    for (final t in store.careFor(pet.id)) {
      if (nextDate == null || t.nextDate.isBefore(nextDate)) {
        nextDate = t.nextDate;
        nextLabel = t.displayName;
      }
    }
    final activeMeds = store.medsFor(pet.id).where((m) => m.isActiveOn(now)).length;
    final isLate = nextDate != null && dateOnly(nextDate).isBefore(dateOnly(now));

    final facts = [
      if (pet.breed.isNotEmpty) pet.breed else speciesLabel(pet.species),
      if (pet.birthDate != null) ageText(pet.birthDate),
      if (weights.isNotEmpty) fmtWeight(weights.last.weightKg, store.settings.useLb),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: c.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openPetDetail(context, pet),
        child: Column(children: [
          Container(height: 6, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              PetAvatar(pet: pet, radius: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pet.name, style: theme.textTheme.titleLarge),
                  if (facts.isNotEmpty) Text(facts, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (nextDate != null)
                      _Tag(
                        icon: Icons.event_outlined,
                        text: '$nextLabel · ${relativeDay(nextDate)}',
                        color: isLate ? c.overdue : color,
                      ),
                    if (activeMeds > 0)
                      _Tag(
                        icon: Icons.medication_outlined,
                        text: activeMeds == 1 ? '1 medicine' : '$activeMeds medicines',
                        color: Brand.petColors[2],
                      ),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Color.lerp(color, Colors.white, 0.3)! : Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
