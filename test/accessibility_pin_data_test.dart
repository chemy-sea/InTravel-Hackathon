import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/models/location_model.dart';
import 'package:intravel/services/location_service.dart';

/// Covers the Section 6 accessibility-pin seed data: every non-Cafe
/// [AccessibilityFeature] with a real-world [AccessibilityFeature.location]
/// must sit inside the verified Intramuros boundary (same polygon/method
/// documented in docs/intramuros-boundary.md) and have a unique id, since
/// these are exactly the features [_NavigationScreenState.
/// _browseAccessibilityFeatures] turns into browse-mode map pins.
void main() {
  // Verified Intramuros boundary polygon (OSM relation 103707, fetched via
  // the Nominatim API — see docs/intramuros-boundary.md), same source used
  // for the Section 1 POI audit.
  const boundary = <List<double>>[
    [120.967321, 14.5959404],
    [120.9680803, 14.5948075],
    [120.9683145, 14.5945004],
    [120.9686472, 14.5940733],
    [120.9701375, 14.5918679],
    [120.9708276, 14.5908483],
    [120.9711229, 14.5903815],
    [120.9715305, 14.5897322],
    [120.9726081, 14.588025],
    [120.9738612, 14.585926],
    [120.974566, 14.5846378],
    [120.9749789, 14.5838329],
    [120.9753848, 14.5831132],
    [120.9754189, 14.5830555],
    [120.9754372, 14.5829932],
    [120.9754818, 14.5828894],
    [120.9757186, 14.5830116],
    [120.9760929, 14.5832257],
    [120.9773152, 14.5839552],
    [120.9785406, 14.5846904],
    [120.9787976, 14.5848496],
    [120.9794552, 14.5852429],
    [120.9797052, 14.5853959],
    [120.9798927, 14.5855317],
    [120.9800252, 14.5856572],
    [120.9801218, 14.5857719],
    [120.9802534, 14.5859725],
    [120.9803426, 14.5861434],
    [120.9803997, 14.5862975],
    [120.9804599, 14.586504],
    [120.980543, 14.5867998],
    [120.9807101, 14.5873892],
    [120.9808769, 14.5879779],
    [120.9809723, 14.5883249],
    [120.9810149, 14.5885812],
    [120.9810822, 14.5890286],
    [120.9809788, 14.5894818],
    [120.9809181, 14.5897179],
    [120.980847, 14.590043],
    [120.9806961, 14.5904526],
    [120.9803674, 14.5914904],
    [120.980236, 14.5918988],
    [120.9801481, 14.5920888],
    [120.9796799, 14.592856],
    [120.9786148, 14.5940218],
    [120.9780157, 14.5946331],
    [120.9779858, 14.5946787],
    [120.9779564, 14.5947276],
    [120.9778247, 14.5949592],
    [120.9776092, 14.5953131],
    [120.9773389, 14.5957838],
    [120.9769412, 14.5956029],
    [120.9758194, 14.5953511],
    [120.974771, 14.5952797],
    [120.9730159, 14.5953105],
    [120.9714972, 14.5955037],
    [120.9703434, 14.5957956],
    [120.9703038, 14.5958054],
    [120.9695916, 14.5959824],
    [120.9684298, 14.5960191],
    [120.967321, 14.5959404],
  ];

  bool isInsideBoundary(double lat, double lng) {
    var inside = false;
    var j = boundary.length - 1;
    for (var i = 0; i < boundary.length; i++) {
      final xi = boundary[i][0], yi = boundary[i][1];
      final xj = boundary[j][0], yj = boundary[j][1];
      if ((yi > lat) != (yj > lat) &&
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  List<AccessibilityFeature> allFeatures() {
    return LocationService()
        .getAllLocations()
        .expand((site) => site.accessibilityFeatures)
        .toList();
  }

  test('every located, non-Cafe accessibility feature is inside the '
      'verified Intramuros boundary', () {
    final offenders = <String>[];
    for (final feature in allFeatures()) {
      if (feature.type == AccessibilityType.cafe) continue;
      final loc = feature.location;
      if (loc == null) continue;
      if (!isInsideBoundary(loc.latitude, loc.longitude)) {
        offenders.add('${feature.name} (${loc.latitude}, ${loc.longitude})');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every accessibility feature id is unique across the catalogue', () {
    final ids = allFeatures().map((f) => f.id).toList();
    final seen = <String>{};
    final dupes = <String>[];
    for (final id in ids) {
      if (!seen.add(id)) dupes.add(id);
    }
    expect(dupes, isEmpty, reason: dupes.join(', '));
  });

  test('at least one located feature exists for every non-Cafe accessibility '
      'type that has a dedicated Accessibility Modes toggle', () {
    const typesRequiringPins = [
      AccessibilityType.restAreas,
      AccessibilityType.brailleVoice,
      AccessibilityType.pwdSeniorPriority,
      AccessibilityType.roughTerrain,
    ];
    final locatedTypes = allFeatures()
        .where((f) => f.location != null)
        .map((f) => f.type)
        .toSet();
    final missing = typesRequiringPins
        .where((t) => !locatedTypes.contains(t))
        .toList();
    expect(
      missing,
      isEmpty,
      reason: 'no located pin exists for: ${missing.join(', ')}',
    );
  });

  test('no Cafe-typed AccessibilityFeature exists in the generic '
      'accessibility seed data (Cafe has its own separate pin system)', () {
    final cafeFeatures = allFeatures()
        .where((f) => f.type == AccessibilityType.cafe)
        .toList();
    expect(cafeFeatures, isEmpty);
  });
}
