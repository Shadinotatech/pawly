import 'package:flutter_test/flutter_test.dart';
import 'package:pawly/models.dart';
import 'package:pawly/util.dart';

void main() {
  test('time formatting', () {
    expect(fmtMinutes(9 * 60), '9:00 AM');
    expect(fmtMinutes(13 * 60 + 5), '1:05 PM');
    expect(fmtMinutes(0), '12:00 AM');
  });

  test('medication active days', () {
    final m = Medication(
      id: 'm1',
      petId: 'p1',
      name: 'Test',
      startDate: DateTime(2026, 1, 10),
      endDate: DateTime(2026, 1, 12),
    );
    expect(m.isActiveOn(DateTime(2026, 1, 9)), isFalse);
    expect(m.isActiveOn(DateTime(2026, 1, 10, 23)), isTrue);
    expect(m.isActiveOn(DateTime(2026, 1, 12)), isTrue);
    expect(m.isActiveOn(DateTime(2026, 1, 13)), isFalse);
  });

  test('json round trip', () {
    final p = Pet(id: 'p1', name: 'Milo', birthDate: DateTime(2022, 3, 1));
    final back = Pet.fromJson(p.toJson());
    expect(back.name, 'Milo');
    expect(back.birthDate, DateTime(2022, 3, 1));
  });
}
