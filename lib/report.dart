import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'store.dart';
import 'util.dart';

/// Builds a vet-ready PDF of one pet's records and opens the share sheet.
Future<void> sharePetReport(AppStore store, Pet pet) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-Bold.ttf'));
  final display = pw.Font.ttf(await rootBundle.load('assets/fonts/Fredoka-SemiBold.ttf'));

  final pw.ImageProvider? photo = await _loadPhoto(pet);

  const ink = PdfColor.fromInt(0xFF1B2236);
  const muted = PdfColor.fromInt(0xFF6B7287);
  const line = PdfColor.fromInt(0xFFE6E8F0);
  const brand = PdfColor.fromInt(0xFF26335C);

  final useLb = store.settings.useLb;
  final vaccines = store.vaccinesFor(pet.id);
  final meds = store.medsFor(pet.id);
  final care = store.careFor(pet.id);
  final weights = store.weightsFor(pet.id).reversed.take(8).toList();
  final visits = store.visitsFor(pet.id);
  final adherence = store.adherence(petId: pet.id);

  pw.Widget heading(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(font: display, fontSize: 15, color: brand)),
      );

  pw.Widget table(List<String> head, List<List<String>> rows) {
    if (rows.isEmpty) {
      return pw.Text('None recorded.', style: pw.TextStyle(font: regular, fontSize: 10, color: muted));
    }
    return pw.TableHelper.fromTextArray(
      headers: head,
      data: rows,
      headerStyle: pw.TextStyle(font: bold, fontSize: 9.5, color: ink),
      cellStyle: pw.TextStyle(font: regular, fontSize: 9.5, color: ink),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F8)),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.6)),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  final info = <List<String>>[
    ['Species', speciesLabel(pet.species)],
    if (pet.breed.isNotEmpty) ['Breed', pet.breed],
    if (pet.birthDate != null) ['Birthday', '${fmtDate(pet.birthDate!)} (${ageText(pet.birthDate)})'],
    if (pet.sex.isNotEmpty) ['Sex', pet.sex == 'male' ? 'Male' : 'Female'],
    if (pet.microchip.isNotEmpty) ['Microchip', pet.microchip],
    if (weights.isNotEmpty) ['Latest weight', fmtWeight(weights.first.weightKg, useLb)],
  ];

  final doc = pw.Document(title: '${pet.name} health report', author: 'Pawly');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Made with Pawly · ${fmtDate(DateTime.now())}',
              style: pw.TextStyle(font: regular, fontSize: 8.5, color: muted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 8.5, color: muted)),
        ],
      ),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (photo != null)
            pw.Container(
              width: 64,
              height: 64,
              margin: const pw.EdgeInsets.only(right: 16),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                image: pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
              ),
            ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(pet.name, style: pw.TextStyle(font: display, fontSize: 26, color: ink)),
              pw.Text('Health report', style: pw.TextStyle(font: regular, fontSize: 12, color: muted)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: line),
        heading('Profile'),
        table(['Detail', 'Value'], info),
        if (pet.notes.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Notes: ${pet.notes}', style: pw.TextStyle(font: regular, fontSize: 10)),
        ],
        heading('Vaccines'),
        table(['Vaccine', 'Given', 'Next due', 'Vet'], [
          for (final v in vaccines)
            [v.name, fmtDate(v.givenDate), v.nextDueDate == null ? '-' : fmtDate(v.nextDueDate!), v.vetName],
        ]),
        heading('Medicines'),
        table(['Medicine', 'Dose', 'Times', 'Period'], [
          for (final m in meds)
            [
              m.name,
              m.dose,
              m.reminderMinutes.map(fmtMinutes).join(', '),
              m.endDate == null ? 'From ${fmtDate(m.startDate)}' : '${fmtDate(m.startDate)} - ${fmtDate(m.endDate!)}',
            ],
        ]),
        if (adherence != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('Doses marked as given in the last 30 days: ${(adherence * 100).round()}%',
                style: pw.TextStyle(font: regular, fontSize: 10, color: muted)),
          ),
        heading('Repeat care'),
        table(['Task', 'Every', 'Next'], [
          for (final c in care) [c.displayName, '${c.repeatEveryDays} days', fmtDate(c.nextDate)],
        ]),
        heading('Weight'),
        table(['Date', 'Weight'], [
          for (final w in weights) [fmtDate(w.date), fmtWeight(w.weightKg, useLb)],
        ]),
        heading('Vet visits'),
        table(['Date', 'Reason', 'Vet', 'Notes'], [
          for (final v in visits) [fmtDate(v.date), v.reason, v.vetName, v.note],
        ]),
        pw.SizedBox(height: 18),
        pw.Text('This report was created by the owner in the Pawly app and is not a veterinary document.',
            style: pw.TextStyle(font: regular, fontSize: 8.5, color: muted)),
      ],
    ),
  );

  final bytes = await doc.save();
  final safe = pet.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  await Printing.sharePdf(bytes: bytes, filename: '${safe}_health_report.pdf');
}

Future<pw.ImageProvider?> _loadPhoto(Pet pet) async {
  final path = pet.photoPath;
  if (path == null) return null;
  final f = File(path);
  if (!await f.exists()) return null;
  return pw.MemoryImage(await f.readAsBytes());
}
