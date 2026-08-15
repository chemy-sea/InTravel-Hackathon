import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Resolves a location's single canonical photo path (`LocationModel
/// .imageUrl`, i.e. `site.photo` in `LocationService`) into an
/// [ImageProvider] — a network image if it's an absolute URL, otherwise a
/// bundled asset. This is the same resolution rule already used privately
/// in `location_details_screen.dart` (`_resolveImage` on both
/// `_LocationDetailsScreenState` and `_RelatedPlaceCard`), extracted here
/// so every other place that needs to show a location's photo (navigation
/// map pin popups, the reviews section) reuses the exact same source
/// instead of re-deriving it.
///
/// Network images are resolved through [CachedNetworkImageProvider] so
/// repeat views (e.g. revisiting a location, scrolling a list back into
/// view) reuse the decoded/downloaded copy instead of re-fetching over the
/// network every rebuild.
///
/// [cacheWidth]/[cacheHeight] (logical pixels) are forwarded to
/// [ResizeImage] so Flutter decodes the image at roughly the size it's
/// actually displayed at rather than at full source resolution — several
/// of the bundled photos in `assets/intravel/assets/home/` are multi-
/// megapixel originals, and decoding those at full size on every build is
/// the main cause of slow/janky photo loads in cards and thumbnails.
/// Callers that render the image large (e.g. a hero photo) can omit these
/// to decode at full resolution.
ImageProvider resolveLocationImage(
  String path, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  final ImageProvider base = path.startsWith('http')
      ? CachedNetworkImageProvider(path)
      : AssetImage(path);
  if (cacheWidth == null && cacheHeight == null) {
    return base;
  }
  return ResizeImage(base, width: cacheWidth, height: cacheHeight);
}

/// Renders a location's photo with the same fallback treatment used
/// throughout the app when the asset fails to load or is missing: a plain
/// colored/gradient box instead of a broken-image icon.
///
/// [fallbackColor] lets callers match their own surrounding surface (e.g.
/// `colors.forest` at reduced opacity, as `_RelatedPlaceCard` already
/// does); if omitted, a gradient close to the hero image's fallback in
/// `location_details_screen.dart` is used instead.
///
/// [width]/[height] should be set to the widget's actual on-screen size
/// (in logical pixels) whenever known — e.g. the same value passed to a
/// wrapping `SizedBox` — so the underlying image is decoded at that size
/// instead of full source resolution. See [resolveLocationImage].
class LocationPhoto extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final Color? fallbackColor;
  final double? width;
  final double? height;

  const LocationPhoto({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.fallbackColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = width != null ? (width! * dpr).round() : null;
    final cacheHeight = height != null ? (height! * dpr).round() : null;
    return Image(
      image: resolveLocationImage(
        imagePath,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      ),
      fit: fit,
      errorBuilder: (_, __, ___) => fallbackColor != null
          ? Container(color: fallbackColor)
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF264B3C), Color(0xFF0D2820)],
                ),
              ),
            ),
    );
  }
}
