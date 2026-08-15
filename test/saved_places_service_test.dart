import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/saved_places_service.dart';

/// Covers the Section 5 fix: no location should be saved by default. An
/// earlier version seeded four locations into the in-memory set before
/// [SavedPlacesService.load] ever ran, so a fresh install (nothing in
/// SharedPreferences yet) showed them as saved without the user tapping
/// anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts with nothing saved before load() is called', () {
    // A literal fresh-install check: the in-memory default before any
    // SharedPreferences read has happened must be empty.
    expect(SavedPlacesService.instance.savedIds, isEmpty);
  });

  test(
    'stays empty after load() on a fresh install (nothing persisted yet)',
    () async {
      SharedPreferences.setMockInitialValues({});
      await SavedPlacesService.instance.load();

      expect(SavedPlacesService.instance.savedIds, isEmpty);
      expect(SavedPlacesService.instance.isSaved('fort-santiago'), isFalse);
      expect(
        SavedPlacesService.instance.isSaved('museo-de-intramuros'),
        isFalse,
      );
      expect(
        SavedPlacesService.instance.isSaved('palacio-del-gobernador'),
        isFalse,
      );
      expect(
        SavedPlacesService.instance.isSaved('ayuntamiento-de-manila'),
        isFalse,
      );
    },
  );

  test('toggle only saves a location when explicitly requested', () async {
    SharedPreferences.setMockInitialValues({});
    await SavedPlacesService.instance.load();

    expect(SavedPlacesService.instance.isSaved('fort-santiago'), isFalse);

    await SavedPlacesService.instance.toggle('fort-santiago');
    expect(SavedPlacesService.instance.isSaved('fort-santiago'), isTrue);

    await SavedPlacesService.instance.toggle('fort-santiago');
    expect(SavedPlacesService.instance.isSaved('fort-santiago'), isFalse);
  });
}
