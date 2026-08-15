import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Single source of truth for the color associated with each map-pin
/// category, used by [lib/screens/navigation_screen.dart] for both the
/// Google Maps marker pins ([categoryPinHue], a 0-360 hue consumed by
/// `BitmapDescriptor.defaultMarkerWithHue`) and the category filter chips
/// ([categoryChipColor], a `Color` for chip backgrounds/text).
///
/// Before this existed, the pin hue lived in `_getCategoryMarkerHue` and
/// the filter chips had no color-coding of their own at all — the two
/// were never actually kept in sync because there was nothing to sync
/// *from*. Now both are derived from the single [_categoryHues] map below:
/// changing a category's pin color here automatically updates its chip
/// color too, since [categoryChipColor] converts the same hue value into
/// an RGB [Color] rather than hardcoding a second, independent color.
const Map<String, double> _categoryHues = {
  'Fortifications': BitmapDescriptor.hueRed,
  'Landmarks': BitmapDescriptor.hueOrange,
  'Schools': BitmapDescriptor.hueYellow,
  'Parks': BitmapDescriptor.hueGreen,
  // addendum spec 3 Section 2.1 — Cafe pins use a distinct hue via the
  // independent `_cafeFilteredLocations` path in navigation_screen.dart,
  // not this shared category-filter map; kept here too so any caller
  // that reaches Cafe sites through [categoryPinHue] directly (rather
  // than that separate path) still renders the same, consistent color.
  'Cafe': BitmapDescriptor.hueMagenta,
};

/// Fallback hue for any category not listed in [_categoryHues] — matches
/// the marker color previously hardcoded as the `default` case in
/// `_getCategoryMarkerHue`.
const double _defaultCategoryHue = BitmapDescriptor.hueAzure;

/// The Google Maps marker hue (0-360) for [category]'s pins.
double categoryPinHue(String category) =>
    _categoryHues[category] ?? _defaultCategoryHue;

/// The RGB [Color] for [category], derived from the exact same hue
/// [categoryPinHue] returns — so a category filter chip always visually
/// matches its pins on the map. Google Maps' hue-based marker tinting
/// uses full saturation/value (it's HSV under the hood, same as
/// [HSVColor]), so reconstructing an [HSVColor] with that hue and
/// standard saturation/value produces the same base color the pin
/// renders in, not just something "close enough".
Color categoryChipColor(String category) {
  return HSVColor.fromAHSV(1.0, categoryPinHue(category), 1.0, 1.0).toColor();
}
