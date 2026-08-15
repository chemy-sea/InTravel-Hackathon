import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/location_model.dart';
import '../models/nav_target.dart';
import '../models/route_result_model.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_colors.dart';
import '../widgets/location_photo.dart';
import '../widgets/nav_flow_launcher.dart';

/// Standalone Explore Intramuros map: Google Maps base layer (Android),
/// category-coded pins for every catalogued location in
/// [LocationService] (the same 50+ site catalog the rest of the app —
/// Home, Navigate, Plans — draws from), and a start/end picker that
/// fetches a real street-following walking route via [RoutingService]
/// (OpenRouteService) and renders it as a polyline.
///
/// Previously this screen's pins/Start/End picker were sourced from a
/// small, separately-curated ~15-entry `assets/data/pois.json` subset
/// (see the now-unused `lib/services/poi_service.dart`) that was
/// completely disconnected from [LocationService]'s much larger catalog
/// — most of the app's locations were never selectable here at all. This
/// screen now draws from [LocationService] directly, so its pin/picker
/// set matches every other screen in the app rather than a separate,
/// incomplete duplicate list.
///
/// Base map engine: `google_maps_flutter` (Android only — see README for
/// native API key setup). If the Google Maps API key is missing/invalid
/// or the map otherwise fails to initialize, this screen detects it and
/// shows a non-crashing fallback state with the location list still
/// accessible.
class OsmPoiMapScreen extends StatefulWidget {
  const OsmPoiMapScreen({super.key, RoutingService? routingService})
    : _routingServiceOverride = routingService;

  final RoutingService? _routingServiceOverride;

  @override
  State<OsmPoiMapScreen> createState() => _OsmPoiMapScreenState();
}

enum _LocationLoadState { loading, loaded, error }

enum _RouteLoadState { idle, loading, loaded, error }

enum _MapLoadState { loading, ready, failed }

class _OsmPoiMapScreenState extends State<OsmPoiMapScreen> {
  static const LatLng _defaultCenter = LatLng(14.5906, 120.9750);
  static const double _defaultZoom = 15;

  /// How long to wait for [GoogleMap.onMapCreated] to fire before treating
  /// the map as failed to load (missing/invalid API key, no Play Services,
  /// etc.) — an invalid-but-present key typically renders a blank/gray map
  /// with `onMapCreated` still firing, which this timeout does not catch;
  /// it specifically guards against the map controller never initializing
  /// at all (e.g. no Google Play services, some manifest misconfigurations)
  /// so the screen never gets stuck on an infinite loader.
  static const Duration _mapLoadTimeout = Duration(seconds: 8);

  late final RoutingService _routingService;
  GoogleMapController? _mapController;
  Timer? _mapLoadTimer;
  _MapLoadState _mapState = _MapLoadState.loading;

  _LocationLoadState _locationState = _LocationLoadState.loading;
  List<LocationModel> _locations = const [];
  String? _locationError;

  LocationModel? _startLocation;
  LocationModel? _endLocation;
  _RouteLoadState _routeState = _RouteLoadState.idle;
  RouteResult? _route;
  String? _routeError;

  /// Whether the non-map location list fallback is being shown — this is
  /// a failsafe only, shown automatically if the map fails to load, so
  /// location browsing/photos keep working even without a map. There is
  /// no manual toggle for it: a standalone "list of locations" view was
  /// removed from this page since it duplicated location browsing
  /// already available elsewhere in the app (Home / Plans).
  bool get _showListFallback => _mapState == _MapLoadState.failed;

  @override
  void initState() {
    super.initState();
    _routingService =
        widget._routingServiceOverride ?? OpenRouteServiceRouting();
    _startMapLoadTimeout();
    _loadLocations();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    super.dispose();
  }

  void _startMapLoadTimeout() {
    _mapLoadTimer = Timer(_mapLoadTimeout, () {
      if (!mounted) return;
      if (_mapState == _MapLoadState.loading) {
        setState(() => _mapState = _MapLoadState.failed);
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapLoadTimer?.cancel();
    _mapController = controller;
    if (!mounted) return;
    setState(() => _mapState = _MapLoadState.ready);
  }

  /// Loads the full catalog from [LocationService] — an in-memory, purely
  /// synchronous lookup (no asset parsing, no network), unlike the old
  /// `PoiService.loadPois()` this replaced. Kept behind the same
  /// loading/loaded/error state machine as before (rather than skipping
  /// straight to a field assignment) so this screen still degrades
  /// gracefully if [LocationService] ever throws, and so `_buildMapArea`'s
  /// existing loading/error branches keep working unchanged.
  void _loadLocations() {
    setState(() {
      _locationState = _LocationLoadState.loading;
      _locationError = null;
    });
    try {
      final locations = LocationService().getAllLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _locationState = _LocationLoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Could not load points of interest.';
        _locationState = _LocationLoadState.error;
      });
    }
  }

  Future<void> _fetchRoute() async {
    final start = _startLocation;
    final end = _endLocation;
    if (start == null || end == null) return;

    setState(() {
      _routeState = _RouteLoadState.loading;
      _routeError = null;
      _route = null;
    });

    try {
      final result = await _routingService.getWalkingRoute(
        _toRoutingLatLng(start.coordinates),
        _toRoutingLatLng(end.coordinates),
      );
      if (!mounted) return;
      setState(() {
        _route = result;
        _routeState = _RouteLoadState.loaded;
      });
      _fitBoundsToRoute(result.points);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = e is RoutingException
            ? e.message
            : 'Could not calculate a walking route. Please try again.';
        _routeState = _RouteLoadState.error;
      });
    }
  }

  /// [RoutingService.getWalkingRoute] and [RouteResult] operate on
  /// `latlong2`'s `LatLng`; [LocationModel.coordinates] and the map
  /// widget itself use `google_maps_flutter`'s own `LatLng` type instead,
  /// so points are converted at this boundary only.
  LatLng _toMapLatLng(ll.LatLng point) =>
      LatLng(point.latitude, point.longitude);

  ll.LatLng _toRoutingLatLng(LatLng point) =>
      ll.LatLng(point.latitude, point.longitude);

  void _fitBoundsToRoute(List<ll.LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_toMapLatLng(points.first), 17),
      );
      return;
    }
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final p in points.skip(1)) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        60,
      ),
    );
  }

  /// Hands off to the exact same shared turn-by-turn experience every
  /// other "Navigate" button in the app uses ([NavFlowLauncher] →
  /// [NavigationScreen]) — real ORS steps, the maneuver icon/distance/
  /// street-name card, live heading-following camera — rather than a
  /// second, simplified reimplementation living only on this screen.
  /// [NavigationScreen] always routes from the user's live position (or
  /// selected gate) to the target, so the previewed [_startLocation] here
  /// is only used to draw the preview polyline above; the actual
  /// turn-by-turn session's destination is [_endLocation].
  void _startTurnByTurn() {
    final end = _endLocation;
    if (end == null) return;
    // Uses [NavFlowLauncher.startTurnByTurn] rather than
    // [NavFlowLauncher.startWithTarget]: this button's label already
    // says "turn-by-turn navigation", so asking the user to then choose
    // between bird's-eye and turn-by-turn would be a redundant,
    // nonsensical extra step — go straight into turn-by-turn.
    NavFlowLauncher.startTurnByTurn(
      context,
      target: NavTarget.fromLocation(end),
    );
  }

  void _clearRoute() {
    setState(() {
      _startLocation = null;
      _endLocation = null;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  void _selectStart(LocationModel location) {
    setState(() {
      _startLocation = location;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  void _selectEnd(LocationModel location) {
    setState(() {
      _endLocation = location;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  /// Single source of truth (lib/utils/category_colors.dart): the same
  /// hue every other map-pin category color in the app derives from —
  /// see the Navigate screen's category filter chips, which use the same
  /// helper, so a category reads the same color everywhere.
  BitmapDescriptor _iconForCategory(String category) =>
      BitmapDescriptor.defaultMarkerWithHue(categoryPinHue(category));

  /// While a route is active (loaded, or in flight), only the start/end
  /// pins should be shown — every other pin is hidden so it doesn't
  /// clutter the route line, making it harder to actually follow. Normal
  /// browsing (no route requested/loaded yet, or after the user clears
  /// it via [_clearRoute]) restores the full pin set as before.
  bool get _isRouteActive =>
      _routeState == _RouteLoadState.loading ||
      _routeState == _RouteLoadState.loaded;

  Set<Marker> _buildMarkers() {
    final locationsToShow = _isRouteActive
        ? _locations.where(
            (loc) => loc.id == _startLocation?.id || loc.id == _endLocation?.id,
          )
        : _locations;
    return locationsToShow.map((location) {
      final isStart = location.id == _startLocation?.id;
      final isEnd = location.id == _endLocation?.id;
      final icon = isStart
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          : isEnd
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : _iconForCategory(location.category);
      return Marker(
        markerId: MarkerId(location.id),
        position: location.coordinates,
        icon: icon,
        onTap: () => _showLocationSheet(location),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    final route = _route;
    if (route == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('walking-route'),
        points: route.points.map(_toMapLatLng).toList(),
        color: AppTheme.accent,
        width: 5,
      ),
    };
  }

  void _showLocationSheet(LocationModel location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(
        location: location,
        onSetStart: () {
          Navigator.of(context).pop();
          _selectStart(location);
        },
        onSetEnd: () {
          Navigator.of(context).pop();
          _selectEnd(location);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: const Text('Explore Intramuros'),
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMapArea(colors)),
          // Preserves the original screen's behavior exactly: the route
          // picker panel was always shown regardless of map/list-fallback
          // state before this change (the old condition
          // `!_showListFallback || _mapState != _MapLoadState.failed` was
          // always true in practice, since the now-removed manual list
          // toggle was the only way `_showListFallback` could be true
          // while the map hadn't failed) — removing the manual toggle
          // must not incidentally change when this panel appears.
          _buildRoutePickerPanel(colors),
        ],
      ),
    );
  }

  Widget _buildMapArea(AppColors colors) {
    if (_locationState == _LocationLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_locationState == _LocationLoadState.error) {
      return _ErrorState(
        message: _locationError ?? 'Could not load points of interest.',
        onRetry: _loadLocations,
      );
    }

    // Map failed to load (missing/invalid key, no Play Services, etc.) —
    // show the graceful fallback instead of a blank screen/crash.
    // Location data and photos remain accessible via the list view either
    // way.
    if (_showListFallback) {
      return _LocationListFallback(
        locations: _locations,
        mapUnavailable: _mapState == _MapLoadState.failed,
        onLocationTap: _showLocationSheet,
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _defaultCenter,
            zoom: _defaultZoom,
          ),
          onMapCreated: _onMapCreated,
          markers: _buildMarkers(),
          polylines: _buildPolylines(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (_mapState == _MapLoadState.loading)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildRoutePickerPanel(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Walking route',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LocationDropdown(
                  label: 'Start',
                  locations: _locations,
                  selected: _startLocation,
                  onChanged: _selectStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LocationDropdown(
                  label: 'End',
                  locations: _locations,
                  selected: _endLocation,
                  onChanged: _selectEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_startLocation != null &&
                          _endLocation != null &&
                          _startLocation!.id != _endLocation!.id &&
                          _routeState != _RouteLoadState.loading)
                      ? _fetchRoute
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _routeState == _RouteLoadState.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get walking route'),
                ),
              ),
              if (_startLocation != null || _endLocation != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _clearRoute,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                ),
              ],
            ],
          ),
          if (_routeState == _RouteLoadState.error) ...[
            const SizedBox(height: 10),
            Text(
              _routeError ?? 'Could not calculate a walking route.',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_routeState == _RouteLoadState.loaded && _route != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 16,
                  color: colors.forest,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_route!.distanceLabel} · ${_route!.durationLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hands off to the same shared turn-by-turn experience every
            // other "Navigate" button in the app uses — real ORS steps,
            // maneuver card, live heading-following camera — rather than
            // a second, simplified version confined to this screen. The
            // polyline preview above stays as a quick visual aid; this
            // is the actual guided navigation entry point.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startTurnByTurn,
                icon: Icon(Icons.navigation_outlined, color: colors.forest),
                label: Text(
                  'Start turn-by-turn navigation',
                  style: TextStyle(
                    color: colors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.forest),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  final String label;
  final List<LocationModel> locations;
  final LocationModel? selected;
  final ValueChanged<LocationModel> onChanged;

  const _LocationDropdown({
    required this.label,
    required this.locations,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selected?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: locations
          .map(
            (location) => DropdownMenuItem<String>(
              value: location.id,
              child: Text(
                location.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id == null) return;
        final location = locations.firstWhere((l) => l.id == id);
        onChanged(location);
      },
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onSetStart;
  final VoidCallback onSetEnd;

  const _LocationPickerSheet({
    required this.location,
    required this.onSetStart,
    required this.onSetEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: location.imageUrl.isEmpty
                    ? Container(color: const Color(0xFF264B3C))
                    : LocationPhoto(imagePath: location.imageUrl),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              location.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              location.category,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSetStart,
                    child: const Text('Set as start'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSetEnd,
                    child: const Text('Set as end'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the map when it fails to load (missing/invalid Google
/// Maps API key, no Play Services, etc.) — per the failsafe requirement,
/// the app must not crash or show a blank screen, and location browsing
/// should keep working even without the map.
class _LocationListFallback extends StatelessWidget {
  final List<LocationModel> locations;
  final bool mapUnavailable;
  final ValueChanged<LocationModel> onLocationTap;

  const _LocationListFallback({
    required this.locations,
    required this.mapUnavailable,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (mapUnavailable)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB25E00),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Map unavailable — check the Google Maps API key. '
                    'Points of interest are still browsable below.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A4200)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final location = locations[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: location.imageUrl.isEmpty
                        ? Container(color: const Color(0xFF264B3C))
                        : LocationPhoto(imagePath: location.imageUrl),
                  ),
                ),
                title: Text(
                  location.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(location.category),
                onTap: () => onLocationTap(location),
              );
            },
          ),
        ),
      ],
    );
  }
}
