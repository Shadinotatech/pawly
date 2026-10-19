import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.pet, this.radius = 24});
  final Pet pet;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = pet.photoPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path)),
      );
    }
    final color = switch (pet.species) {
      Species.dog => scheme.primaryContainer,
      Species.cat => scheme.tertiaryContainer,
      Species.other => scheme.secondaryContainer,
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        pet.name.isEmpty ? '?' : pet.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// A tappable row that shows a value and opens a picker.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today,
    this.onClear,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
        ),
        child: Text(value),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// Standard layout for add/edit screens.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            for (final c in children) ...[c, const SizedBox(height: 16)],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onSave,
        icon: const Icon(Icons.check),
        label: const Text('Save'),
      ),
    );
  }
}
