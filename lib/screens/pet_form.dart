import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models.dart';
import '../util.dart';
import 'widgets.dart';

/// Opens the add/edit pet screen. Returns the saved pet, or null.
Future<Pet?> openPetForm(BuildContext context, {Pet? pet}) {
  return Navigator.of(context).push<Pet>(
    MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
  );
}

class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key, this.pet});
  final Pet? pet;

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _chip;
  late final TextEditingController _notes;
  late Species _species;
  late String _sex;
  DateTime? _birth;
  String? _photoPath;
  String? _newPhotoTemp; // picked but not saved yet

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _name = TextEditingController(text: p?.name ?? '');
    _breed = TextEditingController(text: p?.breed ?? '');
    _chip = TextEditingController(text: p?.microchip ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _species = p?.species ?? Species.dog;
    _sex = p?.sex ?? '';
    _birth = p?.birthDate;
    _photoPath = p?.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _chip.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _newPhotoTemp = file.path);
    } catch (e) {
      if (mounted) toast(context, 'Could not open photos.');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Please enter your pet\'s name.');
      return;
    }
    final store = StoreScope.read(context);
    final id = widget.pet?.id ?? newId();
    var photo = _photoPath;
    if (_newPhotoTemp != null) {
      final dest =
          '${store.photoDir}/$id-${DateTime.now().millisecondsSinceEpoch}.jpg';
      try {
        await File(_newPhotoTemp!).copy(dest);
        if (_photoPath != null && _photoPath != dest) {
          try {
            await File(_photoPath!).delete();
          } catch (_) {}
        }
        photo = dest;
      } catch (_) {}
    }
    final pet = Pet(
      id: id,
      name: name,
      species: _species,
      breed: _breed.text.trim(),
      birthDate: _birth,
      sex: _sex,
      photoPath: photo,
      microchip: _chip.text.trim(),
      notes: _notes.text.trim(),
    );
    store.upsertPet(pet);
    if (mounted) Navigator.of(context).pop(pet);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ImageProvider? image;
    if (_newPhotoTemp != null) {
      image = FileImage(File(_newPhotoTemp!));
    } else if (_photoPath != null && File(_photoPath!).existsSync()) {
      image = FileImage(File(_photoPath!));
    }

    return FormPage(
      title: _isEdit ? 'Edit pet' : 'Add a pet',
      onSave: _save,
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: image,
                  child: image == null
                      ? Icon(Icons.pets, size: 44, color: scheme.primary)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.photo_camera,
                        size: 18, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name *'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final s in Species.values)
              ChoiceChip(
                label: Text(speciesLabel(s)),
                selected: _species == s,
                onSelected: (_) => setState(() => _species = s),
              ),
          ],
        ),
        TextField(
          controller: _breed,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Breed'),
        ),
        PickerField(
          label: 'Birthday',
          value: _birth == null
              ? 'Not set'
              : '${fmtDate(_birth!)}  (${ageText(_birth)})',
          icon: Icons.cake_outlined,
          onTap: () async {
            final d = await pickDate(context, _birth ?? DateTime.now(),
                last: DateTime.now());
            if (d != null) setState(() => _birth = d);
          },
          onClear: _birth == null ? null : () => setState(() => _birth = null),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final s in const ['male', 'female'])
              ChoiceChip(
                label: Text(s == 'male' ? 'Male' : 'Female'),
                selected: _sex == s,
                onSelected: (sel) => setState(() => _sex = sel ? s : ''),
              ),
          ],
        ),
        TextField(
          controller: _chip,
          decoration: const InputDecoration(labelText: 'Microchip number'),
        ),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
              labelText: 'Notes (allergies, food, behaviour)'),
        ),
      ],
    );
  }
}
