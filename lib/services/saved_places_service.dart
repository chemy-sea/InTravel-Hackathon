import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of saved (bookmarked) location IDs, mirroring the
/// Eunice-branch `intravel.saved-places.v1` localStorage key.
///
/// Deliberately starts empty and stays empty until the user explicitly
/// saves something (spec Section 5) — an earlier version seeded four
/// locations (Fort Santiago, Museo de Intramuros, Palacio del Gobernador,
/// Ayuntamiento de Manila) into the in-memory set before [load] ever ran,
/// so on a fresh install (nothing in SharedPreferences yet) those four
/// showed as saved without the user tapping anything. No default seeding
/// happens anymore.
class SavedPlacesService extends ChangeNotifier {
  static final SavedPlacesService instance = SavedPlacesService._internal();
  SavedPlacesService._internal();

  static const String _storageKey = 'intravel.saved-places.v1';

  Set<String> _savedIds = {};
  bool _isLoaded = false;

  Set<String> get savedIds => _savedIds;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey);
      if (stored != null) {
        _savedIds = stored.toSet();
      }
    } catch (_) {
      // Keep the in-memory defaults if persistence is unavailable.
    }
    _isLoaded = true;
    notifyListeners();
  }

  bool isSaved(String id) => _savedIds.contains(id);

  Future<void> toggle(String id) async {
    if (_savedIds.contains(id)) {
      _savedIds.remove(id);
    } else {
      _savedIds.add(id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _savedIds.toList());
    } catch (_) {}
  }
}
