import 'package:flutter/material.dart';

import '../main.dart';
import '../pro.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'widgets.dart';

Future<void> openPro(BuildContext context, {String? reason}) =>
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true, builder: (_) => ProScreen(reason: reason)));

class _Feature {
  final IconData icon;
  final String name;
  final String free;
  final String pro;
  const _Feature(this.icon, this.name, this.free, this.pro);
}

const _features = [
  _Feature(Icons.pets, 'Number of pets', '${AppStore.freePetLimit}', 'Unlimited'),
  _Feature(Icons.notifications_active_outlined, 'Medicine, vaccine & care reminders', 'Yes', 'Yes'),
  _Feature(Icons.monitor_weight_outlined, 'Weight chart & vet notes', 'Yes', 'Yes'),
  _Feature(Icons.dark_mode_outlined, 'Light & dark theme', 'Yes', 'Yes'),
  _Feature(Icons.receipt_long_outlined, 'Expense log & monthly total', 'Yes', 'Yes'),
  _Feature(Icons.picture_as_pdf_outlined, 'Vet-ready PDF health report', '', 'Yes'),
  _Feature(Icons.insights_outlined, 'Spending insights by category & month', '', 'Yes'),
  _Feature(Icons.fact_check_outlined, 'Medicine dose history & on-time score', '', 'Yes'),
  _Feature(Icons.block, 'No ads, ever', 'Yes', 'Yes'),
];

class ProScreen extends StatefulWidget {
  const ProScreen({super.key, this.reason});
  final String? reason;

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  ProPlan _plan = ProPlan.yearly;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pro = ProScope.of(context);
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);

    if (pro.message != null) {
      final msg = pro.message!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        toast(context, msg);
        pro.message = null;
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text(''),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium, color: Brand.marigold, size: 40),
              const SizedBox(width: 10),
              Text('Pawly Pro', style: theme.textTheme.displaySmall),
            ]),
            const SizedBox(height: 8),
            Text(
              store.isPro
                  ? 'Pro is active. Thank you for supporting Pawly.'
                  : widget.reason ??
                      'Everything you need for daily care is free. Pro adds tools for busy, multi-pet homes.',
              style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 20),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(children: [
                    Expanded(child: Text('What you get', style: theme.textTheme.titleSmall)),
                    SizedBox(width: 66, child: Center(child: Text('Free', style: theme.textTheme.titleSmall))),
                    const SizedBox(width: 66, child: Center(child: ProBadge())),
                  ]),
                ),
                const Divider(),
                for (final f in _features)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Icon(f.icon, size: 20, color: c.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f.name, style: theme.textTheme.bodyMedium)),
                      SizedBox(width: 66, child: Center(child: _Cell(f.free, pro: false))),
                      SizedBox(width: 66, child: Center(child: _Cell(f.pro, pro: true))),
                    ]),
                  ),
              ]),
            ),
            if (!store.isPro) ...[
              const SizedBox(height: 22),
              _PlanTile(
                selected: _plan == ProPlan.yearly,
                title: 'Yearly',
                price: '${pro.priceFor(ProPlan.yearly)} / year',
                note: '7-day free trial · best value',
                highlight: true,
                onTap: () => setState(() => _plan = ProPlan.yearly),
              ),
              const SizedBox(height: 10),
              _PlanTile(
                selected: _plan == ProPlan.monthly,
                title: 'Monthly',
                price: '${pro.priceFor(ProPlan.monthly)} / month',
                note: 'Cancel any time in Google Play',
                onTap: () => setState(() => _plan = ProPlan.monthly),
              ),
              const SizedBox(height: 10),
              _PlanTile(
                selected: _plan == ProPlan.lifetime,
                title: 'Lifetime',
                price: '${pro.priceFor(ProPlan.lifetime)} once',
                note: 'Pay once, keep Pro forever',
                onTap: () => setState(() => _plan = ProPlan.lifetime),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Brand.marigold, foregroundColor: const Color(0xFF2E1F00)),
                onPressed: pro.busy ? null : () => pro.buy(_plan),
                child: pro.busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_plan == ProPlan.yearly ? 'Start free trial' : 'Continue'),
              ),
              TextButton(
                onPressed: pro.busy ? null : pro.restore,
                child: const Text('Restore purchase'),
              ),
              Text(
                'Payment is charged to your Google Play account. Subscriptions renew automatically until cancelled in Google Play > Payments & subscriptions.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (kTestBuild) ...[
              const SizedBox(height: 22),
              Panel(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Test build', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('This switch only exists in the test APK so you can try Pro features. The Play Store version does not have it.',
                      style: theme.textTheme.bodySmall),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unlock Pro for testing'),
                    value: store.settings.proTestUnlocked,
                    onChanged: (v) {
                      store.settings.proTestUnlocked = v;
                      store.changed();
                    },
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {required this.pro});
  final String value;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final c = PawlyColors.of(context);
    if (value.isEmpty) return Icon(Icons.remove, size: 18, color: c.muted.withValues(alpha: 0.5));
    if (value == 'Yes') {
      return Icon(Icons.check_circle_rounded,
          size: 20, color: pro ? Brand.marigold : c.done);
    }
    return Text(value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800, color: pro ? null : c.muted));
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.selected,
    required this.title,
    required this.price,
    required this.note,
    required this.onTap,
    this.highlight = false,
  });
  final bool selected;
  final String title;
  final String price;
  final String note;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = PawlyColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: selected ? Brand.marigold : c.cardBorder, width: selected ? 2.2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Brand.marigold : c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (highlight) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: c.done.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Save 58%',
                          style: theme.textTheme.labelSmall?.copyWith(color: c.done, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                Text(note, style: theme.textTheme.bodySmall),
              ]),
            ),
            Text(price, style: theme.textTheme.titleSmall),
          ]),
        ),
      ),
    );
  }
}
