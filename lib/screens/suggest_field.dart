import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// One suggested name; [detail] helps searching and is shown under it.
class Suggestion {
  final String name;
  final String detail;
  const Suggestion(this.name, [this.detail = '']);
  bool matches(String q) =>
      name.toLowerCase().contains(q) || detail.toLowerCase().contains(q);
}

const dogVaccines = [
  Suggestion('Rabies'),
  Suggestion('DHPP', 'Distemper, hepatitis, parvovirus, parainfluenza'),
  Suggestion('DHLPP', 'DHPP plus leptospirosis'),
  Suggestion('DA2PP', 'Distemper, adenovirus, parvovirus, parainfluenza'),
  Suggestion('Parvovirus'),
  Suggestion('Distemper'),
  Suggestion('Bordetella', 'Kennel cough'),
  Suggestion('Leptospirosis'),
  Suggestion('Lyme disease'),
  Suggestion('Canine influenza', 'H3N2 / H3N8 dog flu'),
  Suggestion('Parainfluenza'),
  Suggestion('Canine coronavirus'),
];

const catVaccines = [
  Suggestion('Rabies'),
  Suggestion('FVRCP', 'Rhinotracheitis, calicivirus, panleukopenia'),
  Suggestion('FeLV', 'Feline leukemia'),
  Suggestion('Feline panleukopenia', 'Feline distemper'),
  Suggestion('Feline calicivirus'),
  Suggestion('Feline herpesvirus'),
  Suggestion('Chlamydophila'),
  Suggestion('Bordetella'),
];

const otherVaccines = [
  Suggestion('Rabies'),
  Suggestion('RHDV2', 'Rabbit haemorrhagic disease'),
  Suggestion('Myxomatosis', 'Rabbits'),
  Suggestion('Polyomavirus', 'Birds'),
  Suggestion('Canine distemper', 'Ferrets'),
  Suggestion('Tetanus'),
];

const commonMedicines = [
  Suggestion('Apoquel', 'Oclacitinib · itching, allergy'),
  Suggestion('Cytopoint', 'Allergy injection'),
  Suggestion('NexGard', 'Flea & tick chew'),
  Suggestion('NexGard Spectra', 'Flea, tick & worm chew'),
  Suggestion('Bravecto', 'Flea & tick'),
  Suggestion('Simparica', 'Flea & tick chew'),
  Suggestion('Simparica Trio', 'Flea, tick & heartworm'),
  Suggestion('Credelio', 'Flea & tick'),
  Suggestion('Frontline Plus', 'Flea & tick spot-on'),
  Suggestion('Advantage', 'Flea spot-on'),
  Suggestion('Advocate', 'Flea & worm spot-on'),
  Suggestion('Revolution', 'Selamectin · flea, worms'),
  Suggestion('Revolution Plus', 'Cats · flea, tick, worms'),
  Suggestion('Seresto collar', 'Flea & tick collar'),
  Suggestion('Heartgard Plus', 'Heartworm'),
  Suggestion('Interceptor', 'Heartworm & worms'),
  Suggestion('Milbemax', 'Dewormer'),
  Suggestion('Drontal', 'Dewormer'),
  Suggestion('Drontal Plus', 'Dewormer'),
  Suggestion('Panacur', 'Fenbendazole · dewormer'),
  Suggestion('Praziquantel', 'Tapeworm'),
  Suggestion('Pyrantel', 'Dewormer'),
  Suggestion('Ivermectin', 'Parasites'),
  Suggestion('Metronidazole', 'Antibiotic · diarrhoea'),
  Suggestion('Amoxicillin', 'Antibiotic'),
  Suggestion('Clavamox', 'Amoxicillin-clavulanate · antibiotic'),
  Suggestion('Cephalexin', 'Antibiotic'),
  Suggestion('Doxycycline', 'Antibiotic'),
  Suggestion('Enrofloxacin', 'Baytril · antibiotic'),
  Suggestion('Clindamycin', 'Antibiotic'),
  Suggestion('Prednisolone', 'Steroid'),
  Suggestion('Prednisone', 'Steroid'),
  Suggestion('Dexamethasone', 'Steroid'),
  Suggestion('Carprofen', 'Rimadyl · pain, arthritis'),
  Suggestion('Meloxicam', 'Metacam · pain, arthritis'),
  Suggestion('Onsior', 'Robenacoxib · pain'),
  Suggestion('Galliprant', 'Arthritis pain'),
  Suggestion('Gabapentin', 'Pain, anxiety'),
  Suggestion('Tramadol', 'Pain'),
  Suggestion('Trazodone', 'Anxiety'),
  Suggestion('Fluoxetine', 'Anxiety'),
  Suggestion('Cerenia', 'Maropitant · vomiting'),
  Suggestion('Famotidine', 'Stomach acid'),
  Suggestion('Omeprazole', 'Stomach acid'),
  Suggestion('Sucralfate', 'Stomach'),
  Suggestion('Vetmedin', 'Pimobendan · heart'),
  Suggestion('Enalapril', 'Heart, kidney'),
  Suggestion('Benazepril', 'Heart, kidney'),
  Suggestion('Furosemide', 'Diuretic'),
  Suggestion('Methimazole', 'Cat thyroid'),
  Suggestion('Levothyroxine', 'Dog thyroid'),
  Suggestion('Vetsulin', 'Insulin · diabetes'),
  Suggestion('Phenobarbital', 'Seizures'),
  Suggestion('Levetiracetam', 'Keppra · seizures'),
  Suggestion('Diphenhydramine', 'Benadryl · allergy'),
  Suggestion('Cetirizine', 'Allergy'),
  Suggestion('FortiFlora', 'Probiotic'),
  Suggestion('Fish oil', 'Omega-3 supplement'),
  Suggestion('Glucosamine', 'Joint supplement'),
  Suggestion('Lactulose', 'Constipation'),
  Suggestion('Eye drops'),
  Suggestion('Ear drops'),
];

List<Suggestion> vaccineSuggestions(AppStore store, Species species) {
  final base = switch (species) {
    Species.dog => dogVaccines,
    Species.cat => catVaccines,
    Species.other => otherVaccines,
  };
  return _merge(store.vaccines.map((v) => v.name), base, 'Used before');
}

List<Suggestion> medicineSuggestions(AppStore store) =>
    _merge(store.medications.map((m) => m.name), commonMedicines, 'Used before');

List<Suggestion> _merge(Iterable<String> used, List<Suggestion> base, String usedLabel) {
  final seen = <String>{};
  final out = <Suggestion>[];
  for (final u in used) {
    final t = u.trim();
    if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
    out.add(Suggestion(t, usedLabel));
  }
  for (final b in base) {
    if (seen.add(b.name.toLowerCase())) out.add(b);
  }
  return out;
}

/// A text field that shows matching names under it while typing.
class SuggestField extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.options,
    this.icon = Icons.search,
    required this.label,
    this.hint,
    this.capitalization = TextCapitalization.words,
  });

  final TextEditingController controller;
  final List<Suggestion> options;
  final IconData icon;
  final String label;
  final String? hint;
  final TextCapitalization capitalization;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Iterable<Suggestion> _matches(TextEditingValue v) {
    final q = v.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options.take(8);
    final starts = widget.options.where((o) => o.name.toLowerCase().startsWith(q));
    final rest = widget.options
        .where((o) => !o.name.toLowerCase().startsWith(q) && o.matches(q));
    final all = [...starts, ...rest];
    // Hide the list when the text already equals the only match.
    if (all.length == 1 && all.first.name.toLowerCase() == q) return const [];
    return all.take(8);
  }

  @override
  Widget build(BuildContext context) {
    final c = PawlyColors.of(context);
    final theme = Theme.of(context);
    return RawAutocomplete<Suggestion>(
      displayStringForOption: (o) => o.name,
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: _matches,
      onSelected: (v) => _focus.unfocus(),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: widget.capitalization,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: c.card,
            elevation: 6,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 280,
                maxWidth: MediaQuery.sizeOf(context).width - 40,
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      title: Text(o.name, style: theme.textTheme.titleSmall),
                      subtitle: o.detail.isEmpty
                          ? null
                          : Text(o.detail, style: theme.textTheme.bodySmall),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
