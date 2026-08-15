import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:intravel/models/nav_target.dart';
import 'package:intravel/models/route_result_model.dart';
import 'package:intravel/screens/navigation_screen.dart';
import 'package:intravel/screens/osm_poi_map_screen.dart';
import 'package:intravel/services/routing_service.dart';

class _FakeRoutingService implements RoutingService {
  @override
  Future<RouteResult> getWalkingRoute(LatLng start, LatLng end) async {
    return RouteResult(
      points: [start, end],
      distanceMeters: 100,
      durationSeconds: 90,
    );
  }
}

void main() {
  testWidgets('OsmPoiMapScreen loads POIs and renders the map + picker panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OsmPoiMapScreen(routingService: _FakeRoutingService())),
    );

    // Initial frame: loading state for POIs.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the asset load complete.
    await tester.pumpAndSettle();

    expect(find.text('Explore Intramuros'), findsOneWidget);
    expect(find.text('Walking route'), findsOneWidget);
    expect(find.text('Get walking route'), findsOneWidget);
    // "Get walking route" should be disabled until both start & end picked.
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Get walking route'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows the map-unavailable fallback and a browsable POI list if '
      'onMapCreated never fires within the timeout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OsmPoiMapScreen(routingService: _FakeRoutingService())),
    );
    await tester.pumpAndSettle();

    // In the test environment GoogleMap's platform view never calls
    // onMapCreated, so advancing past the screen's load timeout should
    // trip the failsafe rather than leaving an infinite loader.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();

    expect(find.textContaining('Map unavailable'), findsOneWidget);
    // POI list stays browsable even though the map failed to load.
    expect(find.text('Fort Santiago'), findsOneWidget);
  });

  testWidgets(
    'once a route is loaded, "Start turn-by-turn navigation" hands off to '
    'the shared NavigationScreen (same component every other Navigate '
    'button uses) rather than a separate/simplified reimplementation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OsmPoiMapScreen(routingService: _FakeRoutingService()),
        ),
      );
      await tester.pumpAndSettle();

      // The button shouldn't be present before a route exists.
      expect(find.text('Start turn-by-turn navigation'), findsNothing);

      // Pick Start/End POIs via the dropdowns, then fetch the preview
      // route.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Start'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fort Santiago').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'End'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manila Cathedral').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Get walking route'),
      );
      await tester.pumpAndSettle();

      // Once the route is loaded, the shared turn-by-turn entry point
      // should appear.
      expect(find.text('Start turn-by-turn navigation'), findsOneWidget);

      await tester.tap(find.text('Start turn-by-turn navigation'));
      await tester.pumpAndSettle();

      // The button's label already says "turn-by-turn navigation", so
      // tapping it must go straight into NavigationScreen in turn-by-turn
      // mode — no intermediate Bird's-eye/Turn-by-turn choice sheet
      // (improvement-batch spec: Explore POIs turn-by-turn flow fix).
      expect(find.text('Choose a view'), findsNothing);
      expect(find.byType(NavigationScreen), findsOneWidget);
      final navigationScreen = tester.widget<NavigationScreen>(
        find.byType(NavigationScreen),
      );
      expect(navigationScreen.viewMode, NavViewMode.turnByTurn);
    },
  );

  testWidgets('the app bar has no standalone "list of locations" toggle — POI '
      'browsing lives elsewhere in the app, and the only list fallback here '
      'is the automatic map-unavailable failsafe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OsmPoiMapScreen(routingService: _FakeRoutingService())),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show list'), findsNothing);
    expect(find.byTooltip('Show map'), findsNothing);
  });
}
