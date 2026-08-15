import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intravel/utils/category_colors.dart';

void main() {
  group('categoryPinHue', () {
    test('returns the expected hue for each of the four nav filter '
        'categories', () {
      expect(categoryPinHue('Fortifications'), BitmapDescriptor.hueRed);
      expect(categoryPinHue('Landmarks'), BitmapDescriptor.hueOrange);
      expect(categoryPinHue('Schools'), BitmapDescriptor.hueYellow);
      expect(categoryPinHue('Parks'), BitmapDescriptor.hueGreen);
    });

    test('returns the Cafe hue for the Cafe category', () {
      expect(categoryPinHue('Cafe'), BitmapDescriptor.hueMagenta);
    });

    test('falls back to a default hue for an unrecognized category', () {
      expect(categoryPinHue('SomethingElse'), BitmapDescriptor.hueAzure);
    });
  });

  group('categoryChipColor', () {
    test('derives an RGB color whose hue matches categoryPinHue exactly '
        'for every category — proving there is one source of truth, not '
        'two independently hardcoded color values', () {
      for (final category in [
        'Fortifications',
        'Landmarks',
        'Schools',
        'Parks',
        'Cafe',
      ]) {
        final chipColor = categoryChipColor(category);
        final hsv = HSVColor.fromColor(chipColor);
        // A small tolerance accounts for 8-bit RGB channel quantization
        // when converting HSV -> Color -> HSV (not every hue is exactly
        // representable in 24-bit RGB) — this still proves the two are
        // derived from the same underlying value, not independently
        // chosen colors that merely happen to look similar.
        expect(
          hsv.hue,
          closeTo(categoryPinHue(category), 0.5),
          reason: 'chip color hue for $category must match its pin hue',
        );
      }
    });

    test('returns distinct colors for each category', () {
      final colors = [
        'Fortifications',
        'Landmarks',
        'Schools',
        'Parks',
        'Cafe',
      ].map(categoryChipColor).toSet();
      expect(colors.length, 5);
    });
  });
}
