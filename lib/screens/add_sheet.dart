import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'forms.dart';
import 'pet_form.dart';
import 'widgets.dart';

/// Bottom sheet with quick "add" actions (the Add tab).
Future<void> showAddSheet(BuildContext context) async {
  final options = [
    (Icons.medication_outlined, 'Medicine', Brand.petColors[2]),
    (Icons.vaccines_outlined, 'Vaccine', Brand.petColors[1]),
    (Icons.event_repeat, 'Repeat care', Brand.petColors[5]),
    (Icons.monitor_weight_outlined, 'Weight', Brand.petColors[4]),
    (Icons.local_hospital_outlined, 'Vet visit', Brand.petColors[3]),
    (Icons.receipt_long_outlined, 'Expense', Brand.petColors[0]),
  ];
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Add', style: Theme.of(c).textTheme.headlineSmall),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < options.length; i++)
                  Panel(
                    onTap: () => Navigator.pop(c, i + 1),
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconBubble(options[i].$1, color: options[i].$3, size: 44),
                      const SizedBox(height: 8),
                      Text(options[i].$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(c).textTheme.labelMedium),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(c, 0),
              icon: const Icon(Icons.pets),
              label: const Text('Add a new pet'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 0) {
    await openPetForm(context);
    return;
  }
  final pet = await _choosePet(context);
  if (pet == null || !context.mounted) return;
  switch (choice) {
    case 1:
      await openMedicationForm(context, pet);
    case 2:
      await openVaccineForm(context, pet);
    case 3:
      await openCareForm(context, pet);
    case 4:
      await openWeightForm(context, pet);
    case 5:
      await openVisitForm(context, pet);
    case 6:
      await openExpenseForm(context, pet);
  }
}

Future<Pet?> _choosePet(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.pets.isEmpty) return openPetForm(context);
  if (store.pets.length == 1) return store.pets.first;
  return showModalBottomSheet<Pet>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Which pet?', style: Theme.of(c).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final p in store.pets)
          ListTile(
            leading: PetAvatar(pet: p, radius: 18),
            title: Text(p.name),
            onTap: () => Navigator.pop(c, p),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
