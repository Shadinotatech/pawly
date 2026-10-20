import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'pro_screen.dart';
import 'widgets.dart';

/// Opens the add/edit pet screen. Returns the saved pet, or null.
Future<Pet?> openPetForm(BuildContext context, {Pet? pet}) async {
  final store = StoreScope.read(context);
  if (pet == null && !store.canAddPet) {
    await openPro(context,
        reason: 'The free plan includes up to ${AppStore.freePetLimit} pets. Go Pro for unlimited pets.');
    if (!context.mounted || !store.canAddPet) return null;
  }
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
  DateTime? _adopted;
  int _color = 0;
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
    _adopted = p?.adoptionDate;
    _photoPath = p?.photoPath;
    _color = p?.colorIndex ?? 0;
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _color = StoreScope.read(context).nextColorIndex());
      });
    }
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
    final hasPhoto = _newPhotoTemp != null || _photoPath != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(c, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(c, 'gallery'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(c, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      setState(() {
        _newPhotoTemp = null;
        _photoPath = null;
      });
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _newPhotoTemp = file.path);
    } catch (e) {
      if (mounted) toast(context, choice == 'camera' ? 'Could not open the camera.' : 'Could not open photos.');
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
    final oldPhoto = widget.pet?.photoPath;
    if (oldPhoto != null && photo != oldPhoto) {
      try {
        await File(oldPhoto).delete();
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
      colorIndex: _color,
      adoptionDate: _adopted,
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.petColor(_color)),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Brand.petColor(_color).withValues(alpha: 0.25),
                    backgroundImage: image,
                    child: image == null
                        ? Icon(Icons.add_a_photo_outlined, size: 36, color: scheme.onSurface)
                        : null,
                  ),
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
        const FieldLabel('Colour'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < Brand.petColors.length; i++)
              Semantics(
                button: true,
                selected: _color == i,
                label: 'Colour ${i + 1}',
                child: InkResponse(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Brand.petColors[i],
                      border: Border.all(
                          color: _color == i ? scheme.onSurface : Colors.transparent, width: 3),
                    ),
                    child: _color == i ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                ),
              ),
          ],
        ),
        const FieldLabel('Type'),
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
        PickerField(
          label: 'Adoption day',
          value: _adopted == null ? 'Not set' : fmtDate(_adopted!),
          icon: Icons.favorite_border,
          onTap: () async {
            final d = await pickDate(context, _adopted ?? DateTime.now(), last: DateTime.now());
            if (d != null) setState(() => _adopted = d);
          },
          onClear: _adopted == null ? null : () => setState(() => _adopted = null),
        ),
        const FieldLabel('Sex'),
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
