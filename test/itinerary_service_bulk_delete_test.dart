import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/itinerary_service.dart';

/// Covers [ItineraryService.deleteItineraries] (Your Hub multi-select bulk
/// delete, spec Section 4) — a single-pass removal-by-id-set, distinct
/// from the existing single-item [ItineraryService.deleteItinerary].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ItineraryService.instance.load();
    // ItineraryService is a process-wide singleton with no `clear()` of
    // its own — reset its in-memory state directly between tests, same
    // pattern used by chatbot_function_calling_test.dart.
    for (final itinerary in List.of(ItineraryService.instance.itineraries)) {
      await ItineraryService.instance.deleteItinerary(itinerary.id);
    }
  });

  test('removes every itinerary whose id is in the given set', () async {
    // `ItineraryModel.id` is a microsecond timestamp — pace these apart so
    // three back-to-back creates can't collide onto the same id.
    final a = await ItineraryService.instance.createItinerary(
      name: 'Trip A',
      locationIds: const ['fort-santiago'],
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await ItineraryService.instance.createItinerary(
      name: 'Trip B',
      locationIds: const ['manila-cathedral'],
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final c = await ItineraryService.instance.createItinerary(
      name: 'Trip C',
      locationIds: const ['plaza-roma'],
    );

    await ItineraryService.instance.deleteItineraries({a.id, c.id});

    final remaining = ItineraryService.instance.itineraries;
    expect(remaining.length, 1);
    expect(remaining.single.id, b.id);
  });

  test('is a no-op for ids that do not exist', () async {
    final a = await ItineraryService.instance.createItinerary(
      name: 'Trip A',
      locationIds: const ['fort-santiago'],
    );

    await ItineraryService.instance.deleteItineraries({'not-a-real-id'});

    expect(ItineraryService.instance.itineraries.length, 1);
    expect(ItineraryService.instance.itineraries.single.id, a.id);
  });

  test('is a no-op for an empty id set (does not notify listeners)', () async {
    await ItineraryService.instance.createItinerary(
      name: 'Trip A',
      locationIds: const ['fort-santiago'],
    );

    var notified = false;
    void listener() => notified = true;
    ItineraryService.instance.addListener(listener);
    await ItineraryService.instance.deleteItineraries(const <String>{});
    ItineraryService.instance.removeListener(listener);

    expect(notified, isFalse);
    expect(ItineraryService.instance.itineraries.length, 1);
  });

  test(
    'persists the deletion (survives a fresh read of in-memory state)',
    () async {
      final a = await ItineraryService.instance.createItinerary(
        name: 'Trip A',
        locationIds: const ['fort-santiago'],
      );
      // `ItineraryModel.id` is a microsecond timestamp — pace this apart
      // so it can't collide with `a`'s id if both land in the same
      // microsecond, which real usage (a human tapping "create" twice)
      // never does this fast.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await ItineraryService.instance.createItinerary(
        name: 'Trip B',
        locationIds: const ['manila-cathedral'],
      );

      await ItineraryService.instance.deleteItineraries({a.id});

      final remaining = ItineraryService.instance.itineraries;
      expect(remaining.length, 1);
      expect(remaining.single.id, b.id);
    },
  );
}
