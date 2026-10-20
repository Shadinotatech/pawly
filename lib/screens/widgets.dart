import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

Color petColorOf(Pet pet) => Brand.petColor(pet.colorIndex);

/// Round pet photo (or initial) with a ring in the pet's own colour.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.pet, this.radius = 24, this.ring = true});
  final Pet pet;
  final double radius;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final color = petColorOf(pet);
    final path = pet.photoPath;
    final hasPhoto = path != null && File(path).existsSync();
    final inner = CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.22),
      backgroundImage: hasPhoto ? FileImage(File(path)) : null,
      child: hasPhoto
          ? null
          : Text(
              pet.name.isEmpty ? '?' : pet.name.characters.first.toUpperCase(),
              style: TextStyle(
                fontFamily: Brand.display,
                fontSize: radius * 0.92,
                fontWeight: FontWeight.w600,
                color: Color.lerp(color, Colors.black, 0.35),
              ),
            ),
    );
    if (!ring) return inner;
    return Container(
      padding: EdgeInsets.all(radius > 30 ? 3.5 : 2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Container(
        padding: EdgeInsets.all(radius > 30 ? 3 : 2),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface),
        child: inner,
      ),
    );
  }
}

/// White (or dark) rounded panel used across the app.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = PawlyColors.of(context);
    return Material(
      color: color ?? c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color == null ? c.cardBorder : Colors.transparent),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small coloured square with an icon.
class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, {super.key, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon,
          size: size * 0.52,
          color: dark ? Color.lerp(color, Colors.white, 0.25) : Color.lerp(color, Colors.black, 0.25)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Kept for older screens: a smaller section title.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(text,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: PawlyColors.of(context).muted)),
    );
  }
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 1 : 3),
      decoration: BoxDecoration(
        color: Brand.marigold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Pro',
          style: TextStyle(
            fontFamily: Brand.display,
            fontWeight: FontWeight.w600,
            fontSize: small ? 11 : 12.5,
            color: const Color(0xFF3A2600),
          )),
    );
  }
}

/// Shown in place of a Pro feature for free users.
class ProLockedCard extends StatelessWidget {
  const ProLockedCard({
    super.key,
    required this.title,
    required this.message,
    required this.onUnlock,
    this.icon = Icons.workspace_premium_outlined,
  });
  final String title;
  final String message;
  final VoidCallback onUnlock;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onUnlock,
      child: Row(
        children: [
          IconBubble(icon, color: Brand.marigold, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  const ProBadge(small: true),
                ]),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 20),
        ],
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
            IconBubble(icon, color: theme.colorScheme.primary, size: 72),
            const SizedBox(height: 18),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: PawlyColors.of(context).muted),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// A tappable field that shows a value and opens a picker.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
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
      borderRadius: BorderRadius.circular(14),
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
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
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
    this.saveLabel = 'Save',
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final String saveLabel;

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final c in children) ...[c, const SizedBox(height: 16)],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: onSave, child: Text(saveLabel)),
        ),
      ),
    );
  }
}

/// Label above a group of chips in forms.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: PawlyColors.of(context).muted)),
      );
}
