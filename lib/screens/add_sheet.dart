import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import 'forms.dart';
import 'pet_form.dart';
import 'widgets.dart';

/// Bottom sheet with quick "add" actions (the Add tab).
Future<void> showAddSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(c, 0, Icons.pets, 'Pet'),
          _option(c, 1, Icons.vaccines_outlined, 'Vaccine'),
          _option(c, 2, Icons.medication_outlined, 'Medicine'),
          _option(c, 3, Icons.event_repeat, 'Repeat care (flea, deworming...)'),
          _option(c, 4, Icons.monitor_weight_outlined, 'Weight'),
          _option(c, 5, Icons.local_hospital_outlined, 'Vet visit'),
          const SizedBox(height: 8),
        ],
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
      await openVaccineForm(context, pet);
    case 2:
      await openMedicationForm(context, pet);
    case 3:
      await openCareForm(context, pet);
    case 4:
      await openWeightForm(context, pet);
    case 5:
      await openVisitForm(context, pet);
  }
}

Widget _option(BuildContext c, int value, IconData icon, String label) =>
    ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(c, value),
    );

Future<Pet?> _choosePet(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.pets.isEmpty) {
    return openPetForm(context);
  }
  if (store.pets.length == 1) return store.pets.first;
  return showDialog<Pet>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Which pet?'),
      children: [
        for (final p in store.pets)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, p),
            child: Row(
              children: [
                PetAvatar(pet: p, radius: 18),
                const SizedBox(width: 12),
                Text(p.name),
              ],
            ),
          ),
      ],
    ),
  );
}
