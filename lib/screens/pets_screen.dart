import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../util.dart';
import 'pet_detail.dart';
import 'pet_form.dart';
import 'widgets.dart';

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pets = store.pets;
    return Scaffold(
      appBar: AppBar(title: const Text('My pets')),
      floatingActionButton: FloatingActionButton.extended(
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
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: pets.length,
              itemBuilder: (context, i) {
                final p = pets[i];
                return _PetCard(pet: p);
              },
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
    final info = [
      if (pet.breed.isNotEmpty) pet.breed else speciesLabel(pet.species),
      if (pet.birthDate != null) ageText(pet.birthDate),
    ].where((s) => s.isNotEmpty).join(' · ');

    // Find the next thing that is due for this pet.
    DateTime? nextDate;
    String? nextLabel;
    for (final v in store.dueVaccines(petId: pet.id)) {
      if (nextDate == null || v.nextDueDate!.isBefore(nextDate)) {
        nextDate = v.nextDueDate;
        nextLabel = '${v.name} vaccine';
      }
    }
    for (final c in store.careFor(pet.id)) {
      if (nextDate == null || c.nextDate.isBefore(nextDate)) {
        nextDate = c.nextDate;
        nextLabel = c.displayName;
      }
    }
    final activeMeds = store
        .medsFor(pet.id)
        .where((m) => m.isActiveOn(DateTime.now()))
        .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => openPetDetail(context, pet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PetAvatar(pet: pet, radius: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: theme.textTheme.titleLarge),
                    if (info.isNotEmpty)
                      Text(info,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    if (nextDate != null)
                      Text('Next: $nextLabel · ${relativeDay(nextDate)}',
                          style: theme.textTheme.bodySmall),
                    if (activeMeds > 0)
                      Text(
                          activeMeds == 1
                              ? '1 active medicine'
                              : '$activeMeds active medicines',
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
