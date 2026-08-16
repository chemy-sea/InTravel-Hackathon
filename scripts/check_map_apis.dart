// check_map_apis.dart
//
// Standalone diagnostic script — NOT part of the Flutter app.
// Verifies that ORS_API_KEY and MAPS_API_KEY (from env.json /
// android/local.properties) are valid by making a real, minimal request
// against each provider.
//
// Usage (from repo root):
//   dart run scripts/check_map_apis.dart
//
// Requires only `dart:io` / `dart:convert` — no pub packages needed,
// so `dart run` works even without `flutter pub get`.

import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  stdout.writeln('=== InTravel map API key checker ===\n');

  final ors = await _readOrsKey();
  final maps = await _readMapsKey();

  var okCount = 0;
  var total = 0;

  if (ors != null) {
    total++;
    if (await _checkOrs(ors)) okCount++;
  } else {
    stdout.writeln('[ORS]   SKIP — could not find ORS_API_KEY in env.json');
  }

  if (maps != null) {
    total++;
    if (await _checkGoogleMaps(maps)) okCount++;
  } else {
    stdout.writeln(
        '[MAPS]  SKIP — could not find MAPS_API_KEY in android/local.properties');
  }

  stdout.writeln('\n=== Summary: $okCount/$total key(s) valid ===');
  exit(okCount == total && total > 0 ? 0 : 1);
}

Future<String?> _readOrsKey() async {
  final file = File('env.json');
  if (!await file.exists()) {
    stdout.writeln('[ORS]   env.json not found at repo root.');
    return null;
  }
  try {
    final data = jsonDecode(await file.readAsString()) as Map;
    final key = data['ORS_API_KEY'] as String?;
    if (key == null || key.isEmpty || key.contains('YOUR_')) return null;
    return key;
  } catch (e) {
    stdout.writeln('[ORS]   Failed to parse env.json: $e');
    return null;
  }
}

Future<String?> _readMapsKey() async {
  final file = File('android/local.properties');
  if (!await file.exists()) {
    stdout.writeln(
        '[MAPS]  android/local.properties not found.');
    return null;
  }
  final lines = await file.readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('MAPS_API_KEY=')) {
      final key = trimmed.substring('MAPS_API_KEY='.length).trim();
      if (key.isEmpty || key.contains('YOUR_')) return null;
      return key;
    }
  }
  return null;
}

/// Calls the ORS directions API with two fixed points inside Intramuros,
/// Manila. A 200 with a "features" array means the key + service works.
Future<bool> _checkOrs(String key) async {
  stdout.writeln('[ORS]   Checking OpenRouteService key...');
  final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson');
  try {
    final client = HttpClient();
    final req = await client.postUrl(uri);
    req.headers.set('Authorization', key);
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    // Two points near Fort Santiago / Intramuros — arbitrary but valid land coords.
    req.write(jsonEncode({
      'coordinates': [
        [120.9724, 14.5958], // Fort Santiago
        [120.9752, 14.5915], // Manila Cathedral area
      ],
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();

    if (res.statusCode == 200) {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['features'] is List) {
        stdout.writeln('[ORS]   OK — got a valid route response (200).');
        return true;
      }
      stdout.writeln('[ORS]   WARN — 200 but unexpected body shape.');
      return false;
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      stdout.writeln(
          '[ORS]   FAIL — HTTP ${res.statusCode}: key rejected (invalid/expired/unauthorized).');
    } else if (res.statusCode == 429) {
      stdout.writeln(
          '[ORS]   WARN — HTTP 429: rate-limited. Key format is likely fine; try again later.');
    } else {
      stdout.writeln('[ORS]   FAIL — HTTP ${res.statusCode}: $body');
    }
    return false;
  } catch (e) {
    stdout.writeln('[ORS]   FAIL — request error: $e');
    return false;
  }
}

/// Calls the Google Maps Geocoding API (lightweight, cheap, same project/key
/// as Maps SDK for Android) to confirm the key is valid and enabled.
/// Note: this checks the KEY validity + API enablement at the account level;
/// it cannot verify Android package-name/SHA-1 restrictions if any are set,
/// since those are only enforced for requests coming from the actual signed
/// APK, not from this script.
Future<bool> _checkGoogleMaps(String key) async {
  stdout.writeln('[MAPS]  Checking Google Maps API key...');
  final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=14.5958,120.9724&key=$key');
  try {
    final client = HttpClient();
    final req = await client.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();

    final decoded = jsonDecode(body);
    final status = decoded is Map ? decoded['status'] as String? : null;

    switch (status) {
      case 'OK':
        stdout.writeln('[MAPS]  OK — key is valid and Geocoding API responded.');
        return true;
      case 'REQUEST_DENIED':
        final msg = decoded['error_message'] ?? '(no message)';
        stdout.writeln('[MAPS]  FAIL — REQUEST_DENIED: $msg');
        stdout.writeln(
            '[MAPS]        Common causes: key restricted to Android apps only '
            '(expected — this script isn\'t an Android app, so this specific '
            'check may false-negative), Maps/Geocoding API not enabled, or '
            'billing not enabled on the project.');
        return false;
      case 'ZERO_RESULTS':
        stdout.writeln('[MAPS]  OK — key works (ZERO_RESULTS is a valid response, not a key error).');
        return true;
      default:
        stdout.writeln('[MAPS]  FAIL — status=$status body=$body');
        return false;
    }
  } catch (e) {
    stdout.writeln('[MAPS]  FAIL — request error: $e');
    return false;
  }
}
