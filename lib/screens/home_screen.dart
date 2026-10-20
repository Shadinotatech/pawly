import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../reminders.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'expenses_screen.dart';
import 'forms.dart';
import 'pet_detail.dart';
import 'pet_form.dart';
import 'pro_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenPets});
  final VoidCallback onOpenPets;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool? _notifOk;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final ok = await Reminders.instance.notificationsEnabled();
    if (mounted) setState(() => _notifOk = ok);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<Pet?> _pickPet() async {
    final store = StoreScope.read(context);
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

  Future<void> _quick(int kind) async {
    final pet = await _pickPet();
    if (pet == null || !mounted) return;
    switch (kind) {
      case 0:
        await openMedicationForm(context, pet);
      case 1:
        await openVaccineForm(context, pet);
      case 2:
        await openWeightForm(context, pet);
      case 3:
        await openExpenseForm(context, pet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);

    if (store.pets.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.pets,
            title: 'Add your first pet',
            message:
                'Pawly reminds you about medicines, vaccines and care so nothing is missed.',
            action: FilledButton.icon(
              onPressed: () => openPetForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add a pet'),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = dateOnly(now);
    final items = store.todayItems();
    final todays = items
        .where((i) => !dateOnly(i.when).isAfter(today))
        .toList();
    final doneCount = todays.where((i) => i.done).length;
    final overdue = todays.where((i) => i.overdue).length;

    // Everything due after today: vaccines, repeat care and medicine courses
    // that start later. Nearest first.
    final upcoming = <_Upcoming>[
      for (final v in store.dueVaccines())
        if (store.petById(v.petId) != null && dateOnly(v.nextDueDate!).isAfter(today))
          _Upcoming(store.petById(v.petId)!, '${v.name} vaccine',
              v.nextDueDate!, Icons.vaccines_outlined),
      for (final cTask in store.careTasks)
        if (store.petById(cTask.petId) != null && dateOnly(cTask.nextDate).isAfter(today))
          _Upcoming(store.petById(cTask.petId)!, cTask.displayName,
              cTask.nextDate, Icons.event_repeat),
      for (final m in store.medications)
        if (store.petById(m.petId) != null && dateOnly(m.startDate).isAfter(today))
          _Upcoming(store.petById(m.petId)!, '${m.name} starts',
              m.startDate, Icons.medication_outlined),
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (upcoming.length > 10) upcoming.removeRange(10, upcoming.length);

    final thisMonth = store.spentInMonth(now);
    final lastMonth = store.spentInMonth(DateTime(now.year, now.month - 1));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Reminders.instance.rescheduleAll(store);
          await _checkNotifications();
          setState(() {});
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 2),
                          Text(_longDate(now), style: theme.textTheme.bodyMedium?.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    if (!store.isPro)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.workspace_premium, size: 18, color: Brand.marigold),
                          label: const Text('Go Pro'),
                          onPressed: () => openPro(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _PetStrip(onOpenPets: widget.onOpenPets),
            if (_notifOk == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Panel(
                  color: c.overdue.withValues(alpha: 0.12),
                  onTap: () async {
                    final ok = await Reminders.instance.requestPermission();
                    if (!ok) await Reminders.instance.openNotificationSettings();
                    _checkNotifications();
                  },
                  child: Row(children: [
                    Icon(Icons.notifications_off_outlined, color: c.overdue),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Reminders are off. Tap to turn them on so you never miss a dose.')),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _TodayHero(
                items: todays,
                done: doneCount,
                overdue: overdue,
                next: upcoming.isEmpty ? null : upcoming.first,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                _QuickAction(Icons.medication_outlined, 'Medicine', Brand.petColors[2], () => _quick(0)),
                const SizedBox(width: 10),
                _QuickAction(Icons.vaccines_outlined, 'Vaccine', Brand.petColors[1], () => _quick(1)),
                const SizedBox(width: 10),
                _QuickAction(Icons.monitor_weight_outlined, 'Weight', Brand.petColors[4], () => _quick(2)),
                const SizedBox(width: 10),
                _QuickAction(Icons.receipt_long_outlined, 'Expense', Brand.petColors[0], () => _quick(3)),
              ]),
            ),
            SectionHeader('Today',
                action: todays.isEmpty ? null : '$doneCount of ${todays.length} done'),
            if (todays.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  child: Row(children: [
                    IconBubble(Icons.check_rounded, color: c.done),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Nothing due today. Add a medicine or care task and it will show up here.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ]),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    for (var i = 0; i < todays.length; i++) ...[
                      if (i > 0) const Divider(indent: 72),
                      _TimelineRow(item: todays[i]),
                    ],
                  ]),
                ),
              ),
            const SectionHeader('Coming up'),
            if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconBubble(Icons.event_available_outlined, color: Brand.petColors[1]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Nothing planned yet. Add a vaccine due date or a repeat task like flea treatment.',
                            style: theme.textTheme.bodyMedium),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _quick(1),
                          icon: const Icon(Icons.vaccines_outlined, size: 18),
                          label: const Text('Vaccine'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pet = await _pickPet();
                            if (pet != null && context.mounted) await openCareForm(context, pet);
                          },
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: const Text('Repeat care'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              )
            else ...[
              SizedBox(
                height: 132,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: upcoming.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _UpcomingCard(u: upcoming[i]),
                ),
              ),
            ],
            SectionHeader('Spending',
                action: 'See all',
                onAction: () => openExpenses(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SpendCard(thisMonth: thisMonth, lastMonth: lastMonth),
            ),
            if (!store.isPro)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ProPromo(onTap: () => openPro(context)),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

String _longDate(DateTime d) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${days[d.weekday - 1]}, ${fmtDate(d)}';
}

class _Upcoming {
  final Pet pet;
  final String title;
  final DateTime date;
  final IconData icon;
  _Upcoming(this.pet, this.title, this.date, this.icon);
}

// ------------------------------------------------------------- pet strip

class _PetStrip extends StatelessWidget {
  const _PetStrip({required this.onOpenPets});
  final VoidCallback onOpenPets;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    return SizedBox(
      height: 104,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in store.pets)
            _StripItem(
              onTap: () => openPetDetail(context, p),
              avatar: PetAvatar(pet: p, radius: 27),
              label: p.name,
            ),
          _StripItem(
            onTap: () async {
              if (!store.canAddPet) {
                openPro(context, reason: 'Free plan includes up to ${AppStore.freePetLimit} pets.');
                return;
              }
              await openPetForm(context);
            },
            avatar: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.cardBorder, width: 2),
                color: c.card,
              ),
              child: Icon(Icons.add, color: theme.colorScheme.primary),
            ),
            label: 'Add pet',
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.onTap, required this.avatar, required this.label});
  final VoidCallback onTap;
  final Widget avatar;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(children: [
          avatar,
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------- hero

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.items, required this.done, required this.overdue, this.next});
  final List<TodayItem> items;
  final int done;
  final int overdue;
  final _Upcoming? next;

  @override
  Widget build(BuildContext context) {
    final c = PawlyColors.of(context);
    final total = items.length;
    final headline = total == 0
        ? 'A calm day'
        : done == total
            ? 'All done today'
            : '${total - done} left today';
    final sub = total == 0
        ? 'No medicines or care due.'
        : done == total
            ? 'Every pet is cared for. Nice work.'
            : overdue > 0
                ? '$overdue overdue, check them first.'
                : 'Tap a task below when it is done.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [c.heroStart, c.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: TodayRingPainter(
                    segments: [
                      for (final i in items)
                        RingSegment(petColorOf(i.pet), i.done),
                    ],
                    track: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(total == 0 ? '0' : '$done/$total',
                          style: const TextStyle(
                              fontFamily: Brand.display,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text('done',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: const TextStyle(
                            fontFamily: Brand.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.15)),
                    const SizedBox(height: 6),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.78))),
                    if (overdue > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.overdue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$overdue overdue',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(next!.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Next: ${next!.title} for ${next!.pet.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                Text(relativeDay(next!.date),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class RingSegment {
  final Color color;
  final bool done;
  RingSegment(this.color, this.done);
}

/// The Today ring: one segment per task, painted in the pet's colour once done.
class TodayRingPainter extends CustomPainter {
  TodayRingPainter({required this.segments, required this.track});
  final List<RingSegment> segments;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    if (segments.isEmpty) {
      canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
      return;
    }
    final n = segments.length;
    final gap = n == 1 ? 0.0 : 0.09;
    final sweep = (math.pi * 2 - gap * n) / n;
    var start = -math.pi / 2 + gap / 2;
    for (final s in segments) {
      base.color = s.done ? s.color : track;
      canvas.drawArc(rect, start, n == 1 ? math.pi * 2 : sweep, false, base);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant TodayRingPainter old) => true;
}

// ------------------------------------------------------------- quick actions

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(children: [
          IconBubble(icon, color: color, size: 42),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------- timeline

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});
  final TodayItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final store = StoreScope.read(context);
    final icon = switch (item.kind) {
      TodayKind.medication => Icons.medication_outlined,
      TodayKind.vaccine => Icons.vaccines_outlined,
      TodayKind.care => Icons.event_repeat,
    };
    final when = item.kind == TodayKind.medication ? fmtTime(item.when) : relativeDay(item.when);

    void complete() {
      switch (item.kind) {
        case TodayKind.medication:
          store.toggleDose(item.medication!, item.when);
        case TodayKind.vaccine:
          openVaccineForm(context, item.pet, renewOf: item.vaccine);
        case TodayKind.care:
          final prev = item.care!.nextDate;
          store.completeCare(item.care!);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('${item.title} done. Next on ${fmtDate(item.care!.nextDate)}.'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  item.care!.nextDate = prev;
                  store.changed();
                },
              ),
            ));
      }
    }

    return InkWell(
      onTap: () => openPetDetail(context, item.pet),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            PetAvatar(pet: item.pet, radius: 20),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: theme.colorScheme.primary),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    color: item.done ? c.muted : null,
                  )),
              const SizedBox(height: 2),
              Text('$when · ${item.subtitle}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: item.overdue ? c.overdue : c.muted,
                      fontWeight: item.overdue ? FontWeight.w700 : null)),
            ]),
          ),
          _CheckButton(done: item.done, color: petColorOf(item.pet), onTap: complete),
        ]),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.color, required this.onTap});
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = PawlyColors.of(context);
    return Semantics(
      button: true,
      label: done ? 'Mark not done' : 'Mark done',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? c.done : Colors.transparent,
            border: Border.all(color: done ? c.done : c.cardBorder, width: 2),
          ),
          child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- upcoming

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.u});
  final _Upcoming u;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final days = dateOnly(u.date).difference(dateOnly(DateTime.now())).inDays;
    final color = petColorOf(u.pet);
    return SizedBox(
      width: 168,
      child: Panel(
        onTap: () => openPetDetail(context, u.pet),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('$days',
                  style: TextStyle(
                      fontFamily: Brand.display,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(color, theme.colorScheme.onSurface, 0.35))),
              const SizedBox(width: 6),
              Text(days == 1 ? 'day' : 'days', style: theme.textTheme.bodySmall),
              const Spacer(),
              PetAvatar(pet: u.pet, radius: 13, ring: false),
            ]),
            const Spacer(),
            Text(u.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall),
            Text('${u.pet.name} · ${fmtShortDate(u.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- spending

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.thisMonth, required this.lastMonth});
  final double thisMonth;
  final double lastMonth;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    final cur = store.settings.currency;
    String compare;
    if (lastMonth == 0 && thisMonth == 0) {
      compare = 'Log food, vet and other costs to see where the money goes.';
    } else if (lastMonth == 0) {
      compare = 'First month tracked.';
    } else {
      final diff = thisMonth - lastMonth;
      compare = diff >= 0
          ? '${fmtMoney(diff, cur)} more than last month'
          : '${fmtMoney(-diff, cur)} less than last month';
    }
    return Panel(
      onTap: () => openExpenses(context),
      child: Row(children: [
        IconBubble(Icons.account_balance_wallet_outlined, color: Brand.petColors[0], size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This month', style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
            Text(fmtMoney(thisMonth, cur),
                style: theme.textTheme.headlineSmall),
            Text(compare, style: theme.textTheme.bodySmall),
          ]),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

// ------------------------------------------------------------- pro promo

class _ProPromo extends StatelessWidget {
  const _ProPromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Panel(
      onTap: onTap,
      color: Brand.marigold.withValues(alpha: dark ? 0.16 : 0.2),
      child: Row(children: [
        const Icon(Icons.workspace_premium, color: Brand.marigold, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pawly Pro', style: theme.textTheme.titleMedium),
            Text('Unlimited pets, vet-ready PDF reports, spending insights and dose history.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
          ]),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}
