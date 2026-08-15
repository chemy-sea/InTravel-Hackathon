import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/location_photo.dart';
import '../services/location_service.dart';
import '../services/saved_places_service.dart';
import '../services/itinerary_service.dart';
import '../models/location_model.dart';
import '../models/itinerary_model.dart';
import 'location_details_screen.dart';
import 'itinerary_detail_screen.dart';
import 'itinerary_create_screen.dart';
import 'itinerary_navigation_overview_screen.dart';

/// "Your Hub" saved-places screen, ported from the Eunice-branch
/// `#screen-saved` markup: back chevron, eyebrow + title, Locations /
/// Itineraries hub tabs, and a list of saved-place cards with a heart icon.
/// Backed by [SavedPlacesService] so saves made on the details screen show
/// up here immediately and persist across app restarts.
class FavoritesScreen extends StatefulWidget {
  /// Which hub tab to show first — defaults to 'Locations' to match the
  /// original branch behavior. Pass 'Itineraries' when deep-linking here
  /// from an entry point whose whole purpose is surfacing saved
  /// itineraries (e.g. the Navigation screen's Itineraries chip, or the
  /// Home screen's "View Saved Itineraries" button), so the user lands
  /// straight on the relevant tab instead of Locations.
  final String initialTab;

  const FavoritesScreen({super.key, this.initialTab = 'Locations'});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late String _selectedTab = widget.initialTab;

  /// Multi-select state for the Itineraries tab's bulk-delete flow.
  /// `null` means selection mode is off; an empty-but-non-null set means
  /// the user has long-pressed into selection mode without picking
  /// anything yet.
  Set<String>? _selectedItineraryIds;

  bool get _isSelectingItineraries => _selectedItineraryIds != null;

  @override
  void initState() {
    super.initState();
    SavedPlacesService.instance.load();
    ItineraryService.instance.load();
  }

  void _enterItinerarySelection(String initialId) {
    setState(() => _selectedItineraryIds = {initialId});
  }

  void _toggleItinerarySelection(String id) {
    setState(() {
      final ids = _selectedItineraryIds;
      if (ids == null) return;
      if (ids.contains(id)) {
        ids.remove(id);
      } else {
        ids.add(id);
      }
      // Nothing left selected — exit selection mode entirely rather than
      // leaving an empty-but-active selection bar on screen.
      if (ids.isEmpty) _selectedItineraryIds = null;
    });
  }

  void _cancelItinerarySelection() {
    setState(() => _selectedItineraryIds = null);
  }

  Future<void> _confirmDeleteSelectedItineraries() async {
    final ids = _selectedItineraryIds;
    if (ids == null || ids.isEmpty) return;
    final colors = AppColors.of(context);
    final count = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          'Delete $count itinerar${count == 1 ? 'y' : 'ies'}?',
          style: TextStyle(color: colors.ink),
        ),
        content: Text(
          'This will permanently delete the selected itinerar${count == 1 ? 'y' : 'ies'}. This cannot be undone.',
          style: TextStyle(color: colors.ink.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ItineraryService.instance.deleteItineraries(ids);
      if (mounted) setState(() => _selectedItineraryIds = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: SavedPlacesService.instance,
      builder: (context, _) {
        final savedIds = SavedPlacesService.instance.savedIds;
        final savedLocations = LocationService()
            .getAllLocations()
            .where((l) => savedIds.contains(l.id))
            .toList();

        return Scaffold(
          backgroundColor: colors.paper,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Text(
                          '‹',
                          style: TextStyle(
                            fontSize: 36,
                            height: 1,
                            color: colors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '— SAVED',
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Hub',
                              style: TextStyle(
                                fontFamily: AppTheme.serifFont,
                                fontSize: 27,
                                color: colors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ─── Hub Tabs ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E3D9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HubTabButton(
                            label: 'Locations',
                            isActive: _selectedTab == 'Locations',
                            onTap: () =>
                                setState(() => _selectedTab = 'Locations'),
                          ),
                        ),
                        Expanded(
                          child: _HubTabButton(
                            label: 'Itineraries',
                            isActive: _selectedTab == 'Itineraries',
                            onTap: () =>
                                setState(() => _selectedTab = 'Itineraries'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ─── Saved List ──────────────────────────────────────
                  if (_selectedTab == 'Itineraries')
                    AnimatedBuilder(
                      animation: ItineraryService.instance,
                      builder: (context, _) {
                        final itineraries =
                            ItineraryService.instance.itineraries;
                        // Selected ids can go stale if an itinerary is
                        // deleted from elsewhere while selection mode is
                        // active (e.g. from the detail screen) — drop any
                        // that no longer exist rather than showing a wrong
                        // count.
                        final validIds = itineraries.map((i) => i.id).toSet();
                        final selectedIds = _selectedItineraryIds?.intersection(
                          validIds,
                        );
                        if (_isSelectingItineraries &&
                            selectedIds != _selectedItineraryIds) {
                          _selectedItineraryIds = selectedIds;
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isSelectingItineraries)
                              _ItinerarySelectionBar(
                                colors: colors,
                                selectedCount: selectedIds?.length ?? 0,
                                onCancel: _cancelItinerarySelection,
                                onDelete: _confirmDeleteSelectedItineraries,
                              )
                            else
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ItineraryCreateScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.forest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Add Itinerary',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (itineraries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                child: Center(
                                  child: Text(
                                    'No saved itineraries yet. Tap "Add Itinerary" to build your own trip.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...itineraries.map(
                                (itinerary) => _ItineraryCard(
                                  colors: colors,
                                  itinerary: itinerary,
                                  isSelecting: _isSelectingItineraries,
                                  isSelected:
                                      selectedIds?.contains(itinerary.id) ??
                                      false,
                                  onLongPress: () =>
                                      _enterItinerarySelection(itinerary.id),
                                  onToggleSelected: () =>
                                      _toggleItinerarySelection(itinerary.id),
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  else if (savedLocations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No saved places yet. Open a tourist spot and tap Save place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...savedLocations.map(
                      (location) =>
                          _SavedCard(colors: colors, location: location),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Hub Tab Button ─────────────────────────────────────────────────────────────

class _HubTabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _HubTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF242424), fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Saved Card ─────────────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel location;

  const _SavedCard({required this.colors, required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationDetailsScreen(location: location),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        constraints: const BoxConstraints(minHeight: 102),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 115,
              height: 102,
              child: LocationPhoto(
                imagePath: location.imageUrl,
                width: 115,
                height: 102,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    location.type.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1F5748),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    location.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.note,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF65746C),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 13),
              child: GestureDetector(
                onTap: () => SavedPlacesService.instance.toggle(location.id),
                child: const Text(
                  '♥',
                  style: TextStyle(color: Color(0xFFEC535C), fontSize: 21),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Itinerary Card ─────────────────────────────────────────────────────────────
// Itinerary Hub entry (spec 3.3-3.5), living in the existing "Itineraries"
// tab of Your Hub. Matches the visual language of `_SavedCard` above.

class _ItineraryCard extends StatelessWidget {
  final AppColors colors;
  final ItineraryModel itinerary;

  /// Whether Your Hub's Itineraries tab is currently in multi-select mode
  /// (bulk-delete flow). While active, tapping the card toggles selection
  /// instead of opening the detail screen, and a checkbox-style indicator
  /// replaces the trailing chevron.
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelected;

  const _ItineraryCard({
    required this.colors,
    required this.itinerary,
    this.isSelecting = false,
    this.isSelected = false,
    required this.onLongPress,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final locations = ItineraryService.instance.resolveLocations(itinerary);
    return GestureDetector(
      onTap: isSelecting
          ? onToggleSelected
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ItineraryDetailScreen(itineraryId: itinerary.id),
                ),
              );
            },
      // Long-press enters bulk-select mode (spec Section 4) regardless of
      // whether it's already active, so long-pressing a second card while
      // selecting simply adds to the existing selection.
      onLongPress: isSelecting ? onToggleSelected : onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? Border.all(color: colors.forest, width: 2)
              : null,
        ),
        child: Row(
          children: [
            if (isSelecting) ...[
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? colors.forest : colors.muted,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined, color: colors.forest, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${locations.length} stop${locations.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            // "Navigate" button + chevron are hidden in selection mode —
            // they're not meaningful actions while bulk-selecting, and
            // hiding them keeps the row focused on the checkbox/tap-to-
            // select interaction.
            if (!isSelecting) ...[
              GestureDetector(
                onTap: locations.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItineraryNavigationOverviewScreen(
                              itineraryName: itinerary.name,
                              stops: List<LocationModel>.of(locations),
                            ),
                          ),
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: locations.isEmpty ? colors.line : colors.forest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        color: locations.isEmpty ? colors.muted : Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Navigate',
                        style: TextStyle(
                          color: locations.isEmpty
                              ? colors.muted
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.muted, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contextual selection bar shown in place of the "Add Itinerary" button
/// while Your Hub's Itineraries tab is in multi-select mode (spec Section
/// 4): shows the current selection count and Cancel/Delete actions. This
/// app has no `Scaffold.appBar` anywhere (every screen uses a hand-rolled
/// header `Row` instead), so this swaps in as a replacement for that
/// button rather than an actual AppBar, matching the rest of the app's
/// convention.
class _ItinerarySelectionBar extends StatelessWidget {
  final AppColors colors;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ItinerarySelectionBar({
    required this.colors,
    required this.selectedCount,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.forest.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: selectedCount == 0 ? null : onDelete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFE53935),
                ),
                SizedBox(width: 4),
                Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
